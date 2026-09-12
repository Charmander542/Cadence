import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftData
import UIKit

struct GoogleCalendarSummary: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var primary: Bool
}

enum GoogleCalendarError: LocalizedError {
    case notConfigured
    case notSignedIn
    case authFailed(String)
    case apiFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Calendar is not configured. Add GoogleOAuthClientID to Info.plist."
        case .notSignedIn:
            return "Connect your Google account in Settings."
        case .authFailed(let msg): return msg
        case .apiFailed(let msg): return msg
        }
    }
}

@MainActor
final class GoogleCalendarService: NSObject {
    static let shared = GoogleCalendarService()

    private let keychainAccount = "google_calendar_oauth"
    private let scope = "https://www.googleapis.com/auth/calendar.events"
    private var authSession: ASWebAuthenticationSession?

    var isSignedIn: Bool { loadTokens()?.accessToken != nil }

    var clientID: String? {
        Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String
    }

    var redirectURI: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthRedirectURI") as? String
            ?? "com.musclemeal.app:/oauth2redirect"
    }

    var isConfigured: Bool {
        guard let id = clientID else { return false }
        return !id.isEmpty && !id.hasPrefix("YOUR_")
    }

    // MARK: - OAuth

    func signIn() async throws {
        guard isConfigured, let clientID else { throw GoogleCalendarError.notConfigured }

        let verifier = Self.randomURLSafeString(count: 64)
        let challenge = Self.codeChallenge(for: verifier)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authURL = components.url else {
            throw GoogleCalendarError.authFailed("Invalid auth URL")
        }

        let code: String = try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectScheme) { url, error in
                if let error {
                    continuation.resume(throwing: GoogleCalendarError.authFailed(error.localizedDescription))
                    return
                }
                guard let url,
                      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: GoogleCalendarError.authFailed("Missing authorization code"))
                    return
                }
                continuation.resume(returning: code)
            }
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }

        try await exchangeCode(code, verifier: verifier)
    }

    func signOut() {
        deleteTokens()
        PlannerPreferences.googleCalendarIDs = []
        PlannerPreferences.googleCalendarID = nil
        PlannerPreferences.googleCalendarTitle = nil
    }

    func selectedGoogleCalendarIDs() -> [String] {
        let ids = Array(PlannerPreferences.googleCalendarIDs)
        return ids.isEmpty ? [] : ids
    }

    func initializeGoogleCalendarSelectionIfNeeded(with calendars: [GoogleCalendarSummary]) {
        guard !PlannerPreferences.googleCalendarsSelectionInitialized else { return }
        var selected = Set<String>()
        if let legacy = PlannerPreferences.googleCalendarID, !legacy.isEmpty {
            selected.insert(legacy)
        } else if let primary = calendars.first(where: \.primary) {
            selected.insert(primary.id)
        }
        PlannerPreferences.googleCalendarIDs = selected
        PlannerPreferences.googleCalendarsSelectionInitialized = true
    }

    // MARK: - API

    func listCalendars() async throws -> [GoogleCalendarSummary] {
        let data = try await apiRequest(path: "/users/me/calendarList")
        struct Response: Decodable {
            struct Item: Decodable {
                var id: String
                var summary: String
                var primary: Bool?
            }
            var items: [Item]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.items.map {
            GoogleCalendarSummary(id: $0.id, title: $0.summary, primary: $0.primary ?? false)
        }
    }

    func upsertTaskEvent(_ task: PlannerTaskEntity) async throws {
        guard !task.isImportedExternalEvent else { return }
        guard PlannerPreferences.syncTasksToGoogleCalendar,
              let dueAt = task.dueAt,
              !task.isCompleted
        else {
            try await deleteTaskEvent(task)
            return
        }

        let calendarIDs = selectedGoogleCalendarIDs()
        guard !calendarIDs.isEmpty else { return }

        var map = task.googleCalendarEventIDs
        let selected = Set(calendarIDs)

        for (calendarID, eventID) in map where !selected.contains(calendarID) {
            _ = try? await apiRequest(
                path: "/calendars/\(calendarID.urlPathEncoded)/events/\(eventID.urlPathEncoded)",
                method: "DELETE"
            )
            map.removeValue(forKey: calendarID)
        }

        let end = dueAt.addingTimeInterval(task.durationMinutes > 0 ? TimeInterval(task.durationMinutes * 60) : 3600)
        let body = GoogleEventPayload.summary(
            title: task.title,
            notes: task.notes.isEmpty ? "Cadence task" : task.notes,
            start: dueAt,
            end: end
        )

        for calendarID in calendarIDs {
            if let eventID = map[calendarID] {
                _ = try await apiRequest(
                    path: "/calendars/\(calendarID.urlPathEncoded)/events/\(eventID.urlPathEncoded)",
                    method: "PATCH",
                    body: body
                )
            } else {
                let data = try await apiRequest(
                    path: "/calendars/\(calendarID.urlPathEncoded)/events",
                    method: "POST",
                    body: body
                )
                struct Created: Decodable { var id: String }
                map[calendarID] = try JSONDecoder().decode(Created.self, from: data).id
            }
        }
        task.googleCalendarEventIDs = map
    }

    func deleteTaskEvent(_ task: PlannerTaskEntity) async throws {
        guard !task.isImportedExternalEvent else { return }
        var map = task.googleCalendarEventIDs
        for (calendarID, eventID) in map {
            _ = try? await apiRequest(
                path: "/calendars/\(calendarID.urlPathEncoded)/events/\(eventID.urlPathEncoded)",
                method: "DELETE"
            )
        }
        task.googleCalendarEventIDs = [:]
    }

    /// Pulls events from selected Google calendars into Cadence as calendar events.
    @discardableResult
    func importEvents(into context: ModelContext, lookbackDays: Int = 14, lookaheadDays: Int = 60) async throws -> Int {
        guard PlannerPreferences.importFromGoogleCalendar, isSignedIn else {
            try pruneImportedEvents(source: "google", keeping: [], in: context)
            return 0
        }
        let calendarIDs = selectedGoogleCalendarIDs()
        guard !calendarIDs.isEmpty else {
            try pruneImportedEvents(source: "google", keeping: [], in: context)
            return 0
        }

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -lookbackDays, to: cal.startOfDay(for: .now)) ?? .now
        let end = cal.date(byAdding: .day, value: lookaheadDays, to: cal.startOfDay(for: .now)) ?? .now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var seenIDs = Set<String>()
        var upserted = 0

        struct GoogleEventDateDTO: Decodable {
            var dateTime: String?
            var date: String?
        }
        struct GoogleEventDTO: Decodable {
            var id: String?
            var summary: String?
            var description: String?
            var location: String?
            var start: GoogleEventDateDTO?
            var end: GoogleEventDateDTO?
            var status: String?
        }
        struct GoogleEventListDTO: Decodable {
            var items: [GoogleEventDTO]?
            var nextPageToken: String?
        }

        for calendarID in calendarIDs {
            var pageToken: String?
            repeat {
                var path = "/calendars/\(calendarID.urlPathEncoded)/events?singleEvents=true&orderBy=startTime&maxResults=250"
                path += "&timeMin=\(formatter.string(from: start).urlQueryEncoded)"
                path += "&timeMax=\(formatter.string(from: end).urlQueryEncoded)"
                if let pageToken {
                    path += "&pageToken=\(pageToken.urlQueryEncoded)"
                }
                let data = try await apiRequest(path: path)
                let decoded = try JSONDecoder().decode(GoogleEventListDTO.self, from: data)
                for item in decoded.items ?? [] {
                    guard let eventID = item.id, !eventID.isEmpty else { continue }
                    if item.status == "cancelled" { continue }
                    if CalendarSyncService.isCadenceOwnedNotes(item.description) { continue }
                    let title = item.summary ?? ""
                    if title.hasPrefix("Lift ·") || title.hasPrefix("Lunch ·") || title.hasPrefix("Dinner ·") {
                        continue
                    }
                    guard let startDate = Self.parseGoogleDate(dateTime: item.start?.dateTime, dateOnly: item.start?.date) else { continue }
                    let endDate = Self.parseGoogleDate(dateTime: item.end?.dateTime, dateOnly: item.end?.date)
                        ?? startDate.addingTimeInterval(3600)

                    let externalID = "google:\(calendarID):\(eventID)"
                    seenIDs.insert(externalID)
                    let task = existingImported(externalID: externalID, in: context) ?? {
                        let created = PlannerTaskEntity(title: title.isEmpty ? "Event" : title)
                        created.isEvent = true
                        created.importedExternalID = externalID
                        created.importedSourceRaw = "google"
                        context.insert(created)
                        return created
                    }()

                    task.title = title.isEmpty ? "Event" : title
                    task.notes = item.description ?? ""
                    task.location = item.location ?? ""
                    task.dueAt = startDate
                    task.durationMinutes = max(Int(endDate.timeIntervalSince(startDate) / 60), 30)
                    task.isEvent = true
                    upserted += 1
                }
                pageToken = decoded.nextPageToken
            } while pageToken != nil
        }

        try pruneImportedEvents(source: "google", keeping: seenIDs, in: context)
        try context.save()
        return upserted
    }

    private static func parseGoogleDate(dateTime: String?, dateOnly: String?) -> Date? {
        if let dateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = formatter.date(from: dateTime) { return parsed }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateTime)
        }
        if let dateOnly {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateOnly)
        }
        return nil
    }

    private func existingImported(externalID: String, in context: ModelContext) -> PlannerTaskEntity? {
        let all = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        return all.first { $0.importedExternalID == externalID }
    }

    private func pruneImportedEvents(source: String, keeping: Set<String>, in context: ModelContext) throws {
        let all = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        for task in all where task.importedSourceRaw == source {
            if keeping.isEmpty || !keeping.contains(task.importedExternalID) {
                context.delete(task)
            }
        }
    }

    func syncWorkoutProgram() async throws {
        guard PlannerPreferences.syncWorkoutsToGoogleCalendar else { return }
        let calendarIDs = selectedGoogleCalendarIDs()
        guard !calendarIDs.isEmpty else { return }
        for calendarID in calendarIDs {
            for session in WorkoutProgram.sessions {
                let start = WorkoutIntegration.workoutBlockDate(on: dateForWeekday(session.weekday))
                let body = GoogleEventPayload.recurringWorkout(session: session, start: start)
                _ = try await apiRequest(
                    path: "/calendars/\(calendarID.urlPathEncoded)/events",
                    method: "POST",
                    body: body
                )
            }
        }
    }

    func syncMealPlan(_ plan: WeeklyPlan, recipeNames: [String: String]) async throws {
        guard PlannerPreferences.syncMealsToGoogleCalendar else { return }
        let calendarIDs = selectedGoogleCalendarIDs()
        guard !calendarIDs.isEmpty else { return }
        let cal = Calendar.current
        let monday = mondayOfCurrentWeek()
        for calendarID in calendarIDs {
            for dayIndex in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: dayIndex, to: monday) else { continue }
                for slot in [MealSlot.lunch, MealSlot.dinner] {
                    guard let meal = plan.meal(day: dayIndex, slot: slot) else { continue }
                    let hour = slot == .lunch ? PlannerPreferences.lunchReminderHour : PlannerPreferences.dinnerReminderHour
                    var comps = cal.dateComponents([.year, .month, .day], from: day)
                    comps.hour = hour
                    comps.minute = 0
                    guard let start = cal.date(from: comps),
                          let end = cal.date(byAdding: .hour, value: 1, to: start)
                    else { continue }
                    let name = recipeNames[meal.recipeID] ?? "Planned meal"
                    let title = slot == .lunch ? "Lunch · \(name)" : "Dinner · \(name)"
                    let body = GoogleEventPayload.summary(
                        title: title,
                        notes: "Cadence meal plan",
                        start: start,
                        end: end
                    )
                    _ = try await apiRequest(
                        path: "/calendars/\(calendarID.urlPathEncoded)/events",
                        method: "POST",
                        body: body
                    )
                }
            }
        }
    }

    // MARK: - Token + HTTP

    private struct TokenBundle: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiry: Date
    }

    private func exchangeCode(_ code: String, verifier: String) async throws {
        guard let clientID else { throw GoogleCalendarError.notConfigured }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCalendarError.authFailed(String(data: data, encoding: .utf8) ?? "Token exchange failed")
        }
        struct TokenResponse: Decodable {
            var access_token: String
            var refresh_token: String?
            var expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        saveTokens(TokenBundle(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token ?? loadTokens()?.refreshToken,
            expiry: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        ))
    }

    private func validAccessToken() async throws -> String {
        guard var tokens = loadTokens() else { throw GoogleCalendarError.notSignedIn }
        if tokens.expiry.timeIntervalSinceNow > 120 {
            return tokens.accessToken
        }
        guard let refresh = tokens.refreshToken, let clientID else {
            throw GoogleCalendarError.notSignedIn
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCalendarError.authFailed("Refresh failed")
        }
        struct TokenResponse: Decodable {
            var access_token: String
            var expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        tokens.accessToken = decoded.access_token
        tokens.expiry = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        saveTokens(tokens)
        return tokens.accessToken
    }

    @discardableResult
    private func apiRequest(path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        let token = try await validAccessToken()
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3\(path)") else {
            throw GoogleCalendarError.apiFailed("Bad URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 204 { return Data() }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCalendarError.apiFailed(String(data: data, encoding: .utf8) ?? "Request failed")
        }
        return data
    }

    private var redirectScheme: String {
        redirectURI.components(separatedBy: ":").first ?? "com.musclemeal.app"
    }

    private func saveTokens(_ tokens: TokenBundle) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private func loadTokens() -> TokenBundle? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let tokens = try? JSONDecoder().decode(TokenBundle.self, from: data)
        else { return nil }
        return tokens
    }

    private func deleteTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func randomURLSafeString(count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func dateForWeekday(_ weekday: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let delta = weekday - cal.component(.weekday, from: today)
        return cal.date(byAdding: .day, value: delta, to: today) ?? today
    }

    private func mondayOfCurrentWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return cal.date(from: comps) ?? cal.startOfDay(for: .now)
    }
}

