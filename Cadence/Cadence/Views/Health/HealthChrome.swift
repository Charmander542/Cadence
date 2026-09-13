import SwiftUI

/// Bevel-inspired chrome in Cadence tokens: rings, energy segments, vital monitor, sleep tracker.
enum HealthChrome {
    static let recovery = Color(red: 0.45, green: 0.92, blue: 0.55)
    static let sleep = Theme.cta
    static let strain = Theme.accent
    static let stressWarm = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let stressCool = Color(red: 0.35, green: 0.85, blue: 0.82)
    static let stageAwake = Color(red: 0.98, green: 0.55, blue: 0.32)
    static let stageREM = Color(red: 0.62, green: 0.72, blue: 0.98)
    static let stageCore = Color(red: 0.32, green: 0.52, blue: 0.92)
    static let stageDeep = Color(red: 0.38, green: 0.32, blue: 0.78)

    static func ratingColor(_ rating: BevelScoring.Rating) -> Color {
        switch rating {
        case .excellent: return Theme.cta
        case .good: return recovery
        case .fair: return stressWarm
        case .poor: return Theme.danger
        case .unknown: return Theme.muted
        }
    }

    static func contributorIcon(_ id: String) -> String {
        switch id {
        case "duration": return "clock.fill"
        case "hrDip": return "heart.fill"
        case "rem": return "cloud.moon.fill"
        case "deep": return "zzz"
        case "efficiency": return "gauge.with.needle.fill"
        case "continuity": return "moon.zzz.fill"
        case "latency": return "hourglass"
        default: return "circle.fill"
        }
    }

    struct ScoreRing: View {
        let title: String
        let score: Double
        let tint: Color
        var selected = false
        var action: (() -> Void)? = nil

