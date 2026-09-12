import Foundation

/// Bevel-inspired daily scores (published methodology — Help / blog).
/// Cadence mirrors components: Sleep, Recovery, Strain — with explainable contributor ratings.
/// See `docs/HEALTH_REDESIGN.md`.
enum BevelScoring {
    enum Rating: String, Sendable, CaseIterable {
        case excellent, good, fair, poor, unknown

        var title: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .unknown: return "No data"
            }
        }

        static func from(score: Double, hasData: Bool = true) -> Rating {
            guard hasData, score > 0 else { return .unknown }
            if score >= 85 { return .excellent }
            if score >= 65 { return .good }
            if score >= 45 { return .fair }
            return .poor
        }
    }

    struct Input: Sendable {
        var sleepHours: Double
        var timeInBedHours: Double
        var deepHours: Double
        var remHours: Double
        var coreHours: Double = 0
        var awakeInterruptions: Int
        var sleepLatencyMinutes: Double? = nil
        var overnightRHR: Double
        var daytimeAvgHR: Double
        var hrvMs: Double
        var respiratoryRate: Double
        var spo2Percent: Double
        var wristTempDeltaC: Double?
        var activeEnergyKcal: Double
        var steps: Double
        var exerciseMinutes: Double
        var workoutActiveEnergyKcal: Double
        var zoneMinutes: [Double] // Z1…Z5 minutes
        var sleepGoalHours: Double
        var baselineHRV: Double
        var baselineRHR: Double
        var baselineRR: Double
        var recentAvgStrain: Double
        var recentAvgRecovery: Double
        /// Rolling Σ(asleep − goal) over ~7 days (hours). Negative = debt.
        var sleepBankHours: Double = 0
    }

    struct Result: Sendable {
        var scores: HealthScoreSet
        var targetStrain: Double
        var stressHigh: Double
        var stressLow: Double
        var stressAvg: Double
        var energy: Double
        var confidence: Double
        var insightTitle: String
        var insightBody: String
        var sleepBreakdown: SleepBreakdown
        var recoveryBreakdown: RecoveryBreakdown
        var strainBreakdown: StrainBreakdown
        var sleepBankHours: Double
    }

    struct Contributor: Sendable {
        var id: String
        var title: String
        var score: Double
        var rating: Rating
        var detail: String
        var hasData: Bool
    }

    struct SleepBreakdown: Sendable {
        var durationScore: Double
        var stageScore: Double
        var efficiencyScore: Double
        var continuityScore: Double
        var hrDipScore: Double
        var latencyScore: Double
        var contributors: [Contributor]
        var narrative: String
    }

    struct RecoveryBreakdown: Sendable {
        var hrvScore: Double
        var rhrScore: Double
        var rrScore: Double
        var spo2Score: Double
        var tempScore: Double
        var sleepCarryScore: Double
        var contributors: [Contributor]
        var narrative: String
    }

    struct StrainBreakdown: Sendable {
        var active: Double
        var passive: Double
        var combinedLoad: Double
        var contributors: [Contributor]
        var narrative: String
    }

    static func score(_ input: Input) -> Result {
        let confidence = dataConfidence(input)
        let sleep = sleepScore(input)
        let recovery = recoveryScore(input, sleepScore: sleep.score)
        let strainParts = strainScore(input)
        let target = targetStrain(
            recentAvgStrain: input.recentAvgStrain,
            recovery: recovery.score,
            recentAvgRecovery: input.recentAvgRecovery
        )
        let stress = stressScores(
            recovery: recovery.score,
            strain: strainParts.display,
            hrv: input.hrvMs,
            baselineHRV: input.baselineHRV
        )
        let energy = min(100, max(8, recovery.score * 0.55 + sleep.score * 0.25 + (100 - min(100, strainParts.display)) * 0.2))
        let insight = insightCopy(
            sleep: sleep.score,
            recovery: recovery.score,
            strain: strainParts.display,
            target: target,
            sleepHours: input.sleepHours,
            activeKcal: input.activeEnergyKcal,
            sleepBank: input.sleepBankHours,
            topSleepIssue: sleep.breakdown.contributors
                .filter { $0.rating == .poor || $0.rating == .fair }
                .sorted { $0.score < $1.score }
                .first?.title
        )

        // Soften scores toward neutral when confidence is low (missing Watch overnight data).
        let blend: (Double) -> Double = { raw in
            let neutral = 58.0
            return clamp(raw * confidence + neutral * (1 - confidence))
        }

        return Result(
            scores: HealthScoreSet(
                strain: clamp(strainParts.display),
                recovery: blend(recovery.score),
                sleep: blend(sleep.score)
            ),
            targetStrain: target,
            stressHigh: stress.high,
            stressLow: stress.low,
            stressAvg: stress.avg,
            energy: clamp(energy),
            confidence: confidence,
            insightTitle: insight.title,
            insightBody: insight.body,
            sleepBreakdown: sleep.breakdown,
            recoveryBreakdown: recovery.breakdown,
            strainBreakdown: strainParts.breakdown,
            sleepBankHours: input.sleepBankHours
        )
    }

    // MARK: - Confidence

    /// 0…1 — how complete tonight’s Watch / Health inputs are.
    static func dataConfidence(_ input: Input) -> Double {
        var points = 0.0
        var total = 0.0
        func add(_ ok: Bool, w: Double) {
            total += w
            if ok { points += w }
        }
        add(input.sleepHours > 0.5, w: 2.5)
        add(input.deepHours + input.remHours > 0.1, w: 1.5)
        add(input.timeInBedHours > 0.5, w: 1.0)
        add(input.hrvMs > 0, w: 2.0)
        add(input.overnightRHR > 0 || input.daytimeAvgHR > 0, w: 1.5)
        add(input.respiratoryRate > 0, w: 0.8)
        add(input.spo2Percent > 0, w: 0.7)
        add(input.wristTempDeltaC != nil, w: 0.5)
        add(input.activeEnergyKcal > 0 || input.steps > 0, w: 1.0)
        add(input.zoneMinutes.contains(where: { $0 > 0 }) || input.workoutActiveEnergyKcal > 0, w: 0.8)
        guard total > 0 else { return 0.35 }
        return clamp01(points / total)
    }

    // MARK: - Sleep

    private static func sleepScore(_ input: Input) -> (score: Double, breakdown: SleepBreakdown) {
        let goal = max(5.5, input.sleepGoalHours)
        let hasSleep = input.sleepHours > 0.25

        let durationScore: Double = {
            guard hasSleep else { return 0 }
            let ratio = input.sleepHours / goal
            // Soft reward up to ~1.1× goal, then flat.
            if ratio <= 1 { return clamp01(ratio) * 100 }
            return clamp01(1 - (ratio - 1.1) / 0.5) * 100
        }()

        let deepPct = input.sleepHours > 0.2 ? input.deepHours / input.sleepHours : 0
        let remPct = input.sleepHours > 0.2 ? input.remHours / input.sleepHours : 0
        let hasStages = input.deepHours + input.remHours > 0.05
        let deepScore = hasStages ? clamp01(1 - abs(deepPct - 0.17) / 0.17) * 100 : 0
        let remScore = hasStages ? clamp01(1 - abs(remPct - 0.22) / 0.22) * 100 : 0
        let stageScore = hasStages ? deepScore * 0.5 + remScore * 0.5 : 0

        let hasBed = input.timeInBedHours > 0.25
        let efficiency: Double = {
            guard hasBed else { return hasSleep ? 80 : 0 }
            return clamp01(input.sleepHours / input.timeInBedHours) * 100
        }()

        let continuity = hasSleep ? clamp01(1 - Double(input.awakeInterruptions) / 8.0) * 100 : 0

        let hasHR = input.daytimeAvgHR > 40 && input.overnightRHR > 30
        let hrDipScore: Double = {
            guard hasHR else { return 0 }
            let dip = (input.daytimeAvgHR - input.overnightRHR) / input.daytimeAvgHR
            return clamp01(dip / 0.18) * 100
        }()

        let hasLatency = (input.sleepLatencyMinutes ?? -1) >= 0
        let latencyScore: Double = {
            guard let mins = input.sleepLatencyMinutes, mins >= 0 else { return 0 }
            // Ideal ~5–20 min; late (>45) or instant-but-suspicious handled softly.
            if mins <= 20 { return clamp01(1 - abs(mins - 12) / 20) * 100 }
            if mins <= 45 { return 55 }
            return clamp01(1 - (mins - 45) / 60) * 45
        }()

        var weighted = 0.0
        var weightSum = 0.0
        func accumulate(_ score: Double, w: Double, present: Bool) {
            guard present else { return }
            weighted += score * w
            weightSum += w
        }
        accumulate(durationScore, w: 0.28, present: hasSleep)
        accumulate(stageScore, w: 0.22, present: hasStages)
        accumulate(efficiency, w: 0.18, present: hasBed)
        accumulate(continuity, w: 0.12, present: hasSleep)
        accumulate(hrDipScore, w: 0.12, present: hasHR)
        accumulate(latencyScore, w: 0.08, present: hasLatency)

        let score = weightSum > 0 ? weighted / weightSum : 0

        // Bevel Primary sleep grid (2×3): Time Asleep · HR Dip · REM · Deep · Efficiency · Continuity.
        // Latency stays in the score blend but surfaces as its own “Time to fall asleep” control.
        let contributors: [Contributor] = [
            Contributor(
                id: "duration",
                title: "Time Asleep",
                score: durationScore,
                rating: Rating.from(score: durationScore, hasData: hasSleep),
                detail: hasSleep
                    ? "\(formatHours(input.sleepHours)) vs \(formatHours(goal)) goal"
                    : "Wear Apple Watch overnight to log sleep",
                hasData: hasSleep
            ),
            Contributor(
                id: "hrDip",
                title: "Heart Rate Dip",
                score: hrDipScore,
                rating: Rating.from(score: hrDipScore, hasData: hasHR),
                detail: hasHR
                    ? String(format: "Overnight %.0f vs day %.0f bpm", input.overnightRHR, input.daytimeAvgHR)
                    : "Needs daytime + overnight heart rate",
                hasData: hasHR
            ),
            Contributor(
                id: "rem",
                title: "REM Sleep",
                score: remScore,
                rating: Rating.from(score: remScore, hasData: hasStages),
                detail: hasStages
                    ? String(format: "%.0f%% of asleep (ideal ~22%%)", remPct * 100)
                    : "Stage data needs Watch sleep tracking",
                hasData: hasStages
            ),
            Contributor(
                id: "deep",
                title: "Deep Sleep",
                score: deepScore,
                rating: Rating.from(score: deepScore, hasData: hasStages),
                detail: hasStages
                    ? String(format: "%.0f%% of asleep (ideal ~17%%)", deepPct * 100)
                    : "Stage data needs Watch sleep tracking",
                hasData: hasStages
            ),
            Contributor(
                id: "efficiency",
                title: "Efficiency",
                score: efficiency,
                rating: Rating.from(score: efficiency, hasData: hasBed),
                detail: hasBed
                    ? String(format: "%.0f%% asleep while in bed", efficiency)
                    : "In-bed window unavailable",
                hasData: hasBed
            ),
            Contributor(
                id: "continuity",
                title: "Continuity",
                score: continuity,
                rating: Rating.from(score: continuity, hasData: hasSleep),
                detail: hasSleep
                    ? "\(input.awakeInterruptions) awakening\(input.awakeInterruptions == 1 ? "" : "s")"
                    : "No sleep session",
                hasData: hasSleep
            ),
        ]

        let narrative: String = {
            guard hasSleep else {
                return "No primary sleep yet. Wear your Apple Watch to bed so Cadence can score duration, stages, and recovery inputs."
            }
            if let weak = contributors.filter({ $0.hasData && ($0.rating == .poor || $0.rating == .fair) }).sorted(by: { $0.score < $1.score }).first {
                return "Sleep score \(Int(score.rounded()))%. \(weak.title) looks \(weak.rating.title.lowercased()) — \(weak.detail)."
            }
            return "Solid night: \(formatHours(input.sleepHours)) asleep with balanced contributors."
        }()

        return (
            clamp(score),
            SleepBreakdown(
                durationScore: durationScore,
                stageScore: stageScore,
                efficiencyScore: efficiency,
                continuityScore: continuity,
                hrDipScore: hrDipScore,
                latencyScore: latencyScore,
                contributors: contributors,
                narrative: narrative
            )
        )
    }

    // MARK: - Recovery

    private static func recoveryScore(_ input: Input, sleepScore: Double) -> (score: Double, breakdown: RecoveryBreakdown) {
        let hasHRV = input.hrvMs > 0
        let hrvComponent: Double = {
            guard hasHRV else { return 0 }
            if input.baselineHRV > 0 {
                let ratio = input.hrvMs / input.baselineHRV
                return clamp01((ratio - 0.7) / 0.6) * 100
            }
            return clamp01((input.hrvMs - 20) / 80) * 100
        }()

        let rhr = input.overnightRHR > 0 ? input.overnightRHR : 0
        let hasRHR = rhr > 0
        let rhrComponent: Double = {
            guard hasRHR else { return 0 }
            if input.baselineRHR > 0 {
                let delta = input.baselineRHR - rhr
                return clamp01((delta + 8) / 16) * 100
            }
            return clamp01(1 - (rhr - 45) / 40) * 100
        }()

        let hasRR = input.respiratoryRate > 0
        let rrComponent: Double = {
            guard hasRR else { return 0 }
            let base = input.baselineRR > 0 ? input.baselineRR : 14.5
            return clamp01(1 - abs(input.respiratoryRate - base) / 4.0) * 100
        }()

        let hasSpO2 = input.spo2Percent > 0
        let spo2Component: Double = {
            guard hasSpO2 else { return 0 }
            if input.spo2Percent >= 97 { return 100 }
            if input.spo2Percent >= 95 { return 80 }
            return clamp01((input.spo2Percent - 90) / 5) * 100
        }()

        let hasTemp = input.wristTempDeltaC != nil
        let tempComponent: Double = {
            guard let delta = input.wristTempDeltaC else { return 0 }
            return clamp01(1 - abs(delta) / 1.2) * 100
        }()

        let hasSleep = sleepScore > 0
        let sleepCarry = hasSleep ? sleepScore : 0

        var weighted = 0.0
        var weightSum = 0.0
        func accumulate(_ score: Double, w: Double, present: Bool) {
            guard present else { return }
            weighted += score * w
            weightSum += w
        }
        accumulate(hrvComponent, w: 0.32, present: hasHRV)
        accumulate(rhrComponent, w: 0.26, present: hasRHR)
        accumulate(rrComponent, w: 0.12, present: hasRR)
        accumulate(spo2Component, w: 0.08, present: hasSpO2)
        accumulate(tempComponent, w: 0.05, present: hasTemp)
        accumulate(sleepCarry, w: 0.17, present: hasSleep)

        let score = weightSum > 0 ? weighted / weightSum : 55

        let contributors: [Contributor] = [
            Contributor(
                id: "hrv",
                title: "HRV",
                score: hrvComponent,
                rating: Rating.from(score: hrvComponent, hasData: hasHRV),
                detail: hasHRV
                    ? String(format: "%.0f ms vs %.0f baseline", input.hrvMs, input.baselineHRV > 0 ? input.baselineHRV : input.hrvMs)
                    : "Overnight HRV from Watch unlocks this",
                hasData: hasHRV
            ),
            Contributor(
                id: "rhr",
                title: "Resting HR",
                score: rhrComponent,
                rating: Rating.from(score: rhrComponent, hasData: hasRHR),
                detail: hasRHR
                    ? String(format: "%.0f bpm overnight", rhr)
                    : "Overnight heart rate unavailable",
                hasData: hasRHR
            ),
            Contributor(
                id: "rr",
                title: "Respiratory rate",
                score: rrComponent,
                rating: Rating.from(score: rrComponent, hasData: hasRR),
                detail: hasRR
                    ? String(format: "%.1f breaths/min", input.respiratoryRate)
                    : "Respiratory rate not in Health yet",
                hasData: hasRR
            ),
            Contributor(
                id: "spo2",
                title: "Blood oxygen",
                score: spo2Component,
                rating: Rating.from(score: spo2Component, hasData: hasSpO2),
                detail: hasSpO2
                    ? String(format: "%.1f%% SpO₂", input.spo2Percent)
                    : "Enable Blood Oxygen on Apple Watch",
                hasData: hasSpO2
            ),
            Contributor(
                id: "temp",
                title: "Wrist temperature",
                score: tempComponent,
                rating: Rating.from(score: tempComponent, hasData: hasTemp),
                detail: hasTemp
                    ? String(format: "%+.2f°C vs baseline", input.wristTempDeltaC ?? 0)
                    : "Sleeping wrist temperature when available",
                hasData: hasTemp
            ),
            Contributor(
                id: "sleep",
                title: "Prior sleep",
                score: sleepCarry,
                rating: Rating.from(score: sleepCarry, hasData: hasSleep),
                detail: hasSleep
                    ? "Sleep score feeds readiness"
                    : "No sleep score to carry forward",
                hasData: hasSleep
            ),
        ]

        let narrative: String = {
            if !hasHRV && !hasRHR {
                return "Recovery is provisional until overnight HRV and resting heart rate sync from Apple Watch."
            }
            if let weak = contributors.filter({ $0.hasData && ($0.rating == .poor || $0.rating == .fair) }).sorted(by: { $0.score < $1.score }).first {
                return "Recovery \(Int(score.rounded()))%. \(weak.title) is \(weak.rating.title.lowercased()) — \(weak.detail)."
            }
            return "Body looks restored — HRV and resting heart rate sit near your personal baseline."
        }()

        return (
            clamp(score),
            RecoveryBreakdown(
                hrvScore: hrvComponent,
                rhrScore: rhrComponent,
                rrScore: rrComponent,
                spo2Score: spo2Component,
                tempScore: tempComponent,
                sleepCarryScore: sleepCarry,
                contributors: contributors,
                narrative: narrative
            )
        )
    }

    // MARK: - Strain

    private static func strainScore(_ input: Input) -> (display: Double, breakdown: StrainBreakdown) {
        let z = input.zoneMinutes
        let z1 = z.count > 0 ? z[0] : 0
        let z2 = z.count > 1 ? z[1] : 0
        let z3 = z.count > 2 ? z[2] : 0
        let z4 = z.count > 3 ? z[3] : 0
        let z5 = z.count > 4 ? z[4] : 0
        let zoneLoad = z1 * 0.5 + z2 * 1.0 + z3 * 2.2 + z4 * 3.5 + z5 * 5.0

        let workoutEnergy = max(input.workoutActiveEnergyKcal, 0)
        let exerciseMin = max(input.exerciseMinutes, 0)
        let activeLoad = zoneLoad * 1.2 + workoutEnergy / 12 + exerciseMin * 1.4

        let passiveEnergy = max(0, input.activeEnergyKcal - workoutEnergy)
        let passiveLoad = passiveEnergy / 35 + input.steps / 1800 + max(0, input.daytimeAvgHR - 75) * 0.35

        let combined = activeLoad + passiveLoad * 0.85
        let display = 100 * log(1 + combined) / log(1 + 220)

        let contributors = [
            Contributor(
                id: "active",
                title: "Active load",
                score: min(100, activeLoad / 2.2),
                rating: Rating.from(score: min(100, activeLoad / 2.2), hasData: activeLoad > 0.5),
                detail: String(format: "Zones + %.0f workout kcal + %.0f exercise min", workoutEnergy, exerciseMin),
                hasData: activeLoad > 0.5
            ),
            Contributor(
                id: "passive",
                title: "Passive load",
                score: min(100, passiveLoad / 1.8),
                rating: Rating.from(score: min(100, passiveLoad / 1.8), hasData: passiveLoad > 0.5),
                detail: String(format: "%.0f steps · %.0f non-workout kcal", input.steps, passiveEnergy),
                hasData: passiveLoad > 0.5
            ),
        ]

        let narrative = combined < 8
            ? "Light day so far — movement and workouts will raise strain on a log curve (harder to add points near the top)."
            : String(format: "Combined load %.0f → strain %.0f%%. Active %.0f · passive %.0f.", combined, display, activeLoad, passiveLoad)

        return (
            max(0, display),
            StrainBreakdown(
                active: activeLoad,
                passive: passiveLoad,
                combinedLoad: combined,
                contributors: contributors,
                narrative: narrative
            )
        )
    }

    private static func targetStrain(recentAvgStrain: Double, recovery: Double, recentAvgRecovery: Double) -> Double {
        let base = recentAvgStrain > 5 ? recentAvgStrain : 45
        let recoveryFactor = 0.65 + (recovery / 100) * 0.55
        let trend = recentAvgRecovery > 0 ? clamp01(recovery / max(recentAvgRecovery, 1)) : 1
        let target = base * recoveryFactor * (0.85 + 0.3 * trend)
        return clamp(target, lo: 25, hi: 95)
    }

    private static func stressScores(recovery: Double, strain: Double, hrv: Double, baselineHRV: Double) -> (high: Double, low: Double, avg: Double) {
        let hrvStress: Double = {
            guard hrv > 0, baselineHRV > 0 else { return 40 }
            return clamp01(1.15 - hrv / baselineHRV) * 100
        }()
        let avg = clamp(hrvStress * 0.55 + (100 - recovery) * 0.25 + min(100, strain) * 0.2)
        return (clamp(avg + 16 + min(100, strain) * 0.08), max(2, avg - 20), avg)
    }

    private static func insightCopy(
        sleep: Double,
        recovery: Double,
        strain: Double,
        target: Double,
        sleepHours: Double,
        activeKcal: Double,
        sleepBank: Double,
        topSleepIssue: String?
    ) -> (title: String, body: String) {
        if recovery >= 75 && strain < target * 0.85 {
            return (
                "Green light to push",
                "Recovery \(Int(recovery.rounded()))% with sleep at \(formatHours(sleepHours)). Target strain ~\(Int(target.rounded())) — room to train."
            )
        }
        if sleep < 55 {
            let issue = topSleepIssue.map { " \($0) held the score down." } ?? ""
            return (
                "Prioritize sleep tonight",
                "Sleep score \(Int(sleep.rounded())) after \(formatHours(sleepHours)).\(issue) Keep strain near \(Int(target.rounded())) or below."
            )
        }
        if sleepBank < -4 {
            return (
                "Sleep bank in debt",
                String(format: "You’re %.1fh short over recent nights. Ease strain toward %.0f and protect bedtime.", abs(sleepBank), max(25, target * 0.75))
            )
        }
        if strain >= target * 1.15 {
            return (
                "Above target strain",
                "Strain \(Int(strain.rounded())) vs target \(Int(target.rounded())). Easy movement helps tomorrow’s recovery hold."
            )
        }
        if recovery < 45 {
            return (
                "Take it easier",
                "Recovery \(Int(recovery.rounded()))%. Aim closer to \(Int(max(25, target * 0.7).rounded())) strain and stack sleep."
            )
        }
        return (
            "Steady cadence",
            "Strain \(Int(strain.rounded())) · Recovery \(Int(recovery.rounded())) · Sleep \(Int(sleep.rounded())). ~\(Int(activeKcal.rounded())) active kcal today."
        )
    }

    static func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    private static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
    private static func clamp(_ x: Double, lo: Double = 0, hi: Double = 100) -> Double { min(hi, max(lo, x)) }
}

