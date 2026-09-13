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
    /// Cadence ActionColor / TickTick timeline accent (day number, plus).
    static var cta: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.188, green: 0.584, blue: 1, alpha: 1)
                : UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
        })
    }
    static var nowLine: Color { Color(red: 1, green: 0.25, blue: 0.28) }

    static func eventTint(_ index: Int) -> Color {
        switch index % 3 {
        case 0: return Color(red: 0.55, green: 0.42, blue: 0.95) // purple
        case 1: return Color(red: 0.32, green: 0.55, blue: 0.95) // blue
        default: return Color(red: 0.25, green: 0.72, blue: 0.78) // teal
        }
    }

    static func matrixTint(_ id: String) -> Color {
        switch id {
        case "urgentImportant": return Color(red: 1, green: 0.35, blue: 0.38)
        case "notUrgentImportant": return Color(red: 0.98, green: 0.72, blue: 0.2)
        case "urgentUnimportant": return Color(red: 0.4, green: 0.55, blue: 0.98)
        default: return Color(red: 0.3, green: 0.78, blue: 0.62)
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
        // Minute ticks keep the calendar now-line and countdown accurate.
        var entries: [CadenceWidgetEntry] = []
        let horizon = now.addingTimeInterval(60 * 60)
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
        // TickTick Eisenhower Matrix — titled header, crosshair 2×2, checkable rows.
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Eisenhower Matrix")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: WidgetTheme.Space.sm)
                Link(destination: URL(string: "cadence://open/matrix-add")!) {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(WidgetTheme.cta)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add task")
            }
            .padding(.bottom, WidgetTheme.Space.sm)

            GeometryReader { geo in
                let midX = geo.size.width / 2
                let midY = geo.size.height / 2
                ZStack {
                    // Crosshair dividers
                    Path { path in
                        path.move(to: CGPoint(x: midX, y: 0))
                        path.addLine(to: CGPoint(x: midX, y: geo.size.height))
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: midY))
                    }
                    .stroke(WidgetTheme.hairline, lineWidth: 1)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            tickMatrixCell(quadrants[0], maxTitles: titleLimit)
                            tickMatrixCell(quadrants[1], maxTitles: titleLimit)
                        }
                        HStack(spacing: 0) {
                            tickMatrixCell(quadrants[2], maxTitles: titleLimit)
                            tickMatrixCell(quadrants[3], maxTitles: titleLimit)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private var titleLimit: Int {
        family == .systemExtraLarge ? 5 : 4
    }

    private func tickMatrixCell(_ q: WidgetMatrixQuadrant, maxTitles: Int) -> some View {
        let tint = WidgetTheme.matrixTint(q.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text(q.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            if q.tasks.isEmpty {
                Spacer(minLength: 0)
                Text("No Tasks")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WidgetTheme.muted.opacity(0.85))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ForEach(q.tasks.prefix(maxTitles)) { task in
                    matrixTaskRow(task)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func matrixTaskRow(_ task: WidgetMatrixTask) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleWidgetTaskIntent(taskID: task.id)) {
                matrixTaskLabel(task.title)
            }
            .buttonStyle(.plain)
        } else {
            matrixTaskLabel(task.title)
        }
    }

    private func matrixTaskLabel(_ title: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(WidgetTheme.ink.opacity(0.85), lineWidth: 1.4)
                .frame(width: 12, height: 12)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(WidgetTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
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
}

struct MatrixWidget: Widget {
    let kind = "MatrixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            MatrixWidgetView(entry: entry)
        }
        .configurationDisplayName("Matrix")
        .description("Eisenhower Matrix — TickTick-style quadrants with quick add.")
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
        // TickTick day timeline — large day number + dual columns (7AM–2PM | 2PM–9PM).
        let today = days.first(where: \.isToday) ?? days.first
        return VStack(alignment: .leading, spacing: WidgetTheme.Space.sm) {
            if let today {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(today.dayNumber)")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(WidgetTheme.cta)
                    Text(weekdayFullName(for: today.date))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(WidgetTheme.muted)
                    Spacer(minLength: 0)
                }
            }

            GeometryReader { geo in
                let gap: CGFloat = 10
                let colW = (geo.size.width - gap) / 2
                HStack(alignment: .top, spacing: gap) {
                    timelineColumn(
                        hours: Array(7...14),
                        events: timedEvents(in: 7..<14, from: today?.timedEvents ?? []),
                        width: colW,
                        height: geo.size.height,
                        now: entry.date,
                        dayStart: today?.date
                    )
                    timelineColumn(
                        hours: Array(14...21),
                        events: timedEvents(in: 14..<21, from: today?.timedEvents ?? []),
                        width: colW,
                        height: geo.size.height,
                        now: entry.date,
                        dayStart: today?.date
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            WidgetTheme.chromeBackground
        }
    }

    private func weekdayFullName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    /// Events whose start hour falls in `[startHour, endHour)`.
    private func timedEvents(in range: Range<Int>, from events: [WidgetTimedEvent]) -> [WidgetTimedEvent] {
        events.filter { event in
            let hour = Calendar.current.component(.hour, from: event.startAt)
            return range.contains(hour)
        }
    }

    private func timelineColumn(
        hours: [Int],
        events: [WidgetTimedEvent],
        width: CGFloat,
        height: CGFloat,
        now: Date,
        dayStart: Date?
    ) -> some View {
        let hourCount = max(1, hours.count - 1) // labels include end hour
        let hourHeight = height / CGFloat(hourCount)
        let startHour = hours.first ?? 7
        let endHour = hours.last ?? 21
        let placed = packLanes(events: events, columnStart: startHour, columnEnd: endHour)

        return ZStack(alignment: .topLeading) {
            // Hour lines + labels
            ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                let y = CGFloat(index) * hourHeight
                HStack(spacing: 4) {
                    Text(hourLabel(hour))
                        .font(.system(size: 8, weight: .medium).monospacedDigit())
                        .foregroundStyle(WidgetTheme.muted.opacity(0.85))
                        .frame(width: 26, alignment: .leading)
                    Rectangle()
                        .fill(WidgetTheme.hairline)
                        .frame(height: 1)
                }
                .offset(y: y)
            }

            // Event blocks
            ForEach(placed) { block in
                let top = CGFloat(block.startMinutesFromColumn) / 60 * hourHeight
                let blockHeight = max(16, CGFloat(block.durationMinutes) / 60 * hourHeight - 2)
                let laneWidth = (width - 30) / CGFloat(max(1, block.laneCount))
                let x = 28 + CGFloat(block.lane) * laneWidth
                eventBlock(block.event, height: blockHeight)
                    .frame(width: max(24, laneWidth - 3), height: blockHeight, alignment: .topLeading)
                    .offset(x: x, y: top + 1)
            }

            // Now line
            if let dayStart,
               Calendar.current.isDateInToday(dayStart),
               let y = nowY(
                now: now,
                columnStartHour: startHour,
                columnEndHour: endHour,
                hourHeight: hourHeight
               ) {
                HStack(spacing: 0) {
                    Circle()
                        .fill(WidgetTheme.nowLine)
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(WidgetTheme.nowLine)
                        .frame(height: 1.5)
                }
                .offset(x: 22, y: y - 3.5)
                .frame(width: width - 22, alignment: .leading)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 24
        if h == 0 { return "12AM" }
        if h == 12 { return "12PM" }
        if h < 12 { return "\(h)AM" }
        return "\(h - 12)PM"
    }

    private func nowY(now: Date, columnStartHour: Int, columnEndHour: Int, hourHeight: CGFloat) -> CGFloat? {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        guard hour >= columnStartHour, hour < columnEndHour else { return nil }
        let minutes = (hour - columnStartHour) * 60 + minute
        return CGFloat(minutes) / 60 * hourHeight
    }

    private struct PlacedBlock: Identifiable {
        var id: String { event.id }
        var event: WidgetTimedEvent
        var startMinutesFromColumn: Int
        var durationMinutes: Int
        var lane: Int
        var laneCount: Int
    }

    private func packLanes(events: [WidgetTimedEvent], columnStart: Int, columnEnd: Int) -> [PlacedBlock] {
        let cal = Calendar.current
        struct Interval {
            var event: WidgetTimedEvent
            var start: Int
            var end: Int
        }
        let intervals: [Interval] = events.compactMap { event in
            let startHour = cal.component(.hour, from: event.startAt)
            let startMinute = cal.component(.minute, from: event.startAt)
            var start = (startHour - columnStart) * 60 + startMinute
            var endMinutes: Int = {
                let endHour = cal.component(.hour, from: event.endAt)
                let endMinute = cal.component(.minute, from: event.endAt)
                return (endHour - columnStart) * 60 + endMinute
            }()
            let columnSpan = (columnEnd - columnStart) * 60
            start = max(0, start)
            endMinutes = min(columnSpan, max(start + 15, endMinutes))
            return Interval(event: event, start: start, end: endMinutes)
        }
        .sorted { $0.start < $1.start }

        var laneEnds: [Int] = []
        var provisional: [(Interval, Int)] = []
        for interval in intervals {
            if let lane = laneEnds.firstIndex(where: { $0 <= interval.start }) {
                laneEnds[lane] = interval.end
                provisional.append((interval, lane))
            } else {
                laneEnds.append(interval.end)
                provisional.append((interval, laneEnds.count - 1))
            }
        }

        // Assign laneCount per overlapping cluster (simplified: global max lanes in column).
        let laneCount = max(1, laneEnds.count)
        return provisional.map { interval, lane in
            PlacedBlock(
                event: interval.event,
                startMinutesFromColumn: interval.start,
                durationMinutes: interval.end - interval.start,
                lane: lane,
                laneCount: laneCount
            )
        }
    }

    private func eventBlock(_ event: WidgetTimedEvent, height: CGFloat) -> some View {
        let tint = WidgetTheme.eventTint(event.tintIndex)
        let showTime = height >= 28
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "calendar")
                    .font(.system(size: 8, weight: .semibold))
                Text(event.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(showTime ? 2 : 1)
            }
            if showTime {
                Text(timeRangeLabel(event))
                    .font(.system(size: 8, weight: .medium))
                    .opacity(0.85)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func timeRangeLabel(_ event: WidgetTimedEvent) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: event.startAt)) - \(f.string(from: event.endAt))"
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
}

struct CalendarWidget: Widget {
    let kind = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CadenceWidgetProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("Calendar")
        .description("Large dual-column day timeline — TickTick style. Medium shows the week strip.")
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
