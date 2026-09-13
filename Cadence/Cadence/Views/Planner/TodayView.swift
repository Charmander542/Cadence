import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \PlannerTaskEntity.createdAt) private var tasks: [PlannerTaskEntity]
    @Query(sort: \HabitEntity.sortOrder) private var habits: [HabitEntity]
    @Query(sort: \TaskListEntity.sortOrder) private var lists: [TaskListEntity]
    @Query(sort: \PlannerTagEntity.name) private var plannerTags: [PlannerTagEntity]

    var destination: PlannerDestination
    var onOpenDrawer: () -> Void

    @State private var showQuickAdd = false
    @State private var editingTask: PlannerTaskEntity?
    @State private var editingEvent: EventSheetContext?
    @State private var editingHabit: HabitEntity?
    @State private var editingNote: PlannerNoteEntity?
    @State private var listContentMode: ListContentMode = .tasks
    @State private var pendingUndo: TodayUndoAction?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var showCompleted = false
    @State private var collapsed: Set<String> = ["completed"]

    private var supportsListNotes: Bool {
        switch destination {
        case .list, .inbox: return true
        default: return false
        }
    }

    private var notesListID: UUID? {
        switch destination {
        case .list(let id): return id
        case .inbox: return lists.first { $0.name == "Inbox" }?.id
        default: return nil
        }
    }

    private var todayHabits: [HabitEntity] {
        habits.filter { $0.isScheduled(on: .now) }
    }

    private var title: String {
        switch destination {
        case .today: return "Today"
        case .next7: return "Next 7 Days"
        case .inbox: return "Inbox"
        case .list(let id): return lists.first { $0.id == id }?.name ?? "List"
        default: return "Today"
        }
    }

    private var quickAddInitialDue: Date? {
        switch destination {
        case .inbox: return nil
        case .today, .next7: return Calendar.current.startOfDay(for: .now)
        default: return Calendar.current.startOfDay(for: .now)
        }
    }

    private var quickAddInitialListID: UUID? {
        switch destination {
        case .list(let id): return id
        case .inbox: return lists.first { $0.name == "Inbox" }?.id
        default: return lists.first { $0.name == "Inbox" }?.id
        }
    }

    private var visibleTasks: [PlannerTaskEntity] {
        switch destination {
        case .today:
            return tasks.filter { task in
                if task.isEvent { return false }
                if task.isCompleted { return false }
                if task.isOverdue { return true }
                if let due = task.dueAt { return Calendar.current.isDateInToday(due) }
                if task.dueAt == nil {
                    return task.list?.showInToday ?? false
                }
                return false
            }
        case .next7:
            return tasks.filter { task in
                if task.isEvent { return false }
                if task.isCompleted { return false }
                guard let due = task.dueAt else { return false }
                return PlannerDate.isInNext7Days(due) || task.isOverdue
            }
        case .inbox:
            return tasks.filter { !$0.isEvent && !$0.isCompleted && $0.list?.name == "Inbox" }
        case .list(let id):
            return tasks.filter { !$0.isEvent && !$0.isCompleted && $0.list?.id == id }
        default:
            return []
        }
    }

    private var overdue: [PlannerTaskEntity] {
        visibleTasks.filter { $0.isOverdue && !$0.isCompleted }
    }

    private var openToday: [PlannerTaskEntity] {
        visibleTasks.filter { !$0.isCompleted && !$0.isOverdue }
    }

    private var todayEvents: [PlannerTaskEntity] {
        guard destination == .today else { return [] }
        return tasks.filter { task in
            guard task.isEvent, !task.isCompleted else { return false }
            guard let due = task.dueAt else { return false }
            return Calendar.current.isDateInToday(due)
        }
        .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var completedEventsToday: [PlannerTaskEntity] {
        guard destination == .today else { return [] }
        return tasks.filter { task in
            guard task.isEvent, task.isCompleted else { return false }
            if let due = task.dueAt, Calendar.current.isDateInToday(due) { return true }
            if let completedAt = task.completedAt, Calendar.current.isDateInToday(completedAt) { return true }
            return false
        }
        .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var completedToday: [PlannerTaskEntity] {
        guard destination == .today else {
            return visibleTasks.filter(\.isCompleted)
        }
        return tasks.filter { task in
            guard !task.isEvent, task.isCompleted,
                  Calendar.current.isDateInToday(task.completedAt ?? .now)
            else { return false }
            if let due = task.dueAt {
                return Calendar.current.isDateInToday(due) || task.completedAt.map { Calendar.current.isDateInToday($0) } == true
            }
            return task.list?.showInToday ?? false
        }
    }

    private var openHabits: [HabitEntity] {
        todayHabits.filter { !$0.isDone(on: .now) }
    }

    private var completedHabits: [HabitEntity] {
        todayHabits.filter { $0.isDone(on: .now) }
    }

    private var completedCount: Int {
        completedToday.count
            + completedEventsToday.count
            + (destination == .today ? completedHabits.count : 0)
    }

    private var isMorningFocus: Bool {
        Calendar.current.component(.hour, from: .now) < 12
    }

    private var isEveningFocus: Bool {
        Calendar.current.component(.hour, from: .now) >= 17
    }

    var body: some View {
        todayContent
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTopBar(
                title: title,
                onMenu: onOpenDrawer,
                showSearchInBar: false
            )
            if supportsListNotes {
                listModePicker
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.bottom, Theme.Space.sm)
            }
            if supportsListNotes && listContentMode == .notes {
                ListNotesPane(
                    listID: notesListID,
                    onOpenNote: { editingNote = $0 },
                    onCreateNote: { createNote() }
                )
                .padding(.horizontal, Theme.Space.lg)
                .padding(.bottom, PlannerChromeMetrics.dialFABClearance)
            } else {
            ScrollView {
                VStack(spacing: Theme.Space.sm) {
                    if destination == .today {
                        todayHeroCards
                    }
                    if destination == .today,
                       overdue.isEmpty && openToday.isEmpty && todayEvents.isEmpty && openHabits.isEmpty && completedCount == 0 {
                        Theme.EmptyState(
                            systemImage: "checkmark.circle",
                            title: "All clear",
                            message: "No tasks or habits due today. Add something from the + button.",
                            cta: "Add task",
                            ctaHint: "Opens quick add for a new task"
                        ) {
                            showQuickAdd = true
                        }
                        .frame(minHeight: 120)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("All clear. No tasks or habits due today. Add a task from the add button.")
                    }
                    if visibleTasks.isEmpty && overdue.isEmpty && completedCount == 0 && destination != .today {
                        Theme.EmptyState(
                            systemImage: "checkmark.circle",
                            title: "Nothing scheduled",
                            message: "Tap + to add a task, or open Meals to plan dinner.",
                            cta: "Add task",
                            ctaHint: "Opens quick add for a new task"
                        ) {
                            showQuickAdd = true
                        }
                        .frame(minHeight: 220)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Nothing scheduled. Tap add task or open Meals to plan dinner.")
                    }
                    if !overdue.isEmpty {
                        sectionCard(id: "overdue", title: "Overdue", count: overdue.count, trailing: postponeMenu) {
                            ForEach(overdue) { task in
                                taskRow(task)
                            }
                        }
                    }
                    if destination == .today, !todayEvents.isEmpty {
                        sectionCard(id: "events", title: "Events", count: todayEvents.count) {
                            ForEach(todayEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                    if destination == .today, !openHabits.isEmpty {
                        sectionCard(id: "habits", title: "Habits", count: openHabits.count) {
                            ForEach(openHabits) { habit in
                                habitRow(habit, showSkip: true)
                            }
                        }
                    }
                    if destination == .today, !openToday.isEmpty {
                        sectionCard(id: "tasks", title: "Tasks", count: openToday.count) {
                            ForEach(openToday.prefix(5)) { task in
                                taskRow(task)
                            }
                        }
                    } else if destination == .today,
                              openToday.isEmpty,
                              !(overdue.isEmpty && todayEvents.isEmpty && openHabits.isEmpty && completedCount == 0) {
                        sectionCard(id: "tasks", title: "Tasks", count: 0) {
                            Button { showQuickAdd = true } label: {
                                HStack(spacing: Theme.Space.sm + 2) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.body)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Theme.cta)
                                    Text("ADD TASK")
                                        .font(.caption.weight(.bold))
                                        .tracking(0.7)
                                        .foregroundStyle(Theme.cta)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, Theme.Space.md + 2)
                                .padding(.vertical, Theme.Space.sm + 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add task")
                            .accessibilityHint("Opens quick add for a new task")
                        }
                    }
                    if !openToday.isEmpty && destination != .today {
                        VStack(spacing: 0) {
                            ForEach(openToday) { task in
                                taskRow(task)
                                    .padding(.horizontal, Theme.Space.md + 2)
                                    .padding(.vertical, Theme.Space.sm + 2)
                            }
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    }
                    if completedCount > 0 {
                        completedSection
                    }
                }
                .padding(Theme.Space.lg)
                .padding(.bottom, Theme.Space.xl * 5 + Theme.Space.md)
            }
            } // end tasks scroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .dialFABChrome(
            leading: {
                Group {
                    if pendingUndo != nil {
                        UndoFAB(accessibilityHint: todayUndoAccessibilityHint) {
                            performUndo()
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: pendingUndo != nil)
            },
            fab: { EmptyView() }
        )
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .todayQuickAdd else { return }
            if supportsListNotes && listContentMode == .notes {
                createNote()
            } else {
                showQuickAdd = true
            }
            appModel.requestedFABAction = nil
        }
        .onChange(of: destination) { _, _ in
            listContentMode = .tasks
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(
                initialDue: quickAddInitialDue,
                initialListID: quickAddInitialListID,
                startsWithoutDue: destination == .inbox
            )
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
        .sheet(item: $editingEvent) { context in
            PlannerEventSheet(context: context)
        }
        .sheet(item: $editingHabit) { habit in
            NewHabitSheet(habit: habit)
        }
        .sheet(item: $editingNote) { note in
            NoteEditorView(note: note)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var listModePicker: some View {
        Picker("Content", selection: $listContentMode) {
            ForEach(ListContentMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("List content")
    }

    private func createNote() {
        let list: TaskListEntity?
        switch destination {
        case .list(let id):
            list = lists.first { $0.id == id }
        case .inbox:
            list = lists.first { $0.name == "Inbox" } ?? PlannerStore.ensureInbox(in: modelContext)
        default:
            list = PlannerStore.ensureInbox(in: modelContext)
        }
        let note = PlannerStore.addNote(to: list, in: modelContext)
        editingNote = note
    }

    @ViewBuilder
    private var todayHeroCards: some View {
        if isEveningFocus {
            TonightMealCard(compact: true, promoted: true)
            WorkoutDayCard(compact: true)
        } else if isMorningFocus {
            WorkoutDayCard(compact: true, promoted: true)
            TonightMealCard(compact: true)
        } else {
            WorkoutDayCard()
            TonightMealCard()
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showCompleted.toggle()
            } label: {
                HStack {
                    Text("Completed")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(completedCount)")
                        .foregroundStyle(Theme.muted)
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .foregroundStyle(Theme.muted)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, Theme.Space.md + 2)
                .padding(.vertical, Theme.Space.md)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completed, \(completedCount) items")
            .accessibilityValue(showCompleted ? "Expanded" : "Collapsed")
            .accessibilityHint("Double tap to show or hide completed tasks, events, and habits")

            if showCompleted {
                if !completedToday.isEmpty {
                    ForEach(completedToday) { task in
                        taskRow(task)
                    }
                }
                if destination == .today {
                    ForEach(completedEventsToday) { event in
                        eventRow(event, completed: true)
                    }
                    ForEach(completedHabits) { habit in
                        habitRow(habit)
                    }
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var postponeMenu: AnyView {
        AnyView(
            Menu {
                Button("Tomorrow") { postponeOverdue(days: 1) }
                    .accessibilityHint("Moves all overdue tasks to tomorrow")
                Button("In 3 days") { postponeOverdue(days: 3) }
                    .accessibilityHint("Moves all overdue tasks three days forward")
                Button("Next week") { postponeOverdue(days: 7) }
                    .accessibilityHint("Moves all overdue tasks one week forward")
            } label: {
                HStack(spacing: Theme.Space.xs) {
                    Text("Postpone")
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            .accessibilityLabel("Postpone \(overdue.count) overdue task\(overdue.count == 1 ? "" : "s")")
            .accessibilityHint("Move all overdue tasks to tomorrow, three days, or next week")
        )
    }

    private func sectionCard<Content: View>(
        id: String,
        title: String,
        count: Int,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isCollapsed = collapsed.contains(id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isCollapsed { collapsed.remove(id) } else { collapsed.insert(id) }
            } label: {
                HStack(spacing: Theme.Space.sm) {
                    Text(title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(id == "overdue" ? Theme.danger : Theme.muted)
                    Theme.CountBadge(count: count, emphasized: id == "tasks")
                    Spacer()
                    if let trailing { trailing }
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .foregroundStyle(Theme.muted)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, Theme.Space.md + 2)
                .padding(.vertical, Theme.Space.md)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(count) items")
            .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
            .accessibilityHint("Double tap to show or hide")
            if !isCollapsed {
                Divider().overlay(Theme.gridDivider).padding(.horizontal, Theme.Space.md + 2)
                content()
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var tagColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: plannerTags.map { ($0.name, PlannerColor.from(hex: $0.colorHex)) })
    }

    private func taskRow(_ task: PlannerTaskEntity) -> some View {
        HStack(spacing: Theme.Space.md) {
            TaskCheckbox(completed: task.isCompleted, overdue: task.isOverdue) {
                toggleTask(task)
            }
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(task.title)
                    .foregroundStyle(task.isCompleted ? Theme.muted : Theme.ink)
                    .strikethrough(task.isCompleted)
                if !task.tags.isEmpty {
                    TaskTagChips(tags: task.tags, colorMap: tagColorMap)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingTask = task }
            if let due = task.dueAt {
                Theme.MetaPill(
                    text: PlannerDate.shortDue(due),
                    tone: task.isOverdue && !task.isCompleted ? .danger : .accent
                )
            }
        }
        .padding(.horizontal, Theme.Space.md + 2)
        .padding(.vertical, Theme.Space.sm + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(taskRowAccessibilityLabel(task))
        .accessibilityHint("Double tap to edit")
    }

    private func eventRow(_ event: PlannerTaskEntity, completed: Bool = false) -> some View {
        HStack(spacing: Theme.Space.sm) {
            CountdownTrackButton(eventID: event.id)
            Button {
                editingEvent = EventSheetContext(task: event, startDate: event.dueAt ?? .now)
            } label: {
                HStack(spacing: Theme.Space.sm + 2) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(PlannerColor.from(hex: event.colorHex.isEmpty ? PlannerColor.palette[0] : event.colorHex))
                        .frame(width: 3, height: 18)
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundStyle(completed ? Theme.muted : Theme.ink)
                        .strikethrough(completed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let due = event.dueAt {
                        Text(due, style: .time)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(todayEventAccessibilityLabel(event, completed: completed))
            .accessibilityHint("Double tap to edit event")
        }
        .padding(.horizontal, Theme.Space.md + 2)
        .padding(.vertical, Theme.Space.sm + 2)
    }

    private func todayEventAccessibilityLabel(_ event: PlannerTaskEntity, completed: Bool) -> String {
        var parts = [event.title, "event"]
        if completed { parts.append("completed") }
        if CountdownTracking.isTracked(event.id) { parts.append("countdown tracked") }
        if let due = event.dueAt {
            parts.append(due.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: ", ")
    }

    private func taskRowAccessibilityLabel(_ task: PlannerTaskEntity) -> String {
        var parts = [task.title]
        if task.isCompleted { parts.append("completed") }
        else if task.isOverdue { parts.append("overdue") }
        if let due = task.dueAt { parts.append(PlannerDate.shortDue(due)) }
        if !task.tags.isEmpty { parts.append("tags: \(task.tags.joined(separator: ", "))") }
        return parts.joined(separator: ", ")
    }

    private func habitRow(_ habit: HabitEntity, showSkip: Bool = false) -> some View {
        let done = habit.isDone(on: .now)
        return HStack(spacing: Theme.Space.md) {
            Button {
                toggleHabit(habit)
            } label: {
                HabitIconBadge(
                    symbol: habit.icon,
                    colorHex: habit.iconColorHex,
                    size: 32,
                    completed: done
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark \(habit.name) incomplete" : "Complete \(habit.name)")
            .accessibilityHint(habit.isScheduled(on: .now) ? "Double tap to mark habit complete or incomplete" : "Not scheduled today")
            Text(habit.name)
                .foregroundStyle(done ? Theme.muted : Theme.ink)
                .strikethrough(done)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { editingHabit = habit }
            if showSkip, !done {
                Button {
                    skipHabit(habit)
                } label: {
                    Text("SKIP")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.Space.sm)
                        .padding(.vertical, Theme.Space.sm - 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip habit")
                .accessibilityHint("Marks habit skipped for today without completing it")
            }
        }
        .padding(.horizontal, Theme.Space.md + 2)
        .padding(.vertical, Theme.Space.sm + 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(todayHabitRowAccessibilityLabel(habit, done: done))
        .accessibilityHint("Use complete or skip buttons. Double tap habit name to edit.")
    }

    private func todayHabitRowAccessibilityLabel(_ habit: HabitEntity, done: Bool) -> String {
        var parts = [habit.name]
        if done { parts.append("completed today") }
        else if habit.log(on: .now)?.status == .skipped { parts.append("skipped today") }
        if !habit.isScheduled(on: .now) { parts.append("not scheduled today") }
        return parts.joined(separator: ", ")
    }

    private func toggleTask(_ task: PlannerTaskEntity) {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
            pendingUndo = nil
            undoDismissTask?.cancel()
        } else {
            appModel.taskCompletionHaptic()
            let snapshot = TodayUndoAction.task(task)
            task.isCompleted = true
            task.completedAt = .now
            scheduleUndo(snapshot)
        }
        try? modelContext.save()
        Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
        WidgetSnapshotWriter.publish(in: modelContext)
    }

    private func toggleHabit(_ habit: HabitEntity) {
        let existing = habit.log(on: .now)
        if existing?.status == .done {
            existing.map { modelContext.delete($0) }
            pendingUndo = nil
            undoDismissTask?.cancel()
        } else {
            appModel.taskCompletionHaptic()
            let previousStatus = existing?.status
            if let existing {
                modelContext.delete(existing)
            }
            modelContext.insert(HabitLogEntity(day: .now, status: .done, habit: habit))
            scheduleUndo(.habit(habit, previousStatus: previousStatus))
        }
        try? modelContext.save()
        WidgetSnapshotWriter.publish(in: modelContext)
    }

    private var todayUndoAccessibilityHint: String {
        switch pendingUndo {
        case .task:
            return "Marks the task incomplete again"
        case .habit:
            return "Restores the previous habit status for today"
        case nil:
            return "Restores the last change on Today"
        }
    }

    private func scheduleUndo(_ action: TodayUndoAction) {
        pendingUndo = action
        undoDismissTask?.cancel()
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                pendingUndo = nil
            }
        }
    }

    private func performUndo() {
        undoDismissTask?.cancel()
        guard let action = pendingUndo else { return }
        pendingUndo = nil
        switch action {
        case .task(let task):
            task.isCompleted = false
            task.completedAt = nil
            try? modelContext.save()
            Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
        case .habit(let habit, let previousStatus):
            if let log = habit.log(on: .now) {
                modelContext.delete(log)
            }
            if let previousStatus {
                modelContext.insert(HabitLogEntity(day: .now, status: previousStatus, habit: habit))
            }
            try? modelContext.save()
        }
        WidgetSnapshotWriter.publish(in: modelContext)
    }

    private func postponeOverdue(days: Int) {
        for task in overdue {
            let base = task.dueAt ?? .now
            task.dueAt = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: base))
        }
        try? modelContext.save()
        WidgetSnapshotWriter.publish(in: modelContext)
    }

    private func skipHabit(_ habit: HabitEntity) {
        if let existing = habit.log(on: .now) {
            existing.status = .skipped
        } else {
            modelContext.insert(HabitLogEntity(day: .now, status: .skipped, habit: habit))
        }
        try? modelContext.save()
        WidgetSnapshotWriter.publish(in: modelContext)
    }

}

private enum TodayUndoAction {
    case task(PlannerTaskEntity)
    case habit(HabitEntity, previousStatus: HabitLogStatus?)
}

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskListEntity.sortOrder) private var lists: [TaskListEntity]
    @Query(sort: \PlannerTagEntity.name) private var plannerTags: [PlannerTagEntity]

    /// Pre-fill due date when opened from Today / calendar day.
    var initialDue: Date? = nil
    /// Prefer a specific list (Inbox / custom list).
    var initialListID: UUID? = nil
    /// Inbox opens without a due date; Today defaults to today.
    var startsWithoutDue: Bool = false

    @State private var title = ""
    @State private var notes = ""
    @State private var due = Calendar.current.startOfDay(for: .now)
    @State private var hasDue = true
    @State private var hasReminder = false
    @State private var priority: TaskPriority = .none
    @State private var selectedTags: [String] = []
    @State private var listID: UUID?
    @State private var showDatePicker = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, notes }

    private var parsed: ParsedTaskTitle {
        TaskTitleParser.parse(title)
    }

    private var pickerLists: [TaskListEntity] {
        PlannerStore.visibleTaskLists(lists)
    }

    private var selectedListName: String {
        pickerLists.first { $0.id == listID }?.name ?? "Inbox"
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tagColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: plannerTags.map { ($0.name, PlannerColor.from(hex: $0.colorHex)) })
    }

    private var dueChipLabel: String {
        guard hasDue else { return "Date" }
        if Calendar.current.isDateInToday(due) { return "Today" }
        if Calendar.current.isDateInTomorrow(due) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: due)
    }

    var body: some View {
        // Things 3–style dark compose: title + notes, status + icons, list + Save.
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 28, height: 28)
                        .background(Theme.sunken, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.sm)

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack(alignment: .top, spacing: Theme.Space.sm) {
                    Theme.CheckGlyph(checked: false)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        TextField("New To-Do", text: $title, axis: .vertical)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1...3)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                            .onChange(of: title) { _, _ in applyParsedHints() }
                            .accessibilityLabel("Task title")
                            .accessibilityHint("Try tomorrow or #tag for smart hints")

                        TextField("Notes", text: $notes, axis: .vertical)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1...4)
                            .focused($focusedField, equals: .notes)
                            .accessibilityLabel("Notes")
                    }
                }

                if parsed.dueDate != nil || !parsed.tags.isEmpty {
                    SmartTitleHints(parsed: parsed, tagColors: tagColorMap)
                }
                if !selectedTags.isEmpty {
                    TaskTagChips(tags: selectedTags, colorMap: tagColorMap)
                }

                // Things row: scheduled status left, metadata icons right.
                HStack(spacing: Theme.Space.sm) {
                    if hasDue {
                        Label(dueChipLabel, systemImage: Calendar.current.isDateInToday(due) ? "star.fill" : "calendar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Calendar.current.isDateInToday(due) ? Theme.accent : Theme.danger)
                            .accessibilityLabel("Due \(dueChipLabel)")
                    }
                    if priority != .none {
                        Label(priority.shortLabel, systemImage: "flag.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(priority.flagColor)
                    }
                    if hasReminder {
                        Image(systemName: "bell.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.cta)
                            .accessibilityLabel("Reminder on")
                    }

                    Spacer(minLength: 0)

                    dueToolbarButton
                    tagToolbarMenu
                    Button {
                        hasReminder.toggle()
                        if hasReminder { hasDue = true }
                    } label: {
                        toolbarIcon(
                            hasReminder ? "bell.fill" : "bell",
                            tint: hasReminder ? Theme.cta : Theme.muted,
                            active: hasReminder
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remind me, \(hasReminder ? "on" : "off")")

                    PriorityPickerMenu(priority: $priority) {
                        toolbarIcon(
                            priority == .none ? "flag" : "flag.fill",
                            tint: priority == .none ? Theme.muted : priority.flagColor,
                            active: priority != .none
                        )
                    }
                    .accessibilityLabel("Priority, \(priority.title)")
                }
                .padding(.top, Theme.Space.xs)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.bottom, Theme.Space.md)

            Divider().overlay(Theme.hairline)

            // Footer — Things Inbox + Save.
            HStack(spacing: Theme.Space.sm) {
                Menu {
                    ForEach(pickerLists) { list in
                        Button(list.name) { listID = list.id }
                    }
                } label: {
                    HStack(spacing: Theme.Space.xs) {
                        Image(systemName: selectedListName == "Inbox" ? "tray.fill" : "folder.fill")
                            .font(.caption.weight(.semibold))
                        Text(selectedListName)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Theme.cta)
                }
                .accessibilityLabel("List, \(selectedListName)")

                Spacer(minLength: 0)

                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canSave ? Color.white : Theme.muted)
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.vertical, Theme.Space.sm + 2)
                        .background(canSave ? Theme.cta : Theme.sunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityLabel("Save task")
                .accessibilityHint(canSave ? "Creates task in \(selectedListName)" : "Enter a task title to save")
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.md)
        }
        .background(Theme.surface)
        .tint(Theme.cta)
        .presentationDetents([.height(300), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
        .onAppear {
            if let initialListID, pickerLists.contains(where: { $0.id == initialListID }) {
                listID = initialListID
            } else {
                listID = lists.first { $0.name == "Inbox" }?.id
            }
            if startsWithoutDue, initialDue == nil {
                hasDue = false
            } else if let initialDue {
                due = Calendar.current.startOfDay(for: initialDue)
                hasDue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedField = .title
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DueDatePickerSheet(date: $due, hasDue: $hasDue)
        }
    }

    private var dueToolbarButton: some View {
        Menu {
            Button {
                hasDue = true
                due = Calendar.current.startOfDay(for: .now)
            } label: {
                Label("Today", systemImage: "sun.max")
            }
            Button {
                hasDue = true
                due = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
            } label: {
                Label("Tomorrow", systemImage: "sunrise")
            }
            Button {
                hasDue = true
                due = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: .now)) ?? .now
            } label: {
                Label("Next week", systemImage: "calendar")
            }
            Button {
                showDatePicker = true
            } label: {
                Label("Pick date…", systemImage: "calendar.badge.plus")
            }
            Divider()
            Button {
                hasDue = false
                hasReminder = false
            } label: {
                Label("No date", systemImage: "xmark.circle")
            }
        } label: {
            toolbarIcon(
                "calendar",
                tint: hasDue ? Theme.danger : Theme.muted,
                active: hasDue
            )
        }
        .accessibilityLabel("Due date, \(hasDue ? dueChipLabel : "none")")
    }

    private var tagToolbarMenu: some View {
        Menu {
            if plannerTags.isEmpty {
                Text("No tags yet — type #tag in the title")
            } else {
                ForEach(plannerTags) { tag in
                    Button {
                        toggleTag(tag.name)
                    } label: {
                        if selectedTags.contains(where: { $0.caseInsensitiveCompare(tag.name) == .orderedSame }) {
                            Label(tag.name, systemImage: "checkmark")
                        } else {
                            Text(tag.name)
                        }
                    }
                }
            }
        } label: {
            toolbarIcon(
                "tag",
                tint: selectedTags.isEmpty ? Theme.muted : Theme.accent,
                active: !selectedTags.isEmpty
            )
        }
        .accessibilityLabel("Tags")
    }

    private func toolbarIcon(_ systemImage: String, tint: Color, active: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .opacity(active ? 1 : 0.85)
    }

    private func toggleTag(_ name: String) {
        if let idx = selectedTags.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            selectedTags.remove(at: idx)
        } else {
            selectedTags.append(name)
        }
    }

    private func applyParsedHints() {
        let p = TaskTitleParser.parse(title)
        if let date = p.dueDate {
            hasDue = true
            due = date
        }
    }

    private func save() {
        guard canSave else { return }
        let list = lists.first { $0.id == listID }
        let reminderAt: Date? = {
            guard hasDue, hasReminder else { return nil }
            if let explicit = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: due) {
                return explicit
            }
            return due
        }()
        PlannerStore.addTask(
            title: title,
            due: hasDue ? due : nil,
            priority: priority,
            list: list,
            tags: selectedTags,
            notes: notes,
            reminderAt: reminderAt,
            in: modelContext
        )
        dismiss()
    }
}

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: PlannerTaskEntity
    @Query(sort: \TaskListEntity.sortOrder) private var lists: [TaskListEntity]
    @Query(sort: \PlannerTagEntity.name) private var plannerTags: [PlannerTagEntity]
    @State private var hasReminder = false
    @State private var sheetDetent: PresentationDetent = Self.compactDetent

    private static let compactDetent = PresentationDetent.height(460)
    private static let expandedDetent = PresentationDetent.large

    private var tagColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: plannerTags.map { ($0.name, PlannerColor.from(hex: $0.colorHex)) })
    }

    private var pickerLists: [TaskListEntity] {
        PlannerStore.visibleTaskLists(lists)
    }

    private var taskDueAccessibilityLabel: String {
        if let due = task.dueAt {
            return "Due, \(taskDateTimeLabel(due))"
        }
        return "Due, not set"
    }

    private var taskRemindAtAccessibilityLabel: String {
        let when = task.reminderAt ?? task.dueAt ?? .now
        return "Remind at, \(taskDateTimeLabel(when))"
    }

    private func taskDateTimeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $task.title)
                        .font(.title3.weight(.semibold))
                        .onChange(of: task.title) { _, newValue in
                            let parsed = TaskTitleParser.parse(newValue)
                            if let date = parsed.dueDate { task.dueAt = date }
                            if !parsed.tags.isEmpty { task.tags = parsed.tags }
                        }
                        .accessibilityLabel("Title")
                        .accessibilityValue(task.title.isEmpty ? "Empty" : task.title)
                        .accessibilityHint("Task name; use #tag or tomorrow in title for smart hints")
                    if !task.tags.isEmpty {
                        TaskTagChips(tags: task.tags, colorMap: tagColorMap)
                    }
                    TextField("Notes", text: $task.notes, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityLabel("Notes")
                        .accessibilityValue(task.notes.isEmpty ? "Empty" : task.notes)
                        .accessibilityHint("Optional notes for this task")
                    LocationField(text: $task.location, mapsHint: "Opens task location in Apple Maps")
                } header: {
                    taskEditorSectionHeader("TASK")
                } footer: {
                    Text("Tips: tomorrow · #tag in the title")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Section {
                    PlannerDateTimeRow(
                        label: "Due",
                        date: Binding(
                            get: { task.dueAt ?? .now },
                            set: { task.dueAt = DateSnapping.tenMinutes($0) }
                        ),
                        hint: "Opens date and time picker in five-minute steps"
                    )
                    Toggle("Reminder", isOn: $hasReminder)
                        .accessibilityLabel("Reminder, \(hasReminder ? "on" : "off")")
                        .accessibilityHint("Schedules notification for this task")
                    if hasReminder {
                        PlannerDateTimeRow(
                            label: "Remind at",
                            date: Binding(
                                get: { task.reminderAt ?? task.dueAt ?? .now },
                                set: { task.reminderAt = DateSnapping.tenMinutes($0) }
                            ),
                            hint: "Opens reminder time picker in five-minute steps"
                        )
                        Stepper(
                            "Duration: \(task.durationMinutes) min",
                            value: $task.durationMinutes,
                            in: 0...240,
                            step: 15
                        )
                        .accessibilityLabel("Duration, \(task.durationMinutes) minutes")
                        .accessibilityHint("Estimated time blocked on calendar for this task")
                    }
                } header: {
                    taskEditorSectionHeader("WHEN")
                }

                Section {
                    Picker("Repeat", selection: Binding(
                        get: { task.recurrence },
                        set: { task.recurrence = $0 }
                    )) {
                        ForEach(TaskRecurrence.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .accessibilityLabel("Repeat, \(task.recurrence.title)")
                    .accessibilityHint("Sets how often this task repeats")
                    .onChange(of: task.recurrence) { _, value in
                        if value == .customWeekly, task.recurrenceWeekdayMask == 0 {
                            task.recurrenceWeekdayMask = RecurrenceWeekdayMask.from(startDate: task.dueAt ?? .now)
                        }
                    }
                    if task.recurrence == .customWeekly {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(RecurrenceWeekdayMask.summary(task.recurrenceWeekdayMask))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .accessibilityAddTraits(.isStaticText)
                            HStack(spacing: Theme.Space.sm - 2) {
                                ForEach(RecurrenceWeekdayMask.labels(), id: \.weekday) { item in
                                    let on = RecurrenceWeekdayMask.contains(item.weekday, in: task.recurrenceWeekdayMask)
                                    Button {
                                        task.recurrenceWeekdayMask = RecurrenceWeekdayMask.toggle(item.weekday, in: task.recurrenceWeekdayMask)
                                    } label: {
                                        Text(item.short)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(on ? .black : Theme.ink)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Theme.Space.sm)
                                            .background(on ? Theme.accent : Theme.sunken, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(item.short), \(on ? "repeats" : "does not repeat")")
                                    .accessibilityHint("Double tap to toggle recurring task on this weekday")
                                }
                            }
                        }
                    }
                } header: {
                    taskEditorSectionHeader("REPEAT")
                }

                Section {
                    Picker("Priority", selection: Binding(
                        get: { task.priority },
                        set: { task.priority = $0 }
                    )) {
                        ForEach(TaskPriority.allCases) { p in
                            HStack(spacing: Theme.Space.sm + 2) {
                                PriorityFlagIcon(priority: p)
                                Text(p.title)
                            }
                            .tag(p)
                        }
                    }
                    .accessibilityLabel("Priority, \(task.priority.title)")
                    .accessibilityHint("Sets task priority flag and Matrix quadrant")
                    Picker("List", selection: Binding(
                        get: { task.list?.id },
                        set: { id in task.list = pickerLists.first { $0.id == id } }
                    )) {
                        ForEach(pickerLists) { list in
                            Text(list.name).tag(Optional(list.id))
                        }
                    }
                    .accessibilityLabel("List, \(task.list?.name ?? "None")")
                    .accessibilityHint("Task list that owns this task")
                    Toggle("Completed", isOn: Binding(
                        get: { task.isCompleted },
                        set: {
                            task.isCompleted = $0
                            task.completedAt = $0 ? .now : nil
                        }
                    ))
                    .accessibilityLabel("Completed, \(task.isCompleted ? "on" : "off")")
                    .accessibilityHint("Marks task done or reopens it")
                } header: {
                    taskEditorSectionHeader("ORGANIZE")
                }
            }
            .scrollDismissesKeyboard(.never)
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .tint(Theme.cta)
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let parsed = TaskTitleParser.parse(task.title)
                        if !parsed.cleanTitle.isEmpty { task.title = parsed.cleanTitle }
                        if let date = parsed.dueDate { task.dueAt = date }
                        if !parsed.tags.isEmpty { task.tags = parsed.tags }
                        if !hasReminder { task.reminderAt = nil }
                        try? modelContext.save()
                        Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.cta)
                    .accessibilityHint("Saves task changes and closes editor")
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) { deleteTask() }
                        .accessibilityHint("Permanently removes this task")
                }
            }
            .onAppear {
                hasReminder = task.reminderAt != nil
                    || (PlannerPreferences.taskRemindersEnabled && task.dueAt != nil)
                if let due = task.dueAt {
                    task.dueAt = DateSnapping.tenMinutes(due)
                }
                if let remind = task.reminderAt {
                    task.reminderAt = DateSnapping.tenMinutes(remind)
                }
            }
        }
        .presentationDetents([Self.compactDetent, Self.expandedDetent], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func taskEditorSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
            .textCase(nil)
    }

    private func deleteTask() {
        Task {
            try? CalendarSyncService.shared.deleteTask(task)
            try? await GoogleCalendarService.shared.deleteTaskEvent(task)
        }
        modelContext.delete(task)
        try? modelContext.save()
        WidgetSnapshotWriter.publish(in: modelContext)
        dismiss()
    }
}

