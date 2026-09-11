import Foundation

/// Bevel-inspired daily scores (public methodology from Bevel Help / blog).
/// Not a byte-for-byte clone — Cadence mirrors the published components:
/// Sleep (duration, stages, efficiency, continuity, HR dip),
/// Recovery (HRV/RHR/RR/SpO₂ vs personal baselines),
/// Strain (active workout load + passive movement, logarithmic).
enum BevelScoring {
    struct Input: Sendable {
        var sleepHours: Double
        var timeInBedHours: Double
        var deepHours: Double
        var remHours: Double
        var awakeInterruptions: Int
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
    }

    struct Result: Sendable {
        var scores: HealthScoreSet
        var targetStrain: Double
        var stressHigh: Double
        var stressLow: Double
        var stressAvg: Double
        var energy: Double
        var insightTitle: String
        var insightBody: String
        var sleepBreakdown: SleepBreakdown
        var strainBreakdown: StrainBreakdown
    }

    struct SleepBreakdown: Sendable {
        var durationScore: Double
        var stageScore: Double
        var efficiencyScore: Double
        var continuityScore: Double
        var hrDipScore: Double
    }

    struct StrainBreakdown: Sendable {
        var active: Double
        var passive: Double
        var combinedLoad: Double
    }

    static func score(_ input: Input) -> Result {
        let sleep = sleepScore(input)
        let recovery = recoveryScore(input, sleepScore: sleep.score)
        let strainParts = strainScore(input)
        let target = targetStrain(
            recentAvgStrain: input.recentAvgStrain,
            recovery: recovery,
            recentAvgRecovery: input.recentAvgRecovery
        )
        let stress = stressScores(recovery: recovery, strain: strainParts.display, hrv: input.hrvMs, baselineHRV: input.baselineHRV)
        let energy = min(100, max(8, recovery * 0.55 + sleep.score * 0.25 + (100 - min(100, strainParts.display)) * 0.2))
        let insight = insightCopy(
            sleep: sleep.score,
            recovery: recovery,
            strain: strainParts.display,
            target: target,
            sleepHours: input.sleepHours,
            activeKcal: input.activeEnergyKcal
        )

        return Result(
            scores: HealthScoreSet(strain: strainParts.display, recovery: recovery, sleep: sleep.score),
            targetStrain: target,
            stressHigh: stress.high,
            stressLow: stress.low,
            stressAvg: stress.avg,
            energy: energy,
            insightTitle: insight.title,
            insightBody: insight.body,
            sleepBreakdown: sleep.breakdown,
            strainBreakdown: strainParts.breakdown
        )
    }

    // MARK: - Sleep (Bevel: Time Asleep, REM, Deep, HR Dip, Efficiency, Continuity)

    private static func sleepScore(_ input: Input) -> (score: Double, breakdown: SleepBreakdown) {
        let goal = max(5.5, input.sleepGoalHours)
        let durationScore = clamp01(input.sleepHours / goal) * 100

        let deepPct = input.sleepHours > 0.2 ? input.deepHours / input.sleepHours : 0
        let remPct = input.sleepHours > 0.2 ? input.remHours / input.sleepHours : 0
        // Targets ~18% deep, ~22% REM (adult norms Bevel references via stage balance).
        let deepScore = clamp01(1 - abs(deepPct - 0.18) / 0.18) * 100
        let remScore = clamp01(1 - abs(remPct - 0.22) / 0.22) * 100
        let stageScore = deepScore * 0.5 + remScore * 0.5

        let efficiency: Double = {
            guard input.timeInBedHours > 0.25 else { return input.sleepHours > 0 ? 85 : 0 }
            return clamp01(input.sleepHours / input.timeInBedHours) * 100
        }()

        let continuity = clamp01(1 - Double(input.awakeInterruptions) / 8.0) * 100

        let hrDipScore: Double = {
            guard input.daytimeAvgHR > 40, input.overnightRHR > 30 else { return 70 }
            let dip = (input.daytimeAvgHR - input.overnightRHR) / input.daytimeAvgHR
            // Healthy nocturnal dip often ~10–20%+.
            return clamp01(dip / 0.18) * 100
        }()

        let score = durationScore * 0.30
            + stageScore * 0.25
            + efficiency * 0.20
            + continuity * 0.10
            + hrDipScore * 0.15

        return (
            clamp(score),
            SleepBreakdown(
                durationScore: durationScore,
                stageScore: stageScore,
                efficiencyScore: efficiency,
                continuityScore: continuity,
                hrDipScore: hrDipScore
            )
        )
    }

    // MARK: - Recovery (Bevel: RHR, HRV, RR, SpO₂, wrist temp vs personal baseline)

