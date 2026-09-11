import Foundation
import SwiftData

@MainActor
enum HealthStore {
    /// Bevel-inspired scoring — see `BevelScoring` and docs/APPLE_HEALTH_SETUP.md.
    static func score(
        from raw: HealthKitClient.RawDayMetrics,
        recent: (strain: Double, recovery: Double) = (45, 60)
    ) -> BevelScoring.Result {
        let input = BevelScoring.Input(
            sleepHours: raw.sleepHours,
            timeInBedHours: max(raw.timeInBedHours, raw.sleepHours),
            deepHours: raw.deepHours,
            remHours: raw.remHours,
            awakeInterruptions: raw.awakeInterruptions,
            overnightRHR: raw.overnightRHR > 0 ? raw.overnightRHR : raw.appleRestingHR,
            daytimeAvgHR: raw.daytimeAvgHR,
            hrvMs: raw.hrvMs,
            respiratoryRate: raw.respiratoryRate,
            spo2Percent: raw.spo2Percent,
            wristTempDeltaC: raw.wristTempDeltaC,
            activeEnergyKcal: raw.activeEnergyKcal,
            steps: raw.steps,
            exerciseMinutes: raw.exerciseMinutes,
            workoutActiveEnergyKcal: raw.workoutActiveEnergyKcal,
            zoneMinutes: raw.zoneMinutes,
            sleepGoalHours: HealthPreferences.sleepGoalHours,
            baselineHRV: HealthBaselines.hrv,
            baselineRHR: HealthBaselines.rhr,
            baselineRR: HealthBaselines.respiratoryRate,
            recentAvgStrain: recent.strain,
            recentAvgRecovery: recent.recovery
        )
        return BevelScoring.score(input)
    }

    static func demoRaw(for day: Date = Date()) -> HealthKitClient.RawDayMetrics {
        let seed = Calendar.current.component(.day, from: day)
        var samples: [(hour: Double, bpm: Double)] = []
        for i in 0..<48 {
            let hour = Double(i) * 0.5
            let base: Double = hour < 7 ? 54 : (hour < 12 ? 72 : (hour < 18 ? 88 : 68))
            let wobble = sin(Double(seed + i) * 0.7) * 8
            samples.append((hour, base + wobble))
        }
        let sleep = 6.4 + Double(seed % 5) * 0.35
        return HealthKitClient.RawDayMetrics(
            sleepHours: sleep,
            timeInBedHours: sleep + 0.7,
            deepHours: sleep * 0.17,
            remHours: sleep * 0.21,
            coreHours: sleep * 0.55,
            awakeInterruptions: seed % 4,
            overnightRHR: 52 + Double(seed % 6),
            appleRestingHR: 56 + Double(seed % 7),
            daytimeAvgHR: 74 + Double(seed % 8),
            hrvMs: 42 + Double(seed % 20),
            respiratoryRate: 13.5 + Double(seed % 3) * 0.4,
            spo2Percent: 96 + Double(seed % 3),
            wristTempDeltaC: Double((seed % 5) - 2) * 0.15,
            activeEnergyKcal: 280 + Double(seed % 9) * 55,
            steps: 4200 + Double(seed % 11) * 680,
            exerciseMinutes: Double(20 + seed % 40),
            workoutActiveEnergyKcal: Double(120 + seed % 8 * 30),
            workoutCount: seed % 3 == 0 ? 0 : 1,
            zoneMinutes: [12, 18, 10, 4, Double(seed % 5)],
            heartSamples: samples
        )
    }

