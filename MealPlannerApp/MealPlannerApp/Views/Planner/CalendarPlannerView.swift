import SwiftUI
import SwiftData

private struct CalendarDayItem: Identifiable {
    let id: String
    let title: String
    let color: Color
    let task: PlannerTaskEntity?

    init(title: String, color: Color, task: PlannerTaskEntity? = nil) {
        self.title = title
        self.color = color
        self.task = task
        id = task?.id.uuidString ?? "workout-\(title)"
    }
}

private struct DayDetailContext: Identifiable {
    let id = UUID()
    let day: Date
}

struct CalendarPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(
        filter: #Predicate<PlannerTaskEntity> { task in
            task.isEvent && !task.isCompleted
        },
        sort: \PlannerTaskEntity.dueAt
    ) private var tasks: [PlannerTaskEntity]
    @Query private var profiles: [UserProfileEntity]
    @State private var scope: CalendarScope = .month
    @State private var scopeBeforeDayDrill: CalendarScope?
    @State private var cursor = Date()
    @State private var showScope = false
    @State private var eventContext: EventSheetContext?
    @State private var dayDetailContext: DayDetailContext?
    @State private var draftSlot: DraftEventSlot?
    @State private var eventsByDay: [Date: [PlannerTaskEntity]] = [:]
    @State private var eventIndexStamp: Int = 0
    @State private var previewDay: Date = Calendar.current.startOfDay(for: .now)

    private let weekdaySymbols = ["S", "M", "Tu", "W", "Th", "F", "S"]
    private let hourRowHeight: CGFloat = 52
    private let timeGutter: CGFloat = 44
    /// Bottom inset so the add-event FAB does not cover the last month row.
    private let calendarFABClearance: CGFloat = 96

    private var workoutsEnabled: Bool {
        profiles.first?.workoutsEnabled ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch scope {
                case .year: yearScope
                case .month: monthScope
                case .week: weekScope(days: 7)
                case .threeDay: weekScope(days: 3)
                case .day: weekScope(days: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .dialFABChrome {
            OrangeFAB(
                accessibilityLabel: "Add event",
                accessibilityHint: "Opens new calendar event"
            ) {
                openNewEvent(at: defaultEventStart)
            }
        }
        .confirmationDialog("View", isPresented: $showScope, titleVisibility: .visible) {
            ForEach(CalendarScope.allCases) { item in
                Button(item.title) {
                    scopeBeforeDayDrill = nil
                    scope = item
                }
                    .accessibilityLabel(scope == item ? "\(item.title) view, selected" : "\(item.title) view")
                    .accessibilityHint("Switches calendar to \(item.title.lowercased()) view")
            }
            Button("Cancel", role: .cancel) {}
                .accessibilityHint("Keeps \(scope.title.lowercased()) calendar view")
        }
        .sheet(item: $eventContext) { context in
            PlannerEventSheet(context: context)
        }
        .sheet(item: $dayDetailContext) { context in
            DayDetailSheet(day: context.day)
        }
        .onChange(of: eventContext?.id) { _, new in
            if new == nil { draftSlot = nil }
        }
        .onChange(of: tasks.count) { _, _ in
            eventIndexStamp = 0
            rebuildEventIndex()
        }
        .onAppear {
            rebuildEventIndex()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if scope == .day, let previous = scopeBeforeDayDrill {
                Button { exitDayDrill(to: previous) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text(previous.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.cta)
                }
                .accessibilityLabel("Back to \(previous.title) view")
                .accessibilityHint("Returns to the calendar view you were on")
            } else {
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Previous \(scope.title.lowercased())")
                .accessibilityHint("Shows earlier \(scope.title.lowercased())")
            }
            if scope == .day, scopeBeforeDayDrill != nil {
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Next day")
                .accessibilityHint("Shows the following day")
            } else {
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Next \(scope.title.lowercased())")
                .accessibilityHint("Shows later \(scope.title.lowercased())")
            }
            Spacer()
            Button { showScope = true } label: {
                HStack(spacing: 6) {
                    Text(headerTitle).font(Theme.title(.title2))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel("Calendar view, \(headerTitle)")
            .accessibilityHint("Double tap to change month, week, or day view")
            Spacer()
            Button { cursor = .now; previewDay = Calendar.current.startOfDay(for: .now) } label: {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityLabel("Go to today")
            .accessibilityHint("Jumps calendar to today's date")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var headerTitle: String {
        let f = DateFormatter()
        switch scope {
        case .year: f.dateFormat = "yyyy"
        case .month: f.dateFormat = "MMMM yyyy"
        default: f.dateFormat = "MMM d, yyyy"
        }
        return f.string(from: cursor)
    }

    private var defaultEventStart: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: cursor)
        if cal.isDateInToday(cursor) {
            comps.hour = max(cal.component(.hour, from: .now), 6)
        } else {
            comps.hour = 9
        }
        comps.minute = 0
        return cal.date(from: comps) ?? cursor
    }

    private func shift(_ dir: Int) {
        let cal = Calendar.current
        switch scope {
        case .year:
            cursor = cal.date(byAdding: .year, value: dir, to: cursor) ?? cursor
        case .month:
            cursor = cal.date(byAdding: .month, value: dir, to: cursor) ?? cursor
        case .week:
            cursor = cal.date(byAdding: .weekOfYear, value: dir, to: cursor) ?? cursor
        case .threeDay:
            cursor = cal.date(byAdding: .day, value: dir * 3, to: cursor) ?? cursor
        case .day:
            cursor = cal.date(byAdding: .day, value: dir, to: cursor) ?? cursor
        }
    }

    private func openNewEvent(at start: Date) {
        let end = start.addingTimeInterval(3600)
        draftSlot = DraftEventSlot(start: start, end: end)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            eventContext = EventSheetContext(task: nil, startDate: start)
        }
    }

    private func openEditEvent(_ task: PlannerTaskEntity) {
        eventContext = EventSheetContext(task: task, startDate: task.dueAt ?? .now)
    }

    private func openDayDetail(for day: Date) {
        dayDetailContext = DayDetailContext(day: Calendar.current.startOfDay(for: day))
    }

    private func openDayView(for day: Date) {
        let normalized = Calendar.current.startOfDay(for: day)
        if scope != .day {
            scopeBeforeDayDrill = scope
        }
        cursor = normalized
        previewDay = normalized
        scope = .day
    }

    private func exitDayDrill(to previous: CalendarScope) {
        scope = previous
        scopeBeforeDayDrill = nil
    }

    private func date(on day: Date, hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? day
    }

    // MARK: - Month

    private var monthScope: some View {
        GeometryReader { geo in
            let gridWidth = max(0, geo.size.width)
            let colWidth = gridWidth / 7
            let headerHeight: CGFloat = 28
            let previewHeight: CGFloat = 132
            let cellHeight = max(52, (geo.size.height - headerHeight - calendarFABClearance - previewHeight) / 6)
            let days = monthDays(for: cursor)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                        Text(sym)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: colWidth, height: headerHeight, alignment: .center)
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(colWidth), spacing: 0), count: 7), spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        monthCell(day, width: colWidth, height: cellHeight)
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
                monthDayPreview
                    .frame(height: previewHeight)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, calendarFABClearance)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var monthDayPreview: some View {
        let items = dayCalendarItems(for: previewDay)
        let dayTitle: String = {
            let f = DateFormatter()
            f.dateFormat = Calendar.current.isDateInToday(previewDay) ? "'Today,' EEEE MMM d" : "EEEE, MMM d"
            return f.string(from: previewDay)
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Agenda") { openDayDetail(for: previewDay) }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.cta)
                    .accessibilityHint("Opens full day agenda")
            }
            if items.isEmpty {
                Text("Nothing scheduled — tap a day or + to add.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(items.prefix(3)) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                }
                if items.count > 3 {
                    Text("+\(items.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(monthPreviewAccessibilityLabel(day: previewDay, items: items))
    }

    private func monthPreviewAccessibilityLabel(day: Date, items: [CalendarDayItem]) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        var label = "Preview for \(f.string(from: day))"
        if items.isEmpty {
            label += ", nothing scheduled"
        } else {
            label += ", \(items.count) item\(items.count == 1 ? "" : "s")"
        }
        return label
    }

    private func monthCell(_ day: Date, width: CGFloat, height: CGFloat) -> some View {
        let inMonth = Calendar.current.isDate(day, equalTo: cursor, toGranularity: .month)
        let isToday = Calendar.current.isDateInToday(day)
        let isPreview = Calendar.current.isDate(previewDay, inSameDayAs: day)
        let items = dayCalendarItems(for: day)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 28, height: 28)
                } else if isPreview {
                    Circle()
                        .stroke(Theme.accent.opacity(0.65), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.black : dayNumberColor(inMonth: inMonth))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(items.prefix(3)) { item in
                        if let task = item.task {
                            Button {
                                openEditEvent(task)
                            } label: {
                                calendarEventChip(item.title, color: item.color, accessibilityLabel: "Event: \(item.title)")
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens event editor")
                        } else {
                            calendarEventChip(item.title, color: item.color, accessibilityLabel: "Workout: \(item.title)")
                        }
                    }
                    if items.count > 3 {
                        Text("+\(items.count - 3) more")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityLabel("\(items.count - 3) more events")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 2)
                .onEnded { openDayView(for: day) }
                .exclusively(before: TapGesture(count: 1).onEnded {
                    previewDay = Calendar.current.startOfDay(for: day)
                })
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(width: width, height: height, alignment: .topLeading)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.gridDivider)
                .frame(width: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.gridDivider)
                .frame(height: 0.5)
        }
        .opacity(inMonth ? 1 : 0.35)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(monthCellAccessibilityLabel(day: day, items: items, isToday: isToday, inMonth: inMonth))
        .accessibilityHint("Single tap to preview below. Double tap to open day view.")
        .accessibilityAddTraits(isToday ? [.isButton, .isSelected] : .isButton)
    }

    private func monthCellAccessibilityLabel(day: Date, items: [CalendarDayItem], isToday: Bool, inMonth: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        var label = f.string(from: day)
        if !inMonth { label += ", outside this month" }
        if isToday { label = "Today, \(label)" }
        if items.isEmpty {
            label += ", no events"
        } else if items.count == 1 {
            label += ", 1 item"
        } else {
            label += ", \(items.count) items"
        }
        return label
    }

    private func dayNumberColor(inMonth: Bool) -> Color {
        inMonth ? Theme.ink : Theme.muted
    }

    private func dayCalendarItems(for day: Date) -> [CalendarDayItem] {
        var items: [CalendarDayItem] = []
        if workoutsEnabled, let workout = WorkoutIntegration.scheduledSession(on: day, workoutsEnabled: true) {
            items.append(CalendarDayItem(title: workout.shortName, color: Theme.accent))
        }
        let dayEvents = calendarEvents(on: day)
        items.append(contentsOf: dayEvents.map {
            CalendarDayItem(title: $0.title, color: chipColor($0), task: $0)
        })
        return items
    }

    // MARK: - Week / day

    private func weekScope(days: Int) -> some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - timeGutter) / CGFloat(days)
            let start = weekStart(days: days)
            let columns = (0..<days).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
            let hours = Array(6...22)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: timeGutter, height: 44)
                    ForEach(columns, id: \.self) { day in
                        dayColumnHeader(day, width: colWidth)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded { openDayView(for: day) }
                                    .exclusively(before: TapGesture(count: 1).onEnded {
                                        cursor = Calendar.current.startOfDay(for: day)
                                    })
                            )
                            .accessibilityLabel(dayColumnAccessibilityLabel(day))
                            .accessibilityHint("Double tap to open day view")
                    }
                }
                Divider().overlay(Theme.gridDivider)
                allDayRow(columns: columns, colWidth: colWidth)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 0) {
                                Text(hourLabel(hour))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: timeGutter, height: hourRowHeight, alignment: .topLeading)
                                    .padding(.top, 4)
                                ForEach(columns, id: \.self) { day in
                                    weekHourCell(day: day, hour: hour, width: colWidth)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func allDayRow(columns: [Date], colWidth: CGFloat) -> some View {
        let hasAny = columns.contains { !allDayEvents(on: $0).isEmpty }
        guard hasAny else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    Text("all-day")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .frame(width: timeGutter, alignment: .topLeading)
                        .padding(.top, 4)
                    ForEach(columns, id: \.self) { day in
                        allDayCell(day: day, width: colWidth)
                    }
                }
                Divider().overlay(Theme.gridDivider)
            }
        )
    }

    private func allDayCell(day: Date, width: CGFloat) -> some View {
        let events = allDayEvents(on: day)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(events, id: \.id) { task in
                Button {
                    openEditEvent(task)
                } label: {
                    calendarEventChip(task.title, color: chipColor(task), accessibilityLabel: "All-day event: \(task.title)")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens event editor")
            }
        }
        .padding(2)
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: 28, alignment: .topLeading)
        .overlay {
            Rectangle()
                .stroke(Theme.gridDivider, lineWidth: 0.5)
        }
    }

    private func dayColumnHeader(_ day: Date, width: CGFloat) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        return VStack(spacing: 2) {
            Text(weekday(day))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.headline)
                .foregroundStyle(isToday ? Theme.accent : Theme.ink)
        }
        .frame(width: width, height: 44)
    }

    private func weekHourCell(day: Date, hour: Int, width: CGFloat) -> some View {
        let hourTasks = events(on: day, hour: hour)
        let workout = workoutEvents(on: day, hour: hour)
        let draft = draftSlot.flatMap { matchesDraft($0, day: day, hour: hour) ? $0 : nil }
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(Theme.gridDivider, lineWidth: 0.5)
                .contentShape(Rectangle())
                .onTapGesture {
                    openNewEvent(at: date(on: day, hour: hour))
                }
            VStack(alignment: .leading, spacing: 2) {
                if let draft {
                    ghostEventChip(draft)
                }
                if let session = workout {
                    calendarEventChip(session.name, color: Theme.accent, accessibilityLabel: "Workout: \(session.name)")
                }
                ForEach(hourTasks) { task in
                    Button {
                        openEditEvent(task)
                    } label: {
                        calendarEventChip(task.title, color: chipColor(task), accessibilityLabel: "Event: \(task.title)")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens event editor")
                }
            }
            .padding(2)
        }
        .frame(width: width, height: hourRowHeight, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            weekHourCellAccessibilityLabel(
                day: day,
                hour: hour,
                eventCount: hourTasks.count + (workout != nil ? 1 : 0),
                draftTime: draft.map { timeRangeLabel($0.start, $0.end) }
            )
        )
        .accessibilityHint("Double tap to add event")
        .accessibilityAddTraits(.isButton)
    }

    private func weekHourCellAccessibilityLabel(day: Date, hour: Int, eventCount: Int, draftTime: String? = nil) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let dayName = f.string(from: day)
        let time = hourLabel(hour)
        if let draftTime {
            return "\(dayName) \(time), new event draft at \(draftTime)"
        }
        if eventCount == 0 {
            return "\(dayName) \(time), empty time slot"
        }
        return "\(dayName) \(time), \(eventCount) event\(eventCount == 1 ? "" : "s")"
    }

    private func ghostEventChip(_ draft: DraftEventSlot) -> some View {
        let label = timeRangeLabel(draft.start, draft.end)
        return Text("\(label) · New Event")
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(2)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white.opacity(0.9))
            .background(Theme.accent.opacity(0.45), in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Theme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .accessibilityLabel("New event draft, \(label)")
            .accessibilityAddTraits(.isStaticText)
    }

    private func matchesDraft(_ draft: DraftEventSlot, day: Date, hour: Int) -> Bool {
        Calendar.current.isDate(draft.start, inSameDayAs: day)
            && Calendar.current.component(.hour, from: draft.start) == hour
    }

    private func timeRangeLabel(_ start: Date, _ end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: start)
    }

    private func calendarEventChip(_ title: String, color: Color, accessibilityLabel label: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(2)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.white)
            .accessibilityLabel(label)
    }

    private func weekStart(days: Int) -> Date {
        if days == 7 {
            return Calendar.current.dateInterval(of: .weekOfYear, for: cursor)?.start ?? cursor
        }
        return Calendar.current.startOfDay(for: cursor)
    }

    // MARK: - Year

    private var yearScope: some View {
        let months = (0..<12).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: yearStart(cursor)) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(months, id: \.self) { month in
                    Button {
                        cursor = month
                        scope = .month
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(PlannerDate.monthTitle(month))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month) ? Theme.accent : Theme.ink)
                            miniMonth(month)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(PlannerDate.monthTitle(month))\(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month) ? ", current month" : ""), open month view")
                    .accessibilityHint("Opens month calendar view")
                }
            }
            .padding(16)
        }
    }

    private func miniMonth(_ month: Date) -> some View {
        let days = monthDays(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(days, id: \.self) { day in
                let inMonth = Calendar.current.isDate(day, equalTo: month, toGranularity: .month)
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 8))
                    .foregroundStyle(Calendar.current.isDateInToday(day) ? Theme.accent : (inMonth ? Theme.muted : Color.clear))
            }
        }
    }

    private func events(on day: Date, hour: Int) -> [PlannerTaskEntity] {
        timedEvents(on: day).filter { task in
            guard let due = task.dueAt else { return false }
            return Calendar.current.component(.hour, from: due) == hour
        }
    }

    private func calendarEvents(on day: Date) -> [PlannerTaskEntity] {
        rebuildEventIndex()
        return eventsByDay[Calendar.current.startOfDay(for: day), default: []]
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private func rebuildEventIndex() {
        let stamp = tasks.reduce(0) { partial, task in
            var h = partial
            h ^= task.id.hashValue
            h ^= task.isCompleted ? 1 : 0
            h ^= Int(task.dueAt?.timeIntervalSince1970 ?? 0)
            return h
        }
        guard stamp != eventIndexStamp else { return }
        eventIndexStamp = stamp
        let cal = Calendar.current
        var index: [Date: [PlannerTaskEntity]] = [:]
        for task in tasks {
            guard let due = task.dueAt else { continue }
            let day = cal.startOfDay(for: due)
            index[day, default: []].append(task)
        }
        for key in index.keys {
            index[key]?.sort { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        }
        eventsByDay = index
    }

    private func timedEvents(on day: Date) -> [PlannerTaskEntity] {
        calendarEvents(on: day).filter { task in
            guard let due = task.dueAt else { return false }
            return hasTimeComponent(due)
        }
    }

    private func allDayEvents(on day: Date) -> [PlannerTaskEntity] {
        calendarEvents(on: day).filter { task in
            guard let due = task.dueAt else { return false }
            return !hasTimeComponent(due)
        }
    }

    private func hasTimeComponent(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
    }

    private func workoutEvents(on day: Date, hour: Int) -> WorkoutSessionTemplate? {
        guard workoutsEnabled else { return nil }
        guard hour == WorkoutIntegration.defaultWorkoutHour(on: day) else { return nil }
        return WorkoutIntegration.scheduledSession(on: day, workoutsEnabled: true)
    }

    private func chipColor(_ task: PlannerTaskEntity) -> Color {
        if !task.colorHex.isEmpty {
            return PlannerColor.from(hex: task.colorHex)
        }
        return TagCatalog.displayColor(for: task, in: modelContext)
    }

    private func monthDays(for month: Date) -> [Date] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let pad = firstWeekday - 1
        let start = cal.date(byAdding: .day, value: -pad, to: interval.start) ?? interval.start
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func yearStart(_ date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year], from: date)) ?? date
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func dayColumnAccessibilityLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        return "View agenda for \(f.string(from: day))"
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }
}
