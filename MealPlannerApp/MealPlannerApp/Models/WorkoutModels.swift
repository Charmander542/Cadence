import Foundation
import Combine

// MARK: - Prescription (program template — separate from progression state)

enum WorkoutProgressionType: String, Codable, Hashable {
    case weightRep = "WEIGHT_REP"
    case repOnly = "REP_ONLY"
    case time = "TIME"
}

enum WorkoutExerciseCategory: String, Codable, Hashable {
    case largeCompound
    case smallIsolation
    case abs
    case bodyweight
}

struct WorkoutExerciseTemplate: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    /// For TIME exercises: seconds min/max instead of reps.
    var durationMinSec: Int?
    var durationMaxSec: Int?
    var perSide: Bool
    var category: WorkoutExerciseCategory
    var progressionType: WorkoutProgressionType
    var weightIncrement: Double
    var muscleGroup: String
    var defaultRestSec: Int
}

struct WorkoutSessionTemplate: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var shortName: String
    var focus: String
    /// Calendar weekday: 1=Sun … 7=Sat (Foundation Calendar).
    var weekday: Int
    var exercises: [WorkoutExerciseTemplate]
}

enum WorkoutProgram {
    static let maxDumbbellLbs = 50.0

    /// Rotation order for missed-day catch-up.
    static let rotation: [String] = ["upper-a", "lower-a", "upper-b", "lower-b"]

    static let sessions: [WorkoutSessionTemplate] = [
        upperA, lowerA, upperB, lowerB,
    ]

    static func session(id: String) -> WorkoutSessionTemplate? {
        sessions.first { $0.id == id }
    }

    static func scheduledSession(for weekday: Int) -> WorkoutSessionTemplate? {
        sessions.first { $0.weekday == weekday }
    }

    static var restWeekdays: Set<Int> { [1, 4, 6] } // Sun, Wed, Fri

    // MARK: Templates

    private static let upperA = WorkoutSessionTemplate(
        id: "upper-a",
        name: "Upper A",
        shortName: "Upper",
        focus: "Push + pull + arms",
        weekday: 2, // Monday
        exercises: [
            ex("db-bench", "Dumbbell Bench Press", 4, 6, 10, cat: .largeCompound, inc: 5, muscle: "chest", rest: 90),
            ex("db-floor-press", "Dumbbell Floor Press", 3, 8, 12, cat: .largeCompound, inc: 5, muscle: "chest", rest: 75),
            ex("db-row", "One-Arm Dumbbell Row", 4, 8, 12, cat: .largeCompound, inc: 5, muscle: "back", rest: 75, perSide: true),
            ex("db-lateral", "Dumbbell Lateral Raise", 3, 12, 20, cat: .smallIsolation, inc: 2.5, muscle: "shoulders", rest: 60),
            ex("db-curl", "Dumbbell Curl", 3, 8, 12, cat: .smallIsolation, inc: 2.5, muscle: "biceps", rest: 60),
            ex("db-oh-tri", "Overhead Dumbbell Triceps Extension", 3, 10, 15, cat: .smallIsolation, inc: 2.5, muscle: "triceps", rest: 60),
            ex("weighted-crunch", "Weighted Crunch", 3, 10, 15, cat: .abs, inc: 5, muscle: "abs", rest: 45),
        ]
    )

    private static let lowerA = WorkoutSessionTemplate(
        id: "lower-a",
        name: "Lower A",
        shortName: "Lower",
        focus: "Legs + glutes + core",
        weekday: 3, // Tuesday
        exercises: [
            ex("bss", "Bulgarian Split Squat", 4, 8, 12, cat: .largeCompound, inc: 5, muscle: "quads", rest: 90, perSide: true),
            ex("db-rdl", "Dumbbell Romanian Deadlift", 4, 8, 12, cat: .largeCompound, inc: 5, muscle: "hamstrings", rest: 90),
            ex("goblet-squat", "Goblet Squat", 3, 10, 15, cat: .largeCompound, type: .repOnly, inc: 5, muscle: "quads", rest: 75),
            ex("db-hip-thrust", "Dumbbell Hip Thrust", 3, 10, 15, cat: .largeCompound, inc: 5, muscle: "glutes", rest: 75),
            ex("calf-raise", "Standing Calf Raise", 4, 12, 20, cat: .smallIsolation, type: .repOnly, inc: 5, muscle: "calves", rest: 45),
            ex("lying-leg-raise", "Lying Leg Raise", 3, 8, 15, cat: .abs, type: .repOnly, inc: 0, muscle: "abs", rest: 45),
            ex("reverse-crunch", "Reverse Crunch", 3, 10, 20, cat: .abs, type: .repOnly, inc: 0, muscle: "abs", rest: 45),
            timeEx("side-plank", "Side Plank", 2, 30, 60, muscle: "abs", rest: 30, perSide: true),
        ]
    )

