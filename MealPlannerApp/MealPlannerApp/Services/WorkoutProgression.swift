import Foundation

/// Progression engine: prescription templates stay separate from mutable state.
enum WorkoutProgression {
    struct Decision: Hashable {
        var nextWeight: Double
        var nextDurationSec: Int?
        var difficultyTag: String?
        var message: String
        var suggestedGoal: String
    }

    static func ensureStates(in plan: inout WorkoutPlanState) {
        for session in WorkoutProgram.sessions {
            for ex in session.exercises {
                if plan.exerciseStates[ex.id] == nil {
                    plan.exerciseStates[ex.id] = seed(for: ex)
                } else if var existing = plan.exerciseStates[ex.id] {
                    // Keep user's weight/history; refresh prescription bounds from template.
                    existing.targetSets = ex.targetSets
                    existing.repMin = ex.repMin
                    existing.repMax = ex.repMax
                    existing.weightIncrement = ex.weightIncrement
                    existing.progressionType = ex.progressionType
                    existing.exerciseName = ex.name
                    plan.exerciseStates[ex.id] = existing
                }
            }
        }
    }

    static func seed(for ex: WorkoutExerciseTemplate) -> ExerciseProgressionState {
        let startWeight: Double
        switch ex.category {
        case .largeCompound: startWeight = 30
        case .smallIsolation: startWeight = 15
        case .abs: startWeight = 10
        case .bodyweight: startWeight = 0
        }
        return ExerciseProgressionState(
            exerciseID: ex.id,
            exerciseName: ex.name,
            targetSets: ex.targetSets,
            repMin: ex.repMin,
            repMax: ex.repMax,
            currentWeight: ex.progressionType == .weightRep ? startWeight : (ex.progressionType == .repOnly ? startWeight : 0),
            weightIncrement: ex.weightIncrement,
            progressionType: ex.progressionType,
            currentDurationSec: ex.durationMinSec,
            difficultyTag: nil,
            lastWorkout: nil,
            decliningStreak: 0
        )
    }

    static func buildActiveExercises(
        session: WorkoutSessionTemplate,
        plan: WorkoutPlanState
    ) -> [ActiveExercise] {
        session.exercises.map { template in
            let state = plan.exerciseStates[template.id] ?? seed(for: template)
            let decision = previewDecision(state: state, template: template)
            let rows = WorkoutPrescription.buildSetRows(state: state, template: template)
            return ActiveExercise(
                id: template.id,
                template: template,
                weight: state.currentWeight,
                durationSec: state.currentDurationSec,
                difficultyTag: state.difficultyTag,
                previous: state.lastWorkout,
                goalHint: decision.suggestedGoal,
                sets: rows
            )
        }
    }

