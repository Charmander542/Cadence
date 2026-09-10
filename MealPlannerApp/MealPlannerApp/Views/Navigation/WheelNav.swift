import SwiftUI
import UIKit

struct WheelNavItem: Identifiable, Hashable {
    let id: String
    let label: String
    let systemImage: String
}

/// Compact submerged rotary dial that expands into a full app menu (same chrome, morphing icons).
struct WheelNav: View {
    let items: [WheelNavItem]
    @Binding var selectedId: String
    @Binding var isExpanded: Bool
    /// Reported to RootView so the pull-up peek can overlay without growing the dial inset.
    @Binding var expandPull: CGFloat
    var onSelect: (WheelNavItem) -> Void = { _ in }

    /// Continuous wheel angle in item units (2.35 = 35% between item 2 and 3).
    @State private var position: Double = 0
    @State private var dragOrigin: Double = 0
    @State private var isDragging = false
    @State private var dragAxis: DragAxis = .undecided
    @State private var lastTickIndex: Int?
    @State private var showLabel = false
    @State private var labelHideTask: Task<Void, Never>?
    /// 0 = awake arc dial, 1 = flat idle pill (reference).
    @State private var idleAmount: CGFloat = 0
    @State private var idleTask: Task<Void, Never>?
    @State private var dialWidth: CGFloat = 390
    @State private var momentumTask: Task<Void, Never>?
    @State private var selectionHaptics = UISelectionFeedbackGenerator()
    @State private var commitHaptics = UIImpactFeedbackGenerator(style: .medium)
    @State private var lightHaptics = UIImpactFeedbackGenerator(style: .light)

    private enum DragAxis {
        case undecided, horizontal, vertical
    }

    private var count: Int { max(items.count, 1) }

    private let spacingDegrees: Double = 24
    private let arcRadius: CGFloat = 186
    private let segmentWidth: CGFloat = 63
    private let maxCoastSegments: Double = 2.4
    /// Visual dial (~1.5× original). Page inset stays `PlannerChromeMetrics.dialLayoutHeight`.
    private let dialHeight: CGFloat = 87
    private let hitSlop: CGFloat = 21
    private let flatPillWidth: CGFloat = 360
    private let flatIconSpacing: CGFloat = 72
    private let idleDelaySeconds: Double = 5.0

    private var expandSpring: Animation {
        .spring(response: 0.48, dampingFraction: 0.86, blendDuration: 0.15)
    }

    private var idleSpring: Animation {
        .spring(response: 0.55, dampingFraction: 0.84)
    }