extension GoogleCalendarService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

private enum GoogleEventPayload {
    static func summary(title: String, notes: String, start: Date, end: Date) -> [String: Any] {
        [
            "summary": title,
            "description": notes,
            "start": isoDate(start),
            "end": isoDate(end),
        ]
    }

    static func recurringWorkout(session: WorkoutSessionTemplate, start: Date) -> [String: Any] {
        let end = start.addingTimeInterval(3600)
        let weekday = EKWeekdayBridge.googleWeekday(for: session.weekday)
        return [
            "summary": "Lift · \(session.name)",
            "description": session.focus,
            "start": isoDate(start),
            "end": isoDate(end),
            "recurrence": ["RRULE:FREQ=WEEKLY;BYDAY=\(weekday)"],
        ]
    }

    private static func isoDate(_ date: Date) -> [String: String] {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return ["dateTime": f.string(from: date), "timeZone": TimeZone.current.identifier]
    }
}

private enum EKWeekdayBridge {
    static func googleWeekday(for weekday: Int) -> String {
        switch weekday {
        case 1: return "SU"
        case 2: return "MO"
        case 3: return "TU"
        case 4: return "WE"
        case 5: return "TH"
        case 6: return "FR"
        default: return "SA"
        }
    }
}

private extension String {
    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }

    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
