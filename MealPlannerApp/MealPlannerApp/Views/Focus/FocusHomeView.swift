import SwiftUI
import SwiftData
import UIKit

/// Focus timer pager — Toggl Track ring + Me+ control chrome, Cadence Theme.
struct FocusHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}

    @Query(sort: \FocusSessionEntity.startedAt, order: .reverse)
    private var sessions: [FocusSessionEntity]

    @State private var mode: FocusMode = .pomo
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var startedAt: Date?
    @State private var accumulated: TimeInterval = 0
    @State private var displaySeconds = 0
    @State private var pomoMinutes = FocusPreferences.pomoMinutes
    @State private var showStats = false
    @State private var showDurationPicker = false
    @State private var pickerMinutes = FocusPreferences.pomoMinutes

    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var pomoTargetSeconds: Int { pomoMinutes * 60 }

    private var statusLabel: String {
        if isRunning { return "Running…" }
        if isPaused { return "Paused" }
        return mode == .pomo ? "Ready?" : "Stopwatch"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: Theme.Space.sm)

            timerHero
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            Spacer(minLength: Theme.Space.xl)

            controls
                .padding(.horizontal, Theme.Space.xl)
                .padding(.bottom, Theme.Space.xxl)
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: isRunning)
        .animation(.easeInOut(duration: 0.2), value: isPaused)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.canvas
                if isRunning || isPaused {
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.16), Theme.accent.opacity(0.0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 280
                    )
                    .offset(y: -40)
                    .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
        }
        .onReceive(timer) { _ in refreshDisplay() }
        .onAppear {
            pomoMinutes = FocusPreferences.pomoMinutes
            if !isRunning && !isPaused {
                displaySeconds = mode == .pomo ? pomoTargetSeconds : 0
            }
        }
        .onChange(of: mode) { _, new in
            guard !isRunning && !isPaused else { return }
            displaySeconds = new == .pomo ? pomoTargetSeconds : 0
        }
        .sheet(isPresented: $showStats) {
            FocusStatsView(sessions: sessions)
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPickerSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Space.sm) {
            Button(action: onOpenDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Open sidebar")

            Spacer(minLength: 0)
            modeSwitcher
            Spacer(minLength: 0)

            Button { showStats = true } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Focus statistics")
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, Theme.Space.xs)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(FocusMode.allCases) { item in
                Button {
                    guard !isRunning, mode != item else { return }
                    // Reset clock before flipping mode so the pomo ring never
                    // renders a frame with stopwatch's displaySeconds == 0 (full progress).
                    isPaused = false
                    accumulated = 0
                    startedAt = nil
                    displaySeconds = item == .pomo ? pomoTargetSeconds : 0
                    withAnimation(.easeInOut(duration: 0.18)) { mode = item }
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == item ? Color.white : Theme.muted)
                        .padding(.horizontal, Theme.Space.md + 2)
                        .padding(.vertical, Theme.Space.sm - 1)
                        .background {
                            if mode == item { Capsule().fill(Theme.accent) }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
                .accessibilityLabel("\(item.title)\(mode == item ? ", selected" : "")")
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    // MARK: - Timer hero (Toggl-style dial)

    private var timerHero: some View {
        // Idle pomo is always an empty ring. Only show elapsed progress while running/paused,
        // so mode switches never flash a full/partial orange arc.
        let progress: CGFloat = {
            guard mode == .pomo, pomoTargetSeconds > 0, isRunning || isPaused else { return 0 }
            return min(max(1 - CGFloat(displaySeconds) / CGFloat(pomoTargetSeconds), 0), 1)
        }()

        return GeometryReader { geo in
            let side = min(geo.size.width - 28, geo.size.height - 8, 340)
            ZStack {
                // Soft fill
                Circle()
                    .fill(Theme.surface.opacity(0.55))
                    .frame(width: side * 0.92, height: side * 0.92)

                // Track
                Circle()
                    .stroke(Theme.gridDivider, lineWidth: 10)
                    .frame(width: side * 0.88, height: side * 0.88)

                // Progress
                if mode == .pomo {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Theme.accent,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: side * 0.88, height: side * 0.88)
                        .rotationEffect(.degrees(-90))
                        .animation(isRunning ? .linear(duration: 0.2) : nil, value: displaySeconds)
                } else if isRunning || isPaused {
                    Circle()
                        .stroke(
                            Theme.cta.opacity(0.85),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: side * 0.88, height: side * 0.88)
                }

                // Tick marks (Toggl dial)
                FocusDialTicks(count: 60, majorEvery: 5)
                    .stroke(Theme.muted.opacity(0.45), lineWidth: 1.2)
                    .frame(width: side * 0.78, height: side * 0.78)

                VStack(spacing: Theme.Space.sm) {
                    Text(mode == .pomo ? "FOCUS" : "ELAPSED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)

                    Button {
                        guard mode == .pomo, !isRunning else { return }
                        pickerMinutes = FocusPreferences.snapMinutes(pomoMinutes)
                        showDurationPicker = true
                    } label: {
                        Text(FocusStore.formatClock(displaySeconds))
                            .font(.system(size: side > 300 ? 64 : 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                    .buttonStyle(.plain)
                    .disabled(mode != .pomo || isRunning)
                    .accessibilityLabel(timerAccessibilityLabel)
                    .accessibilityHint(mode == .pomo && !isRunning ? "Double tap to change duration" : "")

                    Text(statusLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isRunning ? Theme.accent : Theme.muted)

                    if mode == .pomo, !isRunning, !isPaused {
                        Text("Tap time to set")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted.opacity(0.8))
                    } else if mode == .pomo {
                        Text("\(pomoMinutes) min session")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted.opacity(0.8))
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 280)
    }

    private var timerAccessibilityLabel: String {
        if mode == .pomo {
            return "\(pomoMinutes) minute pomodoro, \(FocusStore.formatClock(displaySeconds)) remaining"
        }
        return "Stopwatch, \(FocusStore.formatClock(displaySeconds))"
    }

    // MARK: - Controls (Me+ row: reset · primary · finish)

    private var controls: some View {
        VStack(spacing: Theme.Space.md) {
            HStack(spacing: Theme.Space.lg) {
                secondaryCircleButton(
                    systemImage: "arrow.counterclockwise",
                    label: "Reset",
                    enabled: isRunning || isPaused
                ) { reset() }

                Button {
                    if isRunning { pause() }
                    else if isPaused { resume() }
                    else { start() }
                } label: {
                    Text(primaryTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md + 6)
                        .background(Capsule().fill(isRunning ? Theme.accent : Theme.cta))
                        .shadow(color: (isRunning ? Theme.accent : Theme.cta).opacity(0.35), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(primaryTitle)

                secondaryCircleButton(
                    systemImage: "checkmark",
                    label: "Finish",
                    enabled: isRunning || isPaused,
                    tint: Theme.cta
                ) { finish() }
            }
        }
    }

    private func secondaryCircleButton(
        systemImage: String,
        label: String,
        enabled: Bool,
        tint: Color = Theme.muted,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? tint : Theme.muted.opacity(0.35))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(label)
    }

    private var primaryTitle: String {
        if isRunning { return "Pause" }
        if isPaused { return "Resume" }
        return "Start session"
    }

    // MARK: - Duration picker

    private var durationPickerSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.lg) {
                Text("Session length")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, Theme.Space.lg)

                Picker("Minutes", selection: $pickerMinutes) {
                    ForEach(Array(stride(from: 5, through: 90, by: 5)), id: \.self) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 180)
                .accessibilityLabel("Pomodoro length in minutes")

                Button {
                    setPomoMinutes(pickerMinutes)
                    showDurationPicker = false
                } label: {
                    Text("Set \(pickerMinutes) minutes")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md)
                        .background(Capsule().fill(Theme.cta))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Space.xl)

                Spacer(minLength: 0)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDurationPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func setPomoMinutes(_ mins: Int) {
        let clamped = FocusPreferences.snapMinutes(mins)
        pomoMinutes = clamped
        FocusPreferences.pomoMinutes = clamped
        if !isRunning && !isPaused && mode == .pomo {
            displaySeconds = clamped * 60
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Timer engine

    private func start() {
        startedAt = .now
        isRunning = true
        isPaused = false
        if mode == .pomo {
            displaySeconds = pomoTargetSeconds
        } else {
            displaySeconds = Int(accumulated)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func pause() {
        guard let startedAt else { return }
        accumulated += Date().timeIntervalSince(startedAt)
        self.startedAt = nil
        isRunning = false
        isPaused = true
        refreshDisplay()
    }

    private func resume() {
        startedAt = .now
        isRunning = true
        isPaused = false
    }

    private func finish() {
        let elapsed: Int = {
            if mode == .pomo { return max(0, pomoTargetSeconds - displaySeconds) }
            return displaySeconds
        }()
        let start = startedAt.map { $0.addingTimeInterval(-accumulated) }
            ?? Date().addingTimeInterval(-TimeInterval(elapsed))
        FocusStore.recordCompleted(
            mode: mode,
            startedAt: start,
            endedAt: .now,
            durationSeconds: elapsed,
            label: mode.title,
            in: modelContext
        )
        reset()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func reset() {
        isRunning = false
        isPaused = false
        startedAt = nil
        accumulated = 0
        displaySeconds = mode == .pomo ? pomoTargetSeconds : 0
    }

    private func refreshDisplay() {
        guard isRunning, let startedAt else { return }
        let live = accumulated + Date().timeIntervalSince(startedAt)
        if mode == .pomo {
            let remaining = max(0, pomoTargetSeconds - Int(live))
            displaySeconds = remaining
            if remaining == 0 {
                FocusStore.recordCompleted(
                    mode: .pomo,
                    startedAt: startedAt.addingTimeInterval(-accumulated),
                    endedAt: .now,
                    durationSeconds: pomoTargetSeconds,
                    label: FocusMode.pomo.title,
                    in: modelContext
                )
                reset()
                displaySeconds = pomoTargetSeconds
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } else {
            displaySeconds = Int(live)
        }
    }
}

/// Inner dial tick marks for the focus ring (Toggl-style).
private struct FocusDialTicks: Shape {
    var count: Int = 60
    var majorEvery: Int = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        for i in 0..<count {
            let isMajor = i % majorEvery == 0
            let inner = outer - (isMajor ? 10 : 5)
            let angle = (Double(i) / Double(count)) * 2 * Double.pi - Double.pi / 2
            let cosA = CGFloat(Foundation.cos(angle))
            let sinA = CGFloat(Foundation.sin(angle))
            path.move(to: CGPoint(x: center.x + cosA * inner, y: center.y + sinA * inner))
            path.addLine(to: CGPoint(x: center.x + cosA * outer, y: center.y + sinA * outer))
        }
        return path
    }
}
