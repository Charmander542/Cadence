import Foundation

enum NewsPreferences {
    private static let enabledKey = "news_subapp_enabled"
    private static let demoKey = "news_demo_seeded"
    private static let lastSyncKey = "news_last_sync"
    private static let autoSummarizeKey = "news_auto_summarize"

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

    static var hasDemoSeed: Bool {
        get { UserDefaults.standard.bool(forKey: demoKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoKey) }
    }

    static var lastSyncAt: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncKey) }
    }

    /// When an AI key exists, rewrite briefs after fetch.
    static var autoSummarizeWithAI: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoSummarizeKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoSummarizeKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoSummarizeKey) }
    }

    static var hasAIKey: Bool {
        let provider = KeychainStore.selectedProvider
        guard let key = KeychainStore.loadAPIKey(for: provider),
              !key.isEmpty,
              !key.contains("YOUR_") else { return false }
        return true
    }
}
