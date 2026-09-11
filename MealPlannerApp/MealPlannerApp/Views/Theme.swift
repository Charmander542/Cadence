import SwiftUI
import UIKit

/// Shared design language — dark-first chrome with system appearance support.
/// Visual system refined from polished production apps (dark fitness + task + meal patterns):
/// pure canvas, elevated charcoal cards with hairlines, orange for place, blue for action.
enum Theme {
    // MARK: - Color
    //
    // Orange (`accent`) — navigation & context: selected tab, today badges, selection chips.
    // Blue (`cta`) — do something: FAB, Begin/Save, primary CTAs, tappable links.

    /// Orange — where you are (tab bar, today circle, drawer selection).
    /// Use the AccentColor asset explicitly — `Color.accentColor` tracks the view
    /// tint (often CTA blue), which collapses nav vs action semantics.
    static let accent = Color("AccentColor")
    /// Blue — primary call-to-action buttons and links.
    static let cta = Color("ActionColor")
    static var ink: Color { adaptive(light: .label, dark: .white) }
    static var muted: Color {
        adaptive(
            light: .secondaryLabel,
            dark: UIColor.white.withAlphaComponent(0.52)
        )
    }
    static let danger = Color(red: 1, green: 0.32, blue: 0.32)

    static var canvas: Color { adaptive(light: .systemGroupedBackground, dark: .black) }
    static var surface: Color {
        adaptive(
            light: .secondarySystemGroupedBackground,
            dark: UIColor(red: 0.125, green: 0.125, blue: 0.13, alpha: 1)
        )
    }
    static var sunken: Color {
        adaptive(
            light: .tertiarySystemGroupedBackground,
            dark: UIColor(red: 0.17, green: 0.17, blue: 0.175, alpha: 1)
        )
    }
    /// Calendar grid lines and subtle separators — visible in light and dark mode.
    static var gridDivider: Color {
        adaptive(
            light: UIColor.separator.withAlphaComponent(0.55),
            dark: UIColor.white.withAlphaComponent(0.07)
        )
    }
    /// Soft card rim — reads as elevation without heavy shadows.
    static var hairline: Color {
        adaptive(
            light: UIColor.separator.withAlphaComponent(0.35),
            dark: UIColor.white.withAlphaComponent(0.09)
        )
    }
    static var cardShadow: Color {
        adaptive(
            light: UIColor.black.withAlphaComponent(0.08),
            dark: UIColor.black.withAlphaComponent(0.45)
        )
    }
    static let flagHigh = Color(red: 0.95, green: 0.28, blue: 0.32)
    static let flagMedium = Color(red: 0.98, green: 0.78, blue: 0.18)
    static let flagLow = Color(red: 0.35, green: 0.55, blue: 0.98)
    static var flagNone: Color {
        adaptive(light: .tertiaryLabel, dark: UIColor.white.withAlphaComponent(0.35))
    }
    static let matrixI = Color(red: 1, green: 0.45, blue: 0.72)
    static let matrixII = Color(red: 0.95, green: 0.75, blue: 0.2)
    static let matrixIII = Color(red: 0.4, green: 0.55, blue: 0.98)
    static let matrixIV = Color(red: 0.35, green: 0.82, blue: 0.55)

    static var heroGradient: LinearGradient {
        heroGradient(tint: cta)
    }

