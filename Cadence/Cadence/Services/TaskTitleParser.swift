import Foundation

struct ParsedTaskTitle: Equatable {
    var cleanTitle: String
    var dueDate: Date?
    var tags: [String]
}

enum TaskTitleParser {
    static func parse(_ raw: String, reference: Date = .now) -> ParsedTaskTitle {
        var working = raw
        var tags: [String] = []

        while let match = firstMatch(in: working, pattern: #"(?:^|\s)#([\w-]+)"#) {
            tags.append(match.1.lowercased())
            working.removeSubrange(match.0)
        }

        let (date, withoutDates) = extractDate(from: working, reference: reference)
        let clean = withoutDates
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedTaskTitle(
            cleanTitle: clean,
            dueDate: date,
            tags: tags
        )
    }

    private static func firstMatch(in text: String, pattern: String) -> (Range<String.Index>, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 2,
              let swiftRange = Range(match.range, in: text),
              let captureRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return (swiftRange, String(text[captureRange]))
    }

    private static func extractDate(from text: String, reference: Date) -> (Date?, String) {
        let cal = Calendar.current
        var foundDate: Date?
        var result = text

        for (word, dayOffset) in [("tomorrow", 1), ("tommorow", 1), ("today", 0)] {
            if let range = result.range(of: word, options: .caseInsensitive) {
                if foundDate == nil {
                    foundDate = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: reference))
                }
                result.removeSubrange(range)
            }
        }

        let weekdaySymbols = cal.weekdaySymbols
        for (index, name) in weekdaySymbols.enumerated() {
            guard name.count >= 3 else { continue }
            if let range = result.range(of: name, options: .caseInsensitive) {
                if foundDate == nil {
                    foundDate = nextWeekday(index + 1, from: reference, includeToday: true)
                }
                result.removeSubrange(range)
            }
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let ns = result as NSString
            let matches = detector.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                if foundDate == nil, let date = match.date {
                    foundDate = cal.startOfDay(for: date)
                }
                if let range = Range(match.range, in: result) {
                    result.removeSubrange(range)
                }
            }
        }

        return (foundDate, result)
    }

    private static func nextWeekday(_ weekday: Int, from reference: Date, includeToday: Bool) -> Date? {
        let cal = Calendar.current
        let current = cal.component(.weekday, from: reference)
        var delta = weekday - current
        if delta < 0 || (delta == 0 && !includeToday) {
            delta += 7
        }
        return cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: reference))
    }
}
