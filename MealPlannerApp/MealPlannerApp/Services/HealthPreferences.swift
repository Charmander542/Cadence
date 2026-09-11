import Foundation

enum HealthPreferences {
    private static let enabledKey = "health_subapp_enabled"
    private static let authorizedKey = "healthkit_authorized"
    private static let useDemoKey = "health_use_demo_when_empty"
    private static let lastSyncKey = "health_last_sync"
    private static let sleepGoalKey = "health_sleep_goal_hours"

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

    /// User completed (or skipped) an authorization attempt.
    static var didRequestAuthorization: Bool {
        get { UserDefaults.standard.bool(forKey: authorizedKey) }
        set { UserDefaults.standard.set(newValue, forKey: authorizedKey) }
    }

    static var preferDemoFallback: Bool {
        get {
            if UserDefaults.standard.object(forKey: useDemoKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: useDemoKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: useDemoKey) }
    }

    static var lastSyncAt: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    /// Sleep goal used by Bevel-style sleep duration scoring (hours).
    static var sleepGoalHours: Double {
        get {
            let v = UserDefaults.standard.double(forKey: sleepGoalKey)
            return v > 0 ? v : 8
        }
        set { UserDefaults.standard.set(newValue, forKey: sleepGoalKey) }
    }
}