    private static func recoveryScore(_ input: Input, sleepScore: Double) -> Double {
        let hrvComponent: Double = {
            guard input.hrvMs > 0, input.baselineHRV > 0 else {
                return input.hrvMs > 0 ? clamp01((input.hrvMs - 20) / 80) * 100 : 55
            }
            // Above baseline → better recovery.
            let ratio = input.hrvMs / input.baselineHRV
            return clamp01((ratio - 0.7) / 0.6) * 100
        }()

        let rhrComponent: Double = {
            let rhr = input.overnightRHR > 0 ? input.overnightRHR : 0
            guard rhr > 0, input.baselineRHR > 0 else {
                return rhr > 0 ? clamp01(1 - (rhr - 45) / 40) * 100 : 55
            }
            // Below baseline → better recovery.
            let delta = input.baselineRHR - rhr
            return clamp01((delta + 8) / 16) * 100
        }()

        let rrComponent: Double = {
            guard input.respiratoryRate > 0 else { return 60 }
            let base = input.baselineRR > 0 ? input.baselineRR : 14.5
            let delta = abs(input.respiratoryRate - base)
            return clamp01(1 - delta / 4.0) * 100
        }()

        let spo2Component: Double = {
            guard input.spo2Percent > 0 else { return 70 }
            if input.spo2Percent >= 97 { return 100 }
            if input.spo2Percent >= 95 { return 80 }
            return clamp01((input.spo2Percent - 90) / 5) * 100
        }()

        let tempComponent: Double = {
            guard let delta = input.wristTempDeltaC else { return 70 }
            // Large deviation from baseline wrist temp → lower recovery.
            return clamp01(1 - abs(delta) / 1.2) * 100
        }()

        let raw = hrvComponent * 0.32
            + rhrComponent * 0.28
            + rrComponent * 0.12
            + spo2Component * 0.08
            + tempComponent * 0.05
            + sleepScore * 0.15

        return clamp(raw)
    }

    // MARK: - Strain (Bevel: active + passive, logarithmic)

    private static func strainScore(_ input: Input) -> (display: Double, breakdown: StrainBreakdown) {
        let z = input.zoneMinutes
        let z1 = z.count > 0 ? z[0] : 0
        let z2 = z.count > 1 ? z[1] : 0
        let z3 = z.count > 2 ? z[2] : 0
        let z4 = z.count > 3 ? z[3] : 0
        let z5 = z.count > 4 ? z[4] : 0
        // Zone-weighted cardiovascular load (minutes).
        let zoneLoad = z1 * 0.5 + z2 * 1.0 + z3 * 2.2 + z4 * 3.5 + z5 * 5.0

        let workoutEnergy = max(input.workoutActiveEnergyKcal, 0)
        let exerciseMin = max(input.exerciseMinutes, 0)
        let activeLoad = zoneLoad * 1.2 + workoutEnergy / 12 + exerciseMin * 1.4

        let passiveEnergy = max(0, input.activeEnergyKcal - workoutEnergy)
        let passiveLoad = passiveEnergy / 35 + input.steps / 1800 + max(0, input.daytimeAvgHR - 75) * 0.35

        let combined = activeLoad + passiveLoad * 0.85
        // Logarithmic curve — harder to add points at the top (Bevel).
        let display = 100 * log(1 + combined) / log(1 + 220)

        return (
            max(0, display),
            StrainBreakdown(active: activeLoad, passive: passiveLoad, combinedLoad: combined)
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
        activeKcal: Double
    ) -> (title: String, body: String) {
        if recovery >= 75 && strain < target * 0.85 {
            return (
                "Green light to push",
                "Recovery \(Int(recovery.rounded()))% with sleep at \(formatHours(sleepHours)). Target strain ~\(Int(target.rounded())) — room to train."
            )
        }
        if sleep < 55 {
            return (
                "Prioritize sleep tonight",
                "Sleep score \(Int(sleep.rounded())) after \(formatHours(sleepHours)). Keep strain near \(Int(target.rounded())) or below and protect bedtime."
            )
        }
        if strain >= target * 1.15 {
            return (
                "Above target strain",
                "Strain \(Int(strain.rounded())) vs target \(Int(target.rounded())). Easy movement and carbs help tomorrow’s recovery hold."
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

    private static func formatHours(_ hours: Double) -> String {
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

    static func record(hrv: Double, rhr: Double, rr: Double, day: Date = Date()) {
        let dayKey = dayKey(day)
        append(hrvKey, dayKey: dayKey, value: hrv)
        append(rhrKey, dayKey: dayKey, value: rhr)
        append(rrKey, dayKey: dayKey, value: rr)
    }

    static var hrv: Double { average(hrvKey, fallback: 45) }
    static var rhr: Double { average(rhrKey, fallback: 58) }
    static var respiratoryRate: Double { average(rrKey, fallback: 14.5) }

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
