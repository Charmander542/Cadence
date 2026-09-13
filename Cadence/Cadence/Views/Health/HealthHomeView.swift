import SwiftUI
import SwiftData
import UIKit

/// Body home — Bevel Strain/Recovery/Sleep + Cadence Lift program on one dial page.
/// Mobbin/Bevel: dashboard rings, vital pillars; Tonal/Hevy lift CTA.
struct HealthHomeView: View {
    @Environment(\.modelContext) private var modelContext
    var onOpenDrawer: () -> Void = {}

    @Query(sort: \HealthDaySnapshotEntity.dayStart, order: .reverse)
    private var snapshots: [HealthDaySnapshotEntity]

    private enum Segment: String, CaseIterable, Identifiable {
        case overview, sleep, fitness, lift
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .sleep: return "Sleep"
            case .fitness: return "Fitness"
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
    @State private var workouts: [HealthKitClient.WorkoutSummary] = []
    @State private var workoutsError: String?
    @State private var selectedWorkout: HealthKitClient.WorkoutSummary?
    @State private var showDayPicker = false

    private var snapshot: HealthDaySnapshotEntity? {
        snapshots.first { Calendar.current.isDate($0.dayStart, inSameDayAs: selectedDay) }
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
            } else if segment == .sleep {
                sleepScroll
            } else if segment == .fitness {
                fitnessScroll
            } else {
                overviewScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .onAppear {
            CadenceAppsPreferences.migrateWorkoutIntoBodyIfNeeded()
            selectedDay = Calendar.current.startOfDay(for: selectedDay)
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
        .onChange(of: segment) { _, seg in
            if seg == .fitness {
                Task { await loadWorkouts() }
            }
        }
        .onChange(of: selectedDay) { _, _ in
            Task {
                await sync(forcePrompt: false)
                if segment == .fitness {
                    await loadWorkouts()
                }
            }
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
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailSheet(workout: workout)
        }
        .sheet(isPresented: $showDayPicker) {
            NavigationStack {
                List {
                    ForEach(historyDays, id: \.self) { day in
                        Button {
                            selectedDay = Calendar.current.startOfDay(for: day)
                            showDayPicker = false
                        } label: {
                            HStack {
                                Text(historyDayTitle(day))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                if let snap = snapshots.first(where: { Calendar.current.isDate($0.dayStart, inSameDayAs: day) }) {
                                    Text("S \(Int(snap.sleepScore.rounded())) · R \(Int(snap.recoveryScore.rounded()))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.muted)
                                }
                                if Calendar.current.isDate(day, inSameDayAs: selectedDay) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.cta)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showDayPicker = false }
                            .foregroundStyle(Theme.cta)
                    }
                }
            }
            .presentationDetents([.medium, .large])
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
                        title: Calendar.current.isDateInToday(selectedDay) ? "No health data yet" : "No data for this day",
                        message: Calendar.current.isDateInToday(selectedDay)
                            ? "Connect Apple Health / Apple Watch to sync sleep, HRV, and workouts."
                            : "Pull from Apple Health for \(dayTitle), or pick another day.",
                        cta: "SYNC APPLE HEALTH",
                        ctaHint: "Requests HealthKit access and syncs the selected day"
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
            Button {
                showDayPicker = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(dayTitle)
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.ink)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }
                    if let snapshot {
                        Text(snapshot.source == .healthKit ? "Apple Health · Watch sync" : "Demo · Bevel-style scoring")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(dayTitle), choose day")
            .accessibilityHint("Opens multi-day history")

            Spacer()

            Button {
                shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityLabel("Previous day")

            Button {
                shiftDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .disabled(Calendar.current.isDateInToday(selectedDay) || selectedDay > Date())
            .accessibilityLabel("Next day")

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

    private var historyDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days: [Date] = []
        for offset in 0..<30 {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                days.append(d)
            }
        }
        return days
    }

    private func historyDayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: day)
    }

    private func shiftDay(_ delta: Int) {
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .day, value: delta, to: selectedDay) else { return }
        let today = cal.startOfDay(for: Date())
        let candidate = cal.startOfDay(for: next)
        guard candidate <= today else { return }
        selectedDay = candidate
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
                        HealthChrome.StressGauge(
                            value: snapshot.stressAvg,
                            label: stressLabel(snapshot.stressAvg)
                        )
                        .onTapGesture { showDetail = .stress }
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
            Text("HEALTH MONITOR")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.sm) {
                ForEach(HealthStore.vitals(from: snapshot)) { vital in
                    HealthChrome.MonitorCard(
                        vital: vital,
                        focused: focusedVitalID == vital.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            focusedVitalID = vital.id
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // Sheets only when they add real explanation — Sleep opens Primary sleep.
                        if vital.id == "sleep" {
                            showDetail = .sleep
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

    private var sleepScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                dayHeader
                    .padding(.horizontal, Theme.Space.lg)
                if let snapshot {
                    let scored = HealthStore.score(from: HealthStore.rawApproximate(from: snapshot))
                    let asleep = max(snapshot.sleepHours, 0.01)
                    let deep = snapshot.deepSleepHours
                    let rem = snapshot.remSleepHours
                    let core = snapshot.coreSleepHours > 0.05
                        ? snapshot.coreSleepHours
                        : max(0, asleep - deep - rem)
                    let awake = max(0, snapshot.timeInBedHours - snapshot.sleepHours)
                    let denom = max(snapshot.timeInBedHours, asleep)

                    // Bevel Primary sleep event card — score badge, tap for full explainers
                    Button {
                        showDetail = .sleep
                    } label: {
                        Theme.Card {
                            HStack(spacing: Theme.Space.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(HealthChrome.sleep.opacity(0.18))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "moon.stars.fill")
                                        .foregroundStyle(HealthChrome.sleep)
                                    Text("\(Int(snapshot.sleepScore.rounded()))")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                        .padding(5)
                                        .background(Circle().fill(Theme.surface))
                                        .offset(x: 18, y: 18)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Primary sleep")
                                        .font(.headline)
                                        .foregroundStyle(Theme.ink)
                                    Text("\(BevelScoring.formatHours(snapshot.sleepHours)) asleep · \(BevelScoring.formatHours(snapshot.timeInBedHours)) in bed")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                    if snapshot.source == .healthKit {
                                        Text("Apple Watch")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Space.lg)
                    .accessibilityLabel("Primary sleep \(Int(snapshot.sleepScore.rounded())) percent")
                    .accessibilityHint("Opens score contributors and sleep bank")

                    Theme.Card {
                        VStack(alignment: .leading, spacing: Theme.Space.md) {
                            Text("Sleep Stages")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
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
                    .padding(.horizontal, Theme.Space.lg)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.sm) {
                        HealthChrome.StageRingCard(title: "Awake", hours: awake, percent: awake / denom * 100, tint: HealthChrome.stageAwake)
                        HealthChrome.StageRingCard(title: "REM", hours: rem, percent: rem / denom * 100, tint: HealthChrome.stageREM)
                        HealthChrome.StageRingCard(title: "Core", hours: core, percent: core / denom * 100, tint: HealthChrome.stageCore)
                        HealthChrome.StageRingCard(title: "Deep", hours: deep, percent: deep / denom * 100, tint: HealthChrome.stageDeep)
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    Theme.Card {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(scored.sleepBreakdown.narrative)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text("Last night's sleep needed")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Text(BevelScoring.formatHours(HealthPreferences.sleepGoalHours))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("Time To Fall Asleep")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, Theme.Space.lg)
                        Theme.Card {
                            HealthChrome.LatencyScale(
                                minutes: snapshot.sleepLatencyMinutes >= 0 ? snapshot.sleepLatencyMinutes : nil
                            )
                        }
                        .padding(.horizontal, Theme.Space.lg)
                    }

                    sleepTrendCards
                        .padding(.horizontal, Theme.Space.lg)
                } else {
                    Text("Sync Apple Health to see last night’s sleep.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.Space.lg)
                }
            }
            .padding(.vertical, Theme.Space.md)
            .padding(.bottom, PlannerChromeMetrics.dialFABClearance)
        }
    }

    private var sleepTrendCards: some View {
        let recent = Array(snapshots.prefix(14))
        let bank = snapshot.map {
            HealthStore.score(from: HealthStore.rawApproximate(from: $0)).sleepBankHours
        } ?? 0
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Trends")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Theme.Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sleep Score", systemImage: "zzz")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text(snapshot.map { "\(Int($0.sleepScore.rounded()))%" } ?? "—")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    HealthChrome.MiniTrend(values: recent.map(\.sleepScore).reversed(), tint: HealthChrome.sleep)
                        .frame(width: 88, height: 36)
                }
            }
            Theme.Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sleep Bank", systemImage: "building.columns.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text(bank >= 0 ? String(format: "+%.1fh", bank) : String(format: "%.1fh", bank))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(bank >= 0 ? HealthChrome.recovery : HealthChrome.stressWarm)
                        Text(bank >= 0 ? "Surplus" : "Debt")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(bank >= 0 ? HealthChrome.recovery : HealthChrome.stressWarm)
                    }
                    Spacer()
                    HealthChrome.MiniTrend(
                        values: recent.map { $0.sleepHours - HealthPreferences.sleepGoalHours }.reversed(),
                        tint: bank >= 0 ? HealthChrome.recovery : HealthChrome.stressWarm
                    )
                    .frame(width: 88, height: 36)
                }
            }
        }
    }

