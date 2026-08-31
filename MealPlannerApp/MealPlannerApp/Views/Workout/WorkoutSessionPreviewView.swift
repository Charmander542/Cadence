import SwiftUI
import SwiftData

/// Pre-workout screen — exercise list, targets, muscle tags, Start Workout (reference-app style).
struct WorkoutSessionPreviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSessionTemplate
    var planEntity: WorkoutPlanEntity?

    @State private var localPlan: WorkoutPlanEntity?
    @State private var guideExercise: WorkoutExerciseTemplate?

    private var plan: WorkoutPlanState {
        (planEntity ?? localPlan)?.decoded() ?? .fresh
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock
                    exerciseList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            startButton
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if localPlan == nil, planEntity == nil {
                localPlan = WorkoutStore.plan(in: modelContext)
            }
        }
        .sheet(item: $guideExercise) { ex in
            ExerciseGuideView(exercise: ex)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(session.exercises.count) Exercises")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text("Estimated workout time is \(WorkoutVisuals.estimatedMinutes(exerciseCount: session.exercises.count)) min")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(session.focus)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.exercises.count) exercises, estimated \(WorkoutVisuals.estimatedMinutes(exerciseCount: session.exercises.count)) minutes, \(session.focus)")
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(session.exercises) { ex in
                exerciseRow(ex)
                if ex.id != session.exercises.last?.id {
                    Divider().overlay(Theme.gridDivider)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func exerciseRow(_ ex: WorkoutExerciseTemplate) -> some View {
        let state = plan.exerciseStates[ex.id] ?? WorkoutProgression.seed(for: ex)
        let prescribed = WorkoutPrescription.buildSetRows(state: state, template: ex)
        return Button {
            guideExercise = ex
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ExerciseThumbnail(exercise: ex, selected: false, width: 76, heightRatio: 1.45)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(ex.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(prescribed) { set in
                            HStack(spacing: 8) {
                                Text(WorkoutVisuals.setLabel(for: set))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: 18, height: 18)
                                    .background(Theme.sunken, in: Circle())
                                Text(WorkoutPrescription.autoHint(for: set, template: ex))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                if set.isWorking,
                                   let prev = state.lastWorkout,
                                   set.id < prev.reps.count {
                                    Text(prevLabel(prev, index: set.id, ex: ex))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(Theme.accent.opacity(0.85))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.accent.opacity(0.15), in: Capsule())
                                }
                            }
                        }
                    }
                    MuscleTagRow(tags: WorkoutVisuals.muscleTags(for: ex))
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(exerciseRowAccessibilityLabel(ex, state: state, prescribed: prescribed))
        .accessibilityHint("Opens exercise form guide")
    }

    private func exerciseRowAccessibilityLabel(
        _ ex: WorkoutExerciseTemplate,
        state: ExerciseProgressionState,
        prescribed: [ActiveSetRow]
    ) -> String {
        let sets = prescribed.map { WorkoutPrescription.autoHint(for: $0, template: ex) }.joined(separator: ", ")
        var label = "\(ex.name), \(sets)"
        if let prev = state.lastWorkout {
            label += ", previous session logged"
        }
        return label
    }

    private func prevLabel(_ prev: ExerciseLastWorkout, index: Int, ex: WorkoutExerciseTemplate) -> String {
        let rep = index < prev.reps.count ? prev.reps[index] : (prev.reps.last ?? 0)
        if ex.progressionType == .time { return "\(rep)s" }
        if prev.weight > 0 {
            return "\(WorkoutProgression.formatWeight(prev.weight))×\(rep)"
        }
        return "\(rep)"
    }

    private var startButton: some View {
        Button {
            let entity = planEntity ?? localPlan ?? WorkoutStore.plan(in: modelContext)
            appModel.beginLiveWorkout(session: session, plan: entity.decoded())
            dismiss()
        } label: {
            Text("Start Workout")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel("Start \(session.name) workout")
        .accessibilityHint("Begins live set tracking")
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas], startPoint: .top, endPoint: .bottom)
                .frame(height: 90)
                .allowsHitTesting(false),
            alignment: .bottom
        )
    }
}

struct WorkoutPreviewLauncher: ViewModifier {
    @Binding var session: WorkoutSessionTemplate?
    var planEntity: WorkoutPlanEntity?

    func body(content: Content) -> some View {
        content
            .sheet(item: $session) { s in
                NavigationStack {
                    WorkoutSessionPreviewView(session: s, planEntity: planEntity)
                }
            }
    }
}

extension View {
    func workoutPreviewSheet(session: Binding<WorkoutSessionTemplate?>, planEntity: WorkoutPlanEntity? = nil) -> some View {
        modifier(WorkoutPreviewLauncher(session: session, planEntity: planEntity))
    }
}
