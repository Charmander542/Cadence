import SwiftUI

/// Bevel-inspired chrome in Cadence tokens: rings, energy segments, vital pillars, sparklines.
enum HealthChrome {
    static let recovery = Color(red: 0.45, green: 0.92, blue: 0.55)
    static let sleep = Theme.cta
    static let strain = Theme.accent
    static let stressWarm = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let stressCool = Color(red: 0.35, green: 0.85, blue: 0.82)

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

    struct VitalPillar: View {
        let vital: HealthVital
        var focused = false
        var onFocus: (() -> Void)? = nil

        var body: some View {
            Button {
                onFocus?()
            } label: {
                VStack(spacing: Theme.Space.sm) {
                    Image(systemName: vital.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(focused ? Theme.accent : Theme.muted)
                    GeometryReader { geo in
                        let h = geo.size.height
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Theme.sunken)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.cta.opacity(0.35), Theme.accent],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: max(10, h * vital.normalized))
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .shadow(color: Theme.accent.opacity(0.45), radius: 4, y: 1)
                                .offset(y: -(h * vital.normalized) + 5)
                        }
                    }
                    .frame(width: 22, height: 88)
                    VStack(spacing: 2) {
                        Text(vital.value.map { format($0) } ?? "—")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(vital.unit.isEmpty ? vital.title : vital.unit)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, Theme.Space.sm)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(focused ? Theme.accent.opacity(0.12) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(vitalAccessibility)
            .accessibilityAddTraits(focused ? [.isSelected, .isButton] : .isButton)
        }

        private var vitalAccessibility: String {
            if let value = vital.value {
                return "\(vital.title) \(format(value)) \(vital.unit)"
            }
            return "\(vital.title) unavailable"
        }

        private func format(_ value: Double) -> String {
            if value >= 1000 { return String(format: "%.0f", value) }
            if value == floor(value) { return String(format: "%.0f", value) }
            return String(format: "%.1f", value)
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
