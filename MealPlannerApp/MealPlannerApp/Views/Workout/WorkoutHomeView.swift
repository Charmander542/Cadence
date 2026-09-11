import SwiftUI
import SwiftData

/// Workout dial page + Lift sheet hub.
/// Integrates `WorkoutProgram` / `WorkoutScheduler` / live sessions via `AppModel`.
/// Mobbin: Tonal/Hevy home — hero CTA, week program strip, exercise rows with thumbnails + last sets.
struct WorkoutHomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutLogEntity.finishedAt, order: .reverse) private var logs: [WorkoutLogEntity]

    /// Dial / sheet / embedded-in-Body overview.
    enum Presentation {
        case dial
        case sheet
        case embedded
    }

    var presentation: Presentation = .sheet
    /// Dial chrome (menu). When set with `.dial`, page is embedded on the wheel.
    var onOpenDrawer: (() -> Void)? = nil

    @State private var planEntity: WorkoutPlanEntity?
    @State private var tick = Date()
    @State private var showSkipConfirm = false
    @State private var pendingStart: WorkoutSessionTemplate?
    @State private var showReplaceLiveConfirm = false
    @State private var previewExercise: WorkoutExerciseTemplate?

    private var isDialPage: Bool { presentation == .dial }
    private var isEmbedded: Bool { presentation == .embedded }

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
        Group {
            switch presentation {
            case .dial:
                dialChrome
            case .sheet:
                sheetChrome
            case .embedded:
                scrollContent
            }
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
        .sheet(item: $previewExercise) { exercise in
            ExerciseGuideView(exercise: exercise)
        }
        .onAppear {
            planEntity = WorkoutStore.plan(in: modelContext)
            tick = .now
        }
    }

    // MARK: - Chrome

    private var dialChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "Workout", onMenu: onOpenDrawer)
            scrollContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var sheetChrome: some View {
        NavigationStack {
            scrollContent
                .background(Theme.canvas)
                .navigationTitle("Lift")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Theme.cta)
                            .accessibilityHint("Closes Lift program")
                    }
                }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg + 4) {
                hero
                weekStrip
                if case .workout(let session) = status.kind {
                    exercisePreview(session)
                } else {
                    restCard
                }
                programRotationCard
                if !logs.isEmpty {
                    recentSection
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, isDialPage || isEmbedded ? Theme.Space.sm : Theme.Space.md)
            .padding(.bottom, isDialPage || isEmbedded ? 110 : Theme.Space.xl)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        Theme.HeroPanel {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text(weekdayLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text(status.headline)
                            .font(Theme.display(.largeTitle))
                            .foregroundStyle(Theme.ink)
                        Text(status.detail)
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.muted)
                        statusPills
                    }
                    Spacer(minLength: Theme.Space.sm)
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
                    Theme.SecondaryButton(title: "Skip session", systemImage: "forward.fill") {
                        showSkipConfirm = true
                    }
                    .accessibilityHint("Skips next scheduled session without logging sets")
                }
            }
        }
    }

    private var statusPills: some View {
        HStack(spacing: Theme.Space.sm) {
            if case .workout(let session) = status.kind {
                Theme.MetaPill(text: session.shortName.uppercased(), tone: .accent)
                Theme.MetaPill(
                    text: "~\(WorkoutVisuals.estimatedMinutes(exerciseCount: session.exercises.count)) min",
                    tone: .neutral
                )
                if status.isCatchUp {
                    Theme.MetaPill(text: "Catch-up", tone: .cta)
                }
            } else {
                Theme.MetaPill(text: "Rest", tone: .neutral)
            }
            if appModel.liveWorkout != nil {
                Theme.MetaPill(text: "In progress", tone: .cta)
            }
        }
    }

    private var restCard: some View {
        Theme.Card {
            HStack(alignment: .top, spacing: Theme.Space.md) {
                Theme.IconWell(systemImage: "moon.zzz.fill", tint: Theme.muted, size: 44)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Recovery day")
                        .font(.headline)
                    Text("Walk, stretch, or cook — recovery is part of the Lift program. Tap a training day below to start early.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest day. Recovery matters. Walk, stretch, or cook.")
    }

    private var weekStrip: some View {
        let today = Calendar.current.component(.weekday, from: tick)
        return Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
                HStack {
                    Text("This week")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("Lift schedule")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                Text("Tap a day to start that session from the program.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
                HStack(spacing: Theme.Space.sm - 2) {
                    ForEach(2...8, id: \.self) { raw in
                        let weekday = raw == 8 ? 1 : raw
                        let session = WorkoutProgram.scheduledSession(for: weekday)
                        let isToday = weekday == today
                        let dayDate = dateForWeekday(weekday)
                        let logged = session.map { loggedSession($0, on: dayDate) } ?? false
                        Button {
                            if let session {
                                requestStart(session)
                            }
                        } label: {
                            VStack(spacing: Theme.Space.sm - 2) {
                                Text(shortDay(weekday).uppercased())
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.4)
                                    .foregroundStyle(isToday ? Theme.accent : Theme.muted)
                                Text(session?.shortName ?? "Rest")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(session == nil ? Theme.muted : Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Circle()
                                    .fill(logged ? Theme.accent : (session == nil ? Color.clear : Theme.sunken))
                                    .frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Space.sm + 2)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(isToday ? Theme.accent.opacity(0.14) : Theme.sunken)
                            )
                            .overlay {
                                if isToday {
                                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                                }
                            }
                            .shadow(
                                color: isToday ? Theme.accent.opacity(0.22) : .clear,
                                radius: 5,
                                y: 1
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(session == nil || appModel.liveWorkout != nil)
                        .accessibilityLabel("\(shortDay(weekday)), \(session?.name ?? "Rest day")\(logged ? ", logged" : "")")
                        .accessibilityHint(
                            session == nil
                                ? "Rest day, no workout scheduled"
                                : (appModel.liveWorkout != nil ? "Finish current workout first" : "Starts \(session!.name) workout")
                        )
                    }
                }
            }
        }
    }

    private func exercisePreview(_ session: WorkoutSessionTemplate) -> some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack {
                    Text("Today’s lifts")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Theme.CountBadge(count: session.exercises.count, emphasized: true)
                }
                ForEach(session.exercises) { ex in
                    let state = plan.exerciseStates[ex.id]
                    Button {
                        previewExercise = ex
                    } label: {
                        HStack(spacing: Theme.Space.md) {
                            ExerciseThumbnail(exercise: ex, selected: false, width: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                Text(prescriptionLine(ex, state: state))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                MuscleTagRow(tags: WorkoutVisuals.muscleTags(for: ex))
                            }
                            Spacer(minLength: 0)
                            if let last = state?.lastWorkout {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Last")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.muted)
                                    Text(last.reps.map(String.init).joined(separator: "/"))
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                }
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.vertical, Theme.Space.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(liftPreviewRowLabel(ex: ex, state: state))
                    .accessibilityHint("Opens form guide for \(ex.name)")
                    if ex.id != session.exercises.last?.id {
                        Divider().overlay(Theme.gridDivider)
                    }
                }
            }
        }
    }

    private var programRotationCard: some View {
        let rotation = WorkoutProgram.rotation
        let index = plan.nextRotationIndex % max(rotation.count, 1)
        return Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
                Text("Program")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Text("Upper / Lower rotation")
                    .font(.subheadline.weight(.semibold))
                Text("Next up in queue: \(nextSessionToSkip?.name ?? "—"). Completing or skipping advances the program used by Today, Calendar, and Habits.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.sm) {
                    ForEach(Array(rotation.enumerated()), id: \.offset) { offset, id in
                        let session = WorkoutProgram.session(id: id)
                        Theme.MetaPill(
                            text: session?.shortName.uppercased() ?? id,
                            tone: offset == index ? .accent : .neutral
                        )
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rotation order. Next is \(nextSessionToSkip?.shortName ?? "unknown")")
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            Text("Recent")
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            ForEach(logs.prefix(5)) { log in
                HStack(spacing: Theme.Space.md) {
                    Theme.IconWell(systemImage: "checkmark.circle.fill", tint: Theme.accent, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.sessionName)
                            .font(.subheadline.weight(.semibold))
                        Text(log.finishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(formatDuration(log.durationSec))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(log.sessionName), \(log.finishedAt.formatted(date: .abbreviated, time: .shortened)), \(formatDuration(log.durationSec))")
                .accessibilityHint("Past logged workout")
                .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    // MARK: - Actions

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

    private func dateForWeekday(_ weekday: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: tick)
        let todayWeekday = cal.component(.weekday, from: today)
        let delta = weekday - todayWeekday
        return cal.date(byAdding: .day, value: delta, to: today) ?? today
    }

    private func loggedSession(_ session: WorkoutSessionTemplate, on day: Date) -> Bool {
        logs.contains {
            Calendar.current.isDate($0.finishedAt, inSameDayAs: day)
                && ($0.sessionID == session.id || $0.sessionName == session.name)
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

    private func liftPreviewRowLabel(ex: WorkoutExerciseTemplate, state: ExerciseProgressionState?) -> String {
        var parts = [ex.name, prescriptionLine(ex, state: state)]
        if let last = state?.lastWorkout {
            parts.append("last sets \(last.reps.map(String.init).joined(separator: "/"))")
        } else {
            parts.append("no logged sets yet")
        }
        return parts.joined(separator: ", ")
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