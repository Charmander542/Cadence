import SwiftUI
import SwiftData

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfileEntity]
    var day: Date

    private var workoutsEnabled: Bool {
        profiles.first?.workoutsEnabled ?? true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    DayAgendaSection(day: day)
                    if workoutsEnabled {
                        WorkoutDayDetailCard(day: day)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.canvas)
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityHint("Closes day agenda")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var dayTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: day)
    }
}

struct DayAgendaSection: View {
    @Query(sort: \PlannerTaskEntity.dueAt) private var tasks: [PlannerTaskEntity]
    let day: Date

    @State private var editingTask: PlannerTaskEntity?
    @State private var editingEvent: PlannerTaskEntity?
    @State private var showQuickAdd = false
    @State private var newEventContext: EventSheetContext?

    private var dayTasks: [PlannerTaskEntity] {
        tasks.filter { task in
            guard !task.isEvent, !task.isCompleted else { return false }
            guard let due = task.dueAt else { return false }
            return Calendar.current.isDate(due, inSameDayAs: day)
        }
    }

    private var dayEvents: [PlannerTaskEntity] {
        tasks.filter { task in
            guard task.isEvent, !task.isCompleted else { return false }
            guard let due = task.dueAt else { return false }
            return Calendar.current.isDate(due, inSameDayAs: day)
        }
    }

