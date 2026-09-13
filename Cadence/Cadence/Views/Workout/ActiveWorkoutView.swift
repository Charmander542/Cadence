import SwiftUI
import SwiftData
import UIKit

struct ActiveWorkoutView: View {
    @Bindable var planEntity: WorkoutPlanEntity
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFinishConfirm = false
    @State private var showIncompleteConfirm = false
    @State private var showCancelConfirm = false
    @State private var completionNotes: [String: String] = [:]
    @State private var showDoneSheet = false
    @State private var summarySessionName = "Workout"
    @State private var isSaving = false

    var body: some View {
        Group {
            if isSaving || showDoneSheet {
                savingPlaceholder
            } else             if let live = appModel.liveWorkout {
                LiveWorkoutScreen(
                    live: live,
                    isSaving: isSaving,
                    onBack: { leaveWorkout(live: live) },
                    onFinish: { attemptFinish() },
                    onSetCompleted: { restSec in
                        appModel.startRest(seconds: restSec)
                    }
                )
            } else {
                VStack(spacing: Theme.Space.lg) {
                    Theme.EmptyState(
                        systemImage: "dumbbell",
                        title: "No active workout",
                        message: "Start a session from Workout on the dial, Today, or Calendar.",
                        cta: "Close",
                        ctaHint: "Closes workout screen"
                    ) {
                        dismiss()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No active workout. Start a session from Today or the Lift hub.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.canvas)
            }
        }
        .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Log workout", role: .destructive) { finish(allowIncomplete: false) }
                .accessibilityHint("Logs workout and saves all completed sets")
            Button("Cancel", role: .cancel) {}
                .accessibilityHint("Returns to live workout without saving")
        } message: {
            Text("Save every completed set and update progression.")
                .accessibilityAddTraits(.isStaticText)
        }
        .confirmationDialog("Some sets aren’t done", isPresented: $showIncompleteConfirm, titleVisibility: .visible) {
            Button("Log completed sets only", role: .destructive) { finish(allowIncomplete: true) }
                .accessibilityHint("Logs finished sets only; unfinished sets won't count")
            Button("Keep lifting", role: .cancel) {}
                .accessibilityHint("Returns to live workout to finish remaining sets")
        } message: {
            Text("Unfinished sets won’t count toward progression.")
                .accessibilityAddTraits(.isStaticText)
        }
        .confirmationDialog("Leave workout?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Keep progress & exit") {
                appModel.discardLiveWorkoutNavigation()
                dismiss()
            }
            .accessibilityHint("Leaves the screen but keeps logged sets so you can resume later")
            Button("Discard workout", role: .destructive) {
                appModel.clearLiveWorkout()
                dismiss()
            }
            .accessibilityHint("Clears all sets from this session without saving")
            Button("Stay", role: .cancel) {}
                .accessibilityHint("Dismisses dialog and continues the live workout")
        } message: {
            Text("Exit keeps your sets so you can resume. Discard clears this session.")
                .accessibilityAddTraits(.isStaticText)
        }
        .sheet(isPresented: $showDoneSheet, onDismiss: {
            appModel.clearLiveWorkout()
            dismiss()
        }) {
            WorkoutSummarySheet(sessionName: summarySessionName, notes: completionNotes) {
                showDoneSheet = false
            }
        }
    }

    private var savingPlaceholder: some View {
        VStack(spacing: Theme.Space.md) {
            ProgressView()
            Text(showDoneSheet ? "Saved" : "Saving…")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
        .navigationTitle(summarySessionName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showDoneSheet ? "Workout saved" : "Saving workout")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Empty sessions dismiss immediately; sessions with logged sets ask before leaving.
    private func leaveWorkout(live: LiveWorkoutController) {
        if live.completedSetCount == 0 {
            appModel.clearLiveWorkout()
            dismiss()
            return
        }
        showCancelConfirm = true
    }

    private func attemptFinish() {
        guard let live = appModel.liveWorkout, !isSaving else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if live.completedSetCount == 0 {
            leaveWorkout(live: live)
            return
        }
        if live.completedSetCount < live.totalSetCount {
            showIncompleteConfirm = true
        } else {
            showFinishConfirm = true
        }
    }

    private func finish(allowIncomplete: Bool) {
        guard !isSaving, let controller = appModel.liveWorkout else { return }
        isSaving = true
        let snapshot = controller.snapshot()
        summarySessionName = snapshot.session.name
        appModel.skipRest()

        let entity = WorkoutStore.plan(in: modelContext)
        var plan = entity.decoded()
        let loggedExercises: [LoggedExercise] = snapshot.exercises.map { ex in
            LoggedExercise(
                exerciseID: ex.id,
                name: ex.template.name,
                sets: ex.sets.map { row in
                    LoggedSet(
                        reps: row.reps,
                        weight: row.weight,
                        rir: row.rir,
                        durationSec: row.durationSec,
                        completed: row.isCompleted,
                        isWarmup: row.isWarmup
                    )
                },
                prescriptionWeight: ex.weight,
                progressionNote: nil
            )
        }
        let notes = WorkoutProgression.apply(
            logged: loggedExercises,
            sessionID: snapshot.session.id,
            into: &plan
        )
        entity.save(plan)

        let workout = LoggedWorkout(
            id: UUID(),
            sessionID: snapshot.session.id,
            sessionName: snapshot.session.name,
            startedAt: snapshot.startedAt,
            finishedAt: .now,
            durationSec: snapshot.elapsedSec,
            exercises: loggedExercises,
            loggedIncomplete: allowIncomplete && snapshot.completedSetCount < snapshot.totalSetCount
        )
        modelContext.insert(WorkoutLogEntity(workout: workout))
        do {
            try modelContext.save()
        } catch {
            isSaving = false
            appModel.errorMessage = error.localizedDescription
            return
        }

        completionNotes = notes
        showDoneSheet = true
    }
}

// MARK: - Hevy-style live screen — exercise carousel + set table

private struct LiveWorkoutScreen: View {
    @ObservedObject var live: LiveWorkoutController
    @EnvironmentObject private var appModel: AppModel
    var isSaving: Bool
    var onBack: () -> Void
    var onFinish: () -> Void
    var onSetCompleted: (Int) -> Void

    @State private var focusedIndex = 0
    @State private var showOptions = false
    @State private var showGuide = false
    @State private var editorField: WorkoutEditorField?
    @State private var editorDraft = ""
    @State private var editorRIR: Int = 0

    private var focusedExercise: LiveExerciseController? {
        guard focusedIndex >= 0, focusedIndex < live.exercises.count else { return nil }
        return live.exercises[focusedIndex]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                exerciseCarousel
                if let exercise = focusedExercise {
                    exerciseDetail(exercise)
                }
            }

            if editorField != nil {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        editorField = nil
                    }
                    .accessibilityLabel("Dismiss keypad")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)

                WorkoutKeypadEditor(
                    draft: $editorDraft,
                    field: editorField!,
                    rir: editorRIR,
                    onRIR: { newRIR in
                        editorRIR = newRIR
                        applyLiveRIR(newRIR)
                    },
                    onConfirm: commitEditor,
                    onDismiss: { editorField = nil }
                )
                .transition(.move(edge: .bottom))
            } else if live.restRemaining > 0 {
                restBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .animation(.easeOut(duration: 0.2), value: live.restRemaining > 0)
        .animation(.easeOut(duration: 0.2), value: editorField != nil)
        .confirmationDialog("Workout options", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Form guide") { showGuide = true }
                .accessibilityHint("Opens how-to for the current exercise")
            if live.restRemaining > 0 {
                Button("Skip rest") { appModel.skipRest() }
                    .accessibilityHint("Ends the rest timer now")
            }
            Button("Leave workout", role: .destructive) { onBack() }
                .accessibilityHint("Exit or discard this session without finishing")
            Button("Close", role: .cancel) {}
                .accessibilityHint("Returns to live workout")
        } message: {
            Text("Guide and rest tools. Use FINISH to log the session.")
                .accessibilityAddTraits(.isStaticText)
        }
        .sheet(isPresented: $showGuide) {
            if let exercise = focusedExercise {
                ExerciseGuideView(exercise: exercise.template)
            }
        }
    }

    private var topBar: some View {
        TimelineView(.periodic(from: live.startedAt, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(live.startedAt)))
            HStack(spacing: Theme.Space.md) {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Leave workout")
                .accessibilityHint(
                    live.completedSetCount == 0
                        ? "Closes this empty workout"
                        : "Exit and keep progress, or discard the session"
                )

                Label(formatElapsed(elapsed), systemImage: "stopwatch")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: Theme.Space.sm)

                if live.restRemaining > 0 {
                    Label(formatElapsed(live.restRemaining), systemImage: "timer")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }

                Button { showOptions = true } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("More options")
                .accessibilityHint("Form guide, skip rest, or leave workout")

                Button(action: onFinish) {
                    Text("FINISH")
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        .background(Theme.cta, in: Capsule(style: .continuous))
                }
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Logs completed sets and updates progression")
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, Theme.Space.md)
        }
    }

    private var exerciseCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.sm + 2) {
                    ForEach(Array(live.exercises.enumerated()), id: \.element.id) { index, ex in
                        Button {
                            if index == focusedIndex {
                                showGuide = true
                            } else {
                                editorField = nil
                                focusedIndex = index
                            }
                        } label: {
                            ExerciseThumbnail(
                                exercise: ex.template,
                                selected: index == focusedIndex,
                                width: 76,
                                heightRatio: 1.45
                            )
                            .accessibilityHidden(true)
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityLabel(
                            index == focusedIndex
                                ? "\(ex.template.name), selected exercise"
                                : ex.template.name
                        )
                        .accessibilityHint(
                            index == focusedIndex
                                ? "Double tap for form guide"
                                : "Switch to this exercise"
                        )
                        .accessibilityAddTraits(index == focusedIndex ? [.isButton, .isSelected] : .isButton)
                        .id(ex.id)
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.sm)
            }
            .onChange(of: focusedIndex) { _, new in
                if new < live.exercises.count {
                    withAnimation { proxy.scrollTo(live.exercises[new].id, anchor: .center) }
                }
            }
        }
    }

    private func exerciseDetail(_ exercise: LiveExerciseController) -> some View {
        let completedSets = exercise.sets.filter(\.isCompleted).count
        let isTimed = exercise.template.progressionType == .time
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md + 2) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(exercise.template.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Set \(min(completedSets + 1, exercise.sets.count)) of \(exercise.sets.count)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, Theme.Space.lg)

                MuscleTagRow(tags: WorkoutVisuals.muscleTags(for: exercise.template))
                    .padding(.horizontal, Theme.Space.lg)

                HStack(spacing: 0) {
                    colHeader("Set", width: 36)
                    colHeader("Auto ↔", flex: true)
                    colHeader(isTimed ? "Sec" : "Lb", width: 76)
                    colHeader(isTimed ? "" : "Reps", width: 76)
                    colHeader("", width: 44)
                }
                .padding(.horizontal, Theme.Space.lg)

                ForEach(exercise.sets) { set in
                    SetRow(
                        exercise: exercise,
                        setID: set.id,
                        isTimed: isTimed,
                        autoLabel: autoLabel(for: exercise, setID: set.id),
                        editorField: editorField,
                        editorDraft: editorDraft,
                        editorRIR: editorRIR,
                        onEditWeight: {
                            openEditor(
                                .weight(exerciseID: exercise.id, setID: set.id),
                                draft: formatWeight(set.weight),
                                rir: set.rir ?? 0
                            )
                        },
                        onEditReps: {
                            let value = isTimed ? (set.durationSec ?? set.reps) : set.reps
                            openEditor(
                                isTimed ? .duration(exerciseID: exercise.id, setID: set.id) : .reps(exerciseID: exercise.id, setID: set.id),
                                draft: "\(value)",
                                rir: set.rir ?? 0
                            )
                        },
                        onToggleComplete: { completed in
                            if completed { onSetCompleted(exercise.template.defaultRestSec) }
                            appModel.liveWorkout?.refreshCompletedCount()
                        }
                    )
                    .id("\(exercise.id)-\(set.id)")
                }
                .padding(.horizontal, Theme.Space.md)
            }
            .padding(.bottom, bottomInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: editorDraft) { _, new in
            applyLiveDraft(new)
        }
    }

    private func applyLiveDraft(_ draft: String) {
        guard let field = editorField else { return }
        switch field {
        case .weight(let exID, let setID):
            appModel.setLiveSetWeight(exerciseID: exID, setID: setID, weight: Double(draft) ?? 0)
        case .reps(let exID, let setID):
            appModel.setLiveSetReps(exerciseID: exID, setID: setID, reps: Int(draft) ?? 0)
        case .duration(let exID, let setID):
            let sec = Int(draft) ?? 0
            appModel.setLiveSetReps(exerciseID: exID, setID: setID, reps: sec, durationSec: sec)
        }
    }

    private func applyLiveRIR(_ rir: Int) {
        guard case .reps(let exID, let setID) = editorField else { return }
        appModel.setLiveSetRIR(exerciseID: exID, setID: setID, rir: rir)
    }

    private var bottomInset: CGFloat {
        if editorField != nil { return 380 }
        if live.restRemaining > 0 { return 120 }
        return 24
    }

    private func openEditor(_ field: WorkoutEditorField, draft: String, rir: Int = 0) {
        editorField = field
        editorDraft = draft
        editorRIR = rir
    }

    private func commitEditor() {
        guard let field = editorField else { return }
        switch field {
        case .weight(let exID, let setID):
            appModel.setLiveSetWeight(exerciseID: exID, setID: setID, weight: Double(editorDraft) ?? 0)
        case .reps(let exID, let setID):
            appModel.setLiveSetReps(exerciseID: exID, setID: setID, reps: Int(editorDraft) ?? 0)
            appModel.setLiveSetRIR(exerciseID: exID, setID: setID, rir: editorRIR)
        case .duration(let exID, let setID):
            let sec = Int(editorDraft) ?? 0
            appModel.setLiveSetReps(exerciseID: exID, setID: setID, reps: sec, durationSec: sec)
        }
        editorField = nil
    }

    private func formatWeight(_ w: Double) -> String {
        if abs(w - w.rounded()) < 0.05 { return "\(Int(w.rounded()))" }
        return String(format: "%.1f", w)
    }

    private var restBanner: some View {
        // Hevy live rest: muted REST caps, CTA timer, Skip as primary action.
        VStack(spacing: Theme.Space.sm + 2) {
            HStack(alignment: .center, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("REST")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                    Text(formatElapsed(live.restRemaining))
                        .font(.title.monospacedDigit().weight(.bold))
                        .foregroundStyle(Theme.cta)
                }
                Spacer(minLength: 0)
                Button("Skip") { appModel.skipRest() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.sm)
                    .background(Theme.cta, in: Capsule())
                    .accessibilityLabel("Skip rest")
                    .accessibilityHint("Ends rest timer and continues workout")
            }
            ProgressView(
                value: Double(live.restTotal - live.restRemaining),
                total: Double(max(live.restTotal, 1))
            )
            .tint(Theme.cta)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rest timer, \(formatElapsed(live.restRemaining)) remaining")
        .accessibilityHint("Rest between sets. Skip when you are ready to continue.")
        .accessibilityAddTraits(.updatesFrequently)
        .padding(Theme.Space.lg)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.cta.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm + 2)
    }

    private func autoLabel(for exercise: LiveExerciseController, setID: Int) -> String {
        guard let set = exercise.sets.first(where: { $0.id == setID }) else { return "—" }
        return WorkoutPrescription.autoHint(for: set, template: exercise.template)
    }

    private func colHeader(_ title: String, width: CGFloat? = nil, flex: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flex ? .infinity : nil, alignment: .leading)
    }

    private func formatElapsed(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }
}

