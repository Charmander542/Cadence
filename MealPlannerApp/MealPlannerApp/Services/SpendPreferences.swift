import Foundation

enum SpendPreferences {
    private static let enabledKey = "spend_subapp_enabled"
    private static let clientIDKey = "plaid_client_id"
    private static let environmentKey = "plaid_environment"
    private static let redirectURIKey = "plaid_redirect_uri"
    private static let demoSeededKey = "spend_demo_seeded_v9"
    private static let clientUserIDKey = "plaid_client_user_id"
    private static let iCloudKeychainSyncKey = "plaid_icloud_keychain_sync"

    /// Prefill only — not a secret. Secret stays in Keychain / PlaidLocal.plist.
    static let defaultClientID = "6aa4147dd8c4dd000dcfc579"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            NotificationCenter.default.post(name: CadenceAppsPreferences.didChange, object: nil)
        }
    }

    /// Plaid `client_id`. Prefer Info.plist `PlaidClientID`, then UserDefaults, then bundled default.
    static var clientID: String {
        get {
            if let plist = Bundle.main.object(forInfoDictionaryKey: "PlaidClientID") as? String,
               !plist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !plist.contains("YOUR_") {
                return plist
            }
            let stored = UserDefaults.standard.string(forKey: clientIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !stored.isEmpty { return stored }
            return defaultClientID
        }
        set { UserDefaults.standard.set(newValue, forKey: clientIDKey) }
    }

    enum PlaidEnvironment: String, CaseIterable, Identifiable {
        case sandbox
        case production

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var apiHost: String {
            switch self {
            case .sandbox: return "https://sandbox.plaid.com"
            case .production: return "https://production.plaid.com"
            }
        }
    }

    static var environment: PlaidEnvironment {
        get {
            let raw = UserDefaults.standard.string(forKey: environmentKey) ?? PlaidEnvironment.production.rawValue
            return PlaidEnvironment(rawValue: raw) ?? .production
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: environmentKey) }
    }

    /// Universal Link registered in the Plaid Dashboard (required for many OAuth banks).
    static var redirectURI: String {
        get { UserDefaults.standard.string(forKey: redirectURIKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: redirectURIKey) }
    }

    /// Stable per-install user id for `/link/token/create`.
    static var clientUserID: String {
        if let existing = UserDefaults.standard.string(forKey: clientUserIDKey), !existing.isEmpty {
            return existing
        }
        let id = "cadence-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(id, forKey: clientUserIDKey)
        return id
    }

    static var hasDemoSeed: Bool {
        get { UserDefaults.standard.bool(forKey: demoSeededKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoSeededKey) }
    }

    /// When on (default), Plaid secret + Item tokens sync via **iCloud Keychain** so
    /// delete/reinstall (same Apple ID + iCloud Keychain) can restore connections.
    static var plaidICloudKeychainSync: Bool {
        get {
            if UserDefaults.standard.object(forKey: iCloudKeychainSyncKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: iCloudKeychainSyncKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: iCloudKeychainSyncKey) }
    }

    static var isConfigured: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(KeychainStore.loadPlaidSecret()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Loads gitignored `PlaidLocal.plist` once into prefs/Keychain (local only).
    static func ingestLocalSecretsIfNeeded() {
        guard let url = Bundle.main.url(forResource: "PlaidLocal", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return }

        if let id = dict["client_id"] as? String,
           !id.isEmpty,
           !id.contains("YOUR_") {
            clientID = id
        }
        if let secret = dict["secret"] as? String,
           !secret.isEmpty,
           !secret.contains("YOUR_"),
           (KeychainStore.loadPlaidSecret() ?? "").isEmpty {
            try? KeychainStore.savePlaidSecret(secret)
        }
        if let env = dict["environment"] as? String,
           let parsed = PlaidEnvironment(rawValue: env.lowercased()) {
            environment = parsed
        }
        if let redirect = dict["redirect_uri"] as? String {
            redirectURI = redirect
        }
    }
}