    /// Apply logged sets and return updated plan + per-exercise messages.
    static func apply(
        logged: [LoggedExercise],
        sessionID: String,
        into plan: inout WorkoutPlanState
    ) -> [String: String] {
        ensureStates(in: &plan)
        var notes: [String: String] = [:]
        for entry in logged {
            guard let template = WorkoutProgram.sessions
                .flatMap(\.exercises)
                .first(where: { $0.id == entry.exerciseID })
            else { continue }
            var state = plan.exerciseStates[entry.exerciseID] ?? seed(for: template)
            let completed = entry.sets.filter(\.completed)
            guard !completed.isEmpty else { continue }

            let input = WorkoutPrescription.workingSetInput(from: completed)
            let workingCompleted = completed.filter { !$0.isWarmup }
            guard !workingCompleted.isEmpty else { continue }

            let reps = input.reps
            let weight = input.weightUsed > 0 ? input.weightUsed : state.currentWeight
            let rirs = input.rirs.compactMap { $0 }
            let priorAvg = state.lastWorkout.map { average($0.reps) }
            let avg = average(reps)
            if let priorAvg, avg + 0.5 < priorAvg {
                state.decliningStreak += 1
            } else {
                state.decliningStreak = 0
            }

            state.lastWorkout = ExerciseLastWorkout(
                weight: weight,
                reps: reps,
                rir: rirs.isEmpty ? nil : rirs,
                note: nil
            )

            let decision = decide(
                state: state,
                template: template,
                input: input
            )
            state.currentWeight = decision.nextWeight
            state.currentDurationSec = decision.nextDurationSec ?? state.currentDurationSec
            state.difficultyTag = decision.difficultyTag
            if state.decliningStreak >= 3 {
                let deload = max(0, (state.currentWeight * 0.875).rounded(to: 2.5))
                state.currentWeight = deload
                state.decliningStreak = 0
                notes[entry.exerciseID] = "Deload recommended — try \(formatWeight(deload)) next time."
            } else {
                notes[entry.exerciseID] = decision.message
            }
            plan.exerciseStates[entry.exerciseID] = state
        }

        if let idx = WorkoutProgram.rotation.firstIndex(of: sessionID) {
            plan.nextRotationIndex = (idx + 1) % WorkoutProgram.rotation.count
        }
        plan.lastCompletedSessionID = sessionID
        plan.lastCompletedAt = .now
        return notes
    }

    /// Advance rotation past a session without logging sets (no weight progression).
    static func skip(sessionID: String, into plan: inout WorkoutPlanState) {
        ensureStates(in: &plan)
        if let idx = WorkoutProgram.rotation.firstIndex(of: sessionID) {
            plan.nextRotationIndex = (idx + 1) % WorkoutProgram.rotation.count
        } else {
            plan.nextRotationIndex = (plan.nextRotationIndex + 1) % WorkoutProgram.rotation.count
        }
        plan.lastCompletedSessionID = sessionID
        plan.lastCompletedAt = .now
    }

    static func previewDecision(
        state: ExerciseProgressionState,
        template: WorkoutExerciseTemplate
    ) -> Decision {
        let suggestedGoal = WorkoutPrescription.goalHint(state: state, template: template)
        guard let last = state.lastWorkout else {
            return Decision(
                nextWeight: state.currentWeight,
                nextDurationSec: state.currentDurationSec,
                difficultyTag: state.difficultyTag,
                message: "First time — establish a baseline.",
                suggestedGoal: suggestedGoal
            )
        }

        let previewInput = WorkoutPrescription.ProgressionInput(
            reps: last.reps,
            rirs: last.rir?.map { Optional($0) } ?? [],
            weightUsed: last.weight,
            durations: []
        )
        if WorkoutPrescription.shouldIncreaseWeight(
            input: previewInput,
            template: template,
            currentWeight: state.currentWeight
        ) {
            return Decision(
                nextWeight: state.currentWeight,
                nextDurationSec: state.currentDurationSec,
                difficultyTag: state.difficultyTag,
                message: "Ready to add load next session.",
                suggestedGoal: "Hit \(template.repMax) reps at low RIR to progress weight."
            )
        }
        return Decision(
            nextWeight: state.currentWeight,
            nextDurationSec: state.currentDurationSec,
            difficultyTag: state.difficultyTag,
            message: "Keep building reps in range.",
            suggestedGoal: suggestedGoal
        )
    }

