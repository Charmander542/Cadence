import Foundation

enum NewsAIService {
    struct ArticlePayload: Codable {
        let id: String
        let title: String
        let source: String
        let topic: String
        let snippet: String
    }

    struct BriefItem: Codable {
        let id: String
        let brief: String
        let why_it_matters: String
    }

    struct BriefResponse: Codable {
        let day_headline: String
        let day_blurb: String
        let items: [BriefItem]
    }

    static let systemPrompt = """
    You write a daily news digest that is easy to read in under a minute per story.
    Mix curiosity and clarity — no hype, no conspiracy, no medical/financial advice.
    Return ONLY JSON:
    {
      "day_headline": "short day title",
      "day_blurb": "1-2 sentence overview of the slate",
      "items": [
        {
          "id": "same id as input",
          "brief": "2-3 plain sentences, concrete and scannable",
          "why_it_matters": "one short sentence"
        }
      ]
    }
    Keep each brief under 70 words. Preserve factual caution when the snippet is thin.
    """

    static func summarizeDigest(
        client: LLMClient,
        articles: [ArticlePayload]
    ) async throws -> BriefResponse {
        let user = try String(data: JSONEncoder().encode(articles), encoding: .utf8) ?? "[]"
        let text = try await client.completeJSON(
            system: systemPrompt,
            user: "Summarize these \(articles.count) stories for a daily briefing JSON:\n\(user)",
            maxTokens: 2500,
            model: KeychainStore.selectedProvider.fastModel
        )
        guard let data = text.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return try JSONDecoder().decode(BriefResponse.self, from: data)
    }
}
