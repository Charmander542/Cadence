import SwiftUI
import SwiftData

enum PlannerColor {
    static let palette: [String] = [
        "FF6B00", "5EB3FF", "5BCB8A", "F06292", "9575CD",
        "FFB020", "4DB6AC", "FF7043", "7986CB", "FFD54F",
    ]

    static func from(hex: String) -> Color {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = Int(raw, radix: 16) else { return Theme.accent }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    static func defaultHex(for index: Int) -> String {
        palette[index % palette.count]
    }
}

enum TagCatalog {
    static func all(in context: ModelContext) -> [PlannerTagEntity] {
        let descriptor = FetchDescriptor<PlannerTagEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func tag(named name: String, in context: ModelContext) -> PlannerTagEntity? {
        let key = name.lowercased()
        return all(in: context).first { $0.name == key }
    }

    @discardableResult
    static func ensureTag(_ name: String, in context: ModelContext) -> PlannerTagEntity {
        let key = name.lowercased()
        if let existing = tag(named: key, in: context) {
            return existing
        }
        let count = all(in: context).count
        let entity = PlannerTagEntity(name: key, colorHex: PlannerColor.defaultHex(for: count))
        context.insert(entity)
        try? context.save()
        return entity
    }

    static func ensureTags(_ names: [String], in context: ModelContext) {
        for name in names {
            ensureTag(name, in: context)
        }
    }

    static func color(for tagName: String, in context: ModelContext) -> Color {
        if let tag = tag(named: tagName, in: context) {
            return PlannerColor.from(hex: tag.colorHex)
        }
        return Theme.accent
    }

    static func displayColor(for task: PlannerTaskEntity, in context: ModelContext) -> Color {
        if !task.colorHex.isEmpty {
            return PlannerColor.from(hex: task.colorHex)
        }
        if let first = task.tags.first {
            return color(for: first, in: context)
        }
        return task.priority.flagColor
    }
}

enum RecurrenceWeekdayMask {
    static func contains(_ weekday: Int, in mask: Int) -> Bool {
        guard (1...7).contains(weekday) else { return false }
        return mask & (1 << (weekday - 1)) != 0
    }

    static func toggle(_ weekday: Int, in mask: Int) -> Int {
        mask ^ (1 << (weekday - 1))
    }

    static func labels() -> [(weekday: Int, short: String)] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return (1...7).map { weekday in
            (weekday, symbols[max(0, min(symbols.count - 1, weekday - 1))])
        }
    }

    static func from(startDate: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: startDate)
        return 1 << (weekday - 1)
    }

    static func summary(_ mask: Int) -> String {
        let labels = labels().filter { contains($0.weekday, in: mask) }.map(\.short)
        return labels.isEmpty ? "Pick days" : labels.joined(separator: ", ")
    }
}

struct DraftEventSlot: Equatable {
    var start: Date
    var end: Date
}
