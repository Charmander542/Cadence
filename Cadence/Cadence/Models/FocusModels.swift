import Foundation
import SwiftData

enum FocusMode: String, CaseIterable, Identifiable, Codable {
    case pomo
    case stopwatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pomo: return "Pomo"
        case .stopwatch: return "Stopwatch"
        }
    }
}

@Model
final class FocusSessionEntity {
    var id: UUID = UUID()
    var modeRaw: String = "pomo"
    var startedAt: Date = Date()
    var endedAt: Date?
    /// Completed focus seconds (excludes unfinished / cancelled).
    var durationSeconds: Int = 0
    var label: String = "Focus"
    var completed: Bool = false

    var mode: FocusMode {
        get { FocusMode(rawValue: modeRaw) ?? .pomo }
        set { modeRaw = newValue.rawValue }
    }

    init(
        mode: FocusMode,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        durationSeconds: Int = 0,
        label: String = "Focus",
        completed: Bool = false
    ) {
        self.id = UUID()
        self.modeRaw = mode.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.label = label
        self.completed = completed
    }
}