    var body: some View {
        // Dial only — fixed height so safeAreaInset never pushes page content.
        // Pull-up peek is drawn by RootView (sibling overlay), not as dial background.
        ZStack(alignment: .bottom) {
            menuChrome
            dialInterior
        }
        .frame(maxWidth: .infinity)
        .frame(height: dialHeight + hitSlop, alignment: .bottom)
        .animation(idleSpring, value: idleAmount)
        .onAppear {
            selectionHaptics.prepare()
            commitHaptics.prepare()
            lightHaptics.prepare()
            syncPositionToSelection(animated: false)
            scheduleIdle()
        }
        .onChange(of: selectedId) { _, _ in
            if !isDragging { syncPositionToSelection(animated: true) }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                wake(animated: true)
                lightHaptics.impactOccurred(intensity: 0.55)
                lightHaptics.prepare()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    scheduleIdle()
                }
            }
            expandPull = 0
        }
        .onDisappear {
            idleTask?.cancel()
            labelHideTask?.cancel()
            momentumTask?.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation dial")
        .accessibilityValue(selectedItem?.label ?? "")
        .accessibilityHint("Drag sideways to spin. Flick for momentum. Swipe up to expand the menu.")
        .accessibilityAction(named: "Expand menu") {
            withAnimation(expandSpring) { isExpanded = true }
        }
        .accessibilityAdjustableAction { direction in
            guard let current = selectedIndex else { return }
            let next: Int
            switch direction {
            case .increment: next = (current + 1) % count
            case .decrement: next = (current - 1 + count) % count
            @unknown default: return
            }
            commit(to: next, haptic: true)
        }
    }

    // MARK: - Shared chrome (flat pill when idle)

    private var menuChrome: some View {
        // Soft pill — avoid a near-opaque black plate that makes idle icons look brighter than the wheel.
        Capsule(style: .continuous)
            .fill(Color.black.opacity(0.45))
            .frame(width: flatPillWidth, height: 78)
            .opacity(idleAmount)
            .offset(y: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
    }

    // MARK: - Dial (collapsed)

    private var dialInterior: some View {
        ZStack(alignment: .top) {
            Text(selectedItem?.label ?? "")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(showLabel && idleAmount < 0.5 ? 1 : 0)
                .offset(y: 3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            GeometryReader { geo in
                let midX = geo.size.width / 2
                let midY = hitSlop + dialHeight * 0.48

                ZStack {
                    submergedGlass(width: geo.size.width, height: geo.size.height)
                        // Keep glass contrast in idle so neighbor icons don’t jump in brightness.
                        .opacity(1 - idleAmount * 0.35)

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        dialIcon(item: item, index: index, midX: midX, midY: midY)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(dialGesture)
                .onAppear { dialWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, w in dialWidth = w }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.top, -hitSlop)
    }

    private func submergedGlass(width: CGFloat, height: CGFloat) -> some View {
        let visualMid = height * 0.55 + hitSlop * 0.15
        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.05),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.5, y: 0.15),
                        startRadius: 3,
                        endRadius: max(height, 105)
                    )
                )
                .frame(width: min(width * 0.88, 510), height: height * 1.35)
                .offset(y: visualMid)
                .blur(radius: 1.2)

            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.8
                )
                .frame(width: min(width * 0.68, 390), height: 51)
                .offset(y: visualMid + 6)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func dialIcon(item: WheelNavItem, index: Int, midX: CGFloat, midY: CGFloat) -> some View {
        let delta = wrappedDelta(Double(index) - position)
        let absDelta = abs(delta)
        let visible = absDelta < 2.85
        let t = idleAmount // 0 arc → 1 flat pill

        if visible {
            // Arc layout (awake)
            let angleRad = delta * spacingDegrees * .pi / 180
            let arcX = midX + CGFloat(sin(angleRad)) * arcRadius
            let arcY = midY + CGFloat(1 - cos(angleRad)) * arcRadius * 0.62 + 12
            let focus = max(0, 1 - absDelta)
            let isCenter = absDelta < 0.45

            // Shared for wheel + idle: primary full; all other icons one opacity (no blur mismatch).
            let iconScale: CGFloat = isCenter ? 1.0 : (0.72 + 0.16 * pow(focus, 0.65))
            let iconOpacity: CGFloat = isCenter ? 1.0 : 0.42

            // Flat pill layout (idle) — 5 evenly spaced slots
            let flatX = midX + CGFloat(delta) * flatIconSpacing
            let flatY = midY + 24

            let x = arcX + (flatX - arcX) * t
            let y = arcY + (flatY - arcY) * t

            Image(systemName: item.systemImage)
                .font(.system(size: isCenter ? 33 : 26, weight: isCenter ? .semibold : .regular))
                .foregroundStyle(Color.white)
                .frame(width: 66, height: 66)
                .background {
                    if isCenter {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55 * (1 - t)),
                                        Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.18 * (1 - t)),
                                        Color.clear,
                                    ],
                                    center: .center,
                                    startRadius: 3,
                                    endRadius: 42
                                )
                            )
                            .frame(width: 81, height: 81)
                            .blur(radius: 9)
                            .opacity(1 - t)
                    }
                }
                .overlay {
                    if isCenter {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.85 * (1 - t)), lineWidth: 2.1)
                            .frame(width: 60, height: 60)
                            .opacity(1 - t)
                    }
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .position(x: x, y: y)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Expanded menu moved to WheelAppMenuOverlay (RootView overlay)


    // MARK: - Gestures

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                wake(animated: true)
                let tx = value.translation.width
                let ty = value.translation.height

                if dragAxis == .undecided, hypot(tx, ty) > 5 {
                    dragAxis = abs(tx) >= abs(ty) * 0.7 ? .horizontal : .vertical
                    if dragAxis == .horizontal {
                        isDragging = true
                        momentumTask?.cancel()
                        dragOrigin = position
                        lastTickIndex = Int(position.rounded())
                        selectionHaptics.prepare()
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { position = dragOrigin }
                    }
                }

                switch dragAxis {
                case .horizontal:
                    position = dragOrigin - Double(tx / segmentWidth)
                    tickIfNeeded()
                case .vertical:
                    expandPull = max(0, -ty)
                case .undecided:
                    break
                }
            }
            .onEnded { value in
                let axis = dragAxis
                let tx = value.translation.width
                let ty = value.translation.height
                dragAxis = .undecided
                isDragging = false
                lastTickIndex = nil

                switch axis {
                case .horizontal:
                    settleHorizontal(translation: tx, predicted: value.predictedEndTranslation.width)
                case .vertical:
                    let shouldExpand = -ty > 40 || -value.predictedEndTranslation.height > 70 || expandPull > 100
                    expandPull = 0
                    if shouldExpand {
                        withAnimation(expandSpring) {
                            isExpanded = true
                        }
                    } else {
                        scheduleIdle()
                    }
                case .undecided:
                    handleTap(at: value.location)
                }
            }
    }

    // MARK: - Physics

    private func settleHorizontal(translation tx: CGFloat, predicted: CGFloat) {
        let flickPixels = predicted - tx
        var velocity = -Double(flickPixels) / segmentWidth / 0.18
        velocity = max(-maxCoastSegments * 3.2, min(maxCoastSegments * 3.2, velocity))

        if abs(velocity) < 1.2 {
            snapToNearest(haptic: true)
            return
        }

        momentumTask?.cancel()
        momentumTask = Task { @MainActor in
            var v = velocity
            var traveled = 0.0
            while !Task.isCancelled, abs(v) > 0.35, abs(traveled) < maxCoastSegments {
                let step = v * 0.016
                position += step
                traveled += step
                v *= 0.935
                tickIfNeeded()
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard !Task.isCancelled else { return }
            snapToNearest(haptic: true)
        }
    }

    private func snapToNearest(haptic: Bool) {
        let targetIndex = Int(position.rounded())
        let wrapped = ((targetIndex % count) + count) % count
        let currentNearest = Int(position.rounded())
        var delta = wrapped - ((currentNearest % count) + count) % count
        if delta > count / 2 { delta -= count }
        if delta < -(count / 2) { delta += count }
        let absoluteTarget = Double(currentNearest + delta)

        withAnimation(.interpolatingSpring(stiffness: 360, damping: 32)) {
            position = absoluteTarget
        }

        let item = items[wrapped]
        let changed = selectedId != item.id
        if changed {
            selectedId = item.id
            onSelect(item)
            flashLabel()
            if haptic {
                commitHaptics.impactOccurred(intensity: 0.9)
                commitHaptics.prepare()
            }
        } else if haptic {
            selectionHaptics.selectionChanged()
            selectionHaptics.prepare()
        }
        scheduleIdle()
    }

    private func handleTap(at location: CGPoint) {
        let midX = dialWidth / 2
        var bestIndex = selectedIndex ?? 0
        var bestDist = CGFloat.greatestFiniteMagnitude

        for index in items.indices {
            let delta = wrappedDelta(Double(index) - position)
            guard abs(delta) < 2.85 else { continue }
            let angleRad = delta * spacingDegrees * .pi / 180
            let x = midX + CGFloat(sin(angleRad)) * arcRadius
            let d = abs(x - location.x)
            if d < bestDist {
                bestDist = d
                bestIndex = index
            }
        }
        commit(to: bestIndex, haptic: true)
    }

    private func tickIfNeeded() {
        let nearest = Int(position.rounded())
        let clamped = ((nearest % count) + count) % count
        if clamped != lastTickIndex {
            lastTickIndex = clamped
            selectionHaptics.selectionChanged()
            selectionHaptics.prepare()
        }
    }

    // MARK: - Shared

    private var selectedItem: WheelNavItem? {
        items.first { $0.id == selectedId } ?? items.first
    }

    private var selectedIndex: Int? {
        items.firstIndex { $0.id == selectedId }
    }

    private func wrappedDelta(_ delta: Double) -> Double {
        var d = delta
        let half = Double(count) / 2
        while d > half { d -= Double(count) }
        while d <= -half { d += Double(count) }
        return d
    }

    private func commit(to index: Int, haptic: Bool) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        let changed = selectedId != item.id

        let currentNearest = Int(position.rounded())
        var delta = index - ((currentNearest % count) + count) % count
        if delta > count / 2 { delta -= count }
        if delta < -(count / 2) { delta += count }

        withAnimation(.interpolatingSpring(stiffness: 340, damping: 30)) {
            position = Double(currentNearest + delta)
        }

        if changed {
            selectedId = item.id
            if haptic {
                commitHaptics.impactOccurred(intensity: 0.9)
                commitHaptics.prepare()
            }
            onSelect(item)
            flashLabel()
        } else if haptic {
            selectionHaptics.selectionChanged()
            selectionHaptics.prepare()
        }
        scheduleIdle()
    }

    private func syncPositionToSelection(animated: Bool) {
        guard let index = selectedIndex else { return }
        let currentNearest = Int(position.rounded())
        var delta = index - ((currentNearest % count) + count) % count
        if delta > count / 2 { delta -= count }
        if delta < -(count / 2) { delta += count }
        let target = Double(currentNearest + delta)
        if animated {
            withAnimation(.easeOut(duration: 0.26)) {
                position = target
            }
        } else {
            position = target
        }
    }

    private func flashLabel() {
        showLabel = true
        labelHideTask?.cancel()
        labelHideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                showLabel = false
            }
        }
    }

    private func wake(animated: Bool = true) {
        idleTask?.cancel()
        guard idleAmount > 0.01 else { return }
        if animated {
            withAnimation(idleSpring) {
                idleAmount = 0
            }
        } else {
            idleAmount = 0
        }
    }

    private func scheduleIdle() {
        idleTask?.cancel()
        idleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(idleDelaySeconds))
            guard !Task.isCancelled, !isDragging, !isExpanded else { return }
            withAnimation(idleSpring) {
                idleAmount = 1
            }
        }
    }
}

