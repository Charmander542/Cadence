import EventKit
import Foundation
import SwiftData

enum CalendarSourceKind: String, Hashable {
    case apple
    case google
    case other

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .other: return "Other"
        }
    }
}

struct CalendarChoice: Identifiable, Hashable {
    var id: String
    var title: String
    var colorHex: String?
    var sourceKind: CalendarSourceKind
}

@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToEvents()
        }
        return try await store.requestAccess(to: .event)
    }

    func availableCalendars() -> [CalendarChoice] {
        store.calendars(for: .event).map { calendar in
            CalendarChoice(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                colorHex: calendar.cgColor?.hexString,
                sourceKind: sourceKind(for: calendar)
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func calendars(for kind: CalendarSourceKind) -> [CalendarChoice] {
        availableCalendars().filter { $0.sourceKind == kind }
    }

    func selectedAppleCalendars() -> [EKCalendar] {
        let ids = PlannerPreferences.appleCalendarIdentifiers
        guard !ids.isEmpty else { return [] }
        return ids.compactMap { store.calendar(withIdentifier: $0) }
    }

    func initializeAppleCalendarSelectionIfNeeded() {
        guard !PlannerPreferences.appleCalendarsSelectionInitialized else { return }
        var selected = Set<String>()
        if let legacy = PlannerPreferences.appleCalendarIdentifier, !legacy.isEmpty {
            selected.insert(legacy)
        } else if let defaultID = store.defaultCalendarForNewEvents?.calendarIdentifier {
            selected.insert(defaultID)
        }
        PlannerPreferences.appleCalendarIdentifiers = selected
        PlannerPreferences.appleCalendarsSelectionInitialized = true
    }

    // MARK: - Task sync

    func upsertTask(_ task: PlannerTaskEntity) throws {
        guard PlannerPreferences.syncTasksToAppleCalendar,
              let dueAt = task.dueAt,
              !task.isCompleted
        else {
            try deleteTask(task)
            return
        }

        let calendars = selectedAppleCalendars()
        guard !calendars.isEmpty else { return }

        var map = task.appleCalendarEventIDs
        let selectedIDs = Set(calendars.map(\.calendarIdentifier))

        for (calendarID, eventID) in map where !selectedIDs.contains(calendarID) {
            if let event = existingEvent(id: eventID) {
                try store.remove(event, span: .thisEvent, commit: false)
            }
            map.removeValue(forKey: calendarID)
        }

        for calendar in calendars {
            let calendarID = calendar.calendarIdentifier
            let event = existingEvent(id: map[calendarID]) ?? EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = task.title
            event.notes = task.notes.isEmpty ? "Cadence task" : task.notes
            event.location = task.location.isEmpty ? nil : task.location
            event.startDate = dueAt
            if task.durationMinutes > 0 {
                event.endDate = dueAt.addingTimeInterval(TimeInterval(task.durationMinutes * 60))
            } else {
                event.endDate = dueAt.addingTimeInterval(3600)
            }
            event.isAllDay = !hasTimeComponent(dueAt)
            event.recurrenceRules = recurrenceRules(for: task)
            try store.save(event, span: .thisEvent, commit: false)
            map[calendarID] = event.eventIdentifier
        }

        try store.commit()
        task.appleCalendarEventIDs = map
    }

    func deleteTask(_ task: PlannerTaskEntity) throws {
        var map = task.appleCalendarEventIDs
        for (_, eventID) in map {
            if let event = existingEvent(id: eventID) {
                try store.remove(event, span: .thisEvent, commit: false)
            }
        }
        if !map.isEmpty {
            try store.commit()
        }
        task.appleCalendarEventIDs = [:]
    }

    // MARK: - Workout sync

    func syncWorkoutProgram() throws {
        guard PlannerPreferences.syncWorkoutsToAppleCalendar else {
            try removeWorkoutProgramEvents()
            return
        }
        let calendars = selectedAppleCalendars()
        guard !calendars.isEmpty else { return }

        try removeWorkoutProgramEvents()

        for calendar in calendars {
            for session in WorkoutProgram.sessions {
                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = "Lift · \(session.name)"
                event.notes = session.focus
                let start = WorkoutIntegration.workoutBlockDate(on: dateForWeekday(session.weekday))
                event.startDate = start
                event.endDate = start.addingTimeInterval(3600)
                event.recurrenceRules = [weeklyRule(weekday: session.weekday)]
                try store.save(event, span: .futureEvents, commit: false)
            }
        }
        try store.commit()
    }

    func removeWorkoutProgramEvents() throws {
        let start = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        let end = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).filter { $0.notes == "Cadence workout" || $0.title.hasPrefix("Lift ·") }
        for event in events {
            try store.remove(event, span: .futureEvents, commit: false)
        }
        try store.commit()
    }

    // MARK: - Meal sync

    func syncMealPlan(_ plan: WeeklyPlan, recipeNames: [String: String]) throws {
        guard PlannerPreferences.syncMealsToAppleCalendar else {
            try removeMealPlanEvents()
            return
        }
        let calendars = selectedAppleCalendars()
        guard !calendars.isEmpty else { return }

        try removeMealPlanEvents()

        let cal = Calendar.current
        let monday = mondayOfCurrentWeek()
        for calendar in calendars {
            for dayIndex in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: dayIndex, to: monday) else { continue }
                for slot in [MealSlot.lunch, MealSlot.dinner] {
                    guard let meal = plan.meal(day: dayIndex, slot: slot) else { continue }
                    let hour = slot == .lunch ? PlannerPreferences.lunchReminderHour : PlannerPreferences.dinnerReminderHour
                    var comps = cal.dateComponents([.year, .month, .day], from: day)
                    comps.hour = hour
                    comps.minute = 0
                    guard let start = cal.date(from: comps) else { continue }

                    let event = EKEvent(eventStore: store)
                    event.calendar = calendar
                    let name = recipeNames[meal.recipeID] ?? "Planned meal"
                    event.title = slot == .lunch ? "Lunch · \(name)" : "Dinner · \(name)"
                    event.notes = "Cadence meal plan"
                    event.startDate = start
                    event.endDate = start.addingTimeInterval(3600)
                    try store.save(event, span: .thisEvent, commit: false)
                }
            }
        }
        try store.commit()
    }

    func removeMealPlanEvents() throws {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let end = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).filter {
            $0.notes == "Cadence meal plan" || $0.title.hasPrefix("Lunch ·") || $0.title.hasPrefix("Dinner ·")
        }
        for event in events {
            try store.remove(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    // MARK: - Helpers

    private func existingEvent(id: String?) -> EKEvent? {
        guard let id else { return nil }
        return store.event(withIdentifier: id)
    }

    private func sourceKind(for calendar: EKCalendar) -> CalendarSourceKind {
        let sourceTitle = calendar.source.title.lowercased()
        if sourceTitle.contains("google") { return .google }
        switch calendar.source.sourceType {
        case .local, .exchange, .subscribed, .birthdays:
            return .apple
        case .calDAV:
            return sourceTitle.contains("icloud") ? .apple : .other
        @unknown default:
            return .other
        }
    }

    private func weeklyRule(weekday: Int) -> EKRecurrenceRule {
        let ekWeekday = EKWeekday(rawValue: weekday) ?? .monday
        return EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(ekWeekday)],
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )
    }

    private func dateForWeekday(_ weekday: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let todayWeekday = cal.component(.weekday, from: today)
        let delta = weekday - todayWeekday
        return cal.date(byAdding: .day, value: delta, to: today) ?? today
    }

    private func mondayOfCurrentWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return cal.date(from: comps) ?? cal.startOfDay(for: .now)
    }

    private func recurrenceRules(for task: PlannerTaskEntity) -> [EKRecurrenceRule]? {
        switch task.recurrence {
        case .none:
            return nil
        case .daily:
            return [EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)]
        case .weekly:
            return [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)]
        case .customWeekly:
            let days = (1...7).compactMap { weekday -> EKRecurrenceDayOfWeek? in
                guard RecurrenceWeekdayMask.contains(weekday, in: task.recurrenceWeekdayMask) else { return nil }
                return EKRecurrenceDayOfWeek(EKWeekday(rawValue: weekday) ?? .monday)
            }
            guard !days.isEmpty else { return nil }
            return [EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: days,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )]
        case .monthly:
            return [EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)]
        case .yearly:
            return [EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)]
        }
    }

    private func hasTimeComponent(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
    }
}

private extension CGColor {
    var hexString: String? {
        guard let components = components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
