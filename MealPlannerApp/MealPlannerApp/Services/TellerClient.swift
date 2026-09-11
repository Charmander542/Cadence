import Foundation
import Security

/// Thin Teller API surface for Spend.
///
/// **Security:** Never ship your Teller mTLS private key inside the iOS app.
/// Sandbox can call `https://api.teller.io` with Basic auth (`accessToken:`).
/// Development/production must proxy through your backend (cert stays on server).
///
/// Setup checklist: `docs/TELLER_SETUP.md`.
actor TellerClient {
    struct AccountDTO: Decodable, Identifiable, Sendable {
        let id: String
        let name: String?
        let type: String?
        let subtype: String?
        let last_four: String?
        let institution: Institution?

        struct Institution: Decodable, Sendable {
            let name: String?
        }
    }

    struct TransactionDTO: Decodable, Identifiable, Sendable {
        let id: String
        let account_id: String?
        let amount: String
        let date: String
        let description: String?
        let details: Details?
        let type: String?
        let status: String?

        struct Details: Decodable, Sendable {
            let category: String?
            let processing_status: String?
            let counterparty: Counterparty?
        }

        struct Counterparty: Decodable, Sendable {
            let name: String?
            let type: String?
        }

        var amountValue: Double {
            Double(amount) ?? 0
        }

        var merchantName: String {
            details?.counterparty?.name
                ?? description
                ?? "Unknown"
        }
    }

    enum TellerError: LocalizedError {
        case missingAccessToken
        case missingApplicationID
        case http(Int, String)
        case decoding
        case notImplemented(String)

        var errorDescription: String? {
            switch self {
            case .missingAccessToken: return "Connect a bank account first."
            case .missingApplicationID: return "Add your Teller Application ID in Settings → Spend."
            case .http(let code, let body): return "Teller HTTP \(code): \(body)"
            case .decoding: return "Could not read Teller response."
            case .notImplemented(let msg): return msg
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sandbox-only direct fetch. For development/production use `fetchViaBackend`.
    func fetchAccounts(accessToken: String) async throws -> [AccountDTO] {
        try await get(path: "/accounts", accessToken: accessToken)
    }

    func fetchTransactions(accessToken: String, accountID: String) async throws -> [TransactionDTO] {
        try await get(path: "/accounts/\(accountID)/transactions", accessToken: accessToken)
    }

    /// Placeholder for your server that holds the Teller client certificate.
    func fetchViaBackend(baseURL: URL, userSession: String) async throws -> [TransactionDTO] {
        throw TellerError.notImplemented(
            "Point Spend at your backend (mTLS + access token). See docs/TELLER_SETUP.md."
        )
    }

    private func get<T: Decodable>(path: String, accessToken: String) async throws -> T {
        guard !accessToken.isEmpty else { throw TellerError.missingAccessToken }
        var request = URLRequest(url: URL(string: "https://api.teller.io\(path)")!)
        request.httpMethod = "GET"
        let basic = Data("\(accessToken):".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TellerError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TellerError.http(http.statusCode, body)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TellerError.decoding
        }
    }
}

// MARK: - Keychain helpers for enrollment tokens

extension KeychainStore {
    private static let tellerTokenPrefix = "teller_access_"

    static func saveTellerAccessToken(_ token: String, enrollmentID: String) {
        let account = tellerTokenPrefix + enrollmentID
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func tellerAccessToken(enrollmentID: String) -> String? {
        let account = tellerTokenPrefix + enrollmentID
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteTellerAccessToken(enrollmentID: String) {
        let account = tellerTokenPrefix + enrollmentID
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
