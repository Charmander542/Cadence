import Foundation

/// Unified LLM client for Anthropic (Claude) and OpenAI (ChatGPT).
/// API keys come from Keychain — never hardcoded.
actor LLMClient {
    private let session: URLSession
    private let anthropicModel: String
    private let openAIModel: String

    init(
        anthropicModel: String = AIProvider.anthropic.defaultModel,
        openAIModel: String = AIProvider.openai.defaultModel,
        session: URLSession = .shared
    ) {
        self.anthropicModel = anthropicModel
        self.openAIModel = openAIModel
        self.session = session
    }

    func completeJSON(
        system: String,
        user: String,
        maxTokens: Int = 4096,
        model: String? = nil
    ) async throws -> String {
        let provider = KeychainStore.selectedProvider
        switch provider {
        case .anthropic:
            return try await completeAnthropic(
                system: system,
                user: user,
                maxTokens: maxTokens,
                model: model ?? anthropicModel
            )
        case .openai:
            return try await completeOpenAI(
                system: system,
                user: user,
                maxTokens: maxTokens,
                model: model ?? openAIModel
            )
        }
    }

    // MARK: - Anthropic

    private struct AnthropicRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [RoleMessage]
    }

    private struct RoleMessage: Encodable {
        let role: String
        let content: String
    }

    private struct AnthropicResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
        let content: [ContentBlock]
    }

    private func completeAnthropic(
        system: String,
        user: String,
        maxTokens: Int,
        model: String
    ) async throws -> String {
        guard let apiKey = KeychainStore.loadAPIKey(for: .anthropic),
              !apiKey.isEmpty,
              !apiKey.contains("YOUR_") else {
            throw LLMError.missingAPIKey(.anthropic)
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = AnthropicRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [RoleMessage(role: "user", content: user)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(.anthropic, http.statusCode, text)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.compactMap(\.text).joined()
        return Self.stripCodeFences(text)
    }

    // MARK: - OpenAI

    private struct OpenAIRequest: Encodable {
        let model: String
        let max_tokens: Int
        let temperature: Double
        let messages: [RoleMessage]
    }

    private struct OpenAIResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    private func completeOpenAI(
        system: String,
        user: String,
        maxTokens: Int,
        model: String
    ) async throws -> String {
        guard let apiKey = KeychainStore.loadAPIKey(for: .openai),
              !apiKey.isEmpty,
              !apiKey.contains("YOUR_") else {
            throw LLMError.missingAPIKey(.openai)
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Decision: ask for JSON in the system prompt rather than response_format,
        // so both object and array payloads from our prompts remain valid.
        let systemWithJSON = system + "\n\nRespond with valid JSON only — no markdown fences."
        let body = OpenAIRequest(
            model: model,
            max_tokens: maxTokens,
            temperature: 0.2,
            messages: [
                RoleMessage(role: "system", content: systemWithJSON),
                RoleMessage(role: "user", content: user),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(.openai, http.statusCode, text)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let text = decoded.choices.first?.message.content ?? ""
        return Self.stripCodeFences(text)
    }

    static func stripCodeFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*```$", with: "", options: .regularExpression)
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum LLMError: LocalizedError {
        case missingAPIKey(AIProvider)
        case badResponse
        case http(AIProvider, Int, String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey(let provider):
                return "Add your \(provider.title) API key in Settings (stored in Keychain)."
            case .badResponse:
                return "Unexpected response from the AI provider."
            case .http(let provider, let code, let body):
                return "\(provider.title) HTTP \(code): \(body.prefix(240))"
            }
        }
    }
}
