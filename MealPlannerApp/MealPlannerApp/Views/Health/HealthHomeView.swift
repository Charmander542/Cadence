import SwiftUI
import SwiftData
import UIKit

/// Body home — Bevel Strain/Recovery/Sleep + Cadence Lift program on one dial page.
/// Mobbin/Bevel: dashboard rings, vital pillars; Tonal/Hevy lift CTA.
struct HealthHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}

    @Query(sort: \HealthDaySnapshotEntity.dayStart, order: .reverse)
    private var snapshots: [HealthDaySnapshotEntity]

    private enum Segment: String, CaseIterable, Identifiable {
        case overview, lift
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .lift: return "Lift"
            }
        }
    }

    @State private var segment: Segment = .overview
    @State private var selectedDay = Date()
    @State private var selectedRing: HealthMetricKind = .recovery
    @State private var focusedVitalID: String?
    @State private var scrubIndex: Int?
    @State private var showSettings = false
    @State private var showDetail: HealthMetricKind?
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var pulse = false

    private var snapshot: HealthDaySnapshotEntity? {
        snapshots.first { Calendar.current.isDate($0.dayStart, inSameDayAs: selectedDay) }
            ?? snapshots.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "Body", onMenu: onOpenDrawer)

            Picker("Section", selection: $segment) {
                ForEach(Segment.allCases) { seg in
                    Text(seg.title).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.bottom, Theme.Space.sm)
            .accessibilityLabel("Body section")

            if segment == .lift {
                WorkoutHomeView(presentation: .embedded, onOpenDrawer: nil)
            } else {
                overviewScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .onAppear {
            CadenceAppsPreferences.migrateWorkoutIntoBodyIfNeeded()
            if let existing = snapshot, existing.source == .demo {
                _ = try? HealthStore.upsertSnapshot(
                    day: selectedDay,
                    raw: HealthStore.demoRaw(for: selectedDay),
                    source: .demo,
                    in: modelContext
                )
            } else if snapshot == nil {
                HealthStore.ensureDemoSnapshot(in: modelContext, day: selectedDay)
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            Task { await sync(forcePrompt: false) }
        }
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .healthCheckIn else { return }
            segment = .overview
            showDetail = .recovery
            appModel.requestedFABAction = nil
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                HealthSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSettings = false }
                                .foregroundStyle(Theme.cta)
                        }
                    }
            }
        }
        .sheet(item: $showDetail) { kind in
            if let snapshot {
                HealthMetricDetailView(kind: kind, snapshot: snapshot)
            }
        }
    }

    private var overviewScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                dayHeader
                    .padding(.horizontal, Theme.Space.lg)

                statusPills
                    .padding(.horizontal, Theme.Space.lg)

                if let snapshot {
                    ringsCard(snapshot)
                        .padding(.horizontal, Theme.Space.lg)

                    targetStrainCard(snapshot)
                        .padding(.horizontal, Theme.Space.lg)

                    liftShortcutCard
                        .padding(.horizontal, Theme.Space.lg)

                    insightCard(snapshot)
                        .padding(.horizontal, Theme.Space.lg)

                    stressEnergyCard(snapshot)
                        .padding(.horizontal, Theme.Space.lg)

                    vitalsCard(snapshot)
                        .padding(.horizontal, Theme.Space.lg)

                    heartCard(snapshot)
                        .padding(.horizontal, Theme.Space.lg)
                } else {
                    Theme.EmptyState(
                        systemImage: "heart.text.square",
                        title: "No health data yet",
                        message: "Connect Apple Health / Apple Watch to sync sleep, HRV, and workouts.",
                        cta: "CONNECT APPLE HEALTH",
                        ctaHint: "Requests HealthKit access and syncs today"
                    ) {
                        Task { await sync(forcePrompt: true) }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                }
            }
            .padding(.top, Theme.Space.sm)
            .padding(.bottom, 110)
        }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle)
                    .font(Theme.display(.title2))
                    .foregroundStyle(Theme.ink)
                if let snapshot {
                    Text(snapshot.source == .healthKit ? "Apple Health · Watch sync" : "Demo · Bevel-style scoring")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            Button {
                Task { await sync(forcePrompt: true) }
            } label: {
                Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.cta)
                    .rotationEffect(.degrees(isSyncing ? 360 : 0))
                    .animation(isSyncing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: isSyncing)
            }
            .accessibilityLabel("Refresh health data")
            .disabled(isSyncing)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "heart.text.square")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityLabel("Health settings")
        }
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDay) {
            return "Today"
        }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: selectedDay)
    }

    private var statusPills: some View {
        HStack(spacing: Theme.Space.sm) {
            pill(
                icon: "figure.run",
                title: "ACTIVE",
                subtitle: "Until changed",
                tint: HealthChrome.recovery
            )
            pill(
                icon: pulse ? "antenna.radiowaves.left.and.right" : "checkmark.circle",
                title: syncLabel,
                subtitle: statusMessage ?? "Cadence Health",
                tint: Theme.cta
            )
        }
    }

    private var syncLabel: String {
        if let at = HealthPreferences.lastSyncAt {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return "SYNCED \(f.string(from: at).uppercased())"
        }
        return "READY"
    }

    private func pill(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
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
    }

    private func ringsCard(_ snapshot: HealthDaySnapshotEntity) -> some View {
        Theme.Card {
            VStack(spacing: Theme.Space.md) {
                Text("DAILY OVERVIEW")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: Theme.Space.md) {
                    HealthChrome.ScoreRing(
                        title: "Strain",
                        score: snapshot.strainScore,
                        tint: HealthChrome.strain,
                        selected: selectedRing == .strain
                    ) {
                        selectedRing = .strain
                        showDetail = .strain
                    }
                    HealthChrome.ScoreRing(
                        title: "Recovery",
                        score: snapshot.recoveryScore,
                        tint: HealthChrome.recovery,
                        selected: selectedRing == .recovery
                    ) {
                        selectedRing = .recovery
                        showDetail = .recovery
                    }
                    HealthChrome.ScoreRing(
                        title: "Sleep",
                        score: snapshot.sleepScore,
                        tint: HealthChrome.sleep,
                        selected: selectedRing == .sleep
                    ) {
                        selectedRing = .sleep
                        showDetail = .sleep
                    }
                }
                .frame(maxWidth: .infinity)

                if snapshot.sleepHours > 0 || snapshot.deepSleepHours > 0 {
                    HStack(spacing: Theme.Space.sm) {
                        Theme.MetaPill(text: String(format: "%.1fh asleep", snapshot.sleepHours), tone: .neutral)
                        if snapshot.deepSleepHours > 0 {
                            Theme.MetaPill(text: String(format: "%.1fh deep", snapshot.deepSleepHours), tone: .accent)
                        }
                        if snapshot.remSleepHours > 0 {
                            Theme.MetaPill(text: String(format: "%.1fh REM", snapshot.remSleepHours), tone: .cta)
                        }
                    }
                }
            }
        }
    }

    private func targetStrainCard(_ snapshot: HealthDaySnapshotEntity) -> some View {
        Theme.Card {
            HStack(spacing: Theme.Space.md) {
                Theme.IconWell(systemImage: "target", tint: HealthChrome.strain, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target strain")
                        .font(.subheadline.weight(.semibold))
                    Text("Today \(Int(snapshot.strainScore.rounded())) · aim \(Int(snapshot.targetStrain.rounded())) based on recovery")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Theme.ProgressTrack(
                    progress: min(1.2, snapshot.strainScore / max(snapshot.targetStrain, 1)) / 1.2,
                    tint: HealthChrome.strain,
                    height: 6
                )
                .frame(width: 72)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Target strain \(Int(snapshot.targetStrain.rounded())), current \(Int(snapshot.strainScore.rounded()))")
    }

    private var liftShortcutCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { segment = .lift }
        } label: {
            Theme.Card {
                HStack(spacing: Theme.Space.md) {
                    Theme.IconWell(systemImage: "dumbbell.fill", tint: Theme.cta, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lift program")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Begin today’s session, skip, or review the week")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lift program")
        .accessibilityHint("Opens the Lift tab on Body")
    }

    private func insightCard(_ snapshot: HealthDaySnapshotEntity) -> some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text(snapshot.insightTitle)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                Text(snapshot.insightBody)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stressEnergyCard(_ snapshot: HealthDaySnapshotEntity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("STRESS & ENERGY")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("TODAY’S STRESS")
                                .font(.caption2.weight(.bold))
                                .tracking(0.6)
                                .foregroundStyle(Theme.muted)
                            HStack(spacing: Theme.Space.lg) {
                                stressStat("Highest", snapshot.stressHigh, HealthChrome.stressWarm)
                                stressStat("Lowest", snapshot.stressLow, HealthChrome.stressCool)
                                stressStat("Average", snapshot.stressAvg, HealthChrome.recovery)
                            }
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [HealthChrome.recovery, HealthChrome.stressWarm, Color.red.opacity(0.8)],
                                        center: .center
                                    ),
                                    lineWidth: 8
                                )
                                .frame(width: 64, height: 64)
                            VStack(spacing: 0) {
                                Text("\(Int(snapshot.stressAvg.rounded()))")
                                    .font(.title3.weight(.bold))
                                Text(stressLabel(snapshot.stressAvg))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .onTapGesture { showDetail = .stress }
                        .accessibilityLabel("Stress average \(Int(snapshot.stressAvg.rounded())), \(stressLabel(snapshot.stressAvg))")
                    }

                    HealthChrome.EnergyBar(percent: snapshot.energyPercent)
                        .onTapGesture { showDetail = .energy }
                }
            }
        }
    }

    private func stressStat(_ label: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(value.rounded()))")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
    }

    private func stressLabel(_ avg: Double) -> String {
        if avg < 25 { return "Low" }
        if avg < 50 { return "Med" }
        return "High"
    }

    private func vitalsCard(_ snapshot: HealthDaySnapshotEntity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("VITALS")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(HealthStore.vitals(from: snapshot)) { vital in
                        HealthChrome.VitalPillar(
                            vital: vital,
                            focused: focusedVitalID == vital.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                focusedVitalID = vital.id
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
        }
    }

    private func heartCard(_ snapshot: HealthDaySnapshotEntity) -> some View {
        let samples = HealthStore.heartSeries(from: snapshot)
        let scrub = scrubIndex.flatMap { samples.indices.contains($0) ? samples[$0] : nil }
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("HEART RATE")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scrub.map { "\(Int($0.bpm.rounded())) bpm" } ?? "\(Int(snapshot.restingHR.rounded())) bpm rest")
                                .font(Theme.display(.title2))
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText())
                            Text(scrub.map { hourLabel($0.hour) } ?? "Drag the chart to scrub")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button {
                            showDetail = .heartRate
                        } label: {
                            Text("DETAIL")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.cta)
                        }
                        .buttonStyle(.plain)
                    }

                    HealthChrome.Sparkline(samples: samples, scrubIndex: $scrubIndex)
                        .frame(height: 110)
                }
            }
        }
    }

    private func hourLabel(_ hour: Double) -> String {
        let h = Int(hour)
        let m = Int((hour - Double(h)) * 60)
        let period = h >= 12 ? "PM" : "AM"
        let display = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", display, m, period)
    }

    @MainActor
    private func sync(forcePrompt: Bool = true) async {
        isSyncing = true
        defer { isSyncing = false }
        let client = HealthKitClient()
        guard await client.isAvailable else {
            statusMessage = "Demo device"
            HealthStore.ensureDemoSnapshot(in: modelContext, day: selectedDay)
            return
        }
        do {
            if forcePrompt || !HealthPreferences.didRequestAuthorization {
                try await client.requestAuthorization()
                HealthPreferences.didRequestAuthorization = true
            }
            let raw = try await client.fetchDayMetrics(for: selectedDay)
            let hasSignal = raw.sleepHours + raw.overnightRHR + raw.appleRestingHR + raw.steps
                + raw.activeEnergyKcal + raw.hrvMs + Double(raw.workoutCount) > 0
            if hasSignal {
                _ = try HealthStore.upsertSnapshot(day: selectedDay, raw: raw, source: .healthKit, in: modelContext)
                let parts = [
                    raw.workoutCount > 0 ? "\(raw.workoutCount) workout\(raw.workoutCount == 1 ? "" : "s")" : nil,
                    raw.sleepHours > 0 ? String(format: "%.1fh sleep" , raw.sleepHours) : nil,
                ].compactMap { $0 }
                statusMessage = parts.isEmpty ? "Apple Health" : parts.joined(separator: " · ")
            } else if HealthPreferences.preferDemoFallback {
                _ = try HealthStore.upsertSnapshot(day: selectedDay, raw: HealthStore.demoRaw(for: selectedDay), source: .demo, in: modelContext)
                statusMessage = "Demo fallback"
            } else {
                statusMessage = "No samples today"
            }
        } catch {
            statusMessage = error.localizedDescription
            if HealthPreferences.preferDemoFallback {
                HealthStore.ensureDemoSnapshot(in: modelContext, day: selectedDay)
            }
        }
    }
}
