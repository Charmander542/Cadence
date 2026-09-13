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
            coreHours: raw.coreHours,
            awakeInterruptions: raw.awakeInterruptions,
            sleepLatencyMinutes: raw.sleepLatencyMinutes,
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
            recentAvgRecovery: recent.recovery,
            sleepBankHours: HealthBaselines.sleepBankHours(goal: HealthPreferences.sleepGoalHours)
        )
        return BevelScoring.score(input)
    }

    /// Rebuild approximate raw metrics from a persisted snapshot (for detail explainers).
    static func rawApproximate(from snapshot: HealthDaySnapshotEntity) -> HealthKitClient.RawDayMetrics {
        let series = heartSeries(from: snapshot).map { ($0.hour, $0.bpm) }
        let zones = decodeZoneMinutes(snapshot.zoneMinutesJSON)
        return HealthKitClient.RawDayMetrics(
            sleepHours: snapshot.sleepHours,
            timeInBedHours: max(snapshot.timeInBedHours, snapshot.sleepHours),
            deepHours: snapshot.deepSleepHours,
            remHours: snapshot.remSleepHours,
            coreHours: snapshot.coreSleepHours > 0
                ? snapshot.coreSleepHours
                : max(0, snapshot.sleepHours - snapshot.deepSleepHours - snapshot.remSleepHours),
            awakeInterruptions: snapshot.awakeInterruptions,
            sleepLatencyMinutes: snapshot.sleepLatencyMinutes >= 0 ? snapshot.sleepLatencyMinutes : nil,
            overnightRHR: snapshot.restingHR,
            appleRestingHR: snapshot.restingHR,
            daytimeAvgHR: series.map(\.1).averageOr(snapshot.restingHR + 18),
            hrvMs: snapshot.hrvMs,
            respiratoryRate: snapshot.respiratoryRate,
            spo2Percent: snapshot.spo2Percent,
            wristTempDeltaC: snapshot.hasWristTemp ? snapshot.wristTempDeltaC : nil,
            activeEnergyKcal: snapshot.activeEnergyKcal,
            steps: snapshot.steps,
            exerciseMinutes: snapshot.exerciseMinutes,
            workoutActiveEnergyKcal: snapshot.workoutActiveEnergyKcal > 0
                ? snapshot.workoutActiveEnergyKcal
                : snapshot.activeEnergyKcal * 0.45,
            workoutCount: snapshot.workoutCount,
            zoneMinutes: zones,
            heartSamples: series,
            sleepStages: decodeSleepStages(snapshot.sleepStagesJSON)
        )
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
        let nightStart = Calendar.current.date(bySettingHour: 23, minute: 10, second: 0, of: day.addingTimeInterval(-86400))
            ?? day.addingTimeInterval(-2 * 3600)
        var cursor = nightStart.timeIntervalSince1970
        let pattern: [(Int, Double)] = [
            (2, sleep * 0.18), (3, sleep * 0.12), (2, sleep * 0.2), (1, sleep * 0.1),
            (0, 0.08), (2, sleep * 0.15), (3, sleep * 0.08), (1, sleep * 0.12), (2, sleep * 0.12),
        ]
        var stages: [HealthKitClient.SleepStageSegment] = []
        for (stage, hours) in pattern {
            let end = cursor + hours * 3600
            stages.append(.init(stage: stage, startEpoch: cursor, endEpoch: end))
            cursor = end
        }
        return HealthKitClient.RawDayMetrics(
            sleepHours: sleep,
            timeInBedHours: sleep + 0.7,
            deepHours: sleep * 0.17,
            remHours: sleep * 0.21,
            coreHours: sleep * 0.55,
            awakeInterruptions: seed % 4,
            sleepLatencyMinutes: Double(8 + seed % 25),
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
            heartSamples: samples,
            sleepStages: stages
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
        row.coreSleepHours = raw.coreHours
        row.awakeInterruptions = raw.awakeInterruptions
        row.sleepLatencyMinutes = raw.sleepLatencyMinutes ?? -1
        row.restingHR = raw.overnightRHR > 0 ? raw.overnightRHR : raw.appleRestingHR
        row.hrvMs = raw.hrvMs
        row.respiratoryRate = raw.respiratoryRate
        row.spo2Percent = raw.spo2Percent
        if let temp = raw.wristTempDeltaC {
            row.wristTempDeltaC = temp
            row.hasWristTemp = true
        } else {
            row.hasWristTemp = false
        }
        row.activeEnergyKcal = raw.activeEnergyKcal
        row.steps = raw.steps
        row.exerciseMinutes = raw.exerciseMinutes
        row.workoutCount = raw.workoutCount
        row.workoutActiveEnergyKcal = raw.workoutActiveEnergyKcal
        row.zoneMinutesJSON = encodeZoneMinutes(raw.zoneMinutes)
        row.scoreConfidence = scored.confidence
        row.stressHigh = scored.stressHigh
        row.stressLow = scored.stressLow
        row.stressAvg = scored.stressAvg
        row.energyPercent = scored.energy
        row.insightTitle = scored.insightTitle
        row.insightBody = scored.insightBody
        row.source = source
        row.updatedAt = Date()
        row.heartRateSeriesJSON = encodeSeries(raw.heartSamples)
        row.sleepStagesJSON = encodeSleepStages(raw.sleepStages)
        try context.save()

        if source == .healthKit || source == .demo {
            HealthBaselines.record(
                hrv: raw.hrvMs,
                rhr: row.restingHR,
                rr: raw.respiratoryRate,
                sleepHours: raw.sleepHours,
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
        let sleepHours = snapshot.sleepHours
        let goal = HealthPreferences.sleepGoalHours
        func status(for value: Double?, low: Double, high: Double, invertLowerIsBetter: Bool = false) -> HealthVital.Status {
            guard let value, value > 0 else { return .noData }
            if invertLowerIsBetter {
                if value < low { return .lower }
                if value > high { return .higher }
                return .normal
            }
            if value < low { return .lower }
            if value > high { return .higher }
            return .normal
        }

        let rhrDisplay: HealthVital.Status = {
            guard snapshot.restingHR > 0 else { return .noData }
            if snapshot.restingHR < 55 { return .lower }
            if snapshot.restingHR > 75 { return .higher }
            return .normal
        }()

        return [
            HealthVital(
                id: "resp",
                title: "RR",
                systemImage: "lungs.fill",
                value: snapshot.respiratoryRate > 0 ? snapshot.respiratoryRate : nil,
                unit: "rpm",
                normalized: clamp((snapshot.respiratoryRate - 10) / 12),
                status: status(for: snapshot.respiratoryRate, low: 12, high: 20),
                bandLow: 0.25,
                bandHigh: 0.7
            ),
            HealthVital(
                id: "rhr",
                title: "RHR",
                systemImage: "heart.fill",
                value: snapshot.restingHR > 0 ? snapshot.restingHR : nil,
                unit: "bpm",
                normalized: clamp((snapshot.restingHR - 40) / 50),
                status: rhrDisplay,
                bandLow: 0.2,
                bandHigh: 0.55
            ),
            HealthVital(
                id: "hrv",
                title: "HRV",
                systemImage: "waveform.path.ecg",
                value: snapshot.hrvMs > 0 ? snapshot.hrvMs : nil,
                unit: "ms",
                normalized: clamp((snapshot.hrvMs - 20) / 80),
                status: status(for: snapshot.hrvMs, low: 30, high: 120),
                bandLow: 0.3,
                bandHigh: 0.75
            ),
            HealthVital(
                id: "spo2",
                title: "SpO₂",
                systemImage: "drop.fill",
                value: snapshot.spo2Percent > 0 ? snapshot.spo2Percent : nil,
                unit: "%",
                normalized: clamp((snapshot.spo2Percent - 90) / 10),
                status: status(for: snapshot.spo2Percent, low: 95, high: 100),
                bandLow: 0.55,
                bandHigh: 0.95
            ),
            HealthVital(
                id: "temp",
                title: "Temp",
                systemImage: "thermometer.medium",
                value: snapshot.hasWristTemp ? snapshot.wristTempDeltaC : nil,
                unit: "°C Δ",
                normalized: snapshot.hasWristTemp ? clamp(0.5 + snapshot.wristTempDeltaC / 2) : 0.5,
                status: snapshot.hasWristTemp
                    ? (abs(snapshot.wristTempDeltaC) < 0.6 ? .normal : (snapshot.wristTempDeltaC > 0 ? .higher : .lower))
                    : .noData,
                bandLow: 0.35,
                bandHigh: 0.65
            ),
            HealthVital(
                id: "sleep",
                title: "Sleep",
                systemImage: "moon.fill",
                value: sleepHours > 0 ? sleepHours : nil,
                unit: "h",
                normalized: clamp(sleepHours / max(goal, 1)),
                status: sleepHours <= 0 ? .noData : (abs(sleepHours - goal) < 1.0 ? .normal : (sleepHours < goal ? .lower : .higher)),
                bandLow: 0.45,
                bandHigh: 0.8
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

    static func sleepStages(from snapshot: HealthDaySnapshotEntity) -> [HealthKitClient.SleepStageSegment] {
        decodeSleepStages(snapshot.sleepStagesJSON)
    }

    private static func encodeSeries(_ samples: [(hour: Double, bpm: Double)]) -> String {
        let payload = samples.map { ["t": $0.hour, "v": $0.bpm] }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func encodeSleepStages(_ stages: [HealthKitClient.SleepStageSegment]) -> String {
        let payload = stages.map { ["s": Double($0.stage), "a": $0.startEpoch, "b": $0.endEpoch] }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func decodeSleepStages(_ json: String) -> [HealthKitClient.SleepStageSegment] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Double]] else {
            return []
        }
        return arr.compactMap { dict in
            guard let s = dict["s"], let a = dict["a"], let b = dict["b"] else { return nil }
            return HealthKitClient.SleepStageSegment(stage: Int(s), startEpoch: a, endEpoch: b)
        }
    }

    private static func encodeZoneMinutes(_ zones: [Double]) -> String {
        let padded = (0..<5).map { i in i < zones.count ? zones[i] : 0 }
        guard let data = try? JSONSerialization.data(withJSONObject: padded),
              let str = String(data: data, encoding: .utf8) else { return "[0,0,0,0,0]" }
        return str
    }

    private static func decodeZoneMinutes(_ json: String) -> [Double] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Double],
              !arr.isEmpty else {
            return [0, 0, 0, 0, 0]
        }
        var zones = arr
        while zones.count < 5 { zones.append(0) }
        return Array(zones.prefix(5))
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
