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
    @State private var commitHaptics = UIImpactFeedbackGenerator(style: .rigid)
    @State private var tickHaptics = UIImpactFeedbackGenerator(style: .heavy)
    @State private var lightHaptics = UIImpactFeedbackGenerator(style: .light)
    /// Auto-clears when the dial gesture ends *or is cancelled* — prevents a stuck pull-up peek.
    @GestureState private var dialGestureActive = false
    @Environment(\.colorScheme) private var colorScheme

    private enum DragAxis {
        case undecided, horizontal, vertical
    }

    private var count: Int { max(items.count, 1) }

    private let spacingDegrees: Double = 24
    private let arcRadius: CGFloat = 186
    private let segmentWidth: CGFloat = 63
    private let maxCoastSegments: Double = 2.4
    /// Visual dial (~1.5× original). Page inset stays `PlannerChromeMetrics.dialLayoutHeight`.
    private let dialHeight: CGFloat = 104
    private let hitSlop: CGFloat = 40
    private let flatIconSpacing: CGFloat = 72
    private let idleDelaySeconds: Double = 5.0

    /// True black / white plate — matches theme, not charcoal surface.
    private var dockFill: Color {
        colorScheme == .dark ? .black : .white
    }

    private var dockIconColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var expandSpring: Animation {
        .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.1)
    }

    private var idleSpring: Animation {
        .spring(response: 0.42, dampingFraction: 0.88)
    }

    /// Snappy settle when committing a tap / neighbor pick.
    private var commitSpring: Animation {
        .spring(response: 0.26, dampingFraction: 0.90)
    }

    var body: some View {
        // Dial only — fixed height so safeAreaInset never pushes page content.
        // Pull-up peek is drawn by RootView (sibling overlay), not as dial background.
        dialStack
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Navigation dial")
            .accessibilityValue(selectedItem?.label ?? "")
            .accessibilityHint("Drag sideways to spin. Flick for momentum. Swipe up to expand the menu.")
            .accessibilityAction(named: "Expand menu") {
                withAnimation(expandSpring) { isExpanded = true }
            }
            .accessibilityAdjustableAction(handleAccessibilityAdjust)
    }

    private var dialStack: some View {
        ZStack(alignment: .bottom) {
            dockPlate
            dialInterior
        }
        .frame(maxWidth: .infinity)
        .frame(height: dialHeight + hitSlop, alignment: .bottom)
        .animation(idleSpring, value: idleAmount)
        .onAppear(perform: handleAppear)
        .onChange(of: selectedId) { _, _ in
            if !isDragging { syncPositionToSelection(animated: false) }
        }
        .onChange(of: isExpanded, perform: handleExpandedChange)
        .onChange(of: dialGestureActive, perform: handleGestureActiveChange)
        .onDisappear(perform: handleDisappear)
    }

    /// Solid theme plate behind the icons — idle bar sized so icons sit evenly; arc while scrolling.
    /// Circle mode: the arc tip fades in opacity so page content soft-blends above the icons.
    private var dockPlate: some View {
        let awake = max(0, 1 - idleAmount)
        // Slightly under dialHeight so padding above/below idle icons reads even (incl. home indicator).
        let idleBarHeight: CGFloat = dialHeight - 6
        let arcRise: CGFloat = 40 * awake

        return VStack(spacing: 0) {
            DockScrollArc(rise: max(arcRise, 0.01))
                .fill(dockFill)
                .frame(height: max(arcRise, 0.01))
                // Fade only the curved lip — icons live below this band.
                .mask(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.55),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(awake)
                .allowsHitTesting(false)

            Rectangle()
                .fill(dockFill)
                .frame(height: idleBarHeight)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        .frame(height: 1)
                        .opacity(1 - Double(awake) * 0.85)
                }
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func handleAppear() {
        commitHaptics.prepare()
        tickHaptics.prepare()
        lightHaptics.prepare()
        expandPull = 0
        syncPositionToSelection(animated: false)
        scheduleIdle()
    }

    private func handleDisappear() {
        expandPull = 0
        idleTask?.cancel()
        labelHideTask?.cancel()
        momentumTask?.cancel()
    }

    private func handleExpandedChange(_ expanded: Bool) {
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

    private func handleGestureActiveChange(_ active: Bool) {
        // GestureState resets on cancel as well as end — clear any orphaned peek chrome.
        guard !active else { return }
        expandPull = 0
        if dragAxis == .vertical {
            dragAxis = .undecided
        }
    }

    private func handleAccessibilityAdjust(_ direction: AccessibilityAdjustmentDirection) {
        guard let current = selectedIndex else { return }
        let next: Int
        switch direction {
        case .increment: next = (current + 1) % count
        case .decrement: next = (current - 1 + count) % count
        @unknown default: return
        }
        commit(to: next, haptic: true)
    }

    // MARK: - Dial (collapsed)

    private var dialInterior: some View {
        ZStack(alignment: .top) {
            Text(selectedItem?.label ?? "")
                .font(.callout.weight(.semibold))
                .foregroundStyle(dockIconColor.opacity(0.92))
                .padding(.horizontal, Theme.Space.md + 1)
                .padding(.vertical, Theme.Space.sm - 2)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(showLabel && idleAmount < 0.5 ? 1 : 0)
                .offset(y: 3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            GeometryReader { geo in
                let midX = geo.size.width / 2
                let midY = hitSlop + dialHeight * 0.48

                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        dialIcon(item: item, index: index, midX: midX, midY: midY)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Only the dock band takes hits — the hitSlop above is visual/layout only so
                // page controls (Focus Start, etc.) win over the dial scroller like the FAB.
                .contentShape(
                    Path { path in
                        let bandTop = max(0, geo.size.height - dialHeight)
                        path.addRect(CGRect(x: 0, y: bandTop, width: geo.size.width, height: dialHeight))
                    }
                )
                .gesture(dialGesture)
                .onAppear { dialWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, w in dialWidth = w }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.top, -hitSlop)
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

            // Shared for wheel + idle: primary full; neighbors dimmer (keep light-mode icons reading black).
            let iconScale: CGFloat = isCenter ? 1.0 : (0.72 + 0.16 * pow(focus, 0.65))
            let neighborOpacity: CGFloat = colorScheme == .dark ? 0.42 : 0.72
            let iconOpacity: CGFloat = isCenter ? 1.0 : neighborOpacity

            // Flat pill layout (idle) — 5 evenly spaced slots, vertically centered in the dock bar.
            let flatX = midX + CGFloat(delta) * flatIconSpacing
            let flatY = midY + 14

            let x = arcX + (flatX - arcX) * t
            let y = arcY + (flatY - arcY) * t

            Image(systemName: item.systemImage)
                .font(.system(size: isCenter ? 33 : 26, weight: isCenter ? .semibold : .regular))
                .foregroundStyle(dockIconColor)
                .frame(width: 66, height: 66)
                .background {
                    if isCenter {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Theme.accent.opacity(0.55 * (1 - t)),
                                        Theme.accent.opacity(0.18 * (1 - t)),
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
                            .strokeBorder(Theme.accent.opacity(0.9 * (1 - t) + 0.35 * t), lineWidth: 2.1)
                            .frame(width: 60, height: 60)
                            .opacity(max(0.35, 1 - t))
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
            .updating($dialGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let tx = value.translation.width
                let ty = value.translation.height

                if dragAxis == .undecided, hypot(tx, ty) > 5 {
                    dragAxis = abs(tx) >= abs(ty) * 0.7 ? .horizontal : .vertical
                    // Morph idle→arc only once a real drag starts (not on every press).
                    wake(animated: true)
                    if dragAxis == .horizontal {
                        isDragging = true
                        momentumTask?.cancel()
                        dragOrigin = position
                        lastTickIndex = Int(position.rounded())
                        tickHaptics.prepare()
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
                    // Only peek while pulling up; ignore downward noise so chrome never sticks.
                    expandPull = max(0, -ty)
                case .undecided:
                    break
                }
            }
            .onEnded { value in
                let axis = dragAxis
                let tx = value.translation.width
                let ty = value.translation.height
                let pull = expandPull
                dragAxis = .undecided
                isDragging = false
                lastTickIndex = nil
                expandPull = 0

                switch axis {
                case .horizontal:
                    settleHorizontal(translation: tx, predicted: value.predictedEndTranslation.width)
                case .vertical:
                    let shouldExpand = -ty > 40 || -value.predictedEndTranslation.height > 70 || pull > 100
                    if shouldExpand {
                        withAnimation(expandSpring) {
                            isExpanded = true
                        }
                    } else {
                        scheduleIdle()
                    }
                case .undecided:
                    // Instant wake so tap→switch isn't gated on the idle morph spring.
                    wake(animated: false)
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

        let item = items[wrapped]
        let changed = selectedId != item.id
        if changed {
            selectedId = item.id
            onSelect(item)
            flashLabel()
            if haptic {
                commitHaptics.impactOccurred(intensity: 1.0)
                commitHaptics.prepare()
            }
        } else if haptic {
            tickHaptics.impactOccurred(intensity: 0.85)
            tickHaptics.prepare()
        }

        withAnimation(commitSpring) {
            position = absoluteTarget
        }
        scheduleIdle()
    }

    private func handleTap(at location: CGPoint) {
        let midX = dialWidth / 2
        var bestIndex = selectedIndex ?? 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        let t = idleAmount

        for index in items.indices {
            let delta = wrappedDelta(Double(index) - position)
            guard abs(delta) < 2.85 else { continue }
            let angleRad = delta * spacingDegrees * .pi / 180
            let arcX = midX + CGFloat(sin(angleRad)) * arcRadius
            let flatX = midX + CGFloat(delta) * flatIconSpacing
            let x = arcX + (flatX - arcX) * t
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
            // Strong detent feel while spinning the dial.
            tickHaptics.impactOccurred(intensity: 1.0)
            tickHaptics.prepare()
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

        // Content switch first — dial spring follows so the page doesn't feel late.
        if changed {
            selectedId = item.id
            onSelect(item)
            if haptic {
                commitHaptics.impactOccurred(intensity: 1.0)
                commitHaptics.prepare()
            }
            flashLabel()
        } else if haptic {
            tickHaptics.impactOccurred(intensity: 0.85)
            tickHaptics.prepare()
        }

        withAnimation(commitSpring) {
            position = Double(currentNearest + delta)
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
        guard abs(target - position) > 0.001 else { return }
        if animated {
            withAnimation(commitSpring) {
                position = target
            }
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { position = target }
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

/// Hold empty space to edit; drag apps to reorder (Today pinned). − / + for hide/add.
struct WheelAppMenuOverlay: View {
    let items: [WheelNavItem]
    @Binding var selectedId: String
    var onSelect: (WheelNavItem) -> Void
    var onDismiss: () -> Void
    /// Optional: sync Lift profile when Workout is toggled from the grid.
    var onWorkoutVisibilityChange: ((Bool) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var isEditing = false
    @State private var appsRevision = 0
    @State private var draggingId: String?
    @State private var dragTranslation: CGSize = .zero
    @State private var hoverTargetId: String?
    @State private var commitHaptics = UIImpactFeedbackGenerator(style: .rigid)
    @State private var editHaptics = UIImpactFeedbackGenerator(style: .heavy)
    @State private var reorderHaptics = UIImpactFeedbackGenerator(style: .medium)

    private var panelHeight: CGFloat {
        min(UIScreen.main.bounds.height * 0.82, 760)
    }

    private var dismissSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.92)
    }

    private var visibleItems: [WheelNavItem] {
        _ = appsRevision
        return CadenceAppsPreferences.orderedVisibleDialDestinations.map(\.navItem)
    }

    private var availableItems: [WheelNavItem] {
        _ = appsRevision
        return CadenceAppsPreferences.hiddenConfigurable.map(\.navItem)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.muted.opacity(0.4))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Space.md + 2)
                .padding(.bottom, Theme.Space.md + 2)
                .contentShape(Rectangle())
                .accessibilityLabel("Collapse menu")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { dismiss() }
                .accessibilityHint("Swipe down to close the app menu")

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(isEditing ? "Edit apps" : (visibleItems.first(where: { $0.id == selectedId })?.label ?? "Apps"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(isEditing
                         ? "Drag to reorder · tap − / +"
                         : "Hold empty space to edit · swipe down to close")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: Theme.Space.sm)
                if isEditing {
                    Button("Done") {
                        finishEditing()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.cta)
                    .accessibilityHint("Finishes editing the app grid")
                }
            }
            .padding(.horizontal, Theme.Space.xl + 4)
            .padding(.bottom, Theme.Space.sm)

            // Fixed grid while browsing — vertical drag dismisses the whole sheet.
            // Scroll only when editing (Available list can overflow).
            Group {
                if isEditing {
                    ScrollView(showsIndicators: false) {
                        appMenuBody
                    }
                    .scrollDisabled(draggingId != nil)
                } else {
                    appMenuBody
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        // Whole sheet swipes down as one unit (not scroll/reorder the apps).
        .gesture(collapseGesture, isEnabled: !isEditing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App menu")
        .accessibilityHint(
            isEditing
                ? "Drag apps to reorder, or add and remove apps"
                : "Choose an app. Hold empty space to edit. Swipe down to collapse."
        )
        .onReceive(NotificationCenter.default.publisher(for: CadenceAppsPreferences.didChange)) { _ in
            appsRevision += 1
        }
    }

    private var appMenuBody: some View {
        ZStack(alignment: .top) {
            // Hold *around* apps (not on icons) to enter edit mode.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: max(panelHeight - 120, 420))
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.45) {
                    enterEditing()
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                appGrid(visibleItems, mode: .onDial)

                if isEditing, !availableItems.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        Text("AVAILABLE")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, Theme.Space.xl)
                        appGrid(availableItems, mode: .available)
                    }
                }
            }
            .padding(.top, Theme.Space.lg)
            .padding(.bottom, Theme.Space.xl * 2)
        }
    }

    private enum GridMode { case onDial, available }

    private func appGrid(_ gridItems: [WheelNavItem], mode: GridMode) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 24
        ) {
            ForEach(Array(gridItems.enumerated()), id: \.element.id) { index, item in
                cell(item, sort: Double(index), mode: mode)
            }
        }
        .padding(.horizontal, Theme.Space.xl)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: gridItems.map(\.id))
    }

    private func cell(_ item: WheelNavItem, sort: Double, mode: GridMode) -> some View {
        let selected = item.id == selectedId && mode == .onDial
        let dest = WheelDestination(rawValue: item.id)
        let canRemove = mode == .onDial
            && isEditing
            && dest.map { CadenceAppsPreferences.configurable.contains($0) } == true
        let canAdd = mode == .available && isEditing
        let canReorder = isEditing && mode == .onDial && canRemove
        let isDragging = draggingId == item.id
        let isHoverTarget = hoverTargetId == item.id && draggingId != nil && draggingId != item.id

        return Button {
            guard draggingId == nil else { return }
            if isEditing {
                if canRemove, let dest {
                    CadenceAppsPreferences.setVisible(dest, false)
                    if dest == .workout { onWorkoutVisibilityChange?(false) }
                    commitHaptics.impactOccurred(intensity: 0.6)
                } else if canAdd, let dest {
                    CadenceAppsPreferences.setVisible(dest, true)
                    if dest == .workout { onWorkoutVisibilityChange?(true) }
                    commitHaptics.impactOccurred(intensity: 0.6)
                }
                commitHaptics.prepare()
            } else {
                selectedId = item.id
                onSelect(item)
                commitHaptics.impactOccurred(intensity: 0.8)
                commitHaptics.prepare()
                dismiss()
            }
        } label: {
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.xl - 4, style: .continuous)
                        .fill(selected ? Theme.accent.opacity(0.22) : Theme.sunken)
                        .frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: Theme.Radius.xl - 4, style: .continuous)
                        .strokeBorder(
                            isHoverTarget
                                ? Theme.cta.opacity(0.95)
                                : (selected ? Theme.accent.opacity(0.9) : (mode == .available ? Theme.cta.opacity(0.45) : Theme.hairline)),
                            style: StrokeStyle(
                                lineWidth: isHoverTarget || selected ? 1.8 : 1,
                                dash: mode == .available ? [5, 4] : []
                            )
                        )
                        .frame(width: 72, height: 72)
                    Image(systemName: item.systemImage)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(selected ? Theme.accent : Theme.ink)
                        .frame(width: 72, height: 72)

                    if canRemove {
                        Image(systemName: "minus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red.opacity(0.95))
                            .font(.system(size: 22))
                            .offset(x: -6, y: -6)
                            .transaction { $0.animation = nil }
                            .accessibilityHidden(true)
                    } else if canAdd {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.cta)
                            .font(.system(size: 22))
                            .offset(x: -6, y: -6)
                            .transaction { $0.animation = nil }
                            .accessibilityHidden(true)
                    }
                }
                .scaleEffect(isDragging ? 1.08 : (isHoverTarget ? 1.04 : 1))
                .shadow(color: isDragging ? .black.opacity(0.35) : .clear, radius: isDragging ? 12 : 0, y: isDragging ? 6 : 0)

                Text(item.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .frame(width: 80)
            }
            // Keep the hit target on the icon + label only so gaps around apps
            // can receive hold-to-edit on the background.
            .contentShape(Rectangle())
            .opacity(isDragging ? 0.92 : 1)
            .offset(isDragging ? dragTranslation : .zero)
            .zIndex(isDragging ? 20 : (isHoverTarget ? 5 : 0))
        }
        .buttonStyle(WheelAppPressStyle())
        .frame(maxWidth: .infinity)
        .modifier(WheelReorderDragModifier(
            enabled: canReorder,
            onChanged: { value in
                if draggingId == nil {
                    draggingId = item.id
                    editHaptics.impactOccurred(intensity: 0.55)
                    editHaptics.prepare()
                    reorderHaptics.prepare()
                }
                guard draggingId == item.id else { return }
                dragTranslation = value.translation
                updateHoverTarget(for: item, translation: value.translation)
            },
            onEnded: {
                commitReorder(of: item)
            }
        ))
        .accessibilityLabel(item.label)
        .accessibilityHint(
            isEditing
                ? (canRemove
                   ? "Hides \(item.label). Drag to reorder."
                   : (canAdd ? "Adds \(item.label) to the wheel" : "Pinned. Cannot reorder."))
                : "Opens \(item.label)"
        )
        .accessibilityIdentifier("wheel-app-\(item.id)")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilitySortPriority(100 - sort)
        .accessibilityAction(named: Text("Move earlier")) {
            moveItemEarlier(item)
        }
        .accessibilityAction(named: Text("Move later")) {
            moveItemLater(item)
        }
    }

    private func updateHoverTarget(for item: WheelNavItem, translation: CGSize) {
        // Approximate grid cell size for 4-column layout.
        let cellW: CGFloat = (UIScreen.main.bounds.width - Theme.Space.xl * 2) / 4
        let cellH: CGFloat = 72 + 12 + 20 + 24
        let colDelta = Int(round(translation.width / cellW))
        let rowDelta = Int(round(translation.height / cellH))
        guard let fromIndex = visibleItems.firstIndex(where: { $0.id == item.id }) else { return }
        let cols = 4
        let fromRow = fromIndex / cols
        let fromCol = fromIndex % cols
        let toRow = max(0, fromRow + rowDelta)
        let toCol = min(cols - 1, max(0, fromCol + colDelta))
        let toIndex = min(visibleItems.count - 1, toRow * cols + toCol)
        let target = visibleItems[toIndex]
        if hoverTargetId != target.id {
            hoverTargetId = target.id
            if target.id != item.id {
                reorderHaptics.impactOccurred(intensity: 0.9)
                reorderHaptics.prepare()
            }
        }
    }

    private func commitReorder(of item: WheelNavItem) {
        defer {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                draggingId = nil
                dragTranslation = .zero
                hoverTargetId = nil
            }
        }
        guard let targetId = hoverTargetId,
              targetId != item.id,
              let moving = WheelDestination(rawValue: item.id),
              let target = WheelDestination(rawValue: targetId) else { return }
        CadenceAppsPreferences.moveDialDestination(moving, onto: target)
        commitHaptics.impactOccurred(intensity: 1.0)
        commitHaptics.prepare()
    }

    private func moveItemEarlier(_ item: WheelNavItem) {
        guard let dest = WheelDestination(rawValue: item.id),
              CadenceAppsPreferences.configurable.contains(dest) else { return }
        let order = CadenceAppsPreferences.orderedConfigurableVisible
        guard let idx = order.firstIndex(of: dest), idx > 0 else { return }
        CadenceAppsPreferences.moveDialDestination(dest, onto: order[idx - 1])
    }

    private func moveItemLater(_ item: WheelNavItem) {
        guard let dest = WheelDestination(rawValue: item.id),
              CadenceAppsPreferences.configurable.contains(dest) else { return }
        let order = CadenceAppsPreferences.orderedConfigurableVisible
        guard let idx = order.firstIndex(of: dest), idx + 1 < order.count else { return }
        // Place after next by moving next onto this (swap-ish): move this onto item two ahead, or append.
        if idx + 2 < order.count {
            CadenceAppsPreferences.moveDialDestination(dest, onto: order[idx + 2])
        } else {
            CadenceAppsPreferences.moveDialDestination(dest, before: nil)
        }
    }

    private func enterEditing() {
        guard !isEditing else { return }
        isEditing = true
        editHaptics.impactOccurred(intensity: 0.85)
        editHaptics.prepare()
    }

    private func finishEditing() {
        draggingId = nil
        dragTranslation = .zero
        hoverTargetId = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isEditing = false
        }
        editHaptics.impactOccurred(intensity: 0.7)
        editHaptics.prepare()
    }

    private var collapseGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                guard !isEditing, draggingId == nil else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                // Only pull the sheet down — ignore sideways / upward noise.
                guard dy > 0, dy > abs(dx) * 0.85 else { return }
                dragOffset = dy
            }
            .onEnded { value in
                guard !isEditing, draggingId == nil else {
                    dragOffset = 0
                    return
                }
                let dy = max(value.translation.height, dragOffset)
                let predicted = value.predictedEndTranslation.height
                let shouldClose = dy > 90 || predicted > 160 || dragOffset > 140
                if shouldClose {
                    dismiss(animatedSlideOff: true)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismiss(animatedSlideOff: Bool = false) {
        isEditing = false
        draggingId = nil
        dragTranslation = .zero
        hoverTargetId = nil

        // Finish the downward swipe off-screen first. Resetting dragOffset to 0 here
        // used to snap the sheet *up* while the dial faded in → ghost app icons.
        if animatedSlideOff || dragOffset > 8 {
            let distance = max(dragOffset, panelHeight * 0.4)
            withAnimation(dismissSpring) {
                dragOffset = distance + panelHeight
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                onDismiss()
            }
        } else {
            withAnimation(dismissSpring) {
                onDismiss()
            }
        }
    }
}

/// Full-width gradual arc that rises above the idle dock while scrolling.
private struct DockScrollArc: Shape, Animatable {
    var rise: CGFloat

    var animatableData: CGFloat {
        get { rise }
        set { rise = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rise > 0.5 else { return path }
        // Flat base along the idle bar; top is a gentle quadratic across the full width.
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// Light press feedback without stealing long-press (edit is on empty space).
private struct WheelAppPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct WheelReorderDragModifier: ViewModifier {
    var enabled: Bool
    var onChanged: (DragGesture.Value) -> Void
    var onEnded: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged(onChanged)
                    .onEnded { _ in onEnded() }
            )
        } else {
            content
        }
    }
}