/// Rolling personal baselines (Bevel uses ~60-day averages for HRV / RHR).
enum HealthBaselines {
    private static let hrvKey = "health_baseline_hrv_samples_v1"
    private static let rhrKey = "health_baseline_rhr_samples_v1"
    private static let rrKey = "health_baseline_rr_samples_v1"
    private static let sleepKey = "health_baseline_sleep_hours_v1"

    static func record(hrv: Double, rhr: Double, rr: Double, sleepHours: Double = 0, day: Date = Date()) {
        let key = dayKey(day)
        append(hrvKey, dayKey: key, value: hrv)
        append(rhrKey, dayKey: key, value: rhr)
        append(rrKey, dayKey: key, value: rr)
        if sleepHours > 0.5 {
            append(sleepKey, dayKey: key, value: sleepHours)
        }
    }

    static var hrv: Double { average(hrvKey, fallback: 45) }
    static var rhr: Double { average(rhrKey, fallback: 58) }
    static var respiratoryRate: Double { average(rrKey, fallback: 14.5) }

    /// Σ(asleep − goal) over last 7 logged days.
    static func sleepBankHours(goal: Double = 8, day: Date = Date()) -> Double {
        let map = UserDefaults.standard.dictionary(forKey: sleepKey) as? [String: Double] ?? [:]
        let cal = Calendar.current
        var total = 0.0
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: day) else { continue }
            if let asleep = map[dayKey(d)], asleep > 0 {
                total += asleep - goal
            }
        }
        return total
    }

    private static func dayKey(_ day: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func append(_ key: String, dayKey: String, value: Double) {
        guard value > 0 else { return }
        var map = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        map[dayKey] = value
        if map.count > 60 {
            let trimmed = map.sorted(by: { $0.key < $1.key }).suffix(60)
            map = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.key, $0.value) })
        }
        UserDefaults.standard.set(map, forKey: key)
    }

    private static func average(_ key: String, fallback: Double) -> Double {
        let map = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        let values = map.values.filter { $0 > 0 }
        guard !values.isEmpty else { return fallback }
        return values.reduce(0, +) / Double(values.count)
    }
}
