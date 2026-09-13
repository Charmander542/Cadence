import Foundation

enum FocusPreferences {
    private static let enabledKey = "focus_subapp_enabled"
    private static let pomoMinutesKey = "focus_pomo_minutes"
    private static let labelKey = "focus_default_label"
    private static let lockAppsKey = "focus_lock_apps_during_session"

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

    /// Default Pomodoro length in minutes (5-minute steps; common default 25).
    static var pomoMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: pomoMinutesKey)
            let raw = stored > 0 ? stored : 25
            return snapMinutes(raw)
        }
        set {
            UserDefaults.standard.set(snapMinutes(newValue), forKey: pomoMinutesKey)
        }
    }

    /// When true, Screen Time shields other apps while a Focus session is running.
    static var lockAppsDuringSession: Bool {
        get { UserDefaults.standard.bool(forKey: lockAppsKey) }
        set { UserDefaults.standard.set(newValue, forKey: lockAppsKey) }
    }

    /// Clamp to 5…90 and round to the nearest 5-minute step.
    static func snapMinutes(_ minutes: Int) -> Int {
        let clamped = min(max(minutes, 5), 90)
        let snapped = Int((Double(clamped) / 5.0).rounded()) * 5
        return min(max(snapped, 5), 90)
    }

    static var defaultLabel: String {
        get {
            let value = UserDefaults.standard.string(forKey: labelKey) ?? "Focus"
            return value.isEmpty ? "Focus" : value
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: labelKey)
        }
    }
}