    static func heroGradient(tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(0.28),
                tint.opacity(0.08),
                surface,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Human-friendly recipe title (title-cases ALL CAPS cookbook names).
    static func recipeDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return name }
        let letters = trimmed.filter(\.isLetter)
        if !letters.isEmpty, letters.allSatisfy({ $0.isUppercase }) {
            return trimmed.localizedCapitalized
        }
        return trimmed
    }

    // MARK: - Type (rounded display + readable body)

    static func display(_ style: Font.TextStyle = .largeTitle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    static func title(_ style: Font.TextStyle = .title2, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    static func body(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    static func mono(_ style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }

    // MARK: - Space & radius

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Surfaces

    struct Card<Content: View>: View {
        var padding: CGFloat = Space.lg
        var radius: CGFloat = Radius.lg
        var elevated = true
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(hairline, lineWidth: 1)
                )
                .shadow(color: elevated ? cardShadow : .clear, radius: elevated ? 10 : 0, y: elevated ? 4 : 0)
        }
    }

    struct HeroPanel<Content: View>: View {
        var tint: Color = cta
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(heroGradient(tint: tint), in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.18), radius: 16, y: 6)
        }
    }

    struct Pill: View {
        let text: String
        var emphasized = false
        var tint: Color? = nil

        private var fill: Color {
            if let tint { return tint.opacity(0.16) }
            return emphasized ? accent.opacity(0.18) : Color.secondary.opacity(0.12)
        }

        private var foreground: Color {
            if let tint { return tint }
            return emphasized ? accent : muted
        }

        var body: some View {
            Text(text.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .padding(.horizontal, Space.sm + 2)
                .padding(.vertical, Space.xs + 1)
                .background(fill, in: Capsule())
                .foregroundStyle(foreground)
        }
    }

    /// Compact metadata chip under task / recipe titles (Todoist / Attio pattern).
    struct MetaPill: View {
        let text: String
        var tone: MetaTone = .neutral

        enum MetaTone {
            case neutral, accent, danger, cta
        }

        private var colors: (fg: Color, bg: Color) {
            switch tone {
            case .neutral: return (Theme.muted, Theme.sunken)
            case .accent: return (Theme.accent, Theme.accent.opacity(0.14))
            case .danger: return (Theme.danger, Theme.danger.opacity(0.14))
            case .cta: return (Theme.cta, Theme.cta.opacity(0.14))
            }
        }

        var body: some View {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(colors.fg)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs)
                .background(colors.bg, in: Capsule())
        }
    }

    struct CountBadge: View {
        let count: Int
        var emphasized = false

        var body: some View {
            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(emphasized ? Theme.accent : Theme.muted)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs - 1)
                .background(
                    (emphasized ? Theme.accent.opacity(0.16) : Theme.sunken),
                    in: Capsule()
                )
        }
    }

    /// Tinted glyph well for settings / empty-state iconography (Tonal / Letterboxd).
    struct IconWell: View {
        let systemImage: String
        var tint: Color = accent
        var size: CGFloat = 36

        var body: some View {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        }
    }

    struct ProgressTrack: View {
        var progress: Double
        var tint: Color = cta
        var height: CGFloat = 4

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(sunken)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Controls

    struct PrimaryButton: View {
        let title: String
        var systemImage: String? = nil
        var busy = false
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: Space.sm) {
                    if busy {
                        ProgressView()
                            .tint(.white)
                    } else if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(busy ? "WORKING…" : title)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md + 3)
                .foregroundStyle(.white)
                .background(Theme.cta, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .shadow(color: Theme.cta.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }

    struct SecondaryButton: View {
        let title: String
        var systemImage: String? = nil
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: Space.sm) {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md + 1)
                .foregroundStyle(Theme.ink)
                .background(sunken, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    struct FieldChrome<Content: View>: View {
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm + 2)
                .background(sunken, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(hairline, lineWidth: 1)
                )
        }
    }

    struct CheckGlyph: View {
        var checked: Bool

        var body: some View {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(checked ? Theme.cta : muted)
                .symbolRenderingMode(.hierarchical)
        }
    }

    struct EmptyState: View {
        let systemImage: String
        let title: String
        let message: String
        var meta: [String] = []
        var cta: String? = nil
        var ctaHint: String? = nil
        var busy = false
        var action: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: Space.lg) {
                Spacer(minLength: Space.xxl)
                IconWell(systemImage: systemImage, tint: Theme.cta, size: 64)
                Text(title)
                    .font(Theme.title(.title3))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xxl)
                    .accessibilityAddTraits(.isStaticText)
                if !meta.isEmpty {
                    HStack(spacing: Space.sm) {
                        ForEach(meta, id: \.self) { item in
                            MetaPill(text: item, tone: .cta)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(meta.joined(separator: ", "))
                }
                if let cta, let action {
                    Group {
                        if let ctaHint {
                            PrimaryButton(title: cta, busy: busy, action: action)
                                .accessibilityHint(ctaHint)
                        } else {
                            PrimaryButton(title: cta, busy: busy, action: action)
                        }
                    }
                    .padding(.horizontal, Space.xxl)
                    .padding(.top, Space.sm)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct BusyOverlay: View {
        let title: String
        var detail: String? = nil

        var body: some View {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                VStack(spacing: Space.md) {
                    Text("WORKING")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(muted)
                    ProgressView()
                        .controlSize(.large)
                        .tint(cta)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isStaticText)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(muted)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                .padding(Space.xl)
                .background(surface.opacity(0.92), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(hairline, lineWidth: 1)
                )
                .shadow(color: cardShadow, radius: 12, y: 4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(detail.map { "\(title). \($0)" } ?? title)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    struct SectionHeader: View {
        let title: String
        var subtitle: String? = nil
        var count: Int? = nil

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.body(.caption))
                            .foregroundStyle(muted)
                    }
                }
                if let count {
                    CountBadge(count: count)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel({
                var parts = [title]
                if let subtitle { parts.append(subtitle) }
                if let count { parts.append("\(count) items") }
                return parts.joined(separator: ". ")
            }())
        }
    }

    /// Day picker chip — filled capsule when selected (meal week strip).
    struct DayChip: View {
        let label: String
        var selected: Bool
        var isToday: Bool = false
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.subheadline.weight(selected ? .bold : .semibold))
                    .tracking(0.3)
                    .foregroundStyle(selected ? Color.white : (isToday ? Theme.accent : ink))
                    .frame(minWidth: 44)
                    .padding(.vertical, Space.sm + 2)
                    .background(
                        Capsule().fill(selected ? Theme.accent : (isToday ? Theme.accent.opacity(0.12) : sunken))
                    )
                    .overlay {
                        if selected {
                            Capsule().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
                        } else if isToday {
                            Capsule().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1.2)
                        } else {
                            Capsule().strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: selected ? Theme.accent.opacity(0.28) : .clear,
                        radius: 6,
                        y: 2
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "\(label), selected" : label)
            .accessibilityHint(selected ? "Currently showing meals for this day" : "Shows meal plan for this day")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// Week-strip day cell with weekday + number + selection circle (Habits / Lift / Runna pattern).
    struct SoftDayCell: View {
        let weekday: String
        let dayNumber: String
        var selected: Bool
        var isToday: Bool = false
        var badge: String? = nil
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: Space.xs + 1) {
                    Text(weekday)
                        .font(.caption2.weight(.bold))
                        .tracking(0.4)
                        .foregroundStyle(selected || isToday ? Theme.accent : muted)
                    Text(dayNumber)
                        .font(.subheadline.weight(selected ? .bold : .semibold))
                        .foregroundStyle(selected ? Color.white : ink)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(selected ? Theme.accent : (isToday ? Theme.accent.opacity(0.14) : Color.clear))
                        )
                        .overlay {
                            if selected {
                                // Orange nav fill — distinct from CTA blue actions nearby.
                                Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                            } else if isToday {
                                Circle().strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1.5)
                            }
                        }
                        .shadow(
                            color: selected ? Theme.accent.opacity(0.35) : .clear,
                            radius: 5,
                            y: 1
                        )
                    if let badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    } else {
                        Color.clear.frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Plan generating (coach voice)

struct PlanGeneratingOverlay: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var pulse = false

    private let flavorLines = [
        "Picking protein-forward dinners…",
        "Pairing sides that actually belong…",
        "Keeping tonight different from last night…",
        "Building a shop list you’d hand to someone…",
        "Leaving pantry staples off the list…",
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Color.primary.opacity(0.1)
                .ignoresSafeArea()

            VStack(spacing: Theme.Space.xxl) {
                ZStack {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(
                                Theme.cta.opacity(0.22 - Double(ring) * 0.05),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: 92 + CGFloat(ring) * 30,
                                height: 92 + CGFloat(ring) * 30
                            )
                            .scaleEffect(pulse ? 1.06 : 0.94)
                            .animation(
                                .easeInOut(duration: 1.35)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(ring) * 0.18),
                                value: pulse
                            )
                    }
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.cta)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }
                .frame(height: 180)

                VStack(spacing: Theme.Space.sm) {
                    Text("BUILDING WEEK")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                    Text("Planning your week")
                        .font(Theme.title(.title2))
                    TimelineView(.periodic(from: .now, by: 1.5)) { context in
                        let idx = Int(context.date.timeIntervalSinceReferenceDate / 1.5)
                            % max(flavorLines.count, 1)
                        VStack(spacing: Theme.Space.sm - 2) {
                            Text(appModel.generatingStatus)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.muted)
                            Text(flavorLines[idx])
                                .font(.footnote)
                                .foregroundStyle(Theme.muted.opacity(0.75))
                                .id(idx)
                                .accessibilityAddTraits(.isStaticText)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(height: 44)
                    .padding(.horizontal, Theme.Space.xxl)

                    Button("Continue in background") {
                        appModel.minimizePlanGeneratingOverlay()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, Theme.Space.sm)
                    .accessibilityHint("Hides overlay while plan generation continues")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Planning your week. \(appModel.generatingStatus)")
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear { pulse = true }
    }
}

struct IngredientRefreshOverlay: View {
    var body: some View {
        Theme.BusyOverlay(title: "Refreshing shop list", detail: "Updating ingredients…")
    }
}