    private var fitnessScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                dayHeader
                    .padding(.horizontal, Theme.Space.lg)

                activityHeatmapCard
                    .padding(.horizontal, Theme.Space.lg)

                if let snapshot {
                    Theme.Card {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("ACTIVITY SUMMARY")
                                .font(.caption2.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.muted)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "%.0f min", snapshot.exerciseMinutes))
                                        .font(Theme.display(.title))
                                        .foregroundStyle(Theme.ink)
                                    Text("Exercise time")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(snapshot.strainScore.rounded()))%")
                                        .font(Theme.display(.title))
                                        .foregroundStyle(Theme.ink)
                                    Text("Strain · aim \(Int(snapshot.targetStrain.rounded()))")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            Button { showDetail = .strain } label: {
                                Text("Explain strain")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.cta)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                }

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    HStack {
                        Text("WORKOUT LOG")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Button {
                            withAnimation { segment = .lift }
                        } label: {
                            Text("OPEN LIFT")
                                .font(.caption.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.cta)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    if let workoutsError {
                        Text(workoutsError)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, Theme.Space.lg)
                    }

                    if workouts.isEmpty {
                        Theme.Card {
                            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                                Text(Calendar.current.isDateInToday(selectedDay) ? "No workouts logged today" : "No workouts for \(dayTitle)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("Apple Watch workouts and apps that write to Health appear here. Use Lift for Cadence strength sessions.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Theme.Space.lg)
                    } else {
                        Theme.Card {
                            VStack(spacing: 0) {
                                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                                    Button {
                                        selectedWorkout = workout
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(workout.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Theme.ink)
                                                Text([
                                                    workout.start.formatted(date: .omitted, time: .shortened),
                                                    String(format: "%.0fm", workout.durationMinutes),
                                                    String(format: "%.0f kcal", workout.activeEnergyKcal),
                                                    workout.averageHR.map { "\(Int($0.rounded())) bpm" },
                                                    workout.source,
                                                ].compactMap { $0 }.joined(separator: " · "))
                                                    .font(.caption2)
                                                    .foregroundStyle(Theme.muted)
                                            }
                                            Spacer(minLength: 0)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Theme.muted)
                                        }
                                        .padding(.horizontal, Theme.Space.md)
                                        .padding(.vertical, Theme.Space.sm + 2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Opens workout detail")
                                    if index < workouts.count - 1 {
                                        Divider().overlay(Theme.gridDivider)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Space.lg)
                    }
                }
            }
            .padding(.vertical, Theme.Space.md)
            .padding(.bottom, PlannerChromeMetrics.dialFABClearance)
        }
    }

    private var activityHeatmapCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days: [Date] = (0..<30).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }.reversed()
        return Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fitness")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text("Last 30 days")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        let snap = snapshots.first { cal.isDate($0.dayStart, inSameDayAs: day) }
                        let level = activityLevel(snap)
                        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
                        Button {
                            selectedDay = cal.startOfDay(for: day)
                        } label: {
                            Capsule()
                                .fill(heatmapColor(level))
                                .frame(height: 14)
                                .overlay {
                                    if isSelected {
                                        Capsule()
                                            .strokeBorder(Theme.cta, lineWidth: 1.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(historyDayTitle(day)), activity level \(level)")
                    }
                }
                HStack(spacing: Theme.Space.sm) {
                    legendDot(heatmapColor(0), "None")
                    legendDot(heatmapColor(1), "Light")
                    legendDot(heatmapColor(2), "Active")
                    legendDot(heatmapColor(3), "Hard")
                }
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }
        }
    }

    private func activityLevel(_ snap: HealthDaySnapshotEntity?) -> Int {
        guard let snap else { return 0 }
        if snap.workoutCount >= 2 || snap.strainScore >= 70 { return 3 }
        if snap.workoutCount >= 1 || snap.exerciseMinutes >= 30 || snap.strainScore >= 45 { return 2 }
        if snap.steps >= 4000 || snap.exerciseMinutes > 0 || snap.strainScore >= 20 { return 1 }
        return 0
    }

    private func heatmapColor(_ level: Int) -> Color {
        switch level {
        case 1: return HealthChrome.recovery.opacity(0.35)
        case 2: return HealthChrome.recovery.opacity(0.7)
        case 3: return Theme.cta.opacity(0.85)
        default: return Theme.sunken
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    @MainActor
    private func loadWorkouts() async {
        let client = HealthKitClient()
        guard await client.isAvailable else {
            workouts = []
            workoutsError = "Apple Health unavailable — Lift still works for strength."
            return
        }
        do {
            if !HealthPreferences.didRequestAuthorization {
                try await client.requestAuthorization()
                HealthPreferences.didRequestAuthorization = true
            }
            workouts = try await client.fetchWorkouts(for: selectedDay)
            workoutsError = nil
        } catch {
            workouts = []
            workoutsError = error.localizedDescription
        }
    }

    private func detailKind(forVitalID id: String) -> HealthMetricKind? {
        switch id {
        case "rhr": return .heartRate
        case "hrv": return .hrv
        case "resp", "spo2", "temp": return .recovery
        case "sleep": return .sleep
        default: return nil
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
                statusMessage = Calendar.current.isDateInToday(selectedDay) ? "No samples today" : "No samples for this day"
            }
        } catch {
            statusMessage = error.localizedDescription
            if HealthPreferences.preferDemoFallback {
                HealthStore.ensureDemoSnapshot(in: modelContext, day: selectedDay)
            }
        }
    }
}
