import SwiftUI
import SwiftData

struct WorkoutHomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutLogEntity.finishedAt, order: .reverse) private var logs: [WorkoutLogEntity]
    @State private var planEntity: WorkoutPlanEntity?
    @State private var tick = Date()
    @State private var showSkipConfirm = false
    @State private var pendingStart: WorkoutSessionTemplate?
    @State private var showReplaceLiveConfirm = false

    private var plan: WorkoutPlanState {
        planEntity?.decoded() ?? .fresh
    }

    private var status: WorkoutScheduler.DayStatus {
        WorkoutScheduler.status(for: tick, plan: plan)
    }

    private var nextSessionToSkip: WorkoutSessionTemplate? {
        let id = WorkoutProgram.rotation[plan.nextRotationIndex % WorkoutProgram.rotation.count]
        return WorkoutProgram.session(id: id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    weekStrip
                    if case .workout(let session) = status.kind {
                        exercisePreview(session)
                    } else {
                        restCard
                    }
                    if !logs.isEmpty {
                        recentSection
                    }
                }
                .padding()
            }
            .background(Theme.canvas)
            .navigationTitle("Lift")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes Lift program")
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { appModel.showLiveWorkout && appModel.liveWorkout != nil },
                set: { presented in
                    if presented {
                        appModel.showLiveWorkout = true
                    } else {
                        appModel.discardLiveWorkoutNavigation()
                    }
                }
            )) {
                ActiveWorkoutView(planEntity: planEntity ?? WorkoutStore.plan(in: modelContext))
            }
            .confirmationDialog("Skip this session?", isPresented: $showSkipConfirm, titleVisibility: .visible) {
                if let session = nextSessionToSkip {
                    Button("Skip \(session.name)", role: .destructive) {
                        skip(session)
                    }
                    .accessibilityHint("Advances program without logging this session")
                }
                Button("Cancel", role: .cancel) {}
                    .accessibilityHint("Keeps session scheduled")
            } message: {
                Text("Moves the program forward without logging sets. Weights stay where they are.")
                    .accessibilityAddTraits(.isStaticText)
            }
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
            .onAppear {
                planEntity = WorkoutStore.plan(in: modelContext)
                tick = .now
                if appModel.liveWorkout != nil {
                    appModel.showLiveWorkout = true
                }
            }
        }
    }

    private var hero: some View {
        Theme.HeroPanel {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weekdayLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text(status.headline)
                            .font(Theme.display(.largeTitle))
                            .foregroundStyle(Theme.ink)
                        Text(status.detail)
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: statusIcon)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(status.headline). \(status.detail)")

                if appModel.liveWorkout != nil {
                    Theme.PrimaryButton(title: "Resume workout", systemImage: "play.fill") {
                        appModel.resumeLiveWorkout()
                    }
                    .accessibilityHint("Returns to in-progress live workout")
                } else if case .workout(let session) = status.kind {
                    Theme.PrimaryButton(
                        title: status.isCatchUp ? "Begin catch-up" : "Begin workout",
                        systemImage: "dumbbell.fill"
                    ) {
                        requestStart(session)
                    }
                    .accessibilityHint(status.isCatchUp ? "Starts missed workout session" : "Starts live workout session")
                }

                if nextSessionToSkip != nil, appModel.liveWorkout == nil {
                    Theme.SecondaryButton(title: "Skip", systemImage: "forward.fill") {
                        showSkipConfirm = true
                    }
                    .accessibilityHint("Skips next scheduled session without logging sets")
                }
            }
        }
    }

    private var restCard: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery matters")
                    .font(.headline)
                Text("Walk, stretch, or cook — recovery is part of the program.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest day. Recovery matters. Walk, stretch, or cook.")
    }

    private var weekStrip: some View {
        let today = Calendar.current.component(.weekday, from: tick)
        return VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.headline)
            Text("Tap a day to start that session.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isStaticText)
            HStack(spacing: 6) {
                ForEach(2...8, id: \.self) { raw in
                    let weekday = raw == 8 ? 1 : raw // Mon…Sun
                    let session = WorkoutProgram.scheduledSession(for: weekday)
                    let isToday = weekday == today
                    Button {
                        if let session {
                            requestStart(session)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(shortDay(weekday))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isToday ? Theme.accent : Theme.muted)
                            Text(session?.shortName ?? "Rest")
                                .font(.caption2)
                                .foregroundStyle(session == nil ? Theme.muted : Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isToday ? Theme.accent.opacity(0.14) : Theme.surface)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(session == nil || appModel.liveWorkout != nil)
                    .accessibilityLabel("\(shortDay(weekday)), \(session?.name ?? "Rest day")")
                    .accessibilityHint(
                        session == nil
                            ? "Rest day, no workout scheduled"
                            : (appModel.liveWorkout != nil ? "Finish current workout first" : "Starts \(session!.name) workout")
                    )
                }
            }
        }
    }

    private func exercisePreview(_ session: WorkoutSessionTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today’s lifts")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(session.exercises) { ex in
                let state = plan.exerciseStates[ex.id]
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                            .font(.subheadline.weight(.semibold))
                        Text(prescriptionLine(ex, state: state))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if let last = state?.lastWorkout {
                        Text(last.reps.map(String.init).joined(separator: "/"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(liftPreviewRowLabel(ex: ex, state: state))
                if ex.id != session.exercises.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func liftPreviewRowLabel(ex: WorkoutExerciseTemplate, state: ExerciseProgressionState?) -> String {
        var parts = [ex.name, prescriptionLine(ex, state: state)]
        if let last = state?.lastWorkout {
            parts.append("last sets \(last.reps.map(String.init).joined(separator: "/"))")
        } else {
            parts.append("no logged sets yet")
        }
        return parts.joined(separator: ", ")
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(logs.prefix(5)) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.sessionName)
                            .font(.subheadline.weight(.semibold))
                        Text(log.finishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(formatDuration(log.durationSec))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(log.sessionName), \(log.finishedAt.formatted(date: .abbreviated, time: .shortened)), \(formatDuration(log.durationSec))")
                .accessibilityHint("Past logged workout")
                .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var statusIcon: String {
        switch status.kind {
        case .rest: return "moon.zzz.fill"
        case .workout: return status.isCatchUp ? "arrow.uturn.forward.circle.fill" : "dumbbell.fill"
        }
    }

    private var weekdayLabel: String {
        tick.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func shortDay(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols[max(0, min(symbols.count - 1, weekday - 1))]
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
        let entity = planEntity ?? WorkoutStore.plan(in: modelContext)
        planEntity = entity
        appModel.beginLiveWorkout(session: session, plan: entity.decoded())
        tick = .now
    }

    private func skip(_ session: WorkoutSessionTemplate) {
        let entity = planEntity ?? WorkoutStore.plan(in: modelContext)
        planEntity = entity
        var plan = entity.decoded()
        WorkoutProgression.skip(sessionID: session.id, into: &plan)
        entity.save(plan)
        try? modelContext.save()
        tick = .now
    }

    private func prescriptionLine(_ ex: WorkoutExerciseTemplate, state: ExerciseProgressionState?) -> String {
        switch ex.progressionType {
        case .time:
            let sec = state?.currentDurationSec ?? ex.durationMinSec ?? 30
            return "\(ex.targetSets) × \(sec)s\(ex.perSide ? "/side" : "")"
        case .repOnly, .weightRep:
            let w = state.map { WorkoutProgression.formatWeight($0.currentWeight) } ?? "—"
            let range = "\(ex.targetSets) × \(ex.repMin)–\(ex.repMax)\(ex.perSide ? "/leg" : "")"
            if ex.progressionType == .repOnly && (state?.currentWeight ?? 0) <= 0 {
                return range
            }
            return "\(w) · \(range)"
        }
    }

    private func formatDuration(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}
