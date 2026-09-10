import Foundation
import SwiftData
import WidgetKit

enum WidgetSnapshotWriter {
    nonisolated(unsafe) private static var publishTask: Task<Void, Never>?
    nonisolated(unsafe) private static var reloadTask: Task<Void, Never>?

    /// Coalesces rapid toggles so task/habit updates don't hitch the UI.
    @MainActor
    static func publish(in context: ModelContext) {
        publishDebounced(in: context)
    }

    @MainActor
    static func publishImmediately(in context: ModelContext) {
        publishTask?.cancel()
        publishTask = nil
        publishNow(in: context)
    }

    @MainActor
    static func publishDebounced(in context: ModelContext, delay: Duration = .milliseconds(250)) {
        publishTask?.cancel()
        publishTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            publishNow(in: context)
        }
    }

    @MainActor
    static func applyPendingToggles(in context: ModelContext) {
        let pending = WidgetSnapshotStore.consumePendingToggles()
        guard !pending.tasks.isEmpty || !pending.habits.isEmpty else { return }

        let allTasks = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        let allHabits = (try? context.fetch(FetchDescriptor<HabitEntity>())) ?? []

        for id in pending.tasks {
            guard let task = allTasks.first(where: { $0.id == id }) else { continue }
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? .now : nil
        }
        for id in pending.habits {
            guard let habit = allHabits.first(where: { $0.id == id }) else { continue }
            if let existing = habit.log(on: .now) {
                context.delete(existing)
            } else {
                context.insert(HabitLogEntity(day: .now, status: .done, habit: habit))
            }
        }
        try? context.save()
        publishImmediately(in: context)
    }

    @MainActor
    private static func publishNow(in context: ModelContext) {
        let allTasks = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        let widgetTasks = allTasks
            .filter(isTodayOpenTask)
            .prefix(8)
            .map {
                WidgetTaskItem(
                    id: $0.id,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    dueAt: $0.dueAt,
                    isOverdue: $0.isOverdue
                )
            }

        let habits = ((try? context.fetch(FetchDescriptor<HabitEntity>())) ?? [])
            .filter { $0.isScheduled(on: .now) && !$0.isDone(on: .now) }
            .prefix(4)
            .map {
                WidgetHabitItem(id: $0.id, name: $0.name, isDone: false)
            }

        let nextEvent = CountdownTracking.resolveNextEvent(from: allTasks)

        var snap = WidgetSnapshotStore.load()
        snap.updatedAt = .now
        snap.tasks = Array(widgetTasks)
        snap.habits = Array(habits)
        snap.nextEvent = nextEvent
        WidgetSnapshotStore.save(snap)
        scheduleTimelineReload()
    }

    /// WidgetKit reloads are expensive; coalesce them so rapid toggles don't hitch the UI.
    @MainActor
    private static func scheduleTimelineReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func isTodayOpenTask(_ task: PlannerTaskEntity) -> Bool {
        guard !task.isEvent, !task.isCompleted else { return false }
        if task.isOverdue { return true }
        if let due = task.dueAt, Calendar.current.isDateInToday(due) { return true }
        if task.dueAt == nil, task.list?.showInToday == true { return true }
        return false
    }
}
