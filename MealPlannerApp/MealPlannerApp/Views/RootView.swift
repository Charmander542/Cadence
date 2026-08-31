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
    @AppStorage("main_selected_tab") private var selectedTab = 0
    @Query(sort: \TaskListEntity.sortOrder) private var lists: [TaskListEntity]

    @State private var showDrawer = false
    @State private var showSettings = false
    @State private var openShopOnMeals = false
    @State private var plannerDestination: PlannerDestination = .today
    @State private var showTagManager = false
    @State private var loadedTabs: Set<Int> = [MainTab.today.rawValue]

    private enum MainTab: Int {
        case today = 0
        case calendar = 1
        case meals = 2
        case matrix = 3
        case habits = 4
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            lazyTab(MainTab.today.rawValue) {
                TodayView(destination: plannerDestination, onOpenDrawer: { showDrawer = true })
            } label: {
                Label("Today", systemImage: "checkmark.circle")
            }
            lazyTab(MainTab.calendar.rawValue) {
                CalendarPlannerView()
            } label: {
                Label("Calendar", systemImage: "calendar")
            }
            lazyTab(MainTab.meals.rawValue) {
                MealPlanView(profile: profile, openShop: $openShopOnMeals)
            } label: {
                Label("Meals", systemImage: "fork.knife")
            }
            lazyTab(MainTab.matrix.rawValue) {
                MatrixView()
            } label: {
                Label("Matrix", systemImage: "square.grid.2x2")
            }
            lazyTab(MainTab.habits.rawValue) {
                HabitsHomeView()
            } label: {
                Label("Habits", systemImage: "repeat")
            }
        }
        .tint(Theme.accent)
        .liveWorkoutHost()
        .onChange(of: selectedTab) { _, tab in
            loadedTabs.insert(tab)
        }
        .onChange(of: appModel.requestedMainTab) { _, tab in
            if let tab {
                loadedTabs.insert(tab)
                selectedTab = tab
                appModel.requestedMainTab = nil
            }
        }
        .onChange(of: appModel.requestedOpenShop) { _, shouldOpen in
            if shouldOpen {
                loadedTabs.insert(MainTab.meals.rawValue)
                selectedTab = MainTab.meals.rawValue
                openShopOnMeals = true
                appModel.requestedOpenShop = false
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
                            loadedTabs.insert(MainTab.matrix.rawValue)
                            selectedTab = MainTab.matrix.rawValue
                        case .meals:
                            loadedTabs.insert(MainTab.meals.rawValue)
                            selectedTab = MainTab.meals.rawValue
                        case .shop:
                            loadedTabs.insert(MainTab.meals.rawValue)
                            selectedTab = MainTab.meals.rawValue
                            openShopOnMeals = true
                        default:
                            plannerDestination = dest
                            loadedTabs.insert(MainTab.today.rawValue)
                            selectedTab = MainTab.today.rawValue
                        }
                    },
                    onSettings: {
                        showDrawer = false
                        showSettings = true
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
            TabBarAppearance.apply()
            applyLaunchArguments()
        }
    }

    @ViewBuilder
    private func lazyTab<C: View>(
        _ tag: Int,
        @ViewBuilder content: () -> C,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Group {
            if loadedTabs.contains(tag) {
                content()
            } else {
                Theme.canvas.ignoresSafeArea()
            }
        }
        .tabItem { label() }
        .tag(tag)
    }

    @MainActor
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let tabIndex = args.firstIndex(of: "-openMainTab"),
           tabIndex + 1 < args.count,
           let tab = Int(args[tabIndex + 1]),
           (0...4).contains(tab) {
            loadedTabs.insert(tab)
            selectedTab = tab
        }

        if args.contains("-openShop") {
            loadedTabs.insert(MainTab.meals.rawValue)
            selectedTab = MainTab.meals.rawValue
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                openShopOnMeals = true
            }
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
                showSettings = true
            }
        }

        if args.contains("-cadenceSpotCheck") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                for tab in 0...4 {
                    loadedTabs.insert(tab)
                    selectedTab = tab
                    print("CADENCE_SPOT_CHECK tab=\(tab)")
                    try? await Task.sleep(for: .milliseconds(450))
                }
                showSettings = true
                print("CADENCE_SPOT_CHECK settings=open")
                try? await Task.sleep(for: .milliseconds(450))
                showSettings = false
                appModel.showGlobalSearchSheet = true
                print("CADENCE_SPOT_CHECK search=open")
            }
        }
    }
}