private struct WorkoutTightTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Set row

private struct SetRow: View {
    @ObservedObject var exercise: LiveExerciseController
    let setID: Int
    var isTimed: Bool
    var autoLabel: String
    var editorField: WorkoutEditorField?
    var editorDraft: String
    var editorRIR: Int
    var onEditWeight: () -> Void
    var onEditReps: () -> Void
    var onToggleComplete: (Bool) -> Void
    @EnvironmentObject private var appModel: AppModel

    private var set: ActiveSetRow? {
        exercise.sets.first(where: { $0.id == setID })
    }

    var body: some View {
        if let set {
            row(set)
        }
    }

    private func row(_ set: ActiveSetRow) -> some View {
        let value = isTimed ? (set.durationSec ?? set.reps) : set.reps
        let weightFocused: Bool = {
            guard let editorField else { return false }
            if case .weight(let id, let sid) = editorField {
                return id == exercise.id && sid == setID
            }
            return false
        }()
        let repsFocused: Bool = {
            guard let editorField else { return false }
            switch editorField {
            case .reps(let id, let sid), .duration(let id, let sid):
                return id == exercise.id && sid == setID
            default: return false
            }
        }()
        return HStack(spacing: Theme.Space.sm) {
            SetTypeBadge(label: WorkoutPrescription.setLabel(for: set), dimmed: set.isCompleted)
                .frame(width: 36, alignment: .leading)

            Text(autoLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            if !isTimed {
                Button {
                    onEditWeight()
                } label: {
                    WorkoutEditableField(
                        text: weightFocused ? editorDraft : formatWeight(set.weight),
                        focused: weightFocused,
                        width: 76
                    )
                }
                .buttonStyle(WorkoutTightTapStyle())
                .frame(width: 76, height: 36)
                .contentShape(Rectangle())
                .accessibilityLabel("Edit weight")
                .accessibilityHint("Opens weight keypad")
            }

            Button {
                onEditReps()
            } label: {
                WorkoutEditableField(
                    text: repsFocused ? editorDraft : "\(value)",
                    focused: repsFocused,
                    width: 76,
                    rir: isTimed ? nil : (repsFocused ? editorRIR : (set.rir ?? 0))
                )
            }
            .buttonStyle(WorkoutTightTapStyle())
            .frame(width: 76, height: 36)
            .contentShape(Rectangle())
            .accessibilityLabel(isTimed ? "Edit duration" : "Edit reps")
            .accessibilityHint("Opens rep or time keypad")

            Button {
                let next = !set.isCompleted
                appModel.updateLiveSet(exerciseID: exercise.id, setID: setID) { row in
                    row.isCompleted = next
                }
                if next { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                onToggleComplete(next)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(set.isCompleted ? Theme.accent : Theme.muted.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                    if set.isCompleted {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(WorkoutTightTapStyle())
            .frame(width: 36, height: 36)
            .accessibilityLabel(set.isCompleted ? "Mark set incomplete" : "Complete set")
            .accessibilityHint("Double tap to log set complete or reopen it")
        }
        .padding(.vertical, Theme.Space.sm + 2)
        .padding(.horizontal, Theme.Space.xs)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(set.isCompleted ? Theme.accent.opacity(0.06) : Theme.sunken.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .opacity(set.isCompleted ? 0.7 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(setRowAccessibilityLabel(set, value: value))
    }

    private func setRowAccessibilityLabel(_ set: ActiveSetRow, value: Int) -> String {
        let setNumber = (exercise.sets.firstIndex(where: { $0.id == setID }) ?? 0) + 1
        var parts = [
            "Set \(setNumber) of \(exercise.sets.count)",
            WorkoutPrescription.setLabel(for: set),
            autoLabel
        ]
        if !isTimed {
            parts.append("\(formatWeight(set.weight)) pounds")
        }
        parts.append(isTimed ? "\(value) seconds" : "\(value) reps")
        if set.isCompleted { parts.append("completed") }
        return parts.joined(separator: ", ")
    }

    private func formatWeight(_ w: Double) -> String {
        if abs(w - w.rounded()) < 0.05 { return "\(Int(w.rounded()))" }
        return String(format: "%.1f", w)
    }
}

private struct WorkoutSummarySheet: View {
    let sessionName: String
    let notes: [String: String]
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    VStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "checkmark.circle.fill", tint: Theme.accent, size: 72)
                        Text("WORKOUT SAVED")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                        Text(sessionName)
                            .font(Theme.title(.title2))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("Nice work — session logged.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.lg)

                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("NEXT TIME")
                                .font(.caption2.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.muted)
                                .padding(.horizontal, Theme.Space.xs)
                            ForEach(notes.keys.sorted(), id: \.self) { key in
                                if let msg = notes[key] {
                                    HStack(alignment: .top, spacing: Theme.Space.md) {
                                        Theme.IconWell(systemImage: "arrow.up.right", tint: Theme.cta, size: 36)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(prettyName(key))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Theme.ink)
                                            Text(msg)
                                                .font(.footnote)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(Theme.Space.md)
                                    .background(
                                        Theme.surface,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                            .strokeBorder(Theme.hairline, lineWidth: 1)
                                    )
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(prettyName(key)). \(msg)")
                                }
                            }
                        }
                    }

                    Theme.PrimaryButton(title: "Done", systemImage: "checkmark") {
                        onDone()
                    }
                    .padding(.top, Theme.Space.sm)
                    .accessibilityHint("Closes workout summary")
                }
                .padding(Theme.Space.lg)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDone)
                        .foregroundStyle(Theme.muted)
                        .accessibilityHint("Closes workout summary")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func prettyName(_ id: String) -> String {
        for session in WorkoutProgram.sessions {
            if let ex = session.exercises.first(where: { $0.id == id }) {
                return ex.name
            }
        }
        return id
    }
}
