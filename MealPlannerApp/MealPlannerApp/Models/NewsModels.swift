import Foundation
import SwiftData
import SwiftUI

enum NewsTopic: String, CaseIterable, Identifiable, Codable {
    case world, science, tech, business, culture, health, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .world: return "World"
        case .science: return "Science"
        case .tech: return "Tech"
        case .business: return "Business"
        case .culture: return "Culture"
        case .health: return "Health"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .world: return "globe.americas.fill"
        case .science: return "atom"
        case .tech: return "cpu"
        case .business: return "chart.line.uptrend.xyaxis"
        case .culture: return "theatermasks"
        case .health: return "heart.text.square"
        case .other: return "newspaper"
        }
    }

    static func infer(from title: String, source: String, feedHint: String?) -> NewsTopic {
        let hay = "\(title) \(source) \(feedHint ?? "")".lowercased()
        if hay.contains("science") || hay.contains("space") || hay.contains("climate") || hay.contains("nasa") || hay.contains("physics") { return .science }
        if hay.contains("tech") || hay.contains("ai ") || hay.contains("apple") || hay.contains("google") || hay.contains("software") { return .tech }
        if hay.contains("market") || hay.contains("economy") || hay.contains("bank") || hay.contains("trade") || hay.contains("stock") { return .business }
        if hay.contains("health") || hay.contains("covid") || hay.contains("hospital") || hay.contains("vaccine") { return .health }
        if hay.contains("film") || hay.contains("music") || hay.contains("art") || hay.contains("culture") || hay.contains("sport") { return .culture }
        if hay.contains("war") || hay.contains("election") || hay.contains("diplomat") || hay.contains("united nations") || hay.contains("world") { return .world }
        return .other
    }
}

@Model
final class NewsArticleEntity {
    var id: UUID = UUID()
    var remoteID: String = ""
    var title: String = ""
    var rawSummary: String = ""
    var aiBrief: String = ""
    var whyItMatters: String = ""
    var sourceName: String = ""
    var urlString: String = ""
    var imageURLString: String = ""
    var publishedAt: Date = Date()
    var fetchedAt: Date = Date()
    var topicRaw: String = NewsTopic.other.rawValue
    var sortOrder: Int = 0
    var isRead: Bool = false
    var dayStart: Date = Date()

    var topic: NewsTopic {
        get { NewsTopic(rawValue: topicRaw) ?? .other }
        set { topicRaw = newValue.rawValue }
    }

    var url: URL? { URL(string: urlString) }
    var imageURL: URL? {
        guard !imageURLString.isEmpty else { return nil }
        return URL(string: imageURLString)
    }

    var digestText: String {
        if !aiBrief.isEmpty { return aiBrief }
        if !rawSummary.isEmpty { return rawSummary }
        return "Open the article for the full story."
    }

    init(
        remoteID: String,
        title: String,
        rawSummary: String = "",
        sourceName: String,
        urlString: String,
        imageURLString: String = "",
        publishedAt: Date = Date(),
        topic: NewsTopic = .other,
        sortOrder: Int = 0,
        dayStart: Date = Calendar.current.startOfDay(for: Date())
    ) {
        self.remoteID = remoteID
        self.title = title
        self.rawSummary = rawSummary
        self.sourceName = sourceName
        self.urlString = urlString
        self.imageURLString = imageURLString
        self.publishedAt = publishedAt
        topicRaw = topic.rawValue
        self.sortOrder = sortOrder
        self.dayStart = dayStart
        fetchedAt = Date()
    }
}

@Model
final class NewsBriefingEntity {
    var id: UUID = UUID()
    var dayStart: Date = Date()
    var headline: String = ""
    var blurb: String = ""
    var articleCount: Int = 0
    var updatedAt: Date = Date()
    var usedAI: Bool = false

    init(dayStart: Date) {
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
    }
}

struct NewsArticleDTO: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var summary: String
    var sourceName: String
    var url: String
    var imageURL: String?
    var publishedAt: Date
    var topic: NewsTopic
}
