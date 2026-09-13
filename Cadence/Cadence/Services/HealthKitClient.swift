import Foundation
import HealthKit

/// Apple Health / Watch reader for Body (Health + Lift).
/// Scoring lives in `BevelScoring` / `HealthStore`. Setup: `docs/APPLE_HEALTH_SETUP.md`.
actor HealthKitClient {
    enum HealthKitError: LocalizedError {
        case unavailable
        case notAuthorized
        case queryFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Apple Health is not available on this device."
            case .notAuthorized: return "Allow Cadence to read health data in Settings → Health."
            case .queryFailed(let msg): return msg
            }
        }
    }

    /// Ordered overnight stage chunks for Bevel-style hypnogram (epoch seconds + stage code).
    struct SleepStageSegment: Sendable, Hashable {
        /// 0 awake · 1 REM · 2 core · 3 deep · 4 unspecified asleep
        var stage: Int
        var startEpoch: TimeInterval
        var endEpoch: TimeInterval

        var durationHours: Double { max(0, (endEpoch - startEpoch) / 3600) }
    }

    struct RawDayMetrics: Sendable {
        var sleepHours: Double = 0
        var timeInBedHours: Double = 0
        var deepHours: Double = 0
        var remHours: Double = 0
        var coreHours: Double = 0
        var awakeInterruptions: Int = 0
        /// Minutes from first in-bed to first asleep sample (nil if unknown).
        var sleepLatencyMinutes: Double? = nil
        var overnightRHR: Double = 0
        var appleRestingHR: Double = 0
        var daytimeAvgHR: Double = 0
        var hrvMs: Double = 0
        var respiratoryRate: Double = 0
        var spo2Percent: Double = 0
        var wristTempDeltaC: Double?
        var activeEnergyKcal: Double = 0
        var steps: Double = 0
        var exerciseMinutes: Double = 0
        var workoutActiveEnergyKcal: Double = 0
        var workoutCount: Int = 0
        var zoneMinutes: [Double] = [0, 0, 0, 0, 0]
        var heartSamples: [(hour: Double, bpm: Double)] = []
        var sleepStages: [SleepStageSegment] = []
    }

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let quantity: [HKQuantityTypeIdentifier] = [
            .restingHeartRate,
            .heartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate,
            .oxygenSaturation,
            .activeEnergyBurned,
            .stepCount,
            .appleExerciseTime,
        ]
        for id in quantity {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        types.insert(HKObjectType.workoutType())
        // Wrist temperature (watchOS / newer HealthKit) — optional.
        if #available(iOS 16.0, *) {
            if let temp = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                types.insert(temp)
            }
        }
        return types
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func fetchDayMetrics(for day: Date = Date()) async throws -> RawDayMetrics {
        guard isAvailable else { throw HealthKitError.unavailable }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            throw HealthKitError.queryFailed("Bad date range")
        }
        // Sleep often straddles midnight — look back from noon-centered window.
        let sleepStart = cal.date(byAdding: .hour, value: -6, to: start) ?? start
        let sleepEnd = cal.date(byAdding: .hour, value: 14, to: start) ?? end
        let dayPredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        async let sleep = sleepBreakdown(start: sleepStart, end: sleepEnd)
        async let appleRHR = averageQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: dayPredicate)
        async let hrv = averageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), predicate: dayPredicate)
        async let resp = averageQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: dayPredicate)
        async let spo2 = averageQuantity(.oxygenSaturation, unit: .percent(), predicate: dayPredicate)
        async let energy = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), predicate: dayPredicate)
        async let steps = sumQuantity(.stepCount, unit: .count(), predicate: dayPredicate)
        async let exercise = sumQuantity(.appleExerciseTime, unit: .minute(), predicate: dayPredicate)
        async let series = heartRateSeries(start: start, end: end)
        async let workouts = workoutStats(start: start, end: end)
        async let wristTemp = sleepingWristTemperatureDelta(start: sleepStart, end: sleepEnd)

        let sleepData = try await sleep
        let samples = try await series
        let overnight = overnightAverageHR(from: samples, asleepHours: sleepData.asleepIntervals, dayStart: start)
        let daytime = daytimeAverageHR(from: samples, asleepHours: sleepData.asleepIntervals, dayStart: start)
        let zones = zoneMinutes(from: samples, maxHR: estimatedMaxHR(resting: try await appleRHR))
        let workout = try await workouts
        let spo2Raw = try await spo2

        return RawDayMetrics(
            sleepHours: sleepData.asleepHours,
            timeInBedHours: sleepData.inBedHours,
            deepHours: sleepData.deepHours,
            remHours: sleepData.remHours,
            coreHours: sleepData.coreHours,
            awakeInterruptions: sleepData.awakeInterruptions,
            sleepLatencyMinutes: sleepData.latencyMinutes,
            overnightRHR: overnight > 0 ? overnight : (try await appleRHR),
            appleRestingHR: try await appleRHR,
            daytimeAvgHR: daytime,
            hrvMs: try await hrv,
            respiratoryRate: try await resp,
            spo2Percent: spo2Raw > 0 && spo2Raw <= 1.5 ? spo2Raw * 100 : spo2Raw,
            wristTempDeltaC: try await wristTemp,
            activeEnergyKcal: try await energy,
            steps: try await steps,
            exerciseMinutes: try await exercise,
            workoutActiveEnergyKcal: workout.energy,
            workoutCount: workout.count,
            zoneMinutes: zones,
            heartSamples: samples,
            sleepStages: sleepData.stages
        )
    }

    // MARK: - Sleep

    private struct SleepBreakdown {
        var asleepHours: Double
        var inBedHours: Double
        var deepHours: Double
        var remHours: Double
        var coreHours: Double
        var awakeInterruptions: Int
        var asleepIntervals: [(Date, Date)]
        var latencyMinutes: Double?
        var stages: [SleepStageSegment]
    }

    private func sleepBreakdown(start: Date, end: Date) async throws -> SleepBreakdown {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return SleepBreakdown(asleepHours: 0, inBedHours: 0, deepHours: 0, remHours: 0, coreHours: 0, awakeInterruptions: 0, asleepIntervals: [], latencyMinutes: nil, stages: [])
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [
                NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            ]) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        var asleep = 0.0
        var deep = 0.0
        var rem = 0.0
        var core = 0.0
        var inBed = 0.0
        var awakeCount = 0
        var intervals: [(Date, Date)] = []
        var stages: [SleepStageSegment] = []
        var firstInBed: Date?
        var firstAsleep: Date?

        for sample in samples {
            let dur = sample.endDate.timeIntervalSince(sample.startDate)
            if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                inBed += dur
                if firstInBed == nil { firstInBed = sample.startDate }
            }
            if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                awakeCount += 1
                stages.append(SleepStageSegment(
                    stage: 0,
                    startEpoch: sample.startDate.timeIntervalSince1970,
                    endEpoch: sample.endDate.timeIntervalSince1970
                ))
            }
            if asleepValues.contains(sample.value) {
                asleep += dur
                intervals.append((sample.startDate, sample.endDate))
                if firstAsleep == nil { firstAsleep = sample.startDate }
                let stageCode: Int
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deep += dur
                    stageCode = 3
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    rem += dur
                    stageCode = 1
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    core += dur
                    stageCode = 2
                default:
                    stageCode = 4
                }
                stages.append(SleepStageSegment(
                    stage: stageCode,
                    startEpoch: sample.startDate.timeIntervalSince1970,
                    endEpoch: sample.endDate.timeIntervalSince1970
                ))
            }
        }
        if inBed < asleep { inBed = asleep }
        stages.sort { $0.startEpoch < $1.startEpoch }

        let latency: Double? = {
            guard let bed = firstInBed, let asleepAt = firstAsleep, asleepAt >= bed else { return nil }
            let mins = asleepAt.timeIntervalSince(bed) / 60
            guard mins >= 0, mins < 240 else { return nil }
            return mins
        }()

        return SleepBreakdown(
            asleepHours: asleep / 3600,
            inBedHours: inBed / 3600,
            deepHours: deep / 3600,
            remHours: rem / 3600,
            coreHours: core / 3600,
            awakeInterruptions: awakeCount,
            asleepIntervals: intervals,
            latencyMinutes: latency,
            stages: stages
        )
    }

    // MARK: - Workouts & HR

    /// Workouts for Fitness logger (Watch + third-party written to Health).
    struct WorkoutSummary: Sendable, Identifiable {
        var id: UUID
        var name: String
        var start: Date
        var durationMinutes: Double
        var activeEnergyKcal: Double
        var averageHR: Double?
        var source: String
    }

    private func workoutStats(start: Date, end: Date) async throws -> (energy: Double, count: Int) {
        let summaries = try await fetchWorkouts(for: start)
        let inRange = summaries.filter { $0.start >= start && $0.start < end }
        let energy = inRange.reduce(0.0) { $0 + $1.activeEnergyKcal }
        return (energy, inRange.count)
    }

    func fetchWorkouts(for day: Date = Date()) async throws -> [WorkoutSummary] {
        guard isAvailable else { throw HealthKitError.unavailable }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        return samples.map { workout in
            let name = workout.workoutActivityType.cadenceDisplayName
            let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            let mins = workout.duration / 60
            let avgHR: Double? = {
                guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
                return workout.statistics(for: hrType)?
                    .averageQuantity()?
                    .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }()
            let source = workout.sourceRevision.source.name
            return WorkoutSummary(
                id: workout.uuid,
                name: name,
                start: workout.startDate,
                durationMinutes: mins,
                activeEnergyKcal: kcal,
                averageHR: avgHR,
                source: source
            )
        }
    }

    private func heartRateSeries(start: Date, end: Date) async throws -> [(hour: Double, bpm: Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 2000, sortDescriptors: [sort]) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return samples.map { sample in
            let hour = sample.startDate.timeIntervalSince(start) / 3600
            return (hour, sample.quantity.doubleValue(for: unit))
        }
    }

    private func overnightAverageHR(
        from samples: [(hour: Double, bpm: Double)],
        asleepHours: [(Date, Date)],
        dayStart: Date
    ) -> Double {
        guard !samples.isEmpty else { return 0 }
        let asleepHoursOfDay: [(Double, Double)] = asleepHours.map { start, end in
            (start.timeIntervalSince(dayStart) / 3600, end.timeIntervalSince(dayStart) / 3600)
        }
        let overnight: [Double]
        if asleepHoursOfDay.isEmpty {
            overnight = samples.filter { $0.hour >= 0 && $0.hour < 7 }.map(\.bpm)
        } else {
            overnight = samples.compactMap { sample in
                asleepHoursOfDay.contains(where: { sample.hour >= $0.0 && sample.hour <= $0.1 }) ? sample.bpm : nil
            }
        }
        guard !overnight.isEmpty else { return 0 }
        return overnight.reduce(0, +) / Double(overnight.count)
    }

    private func daytimeAverageHR(
        from samples: [(hour: Double, bpm: Double)],
        asleepHours: [(Date, Date)],
        dayStart: Date
    ) -> Double {
        let asleepHoursOfDay: [(Double, Double)] = asleepHours.map { start, end in
            (start.timeIntervalSince(dayStart) / 3600, end.timeIntervalSince(dayStart) / 3600)
        }
        let daytime = samples.filter { sample in
            !asleepHoursOfDay.contains(where: { sample.hour >= $0.0 && sample.hour <= $0.1 })
                && sample.hour >= 7 && sample.hour < 22
        }.map(\.bpm)
        guard !daytime.isEmpty else { return 0 }
        return daytime.reduce(0, +) / Double(daytime.count)
    }

    private func estimatedMaxHR(resting: Double) -> Double {
        // Without profile age, infer a Tanaka-ish max from resting HR instead of a flat 190.
        let estimatedAge = max(18, min(75, 200 - resting * 1.6))
        let tanaka = 208 - 0.7 * estimatedAge
        return max(150, min(210, tanaka))
    }

    private func zoneMinutes(from samples: [(hour: Double, bpm: Double)], maxHR: Double) -> [Double] {
        guard samples.count >= 2, maxHR > 100 else { return [0, 0, 0, 0, 0] }
        // %HRmax zones: Z1 50–60, Z2 60–70, Z3 70–80, Z4 80–90, Z5 90+
        var zones = [0.0, 0.0, 0.0, 0.0, 0.0]
        for i in 1..<samples.count {
            let dtMin = max(0, (samples[i].hour - samples[i - 1].hour) * 60)
            guard dtMin < 15 else { continue } // ignore large gaps
            let pct = samples[i].bpm / maxHR
            let idx: Int
            switch pct {
            case ..<0.5: continue
            case ..<0.6: idx = 0
            case ..<0.7: idx = 1
            case ..<0.8: idx = 2
            case ..<0.9: idx = 3
            default: idx = 4
            }
            zones[idx] += dtMin
        }
        return zones
    }

    private func sleepingWristTemperatureDelta(start: Date, end: Date) async throws -> Double? {
        guard #available(iOS 16.0, *) else { return nil }
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let value = stats?.averageQuantity()?.doubleValue(for: .degreeCelsius())
                cont.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func averageQuantity(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let value = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func sumQuantity(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

private extension HKWorkoutActivityType {
    var cadenceDisplayName: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .swimBikeRun, .swimming: return "Swimming"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core"
        case .flexibility: return "Flexibility"
        case .dance: return "Dance"
        case .martialArts: return "Martial arts"
        case .soccer, .basketball, .tennis: return "Sport"
        default:
            return "Workout"
        }
    }
}
