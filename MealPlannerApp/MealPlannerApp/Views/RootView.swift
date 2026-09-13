import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @Query private var profiles: [UserProfileEntity]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let profile = profiles.first, profile.onboardingComplete {
                MainTabView(profile: profile)
            } else {
                OnboardingView(profile: ensureProfile())
            }
        }
        .cadenceDismissKeyboardOnTap()
        .cadenceKeyboardDoneButton()
        .onAppear { _ = ensureProfile() }
        .onAppear {
            CadenceAutomation.skipOnboardingIfRequested(modelContext: modelContext, profiles: profiles)
        }
        .alert("Error", isPresented: Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appModel.errorMessage = nil }
                .accessibilityHint("Dismisses error message")
        } message: {
            Text(appModel.errorMessage ?? "")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func ensureProfile() -> UserProfileEntity {
        if let existing = profiles.first { return existing }
        let profile = UserProfileEntity()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity
    /// Legacy 0…4 tab index used by launch args / automation for core pages.
    @AppStorage("main_selected_tab") private var selectedTab = 0
    @AppStorage("main_selected_wheel") private var selectedWheelId = WheelDestination.today.rawValue
    @Query(sort: \TaskListEntity.sortOrder) private var lists: [TaskListEntity]

    @State private var showDrawer = false
    /// Interactive edge-swipe reveal while opening (0…sidebarWidth). Shared with the real drawer — no blank preview.
    @State private var sidebarOpenDragX: CGFloat = 0
    /// Once the open drag is clearly horizontal, keep tracking even if the finger drifts vertical.
    @State private var sidebarOpenAxisLocked = false
    /// Bumped to cancel in-flight open settle completions.
    @State private var sidebarOpenGeneration = 0
    @State private var showSettings = false
    private let sidebarWidth: CGFloat = 300
    private let sidebarEdgeWidth: CGFloat = 22
    private let sidebarOpenThreshold: CGFloat = 72
    private let sidebarOpenSpring = Animation.spring(response: 0.30, dampingFraction: 0.92)
    @State private var openShopOnMeals = false
    @State private var plannerDestination: PlannerDestination = .today
    @State private var showTagManager = false
    @State private var loadedPages: Set<String> = [WheelDestination.today.rawValue]
    /// Content behind Shop/Settings overlays (those wheel picks open sheets).
    @State private var contentDestination: WheelDestination = .today
    @State private var isAppGridExpanded = false
    /// Live pull-up distance from the dial — drawn in this ZStack so it never resizes the page inset.
    @State private var wheelExpandPull: CGFloat = 0
    /// Hide dial while the app menu is up / dismissing so icons don’t flash through (“ghost apps”).
    @State private var showWheelDock = true
    @StateObject private var appsModel = CadenceAppsModel()

    private var wheelItems: [WheelNavItem] { appsModel.dialItems }
    private let appMenuSpring = Animation.spring(response: 0.32, dampingFraction: 0.90)

    var body: some View {
        ZStack {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.canvas.ignoresSafeArea())
                // Keep the old inset height so page + FAB stay put while the dial draws larger on top.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: PlannerChromeMetrics.dialLayoutHeight)
                        .accessibilityHidden(true)
                }
                // Expand/collapse must not animate page layout (title lag vs cards).
                .animation(nil, value: isAppGridExpanded)
                .animation(nil, value: wheelExpandPull)

            // Larger dial overlays the reserved band (may extend slightly into content).
            if showWheelDock {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    wheelDock
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.opacity)
            }

            // FAB above the dial — ZStack positions the + without expanding its hit box
            // across the trailing band (that blocked Spend category rows above the menu).
            if showWheelDock, let fab = contentDestination.fabAction {
                ZStack(alignment: .bottomTrailing) {
                    CreateFAB(
                        accessibilityLabel: fab.accessibilityLabel,
                        accessibilityHint: fab.accessibilityHint
                    ) {
                        appModel.requestedFABAction = fab
                    }
                    .padding(.trailing, PlannerChromeMetrics.dialFABTrailingPadding)
                    .padding(.bottom, PlannerChromeMetrics.dialFABBottomPadding + PlannerChromeMetrics.dialLayoutHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .zIndex(3)
            }

            // Interactive pull-up peek — sibling overlay, not part of the bottom inset.
            // Only while the dial reports an active upward pull (cleared on gesture cancel).
            if wheelExpandPull > 12, showWheelDock {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: Theme.Radius.xl + 4, style: .continuous)
                        .fill(Theme.surface.opacity(min(1, wheelExpandPull / 100)))
                        .frame(height: min(wheelExpandPull * 0.85, 160))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Theme.muted.opacity(0.45))
                                .frame(width: 32, height: 4)
                                .padding(.top, Theme.Space.sm + 2)
                        }
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            // Full-screen overlay (sibling of inset content) so expand never pushes the page.
            // Avoid .move(edge:) removal — a cancelled spring can leave grabber chrome stuck on-screen.
            ZStack {
                if isAppGridExpanded {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Match swipe-dismiss: hide dial first, then collapse overlay.
                            showWheelDock = false
                            withAnimation(appMenuSpring) {
                                isAppGridExpanded = false
                            }
                        }
                        .transition(.opacity)
                        .accessibilityLabel("Dismiss app grid")
                        .accessibilityAddTraits(.isButton)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        WheelAppMenuOverlay(
                            items: wheelItems,
                            selectedId: $selectedWheelId,
                            onSelect: handleWheelSelect,
                            onRevealDock: {
                                // While the sheet slides off, restore the dial underneath.
                                withAnimation(.easeOut(duration: 0.12)) {
                                    showWheelDock = true
                                }
                            },
                            onDismiss: {
                                // Menu already slid off — drop overlay without bringing the dial back early.
                                var t = Transaction()
                                t.disablesAnimations = true
                                withTransaction(t) {
                                    isAppGridExpanded = false
                                }
                            },
                            onWorkoutVisibilityChange: { on in
                                profile.workoutsEnabled = on
                                Task { await PlannerSyncCoordinator.shared.refreshAll(in: modelContext) }
                            }
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                    // Slide in; fade out on dismiss so a cancelled spring can't leave grabber chrome stuck.
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .animation(appMenuSpring, value: isAppGridExpanded)
            .allowsHitTesting(isAppGridExpanded)
        }
        // Prefer dial / app-menu swipes over Home Indicator + app-switcher edge gestures.
        // Users still reach Home by swiping up a second time (or from outside the dial).
        .defersSystemGestures(on: .bottom)
        .environment(\.isAppGridExpanded, isAppGridExpanded)
        .tint(Theme.accent)
        .liveWorkoutHost()
        .onChange(of: selectedWheelId) { _, id in
            loadedPages.insert(id)
            if let dest = WheelDestination(rawValue: id), dest.showsContentPage {
                contentDestination = dest
                if let legacy = dest.legacyTabIndex {
                    selectedTab = legacy
                }
            }
        }
        .onChange(of: appModel.requestedMainTab) { _, tab in
            if let tab, let dest = WheelDestination.fromLegacyTab(tab) {
                selectWheel(dest)
                appModel.requestedMainTab = nil
            }
        }
        .onChange(of: appModel.requestedWheelId) { _, id in
            if let id, let dest = WheelDestination(rawValue: id) {
                selectWheel(dest)
                appModel.requestedWheelId = nil
            }
        }
        .onChange(of: appModel.requestedOpenShop) { _, shouldOpen in
            if shouldOpen {
                appModel.requestedOpenShop = false
                openShop()
            }
        }
        .onChange(of: appModel.requestedOpenDrawer) { _, shouldOpen in
            if shouldOpen {
                openSidebar(animated: true)
                appModel.requestedOpenDrawer = false
            }
        }
        .onChange(of: appModel.requestedCloseDrawer) { _, shouldClose in
            if shouldClose {
                showDrawer = false
                sidebarOpenDragX = 0
                appModel.requestedCloseDrawer = false
            }
        }
        .onChange(of: showDrawer) { _, open in
            if open, isAppGridExpanded {
                withAnimation(.easeOut(duration: 0.2)) {
                    isAppGridExpanded = false
                }
            }
        }
        .onChange(of: isAppGridExpanded) { _, expanded in
            if expanded {
                // Cover dial immediately so icons never sit under a translucent menu.
                showWheelDock = false
                wheelExpandPull = 0
            } else if !showWheelDock {
                revealWheelDockAfterMenu()
            }
        }
        .overlay {
            if appModel.isGeneratingPlan && !appModel.planGeneratingMinimized {
                PlanGeneratingOverlay()
                    .transition(.opacity)
            }
        }
        .overlay {
            // One real drawer for finger-open + settled open — no preview handoff.
            if showDrawer || sidebarOpenDragX > 0.01 {
                PlannerDrawer(
                    lists: lists,
                    destination: plannerDestination,
                    onSelect: { dest in
                        closeSidebarImmediate()
                        switch dest {
                        case .matrix:
                            selectWheel(.matrix)
                        case .meals:
                            guard CadenceAppsPreferences.isVisible(.meals) else { break }
                            selectWheel(.meals)
                        case .shop:
                            guard CadenceAppsPreferences.isVisible(.shop) else { break }
                            openShop()
                        default:
                            plannerDestination = dest
                            selectWheel(.today)
                        }
                    },
                    onSettings: {
                        closeSidebarImmediate()
                        openSettings()
                    },
                    onClose: { closeSidebarImmediate() },
                    onAddList: { name in
                        PlannerStore.addList(named: name, in: modelContext)
                    },
                    onManageTags: {
                        closeSidebarImmediate()
                        showTagManager = true
                    },
                    onSearch: {
                        closeSidebarImmediate()
                        appModel.showGlobalSearchSheet = true
                    },
                    interactiveOpenX: showDrawer ? nil : sidebarOpenDragX
                )
                .allowsHitTesting(showDrawer)
                .transition(.identity)
            }
        }
        // Left-edge swipe opens the sidebar — stop above the dial so menu swipes win.
        .overlay(alignment: .leading) {
            if !showDrawer {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: sidebarEdgeWidth)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(sidebarOpenEdgeGesture)
                    // Dead zone over the wheel / home-indicator band.
                    Color.clear
                        .frame(width: sidebarEdgeWidth, height: PlannerChromeMetrics.dialLayoutHeight + 44)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea(edges: .bottom)
                .accessibilityHidden(true)
            }
        }
        .sheet(isPresented: Binding(
            get: { showSettings || appModel.showSettingsSheet },
            set: { presented in
                if !presented {
                    showSettings = false
                    appModel.showSettingsSheet = false
                } else {
                    showSettings = true
                }
            }
        )) {
            SettingsView(profile: profile)
        }
        .sheet(isPresented: $appModel.showGlobalSearchSheet) {
            GlobalSearchSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTagManager) {
            TagManagerSheet()
        }
        .animation(nil, value: showDrawer)
        .animation(.easeInOut(duration: 0.28), value: appModel.isGeneratingPlan)
        .safeAreaInset(edge: .top) {
            if appModel.isGeneratingPlan && appModel.planGeneratingMinimized {
                HStack(spacing: Theme.Space.sm + 2) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appModel.generatingStatus)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Button("Show") {
                        appModel.planGeneratingMinimized = false
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel("Show plan generation progress")
                    .accessibilityHint("Opens full plan generation overlay")
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.sm + 2)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            // Cold launch / return: never leave pull-peek or app-menu chrome on screen.
            isAppGridExpanded = false
            showWheelDock = true
            wheelExpandPull = 0
            migrateLegacySelectionIfNeeded()
            loadedPages.insert(selectedWheelId)
            if let dest = WheelDestination(rawValue: selectedWheelId), dest.showsContentPage {
                contentDestination = dest
            } else if let dest = WheelDestination.fromLegacyTab(selectedTab) {
                contentDestination = dest
                selectedWheelId = dest.rawValue
            }
            ensureSelectionVisible()
            applyLaunchArguments()
        }
        .onChange(of: appsModel.revision) { _, _ in
            ensureSelectionVisible()
        }
    }

    private var wheelDock: some View {
        WheelNav(
            items: wheelItems,
            selectedId: $selectedWheelId,
            isExpanded: $isAppGridExpanded,
            expandPull: $wheelExpandPull,
            endStops: appsModel.dialHasEndStops,
            onSelect: handleWheelSelect
        )
        .zIndex(2)
    }

    private func revealWheelDockAfterMenu() {
        // Menu is already gone (or fading) — bring the dial back immediately.
        guard !isAppGridExpanded else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            showWheelDock = true
        }
    }

    private var sidebarOpenEdgeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                // Ignore pulls that began in the dial / menu band.
                guard !startsInDialBand(value.startLocation) else {
                    resetSidebarOpenDrag()
                    return
                }
                let tx = value.translation.width
                let ty = value.translation.height
                if !sidebarOpenAxisLocked {
                    guard abs(tx) >= abs(ty) * 0.55, tx > 0 else { return }
                    sidebarOpenAxisLocked = true
                }
                // Follow the finger with no implicit animation.
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    sidebarOpenDragX = min(sidebarWidth, max(0, tx))
                }
            }
            .onEnded { value in
                defer { sidebarOpenAxisLocked = false }
                guard !startsInDialBand(value.startLocation) else {
                    resetSidebarOpenDrag()
                    return
                }
                let tx = max(value.translation.width, sidebarOpenDragX)
                let predicted = max(value.predictedEndTranslation.width, tx)
                let shouldOpen = tx > sidebarOpenThreshold || predicted > sidebarOpenThreshold * 1.25
                if shouldOpen {
                    settleSidebarOpen()
                } else {
                    sidebarOpenGeneration += 1
                    withAnimation(sidebarOpenSpring) {
                        sidebarOpenDragX = 0
                    }
                }
            }
    }

    private func resetSidebarOpenDrag() {
        sidebarOpenAxisLocked = false
        sidebarOpenGeneration += 1
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            sidebarOpenDragX = 0
        }
    }

    /// Button / automation open — same spring path as a completed edge swipe.
    private func openSidebar(animated: Bool) {
        guard !showDrawer else { return }
        if animated {
            sidebarOpenGeneration += 1
            let gen = sidebarOpenGeneration
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                sidebarOpenDragX = 1
            }
            withAnimation(sidebarOpenSpring) {
                sidebarOpenDragX = sidebarWidth
            } completion: {
                guard gen == sidebarOpenGeneration else { return }
                commitSidebarOpen()
            }
        } else {
            commitSidebarOpen()
        }
    }

    /// Spring the interactive reveal to full width, then mark settled (same drawer instance).
    private func settleSidebarOpen() {
        sidebarOpenGeneration += 1
        let gen = sidebarOpenGeneration
        withAnimation(sidebarOpenSpring) {
            sidebarOpenDragX = sidebarWidth
        } completion: {
            guard gen == sidebarOpenGeneration else { return }
            commitSidebarOpen()
        }
    }

    private func commitSidebarOpen() {
        guard !showDrawer else {
            sidebarOpenDragX = 0
            return
        }
        // Same frame: keep the drawer mounted (`showDrawer || dragX`) while switching
        // from interactiveOpenX → settled. No second slide, no remount flash.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            showDrawer = true
            sidebarOpenDragX = 0
        }
    }

    private func closeSidebarImmediate() {
        sidebarOpenGeneration += 1
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            showDrawer = false
            sidebarOpenDragX = 0
        }
    }

    private func startsInDialBand(_ globalPoint: CGPoint) -> Bool {
        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen.bounds.height
            ?? UIScreen.main.bounds.height
        let band = PlannerChromeMetrics.dialLayoutHeight + 44
        return globalPoint.y >= screenHeight - band
    }

    private var pageContent: some View {
        let page = contentDestination
        return ZStack {
            lazyPage(WheelDestination.today.rawValue, active: page == .today) {
                TodayView(destination: plannerDestination, onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.calendar.rawValue, active: page == .calendar) {
                CalendarPlannerView()
            }
            lazyPage(WheelDestination.meals.rawValue, active: page == .meals) {
                MealPlanView(
                    profile: profile,
                    openShop: $openShopOnMeals,
                    onOpenDrawer: { openSidebar(animated: true) },
                    onShopDismiss: {
                        // Shop is a sheet, not a dial destination — stay on Meals.
                    }
                )
            }
            lazyPage(WheelDestination.matrix.rawValue, active: page == .matrix) {
                MatrixView(onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.habits.rawValue, active: page == .habits) {
                HabitsHomeView(onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.inbox.rawValue, active: page == .inbox) {
                TodayView(destination: .inbox, onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.browse.rawValue, active: page == .browse) {
                BrowseHomeView(onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.spend.rawValue, active: page == .spend) {
                SpendHomeView(onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.health.rawValue, active: page == .health || page == .workout) {
                HealthHomeView(onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.news.rawValue, active: page == .news) {
                NewsHomeView(onOpenDrawer: { openSidebar(animated: true) })
            }
            lazyPage(WheelDestination.focus.rawValue, active: page == .focus) {
                FocusHomeView(onOpenDrawer: { openSidebar(animated: true) })
            }
        }
    }

    @ViewBuilder
    private func lazyPage<C: View>(
        _ id: String,
        active: Bool,
        @ViewBuilder content: () -> C
    ) -> some View {
        if loadedPages.contains(id) || active {
            content()
                .opacity(active ? 1 : 0)
                .allowsHitTesting(active)
                .accessibilityHidden(!active)
                // Instant swap — crossfade made wheel picks feel late.
                .animation(nil, value: active)
        }
    }

    private func handleWheelSelect(_ item: WheelNavItem) {
        guard let dest = WheelDestination(rawValue: item.id) else { return }
        switch dest {
        case .shop:
            openShop()
        case .settings:
            openSettings()
        default:
            selectWheel(dest)
        }
    }

    private func selectWheel(_ dest: WheelDestination) {
        let remapped: WheelDestination = {
            // Workout dial folded into Body (Health).
            if dest == .workout { return .health }
            return dest
        }()
        // Off-wheel apps stay openable from the swipe-up menu; dial only lists on-wheel apps.
        loadedPages.insert(remapped.rawValue)
        selectedWheelId = remapped.rawValue
        if remapped.showsContentPage {
            contentDestination = remapped
        }
        if let legacy = remapped.legacyTabIndex {
            selectedTab = legacy
        }
    }

    private func openShop() {
        // Shop follows Meals; allow via menu even when Meals is off the wheel.
        loadedPages.insert(WheelDestination.meals.rawValue)
        contentDestination = .meals
        selectedTab = WheelDestination.meals.legacyTabIndex ?? 2
        selectedWheelId = WheelDestination.meals.rawValue
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            openShopOnMeals = true
        }
    }

    private func ensureSelectionVisible() {
        guard let dest = WheelDestination(rawValue: selectedWheelId) else {
            selectWheel(.today)
            return
        }
        if dest == .workout {
            selectWheel(.health)
            return
        }
        // Off-wheel apps remain valid (reachable from the app menu). Only bounce unknowns.
        let known = dest.showsContentPage
            || dest == .shop
            || dest == .settings
            || CadenceAppsPreferences.configurable.contains(dest)
            || CadenceAppsPreferences.pinned.contains(dest)
        if !known {
            selectWheel(.today)
        }
    }

    private func openSettings() {
        showSettings = true
    }

    private func migrateLegacySelectionIfNeeded() {
        // If wheel id is missing/invalid or a removed dial destination, map from legacy tab.
        if let dest = WheelDestination(rawValue: selectedWheelId),
           WheelDestination.dialCases.contains(dest) {
            return
        }
        if let dest = WheelDestination.fromLegacyTab(selectedTab) {
            selectedWheelId = dest.rawValue
        } else {
            selectedWheelId = WheelDestination.today.rawValue
        }
    }

    @MainActor
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let tabIndex = args.firstIndex(of: "-openMainTab"),
           tabIndex + 1 < args.count,
           let tab = Int(args[tabIndex + 1]),
           let dest = WheelDestination.fromLegacyTab(tab) {
            selectWheel(dest)
        }

        if args.contains("-openShop") {
            openShop()
        }

        if args.contains("-openGlobalSearch") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                appModel.showGlobalSearchSheet = true
            }
        }

        if args.contains("-openSettings") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                openSettings()
            }
        }

        if let wheelIndex = args.firstIndex(of: "-openWheel"),
           wheelIndex + 1 < args.count {
            let token = args[wheelIndex + 1].lowercased()
            if let dest = WheelDestination(rawValue: token) {
                selectWheel(dest)
            }
        }

        if args.contains("-openSpendCategories")
            || args.contains("-openSpendNewCategory")
            || args.contains("-openSpendCategoryPurchase") {
            selectWheel(.spend)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1100))
                if args.contains("-openSpendCategoryPurchase") {
                    appModel.requestedOpenSpendCategoryPurchase = true
                } else {
                    appModel.requestedOpenSpendCategories = true
                    if args.contains("-openSpendNewCategory") {
                        appModel.requestedOpenSpendNewCategory = true
                    }
                }
            }
        }

        if args.contains("-cadenceSpotCheck") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                for dest in [WheelDestination.today, .calendar, .meals, .matrix, .habits] {
                    selectWheel(dest)
                    print("CADENCE_SPOT_CHECK tab=\(dest.legacyTabIndex ?? -1)")
                    try? await Task.sleep(for: .milliseconds(450))
                }
                openSettings()
                print("CADENCE_SPOT_CHECK settings=open")
                try? await Task.sleep(for: .milliseconds(450))
                showSettings = false
                appModel.showSettingsSheet = false
                selectedWheelId = contentDestination.rawValue
                appModel.showGlobalSearchSheet = true
                print("CADENCE_SPOT_CHECK search=open")
            }
        }
    }
}

