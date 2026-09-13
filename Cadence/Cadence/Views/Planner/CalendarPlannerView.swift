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
    /// Notion / Outlook-style default: three focused days, month picker on pull-down.
    @State private var scope: CalendarScope = .threeDay
    @State private var scopeBeforeDayDrill: CalendarScope?
    @State private var cursor = Date()
    @State private var showScope = false
    @State private var eventContext: EventSheetContext?
    @State private var dayDetailContext: DayDetailContext?
    @State private var draftSlot: DraftEventSlot?
    @State private var eventsByDay: [Date: [PlannerTaskEntity]] = [:]
    @State private var eventIndexStamp: Int = 0
    @State private var previewDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var monthPickerExpanded = false
    @State private var pickerMonth = Date()
    /// When the pull-down month picker is open, tap the month title to jump years.
    @State private var pickerShowsYears = false
    /// Shared 3-day/week/day page offset so hour labels stay pinned while columns slide.
    @State private var periodDragX: CGFloat = 0
    @State private var periodSettling = false

    private let weekdaySymbols = ["S", "M", "Tu", "W", "Th", "F", "S"]
    private let hourRowHeight: CGFloat = 52
    private let timeGutter: CGFloat = 44
    /// Bottom inset so the add-event FAB does not cover the last month row.
    private let calendarFABClearance: CGFloat = 120

    private var workoutsEnabled: Bool {
        CadenceAppsPreferences.isVisible(.workout) && (profiles.first?.workoutsEnabled ?? true)
    }

    private var usesFocusChrome: Bool {
        scope == .threeDay || scope == .week || scope == .day
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch scope {
                case .year:
                    CalendarPeriodPager(onPage: shift) { step in
                        yearGrid(at: dateByShifting(cursor, steps: step))
                    }
                case .month:
                    CalendarPeriodPager(onPage: shift) { step in
                        monthGrid(at: dateByShifting(cursor, steps: step))
                    }
                case .week, .threeDay, .day:
                    focusScope
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .addEvent else { return }
            openNewEvent(at: defaultEventStart)
            appModel.requestedFABAction = nil
        }
        .confirmationDialog("View", isPresented: $showScope, titleVisibility: .visible) {
            ForEach(CalendarScope.focusOrdered) { item in
                Button(item.title) {
                    scopeBeforeDayDrill = nil
                    scope = item
                    if item == .threeDay || item == .week || item == .day {
                        monthPickerExpanded = false
                    }
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
        .onChange(of: cursor) { _, new in
            previewDay = Calendar.current.startOfDay(for: new)
            if !Calendar.current.isDate(new, equalTo: pickerMonth, toGranularity: .month) {
                pickerMonth = new
            }
        }
        .onAppear {
            rebuildEventIndex()
            pickerMonth = cursor
            previewDay = Calendar.current.startOfDay(for: cursor)
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.sm) {
            if scope == .day, let previous = scopeBeforeDayDrill {
                Button { exitDayDrill(to: previous) } label: {
                    HStack(spacing: Theme.Space.xs) {
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
                Menu {
                    ForEach(CalendarScope.focusOrdered) { item in
                        Button {
                            scopeBeforeDayDrill = nil
                            scope = item
                            if item == .threeDay || item == .week || item == .day {
                                monthPickerExpanded = false
                            }
                        } label: {
                            Label {
                                Text(scope == item ? "\(item.title) ✓" : item.title)
                            } icon: {
                                Image(systemName: item.icon)
                            }
                        }
                        .accessibilityLabel(scope == item ? "\(item.title) view, selected" : "\(item.title) view")
                    }
                } label: {
                    Image(systemName: scope.viewSwitcherSymbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Change view, \(scope.title)")
                .accessibilityHint("Choose day, 3 day, week, month, or year")
            }

            Spacer(minLength: 0)

            Button {
                if usesFocusChrome {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        monthPickerExpanded.toggle()
                        if monthPickerExpanded {
                            pickerMonth = cursor
                            pickerShowsYears = false
                        } else {
                            pickerShowsYears = false
                        }
                    }
                } else {
                    showScope = true
                }
            } label: {
                Text(headerTitle)
                    .font(Theme.title(.title2))
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(usesFocusChrome
                ? "\(headerTitle). Calendar \(monthPickerExpanded ? "expanded" : "collapsed")"
                : "Calendar view, \(headerTitle)")
            .accessibilityHint(usesFocusChrome
                ? "Double tap to \(monthPickerExpanded ? "hide" : "show") month picker"
                : "Double tap to change calendar view")
            .contextMenu {
                Button("Change view…") { showScope = true }
                Button("Previous") { shift(-1) }
                Button("Next") { shift(1) }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    cursor = .now
                    previewDay = Calendar.current.startOfDay(for: .now)
                    pickerMonth = .now
                }
            } label: {
                Text("TODAY")
                    .font(.caption.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.accent)
                    .frame(minWidth: 36, minHeight: 36)
            }
            .accessibilityLabel("Go to today")
            .accessibilityHint("Jumps calendar to today's date")
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
    }

    /// Month name only (Structured/TickTick-style) — no date range strip in the header.
    private var headerTitle: String {
        let f = DateFormatter()
        switch scope {
        case .year:
            f.dateFormat = "yyyy"
            return f.string(from: cursor)
        default:
            f.dateFormat = "MMMM"
            return f.string(from: cursor)
        }
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

    private func dateByShifting(_ date: Date, steps: Int) -> Date {
        guard steps != 0 else { return date }
        let cal = Calendar.current
        switch scope {
        case .year:
            return cal.date(byAdding: .year, value: steps, to: date) ?? date
        case .month:
            return cal.date(byAdding: .month, value: steps, to: date) ?? date
        case .week:
            return cal.date(byAdding: .weekOfYear, value: steps, to: date) ?? date
        case .threeDay:
            return cal.date(byAdding: .day, value: steps * 3, to: date) ?? date
        case .day:
            return cal.date(byAdding: .day, value: steps, to: date) ?? date
        }
    }

    private func shift(_ dir: Int) {
        cursor = dateByShifting(cursor, steps: dir)
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

    // MARK: - Focus (3-day / week / day) + pull-down month picker

    private var focusScope: some View {
        let days: Int = {
            switch scope {
            case .week: return 7
            case .day: return 1
            default: return 3
            }
        }()
        return VStack(spacing: 0) {
            if monthPickerExpanded {
                compactMonthPicker
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            monthPickerHandle
            focusWeekBoard(days: days)
                .padding(.bottom, calendarFABClearance * 0.35)
        }
    }

    private var monthPickerHandle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                monthPickerExpanded.toggle()
                if monthPickerExpanded {
                    pickerMonth = cursor
                    pickerShowsYears = false
                } else {
                    pickerShowsYears = false
                }
            }
        } label: {
            Capsule()
                .fill(Theme.muted.opacity(0.45))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(monthPickerExpanded ? "Hide month picker" : "Show month picker")
        .accessibilityHint(monthPickerExpanded
            ? "Collapses to the focused day columns"
            : "Expands a month grid to choose which days to view")
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    let dy = value.translation.height
                    withAnimation(.easeInOut(duration: 0.22)) {
                        if dy > 28 {
                            monthPickerExpanded = true
                            pickerMonth = cursor
                            pickerShowsYears = false
                        } else if dy < -28 {
                            monthPickerExpanded = false
                            pickerShowsYears = false
                        }
                    }
                }
        )
    }

    private var compactMonthPicker: some View {
        let cal = Calendar.current
        let year = cal.component(.year, from: pickerMonth)
        return VStack(spacing: Theme.Space.sm) {
            HStack {
                Button {
                    if pickerShowsYears {
                        pickerMonth = cal.date(byAdding: .year, value: -1, to: pickerMonth) ?? pickerMonth
                    } else {
                        pickerMonth = cal.date(byAdding: .month, value: -1, to: pickerMonth) ?? pickerMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel(pickerShowsYears ? "Previous year" : "Previous month")

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pickerShowsYears.toggle()
                    }
                } label: {
                    HStack(spacing: Theme.Space.xs) {
                        if pickerShowsYears {
                            Text(year, format: .number.grouping(.never))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        } else {
                            Text(verbatim: compactPickerTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        Image(systemName: pickerShowsYears ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pickerShowsYears ? "Year \(year)" : compactPickerTitle)
                .accessibilityHint(pickerShowsYears
                    ? "Double tap to return to month days"
                    : "Double tap to jump by year")

                Spacer()

                Button {
                    if pickerShowsYears {
                        pickerMonth = cal.date(byAdding: .year, value: 1, to: pickerMonth) ?? pickerMonth
                    } else {
                        pickerMonth = cal.date(byAdding: .month, value: 1, to: pickerMonth) ?? pickerMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel(pickerShowsYears ? "Next year" : "Next month")
            }
            .padding(.horizontal, Theme.Space.lg)

            if pickerShowsYears {
                compactYearPicker(centeredOn: year)
            } else {
                compactMonthDayGrid
            }
        }
        .padding(.top, Theme.Space.xs)
        .background(Theme.surface.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private var compactMonthDayGrid: some View {
        let days = monthDays(for: pickerMonth)
        return VStack(spacing: Theme.Space.sm) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                    Text(sym.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Space.md)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: Theme.Space.xs
            ) {
                ForEach(days, id: \.self) { day in
                    compactMonthDayCell(day)
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, Theme.Space.sm)
        }
    }

    /// Apple Calendar–style year grid — tap a year to land on the same month in that year.
    private func compactYearPicker(centeredOn year: Int) -> some View {
        let cal = Calendar.current
        let years = Array((year - 8)...(year + 7))
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.sm), count: 4),
            spacing: Theme.Space.sm
        ) {
            ForEach(years, id: \.self) { y in
                let isCurrent = y == cal.component(.year, from: .now)
                let isSelected = y == year
                Button {
                    var comps = cal.dateComponents([.year, .month, .day], from: pickerMonth)
                    comps.year = y
                    if let jumped = cal.date(from: comps) {
                        pickerMonth = jumped
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pickerShowsYears = false
                    }
                } label: {
                    Text(y, format: .number.grouping(.never))
                        .font(.subheadline.weight(isSelected || isCurrent ? .bold : .medium))
                        .foregroundStyle(isCurrent ? Color.white : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm + 2)
                        .background {
                            if isCurrent {
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.accent)
                            } else if isSelected {
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.accent.opacity(0.18))
                            }
                        }
                        .overlay {
                            if isSelected && !isCurrent {
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(y)\(isCurrent ? ", current year" : "")\(isSelected ? ", selected" : "")")
                .accessibilityHint("Shows \(compactPickerTitle) in \(y)")
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, Theme.Space.md)
    }

    private var compactPickerTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: pickerMonth)
    }

    private func compactMonthDayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let inMonth = cal.isDate(day, equalTo: pickerMonth, toGranularity: .month)
        let isToday = cal.isDateInToday(day)
        let isFocusStart = cal.isDate(day, inSameDayAs: cursor)
        let focusCount = scope == .week ? 7 : (scope == .day ? 1 : 3)
        let focusStart = weekStart(days: focusCount)
        let focusEnd = cal.date(byAdding: .day, value: focusCount - 1, to: focusStart) ?? focusStart
        let inFocus = inMonth && day >= focusStart && day <= focusEnd
        let hasItems = !dayCalendarItems(for: day).isEmpty
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                cursor = cal.startOfDay(for: day)
                previewDay = cursor
                // Stay expanded — dismiss only via header title or swipe up.
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.caption.weight(isToday || isFocusStart ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.white : (inMonth ? Theme.ink : Theme.muted.opacity(0.35)))
                    .frame(width: 30, height: 30)
                    .background {
                        Circle().fill(
                            isToday ? Theme.accent
                            : (inFocus ? Theme.accent.opacity(0.18) : Color.clear)
                        )
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                inFocus && !isToday ? Theme.accent.opacity(0.55) : Color.clear,
                                lineWidth: 1
                            )
                    }
                Circle()
                    .fill(hasItems && inMonth ? Theme.cta.opacity(0.9) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .disabled(!inMonth)
        .accessibilityLabel(compactMonthAccessibilityLabel(day: day, inFocus: inFocus, isToday: isToday, hasItems: hasItems))
        .accessibilityHint("Shows this day in the focused columns")
    }

    private func compactMonthAccessibilityLabel(day: Date, inFocus: Bool, isToday: Bool, hasItems: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        var label = f.string(from: day)
        if isToday { label = "Today, \(label)" }
        if inFocus { label += ", in focus" }
        if hasItems { label += ", has items" }
        return label
    }

    // MARK: - Month

    private func monthGrid(at pageCursor: Date) -> some View {
        GeometryReader { geo in
            let gridWidth = max(0, geo.size.width)
            let colWidth = gridWidth / 7
            let headerHeight: CGFloat = 28
            let cellHeight = max(44, (geo.size.height - headerHeight - calendarFABClearance) / 6)
            let days = monthDays(for: pageCursor)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                        Text(sym.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                            .frame(width: colWidth, height: headerHeight, alignment: .center)
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(colWidth), spacing: 0), count: 7), spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        monthCell(day, cursor: pageCursor, width: colWidth, height: cellHeight)
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, calendarFABClearance)
        }
    }

    private func monthCell(_ day: Date, cursor pageCursor: Date, width: CGFloat, height: CGFloat) -> some View {
        let inMonth = Calendar.current.isDate(day, equalTo: pageCursor, toGranularity: .month)
        let isToday = Calendar.current.isDateInToday(day)
        let isPreview = Calendar.current.isDate(previewDay, inSameDayAs: day)
        let items = dayCalendarItems(for: day)
        return VStack(spacing: Theme.Space.sm - 2) {
            ZStack {
                // Stable layers for every cell so the today fill does not trail the pager spring.
                Circle()
                    .fill(isToday ? Theme.accent : Color.clear)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(isPreview && !isToday ? Theme.accent.opacity(0.65) : Color.clear, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.white : dayNumberColor(inMonth: inMonth))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .transaction { $0.animation = nil }
            HStack(spacing: 3) {
                ForEach(0..<min(items.count, 3), id: \.self) { idx in
                    Circle()
                        .fill(items[idx].color.opacity(0.9))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 8)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 2)
                .onEnded { openDayDetail(for: day) }
                .exclusively(before: TapGesture(count: 1).onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cursor = Calendar.current.startOfDay(for: day)
                        previewDay = cursor
                        scope = .threeDay
                        monthPickerExpanded = false
                    }
                })
        )
        .padding(.horizontal, Theme.Space.xs)
        .padding(.vertical, Theme.Space.sm - 2)
        .frame(width: width, height: height, alignment: .top)
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
        .accessibilityHint("Single tap opens 3-day focus. Double tap opens day agenda.")
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

    /// Hour labels stay pinned; only the day columns page horizontally.
    private func focusWeekBoard(days: Int) -> some View {
        let hours = Array(6...22)
        let showAllDay = focusPagesHaveAllDay(days: days)
        return GeometryReader { geo in
            let columnWidth = max(geo.size.width - timeGutter, 1)
            let colWidth = columnWidth / CGFloat(days)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: timeGutter, height: 32)
                        .background(Theme.canvas)
                    CalendarPeriodStrip(pageWidth: columnWidth, dragX: periodDragX) { step in
                        focusDayHeaders(days: days, at: dateByShifting(cursor, steps: step), colWidth: colWidth)
                    }
                }
                if showAllDay {
                    HStack(alignment: .top, spacing: 0) {
                        Text("all-day")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                            .frame(width: timeGutter, alignment: .topLeading)
                            .padding(.top, Theme.Space.xs)
                            .background(Theme.canvas)
                        CalendarPeriodStrip(pageWidth: columnWidth, dragX: periodDragX) { step in
                            focusAllDayCells(days: days, at: dateByShifting(cursor, steps: step), colWidth: colWidth)
                        }
                    }
                    Divider().overlay(Theme.gridDivider)
                }
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { hour in
                                Text(hourLabel(hour))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: timeGutter, height: hourRowHeight, alignment: .topLeading)
                                    .padding(.top, Theme.Space.xs)
                            }
                        }
                        .background(Theme.canvas)
                        .zIndex(1)
                        CalendarPeriodStrip(pageWidth: columnWidth, dragX: periodDragX) { step in
                            focusHourGrid(days: days, at: dateByShifting(cursor, steps: step), colWidth: colWidth, hours: hours)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .modifier(
                CalendarPagerDragModifier(
                    width: columnWidth,
                    dragX: $periodDragX,
                    isSettling: $periodSettling,
                    onPage: shift
                )
            )
        }
        .onChange(of: scope) { _, _ in
            periodDragX = 0
            periodSettling = false
        }
    }

    private func focusPageColumns(days: Int, at pageCursor: Date) -> [Date] {
        let start = weekStart(days: days, cursor: pageCursor)
        return (0..<days).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func focusPagesHaveAllDay(days: Int) -> Bool {
        (-1...1).contains { step in
            focusPageColumns(days: days, at: dateByShifting(cursor, steps: step))
                .contains { !allDayEvents(on: $0).isEmpty }
        }
    }

    private func focusDayHeaders(days: Int, at pageCursor: Date, colWidth: CGFloat) -> some View {
        let columns = focusPageColumns(days: days, at: pageCursor)
        return HStack(spacing: 0) {
            ForEach(columns, id: \.self) { day in
                dayColumnHeader(day, width: colWidth)
            }
        }
        // Keep today badge + neighbor labels on one layer during the pager spring.
        .compositingGroup()
    }

    private func focusAllDayCells(days: Int, at pageCursor: Date, colWidth: CGFloat) -> some View {
        let columns = focusPageColumns(days: days, at: pageCursor)
        return HStack(alignment: .top, spacing: 0) {
            ForEach(columns, id: \.self) { day in
                allDayCell(day: day, width: colWidth)
            }
        }
    }

    private func focusHourGrid(days: Int, at pageCursor: Date, colWidth: CGFloat, hours: [Int]) -> some View {
        let columns = focusPageColumns(days: days, at: pageCursor)
        return VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(columns, id: \.self) { day in
                        weekHourCell(day: day, hour: hour, width: colWidth)
                    }
                }
            }
        }
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
        let dayNum = Calendar.current.component(.day, from: day)
        // Full weekday when columns are wide (day / 3-day); abbreviated for week.
        let weekdayName: String = {
            let f = DateFormatter()
            f.dateFormat = width >= 90 ? "EEEE" : "EEE"
            return f.string(from: day)
        }()
        return HStack(spacing: 4) {
            Text(weekdayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? Theme.accent : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(dayNum)")
                .font(.caption.weight(.bold))
                .foregroundStyle(isToday ? Color.white : Theme.ink)
                .frame(width: 22, height: 22)
                // Always allocate the circle so today does not form a separate animating layer.
                .background {
                    Circle().fill(isToday ? Theme.accent : Color.clear)
                }
        }
        .frame(width: width, height: 32)
        // Pager spring should move the strip as one unit — not re-animate badge chrome.
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let f = DateFormatter()
            f.dateStyle = .full
            let base = f.string(from: day)
            return isToday ? "Today, \(base)" : base
        }())
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
            .padding(.horizontal, Theme.Space.xs)
            .padding(.vertical, Theme.Space.xs - 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white.opacity(0.9))
            .background(Theme.accent.opacity(0.45), in: RoundedRectangle(cornerRadius: Theme.Space.xs))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Space.xs)
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
            .font(.system(size: 9, weight: .bold))
            .tracking(0.3)
            .lineLimit(2)
            .padding(.horizontal, Theme.Space.xs)
            .padding(.vertical, Theme.Space.xs - 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .foregroundStyle(.white)
            .accessibilityLabel(label)
    }

    private func weekStart(days: Int, cursor pageCursor: Date? = nil) -> Date {
        let ref = pageCursor ?? cursor
        if days == 7 {
            return Calendar.current.dateInterval(of: .weekOfYear, for: ref)?.start ?? ref
        }
        return Calendar.current.startOfDay(for: ref)
    }

    // MARK: - Year

    private func yearGrid(at pageCursor: Date) -> some View {
        let months = (0..<12).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: yearStart(pageCursor)) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Space.sm + 2), count: 3)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Space.lg) {
                ForEach(months, id: \.self) { month in
                    Button {
                        cursor = month
                        scope = .month
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.sm - 2) {
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

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }
}

/// Offset-only previous / current / next strip. Parent owns the drag.
private struct CalendarPeriodStrip<Page: View>: View {
    var pageWidth: CGFloat
    var height: CGFloat?
    var dragX: CGFloat
    @ViewBuilder var page: (Int) -> Page

    var body: some View {
        let width = max(pageWidth, 1)
        HStack(spacing: 0) {
            page(-1)
                .frame(width: width, height: height)
                .allowsHitTesting(false)
            page(0)
                .frame(width: width, height: height)
            page(1)
                .frame(width: width, height: height)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height, alignment: .leading)
        // GeometryEffect keeps every cell (including today chrome) on one animatable transform.
        .modifier(CalendarPagerOffsetEffect(x: -width + dragX))
        .clipped()
    }
}

private struct CalendarPagerOffsetEffect: GeometryEffect {
    var x: CGFloat

    var animatableData: CGFloat {
        get { x }
        set { x = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

private struct CalendarPagerDragModifier: ViewModifier {
    var width: CGFloat
    @Binding var dragX: CGFloat
    @Binding var isSettling: Bool
    var onPage: (Int) -> Void

    private enum DragAxis {
        case undecided, horizontal, vertical
    }

    @State private var axis: DragAxis = .undecided

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(pagerGesture)
            .accessibilityAdjustableAction { direction in
                guard !isSettling else { return }
                switch direction {
                case .increment: commit(1)
                case .decrement: commit(-1)
                @unknown default: break
                }
            }
    }

    private var pagerGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !isSettling else { return }
                let tx = value.translation.width
                let ty = value.translation.height
                if axis == .undecided, hypot(tx, ty) > 10 {
                    axis = abs(tx) > abs(ty) * 1.15 ? .horizontal : .vertical
                }
                if axis == .horizontal {
                    dragX = tx
                }
            }
            .onEnded { value in
                let locked = axis
                axis = .undecided
                guard locked == .horizontal, !isSettling else {
                    if dragX != 0 {
                        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88)) {
                            dragX = 0
                        }
                    }
                    return
                }
                let tx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if tx < -width * 0.18 || predicted < -width * 0.42 {
                    commit(1)
                } else if tx > width * 0.18 || predicted > width * 0.42 {
                    commit(-1)
                } else {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88)) {
                        dragX = 0
                    }
                }
            }
    }

    private func commit(_ dir: Int) {
        guard !isSettling else { return }
        isSettling = true
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            dragX = -width * CGFloat(dir)
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onPage(dir)
                dragX = 0
            }
            isSettling = false
        }
    }
}

/// Standalone pager (month / year) — previous / current / next with a finger-following spring.
private struct CalendarPeriodPager<Page: View>: View {
    var onPage: (Int) -> Void
    @ViewBuilder var page: (Int) -> Page

    @State private var dragX: CGFloat = 0
    @State private var isSettling = false

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            CalendarPeriodStrip(pageWidth: width, height: geo.size.height, dragX: dragX, page: page)
                .contentShape(Rectangle())
                .modifier(
                    CalendarPagerDragModifier(
                        width: width,
                        dragX: $dragX,
                        isSettling: $isSettling,
                        onPage: onPage
                    )
                )
        }
    }
}
