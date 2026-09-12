import Foundation
import SwiftData
import WidgetKit

extension Notification.Name {
    static let countdownTrackingDidChange = Notification.Name("countdownTrackingDidChange")
}

/// User-picked event for home/lock screen countdown widgets (one at a time).
/// Stored in the App Group so the widget snapshot and main app stay in sync.
enum CountdownTracking {
    private static let key = "planner.trackedCountdownEventID"
    private static let legacyStandardKey = "planner.trackedCountdownEventID"

    private static var store: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupID) ?? .standard
    }

    static var trackedEventID: UUID? {
        get {
            migrateFromStandardIfNeeded()
            guard let raw = store.string(forKey: key) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let id = newValue {
                store.set(id.uuidString, forKey: key)
            } else {
                store.removeObject(forKey: key)
            }
            // Keep legacy key cleared so we don't resurrect a stale star.
            UserDefaults.standard.removeObject(forKey: legacyStandardKey)
        }
    }

    static func isTracked(_ eventID: UUID) -> Bool {
        trackedEventID == eventID
    }

    @MainActor
    static func toggle(_ eventID: UUID, in context: ModelContext) {
        if trackedEventID == eventID {
            trackedEventID = nil
        } else {
            trackedEventID = eventID
        }
        NotificationCenter.default.post(name: .countdownTrackingDidChange, object: nil)
        WidgetSnapshotWriter.publishImmediately(in: context)
    }

    @MainActor
    static func clearIfTracked(_ eventID: UUID, in context: ModelContext) {
        guard trackedEventID == eventID else { return }
        trackedEventID = nil
        NotificationCenter.default.post(name: .countdownTrackingDidChange, object: nil)
        WidgetSnapshotWriter.publishImmediately(in: context)
    }

    /// Prefer the starred event; otherwise the soonest future calendar event.
    static func resolveNextEvent(from tasks: [PlannerTaskEntity]) -> WidgetNextEvent? {
        if let id = trackedEventID,
           let task = tasks.first(where: { $0.id == id }),
           task.isEvent,
           !task.isCompleted,
           let startAt = countdownStart(for: task),
           startAt > .now {
            return WidgetNextEvent(title: task.title, startAt: startAt)
        }

        let upcoming: [(title: String, start: Date)] = tasks.compactMap { task in
            guard task.isEvent, !task.isCompleted,
                  let start = countdownStart(for: task),
                  start > .now
            else { return nil }
            return (task.title, start)
        }
        .sorted { $0.start < $1.start }

        guard let next = upcoming.first else { return nil }
        return WidgetNextEvent(title: next.title, startAt: next.start)
    }

    static func countdownStart(for task: PlannerTaskEntity) -> Date? {
        if let due = task.dueAt { return due }
        return task.reminderAt
    }

    private static func migrateFromStandardIfNeeded() {
        if store.string(forKey: key) != nil { return }
        guard let legacy = UserDefaults.standard.string(forKey: legacyStandardKey), !legacy.isEmpty else { return }
        store.set(legacy, forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyStandardKey)
    }
}
