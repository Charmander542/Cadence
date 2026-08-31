import SwiftUI
import UIKit

// MARK: - Focus model

enum WorkoutEditorField: Equatable {
    case weight(exerciseID: String, setID: Int)
    case reps(exerciseID: String, setID: Int)
    case duration(exerciseID: String, setID: Int)
}

enum WorkoutKeypadMode {
    case weight
    case reps
    case duration
}

// MARK: - Keypad panel

struct WorkoutKeypadEditor: View {
    @Binding var draft: String
    var field: WorkoutEditorField
    var rir: Int
    var onRIR: (Int) -> Void
    var onConfirm: () -> Void
    var onDismiss: () -> Void

    @State private var failureMode = true

    private var mode: WorkoutKeypadMode {
        switch field {
        case .weight: return .weight
        case .reps: return .reps
        case .duration: return .duration
        }
    }

    var body: some View {
        keypad
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.ignoresSafeArea(edges: .bottom))
    }

    private var parsedDouble: Double {
        Double(draft) ?? 0
    }

    private var rirBarInline: some View {
        HStack(spacing: 8) {
            ForEach([0, 1, 2, 3, 4], id: \.self) { value in
                rirChip(value, color: RIRPalette.color(for: value), compact: true)
            }
            rirChip(5, label: "5+", color: RIRPalette.color(for: 5), compact: true, capsAtOrAbove: true)
            rirChip(-1, label: "?", color: Color(white: 0.22), compact: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .padding(.horizontal, 6)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rirChip(
        _ value: Int,
        label: String? = nil,
        color: Color,
        compact: Bool = false,
        capsAtOrAbove: Bool = false
    ) -> some View {
        let selected = rir == value || (capsAtOrAbove && rir >= value)
        let display = label ?? "\(value)"
        let size: CGFloat = compact ? 32 : 38
        return Button {
            onRIR(value == -1 ? rir : value)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(display)
                .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color, in: Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: selected ? 2.5 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rirAccessibilityLabel(value: value, display: display, capsAtOrAbove: capsAtOrAbove, selected: selected))
        .accessibilityHint("Sets reps in reserve for this set")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func rirAccessibilityLabel(
        value: Int,
        display: String,
        capsAtOrAbove: Bool,
        selected: Bool
    ) -> String {
        let base: String
        if value == -1 {
            base = "Unknown RIR"
        } else if capsAtOrAbove {
            base = "RIR \(display) or more"
        } else {
            base = "RIR \(display)"
        }
        return selected ? "\(base), selected" : base
    }

    private var keypad: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 6) {
                if mode == .weight {
                    PlateCalculatorInline(weightLb: parsedDouble)
                        .frame(height: 54)
                } else if mode == .reps {
                    rirBarInline
                } else {
                    Color.clear.frame(height: 54)
                }
                numRow(["1", "2", "3"])
                numRow(["4", "5", "6"])
                numRow(["7", "8", "9"])
                HStack(spacing: 6) {
                    if mode == .weight {
                        numKey(".")
                    } else if mode == .reps {
                        fpToggle
                    } else {
                        Color.clear.frame(maxWidth: .infinity).frame(height: 54)
                    }
                    numKey("0")
                    Button(action: backspace) {
                        Image(systemName: "delete.left")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete")
                    .accessibilityHint("Removes the last digit")
                }
            }

            VStack(spacing: 6) {
                actionKey(systemImage: "keyboard.chevron.compact.down", accessibilityLabel: "Hide keypad", accessibilityHint: "Closes keypad without saving", action: onDismiss)
                actionKey(systemImage: "minus", accessibilityLabel: "Decrease", accessibilityHint: nudgeHint) { nudge(-1) }
                actionKey(systemImage: "plus", accessibilityLabel: "Increase", accessibilityHint: nudgeHint) { nudge(1) }
                confirmButton
            }
            .frame(width: 76)
        }
    }

    private func numRow(_ keys: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { numKey($0) }
        }
    }

    private func numKey(_ title: String) -> some View {
        Button { append(title) } label: {
            Text(title)
                .font(.title.weight(.regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(title == "." && draft.contains("."))
        .opacity(title == "." && draft.contains(".") ? 0.35 : 1)
        .accessibilityLabel(numKeyAccessibilityLabel(title))
        .accessibilityHint(numKeyHint(title))
    }

    private func numKeyHint(_ title: String) -> String {
        switch mode {
        case .weight:
            return title == "." ? "Adds decimal to weight entry" : "Adds \(title) to weight entry"
        case .reps:
            return "Adds \(title) to rep count"
        case .duration:
            return "Adds \(title) to duration in seconds"
        }
    }

    private func numKeyAccessibilityLabel(_ title: String) -> String {
        switch title {
        case ".": return "Decimal point"
        default: return "Digit \(title)"
        }
    }

    private var nudgeHint: String {
        mode == .weight ? "Adjusts weight by 5 pounds" : "Adjusts value by 1"
    }

    private func actionKey(
        systemImage: String? = nil,
        label: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            Group {
                if let label {
                    Text(label).font(.caption.weight(.bold))
                } else if let systemImage {
                    Image(systemName: systemImage).font(.body.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label ?? systemImage ?? "Action")
        .accessibilityHint(accessibilityHint ?? "")
    }

    private var fpToggle: some View {
        HStack(spacing: 0) {
            Button { failureMode = true } label: {
                Text("F")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(failureMode ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(failureMode ? Color.white : Color(white: 0.14))
            }
            .accessibilityLabel(failureMode ? "Failure set, selected" : "Failure set")
            .accessibilityHint("Marks set as taken to failure")
            .accessibilityAddTraits(failureMode ? [.isButton, .isSelected] : .isButton)
            Button { failureMode = false } label: {
                Text("P")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(!failureMode ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(!failureMode ? Color.white : Color(white: 0.14))
            }
            .accessibilityLabel(!failureMode ? "Partial reps, selected" : "Partial reps")
            .accessibilityHint("Marks set as partial reps")
            .accessibilityAddTraits(!failureMode ? [.isButton, .isSelected] : .isButton)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .buttonStyle(.plain)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Image(systemName: "arrow.right")
                .font(.title2.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 114)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Confirm")
        .accessibilityHint("Applies entered value to set")
    }

    private func append(_ key: String) {
        if key == "." && draft.contains(".") { return }
        if draft == "0" && key != "." { draft = key } else { draft += key }
    }

    private func backspace() {
        if draft.count <= 1 {
            draft = "0"
        } else {
            draft.removeLast()
        }
    }

    private func nudge(_ delta: Int) {
        if mode == .weight {
            let step = delta > 0 ? 5.0 : -5.0
            draft = formatWeight(max(0, parsedDouble + step))
        } else {
            let base = Int(draft) ?? 0
            draft = "\(max(0, base + delta))"
        }
    }

    private func formatWeight(_ w: Double) -> String {
        if abs(w - w.rounded()) < 0.05 { return "\(Int(w.rounded()))" }
        return String(format: "%.1f", w)
    }
}

enum RIRPalette {
    static func color(for value: Int) -> Color {
        switch value {
        case 0, 1: return Color(red: 0.90, green: 0.20, blue: 0.20)
        case 2: return Color(red: 0.95, green: 0.55, blue: 0.12)
        case 3: return Color(red: 0.98, green: 0.78, blue: 0.15)
        case 4: return Color(red: 0.25, green: 0.70, blue: 0.38)
        case 5: return Color(red: 0.30, green: 0.50, blue: 0.95)
        default: return Color(red: 0.30, green: 0.50, blue: 0.95)
        }
    }
}

// MARK: - Plate calculator (inline — left side, above row 1)

struct PlateCalculatorInline: View {
    var weightLb: Double

    private struct PlateSpec: Identifiable {
        let id: Int
        var weight: Double
        var color: Color
        var width: CGFloat
        var height: CGFloat
    }

    private var barMode: Bool { weightLb > 45 }

    private var platesPerSide: [PlateSpec] {
        if barMode {
            return buildPlates(perSide: (weightLb - 45) / 2)
        }
        return buildPlates(perSide: max(0, (weightLb - 5) / 2))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leftSideBarbell(plates: platesPerSide)
                .frame(width: 96, height: 54, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                if !platesPerSide.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(groupedLegend(platesPerSide), id: \.label) { item in
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                Text(item.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color(white: 0.55))
                            }
                        }
                    }
                }
                Text(summaryText)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color(white: 0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryText)
        .accessibilityHint("Plate loading for entered weight")
    }

    private var summaryText: String {
        if barMode {
            let perSide = (weightLb - 45) / 2
            return "\(format(perSide)) lb/side + 45 bar = \(format(weightLb)) lb"
        }
        if weightLb <= 0 { return "Enter weight" }
        return "\(format(weightLb)) lb per dumbbell"
    }

    /// Plates on the right of the collar, whole assembly left-aligned and vertically centered.
    private func leftSideBarbell(plates: [PlateSpec]) -> some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                if plates.isEmpty {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(white: 0.28), lineWidth: 1)
                        .frame(width: 5, height: 24)
                } else {
                    ForEach(plates) { plate in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(plate.color)
                            .frame(width: plate.width, height: plate.height)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                }
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.40))
                .frame(width: barMode ? 48 : 28, height: 8)
        }
    }

    private func buildPlates(perSide: Double) -> [PlateSpec] {
        var remaining = max(0, perSide)
        let standard: [(Double, Color, CGFloat, CGFloat)] = [
            (45, Color(red: 0.18, green: 0.42, blue: 0.88), 13, 46),
            (35, Color(red: 0.95, green: 0.55, blue: 0.12), 12, 42),
            (25, Color(red: 0.20, green: 0.68, blue: 0.32), 11, 38),
            (10, Color(white: 0.90), 9, 32),
            (5, Color(white: 0.52), 8, 26),
            (2.5, Color(red: 0.22, green: 0.72, blue: 0.38), 7, 22),
        ]
        var result: [PlateSpec] = []
        var idx = 0
        for (w, color, width, height) in standard {
            while remaining >= w - 0.01 {
                result.append(PlateSpec(id: idx, weight: w, color: color, width: width, height: height))
                idx += 1
                remaining -= w
            }
        }
        return result
    }

    private struct LegendItem {
        var label: String
        var color: Color
    }

    private func groupedLegend(_ plates: [PlateSpec]) -> [LegendItem] {
        var counts: [Double: (Int, Color)] = [:]
        for p in plates {
            let cur = counts[p.weight]?.0 ?? 0
            counts[p.weight] = (cur + 1, p.color)
        }
        return counts.keys.sorted(by: >).map { w in
            LegendItem(label: "\(counts[w]!.0)×\(format(w))", color: counts[w]!.1)
        }
    }

    private func format(_ w: Double) -> String {
        if abs(w - w.rounded()) < 0.05 { return "\(Int(w.rounded()))" }
        return String(format: "%.1f", w)
    }
}

struct WorkoutEditableField: View {
    var text: String
    var focused: Bool
    var width: CGFloat = 76
    var rir: Int?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(text.isEmpty ? "—" : text)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: width, height: 44)
                .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(focused ? Color.white : Color.clear, lineWidth: 2)
                )
            if let rir {
                RIRBadge(value: rir)
                    .offset(x: 8, y: 8)
            }
        }
    }
}

struct RIRBadge: View {
    var value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RIRPalette.color(for: value), in: Circle())
    }
}

struct SetTypeBadge: View {
    var label: String
    var dimmed: Bool

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(dimmed ? Color(white: 0.45) : .white)
            .frame(width: 28, height: 28)
            .background(Color(white: 0.18), in: Circle())
    }
}