        var body: some View {
            Button {
                action?()
            } label: {
                VStack(spacing: Theme.Space.sm) {
                    ZStack {
                        Circle()
                            .stroke(Theme.sunken, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1, max(0, score / 100))))
                            .stroke(
                                AngularGradient(
                                    colors: [tint.opacity(0.55), tint, tint.opacity(0.85)],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.45), value: score)
                        Text("\(Int(score.rounded()))%")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                    .frame(width: 88, height: 88)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Theme.canvas.opacity(0.55))
                    )
                    .overlay {
                        if selected {
                            Circle()
                                .strokeBorder(tint.opacity(0.85), lineWidth: 2)
                                .padding(-4)
                        }
                    }
                    Text(title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) \(Int(score.rounded())) percent")
            .accessibilityHint(action == nil ? "" : "Opens \(title) detail")
            .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        }
    }

    /// Compact ring used in Sleep Score pill / stage cards (Bevel Primary sleep).
    struct MiniRing: View {
        let progress: Double
        let tint: Color
        var size: CGFloat = 28
        var lineWidth: CGFloat = 3.5

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Theme.sunken, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)
        }
    }

    struct EnergyBar: View {
        let percent: Double
        private let segments = 28

        var body: some View {
            let filled = Int((percent / 100) * Double(segments))
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HealthChrome.recovery)
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < filled ? HealthChrome.recovery : Theme.sunken)
                        .frame(height: 18)
                }
                Text("\(Int(percent.rounded()))%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Energy \(Int(percent.rounded())) percent")
        }
    }

    /// Bevel half-gauge for stress average.
    struct StressGauge: View {
        let value: Double
        var label: String

        var body: some View {
            let progress = min(1, max(0, value / 100))
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .trim(from: 0.12, to: 0.88)
                        .stroke(Theme.sunken, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(90))
                    Circle()
                        .trim(from: 0.12, to: 0.12 + 0.76 * progress)
                        .stroke(
                            AngularGradient(
                                colors: [recovery, stressWarm, Color.red.opacity(0.85)],
                                center: .center,
                                startAngle: .degrees(90),
                                endAngle: .degrees(450)
                            ),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                    VStack(spacing: 0) {
                        Text("\(Int(value.rounded()))")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        Text(label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .offset(y: 4)
                }
                .frame(width: 72, height: 72)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Stress \(Int(value.rounded())), \(label)")
        }
    }

    /// Bevel Health Monitor card — value + status pill + vertical range gauge.
    struct MonitorCard: View {
        let vital: HealthVital
        var focused = false
        var onFocus: (() -> Void)? = nil

        var body: some View {
            Button {
                onFocus?()
            } label: {
                HStack(alignment: .center, spacing: Theme.Space.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: vital.systemImage)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                            Text(vital.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                        }
                        Group {
                            if let value = vital.value {
                                (Text(format(value))
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.ink)
                                 + Text(vital.unit.isEmpty ? "" : " \(vital.unit)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted))
                            } else {
                                Text("No data")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        statusPill
                    }
                    Spacer(minLength: 0)
                    rangeGauge
                }
                .padding(Theme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(focused ? Theme.accent.opacity(0.12) : Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vitalAccessibility)
            .accessibilityAddTraits(focused ? [.isSelected, .isButton] : .isButton)
        }

        private var statusTint: Color {
            switch vital.status {
            case .normal: return recovery
            case .lower: return Theme.cta
            case .higher: return stressWarm
            case .noData: return Theme.muted
            }
        }

        private var statusIcon: String {
            switch vital.status {
            case .normal: return "checkmark"
            case .lower: return "arrow.down"
            case .higher: return "arrow.up"
            case .noData: return "minus"
            }
        }

        private var statusPill: some View {
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.system(size: 9, weight: .bold))
                Text(vital.status.title)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(statusTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(statusTint.opacity(0.15)))
        }

        private var rangeGauge: some View {
            GeometryReader { geo in
                let h = geo.size.height
                let pos = vital.value == nil ? 0.5 : min(1, max(0, vital.normalized))
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Theme.sunken)
                    Capsule()
                        .fill(statusTint.opacity(0.45))
                        .frame(height: max(12, h * (vital.bandHigh - vital.bandLow)))
                        .offset(y: -(h * vital.bandLow))
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                        .shadow(color: statusTint.opacity(0.4), radius: 3, y: 1)
                        .offset(y: -(h * pos) + 4.5)
                }
            }
            .frame(width: 10, height: 64)
            .opacity(vital.value == nil ? 0.35 : 1)
        }

        private var vitalAccessibility: String {
            if let value = vital.value {
                return "\(vital.title) \(format(value)) \(vital.unit), \(vital.status.title)"
            }
            return "\(vital.title) unavailable"
        }

        private func format(_ value: Double) -> String {
            if value >= 1000 { return String(format: "%.0f", value) }
            if value == floor(value) { return String(format: "%.0f", value) }
            return String(format: "%.1f", value)
        }
    }

    /// Legacy pillars kept for any callers; prefer MonitorCard.
    struct VitalPillar: View {
        let vital: HealthVital
        var focused = false
        var onFocus: (() -> Void)? = nil

        var body: some View {
            MonitorCard(vital: vital, focused: focused, onFocus: onFocus)
        }
    }

    struct ContributorCell: View {
        let item: BevelScoring.Contributor

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: HealthChrome.contributorIcon(item.id))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 18)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    Text(item.rating.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HealthChrome.ratingColor(item.rating))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.sunken)
                        Capsule()
                            .fill(HealthChrome.ratingColor(item.rating).opacity(item.hasData ? 1 : 0.35))
                            .frame(width: max(4, geo.size.width * CGFloat(min(1, item.score / 100))))
                    }
                }
                .frame(height: 5)
                Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, Theme.Space.sm)
            .padding(.horizontal, Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), \(item.rating.title), \(item.detail)")
        }
    }

    /// Fast / Normal / Late latency track (Bevel Primary sleep).
    struct LatencyScale: View {
        let minutes: Double?

        var body: some View {
            let position: CGFloat = {
                guard let minutes, minutes >= 0 else { return 0.5 }
                // Fast ≤15, Normal ~15–35, Late ≥35 — map onto 0…1
                if minutes <= 15 { return CGFloat(minutes / 15) * 0.28 }
                if minutes <= 35 { return 0.28 + CGFloat((minutes - 15) / 20) * 0.36 }
                return min(1, 0.64 + CGFloat((minutes - 35) / 90) * 0.36)
            }()

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text(minutes.map { "\(Int($0.rounded())) minutes" } ?? "No data")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [recovery, Theme.cta.opacity(0.7), stressWarm],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 6)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                            .offset(x: max(0, min(geo.size.width - 14, geo.size.width * position - 7)))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 18)
                HStack {
                    Text("Fast")
                    Spacer()
                    Text("Normal")
                    Spacer()
                    Text("Late")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(minutes.map { "Time to fall asleep \($0) minutes" } ?? "Time to fall asleep unavailable")
        }
    }

    /// Bevel / Eight Sleep–style stepped hypnogram with scrub tooltip.
    /// Y bands: Awake (top) → REM → Core → Deep (bottom). X = night timeline.
    struct SleepHypnogram: View {
        let asleepHours: Double
        let deepHours: Double
        let remHours: Double
        let coreHours: Double
        let awakeHours: Double
        var segments: [HealthKitClient.SleepStageSegment] = []

        @State private var scrubX: CGFloat?
        @State private var scrubSegment: HealthKitClient.SleepStageSegment?

        private var resolved: [HealthKitClient.SleepStageSegment] {
            let cleaned = segments
                .filter { $0.endEpoch > $0.startEpoch }
                .sorted { $0.startEpoch < $1.startEpoch }
            if cleaned.count >= 2 { return cleaned.map(normalizeStage) }
            return synthesizeTimedSegments()
        }

        private var nightStart: TimeInterval { resolved.first?.startEpoch ?? 0 }
        private var nightEnd: TimeInterval { resolved.last?.endEpoch ?? 1 }
        private var nightSpan: TimeInterval { max(1, nightEnd - nightStart) }

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text("Typical range")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("Duration: \(formatHMS(asleepHours))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }

                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        chartCanvas
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = min(max(0, value.location.x), geo.size.width)
                                        scrubX = x
                                        scrubSegment = segment(at: x, width: geo.size.width)
                                    }
                                    .onEnded { _ in
                                        scrubX = nil
                                        scrubSegment = nil
                                    }
                            )

                        if let scrubSegment, let scrubX {
                            tooltip(for: scrubSegment)
                                .position(x: min(max(72, scrubX), geo.size.width - 72), y: 28)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .frame(height: 168)

                HStack {
                    Label(timeLabel(nightStart), systemImage: "moon.fill")
                    Spacer()
                    Label(timeLabel(nightEnd), systemImage: "sun.max.fill")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)

                HStack(spacing: Theme.Space.md) {
                    legendSwatch(stageAwake, "Awake")
                    legendSwatch(stageREM, "REM")
                    legendSwatch(stageCore, "Core")
                    legendSwatch(stageDeep, "Deep")
                }
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sleep stages overnight chart, \(BevelScoring.formatHours(asleepHours)) asleep. Drag to inspect stages.")
            .accessibilityHint("Drag across the chart to see stage and time")
        }

        private var chartCanvas: some View {
            Canvas { context, size in
                let bandH = size.height / 4
                let padY: CGFloat = 4

                // Horizontal band guides
                for i in 0..<4 {
                    let y = CGFloat(i) * bandH + padY
                    var guide = Path()
                    guide.move(to: CGPoint(x: 0, y: y + bandH - padY * 2))
                    guide.addLine(to: CGPoint(x: size.width, y: y + bandH - padY * 2))
                    context.stroke(guide, with: .color(Theme.gridDivider.opacity(0.55)), lineWidth: 0.5)
                }

                for seg in resolved {
                    let stage = normalizeStage(seg).stage
                    let x0 = CGFloat((seg.startEpoch - nightStart) / nightSpan) * size.width
                    let x1 = CGFloat((seg.endEpoch - nightStart) / nightSpan) * size.width
                    let w = max(1.5, x1 - x0)
                    let band = CGFloat(yIndex(for: stage))
                    let barH = bandH - padY * 2
                    let y = band * bandH + padY
                    let rect = CGRect(x: x0, y: y, width: w, height: barH)
                    let path = Path(roundedRect: rect, cornerRadius: min(3, w / 2))
                    context.fill(path, with: .color(color(for: stage)))
                }

                if let scrubX {
                    var line = Path()
                    line.move(to: CGPoint(x: scrubX, y: 0))
                    line.addLine(to: CGPoint(x: scrubX, y: size.height))
                    context.stroke(line, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.sunken.opacity(0.45))
            )
        }

        private func segment(at x: CGFloat, width: CGFloat) -> HealthKitClient.SleepStageSegment? {
            let w = max(width, 1)
            let t = nightStart + Double(min(max(0, x), w) / w) * nightSpan
            return resolved.first { t >= $0.startEpoch && t <= $0.endEpoch } ?? resolved.min(by: {
                abs(($0.startEpoch + $0.endEpoch) / 2 - t) < abs(($1.startEpoch + $1.endEpoch) / 2 - t)
            })
        }

        private func tooltip(for seg: HealthKitClient.SleepStageSegment) -> some View {
            let stage = normalizeStage(seg).stage
            return HStack(spacing: 8) {
                Circle()
                    .fill(color(for: stage))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(stageName(stage))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("\(timeLabel(seg.startEpoch)) – \(timeLabel(seg.endEpoch))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }

        private func legendSwatch(_ color: Color, _ title: String) -> some View {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
            }
        }

        private func color(for stage: Int) -> Color {
            switch stage {
            case 0: return stageAwake
            case 1: return stageREM
            case 2: return stageCore
            default: return stageDeep
            }
        }

        private func stageName(_ stage: Int) -> String {
            switch stage {
            case 0: return "Awake"
            case 1: return "REM"
            case 2: return "Core"
            case 3: return "Deep"
            default: return "Asleep"
            }
        }

        /// Bevel Y order: Awake top (0), REM (1), Core (2), Deep bottom (3).
        private func yIndex(for stage: Int) -> Int {
            switch stage {
            case 0: return 0
            case 1: return 1
            case 2: return 2
            default: return 3
            }
        }

        private func normalizeStage(_ seg: HealthKitClient.SleepStageSegment) -> HealthKitClient.SleepStageSegment {
            var copy = seg
            if copy.stage == 4 { copy.stage = 2 }
            return copy
        }

        private func timeLabel(_ epoch: TimeInterval) -> String {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: Date(timeIntervalSince1970: epoch))
        }

        private func formatHMS(_ hours: Double) -> String {
            let total = max(0, Int((hours * 3600).rounded()))
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            return String(format: "%02d:%02d:%02d", h, m, s)
        }

        private func synthesizeTimedSegments() -> [HealthKitClient.SleepStageSegment] {
            let deep = max(0, deepHours)
            let rem = max(0, remHours)
            let core = max(0, coreHours > 0.05 ? coreHours : max(0, asleepHours - deep - rem))
            let awake = max(0.05, awakeHours)
            let pattern: [(Int, Double)] = [
                (2, core * 0.22), (3, deep * 0.45), (2, core * 0.18), (1, rem * 0.35),
                (0, awake * 0.35), (2, core * 0.2), (3, deep * 0.55), (1, rem * 0.4),
                (0, awake * 0.3), (2, core * 0.2), (1, rem * 0.25), (2, core * 0.2),
                (0, awake * 0.35),
            ]
            let cal = Calendar.current
            let wake = cal.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
            let totalH = pattern.reduce(0.0) { $0 + $1.1 }
            var cursor = wake.addingTimeInterval(-totalH * 3600).timeIntervalSince1970
            return pattern.compactMap { stage, hours in
                guard hours > 0.01 else { return nil }
                let end = cursor + hours * 3600
                defer { cursor = end }
                return HealthKitClient.SleepStageSegment(stage: stage, startEpoch: cursor, endEpoch: end)
            }
        }
    }

    struct StageRingCard: View {
        let title: String
        let hours: Double
        let percent: Double
        let tint: Color

        var body: some View {
            Theme.Card {
                HStack(spacing: Theme.Space.md) {
                    MiniRing(progress: percent / 100, tint: tint, size: 36, lineWidth: 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text(formatHMS(hours))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        Text(String(format: "%.0f%%", percent))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) \(BevelScoring.formatHours(hours)), \(Int(percent.rounded())) percent")
        }

        private func formatHMS(_ hours: Double) -> String {
            let total = max(0, Int((hours * 3600).rounded()))
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        }
    }

    struct MiniTrend: View {
        let values: [Double]
        let tint: Color

        var body: some View {
            GeometryReader { geo in
                let pts = points(in: geo.size)
                ZStack {
                    Path { path in
                        guard let first = pts.first else { return }
                        path.move(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    if let last = pts.last {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: tint.opacity(0.6), radius: 4)
                            .position(last)
                    }
                }
            }
            .accessibilityHidden(true)
        }

        private func points(in size: CGSize) -> [CGPoint] {
            guard values.count > 1 else { return [] }
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(maxV - minV, 1)
            return values.enumerated().map { i, v in
                let x = CGFloat(i) / CGFloat(values.count - 1) * size.width
                let y = (1 - CGFloat((v - minV) / span)) * size.height
                return CGPoint(x: x, y: y)
            }
        }
    }

    struct Sparkline: View {
        let samples: [HealthHeartSample]
        @Binding var scrubIndex: Int?

        var body: some View {
            GeometryReader { geo in
                let pts = points(in: geo.size)
                ZStack {
                    Path { path in
                        guard let first = pts.first else { return }
                        path.move(to: first)
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(Theme.cta, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if let scrubIndex, samples.indices.contains(scrubIndex), scrubIndex < pts.count {
                        let p = pts[scrubIndex]
                        Path { path in
                            path.move(to: CGPoint(x: p.x, y: 0))
                            path.addLine(to: CGPoint(x: p.x, y: geo.size.height))
                        }
                        .stroke(Theme.accent.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 10, height: 10)
                            .position(p)
                            .shadow(color: Theme.accent.opacity(0.5), radius: 6)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !samples.isEmpty else { return }
                            let x = min(max(0, value.location.x), geo.size.width)
                            let idx = Int((x / max(geo.size.width, 1)) * CGFloat(samples.count - 1))
                            scrubIndex = idx
                        }
                        .onEnded { _ in
                            // Keep last scrub so the readout stays playful.
                        }
                )
            }
            .accessibilityLabel("Heart rate trend")
            .accessibilityHint("Drag to scrub through the day")
        }

        private func points(in size: CGSize) -> [CGPoint] {
            guard samples.count > 1 else { return [] }
            let minV = samples.map(\.bpm).min() ?? 0
            let maxV = samples.map(\.bpm).max() ?? 1
            let span = max(maxV - minV, 1)
            return samples.enumerated().map { i, sample in
                let x = CGFloat(i) / CGFloat(samples.count - 1) * size.width
                let y = (1 - CGFloat((sample.bpm - minV) / span)) * size.height
                return CGPoint(x: x, y: y)
            }
        }
    }
}
