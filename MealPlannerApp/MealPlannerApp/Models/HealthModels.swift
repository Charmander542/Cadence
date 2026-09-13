import Foundation
import SwiftData
import SwiftUI

/// Cached day snapshot for Body (Health + Lift). Bevel-inspired scores live in `BevelScoring`.
@Model
final class HealthDaySnapshotEntity {
    var id: UUID = UUID()
    var dayStart: Date = Date()
    var strainScore: Double = 0
    var recoveryScore: Double = 0
    var sleepScore: Double = 0
    var targetStrain: Double = 45
    var sleepHours: Double = 0
    var timeInBedHours: Double = 0
    var deepSleepHours: Double = 0
    var remSleepHours: Double = 0
    var coreSleepHours: Double = 0
    var awakeInterruptions: Int = 0
    var sleepLatencyMinutes: Double = -1
    var restingHR: Double = 0
    var hrvMs: Double = 0
    var respiratoryRate: Double = 0
    var spo2Percent: Double = 0
    var wristTempDeltaC: Double = 0
    var hasWristTemp: Bool = false
    var activeEnergyKcal: Double = 0
    var steps: Double = 0
    var exerciseMinutes: Double = 0
    var workoutCount: Int = 0
    var workoutActiveEnergyKcal: Double = 0
    var zoneMinutesJSON: String = "[0,0,0,0,0]"
    var scoreConfidence: Double = 0
    var stressHigh: Double = 0
    var stressLow: Double = 0
    var stressAvg: Double = 0
    var energyPercent: Double = 0
    var insightTitle: String = ""
    var insightBody: String = ""
    var sourceRaw: String = "demo"
    var updatedAt: Date = Date()

    /// Optional JSON array of `{s,a,b}` sleep stage segments (stage, startEpoch, endEpoch).
    var sleepStagesJSON: String = "[]"

    /// Optional JSON array of `{t,v}` for HR sparkline (hours from midnight, bpm).
    var heartRateSeriesJSON: String = "[]"

    var source: HealthDataSource {
        get { HealthDataSource(rawValue: sourceRaw) ?? .demo }
        set { sourceRaw = newValue.rawValue }
    }

    init(dayStart: Date) {
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
    }
}

enum HealthDataSource: String, Codable {
    case demo
    case healthKit
}

struct HealthVital: Identifiable, Hashable {
    enum Status: String, Hashable {
        case normal, lower, higher, noData
        var title: String {
            switch self {
            case .normal: return "Normal"
            case .lower: return "Lower"
            case .higher: return "Higher"
            case .noData: return "No data"
            }
        }
    }

    let id: String
    let title: String
    let systemImage: String
    let value: Double?
    let unit: String
    let normalized: Double // 0…1 for pillar / gauge position
    var status: Status = .normal
    /// Highlight band on the vertical gauge (baseline “normal” range), 0…1.
    var bandLow: Double = 0.35
    var bandHigh: Double = 0.65
}

struct HealthScoreSet: Hashable {
    var strain: Double
    var recovery: Double
    var sleep: Double
}

enum HealthMetricKind: String, CaseIterable, Identifiable {
    case strain, recovery, sleep, heartRate, hrv, energy, stress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strain: return "Strain"
        case .recovery: return "Recovery"
        case .sleep: return "Sleep"
        case .heartRate: return "Heart rate"
        case .hrv: return "HRV"
        case .energy: return "Energy"
        case .stress: return "Stress"
        }
    }

    var systemImage: String {
        switch self {
        case .strain: return "flame.fill"
        case .recovery: return "arrow.triangle.2.circlepath"
        case .sleep: return "moon.fill"
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .energy: return "bolt.fill"
        case .stress: return "brain.head.profile"
        }
    }
}

struct HealthHeartSample: Identifiable, Hashable {
    var id: Double { hour }
    let hour: Double
    let bpm: Double
}
