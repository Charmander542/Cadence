import SwiftUI
import SwiftData

/// Deliberate metric detail — Bevel Primary sleep / Recovery / Strain explainers.
struct HealthMetricDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: HealthMetricKind
    let snapshot: HealthDaySnapshotEntity
    @State private var scrubIndex: Int?

    private var scored: BevelScoring.Result {
        HealthStore.score(from: HealthStore.rawApproximate(from: snapshot))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if kind == .sleep {
                        primarySleepContent
                    } else {
                        genericContent
                    }
                }
                .padding(.vertical, Theme.Space.lg)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(kind == .sleep ? "Primary sleep" : kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    // MARK: - Bevel Primary sleep

    private var primarySleepContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            sleepHeader
                .padding(.horizontal, Theme.Space.lg)

            sleepScorePill
                .padding(.horizontal, Theme.Space.lg)

            // Hypnogram first — this is the night tracker people come for.
            sleepStagesSection
                .padding(.horizontal, Theme.Space.lg)

            primarySleepCard
                .padding(.horizontal, Theme.Space.lg)

            sleepNeededRow
                .padding(.horizontal, Theme.Space.lg)

            latencySection
                .padding(.horizontal, Theme.Space.lg)

            sleepBankCard
                .padding(.horizontal, Theme.Space.lg)

            Text(scored.sleepBreakdown.narrative)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.lg)

            confidenceFooter
                .padding(.horizontal, Theme.Space.lg)
        }
    }

    private var sleepHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Primary sleep")
                .font(Theme.display(.title))
                .foregroundStyle(Theme.ink)
            Text(sleepSubtitleDate)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if snapshot.source == .healthKit {
                Label("Tracked with Apple Watch", systemImage: "applewatch")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sleepSubtitleDate: String {
        let f = DateFormatter()
        f.dateFormat = "M/d/yy"
        let day = f.string(from: snapshot.dayStart)
        return "\(day) · last night"
    }

    private var sleepScorePill: some View {
        HStack {
            Text("Sleep Score")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("\(Int(snapshot.sleepScore.rounded()))%")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
            HealthChrome.MiniRing(
                progress: snapshot.sleepScore / 100,
                tint: HealthChrome.sleep,
                size: 28,
                lineWidth: 3.5
            )
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm + 2)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep score \(Int(snapshot.sleepScore.rounded())) percent")
    }

    private var primarySleepCard: some View {
        let items = Array(scored.sleepBreakdown.contributors.prefix(6))
        return Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack {
                    Label("Sleep Period", systemImage: "bed.double.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text(sleepPeriodLabel)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }

                HStack(spacing: Theme.Space.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BevelScoring.formatHours(snapshot.timeInBedHours))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        Text("Time In Bed")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BevelScoring.formatHours(snapshot.sleepHours))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        Text("Time Asleep")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Contributors")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HealthChrome.ContributorCell(item: item)
                        if index < items.count - 1 {
                            Divider().overlay(Theme.gridDivider)
                        }
                    }
                }

                if snapshot.source == .healthKit {
                    Label("Tracked with Apple Watch", systemImage: "applewatch")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var sleepPeriodLabel: String {
        // Approximate overnight window from asleep duration ending ~wake.
        let asleep = snapshot.sleepHours
        let inBed = max(snapshot.timeInBedHours, asleep)
        guard asleep > 0.2 else { return "—" }
        let wakeHour = 8.0
        let startHour = wakeHour - inBed
        return "\(hourClock(startHour)) – \(hourClock(wakeHour))"
    }

    private func hourClock(_ hour: Double) -> String {
        var h = hour
        while h < 0 { h += 24 }
        while h >= 24 { h -= 24 }
        let hi = Int(h)
        let m = Int((h - Double(hi)) * 60)
        let period = hi >= 12 ? "PM" : "AM"
        let display = hi % 12 == 0 ? 12 : hi % 12
        return String(format: "%d:%02d %@", display, m, period)
    }

    private var sleepStagesSection: some View {
        let asleep = max(snapshot.sleepHours, 0.01)
        let deep = snapshot.deepSleepHours
        let rem = snapshot.remSleepHours
        let core = snapshot.coreSleepHours > 0.05
            ? snapshot.coreSleepHours
            : max(0, asleep - deep - rem)
        let awake = max(0, snapshot.timeInBedHours - snapshot.sleepHours)
        let denom = max(snapshot.timeInBedHours, asleep)

        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Sleep Stages")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    HealthChrome.SleepHypnogram(
                        asleepHours: asleep,
                        deepHours: deep,
                        remHours: rem,
                        coreHours: core,
                        awakeHours: awake,
                        segments: HealthStore.sleepStages(from: snapshot)
                    )
                    Text("Hold and drag to inspect a stage.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.sm) {
                HealthChrome.StageRingCard(
                    title: "Awake",
                    hours: awake,
                    percent: awake / denom * 100,
                    tint: HealthChrome.stageAwake
                )
                HealthChrome.StageRingCard(
                    title: "REM",
                    hours: rem,
                    percent: rem / denom * 100,
                    tint: HealthChrome.stageREM
                )
                HealthChrome.StageRingCard(
                    title: "Core",
                    hours: core,
                    percent: core / denom * 100,
                    tint: HealthChrome.stageCore
                )
                HealthChrome.StageRingCard(
                    title: "Deep",
                    hours: deep,
                    percent: deep / denom * 100,
                    tint: HealthChrome.stageDeep
                )
            }
        }
    }

    private var sleepNeededRow: some View {
        Theme.Card {
            HStack {
                Text("Last night's sleep needed")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(BevelScoring.formatHours(HealthPreferences.sleepGoalHours))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last night's sleep needed \(BevelScoring.formatHours(HealthPreferences.sleepGoalHours))")
    }

    private var latencySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Time To Fall Asleep")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Theme.Card {
                HealthChrome.LatencyScale(
                    minutes: snapshot.sleepLatencyMinutes >= 0 ? snapshot.sleepLatencyMinutes : nil
                )
            }
        }
    }

    // MARK: - Non-sleep metrics

    private var genericContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            hero
                .padding(.horizontal, Theme.Space.lg)

            if kind == .recovery || kind == .strain {
                narrativeCard
                    .padding(.horizontal, Theme.Space.lg)
                contributorsSection
                    .padding(.horizontal, Theme.Space.lg)
            } else {
                explanation
                    .padding(.horizontal, Theme.Space.lg)
            }

            if kind == .heartRate || kind == .strain {
                chart
                    .padding(.horizontal, Theme.Space.lg)
            }

            confidenceFooter
                .padding(.horizontal, Theme.Space.lg)
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
        case .strain:
            return "Target \(Int(snapshot.targetStrain.rounded()))% · \(Int(snapshot.activeEnergyKcal.rounded())) active kcal · \(Int(snapshot.steps.rounded())) steps"
        case .recovery:
            return "HRV \(Int(snapshot.hrvMs.rounded())) ms · RHR \(Int(snapshot.restingHR.rounded())) bpm vs your baseline"
        case .sleep:
            return "\(BevelScoring.formatHours(snapshot.sleepHours)) asleep · \(BevelScoring.formatHours(snapshot.timeInBedHours)) in bed"
        case .heartRate:
            return "Overnight / resting heart rate for this day"
        case .hrv:
            return "SDNN from Apple Health — higher vs your baseline usually means better recovery"
        case .energy:
            return "Blend of recovery, sleep, and leftover strain capacity"
        case .stress:
            return "High \(Int(snapshot.stressHigh.rounded())) · Low \(Int(snapshot.stressLow.rounded())) — from HRV, recovery, and strain"
        }
    }

    private var narrativeCard: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("WHAT THIS MEANS")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Text(narrativeText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var narrativeText: String {
        switch kind {
        case .sleep: return scored.sleepBreakdown.narrative
        case .recovery: return scored.recoveryBreakdown.narrative
        case .strain: return scored.strainBreakdown.narrative
        default: return blurb
        }
    }

    private var contributors: [BevelScoring.Contributor] {
        switch kind {
        case .sleep: return scored.sleepBreakdown.contributors
        case .recovery: return scored.recoveryBreakdown.contributors
        case .strain: return scored.strainBreakdown.contributors
        default: return []
        }
    }

    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("CONTRIBUTORS")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 2)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                VStack(spacing: 0) {
                    ForEach(Array(contributors.enumerated()), id: \.element.id) { index, item in
                        HealthChrome.ContributorCell(item: item)
                        if index < contributors.count - 1 {
                            Divider().overlay(Theme.gridDivider)
                        }
                    }
                }
            }
        }
    }

    private var sleepBankCard: some View {
        let bank = scored.sleepBankHours
        return Theme.Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP BANK")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                    Text(bank >= 0
                         ? String(format: "+%.1fh surplus", bank)
                         : String(format: "%.1fh debt", abs(bank)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(bank >= 0 ? Theme.cta : Theme.danger)
                    Text("Last 7 nights vs \(String(format: "%.1fh", HealthPreferences.sleepGoalHours)) goal")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: bank >= 0 ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(bank >= 0 ? Theme.cta : Theme.danger)
            }
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
            return "Strain estimates how hard the day pushed you from workouts (active) and daily movement (passive), on a log curve so the top is harder to reach."
        case .recovery:
            return "Recovery compares overnight HRV, resting heart rate, breathing, SpO₂, and wrist temperature to your personal baselines, plus last night’s sleep."
        case .sleep:
            return "Sleep blends duration, REM/deep balance, efficiency, continuity, and nocturnal heart-rate dip — matching Bevel’s Primary sleep contributors."
        case .heartRate:
            return "Scrub the sparkline to replay the day. Resting values prefer overnight samples when Watch sleep is available."
        case .hrv:
            return "HRV (SDNN) is one of the strongest readiness signals when measured consistently overnight."
        case .energy:
            return "Energy is a glanceable battery from recovery, sleep, and unused strain capacity — not a medical claim."
        case .stress:
            return "Stress high/avg/low are derived from HRV vs baseline, recovery, and strain for training decisions."
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
                    .frame(height: 120)
            }
        }
    }

    private var confidenceFooter: some View {
        Text(String(format: "Data confidence %.0f%% · scores use Apple Health when available. Not medical advice.", scored.confidence * 100))
            .font(.footnote)
            .foregroundStyle(Theme.muted)
    }
}
