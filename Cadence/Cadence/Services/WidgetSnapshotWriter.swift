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
            .prefix(12)
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
            .prefix(6)
            .map {
                WidgetHabitItem(id: $0.id, name: $0.name, isDone: false)
            }

        let nextEvent = CountdownTracking.resolveNextEvent(from: allTasks)
        let matrixQuadrants = buildMatrixQuadrants(from: allTasks)
        let calendarDays = buildCalendarDays(from: allTasks)

        var snap = WidgetSnapshotStore.load()
        snap.updatedAt = .now
        snap.tasks = Array(widgetTasks)
        snap.habits = Array(habits)
        snap.nextEvent = nextEvent
        snap.matrixQuadrants = matrixQuadrants
        snap.calendarDays = calendarDays
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

    private static func buildMatrixQuadrants(from tasks: [PlannerTaskEntity]) -> [WidgetMatrixQuadrant] {
        let open = tasks.filter { !$0.isCompleted && !$0.isEvent }
        let grouped = Dictionary(grouping: open, by: { $0.priority.matrixQuadrant })
        return MatrixQuadrant.allCases.map { q in
            let items = grouped[q, default: []]
            return WidgetMatrixQuadrant(
                id: q.rawValue,
                roman: q.roman,
                title: q.title,
                count: items.count,
                tasks: items.prefix(5).map { WidgetMatrixTask(id: $0.id, title: $0.title) }
            )
        }
    }

    private static func buildCalendarDays(from tasks: [PlannerTaskEntity]) -> [WidgetCalendarDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        return (0..<7).compactMap { offset -> WidgetCalendarDay? in
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let dayStart = cal.startOfDay(for: day)
            let events = tasks
                .filter { task in
                    guard task.isEvent, let due = task.dueAt else { return false }
                    return cal.isDate(due, inSameDayAs: dayStart)
                }
                .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            let openTasks = tasks.filter { task in
                guard !task.isEvent, !task.isCompleted, let due = task.dueAt else { return false }
                return cal.isDate(due, inSameDayAs: dayStart)
            }
            let formatter = DateFormatter()
            formatter.calendar = cal
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let id = formatter.string(from: dayStart)
            let timed = offset == 0 ? buildTimedEvents(for: dayStart, from: tasks) : []
            return WidgetCalendarDay(
                id: id,
                date: dayStart,
                weekdaySymbol: weekday.string(from: dayStart).uppercased(),
                dayNumber: cal.component(.day, from: dayStart),
                isToday: offset == 0,
                eventTitles: events.prefix(4).map(\.title),
                openTaskCount: openTasks.count,
                timedEvents: timed
            )
        }
    }

    /// Timed blocks for today's dual-column timeline (events + due tasks with a clock time).
    private static func buildTimedEvents(for dayStart: Date, from tasks: [PlannerTaskEntity]) -> [WidgetTimedEvent] {
        let cal = Calendar.current
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var blocks: [(start: Date, end: Date, title: String, id: String)] = []
        for task in tasks {
            guard let start = task.dueAt, cal.isDate(start, inSameDayAs: dayStart) else { continue }
            // Skip true all-day (midnight with default duration still gets a 1h block if event).
            let hour = cal.component(.hour, from: start)
            let minute = cal.component(.minute, from: start)
            if !task.isEvent, hour == 0, minute == 0 { continue }

            let duration = max(15, task.durationMinutes)
            let end = min(start.addingTimeInterval(TimeInterval(duration * 60)), dayEnd)
            guard end > start else { continue }
            blocks.append((start, end, task.title, task.id.uuidString))
        }

        return blocks
            .sorted { $0.start < $1.start }
            .prefix(24)
            .enumerated()
            .map { index, block in
                WidgetTimedEvent(
                    id: block.id,
                    title: block.title,
                    startAt: block.start,
                    endAt: block.end,
                    tintIndex: index
                )
            }
    }
}
