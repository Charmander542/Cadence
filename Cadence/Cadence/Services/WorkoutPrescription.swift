import Foundation

/// Hypertrophy prescription: warm-up sets, RIR targets, and double-progression math.
///
/// Based on common evidence-backed practice:
/// - Double progression within a rep range (add reps until top of range, then load).
/// - RIR-guided autoregulation (compounds: top set ~0–1 RIR, back-offs ~2 RIR).
/// - Ramp warm-ups (lighter compounds: one set; heavier: two quick sets).
enum WorkoutPrescription {
    struct WarmupSpec: Hashable {
        var fraction: Double
        var reps: Int
    }

    // MARK: - Set building

    static func buildSetRows(
        state: ExerciseProgressionState,
        template: WorkoutExerciseTemplate
    ) -> [ActiveSetRow] {
        switch template.progressionType {
        case .time:
            return buildTimedRows(state: state, template: template)
        case .repOnly, .weightRep:
            let workingWeight = state.currentWeight
            var rows: [ActiveSetRow] = []
            let warmups = warmupSpecs(for: template, workingWeight: workingWeight)
            for (idx, spec) in warmups.enumerated() {
                let w = roundLoad(spec.fraction * workingWeight, increment: template.weightIncrement)
                guard w > 0, w < workingWeight else { continue }
                rows.append(ActiveSetRow(
                    id: -(warmups.count - idx),
                    kind: .warmup,
                    targetReps: spec.reps,
                    weight: w,
                    reps: spec.reps,
                    rir: nil,
                    durationSec: nil,
                    isCompleted: false
                ))
            }
            let targets = workingRepTargets(state: state, template: template)
            for i in 0..<template.targetSets {
                let target = targets[safe: i] ?? template.repMin
                rows.append(ActiveSetRow(
                    id: i,
                    kind: .working,
                    targetReps: target,
                    weight: workingWeight,
                    reps: target,
                    rir: prescribedRIR(workingIndex: i, template: template),
                    durationSec: nil,
                    isCompleted: false
                ))
            }
            return rows
        }
    }

    static func refreshWarmupWeights(
        in sets: inout [ActiveSetRow],
        workingWeight: Double,
        template: WorkoutExerciseTemplate
    ) {
        let specs = warmupSpecs(for: template, workingWeight: workingWeight)
        let warmupIndices = sets.indices
            .filter { sets[$0].isWarmup }
            .sorted { sets[$0].id < sets[$1].id }
        for (specIdx, setIdx) in warmupIndices.enumerated() {
            guard specIdx < specs.count else { continue }
            let spec = specs[specIdx]
            let w = roundLoad(spec.fraction * workingWeight, increment: template.weightIncrement)
            if w > 0, w < workingWeight {
                sets[setIdx].weight = w
            }
        }
    }

    // MARK: - Warm-up math

    static func warmupSpecs(
        for template: WorkoutExerciseTemplate,
        workingWeight: Double
    ) -> [WarmupSpec] {
        guard template.progressionType != .time else { return [] }
        guard workingWeight > 0 else { return [] }

        switch template.category {
        case .largeCompound:
            if workingWeight >= 35 {
                return [
                    WarmupSpec(fraction: 0.5, reps: 8),
                    WarmupSpec(fraction: 0.75, reps: 3),
                ]
            }
            if workingWeight >= 15 {
                return [WarmupSpec(fraction: 0.5, reps: 8)]
            }
            return []
        case .smallIsolation:
            if workingWeight >= 30 {
                return [WarmupSpec(fraction: 0.5, reps: 10)]
            }
            return []
        case .abs, .bodyweight:
            return []
        }
    }

    static func warmupCount(for template: WorkoutExerciseTemplate, workingWeight: Double) -> Int {
        warmupSpecs(for: template, workingWeight: workingWeight).count
    }

    // MARK: - RIR

    /// Top working set: 0 RIR on compounds, 1 on isolation. Back-offs: 2 RIR.
    static func prescribedRIR(workingIndex: Int, template: WorkoutExerciseTemplate) -> Int? {
        guard template.progressionType != .time else { return nil }
        if workingIndex == 0 {
            switch template.category {
            case .largeCompound: return 0
            case .smallIsolation, .abs: return 1
            case .bodyweight: return 1
            }
        }
        return 2
    }

    // MARK: - Double progression targets

    static func workingRepTargets(
        state: ExerciseProgressionState,
        template: WorkoutExerciseTemplate
    ) -> [Int] {
        guard let last = state.lastWorkout, !last.reps.isEmpty else {
            return Array(repeating: template.repMin, count: template.targetSets)
        }

        let count = template.targetSets
        var targets = (0..<count).map { i -> Int in
            let prev = last.reps[safe: i] ?? last.reps.last ?? template.repMin
            return min(template.repMax, max(template.repMin, prev + 1))
        }

        // After a load increase, reps reset toward the bottom of the range.
        if last.weight + 0.01 < state.currentWeight {
            return Array(repeating: template.repMin, count: count)
        }

        // If last session hit the ceiling at low RIR, keep pushing repMax on weak sets.
        if last.reps.allSatisfy({ $0 >= template.repMax }),
           rirAllowsProgression(last.rir, template: template) {
            return Array(repeating: template.repMax, count: count)
        }

        return targets
    }

    // MARK: - Progression decisions (RIR-aware)

    struct ProgressionInput: Hashable {
        var reps: [Int]
        var rirs: [Int?]
        var weightUsed: Double
        var durations: [Int]
    }

