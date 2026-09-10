import WidgetKit
import SwiftUI
import AppIntents
import UIKit

private enum WidgetTheme {
    static var surface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1)
                : .secondarySystemGroupedBackground
        })
    }
}

struct ToggleWidgetTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle task"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { return .result() }
        WidgetSnapshotStore.queueTaskToggle(id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct ToggleWidgetHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle habit"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else { return .result() }
        WidgetSnapshotStore.queueHabitToggle(id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct CadenceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CadenceWidgetEntry {
        CadenceWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (CadenceWidgetEntry) -> Void) {
        completion(CadenceWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CadenceWidgetEntry>) -> Void) {
        let snap = WidgetSnapshotStore.load()
        let entry = CadenceWidgetEntry(date: .now, snapshot: snap)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CadenceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayTasksWidgetView: View {
    var entry: CadenceWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            countdownBody
        default:
            tasksBody
        }
    }

    private var tasksBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("\(openCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if entry.snapshot.tasks.isEmpty && entry.snapshot.habits.isEmpty {
                Text("All clear")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.snapshot.tasks.prefix(rowLimit)) { task in
                    taskLine(task)
                }
                ForEach(entry.snapshot.habits.prefix(max(0, rowLimit - entry.snapshot.tasks.count))) { habit in
                    habitLine(habit)
                }
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.surface
        }
    }

    private var countdownBody: some View {
        Group {
            if let event = entry.snapshot.nextEvent, event.startAt > .now {
                if family == .accessoryCircular {
                    VStack(spacing: 2) {
                        Text(timerInterval: .now...event.startAt, countsDown: true)
                            .font(.caption2.monospacedDigit())
                            .multilineTextAlignment(.center)
                        Text("left")
                            .font(.system(size: 8))
                    }
                } else if family == .accessoryInline {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(event.title)
                        Text(timerInterval: .now...event.startAt, countsDown: true)
                    }
                    .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(timerInterval: .now...event.startAt, countsDown: true)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No upcoming")
                    .font(.caption)
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.surface
        }
    }

    private var openCount: Int {
        entry.snapshot.tasks.filter { !$0.isCompleted }.count + entry.snapshot.habits.filter { !$0.isDone }.count
    }

    private var rowLimit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        default: return 6
        }
    }

    @ViewBuilder
    private func taskLine(_ task: WidgetTaskItem) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleWidgetTaskIntent(taskID: task.id)) {
                rowLabel(task.title, done: task.isCompleted, overdue: task.isOverdue)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(task.title, done: task.isCompleted, overdue: task.isOverdue)
        }
    }

    @ViewBuilder
    private func habitLine(_ habit: WidgetHabitItem) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleWidgetHabitIntent(habitID: habit.id)) {
                rowLabel(habit.name, done: habit.isDone, overdue: false)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(habit.name, done: habit.isDone, overdue: false)
        }
    }

    private func rowLabel(_ title: String, done: Bool, overdue: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .orange : (overdue ? .red : .secondary))
                .font(.caption)
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .strikethrough(done)
        }
    }
}

struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Check off tasks and habits from your home or lock screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Time until your starred event.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .systemSmall,
        ])
    }
}

struct CountdownWidgetView: View {
    var entry: CadenceWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let event = entry.snapshot.nextEvent, event.startAt > .now {
            VStack(alignment: .leading, spacing: 6) {
                Text("Up next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.headline)
                    .lineLimit(family == .systemSmall ? 2 : 1)
                Text(event.startAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(timerInterval: .now...event.startAt, countsDown: true)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                WidgetTheme.surface
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Up next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Star an event to track")
                    .font(.headline)
            }
            .containerBackground(for: .widget) {
                WidgetTheme.surface
            }
        }
    }
}

@main
struct CadenceWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        CountdownWidget()
    }
}