// MARK: - Full app menu (overlays content — does not resize the dial inset)

struct WheelAppMenuOverlay: View {
    let items: [WheelNavItem]
    @Binding var selectedId: String
    var onSelect: (WheelNavItem) -> Void
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var commitHaptics = UIImpactFeedbackGenerator(style: .light)

    private var panelHeight: CGFloat {
        min(UIScreen.main.bounds.height * 0.82, 760)
    }

    private var dismissSpring: Animation {
        .spring(response: 0.48, dampingFraction: 0.86)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.muted.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .accessibilityLabel("Collapse menu")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { dismiss() }

            Text(items.first(where: { $0.id == selectedId })?.label ?? "Apps")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

            Text("Swipe down to collapse")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .accessibilityHidden(true)

            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
                    spacing: 24
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        cell(item, sort: Double(index))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Theme.surface)
            .shadow(color: .black.opacity(0.45), radius: 28, y: -10)
            .ignoresSafeArea(edges: .bottom)
        )
        .padding(.bottom, 0)
        .offset(y: max(0, dragOffset))
        .gesture(collapseGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App menu")
        .accessibilityHint("Choose an app, or swipe down to collapse")
    }

    private func cell(_ item: WheelNavItem, sort: Double) -> some View {
        let selected = item.id == selectedId
        return Button {
            selectedId = item.id
            onSelect(item)
            commitHaptics.impactOccurred(intensity: 0.8)
            commitHaptics.prepare()
            dismiss()
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(selected ? Theme.accent.opacity(0.22) : Theme.canvas.opacity(0.8))
                        .frame(width: 72, height: 72)
                    if selected {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.9), lineWidth: 1.6)
                            .frame(width: 72, height: 72)
                    }
                    Image(systemName: item.systemImage)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(selected ? Theme.accent : Theme.ink)
                }
                Text(item.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityHint("Opens \(item.label)")
        .accessibilityIdentifier("wheel-app-\(item.id)")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilitySortPriority(100 - sort)
    }

    private var collapseGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                let shouldClose = value.translation.height > 90
                    || value.predictedEndTranslation.height > 160
                    || dragOffset > 140
                if shouldClose {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismiss() {
        withAnimation(dismissSpring) {
            dragOffset = 0
            onDismiss()
        }
    }
}
