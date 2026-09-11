import SwiftUI
import SwiftData

struct HealthMetricDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: HealthMetricKind
    let snapshot: HealthDaySnapshotEntity
    @State private var scrubIndex: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    hero
                        .padding(.horizontal, Theme.Space.lg)
                    explanation
                        .padding(.horizontal, Theme.Space.lg)
                    if kind == .heartRate || kind == .strain {
                        chart
                            .padding(.horizontal, Theme.Space.lg)
                    }
                    Text("Scoring is a lightweight placeholder — swap algorithms later without redesigning this screen.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.Space.lg)
                }
                .padding(.vertical, Theme.Space.lg)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cta)
                }
            }
        }
    }

    private var hero: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Label(kind.title.uppercased(), systemImage: kind.systemImage)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                Text(heroValue)
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(heroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroValue: String {
        switch kind {
        case .strain: return "\(Int(snapshot.strainScore.rounded()))%"
        case .recovery: return "\(Int(snapshot.recoveryScore.rounded()))%"
        case .sleep: return "\(Int(snapshot.sleepScore.rounded()))%"
        case .heartRate: return "\(Int(snapshot.restingHR.rounded())) bpm"
        case .hrv: return "\(Int(snapshot.hrvMs.rounded())) ms"
        case .energy: return "\(Int(snapshot.energyPercent.rounded()))%"
        case .stress: return "\(Int(snapshot.stressAvg.rounded())) avg"
        }
    }

    private var heroSubtitle: String {
        switch kind {
        case .strain: return "\(Int(snapshot.activeEnergyKcal.rounded())) active kcal · \(Int(snapshot.steps.rounded())) steps"
        case .recovery: return "HRV \(Int(snapshot.hrvMs.rounded())) ms · RHR \(Int(snapshot.restingHR.rounded())) bpm"
        case .sleep: return String(format: "%.1f hours logged", snapshot.sleepHours)
        case .heartRate: return "Resting baseline for this day"
        case .hrv: return "SDNN-style variability (placeholder)"
        case .energy: return "Derived from recovery, strain, and sleep"
        case .stress: return "High \(Int(snapshot.stressHigh.rounded())) · Low \(Int(snapshot.stressLow.rounded()))"
        }
    }

    private var explanation: some View {
        Theme.Card {
            Text(blurb)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var blurb: String {
        switch kind {
        case .strain:
            return "Strain estimates how hard the day pushed you from movement and burn. Cadence will get smarter models later — this ring is for feel and habit."
        case .recovery:
            return "Recovery blends sleep load with HRV and resting heart rate. Tap vitals on Home to explore the inputs."
        case .sleep:
            return "Sleep score is duration versus an 8-hour target for now. Stage-aware scoring can land once HealthKit stages are wired deeper."
        case .heartRate:
            return "Scrub the sparkline to replay the day. Fun first — clinical precision later."
        case .hrv:
            return "HRV is one of the strongest recovery signals when measured consistently."
        case .energy:
            return "Energy is a playful battery — not a medical claim — so you can glance and decide how hard to go."
        case .stress:
            return "Stress highs/lows are sketched from strain and recovery until a proper HRV-stress model ships."
        }
    }

    private var chart: some View {
        let samples = HealthStore.heartSeries(from: snapshot)
        return Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("DAY TREND")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                HealthChrome.Sparkline(samples: samples, scrubIndex: $scrubIndex)
                    .frame(height: 140)
            }
        }
    }
}