    var body: some View {
        Group {
            if dayTasks.isEmpty && dayEvents.isEmpty {
                Theme.Card {
                    VStack(spacing: 14) {
                        Text("No tasks or events this day.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                        Button("Add task") { showQuickAdd = true }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .accessibilityHint("Opens quick add with this day as due date")
                        Button("Add event") {
                            newEventContext = EventSheetContext(startDate: day)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Creates a calendar event on this day")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No tasks or events this day. Add task or add event.")
                    .accessibilityHint("Choose an action below")
                }
            } else {
                if !dayTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tasks")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(dayTasks) { task in
                            Button {
                                editingTask = task
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .stroke(Theme.muted, lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    Text(task.title)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    if task.isOverdue {
                                        Text("Overdue")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Theme.danger)
                                            .accessibilityHidden(true)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.muted)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(dayTaskAccessibilityLabel(task))
                            .accessibilityHint("Double tap to edit task")
                        }
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if !dayEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Events")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(dayEvents) { event in
                            HStack(spacing: 4) {
                                CountdownTrackButton(eventID: event.id)
                                Button {
                                    editingEvent = event
                                } label: {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(PlannerColor.from(hex: event.colorHex.isEmpty ? PlannerColor.palette[0] : event.colorHex))
                                            .frame(width: 8, height: 8)
                                        Text(event.title)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.ink)
                                        Spacer()
                                        if let due = event.dueAt {
                                            Text(due, style: .time)
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(dayEventAccessibilityLabel(event))
                                .accessibilityHint("Double tap to edit event")
                            }
                        }
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
        .sheet(item: $editingEvent) { event in
            PlannerEventSheet(context: EventSheetContext(task: event, startDate: event.dueAt ?? day))
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(initialDue: day)
        }
        .sheet(item: $newEventContext) { context in
            PlannerEventSheet(context: context)
        }
    }

    private func dayTaskAccessibilityLabel(_ task: PlannerTaskEntity) -> String {
        var parts = [task.title]
        if task.isOverdue { parts.append("overdue") }
        if let due = task.dueAt {
            parts.append(PlannerDate.shortDue(due))
        }
        return parts.joined(separator: ", ")
    }

    private func dayEventAccessibilityLabel(_ event: PlannerTaskEntity) -> String {
        var parts = [event.title, "event"]
        if CountdownTracking.isTracked(event.id) {
            parts.append("countdown tracked")
        }
        if let due = event.dueAt {
            parts.append(due.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: ", ")
    }
}

/// Calendar day drill-in — program schedule only, no catch-up logic.
struct WorkoutDayDetailCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLogEntity.finishedAt, order: .reverse) private var logs: [WorkoutLogEntity]

    var day: Date

    @State private var previewSession: WorkoutSessionTemplate?
    @State private var pendingStart: WorkoutSessionTemplate?
    @State private var showReplaceLiveConfirm = false

    private var scheduled: WorkoutSessionTemplate? {
        WorkoutIntegration.scheduledSession(on: day, workoutsEnabled: true)
    }

    private var dayLog: WorkoutLogEntity? {
        logs.first { Calendar.current.isDate($0.finishedAt, inSameDayAs: day) }
    }

    private var isPast: Bool {
        Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: .now)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let scheduled {
                scheduledHeader(scheduled)
                if let log = dayLog, let workout = log.decoded() {
                    WorkoutLogSummary(workout: workout, log: log)
                } else if isPast {
                    missedSection(scheduled)
                } else if isToday {
                    WorkoutTodayActions(session: scheduled)
                } else {
                    Text("Scheduled for this day.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                restDayCard
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .workoutPreviewSheet(session: $previewSession)
        .confirmationDialog("Replace in-progress workout?", isPresented: $showReplaceLiveConfirm, titleVisibility: .visible) {
            if let session = pendingStart {
                Button("Discard & start \(session.name)", role: .destructive) {
                    appModel.clearLiveWorkout()
                    begin(session)
                    pendingStart = nil
                }
                .accessibilityHint("Clears current workout and starts selected session")
            }
            Button("Resume current instead") {
                pendingStart = nil
                appModel.resumeLiveWorkout()
            }
            .accessibilityHint("Returns to in-progress workout")
            Button("Cancel", role: .cancel) { pendingStart = nil }
                .accessibilityHint("Cancels starting new session")
        } message: {
            Text("You already have a workout open. Starting another discards those sets.")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func scheduledHeader(_ session: WorkoutSessionTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(session.focus)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
    }

    private var restDayCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest day")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("No lift scheduled on this weekday.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func missedSection(_ session: WorkoutSessionTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Missed")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.danger)
            Text("You didn't log \(session.name) on this day.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Button {
                previewSession = session
            } label: {
                Label("Do this workout", systemImage: "dumbbell.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityLabel("Do \(session.name) workout")
            .accessibilityHint("Opens workout preview to start or log session")
        }
    }

    private func requestStart(_ session: WorkoutSessionTemplate) {
        if appModel.liveWorkout != nil {
            pendingStart = session
            showReplaceLiveConfirm = true
            return
        }
        begin(session)
    }

    private func begin(_ session: WorkoutSessionTemplate) {
        let entity = WorkoutStore.plan(in: modelContext)
        appModel.beginLiveWorkout(session: session, plan: entity.decoded())
    }
}

/// What to do right now on Today — uses rotation when behind, but no "catch-up" chrome.
struct WorkoutTodayActions: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext

    var session: WorkoutSessionTemplate

    @State private var planEntity: WorkoutPlanEntity?
    @State private var showSkipConfirm = false
    @State private var pendingStart: WorkoutSessionTemplate?
    @State private var showReplaceLiveConfirm = false

    private var todaySession: WorkoutSessionTemplate {
        let plan = planEntity?.decoded() ?? .fresh
        let status = WorkoutIntegration.status(on: .now, plan: plan)
        if case .workout(let s) = status.kind { return s }
        return session
    }

    var body: some View {
        VStack(spacing: 10) {
            if appModel.liveWorkout != nil {
                Button { appModel.resumeLiveWorkout() } label: {
                    Label("Resume workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("Resume workout")
                .accessibilityHint("Returns to in-progress live workout")
            } else {
                HStack(spacing: 10) {
                    Button { requestStart(todaySession) } label: {
                        Label("Begin workout", systemImage: "dumbbell.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .accessibilityLabel("Begin \(todaySession.name) workout")
                    .accessibilityHint("Starts live workout session")
                    Button("Skip") { showSkipConfirm = true }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Skip \(todaySession.name)")
                        .accessibilityHint("Marks session skipped for today")
                }
            }
        }
        .onAppear { planEntity = WorkoutStore.plan(in: modelContext) }
        .confirmationDialog("Skip this session?", isPresented: $showSkipConfirm, titleVisibility: .visible) {
            Button("Skip \(todaySession.name)", role: .destructive) { skip(todaySession) }
                .accessibilityHint("Advances program without logging this session")
            Button("Cancel", role: .cancel) {}
                .accessibilityHint("Keeps session scheduled")
        } message: {
            Text("Moves the program forward without logging sets. Weights stay where they are.")
                .accessibilityAddTraits(.isStaticText)
        }
        .confirmationDialog("Replace in-progress workout?", isPresented: $showReplaceLiveConfirm, titleVisibility: .visible) {
            if let s = pendingStart {
                Button("Discard & start \(s.name)", role: .destructive) {
                    appModel.clearLiveWorkout()
                    begin(s)
                    pendingStart = nil
                }
                .accessibilityHint("Clears current workout and starts selected session")
            }
            Button("Resume current instead") { pendingStart = nil; appModel.resumeLiveWorkout() }
                .accessibilityHint("Returns to in-progress workout")
            Button("Cancel", role: .cancel) { pendingStart = nil }
                .accessibilityHint("Cancels starting new session")
        } message: {
            Text("You already have a workout open. Starting another discards those sets.")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func requestStart(_ s: WorkoutSessionTemplate) {
        if appModel.liveWorkout != nil {
            pendingStart = s
            showReplaceLiveConfirm = true
            return
        }
        begin(s)
    }

    private func begin(_ s: WorkoutSessionTemplate) {
        let entity = planEntity ?? WorkoutStore.plan(in: modelContext)
        planEntity = entity
        appModel.beginLiveWorkout(session: s, plan: entity.decoded())
    }

    private func skip(_ s: WorkoutSessionTemplate) {
        let entity = planEntity ?? WorkoutStore.plan(in: modelContext)
        planEntity = entity
        var plan = entity.decoded()
        WorkoutProgression.skip(sessionID: s.id, into: &plan)
        entity.save(plan)
        try? modelContext.save()
    }
}

struct WorkoutLogSummary: View {
    var workout: LoggedWorkout
    var log: WorkoutLogEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mint)
                Spacer()
                Text(formatDuration(log.durationSec))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Text(log.finishedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            ForEach(workout.exercises, id: \.name) { ex in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(ex.sets.filter(\.completed).map { setLine($0) }.joined(separator: " · "))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workoutLogSummaryLabel)
        .accessibilityAddTraits(.isStaticText)
    }

    private var workoutLogSummaryLabel: String {
        let time = log.finishedAt.formatted(date: .abbreviated, time: .shortened)
        return "Completed workout, \(formatDuration(log.durationSec)), finished \(time)"
    }

    private func setLine(_ set: LoggedSet) -> String {
        if let sec = set.durationSec { return "\(sec)s" }
        if set.weight > 0 { return "\(WorkoutProgression.formatWeight(set.weight))×\(set.reps)" }
        return "\(set.reps) reps"
    }

    private func formatDuration(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }
}
