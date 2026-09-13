import Foundation

/// Fetches a mixed daily slate from public RSS feeds (no API key).
/// A stronger backend can replace this later; keep DTO shape stable.
actor NewsClient {
    struct Feed: Sendable {
        let name: String
        let url: URL
        let topicHint: NewsTopic
    }

    enum NewsClientError: LocalizedError {
        case badResponse
        case empty

        var errorDescription: String? {
            switch self {
            case .badResponse: return "News feed returned an unexpected response."
            case .empty: return "No stories in feeds right now."
            }
        }
    }

    private let session: URLSession

    /// Curated mix: world, science, tech, business, culture.
    static let defaultFeeds: [Feed] = [
        Feed(name: "BBC World", url: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!, topicHint: .world),
        Feed(name: "NPR News", url: URL(string: "https://feeds.npr.org/1001/rss.xml")!, topicHint: .world),
        Feed(name: "NASA", url: URL(string: "https://www.nasa.gov/rss/dyn/breaking_news.rss")!, topicHint: .science),
        Feed(name: "ScienceDaily", url: URL(string: "https://www.sciencedaily.com/rss/top.xml")!, topicHint: .science),
        Feed(name: "The Verge", url: URL(string: "https://www.theverge.com/rss/index.xml")!, topicHint: .tech),
        Feed(name: "CNBC Top", url: URL(string: "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=100003114")!, topicHint: .business),
        Feed(name: "Smithsonian", url: URL(string: "https://www.smithsonianmag.com/rss/latest/")!, topicHint: .culture),
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Pulls from several feeds and returns up to `limit` diverse stories.
    func fetchDailyDigest(limit: Int = 10) async throws -> [NewsArticleDTO] {
        var collected: [NewsArticleDTO] = []
        await withTaskGroup(of: [NewsArticleDTO].self) { group in
            for feed in Self.defaultFeeds {
                group.addTask {
                    (try? await self.fetchFeed(feed)) ?? []
                }
            }
            for await batch in group {
                collected.append(contentsOf: batch)
            }
        }

        // Prefer recent + diversify by topic.
        let sorted = collected.sorted { $0.publishedAt > $1.publishedAt }
        var seenTitles = Set<String>()
        var byTopic: [NewsTopic: [NewsArticleDTO]] = [:]
        for item in sorted {
            let key = item.title.lowercased()
            guard !seenTitles.contains(key) else { continue }
            seenTitles.insert(key)
            byTopic[item.topic, default: []].append(item)
        }

        var picks: [NewsArticleDTO] = []
        let order: [NewsTopic] = [.world, .science, .tech, .business, .culture, .health, .other]
        var index = 0
        while picks.count < limit {
            var added = false
            for topic in order {
                guard picks.count < limit else { break }
                var bucket = byTopic[topic] ?? []
                guard index < bucket.count else { continue }
                picks.append(bucket[index])
                added = true
            }
            if !added { break }
            index += 1
        }

        if picks.isEmpty { throw NewsClientError.empty }
        return Array(picks.prefix(limit))
    }

    private func fetchFeed(_ feed: Feed) async throws -> [NewsArticleDTO] {
        var request = URLRequest(url: feed.url)
        request.setValue("CadenceNews/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NewsClientError.badResponse
        }
        let xml = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return RSSParser.parse(xml: xml, sourceName: feed.name, topicHint: feed.topicHint)
    }
}

// MARK: - Minimal RSS / Atom parser

enum RSSParser {
    static func parse(xml: String, sourceName: String, topicHint: NewsTopic) -> [NewsArticleDTO] {
        let items = splitBlocks(xml, open: "<item", close: "</item>")
            + splitBlocks(xml, open: "<entry", close: "</entry>")
        return items.compactMap { block -> NewsArticleDTO? in
            let title = decode(tag("title", in: block) ?? "")
            guard !title.isEmpty else { return nil }
            let link = firstLink(in: block) ?? ""
            guard !link.isEmpty else { return nil }
            let summary = decode(
                tag("description", in: block)
                    ?? tag("summary", in: block)
                    ?? tag("content", in: block)
                    ?? ""
            )
            let cleaned = stripHTML(summary)
            let image = mediaImage(in: block) ?? firstImageURL(in: summary)
            let date = parseDate(tag("pubDate", in: block) ?? tag("published", in: block) ?? tag("updated", in: block))
            let topic = NewsTopic.infer(from: title, source: sourceName, feedHint: topicHint.rawValue)
            let finalTopic = topic == .other ? topicHint : topic
            return NewsArticleDTO(
                id: link,
                title: title,
                summary: String(cleaned.prefix(420)),
                sourceName: sourceName,
                url: link,
                imageURL: image,
                publishedAt: date ?? Date(),
                topic: finalTopic
            )
        }
    }

    private static func splitBlocks(_ xml: String, open: String, close: String) -> [String] {
        var result: [String] = []
        var search = xml[...]
        while let start = search.range(of: open, options: .caseInsensitive) {
            let from = start.lowerBound
            guard let end = search[from...].range(of: close, options: .caseInsensitive) else { break }
            result.append(String(search[from..<end.upperBound]))
            search = search[end.upperBound...]
        }
        return result
    }

    private static func tag(_ name: String, in block: String) -> String? {
        let patterns = [
            "<\(name)[^>]*><!\\[CDATA\\[(.*?)\\]\\]></\(name)>",
            "<\(name)[^>]*>(.*?)</\(name)>",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: block) {
                return String(block[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func firstLink(in block: String) -> String? {
        if let link = tag("link", in: block), link.hasPrefix("http") { return link }
        // Atom: <link href="..." />
        if let regex = try? NSRegularExpression(pattern: #"<link[^>]+href=\"([^\"]+)\""#, options: .caseInsensitive),
           let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
           let range = Range(match.range(at: 1), in: block) {
            return String(block[range])
        }
        if let regex = try? NSRegularExpression(pattern: #"<guid[^>]*>(https?://[^<]+)</guid>"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
           let range = Range(match.range(at: 1), in: block) {
            return String(block[range])
        }
        return nil
    }

    private static func mediaImage(in block: String) -> String? {
        let patterns = [
            #"<media:content[^>]+url=\"([^\"]+)\""#,
            #"<media:thumbnail[^>]+url=\"([^\"]+)\""#,
            #"<enclosure[^>]+url=\"([^\"]+\.(?:jpg|jpeg|png|webp)[^\"]*)\""#,
            #"<enclosure[^>]+type=\"image/[^\"]+\"[^>]+url=\"([^\"]+)\""#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               let range = Range(match.range(at: 1), in: block) {
                return String(block[range])
            }
        }
        return nil
    }

    private static func firstImageURL(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<img[^>]+src=\"([^\"]+)\""#, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }

    private static func stripHTML(_ text: String) -> String {
        var s = text
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .dotMatchesLineSeparators) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decode(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return ISO8601DateFormatter().date(from: raw)
    }
}