    static func upsertSnapshot(
        day: Date,
        raw: HealthKitClient.RawDayMetrics,
        source: HealthDataSource,
        in context: ModelContext
    ) throws -> HealthDaySnapshotEntity {
        let start = Calendar.current.startOfDay(for: day)
        let all = try context.fetch(FetchDescriptor<HealthDaySnapshotEntity>(
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        ))
        let existing = all.first { Calendar.current.isDate($0.dayStart, inSameDayAs: start) }
        let recentRows = all.filter { !Calendar.current.isDate($0.dayStart, inSameDayAs: start) }.prefix(7)
        let recentStrain = recentRows.map(\.strainScore).averageOr(45)
        let recentRecovery = recentRows.map(\.recoveryScore).averageOr(60)

        let row = existing ?? {
            let created = HealthDaySnapshotEntity(dayStart: start)
            context.insert(created)
            return created
        }()

        let scored = score(from: raw, recent: (recentStrain, recentRecovery))
        row.strainScore = scored.scores.strain
        row.recoveryScore = scored.scores.recovery
        row.sleepScore = scored.scores.sleep
        row.targetStrain = scored.targetStrain
        row.sleepHours = raw.sleepHours
        row.timeInBedHours = raw.timeInBedHours
        row.deepSleepHours = raw.deepHours
        row.remSleepHours = raw.remHours
        row.restingHR = raw.overnightRHR > 0 ? raw.overnightRHR : raw.appleRestingHR
        row.hrvMs = raw.hrvMs
        row.respiratoryRate = raw.respiratoryRate
        row.spo2Percent = raw.spo2Percent
        row.activeEnergyKcal = raw.activeEnergyKcal
        row.steps = raw.steps
        row.exerciseMinutes = raw.exerciseMinutes
        row.workoutCount = raw.workoutCount
        row.stressHigh = scored.stressHigh
        row.stressLow = scored.stressLow
        row.stressAvg = scored.stressAvg
        row.energyPercent = scored.energy
        row.insightTitle = scored.insightTitle
        row.insightBody = scored.insightBody
        row.source = source
        row.updatedAt = Date()
        row.heartRateSeriesJSON = encodeSeries(raw.heartSamples)
        try context.save()

        if source == .healthKit {
            HealthBaselines.record(
                hrv: raw.hrvMs,
                rhr: row.restingHR,
                rr: raw.respiratoryRate,
                day: start
            )
        }
        HealthPreferences.lastSyncAt = Date()
        return row
    }

    static func ensureDemoSnapshot(in context: ModelContext, day: Date = Date()) {
        let start = Calendar.current.startOfDay(for: day)
        let has = (try? context.fetch(FetchDescriptor<HealthDaySnapshotEntity>()))?
            .contains { Calendar.current.isDate($0.dayStart, inSameDayAs: start) } == true
        guard !has else { return }
        try? upsertSnapshot(day: day, raw: demoRaw(for: day), source: .demo, in: context)
    }

    static func vitals(from snapshot: HealthDaySnapshotEntity) -> [HealthVital] {
        [
            HealthVital(
                id: "resp",
                title: "Resp",
                systemImage: "lungs.fill",
                value: snapshot.respiratoryRate > 0 ? snapshot.respiratoryRate : nil,
                unit: "rpm",
                normalized: clamp((snapshot.respiratoryRate - 10) / 10)
            ),
            HealthVital(
                id: "rhr",
                title: "RHR",
                systemImage: "heart.fill",
                value: snapshot.restingHR > 0 ? snapshot.restingHR : nil,
                unit: "bpm",
                normalized: clamp(1 - (snapshot.restingHR - 45) / 50)
            ),
            HealthVital(
                id: "hrv",
                title: "HRV",
                systemImage: "waveform.path.ecg",
                value: snapshot.hrvMs > 0 ? snapshot.hrvMs : nil,
                unit: "ms",
                normalized: clamp((snapshot.hrvMs - 20) / 80)
            ),
            HealthVital(
                id: "spo2",
                title: "SpO₂",
                systemImage: "drop.fill",
                value: snapshot.spo2Percent > 0 ? snapshot.spo2Percent : nil,
                unit: "%",
                normalized: clamp((snapshot.spo2Percent - 90) / 10)
            ),
            HealthVital(
                id: "steps",
                title: "Steps",
                systemImage: "figure.walk",
                value: snapshot.steps > 0 ? snapshot.steps : nil,
                unit: "",
                normalized: clamp(snapshot.steps / 10_000)
            ),
            HealthVital(
                id: "kcal",
                title: "Active",
                systemImage: "flame.fill",
                value: snapshot.activeEnergyKcal > 0 ? snapshot.activeEnergyKcal : nil,
                unit: "kcal",
                normalized: clamp(snapshot.activeEnergyKcal / 700)
            ),
        ]
    }

    static func heartSeries(from snapshot: HealthDaySnapshotEntity) -> [HealthHeartSample] {
        guard let data = snapshot.heartRateSeriesJSON.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else {
            return []
        }
        return arr.compactMap { dict in
            guard let t = dict["t"], let v = dict["v"] else { return nil }
            return HealthHeartSample(hour: t, bpm: v)
        }
    }

    private static func encodeSeries(_ samples: [(hour: Double, bpm: Double)]) -> String {
        let payload = samples.map { ["t": $0.hour, "v": $0.bpm] }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

private extension Sequence where Element == Double {
    func averageOr(_ fallback: Double) -> Double {
        var total = 0.0
        var count = 0
        for value in self {
            total += value
            count += 1
        }
        guard count > 0 else { return fallback }
        return total / Double(count)
    }
}