    private static let upperB = WorkoutSessionTemplate(
        id: "upper-b",
        name: "Upper B",
        shortName: "Upper",
        focus: "Press + delts + arms",
        weekday: 5, // Thursday
        exercises: [
            ex("db-bench", "Dumbbell Bench Press", 3, 8, 12, cat: .largeCompound, inc: 5, muscle: "chest", rest: 90),
            ex("db-floor-press", "Dumbbell Floor Press", 3, 8, 12, cat: .largeCompound, inc: 5, muscle: "chest", rest: 75),
            ex("db-row", "One-Arm Dumbbell Row", 4, 8, 12, cat: .largeCompound, inc: 5, muscle: "back", rest: 75, perSide: true),
            ex("db-shoulder-press", "Dumbbell Shoulder Press", 3, 8, 12, cat: .largeCompound, inc: 5, muscle: "shoulders", rest: 75),
            ex("db-lateral", "Dumbbell Lateral Raise", 3, 12, 20, cat: .smallIsolation, inc: 2.5, muscle: "shoulders", rest: 60),
            ex("rear-delt-fly", "Rear-Delt Fly", 3, 12, 20, cat: .smallIsolation, inc: 2.5, muscle: "shoulders", rest: 60),
            ex("hammer-curl", "Hammer Curl", 3, 8, 12, cat: .smallIsolation, inc: 2.5, muscle: "biceps", rest: 60),
            ex("db-skull", "Dumbbell Skull Crusher", 3, 10, 15, cat: .smallIsolation, inc: 2.5, muscle: "triceps", rest: 60),
            ex("weighted-crunch", "Weighted Crunch", 3, 10, 15, cat: .abs, inc: 5, muscle: "abs", rest: 45),
        ]
    )

    private static let lowerB = WorkoutSessionTemplate(
        id: "lower-b",
        name: "Lower B",
        shortName: "Lower",
        focus: "Legs + glutes + core",
        weekday: 7, // Saturday
        exercises: [
            ex("bss", "Bulgarian Split Squat", 3, 8, 12, cat: .largeCompound, inc: 5, muscle: "quads", rest: 90, perSide: true),
            ex("db-rdl", "Dumbbell Romanian Deadlift", 4, 8, 12, cat: .largeCompound, inc: 5, muscle: "hamstrings", rest: 90),
            ex("goblet-squat", "Goblet Squat", 3, 10, 15, cat: .largeCompound, type: .repOnly, inc: 5, muscle: "quads", rest: 75),
            ex("db-hip-thrust", "Dumbbell Hip Thrust", 3, 10, 15, cat: .largeCompound, inc: 5, muscle: "glutes", rest: 75),
            ex("calf-raise", "Standing Calf Raise", 4, 12, 20, cat: .smallIsolation, type: .repOnly, inc: 5, muscle: "calves", rest: 45),
            ex("lying-leg-raise", "Lying Leg Raise", 3, 8, 15, cat: .abs, type: .repOnly, inc: 0, muscle: "abs", rest: 45),
            ex("reverse-crunch", "Reverse Crunch", 3, 10, 20, cat: .abs, type: .repOnly, inc: 0, muscle: "abs", rest: 45),
            timeEx("side-plank", "Side Plank", 2, 30, 60, muscle: "abs", rest: 30, perSide: true),
        ]
    )

    private static func ex(
        _ id: String,
        _ name: String,
        _ sets: Int,
        _ min: Int,
        _ max: Int,
        cat: WorkoutExerciseCategory,
        type: WorkoutProgressionType = .weightRep,
        inc: Double,
        muscle: String,
        rest: Int,
        perSide: Bool = false
    ) -> WorkoutExerciseTemplate {
        WorkoutExerciseTemplate(
            id: id,
            name: name,
            targetSets: sets,
            repMin: min,
            repMax: max,
            durationMinSec: nil,
            durationMaxSec: nil,
            perSide: perSide,
            category: cat,
            progressionType: type,
            weightIncrement: inc,
            muscleGroup: muscle,
            defaultRestSec: rest
        )
    }

    private static func timeEx(
        _ id: String,
        _ name: String,
        _ sets: Int,
        _ minSec: Int,
        _ maxSec: Int,
        muscle: String,
        rest: Int,
        perSide: Bool = false
    ) -> WorkoutExerciseTemplate {
        WorkoutExerciseTemplate(
            id: id,
            name: name,
            targetSets: sets,
            repMin: minSec,
            repMax: maxSec,
            durationMinSec: minSec,
            durationMaxSec: maxSec,
            perSide: perSide,
            category: .bodyweight,
            progressionType: .time,
            weightIncrement: 0,
            muscleGroup: muscle,
            defaultRestSec: rest
        )
    }
}

// MARK: - Progression state

struct ExerciseLastWorkout: Hashable, Codable {
    var weight: Double
    var reps: [Int]
    /// Optional RIR per set (same length as reps when present).
    var rir: [Int]?
    var note: String?
}

