import SwiftUI
import UIKit

/// Shared design language — dark-first chrome with system appearance support.
enum Theme {
    // MARK: - Color

    static let accent = Color.accentColor
    static var ink: Color { adaptive(light: .label, dark: .white) }
    static var muted: Color {
        adaptive(
            light: .secondaryLabel,
            dark: UIColor.white.withAlphaComponent(0.55)
        )
    }
    static let danger = Color(red: 1, green: 0.32, blue: 0.32)

    static var canvas: Color { adaptive(light: .systemGroupedBackground, dark: .black) }
    static var surface: Color {
        adaptive(
            light: .secondarySystemGroupedBackground,
            dark: UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1)
        )
    }
    static var sunken: Color {
        adaptive(
            light: .tertiarySystemGroupedBackground,
            dark: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
        )
    }
    /// Calendar grid lines and subtle separators — visible in light and dark mode.
    static var gridDivider: Color {
        adaptive(
            light: UIColor.separator.withAlphaComponent(0.55),
            dark: UIColor.white.withAlphaComponent(0.06)
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
        LinearGradient(
            colors: [
                accent.opacity(0.28),
                accent.opacity(0.08),
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
        static let xl: CGFloat = 22
        static let pill: CGFloat = 999
    }

    // MARK: - Surfaces

    struct Card<Content: View>: View {
        var padding: CGFloat = Space.lg
        var radius: CGFloat = Radius.lg
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    struct HeroPanel<Content: View>: View {
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(heroGradient, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
    }

    struct Pill: View {
        let text: String
        var emphasized = false

        var body: some View {
            Text(text.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    emphasized ? accent.opacity(0.18) : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(emphasized ? accent : muted)
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
                    Text(busy ? "Working…" : title)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    struct FieldChrome<Content: View>: View {
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm + 2)
                .background(sunken, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
    }

    struct CheckGlyph: View {
        var checked: Bool

        var body: some View {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(checked ? accent : muted)
                .symbolRenderingMode(.hierarchical)
        }
    }

    struct EmptyState: View {
        let systemImage: String
        let title: String
        let message: String
        var cta: String? = nil
        var ctaHint: String? = nil
        var busy = false
        var action: (() -> Void)? = nil

        var body: some View {
            VStack(spacing: Space.lg) {
                Spacer(minLength: Space.xxl)
                Image(systemName: systemImage)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(Theme.title(.title3))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xxl)
                    .accessibilityAddTraits(.isStaticText)
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
                    ProgressView()
                        .controlSize(.large)
                        .tint(accent)
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
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(detail.map { "\(title). \($0)" } ?? title)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    struct SectionHeader: View {
        let title: String
        var subtitle: String? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.title(.headline))
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.body(.caption))
                        .foregroundStyle(muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(subtitle.map { "\(title). \($0)" } ?? title)
        }
    }

    struct DayChip: View {
        let label: String
        var selected: Bool
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                    Circle()
                        .fill(selected ? accent : sunken)
                        .frame(width: 6, height: 6)
                }
                .foregroundStyle(selected ? accent : ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selected ? accent.opacity(0.14) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "\(label), selected" : label)
            .accessibilityHint(selected ? "Currently showing meals for this day" : "Shows meal plan for this day")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
                                Theme.accent.opacity(0.2 - Double(ring) * 0.04),
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
                        .foregroundStyle(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }
                .frame(height: 180)

                VStack(spacing: Theme.Space.sm) {
                    Text("Planning your week")
                        .font(Theme.title(.title2))
                    TimelineView(.periodic(from: .now, by: 1.5)) { context in
                        let idx = Int(context.date.timeIntervalSinceReferenceDate / 1.5)
                            % max(flavorLines.count, 1)
                        VStack(spacing: 6) {
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