// MARK: - Wheel destinations

enum WheelDestination: String, CaseIterable, Identifiable {
    case today
    case calendar
    case meals
    case matrix
    case habits
    case shop
    case inbox
    case browse
    case workout
    case spend
    case health
    case news
    case focus
    case settings

    var id: String { rawValue }

    /// Destinations shown on the rotary dial. Swipe-up menu lists all apps in Wheel / Not on wheel.
    /// Shop and Settings open as sheets from the drawer / Meals, not the dial.
    /// Visibility comes from `CadenceAppsPreferences` (edit grid + Settings → Apps).
    static var dialCases: [WheelDestination] {
        CadenceAppsPreferences.orderedVisibleDialDestinations
    }

    var showsContentPage: Bool {
        switch self {
        case .shop, .settings: return false
        default: return true
        }
    }

    /// Pages that show the shared dial create control (hosted above the wheel in RootView).
    /// Create surfaces only — News / Health / Focus / Meals / Browse use in-page CTAs instead.
    var fabAction: FABAction? {
        switch self {
        case .today, .inbox: return .todayQuickAdd
        case .matrix: return .matrixQuickAdd
        case .calendar: return .addEvent
        case .habits: return .addHabit
        case .spend: return .addSpendItem
        default: return nil
        }
    }

    var legacyTabIndex: Int? {
        switch self {
        case .today: return 0
        case .calendar: return 1
        case .meals, .shop: return 2
        case .matrix: return 3
        case .habits: return 4
        default: return nil
        }
    }