struct ExerciseProgressionState: Identifiable, Hashable, Codable {
    var id: String { exerciseID }
    var exerciseID: String
    var exerciseName: String
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    var currentWeight: Double
    var weightIncrement: Double
    var progressionType: WorkoutProgressionType
    var currentDurationSec: Int?
    /// e.g. "pause", "3sec-eccentric", "single-leg"
    var difficultyTag: String?
    var lastWorkout: ExerciseLastWorkout?
    /// Consecutive sessions where average reps dropped vs prior.
    var decliningStreak: Int
}

struct WorkoutPlanState: Hashable, Codable {
    /// Index into `WorkoutProgram.rotation` for the next session to complete.
    var nextRotationIndex: Int
    var exerciseStates: [String: ExerciseProgressionState]
    var lastCompletedSessionID: String?
    var lastCompletedAt: Date?

    static var fresh: WorkoutPlanState {
        WorkoutPlanState(nextRotationIndex: 0, exerciseStates: [:], lastCompletedSessionID: nil, lastCompletedAt: nil)
    }
}

// MARK: - Logged workout

struct LoggedSet: Hashable, Codable {
    var reps: Int
    var weight: Double
    var rir: Int?
    var durationSec: Int?
    var completed: Bool
    /// Warm-up sets are logged but excluded from progression.
    var isWarmup: Bool = false
}

struct LoggedExercise: Hashable, Codable {
    var exerciseID: String
    var name: String
    var sets: [LoggedSet]
    var prescriptionWeight: Double
    var progressionNote: String?
}

struct LoggedWorkout: Identifiable, Hashable, Codable {
    var id: UUID
    var sessionID: String
    var sessionName: String
    var startedAt: Date
    var finishedAt: Date
    var durationSec: Int
    var exercises: [LoggedExercise]
    var loggedIncomplete: Bool
}

// MARK: - Active session (in-memory)

enum ActiveSetKind: String, Hashable, Codable {
    case warmup
    case working
}

struct ActiveSetRow: Identifiable, Hashable {
    var id: Int
    var kind: ActiveSetKind
    var targetReps: Int
    var weight: Double
    var reps: Int
    var rir: Int?
    var durationSec: Int?
    var isCompleted: Bool

    var isWarmup: Bool { kind == .warmup }
    var isWorking: Bool { kind == .working }
}

struct ActiveExercise: Identifiable, Hashable {
    var id: String
    var template: WorkoutExerciseTemplate
    var weight: Double
    var durationSec: Int?
    var difficultyTag: String?
    var previous: ExerciseLastWorkout?
    var goalHint: String
    var sets: [ActiveSetRow]
}

/// Value snapshot used when finishing / logging a workout.
struct LiveWorkout: Hashable {
    var session: WorkoutSessionTemplate
    var exercises: [ActiveExercise]
    var startedAt: Date
    var restRemaining: Int
    var restTotal: Int

    var elapsedSec: Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

/// Reference-type live session so set toggles only redraw one exercise (Hevy-like snappiness).
@MainActor
final class LiveWorkoutController: ObservableObject {
    let session: WorkoutSessionTemplate
    let startedAt: Date
    let exercises: [LiveExerciseController]
    @Published var restRemaining: Int = 0
    @Published var restTotal: Int = 0
    @Published private(set) var completedSetCount: Int = 0

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    init(session: WorkoutSessionTemplate, exercises: [ActiveExercise], startedAt: Date = .now) {
        self.session = session
        self.startedAt = startedAt
        self.exercises = exercises.map { LiveExerciseController(from: $0) }
        refreshCompletedCount()
    }

    func refreshCompletedCount() {
        completedSetCount = exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    func snapshot() -> LiveWorkout {
        LiveWorkout(
            session: session,
            exercises: exercises.map(\.asValue),
            startedAt: startedAt,
            restRemaining: restRemaining,
            restTotal: restTotal
        )
    }
}

@MainActor
final class LiveExerciseController: ObservableObject, Identifiable {
    let id: String
    let template: WorkoutExerciseTemplate
    let previous: ExerciseLastWorkout?
    let goalHint: String
    let difficultyTag: String?
    let durationSec: Int?
    @Published var weight: Double
    @Published var sets: [ActiveSetRow]

    init(from exercise: ActiveExercise) {
        id = exercise.id
        template = exercise.template
        previous = exercise.previous
        goalHint = exercise.goalHint
        difficultyTag = exercise.difficultyTag
        durationSec = exercise.durationSec
        weight = exercise.weight
        sets = exercise.sets
    }

    var asValue: ActiveExercise {
        ActiveExercise(
            id: id,
            template: template,
            weight: weight,
            durationSec: durationSec,
            difficultyTag: difficultyTag,
            previous: previous,
            goalHint: goalHint,
            sets: sets
        )
    }

    func updateSet(id setID: Int, _ update: (inout ActiveSetRow) -> Void) {
        guard let idx = sets.firstIndex(where: { $0.id == setID }) else { return }
        update(&sets[idx])
    }

    func bumpWeight(by delta: Double) {
        weight = max(0, weight + delta)
        for i in sets.indices where sets[i].isWorking {
            sets[i].weight = weight
        }
        WorkoutPrescription.refreshWarmupWeights(in: &sets, workingWeight: weight, template: template)
    }
}
