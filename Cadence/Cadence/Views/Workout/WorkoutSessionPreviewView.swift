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
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    headerBlock
                    exerciseList
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, Theme.Space.xl * 5)
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
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func exerciseRow(_ ex: WorkoutExerciseTemplate) -> some View {
        let state = plan.exerciseStates[ex.id] ?? WorkoutProgression.seed(for: ex)
        let prescribed = WorkoutPrescription.buildSetRows(state: state, template: ex)
        return Button {
            guideExercise = ex
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.md) {
                ExerciseThumbnail(exercise: ex, selected: false, width: 76, heightRatio: 1.45)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text(ex.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        ForEach(prescribed) { set in
                            HStack(spacing: Theme.Space.sm) {
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
                                        .padding(.horizontal, Theme.Space.sm - 2)
                                        .padding(.vertical, Theme.Space.xs / 2)
                                        .background(Theme.accent.opacity(0.15), in: Capsule())
                                }
                            }
                        }
                    }
                    MuscleTagRow(tags: WorkoutVisuals.muscleTags(for: ex))
                }
            }
            .padding(Theme.Space.md + 2)
            .contentShape(Rectangle())
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
            Text("START WORKOUT")
                .font(.headline.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.lg)
                .background(Theme.cta, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .shadow(color: Theme.cta.opacity(0.35), radius: 10, y: 4)
        }
        .accessibilityLabel("Start \(session.name) workout")
        .accessibilityHint("Begins live set tracking")
        .padding(.horizontal, Theme.Space.lg)
        .padding(.bottom, Theme.Space.md)
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
