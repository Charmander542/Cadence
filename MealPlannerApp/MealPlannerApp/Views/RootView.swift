import SwiftUI
import SwiftData

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
    @State private var showSettings = false
    @State private var openShopOnMeals = false
    @State private var plannerDestination: PlannerDestination = .today
    @State private var showTagManager = false
    @State private var loadedPages: Set<String> = [WheelDestination.today.rawValue]
    /// Content behind Shop/Settings overlays (those wheel picks open sheets).
    @State private var contentDestination: WheelDestination = .today
    @State private var isAppGridExpanded = false
    /// Live pull-up distance from the dial — drawn in this ZStack so it never resizes the page inset.
    @State private var wheelExpandPull: CGFloat = 0

    private let wheelItems: [WheelNavItem] = WheelDestination.dialCases.map(\.navItem)
    private let appMenuSpring = Animation.spring(response: 0.48, dampingFraction: 0.86)

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
            if !isAppGridExpanded {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    wheelDock
                }
                .ignoresSafeArea(edges: .bottom)
            }

            // Interactive pull-up peek — sibling overlay, not part of the bottom inset.
            if wheelExpandPull > 12, !isAppGridExpanded {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.surface.opacity(min(0.95, wheelExpandPull / 120)))
                        .frame(height: min(wheelExpandPull * 0.85, 160))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Theme.muted.opacity(0.45))
                                .frame(width: 32, height: 4)
                                .padding(.top, 10)
                        }
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }

            // Full-screen overlay (sibling of inset content) so expand never pushes the page.
            ZStack {
                if isAppGridExpanded {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
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
                            onDismiss: {
                                isAppGridExpanded = false
                            }
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(appMenuSpring, value: isAppGridExpanded)
            .allowsHitTesting(isAppGridExpanded)
        }
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
        .onChange(of: appModel.requestedOpenShop) { _, shouldOpen in
            if shouldOpen {
                appModel.requestedOpenShop = false
                openShop()
            }
        }
        .onChange(of: appModel.requestedOpenDrawer) { _, shouldOpen in
            if shouldOpen {
                showDrawer = true
                appModel.requestedOpenDrawer = false
            }
        }
        .onChange(of: appModel.requestedCloseDrawer) { _, shouldClose in
            if shouldClose {
                showDrawer = false
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
        .overlay {
            if appModel.isGeneratingPlan && !appModel.planGeneratingMinimized {
                PlanGeneratingOverlay()
                    .transition(.opacity)
            }
        }
        .overlay {
            if showDrawer {
                PlannerDrawer(
                    lists: lists,
                    destination: plannerDestination,
                    onSelect: { dest in
                        showDrawer = false
                        switch dest {
                        case .matrix:
                            selectWheel(.matrix)
                        case .meals:
                            selectWheel(.meals)
                        case .shop:
                            openShop()
                        default:
                            plannerDestination = dest
                            selectWheel(.today)
                        }
                    },
                    onSettings: {
                        showDrawer = false
                        openSettings()
                    },
                    onClose: { showDrawer = false },
                    onAddList: { name in
                        PlannerStore.addList(named: name, in: modelContext)
                    },
                    onManageTags: {
                        showDrawer = false
                        showTagManager = true
                    },
                    onSearch: {
                        showDrawer = false
                        appModel.showGlobalSearchSheet = true
                    }
                )
                .transition(.opacity)
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
        .animation(.easeInOut(duration: 0.22), value: showDrawer)
        .animation(.easeInOut(duration: 0.28), value: appModel.isGeneratingPlan)
        .safeAreaInset(edge: .top) {
            if appModel.isGeneratingPlan && appModel.planGeneratingMinimized {
                HStack(spacing: 10) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            migrateLegacySelectionIfNeeded()
            loadedPages.insert(selectedWheelId)
            if let dest = WheelDestination(rawValue: selectedWheelId), dest.showsContentPage {
                contentDestination = dest
            } else if let dest = WheelDestination.fromLegacyTab(selectedTab) {
                contentDestination = dest
                selectedWheelId = dest.rawValue
            }
            applyLaunchArguments()
        }
    }

    private var wheelDock: some View {
        WheelNav(
            items: wheelItems,
            selectedId: $selectedWheelId,
            isExpanded: $isAppGridExpanded,
            expandPull: $wheelExpandPull,
            onSelect: handleWheelSelect
        )
        // Soft fade so content remains readable under the dial — not a solid chrome bar.
        // Keep fade inside the fixed dial bounds so safeAreaInset height never changes.
        .background(
            LinearGradient(
                colors: [
                    Theme.canvas.opacity(0),
                    Theme.canvas.opacity(0.35),
                    Theme.canvas.opacity(0.55),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
        .zIndex(2)
    }

    @ViewBuilder
    private var pageContent: some View {
        let page = contentDestination
        ZStack {
            lazyPage(WheelDestination.today.rawValue, active: page == .today) {
                TodayView(destination: plannerDestination, onOpenDrawer: { showDrawer = true })
            }
            lazyPage(WheelDestination.calendar.rawValue, active: page == .calendar) {
                CalendarPlannerView()
            }
            lazyPage(WheelDestination.meals.rawValue, active: page == .meals) {
                MealPlanView(
                    profile: profile,
                    openShop: $openShopOnMeals,
                    onOpenDrawer: { showDrawer = true },
                    onShopDismiss: {
                        // Shop is a sheet, not a dial destination — stay on Meals.
                    }
                )
            }
            lazyPage(WheelDestination.matrix.rawValue, active: page == .matrix) {
                MatrixView(onOpenDrawer: { showDrawer = true })
            }
            lazyPage(WheelDestination.habits.rawValue, active: page == .habits) {
                HabitsHomeView(onOpenDrawer: { showDrawer = true })
            }
            lazyPage(WheelDestination.inbox.rawValue, active: page == .inbox) {
                PlaceholderPageView(
                    title: "Inbox",
                    systemImage: "tray",
                    subtitle: "Tasks without a due date will live here. Placeholder for the wheel demo.",
                    onOpenDrawer: { showDrawer = true },
                    onGoToday: { selectWheel(.today) }
                )
            }
            lazyPage(WheelDestination.browse.rawValue, active: page == .browse) {
                PlaceholderPageView(
                    title: "Browse",
                    systemImage: "book",
                    subtitle: "Cookbook browsing will land here. Placeholder for the wheel demo.",
                    onOpenDrawer: { showDrawer = true },
                    onGoToday: { selectWheel(.today) }
                )
            }
            lazyPage(WheelDestination.workout.rawValue, active: page == .workout) {
                PlaceholderPageView(
                    title: "Workout",
                    systemImage: "dumbbell",
                    subtitle: "Lift sessions and progress will surface here. Placeholder for the wheel demo.",
                    onOpenDrawer: { showDrawer = true },
                    onGoToday: { selectWheel(.today) }
                )
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
                .animation(.easeInOut(duration: 0.18), value: active)
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
        loadedPages.insert(dest.rawValue)
        selectedWheelId = dest.rawValue
        if dest.showsContentPage {
            contentDestination = dest
        }
        if let legacy = dest.legacyTabIndex {
            selectedTab = legacy
        }
    }

    private func openShop() {
        loadedPages.insert(WheelDestination.meals.rawValue)
        contentDestination = .meals
        selectedTab = WheelDestination.meals.legacyTabIndex ?? 2
        selectedWheelId = WheelDestination.meals.rawValue
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            openShopOnMeals = true
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
    case settings

    var id: String { rawValue }

    /// Destinations shown on the rotary dial and swipe-up app grid.
    /// Shop and Settings open as sheets from the drawer / Meals, not the dial.
    static var dialCases: [WheelDestination] {
        allCases.filter { $0 != .shop && $0 != .settings }
    }

    var showsContentPage: Bool {
        switch self {
        case .shop, .settings: return false
        default: return true
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
            return .init(id: rawValue, label: "Workout", systemImage: "dumbbell")
        case .settings:
            return .init(id: rawValue, label: "Settings", systemImage: "gearshape")
        }
    }
}
