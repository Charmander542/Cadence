import Foundation
import SwiftData
import WidgetKit

extension Notification.Name {
    static let countdownTrackingDidChange = Notification.Name("countdownTrackingDidChange")
}

/// User-picked event for home/lock screen countdown widgets (one at a time).
enum CountdownTracking {
    private static let key = "planner.trackedCountdownEventID"

    static var trackedEventID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
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
        WidgetSnapshotWriter.publish(in: context)
    }

    @MainActor
    static func clearIfTracked(_ eventID: UUID, in context: ModelContext) {
        guard trackedEventID == eventID else { return }
        trackedEventID = nil
        NotificationCenter.default.post(name: .countdownTrackingDidChange, object: nil)
        WidgetSnapshotWriter.publish(in: context)
    }

    static func resolveNextEvent(from tasks: [PlannerTaskEntity]) -> WidgetNextEvent? {
        guard let id = trackedEventID,
              let task = tasks.first(where: { $0.id == id }),
              task.isEvent,
              !task.isCompleted,
              let startAt = countdownStart(for: task),
              startAt > .now
        else {
            return nil
        }
        return WidgetNextEvent(title: task.title, startAt: startAt)
    }

    private static func countdownStart(for task: PlannerTaskEntity) -> Date? {
        if let due = task.dueAt { return due }
        return task.reminderAt
    }
}