    static func workingSetInput(from logged: [LoggedSet]) -> ProgressionInput {
        let working = logged.filter { $0.completed && !$0.isWarmup }
        return ProgressionInput(
            reps: working.map(\.reps),
            rirs: working.map(\.rir),
            weightUsed: working.map(\.weight).max() ?? 0,
            durations: working.compactMap(\.durationSec)
        )
    }

    static func shouldIncreaseWeight(
        input: ProgressionInput,
        template: WorkoutExerciseTemplate,
        currentWeight: Double
    ) -> Bool {
        let reps = input.reps
        guard !reps.isEmpty else { return false }

        switch template.progressionType {
        case .time:
            let best = input.durations.max() ?? 0
            return best >= (template.durationMaxSec ?? template.repMax)
        case .repOnly:
            return reps.allSatisfy { $0 >= template.repMax }
        case .weightRep:
            // Classic double progression: all sets at top of rep range.
            if reps.allSatisfy({ $0 >= template.repMax }) {
                return rirAllowsProgression(input.rirs.compactMap { $0 }, template: template)
            }
            // Autoregulation: load was too light (high RIR, near-max reps).
            let rirs = input.rirs.compactMap { $0 }
            if !rirs.isEmpty, rirs.allSatisfy({ $0 >= 3 }),
               reps.allSatisfy({ $0 >= template.repMax - 1 }) {
                return true
            }
            // Top set at rep ceiling with 0–1 RIR — ready to add load even if back-offs lag.
            if let topReps = reps.first {
                let topRIR = input.rirs.first ?? nil
                if topReps >= template.repMax, (topRIR ?? 1) <= 1 {
                    return true
                }
            }
            return false
        }
    }

    static func shouldDecreaseWeight(
        input: ProgressionInput,
        template: WorkoutExerciseTemplate
    ) -> Bool {
        let reps = input.reps
        guard !reps.isEmpty else { return false }

        switch template.progressionType {
        case .time, .repOnly:
            return false
        case .weightRep:
            if reps.contains(where: { $0 < template.repMin }) { return true }
            for (rep, rir) in zip(reps, input.rirs) {
                if (rir ?? 0) == 0, rep < template.repMin { return true }
            }
            return false
        }
    }

    static func nextWeightAfterIncrease(
        weightUsed: Double,
        template: WorkoutExerciseTemplate
    ) -> Double {
        min(WorkoutProgram.maxDumbbellLbs, weightUsed + template.weightIncrement)
    }

    static func nextWeightAfterDecrease(
        weightUsed: Double,
        template: WorkoutExerciseTemplate
    ) -> Double {
        max(0, weightUsed - template.weightIncrement)
    }

    // MARK: - UI hints

    static func autoHint(for set: ActiveSetRow, template: WorkoutExerciseTemplate) -> String {
        switch template.progressionType {
        case .time:
            let sec = set.durationSec ?? set.targetReps
            return "\(sec)s"
        case .repOnly, .weightRep:
            if set.isWarmup {
                return "\(formatWeightShort(set.weight))×\(set.targetReps)"
            }
            let repStr = set.targetReps >= template.repMax ? "\(set.targetReps)+" : "\(set.targetReps)"
            var hint = template.progressionType == .repOnly
                ? "\(repStr) reps"
                : "\(formatWeightShort(set.weight))×\(repStr)"
            if let rir = set.rir {
                hint += " · \(rir) RIR"
            }
            return hint
        }
    }

    static func setLabel(for set: ActiveSetRow) -> String {
        switch set.kind {
        case .warmup: return "W"
        case .working: return set.id == 0 ? "F" : "\(set.id + 1)"
        }
    }

    static func goalHint(
        state: ExerciseProgressionState,
        template: WorkoutExerciseTemplate
    ) -> String {
        switch template.progressionType {
        case .time:
            let sec = state.currentDurationSec ?? template.durationMinSec ?? 30
            return "Hold \(sec)s · build toward \(template.durationMaxSec ?? sec)s."
        case .repOnly:
            return "Hit \(template.repMin)–\(template.repMax) reps. Top set ~\(prescribedRIR(workingIndex: 0, template: template) ?? 2) RIR."
        case .weightRep:
            let warmups = warmupCount(for: template, workingWeight: state.currentWeight)
            let warmupNote = warmups > 0 ? "\(warmups) warm-up sets · " : ""
            return "\(warmupNote)\(WorkoutProgression.formatWeight(state.currentWeight)) · \(template.targetSets)×\(template.repMin)–\(template.repMax) · double progression."
        }
    }

    // MARK: - Helpers

    static func roundLoad(_ weight: Double, increment: Double) -> Double {
        guard increment > 0 else { return max(0, weight.rounded()) }
        return max(0, (weight / increment).rounded() * increment)
    }

    static func formatWeightShort(_ w: Double) -> String {
        if abs(w - w.rounded()) < 0.05 { return "\(Int(w.rounded()))" }
        return String(format: "%.1f", w)
    }

    private static func buildTimedRows(
        state: ExerciseProgressionState,
        template: WorkoutExerciseTemplate
    ) -> [ActiveSetRow] {
        let sec = state.currentDurationSec ?? template.durationMinSec ?? 30
        return (0..<template.targetSets).map { i in
            ActiveSetRow(
                id: i,
                kind: .working,
                targetReps: sec,
                weight: 0,
                reps: sec,
                rir: nil,
                durationSec: sec,
                isCompleted: false
            )
        }
    }

    private static func rirAllowsProgression(_ rirs: [Int]?, template: WorkoutExerciseTemplate) -> Bool {
        guard let rirs, !rirs.isEmpty else { return true }
        // Allow load increase when effort was sufficient (not stopping 3+ reps shy).
        return rirs.allSatisfy { $0 <= 2 }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
