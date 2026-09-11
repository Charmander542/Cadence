import Foundation

enum SpendPreferences {
    private static let enabledKey = "spend_subapp_enabled"
    private static let appIDKey = "teller_application_id"
    private static let environmentKey = "teller_environment"
    private static let demoSeededKey = "spend_demo_seeded"

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

    /// Teller Connect `applicationId`. Prefer Info.plist `TellerApplicationID` in release builds.
    static var applicationID: String {
        get {
            if let plist = Bundle.main.object(forInfoDictionaryKey: "TellerApplicationID") as? String,
               !plist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !plist.contains("YOUR_") {
                return plist
            }
            return UserDefaults.standard.string(forKey: appIDKey) ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: appIDKey) }
    }

    enum TellerEnvironment: String, CaseIterable, Identifiable {
        case sandbox, development, production
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    static var environment: TellerEnvironment {
        get {
            let raw = UserDefaults.standard.string(forKey: environmentKey) ?? TellerEnvironment.sandbox.rawValue
            return TellerEnvironment(rawValue: raw) ?? .sandbox
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: environmentKey) }
    }

    static var hasDemoSeed: Bool {
        get { UserDefaults.standard.bool(forKey: demoSeededKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoSeededKey) }
    }

    static var isConfigured: Bool {
        !applicationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