    private static func decide(
        state: ExerciseProgressionState,
        template: WorkoutExerciseTemplate,
        input: WorkoutPrescription.ProgressionInput
    ) -> Decision {
        let reps = input.reps
        let weightUsed = input.weightUsed > 0 ? input.weightUsed : state.currentWeight
        let durations = input.durations

        switch template.progressionType {
        case .time:
            let best = durations.max() ?? (state.currentDurationSec ?? template.durationMinSec ?? 30)
            let maxSec = template.durationMaxSec ?? 60
            if best >= maxSec {
                return Decision(
                    nextWeight: 0,
                    nextDurationSec: maxSec,
                    difficultyTag: "harder-variation",
                    message: "Max hold hit — try a harder variation next time.",
                    suggestedGoal: "\(maxSec)s or harder variation"
                )
            }
            let next = min(maxSec, best + 10)
            return Decision(
                nextWeight: 0,
                nextDurationSec: next,
                difficultyTag: nil,
                message: "Next time: \(next)s holds.",
                suggestedGoal: "\(next)s"
            )

        case .repOnly:
            if WorkoutPrescription.shouldIncreaseWeight(
                input: input,
                template: template,
                currentWeight: state.currentWeight
            ) {
                if weightUsed + template.weightIncrement <= WorkoutProgram.maxDumbbellLbs, template.weightIncrement > 0 {
                    let next = WorkoutPrescription.nextWeightAfterIncrease(
                        weightUsed: weightUsed,
                        template: template
                    )
                    return Decision(
                        nextWeight: next,
                        nextDurationSec: nil,
                        difficultyTag: nil,
                        message: "Next time: \(formatWeight(next)).",
                        suggestedGoal: formatWeight(next)
                    )
                }
                let tag = nextDifficulty(after: state.difficultyTag)
                return Decision(
                    nextWeight: weightUsed,
                    nextDurationSec: nil,
                    difficultyTag: tag,
                    message: "Next time: \(formatWeight(weightUsed)) with \(tagLabel(tag)).",
                    suggestedGoal: "\(formatWeight(weightUsed)) · \(tagLabel(tag))"
                )
            }
            return Decision(
                nextWeight: weightUsed,
                nextDurationSec: nil,
                difficultyTag: state.difficultyTag,
                message: "Keep \(formatWeight(weightUsed)) — push reps toward \(template.repMax).",
                suggestedGoal: "Add reps before increasing load."
            )

        case .weightRep:
            if WorkoutPrescription.shouldDecreaseWeight(input: input, template: template) {
                let next = WorkoutPrescription.nextWeightAfterDecrease(
                    weightUsed: weightUsed,
                    template: template
                )
                return Decision(
                    nextWeight: next,
                    nextDurationSec: nil,
                    difficultyTag: nil,
                    message: "Next time: \(formatWeight(next)) — missed rep floor or failed top set.",
                    suggestedGoal: formatWeight(next)
                )
            }
            if WorkoutPrescription.shouldIncreaseWeight(
                input: input,
                template: template,
                currentWeight: state.currentWeight
            ) {
                let candidate = WorkoutPrescription.nextWeightAfterIncrease(
                    weightUsed: weightUsed,
                    template: template
                )
                if candidate > WorkoutProgram.maxDumbbellLbs {
                    let tag = nextDifficulty(after: state.difficultyTag)
                    let bumpMax = template.repMax + 3
                    return Decision(
                        nextWeight: WorkoutProgram.maxDumbbellLbs,
                        nextDurationSec: nil,
                        difficultyTag: tag,
                        message: "At max dumbbells — next: \(Int(WorkoutProgram.maxDumbbellLbs)) lb × \(template.repMax)–\(bumpMax) or \(tagLabel(tag)).",
                        suggestedGoal: "\(Int(WorkoutProgram.maxDumbbellLbs)) lb · harder"
                    )
                }
                return Decision(
                    nextWeight: candidate,
                    nextDurationSec: nil,
                    difficultyTag: nil,
                    message: "Next time: \(formatWeight(candidate)) — double progression complete.",
                    suggestedGoal: formatWeight(candidate)
                )
            }
            return Decision(
                nextWeight: weightUsed,
                nextDurationSec: nil,
                difficultyTag: state.difficultyTag,
                message: "Keep \(formatWeight(weightUsed)) — add reps within \(template.repMin)–\(template.repMax).",
                suggestedGoal: "Top set ~\(WorkoutPrescription.prescribedRIR(workingIndex: 0, template: template) ?? 0) RIR."
            )
        }
    }

