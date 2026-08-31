import Foundation

/// App Group payload for home/lock screen widgets.
struct WidgetTaskItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dueAt: Date?
    var isOverdue: Bool
}

struct WidgetHabitItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var isDone: Bool
}

struct WidgetNextEvent: Codable, Hashable {
    var title: String
    var startAt: Date
}

struct WidgetSnapshot: Codable {
    var updatedAt: Date
    var tasks: [WidgetTaskItem]
    var habits: [WidgetHabitItem]
    var nextEvent: WidgetNextEvent?
    var pendingTaskToggles: [UUID]
    var pendingHabitToggles: [UUID]

    static let empty = WidgetSnapshot(
        updatedAt: .now,
        tasks: [],
        habits: [],
        nextEvent: nil,
        pendingTaskToggles: [],
        pendingHabitToggles: []
    )
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.musclemeal.app"
    private static let snapshotKey = "widget_snapshot_v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return decoded
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    static func queueTaskToggle(_ id: UUID) {
        var snap = load()
        if !snap.pendingTaskToggles.contains(id) {
            snap.pendingTaskToggles.append(id)
        }
        save(snap)
    }

    static func queueHabitToggle(_ id: UUID) {
        var snap = load()
        if !snap.pendingHabitToggles.contains(id) {
            snap.pendingHabitToggles.append(id)
        }
        save(snap)
    }

    static func consumePendingToggles() -> (tasks: [UUID], habits: [UUID]) {
        var snap = load()
        let tasks = snap.pendingTaskToggles
        let habits = snap.pendingHabitToggles
        snap.pendingTaskToggles = []
        snap.pendingHabitToggles = []
        save(snap)
        return (tasks, habits)
    }
}
