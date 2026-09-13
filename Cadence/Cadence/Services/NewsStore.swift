import Foundation
import SwiftData

@MainActor
enum NewsStore {
    static let dailyLimit = 10

    static func seedDemoIfNeeded(in context: ModelContext) {
        guard !NewsPreferences.hasDemoSeed else { return }
        let day = Calendar.current.startOfDay(for: Date())
        var descriptor = FetchDescriptor<NewsArticleEntity>(
            predicate: #Predicate { $0.dayStart == day }
        )
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.isEmpty == false {
            NewsPreferences.hasDemoSeed = true
            return
        }
        upsert(demoArticles(for: day), day: day, in: context)
        // Attach readable demo briefs so the UI shows digests without an AI key.
        let rows = ((try? context.fetch(FetchDescriptor<NewsArticleEntity>())) ?? [])
            .filter { Calendar.current.isDate($0.dayStart, inSameDayAs: day) }
        for row in rows {
            if row.aiBrief.isEmpty {
                row.aiBrief = row.rawSummary
                row.whyItMatters = "Demo copy — refresh with an AI key for tighter digests."
            }
        }
        try? context.save()
        upsertBriefing(
            day: day,
            headline: "Ten stories worth your attention",
            blurb: "A Cadence demo slate spanning world, science, tech, markets, and culture — refresh to pull live RSS + optional AI briefs.",
            count: dailyLimit,
            usedAI: false,
            in: context
        )
        NewsPreferences.hasDemoSeed = true
    }

    static func upsert(_ dtos: [NewsArticleDTO], day: Date, in context: ModelContext) {
        let start = Calendar.current.startOfDay(for: day)
        let existing = (try? context.fetch(FetchDescriptor<NewsArticleEntity>())) ?? []
        let todayRows = existing.filter { Calendar.current.isDate($0.dayStart, inSameDayAs: start) }
        for row in todayRows {
            context.delete(row)
        }
        for (index, dto) in dtos.prefix(dailyLimit).enumerated() {
            let row = NewsArticleEntity(
                remoteID: dto.id,
                title: dto.title,
                rawSummary: dto.summary,
                sourceName: dto.sourceName,
                urlString: dto.url,
                imageURLString: dto.imageURL ?? "",
                publishedAt: dto.publishedAt,
                topic: dto.topic,
                sortOrder: index,
                dayStart: start
            )
            context.insert(row)
        }
        try? context.save()
        NewsPreferences.lastSyncAt = Date()
    }

    static func upsertBriefing(
        day: Date,
        headline: String,
        blurb: String,
        count: Int,
        usedAI: Bool,
        in context: ModelContext
    ) {
        let start = Calendar.current.startOfDay(for: day)
        let existing = ((try? context.fetch(FetchDescriptor<NewsBriefingEntity>())) ?? [])
            .first { Calendar.current.isDate($0.dayStart, inSameDayAs: start) }
        let row = existing ?? {
            let created = NewsBriefingEntity(dayStart: start)
            context.insert(created)
            return created
        }()
        row.headline = headline
        row.blurb = blurb
        row.articleCount = count
        row.usedAI = usedAI
        row.updatedAt = Date()
        try? context.save()
    }

    static func applyAIBriefs(
        _ response: NewsAIService.BriefResponse,
        day: Date,
        in context: ModelContext
    ) {
        let start = Calendar.current.startOfDay(for: day)
        let articles = ((try? context.fetch(FetchDescriptor<NewsArticleEntity>())) ?? [])
            .filter { Calendar.current.isDate($0.dayStart, inSameDayAs: start) }
        let byID = Dictionary(uniqueKeysWithValues: articles.map { ($0.remoteID, $0) })
        for item in response.items {
            guard let row = byID[item.id] else { continue }
            row.aiBrief = item.brief
            row.whyItMatters = item.why_it_matters
        }
        upsertBriefing(
            day: day,
            headline: response.day_headline,
            blurb: response.day_blurb,
            count: articles.count,
            usedAI: true,
            in: context
        )
    }

    static func refresh(
        llm: LLMClient,
        in context: ModelContext,
        day: Date = Date()
    ) async throws {
        let client = NewsClient()
        let dtos = try await client.fetchDailyDigest(limit: dailyLimit)
        upsert(dtos, day: day, in: context)
        upsertBriefing(
            day: day,
            headline: "Today’s \(dtos.count) headlines",
            blurb: "Pulled from public feeds across world, science, tech, business, and culture.",
            count: dtos.count,
            usedAI: false,
            in: context
        )

        guard NewsPreferences.autoSummarizeWithAI, NewsPreferences.hasAIKey else { return }
        let payload = dtos.map {
            NewsAIService.ArticlePayload(
                id: $0.id,
                title: $0.title,
                source: $0.sourceName,
                topic: $0.topic.title,
                snippet: $0.summary
            )
        }
        let briefs = try await NewsAIService.summarizeDigest(client: llm, articles: payload)
        applyAIBriefs(briefs, day: day, in: context)
    }

    static func demoArticles(for day: Date) -> [NewsArticleDTO] {
        let samples: [(String, String, NewsTopic, String, String)] = [
            ("Global talks seek ceasefire framework as aid corridors reopen", "Diplomats outline a phased pause while agencies race to expand humanitarian routes.", .world, "World Desk", "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=1200"),
            ("New climate model ties ocean heat to sharper monsoon swings", "Researchers say warmer seas may intensify wet-dry extremes across South Asia this decade.", .science, "Science Wire", "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1200"),
            ("Chipmakers race to ship on-device AI kits for phones", "A fresh silicon stack promises faster local models without cloud round-trips.", .tech, "Tech Ledger", "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1200"),
            ("Central banks hold rates as inflation cools unevenly", "Markets digest a patient stance while housing and services stay sticky.", .business, "Markets", "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=1200"),
            ("Archaeologists map a lost harbor using underwater lidar", "Point clouds reveal docks buried for centuries beneath silt.", .science, "Field Notes", "https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200"),
            ("Cities trial quiet night deliveries with electric fleets", "Pilot programs cut noise complaints while keeping shelves stocked.", .world, "Metro", "https://images.unsplash.com/photo-1494412574643-ff11b0a5c1c3?w=1200"),
            ("Studio collective releases an open score for community orchestras", "Free sheet music aims to lower the barrier for local performances.", .culture, "Arts", "https://images.unsplash.com/photo-1514320291840-b9a56ab6d6bb?w=1200"),
            ("Wearable study links sleep regularity to sharper next-day focus", "Consistency beat total hours in a large consumer cohort.", .health, "Body & Mind", "https://images.unsplash.com/photo-1515377905703-c4788e51af15?w=1200"),
            ("Startups turn food waste into low-carbon packaging foam", "Mycelium panels match polystyrene cushioning in early lab tests.", .tech, "Climate Tech", "https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200"),
            ("Documentary festival puts citizen journalists on the main stage", "Editors highlight verification tools that travel with phone footage.", .culture, "Media", "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=1200"),
        ]
        return samples.enumerated().map { index, item in
            NewsArticleDTO(
                id: "demo-\(index)",
                title: item.0,
                summary: item.1,
                sourceName: item.3,
                url: "https://example.com/news/\(index)",
                imageURL: item.4,
                publishedAt: Calendar.current.date(byAdding: .hour, value: -index * 2, to: Date()) ?? Date(),
                topic: item.2
            )
        }
    }
}