    private static func nextDifficulty(after tag: String?) -> String {
        switch tag {
        case nil, "": return "3sec-eccentric"
        case "3sec-eccentric": return "pause"
        case "pause": return "single-leg"
        default: return "pause"
        }
    }

    private static func tagLabel(_ tag: String?) -> String {
        switch tag {
        case "3sec-eccentric": return "3-sec eccentric"
        case "pause": return "pause reps"
        case "single-leg": return "single-leg variation"
        case "harder-variation": return "harder variation"
        default: return "tempo focus"
        }
    }

    static func formatWeight(_ w: Double) -> String {
        if abs(w - w.rounded()) < 0.05 { return "\(Int(w.rounded())) lb" }
        return String(format: "%.1f lb", w)
    }

    private static func average(_ reps: [Int]) -> Double {
        guard !reps.isEmpty else { return 0 }
        return Double(reps.reduce(0, +)) / Double(reps.count)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Double {
    func rounded(to step: Double) -> Double {
        (self / step).rounded() * step
    }
}

// MARK: - Day / missed-day scheduler

enum WorkoutScheduler {
    struct DayStatus: Hashable {
        enum Kind: Hashable {
            case rest
            case workout(WorkoutSessionTemplate)
        }
        var kind: Kind
        var isCatchUp: Bool
        var headline: String
        var detail: String
    }

    static func status(for date: Date = .now, plan: WorkoutPlanState) -> DayStatus {
        let weekday = Calendar.current.component(.weekday, from: date)
        let scheduled = WorkoutProgram.scheduledSession(for: weekday)
        let nextID = WorkoutProgram.rotation[plan.nextRotationIndex % WorkoutProgram.rotation.count]
        let nextSession = WorkoutProgram.session(id: nextID) ?? WorkoutProgram.sessions[0]

        if let scheduled {
            if scheduled.id == nextID {
                return DayStatus(
                    kind: .workout(scheduled),
                    isCatchUp: false,
                    headline: scheduled.name,
                    detail: "\(weekdayName(weekday)) · \(scheduled.focus)"
                )
            }
            // Training day, but rotation is behind (missed earlier day).
            return DayStatus(
                kind: .workout(nextSession),
                isCatchUp: true,
                headline: nextSession.name,
                detail: "Catch-up · \(scheduled.name) waits until this is done"
            )
        }

        // Rest calendar day — still offer catch-up if a session is overdue.
        if isOverdue(plan: plan, today: date) {
            return DayStatus(
                kind: .workout(nextSession),
                isCatchUp: true,
                headline: nextSession.name,
                detail: "Rest day on the calendar — finish your missed \(nextSession.name) when ready"
            )
        }

        return DayStatus(
            kind: .rest,
            isCatchUp: false,
            headline: "Rest day",
            detail: "Recover. Next up: \(nextSession.name) (\(weekdayName(nextSession.weekday)))"
        )
    }

    /// True if the next rotation session's scheduled weekday has already passed this week without a log.
    private static func isOverdue(plan: WorkoutPlanState, today: Date) -> Bool {
        let nextID = WorkoutProgram.rotation[plan.nextRotationIndex % WorkoutProgram.rotation.count]
        guard let next = WorkoutProgram.session(id: nextID) else { return false }
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: today)
        // If last completed was this session recently (today), not overdue.
        if let last = plan.lastCompletedAt, cal.isDate(last, inSameDayAs: today),
           plan.lastCompletedSessionID == nextID {
            return false
        }
        // Overdue if scheduled weekday is earlier in the week than today.
        return weekdayOrder(next.weekday) < weekdayOrder(todayWeekday)
    }

    private static func weekdayOrder(_ weekday: Int) -> Int {
        // Map Sun=1…Sat=7 → Mon-first 0…6 for comparison within week.
        (weekday + 5) % 7
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let idx = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[idx]
    }
}
