import Foundation
import Security

/// Plaid API surface for Spend (link tokens, Item exchange, transactions sync).
///
/// **Security:** Keep `secret` in Keychain (or a gitignored `PlaidLocal.plist`).
/// Never commit secrets. Prefer a tiny backend later if Cadence ships to App Store.
///
/// Setup: `docs/PLAID_SETUP.md`.
actor PlaidClient {
    struct AccountDTO: Decodable, Identifiable, Sendable {
        let account_id: String
        let name: String?
        let official_name: String?
        let mask: String?
        let type: String?
        let subtype: String?

        var id: String { account_id }

        var displayName: String {
            let base = name ?? official_name ?? "Account"
            if let mask, !mask.isEmpty { return "\(base) ••\(mask)" }
            return base
        }
    }

    struct AccountsResponse: Decodable, Sendable {
        let accounts: [AccountDTO]
        let item: ItemMeta?

        struct ItemMeta: Decodable, Sendable {
            let item_id: String?
            let institution_id: String?
        }
    }

    struct InstitutionResponse: Decodable, Sendable {
        let institution: Institution?

        struct Institution: Decodable, Sendable {
            let institution_id: String?
            let name: String?
        }
    }

    struct TransactionDTO: Decodable, Identifiable, Sendable {
        let transaction_id: String
        let account_id: String?
        let amount: Double
        let date: String
        let name: String?
        let merchant_name: String?
        let pending: Bool?
        let personal_finance_category: PFC?
        let category: [String]?

        struct PFC: Decodable, Sendable {
            let primary: String?
            let detailed: String?
        }

        var id: String { transaction_id }

        var merchantName: String {
            merchant_name ?? name ?? "Unknown"
        }

        var categoryLabel: String? {
            personal_finance_category?.detailed
                ?? personal_finance_category?.primary
                ?? category?.first
        }
    }

    struct SyncResponse: Decodable, Sendable {
        let added: [TransactionDTO]
        let modified: [TransactionDTO]
        let removed: [Removed]
        let next_cursor: String
        let has_more: Bool

        struct Removed: Decodable, Sendable {
            let transaction_id: String?
        }
    }

    struct LinkTokenResponse: Decodable, Sendable {
        let link_token: String
        let expiration: String?
    }

    struct PublicTokenExchangeResponse: Decodable, Sendable {
        let access_token: String
        let item_id: String
    }

    struct SandboxPublicTokenResponse: Decodable, Sendable {
        let public_token: String
    }

    enum PlaidError: LocalizedError {
        case missingCredentials
        case http(Int, String)
        case decoding
        case emptyLinkToken

        var errorDescription: String? {
            switch self {
            case .missingCredentials:
                return "Add your Plaid client ID and secret in Settings → Spend."
            case .http(let code, let body):
                return "Plaid HTTP \(code): \(body)"
            case .decoding:
                return "Could not read Plaid response."
            case .emptyLinkToken:
                return "Plaid did not return a link token."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func createLinkToken(
        clientID: String,
        secret: String,
        environment: SpendPreferences.PlaidEnvironment,
        clientUserID: String,
        redirectURI: String?
    ) async throws -> String {
        var body: [String: Any] = [
            "client_id": clientID,
            "secret": secret,
            "client_name": "Cadence",
            "language": "en",
            "country_codes": ["US"],
            "user": ["client_user_id": clientUserID],
            "products": ["transactions"],
            "transactions": ["days_requested": 90],
        ]
        if let redirectURI, !redirectURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["redirect_uri"] = redirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let response: LinkTokenResponse = try await post(
            path: "/link/token/create",
            environment: environment,
            json: body
        )
        guard !response.link_token.isEmpty else { throw PlaidError.emptyLinkToken }
        return response.link_token
    }

    func exchangePublicToken(
        clientID: String,
        secret: String,
        environment: SpendPreferences.PlaidEnvironment,
        publicToken: String
    ) async throws -> PublicTokenExchangeResponse {
        try await post(
            path: "/item/public_token/exchange",
            environment: environment,
            json: [
                "client_id": clientID,
                "secret": secret,
                "public_token": publicToken,
            ]
        )
    }

    func fetchAccounts(
        clientID: String,
        secret: String,
        environment: SpendPreferences.PlaidEnvironment,
        accessToken: String
    ) async throws -> AccountsResponse {
        try await post(
            path: "/accounts/get",
            environment: environment,
            json: [
                "client_id": clientID,
                "secret": secret,
                "access_token": accessToken,
            ]
        )
    }

    func fetchInstitutionName(
        clientID: String,
        secret: String,
        environment: SpendPreferences.PlaidEnvironment,
        institutionID: String
    ) async throws -> String? {
        let response: InstitutionResponse = try await post(
            path: "/institutions/get_by_id",
            environment: environment,
            json: [
                "client_id": clientID,
                "secret": secret,
                "institution_id": institutionID,
                "country_codes": ["US"],
            ]
        )
        return response.institution?.name
    }

    /// Pulls all available pages from `/transactions/sync`.
    func syncAllTransactions(
        clientID: String,
        secret: String,
        environment: SpendPreferences.PlaidEnvironment,
        accessToken: String,
        cursor: String
    ) async throws -> (added: [TransactionDTO], modified: [TransactionDTO], removedIDs: [String], nextCursor: String) {
        var cursor = cursor
        var added: [TransactionDTO] = []
        var modified: [TransactionDTO] = []
        var removed: [String] = []
        var guardPages = 0

        while true {
            guardPages += 1
            if guardPages > 40 { break }
            var body: [String: Any] = [
                "client_id": clientID,
                "secret": secret,
                "access_token": accessToken,
                "count": 500,
            ]
            if !cursor.isEmpty {
                body["cursor"] = cursor
            }
            let page: SyncResponse = try await post(
                path: "/transactions/sync",
                environment: environment,
                json: body
            )
            added.append(contentsOf: page.added)
            modified.append(contentsOf: page.modified)
            removed.append(contentsOf: page.removed.compactMap(\.transaction_id))
            cursor = page.next_cursor
            if !page.has_more { break }
        }
        return (added, modified, removed, cursor)
    }

    /// Instant sandbox Item without Link UI (First Platypus Bank).
    func createSandboxPublicToken(
        clientID: String,
        secret: String
    ) async throws -> String {
        let response: SandboxPublicTokenResponse = try await post(
            path: "/sandbox/public_token/create",
            environment: .sandbox,
            json: [
                "client_id": clientID,
                "secret": secret,
                "institution_id": "ins_109508",
                "initial_products": ["transactions"],
                "options": [
                    "override_username": "user_good",
                    "override_password": "pass_good",
                ],
            ]
        )
        return response.public_token
    }

    private func post<T: Decodable>(
        path: String,
        environment: SpendPreferences.PlaidEnvironment,
        json: [String: Any]
    ) async throws -> T {
        guard let url = URL(string: environment.apiHost + path) else { throw PlaidError.decoding }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlaidError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PlaidError.http(http.statusCode, body)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PlaidError.decoding
        }
    }
}

// MARK: - Keychain (secret + Item access tokens + sync cursors)

extension KeychainStore {
    private static let plaidSecretAccount = "plaid_secret"
    private static let plaidAccessPrefix = "plaid_access_"
    private static let plaidCursorPrefix = "plaid_cursor_"

    static func savePlaidSecret(_ secret: String) throws {
        try saveGeneric(account: plaidSecretAccount, value: secret)
    }

    static func loadPlaidSecret() -> String? {
        loadGeneric(account: plaidSecretAccount)
    }

    static func deletePlaidSecret() {
        deleteGeneric(account: plaidSecretAccount)
    }

    static func savePlaidAccessToken(_ token: String, itemID: String) {
        saveGenericBestEffort(account: plaidAccessPrefix + itemID, value: token)
    }

    static func plaidAccessToken(itemID: String) -> String? {
        loadGeneric(account: plaidAccessPrefix + itemID)
    }

    static func deletePlaidAccessToken(itemID: String) {
        deleteGeneric(account: plaidAccessPrefix + itemID)
        deleteGeneric(account: plaidCursorPrefix + itemID)
    }

    static func savePlaidSyncCursor(_ cursor: String, itemID: String) {
        saveGenericBestEffort(account: plaidCursorPrefix + itemID, value: cursor)
    }

    static func plaidSyncCursor(itemID: String) -> String {
        loadGeneric(account: plaidCursorPrefix + itemID) ?? ""
    }

    private static func saveGeneric(account: String, value: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    private static func saveGenericBestEffort(account: String, value: String) {
        try? saveGeneric(account: account, value: value)
    }

    private static func loadGeneric(account: String) -> String? {
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

    private static func deleteGeneric(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.musclemeal.app",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