    static func fromLegacyTab(_ index: Int) -> WheelDestination? {
        switch index {
        case 0: return .today
        case 1: return .calendar
        case 2: return .meals
        case 3: return .matrix
        case 4: return .habits
        default: return nil
        }
    }

    var navItem: WheelNavItem {
        switch self {
        case .today:
            return .init(id: rawValue, label: "Today", systemImage: "checkmark.circle")
        case .calendar:
            return .init(id: rawValue, label: "Calendar", systemImage: "calendar")
        case .meals:
            return .init(id: rawValue, label: "Meals", systemImage: "fork.knife")
        case .matrix:
            return .init(id: rawValue, label: "Matrix", systemImage: "square.grid.2x2")
        case .habits:
            return .init(id: rawValue, label: "Habits", systemImage: "repeat")
        case .shop:
            return .init(id: rawValue, label: "Shop", systemImage: "basket")
        case .inbox:
            return .init(id: rawValue, label: "Inbox", systemImage: "tray")
        case .browse:
            return .init(id: rawValue, label: "Browse", systemImage: "book")
        case .workout:
            return .init(id: rawValue, label: "Body", systemImage: "dumbbell")
        case .spend:
            return .init(id: rawValue, label: "Spend", systemImage: "creditcard")
        case .health:
            return .init(id: rawValue, label: "Body", systemImage: "heart.text.square")
        case .news:
            return .init(id: rawValue, label: "News", systemImage: "newspaper")
        case .focus:
            return .init(id: rawValue, label: "Focus", systemImage: "target")
        case .settings:
            return .init(id: rawValue, label: "Settings", systemImage: "gearshape")
        }
    }
}
