import XCTest
@testable import Cadence

final class WorkoutProgressionTests: XCTestCase {
    private func benchPress() -> WorkoutExerciseTemplate {
        WorkoutProgram.sessions.flatMap(\.exercises).first { $0.id == "db-bench" }!
    }

    private func lateralRaise() -> WorkoutExerciseTemplate {
        WorkoutProgram.sessions.flatMap(\.exercises).first { $0.id == "db-lateral" }!
    }

    func testCompoundWarmupsAtWorkingWeight() {
        let template = benchPress()
        var state = WorkoutProgression.seed(for: template)
        state.currentWeight = 40

        let rows = WorkoutPrescription.buildSetRows(state: state, template: template)
        let warmups = rows.filter(\.isWarmup)
        let working = rows.filter(\.isWorking)

        XCTAssertEqual(warmups.count, 2)
        XCTAssertEqual(working.count, template.targetSets)
        XCTAssertTrue(warmups.allSatisfy { $0.weight < state.currentWeight })
        XCTAssertEqual(warmups.map(\.weight), [20, 30])
        XCTAssertEqual(working.first?.rir, 0)
        XCTAssertEqual(working.dropFirst().first?.rir, 2)
    }

    func testIsolationSkipsWarmupsAtLightWeight() {
        let template = lateralRaise()
        var state = WorkoutProgression.seed(for: template)
        state.currentWeight = 15

        let rows = WorkoutPrescription.buildSetRows(state: state, template: template)
        XCTAssertTrue(rows.filter(\.isWarmup).isEmpty)
        XCTAssertEqual(rows.filter(\.isWorking).count, template.targetSets)
    }

    func testDoubleProgressionIncreasesWeightAtRepCeiling() {
        let template = benchPress()
        var state = WorkoutProgression.seed(for: template)
        state.currentWeight = 35
        state.lastWorkout = ExerciseLastWorkout(
            weight: 35,
            reps: [10, 10, 10, 10],
            rir: [1, 2, 2, 2],
            note: nil
        )

        let input = WorkoutPrescription.ProgressionInput(
            reps: [10, 10, 10, 10],
            rirs: [1, 2, 2, 2],
            weightUsed: 35,
            durations: []
        )
        XCTAssertTrue(
            WorkoutPrescription.shouldIncreaseWeight(
                input: input,
                template: template,
                currentWeight: state.currentWeight
            )
        )

        var plan = WorkoutPlanState.fresh
        plan.exerciseStates[template.id] = state
        let notes = WorkoutProgression.apply(
            logged: [
                LoggedExercise(
                    exerciseID: template.id,
                    name: template.name,
                    sets: (0..<4).map {
                        LoggedSet(reps: 10, weight: 35, rir: $0 == 0 ? 1 : 2, completed: true)
                    },
                    prescriptionWeight: 35,
                    progressionNote: nil
                ),
            ],
            sessionID: "upper-a",
            into: &plan
        )

        XCTAssertEqual(plan.exerciseStates[template.id]?.currentWeight, 40)
        XCTAssertFalse(notes.isEmpty)
    }

    func testMissedRepFloorDecreasesWeight() {
        let template = benchPress()
        var state = WorkoutProgression.seed(for: template)
        state.currentWeight = 40

        let input = WorkoutPrescription.ProgressionInput(
            reps: [5, 5, 5, 5],
            rirs: [0, 1, 2, 2],
            weightUsed: 40,
            durations: []
        )
        XCTAssertTrue(WorkoutPrescription.shouldDecreaseWeight(input: input, template: template))

        var plan = WorkoutPlanState.fresh
        plan.exerciseStates[template.id] = state
        WorkoutProgression.apply(
            logged: [
                LoggedExercise(
                    exerciseID: template.id,
                    name: template.name,
                    sets: [
                        LoggedSet(reps: 5, weight: 40, rir: 0, completed: true),
                        LoggedSet(reps: 5, weight: 40, rir: 1, completed: true),
                        LoggedSet(reps: 5, weight: 40, rir: 2, completed: true),
                        LoggedSet(reps: 5, weight: 40, rir: 2, completed: true),
                    ],
                    prescriptionWeight: 40,
                    progressionNote: nil
                ),
            ],
            sessionID: "upper-a",
            into: &plan
        )

        XCTAssertEqual(plan.exerciseStates[template.id]?.currentWeight, 35)
    }

    func testWarmupsExcludedFromProgression() {
        let template = benchPress()
        var state = WorkoutProgression.seed(for: template)
        state.currentWeight = 40

        var plan = WorkoutPlanState.fresh
        plan.exerciseStates[template.id] = state
        WorkoutProgression.apply(
            logged: [
                LoggedExercise(
                    exerciseID: template.id,
                    name: template.name,
                    sets: [
                        LoggedSet(reps: 8, weight: 20, completed: true, isWarmup: true),
                        LoggedSet(reps: 3, weight: 30, completed: true, isWarmup: true),
                        LoggedSet(reps: 9, weight: 40, rir: 2, completed: true),
                        LoggedSet(reps: 9, weight: 40, rir: 2, completed: true),
                        LoggedSet(reps: 9, weight: 40, rir: 2, completed: true),
                        LoggedSet(reps: 8, weight: 40, rir: 2, completed: true),
                    ],
                    prescriptionWeight: 40,
                    progressionNote: nil
                ),
            ],
            sessionID: "upper-a",
            into: &plan
        )

        XCTAssertEqual(plan.exerciseStates[template.id]?.lastWorkout?.reps, [9, 9, 9, 8])
        XCTAssertEqual(plan.exerciseStates[template.id]?.currentWeight, 40)
    }

    func testHighRIRAutoregulationIncreasesWeight() {
        let template = benchPress()
        let input = WorkoutPrescription.ProgressionInput(
            reps: [9, 9, 9, 9],
            rirs: [3, 3, 4, 4],
            weightUsed: 35,
            durations: []
        )
        XCTAssertTrue(
            WorkoutPrescription.shouldIncreaseWeight(
                input: input,
                template: template,
                currentWeight: 35
            )
        )
    }
}
