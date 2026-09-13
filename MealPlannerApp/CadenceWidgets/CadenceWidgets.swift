import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - Theme (Cadence chrome — Things / Structured / Matrix)

private enum WidgetTheme {
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    static var surface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.125, green: 0.125, blue: 0.13, alpha: 1)
                : .secondarySystemGroupedBackground
        })
    }

    static var sunken: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.09, green: 0.09, blue: 0.1, alpha: 1)
                : UIColor.tertiarySystemGroupedBackground
        })
    }

    static var hairline: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.09)
                : UIColor.separator.withAlphaComponent(0.35)
        })
    }

    static var ink: Color { Color.primary }
    static var muted: Color { Color.secondary }
    /// Hardcoded — widget target has no Assets catalog, so `Color("AccentColor")` resolves clear.
    static var accent: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 0.478, blue: 0, alpha: 1)
                : UIColor(red: 1, green: 0.42, blue: 0, alpha: 1)
        })
    }

    static func matrixTint(_ id: String) -> Color {
        switch id {
        case "urgentImportant": return Color(red: 1, green: 0.45, blue: 0.72)
        case "notUrgentImportant": return Color(red: 0.95, green: 0.75, blue: 0.2)
        case "urgentUnimportant": return Color(red: 0.4, green: 0.55, blue: 0.98)
        default: return Color(red: 0.35, green: 0.82, blue: 0.55)
        }
    }

    static var chromeBackground: some View {
        surface.overlay {
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(hairline, lineWidth: 1)
        }
    }
}

// MARK: - Intents

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

// MARK: - Provider

struct CadenceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CadenceWidgetEntry {
        CadenceWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (CadenceWidgetEntry) -> Void) {
        completion(CadenceWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CadenceWidgetEntry>) -> Void) {
        let snap = WidgetSnapshotStore.load()
        let now = Date()
        // Minute-level entries so countdown days/hours/mins stay accurate.
        if let end = snap.nextEvent?.startAt, end > now {
            var entries: [CadenceWidgetEntry] = []
            let horizon = min(end, now.addingTimeInterval(60 * 60)) // next hour of updates
            var tick = now
            while tick <= horizon {
                entries.append(CadenceWidgetEntry(date: tick, snapshot: snap))
                guard let next = Calendar.current.date(byAdding: .minute, value: 1, to: tick) else { break }
                tick = next
            }
            if entries.isEmpty {
                entries = [CadenceWidgetEntry(date: now, snapshot: snap)]
            }
            completion(Timeline(entries: entries, policy: .after(horizon)))
        } else {
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
            completion(Timeline(entries: [CadenceWidgetEntry(date: now, snapshot: snap)], policy: .after(next)))
        }
    }
}

struct CadenceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Today Tasks (Things / Todoist large checklist)

