import Foundation
import Security

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic
    case openai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "ChatGPT (OpenAI)"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-…"
        case .openai: return "sk-…"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-sonnet-4-20250514"
        // Cheapest OpenAI chat model for structured JSON prompts (~$0.15/$0.60 per 1M tokens).
        case .openai: return "gpt-4o-mini"
        }
    }

    /// Faster/cheaper model for structured shop-list JSON.
    var fastModel: String {
        switch self {
        case .anthropic: return "claude-3-5-haiku-20241022"
        case .openai: return "gpt-4o-mini"
        }
    }
}

enum KeychainStore {
    private static let service = "com.musclemeal.app"
    private static let providerDefaultsKey = "ai_provider"

    private static func account(for provider: AIProvider) -> String {
        switch provider {
        case .anthropic: return "anthropic_api_key"
        case .openai: return "openai_api_key"
        }
    }

    static var selectedProvider: AIProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: providerDefaultsKey) ?? AIProvider.anthropic.rawValue
            return AIProvider(rawValue: raw) ?? .anthropic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerDefaultsKey)
        }
    }

    static func saveAPIKey(_ key: String, for provider: AIProvider) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
        ]
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func loadAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Migrate legacy single-key account if present.
    static func migrateLegacyAnthropicKeyIfNeeded() {
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "anthropic_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        // Already using the anthropic account name — no rename needed.
        // Older builds only had one key; nothing else to migrate.
        _ = legacyQuery
    }

    enum KeychainError: Error {
        case unhandled(OSStatus)
    }
}