struct TodayTasksWidgetView: View {
    var entry: CadenceWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            countdownBody
        case .systemLarge, .systemExtraLarge:
            largeTasksBody
        default:
            tasksBody
        }
    }

    /// Compact / medium — existing density.
    private var tasksBody: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(WidgetTheme.muted)
                    Text("Tasks")
                        .font(.headline)
                }
                Spacer()
                countBadge(openCount)
            }
            if entry.snapshot.tasks.isEmpty && entry.snapshot.habits.isEmpty {
                emptyLine("ALL CLEAR")
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
            WidgetTheme.chromeBackground
        }
    }

    /// Large — Things-style sections: open count hero, checkable rows, habits footer.
    private var largeTasksBody: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(WidgetTheme.muted)
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WidgetTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: WidgetTheme.Space.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(openCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WidgetTheme.accent)
                    Text("OPEN")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(WidgetTheme.muted)
                }
            }

            if entry.snapshot.tasks.isEmpty && entry.snapshot.habits.isEmpty {
                Spacer(minLength: 0)
                emptyLine("Nothing due — enjoy the clear day")
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
                    ForEach(entry.snapshot.tasks.prefix(rowLimit)) { task in
                        taskLine(task, showDue: true)
                    }
                }

                if !entry.snapshot.habits.isEmpty {
                    Rectangle()
                        .fill(WidgetTheme.hairline)
                        .frame(height: 1)
                        .padding(.vertical, 2)
                    Text("HABITS")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(WidgetTheme.muted)
                    ForEach(entry.snapshot.habits.prefix(max(0, rowLimit - entry.snapshot.tasks.prefix(rowLimit).count))) { habit in
                        habitLine(habit)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var countdownBody: some View {
        Group {
            if let event = entry.snapshot.nextEvent,
               event.startAt > entry.date,
               let remaining = CountdownRemaining.until(event.startAt, from: entry.date) {
                if family == .accessoryCircular {
                    VStack(spacing: 1) {
                        if remaining.days > 0 {
                            Text("\(remaining.days)d")
                                .font(.caption.monospacedDigit().weight(.bold))
                            Text("\(remaining.hours)h")
                                .font(.system(size: 9).monospacedDigit())
                        } else if remaining.hours > 0 {
                            Text("\(remaining.hours)h")
                                .font(.caption.monospacedDigit().weight(.bold))
                            Text("\(remaining.minutes)m")
                                .font(.system(size: 9).monospacedDigit())
                        } else {
                            Text("\(remaining.minutes)m")
                                .font(.caption.monospacedDigit().weight(.bold))
                        }
                    }
                } else if family == .accessoryInline {
                    HStack(spacing: WidgetTheme.Space.xs) {
                        Image(systemName: "timer")
                        Text(event.title)
                        Text(remaining.compactLabel)
                    }
                    .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(remaining.compactLabel)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(WidgetTheme.accent)
                    }
                }
            } else {
                Text("NO UPCOMING")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(WidgetTheme.muted)
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var openCount: Int {
        entry.snapshot.tasks.filter { !$0.isCompleted }.count
            + entry.snapshot.habits.filter { !$0.isDone }.count
    }

    private var rowLimit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 8
        case .systemExtraLarge: return 12
        default: return 6
        }
    }

    @ViewBuilder
    private func taskLine(_ task: WidgetTaskItem, showDue: Bool = false) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleWidgetTaskIntent(taskID: task.id)) {
                rowLabel(task.title, done: task.isCompleted, overdue: task.isOverdue, dueAt: showDue ? task.dueAt : nil)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(task.title, done: task.isCompleted, overdue: task.isOverdue, dueAt: showDue ? task.dueAt : nil)
        }
    }

    @ViewBuilder
    private func habitLine(_ habit: WidgetHabitItem) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleWidgetHabitIntent(habitID: habit.id)) {
                rowLabel(habit.name, done: habit.isDone, overdue: false, dueAt: nil)
            }
            .buttonStyle(.plain)
        } else {
            rowLabel(habit.name, done: habit.isDone, overdue: false, dueAt: nil)
        }
    }

    private func rowLabel(_ title: String, done: Bool, overdue: Bool, dueAt: Date?) -> some View {
        HStack(spacing: WidgetTheme.Space.sm) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? WidgetTheme.accent : (overdue ? .red : WidgetTheme.muted))
                .font(.body)
            Text(title)
                .font(.subheadline.weight(.medium))
                .strikethrough(done)
                .foregroundStyle(done ? WidgetTheme.muted : WidgetTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let dueAt, !done {
                Text(dueAt, style: .time)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(overdue ? .red : WidgetTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(WidgetTheme.sunken, in: Capsule())
            }
        }
    }

    private func countBadge(_ n: Int) -> some View {
        Text("\(n)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(WidgetTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(WidgetTheme.sunken, in: Capsule())
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(WidgetTheme.muted)
    }
}

struct TodayTasksWidget: Widget {
    let kind = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Large checklist of today’s tasks and habits — Things-style open count.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Matrix (iomatrix / TickTick 2×2 large)

struct MatrixWidgetView: View {
    var entry: CadenceWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var quadrants: [WidgetMatrixQuadrant] {
        let q = entry.snapshot.matrixQuadrants
        return q.count == 4 ? q : WidgetSnapshot.placeholderMatrix
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallGrid
        case .systemMedium:
            mediumRow
        default:
            largeGrid
        }
    }

    private var smallGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                miniCell(quadrants[0])
                miniCell(quadrants[1])
            }
            HStack(spacing: 6) {
                miniCell(quadrants[2])
                miniCell(quadrants[3])
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var mediumRow: some View {
        HStack(spacing: 8) {
            ForEach(quadrants) { q in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(q.roman)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WidgetTheme.matrixTint(q.id))
                        Spacer()
                        Text("\(q.count)")
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(WidgetTheme.ink)
                    }
                    Text(q.title.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(WidgetTheme.muted)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WidgetTheme.sunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(WidgetTheme.matrixTint(q.id).opacity(0.45), lineWidth: 1)
                }
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var largeGrid: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MATRIX")
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(WidgetTheme.muted)
                    Text("Eisenhower")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Text("\(quadrants.reduce(0) { $0 + $1.count }) open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.muted)
            }

            let gap: CGFloat = 8
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    largeCell(quadrants[0])
                    largeCell(quadrants[1])
                }
                HStack(spacing: gap) {
                    largeCell(quadrants[2])
                    largeCell(quadrants[3])
                }
            }
            .frame(maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private func miniCell(_ q: WidgetMatrixQuadrant) -> some View {
        VStack(spacing: 2) {
            Text(q.roman)
                .font(.caption2.weight(.bold))
                .foregroundStyle(WidgetTheme.matrixTint(q.id))
            Text("\(q.count)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(WidgetTheme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetTheme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(WidgetTheme.matrixTint(q.id).opacity(0.4), lineWidth: 1)
        }
    }

    private func largeCell(_ q: WidgetMatrixQuadrant) -> some View {
        let tint = WidgetTheme.matrixTint(q.id)
        let titleLimit = family == .systemExtraLarge ? 3 : 2
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(q.roman). \(q.title)")
                    .font(.caption2.weight(.bold))
                    .tracking(0.3)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("\(q.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.muted)
            }
            if q.taskTitles.isEmpty {
                Text("Clear")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted.opacity(0.7))
            } else {
                ForEach(Array(q.taskTitles.prefix(titleLimit).enumerated()), id: \.offset) { _, title in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)
                        Text(title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WidgetTheme.ink)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidgetTheme.sunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1.2)
        }
    }
}

struct MatrixWidget: Widget {
    let kind = "MatrixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            MatrixWidgetView(entry: entry)
        }
        .configurationDisplayName("Matrix")
        .description("Eisenhower quadrants at a glance — Do / Schedule / Delegate / Eliminate.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
        ])
    }
}

// MARK: - Calendar (Structured / Outlook week + agenda)

struct CalendarWidgetView: View {
    var entry: CadenceWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var days: [WidgetCalendarDay] {
        entry.snapshot.calendarDays
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallAgenda
        case .systemMedium:
            mediumStrip
        default:
            largeAgenda
        }
    }

    private var smallAgenda: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
            Text("CALENDAR")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(WidgetTheme.muted)
            if let today = days.first {
                Text("\(today.dayNumber)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.accent)
                Text(today.weekdaySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.muted)
                if let first = today.eventTitles.first {
                    Text(first)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetTheme.ink)
                        .lineLimit(2)
                } else {
                    Text("No events")
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.muted)
                }
            } else {
                Text("Open Cadence")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var mediumStrip: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
            HStack {
                Text("THIS WEEK")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer()
                Text(Date.now, format: .dateTime.month(.abbreviated).year())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.muted)
            }
            HStack(spacing: 4) {
                ForEach(days.prefix(7)) { day in
                    dayChip(day)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var largeAgenda: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALENDAR")
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(WidgetTheme.muted)
                    Text(Date.now, format: .dateTime.month(.wide).year())
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                if let next = entry.snapshot.nextEvent, next.startAt > .now {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("UP NEXT")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(WidgetTheme.muted)
                        Text(next.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(next.startAt, style: .time)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(WidgetTheme.accent)
                    }
                }
            }

            HStack(spacing: 4) {
                ForEach(days.prefix(7)) { day in
                    dayChip(day)
                }
            }
            .frame(height: 64)

            Rectangle()
                .fill(WidgetTheme.hairline)
                .frame(height: 1)

            let agenda = agendaRows
            if agenda.isEmpty {
                Text("NO EVENTS THIS WEEK")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
                    ForEach(agenda.prefix(family == .systemExtraLarge ? 8 : 5), id: \.id) { row in
                        HStack(alignment: .top, spacing: WidgetTheme.Space.sm) {
                            VStack(spacing: 0) {
                                Text(row.weekday)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(WidgetTheme.muted)
                                Text("\(row.dayNumber)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(row.isToday ? WidgetTheme.accent : WidgetTheme.ink)
                            }
                            .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(WidgetTheme.ink)
                                    .lineLimit(1)
                                if row.taskCount > 0 {
                                    Text("\(row.taskCount) task\(row.taskCount == 1 ? "" : "s") due")
                                        .font(.caption2)
                                        .foregroundStyle(WidgetTheme.muted)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private func dayChip(_ day: WidgetCalendarDay) -> some View {
        let hasEvents = !day.eventTitles.isEmpty || day.openTaskCount > 0
        return VStack(spacing: 4) {
            Text(String(day.weekdaySymbol.prefix(1)))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(WidgetTheme.muted)
            Text("\(day.dayNumber)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(day.isToday ? Color.white : WidgetTheme.ink)
                .frame(width: 28, height: 28)
                .background {
                    if day.isToday {
                        Circle().fill(WidgetTheme.accent)
                    }
                }
            Circle()
                .fill(hasEvents ? WidgetTheme.accent.opacity(0.85) : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private struct AgendaRow: Identifiable {
        let id: String
        let weekday: String
        let dayNumber: Int
        let isToday: Bool
        let title: String
        let taskCount: Int
    }

    private var agendaRows: [AgendaRow] {
        var rows: [AgendaRow] = []
        for day in days {
            for (idx, title) in day.eventTitles.enumerated() {
                rows.append(AgendaRow(
                    id: "\(day.id)-\(idx)",
                    weekday: String(day.weekdaySymbol.prefix(3)),
                    dayNumber: day.dayNumber,
                    isToday: day.isToday,
                    title: title,
                    taskCount: idx == 0 ? day.openTaskCount : 0
                ))
            }
            if day.eventTitles.isEmpty, day.openTaskCount > 0 {
                rows.append(AgendaRow(
                    id: "\(day.id)-tasks",
                    weekday: String(day.weekdaySymbol.prefix(3)),
                    dayNumber: day.dayNumber,
                    isToday: day.isToday,
                    title: "\(day.openTaskCount) task\(day.openTaskCount == 1 ? "" : "s") due",
                    taskCount: 0
                ))
            }
        }
        return rows
    }
}

struct CalendarWidget: Widget {
    let kind = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Calendar")
        .description("Week strip and upcoming agenda — Structured / Outlook style.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
        ])
    }
}

// MARK: - Countdown

struct CountdownWidget: Widget {
    let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Days, hours, and minutes until your starred or next upcoming event.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .systemSmall,
            .systemMedium,
        ])
    }
}

struct CountdownWidgetView: View {
    var entry: CadenceWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var event: WidgetNextEvent? {
        guard let event = entry.snapshot.nextEvent, event.startAt > entry.date else { return nil }
        return event
    }

    private var remaining: CountdownRemaining? {
        guard let event else { return nil }
        return CountdownRemaining.until(event.startAt, from: entry.date)
    }

    var body: some View {
        Group {
            if let event, let remaining {
                switch family {
                case .accessoryCircular:
                    circularBody(remaining)
                case .accessoryInline:
                    Text("\(event.title) · \(remaining.compactLabel)")
                        .lineLimit(1)
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(remaining.compactLabel)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(WidgetTheme.accent)
                    }
                case .systemMedium:
                    mediumBody(event, remaining)
                default:
                    smallBody(event, remaining)
                }
            } else {
                emptyBody
            }
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.xs) {
            Text("COUNTDOWN")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(WidgetTheme.muted)
            Text("No upcoming event")
                .font(.headline)
            Text("Add a calendar event or star one to pin it.")
                .font(.caption)
                .foregroundStyle(WidgetTheme.muted)
                .lineLimit(family == .systemSmall ? 3 : 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallBody(_ event: WidgetNextEvent, _ remaining: CountdownRemaining) -> some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
            Text("COUNTDOWN")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(WidgetTheme.muted)
            Text(event.title)
                .font(.headline)
                .lineLimit(2)
            Text(event.startAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(WidgetTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            countdownUnits(remaining, compact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediumBody(_ event: WidgetNextEvent, _ remaining: CountdownRemaining) -> some View {
        HStack(alignment: .center, spacing: WidgetTheme.Space.md) {
            VStack(alignment: .leading, spacing: WidgetTheme.Space.sm - 2) {
                Text("COUNTDOWN")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(WidgetTheme.muted)
                Text(event.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(event.startAt, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            countdownUnits(remaining, compact: false)
        }
    }

    private func circularBody(_ remaining: CountdownRemaining) -> some View {
        VStack(spacing: 1) {
            if remaining.days > 0 {
                Text("\(remaining.days)d")
                    .font(.headline.monospacedDigit().weight(.bold))
                Text("\(remaining.hours)h")
                    .font(.caption2.monospacedDigit())
            } else if remaining.hours > 0 {
                Text("\(remaining.hours)h")
                    .font(.headline.monospacedDigit().weight(.bold))
                Text("\(remaining.minutes)m")
                    .font(.caption2.monospacedDigit())
            } else {
                Text("\(remaining.minutes)")
                    .font(.headline.monospacedDigit().weight(.bold))
                Text("min")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(WidgetTheme.accent)
    }

    private func countdownUnits(_ remaining: CountdownRemaining, compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 10) {
            unitCell(value: remaining.days, label: "DAYS", compact: compact)
            unitCell(value: remaining.hours, label: "HRS", compact: compact)
            unitCell(value: remaining.minutes, label: "MIN", compact: compact)
        }
    }

    private func unitCell(value: Int, label: String, compact: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(compact
                      ? .title3.monospacedDigit().weight(.bold)
                      : .largeTitle.monospacedDigit().weight(.bold))
                .foregroundStyle(WidgetTheme.accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: compact ? 8 : 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(WidgetTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 6 : 8)
        .background(WidgetTheme.sunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Bundle

@main
struct CadenceWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        MatrixWidget()
        CalendarWidget()
        CountdownWidget()
    }
}
