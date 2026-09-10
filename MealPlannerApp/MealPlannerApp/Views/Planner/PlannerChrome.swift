import SwiftUI
import SwiftData
import UIKit

struct PlannerTabChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Theme.canvas, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct AppGridExpandedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isAppGridExpanded: Bool {
        get { self[AppGridExpandedKey.self] }
        set { self[AppGridExpandedKey.self] = newValue }
    }
}

enum PlannerChromeMetrics {
    /// Reserved bottom inset so page layout stays put while the dial draws larger on top.
    static let dialLayoutHeight: CGFloat = 72
    static let dialFABTrailingPadding: CGFloat = 22
    /// Distance from the physical bottom edge to the FAB bottom — shared by every page with +.
    /// Negative pulls + down into the dial band (Today’s tight lower placement).
    static let dialFABBottomPadding: CGFloat = -20
}

/// Pins + (and optional leading undo) to the same bottom-trailing spot as the dial overlay.
struct DialFABBar<Leading: View, FAB: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var fab: () -> FAB

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            leading()
            Spacer(minLength: 0)
            fab()
                .padding(.trailing, PlannerChromeMetrics.dialFABTrailingPadding)
        }
        .padding(.bottom, PlannerChromeMetrics.dialFABBottomPadding)
        // Same coordinate space as the dial (ignores bottom safe area / page inset).
        .ignoresSafeArea(edges: .bottom)
    }
}

extension View {
    func dialFABChrome<Leading: View, FAB: View>(
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder fab: @escaping () -> FAB
    ) -> some View {
        overlay(alignment: .bottom) {
            DialFABBar(leading: leading, fab: fab)
        }
    }

    func dialFABChrome<FAB: View>(
        @ViewBuilder fab: @escaping () -> FAB
    ) -> some View {
        dialFABChrome(leading: { EmptyView() }, fab: fab)
    }
}

struct OrangeFAB: View {
    var systemImage: String = "plus"
    var accessibilityLabel: String = "Add task"
    var accessibilityHint: String = "Opens quick add"
    var action: () -> Void
    @Environment(\.isAppGridExpanded) private var isAppGridExpanded

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Theme.cta, in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .opacity(isAppGridExpanded ? 0 : 1)
        .allowsHitTesting(!isAppGridExpanded)
        .accessibilityHidden(isAppGridExpanded)
        .animation(.easeOut(duration: 0.2), value: isAppGridExpanded)
    }
}

struct UndoFAB: View {
    var label: String = "Undo"
    var accessibilityHint: String = "Restores the last completed task"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Theme.flagMedium, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
    }
}

struct PlannerDrawer: View {
    var lists: [TaskListEntity]
    var destination: PlannerDestination
    var onSelect: (PlannerDestination) -> Void
    var onSettings: () -> Void
    var onClose: () -> Void
    var onAddList: (String) -> Void
    var onManageTags: () -> Void
    var onSearch: () -> Void

    @State private var showNewList = false
    @State private var newListName = ""
    @State private var editingList: TaskListEntity?

    private var navigableLists: [TaskListEntity] {
        lists.filter {
            $0.name.lowercased() != "inbox" && !PlannerStore.isLegacyShoppingList($0)
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Menu")
                        .font(Theme.title(.title3))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Close menu")
                    .accessibilityHint("Closes planner drawer")
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        drawerSectionHeader("Views")
                        drawerRow("Today", icon: "sun.max", dest: .today, hint: "Shows today’s tasks and habits")
                        drawerRow("Next 7 Days", icon: "calendar", dest: .next7, hint: "Shows tasks due in the next week")
                        drawerRow("Inbox", icon: "tray", dest: .inbox, hint: "Shows tasks without a due date")
                        Divider().overlay(Theme.gridDivider).padding(.vertical, 8)
                        drawerSectionHeader("Lists")
                        ForEach(navigableLists) { list in
                            listDrawerRow(list)
                        }
                        Button {
                            showNewList = true
                        } label: {
                            Label("New list", systemImage: "plus.circle")
                                .foregroundStyle(Theme.cta)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Creates a custom task list")
                        Divider().overlay(Theme.gridDivider).padding(.vertical, 8)
                        drawerSectionHeader("More")
                        drawerRow("Shop", icon: "basket", dest: .shop, hint: "Opens grocery shop list on Meals tab")
                        Button(action: onManageTags) {
                            Label("Manage tags", systemImage: "number")
                                .foregroundStyle(Theme.cta)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit task tag names and colors")
                    }
                    .padding(.horizontal, 10)
                }

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    Divider().overlay(Theme.gridDivider)
                    Button(action: onSearch) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Search", systemImage: "magnifyingglass")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text("Tasks, habits, events, recipes, shop, and settings")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                                .accessibilityAddTraits(.isStaticText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search. Tasks, habits, events, recipes, shop, and settings")
                    .accessibilityHint("Search tasks, habits, events, recipes, shop items, and settings")
                    .accessibilityIdentifier("global-search-drawer")
                    Divider().overlay(Theme.gridDivider)
                    Button(action: onSettings) {
                        Label("Settings", systemImage: "gearshape")
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings")
                }
            }
            .frame(width: 300, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Theme.surface)
        }
        .alert("New list", isPresented: $showNewList) {
            TextField("List name", text: $newListName)
            Button("Create") {
                onAddList(newListName)
                newListName = ""
            }
            .accessibilityHint("Creates custom task list with entered name")
            Button("Cancel", role: .cancel) { newListName = "" }
                .accessibilityHint("Discards new list")
        } message: {
            Text("Custom lists organize tasks outside Today and Matrix defaults.")
                .accessibilityAddTraits(.isStaticText)
        }
        .sheet(item: $editingList) { list in
            ListSettingsSheet(list: list)
        }
    }

    private func drawerSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func listDrawerRow(_ list: TaskListEntity) -> some View {
        let selected = destination == .list(list.id)
        return HStack(spacing: 0) {
            Button {
                onSelect(.list(list.id))
            } label: {
                HStack {
                    Label(list.name, systemImage: "list.bullet")
                        .font(.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.accent : Theme.ink)
                    Spacer()
                    if list.showInToday {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(selected ? Theme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "\(list.name) list, selected" : "\(list.name) list")
            .accessibilityHint("Opens this task list")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            Button {
                editingList = list
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("List settings for \(list.name)")
            .accessibilityHint("Edit list name and Today visibility")
        }
    }

    private func drawerRow(_ title: String, icon: String, dest: PlannerDestination, hint: String) -> some View {
        let selected = dest == destination
        return Button {
            onSelect(dest)
        } label: {
            Label(title, systemImage: icon)
                .font(.body.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.accent : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(selected ? Theme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "\(title), selected" : title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

struct SettingsGearButton: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Button {
            appModel.showSettingsSheet = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens app settings")
    }
}

struct GlobalSearchButton: View {
    @EnvironmentObject private var appModel: AppModel
    var prominent = false

    var body: some View {
        Button {
            appModel.showGlobalSearchSheet = true
        } label: {
            Group {
                if prominent {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surface, in: Capsule())
                } else {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
        .accessibilityHint("Search tasks, habits, events, recipes, and shop items")
        .accessibilityIdentifier(prominent ? "global-search-prominent" : "global-search-button")
        .accessibilityAddTraits(.isButton)
    }
}

struct PlannerHeaderActions: View {
    var showSearch = true

    var body: some View {
        HStack(spacing: 4) {
            if showSearch {
                GlobalSearchButton()
            }
            SettingsGearButton()
        }
    }
}

/// Opens the planner lists drawer (Today, Inbox, custom lists, search, settings).
struct PlannerMenuButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open menu")
        .accessibilityHint("Opens planner drawer with lists, search, shop, and settings")
    }
}

/// Large-title header with optional trailing toolbar (Meals, Calendar scope picker).
/// Content-first tabs without header actions use `PlannerTitleHeader` instead.
struct PlannerScreenHeader<Trailing: View>: View {
    let title: String
    var onMenu: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, onMenu: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.onMenu = onMenu
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let onMenu {
                PlannerMenuButton(action: onMenu)
            }
            Text(title)
                .font(Theme.display(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            trailing()
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

extension PlannerScreenHeader where Trailing == EmptyView {
    init(title: String, onMenu: (() -> Void)? = nil) {
        self.title = title
        self.onMenu = onMenu
        self.trailing = { EmptyView() }
    }
}

/// Title-only header for content-first tabs (Matrix, Habits).
/// Tabs with actions (Meals, Calendar) use `PlannerScreenHeader` with a trailing toolbar instead.
struct PlannerTitleHeader: View {
    let title: String
    var onMenu: (() -> Void)?

    init(title: String, onMenu: (() -> Void)? = nil) {
        self.title = title
        self.onMenu = onMenu
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let onMenu {
                PlannerMenuButton(action: onMenu)
            }
            Text(title)
                .font(Theme.display(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct PlannerTopBar: View {
    var title: String
    var onMenu: () -> Void
    /// When false, search is omitted from the top bar (e.g. Today uses a prominent pill below the title).
    var showSearchInBar = true
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            PlannerMenuButton(action: onMenu)
            Text(title)
                .font(Theme.display(.largeTitle, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let trailing {
                trailing()
            } else if showSearchInBar {
                GlobalSearchButton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}

struct TaskCheckbox: View {
    var completed: Bool
    var overdue: Bool
    var action: () -> Void

    private let size: CGFloat = 24

    @State private var fillScale: CGFloat = 0
    @State private var checkScale: CGFloat = 0.2
    @State private var checkOpacity: Double = 0
    @State private var burstScale: CGFloat = 0.75
    @State private var burstOpacity: Double = 0
    @State private var pressScale: CGFloat = 1
    @State private var showsFilled = false

    private var ringColor: Color {
        showsFilled ? Theme.accent : (overdue ? Theme.danger : Theme.muted.opacity(0.45))
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                pressScale = 0.86
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                    pressScale = 1
                }
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(burstOpacity), lineWidth: 2.5)
                    .frame(width: size, height: size)
                    .scaleEffect(burstScale)

                Circle()
                    .stroke(ringColor, lineWidth: 1.8)
                    .frame(width: size, height: size)

                if showsFilled {
                    Circle()
                        .fill(Theme.accent.gradient)
                        .frame(width: size, height: size)
                        .scaleEffect(fillScale)
                        .shadow(color: Theme.accent.opacity(0.35), radius: 4, y: 1)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .scaleEffect(checkScale)
                        .opacity(checkOpacity)
                        .rotationEffect(.degrees(checkScale < 1 ? -14 : 0))
                }
            }
            .frame(width: size + 6, height: size + 6)
            .scaleEffect(pressScale)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.68), value: showsFilled)
        .onAppear { applyCompletedState(completed, animated: false) }
        .onChange(of: completed) { _, new in
            if new && !showsFilled {
                playCompleteAnimation()
            } else if !new && showsFilled {
                playUncheckAnimation()
            }
        }
        .accessibilityLabel(completed ? "Mark incomplete" : (overdue ? "Mark complete, overdue task" : "Mark complete"))
        .accessibilityHint(completed ? "Reopens task" : "Marks task complete")
        .accessibilityAddTraits(.isButton)
    }

    private func applyCompletedState(_ isCompleted: Bool, animated: Bool) {
        if isCompleted {
            if animated { playCompleteAnimation() }
            else { setCompletedVisuals(active: true) }
        } else {
            if animated { playUncheckAnimation() }
            else { setCompletedVisuals(active: false) }
        }
    }

    private func playCompleteAnimation() {
        guard !showsFilled else { return }
        showsFilled = true
        fillScale = 0.15
        checkScale = 0.15
        checkOpacity = 0
        burstScale = 0.75
        burstOpacity = 0.7

        withAnimation(.spring(response: 0.32, dampingFraction: 0.56)) {
            fillScale = 1.08
            checkScale = 1.18
            checkOpacity = 1
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74).delay(0.05)) {
            fillScale = 1
            checkScale = 1
        }
        withAnimation(.easeOut(duration: 0.42)) {
            burstScale = 2.1
            burstOpacity = 0
        }
    }

    private func playUncheckAnimation() {
        guard showsFilled else { return }
        burstOpacity = 0
        withAnimation(.easeIn(duration: 0.14)) {
            fillScale = 0.2
            checkScale = 0.2
            checkOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            showsFilled = false
            setCompletedVisuals(active: false)
        }
    }

    private func setCompletedVisuals(active: Bool) {
        showsFilled = active
        fillScale = active ? 1 : 0
        checkScale = active ? 1 : 0.2
        checkOpacity = active ? 1 : 0
        burstOpacity = 0
        burstScale = 0.75
    }
}

enum TabBarAppearance {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .black : .systemBackground
        }
        let orange = UIColor(named: "AccentColor") ?? UIColor(red: 1, green: 0.42, blue: 0, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = orange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: orange]
        let unselected = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.45)
                : .secondaryLabel
        }
        appearance.stackedLayoutAppearance.normal.iconColor = unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = unselected
    }
}

struct CountdownTrackButton: View {
    @Environment(\.modelContext) private var modelContext
    let eventID: UUID
    @State private var trackedRevision = 0

    private var isTracked: Bool {
        _ = trackedRevision
        return CountdownTracking.isTracked(eventID)
    }

    var body: some View {
        Button {
            CountdownTracking.toggle(eventID, in: modelContext)
        } label: {
            Image(systemName: isTracked ? "star.fill" : "star")
                .font(.body.weight(.semibold))
                .foregroundStyle(isTracked ? Theme.accent : Theme.muted.opacity(0.55))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTracked ? "Countdown tracked" : "Track countdown")
        .accessibilityHint(
            isTracked
                ? "Removes this event from the countdown widget"
                : "Shows this event on the countdown widget. Only one event can be tracked."
        )
        .onReceive(NotificationCenter.default.publisher(for: .countdownTrackingDidChange)) { _ in
            trackedRevision += 1
        }
    }
}

struct GlobalSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \PlannerTaskEntity.title) private var tasks: [PlannerTaskEntity]
    @Query(sort: \HabitEntity.name) private var habits: [HabitEntity]
    @Query(sort: \GroceryItemEntity.sortOrder) private var groceryItems: [GroceryItemEntity]

    @State private var query = ""
    @State private var searchQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var editingTask: PlannerTaskEntity?
    @State private var editingHabit: HabitEntity?
    @State private var editingEvent: EventSheetContext?
    @FocusState private var searchFieldFocused: Bool
    @State private var searchRecents: [String] = PlannerPreferences.searchRecents()

    private let searchDebounceMs = 350

    private var tokens: [String] {
        searchQuery.lowercased().split(separator: " ").map(String.init).filter { $0.count > 1 }
    }

    private var matchingTasks: [PlannerTaskEntity] {
        guard !tokens.isEmpty else { return [] }
        return tasks.filter { task in
            let hay = task.title.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .filter { !$0.isEvent }
        .prefix(20)
        .map { $0 }
    }

    private var matchingEvents: [PlannerTaskEntity] {
        guard !tokens.isEmpty else { return [] }
        return tasks.filter { task in
            guard task.isEvent else { return false }
            let hay = task.title.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        .prefix(20)
        .map { $0 }
    }

    private var matchingHabits: [HabitEntity] {
        guard !tokens.isEmpty else { return [] }
        return habits.filter { habit in
            let hay = habit.name.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .prefix(20)
        .map { $0 }
    }

    private var matchingRecipes: [Recipe] {
        guard !tokens.isEmpty else { return [] }
        return appModel.recipeDB.search(searchQuery, limit: 20)
    }

    private var matchingGroceries: [GroceryItemEntity] {
        guard !tokens.isEmpty else { return [] }
        return groceryItems.filter { item in
            let hay = item.ingredientName.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .prefix(20)
        .map { $0 }
    }

    private var matchingSettings: [SettingsSearchMatch] {
        SettingsSearchMatch.matches(query: searchQuery)
    }

    private var isSearching: Bool {
        query.trimmingCharacters(in: .whitespaces) != searchQuery.trimmingCharacters(in: .whitespaces)
    }

    private var hasAnyResults: Bool {
        !matchingTasks.isEmpty
            || !matchingEvents.isEmpty
            || !matchingHabits.isEmpty
            || !matchingRecipes.isEmpty
            || !matchingGroceries.isEmpty
            || !matchingSettings.isEmpty
    }

    private func recipeDisplayName(_ name: String) -> String {
        Theme.recipeDisplayName(name)
    }

    private func globalSearchTaskLabel(_ task: PlannerTaskEntity) -> String {
        if let due = task.dueAt {
            return "\(task.title), due \(PlannerDate.shortDue(due))"
        }
        return task.title
    }

    private func globalSearchEventLabel(_ event: PlannerTaskEntity) -> String {
        if let due = event.dueAt {
            return "\(event.title), event, \(PlannerDate.shortDue(due))"
        }
        return "\(event.title), event"
    }

    private func globalSearchRecipeLabel(_ recipe: Recipe) -> String {
        var parts = [
            recipeDisplayName(recipe.name),
            recipe.course.isEmpty ? "recipe" : recipe.course
        ]
        if !recipe.sourceCitation.isEmpty {
            parts.append(recipe.sourceCitation)
        }
        if recipe.webLink != nil {
            parts.append("web link available")
        }
        return parts.joined(separator: ", ")
    }

    private func globalSearchGroceryLabel(_ item: GroceryItemEntity) -> String {
        let checked = item.isChecked ? "checked off" : "not checked"
        return "\(item.ingredientName), \(item.category), \(checked)"
    }

    private func globalSearchSettingsLabel(_ match: SettingsSearchMatch) -> String {
        "\(match.title), settings, \(match.subtitle)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search tasks, habits, events, recipes, shop, and settings…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($searchFieldFocused)
                        .accessibilityIdentifier("global-search-field")
                        .accessibilityHint("Search across tasks, habits, events, recipes, shop items, and settings")
                }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchEmptyState
                } else if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching…")
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Searching")
                } else if !hasAnyResults {
                    Text("No results for “\(searchQuery)”")
                        .foregroundStyle(Theme.muted)
                        .accessibilityLabel("No results for \(searchQuery)")
                        .accessibilityAddTraits(.isStaticText)
                } else {
                    if !matchingTasks.isEmpty {
                        Section {
                            ForEach(matchingTasks) { task in
                                Button {
                                    editingTask = task
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                            .foregroundStyle(Theme.ink)
                                        if let due = task.dueAt {
                                            Text(PlannerDate.shortDue(due))
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchTaskLabel(task))
                                .accessibilityHint("Opens task editor")
                            }
                        } header: {
                            Text("Tasks")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if !matchingEvents.isEmpty {
                        Section {
                            ForEach(matchingEvents) { event in
                                HStack(spacing: 0) {
                                    CountdownTrackButton(eventID: event.id)
                                    Button {
                                        editingEvent = EventSheetContext(task: event, startDate: event.dueAt ?? .now)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .foregroundStyle(Theme.ink)
                                            if let due = event.dueAt {
                                                Text(PlannerDate.shortDue(due))
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.muted)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(globalSearchEventLabel(event))
                                    .accessibilityHint("Opens event editor")
                                }
                            }
                        } header: {
                            Text("Events")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if !matchingHabits.isEmpty {
                        Section {
                            ForEach(matchingHabits) { habit in
                                Button {
                                    editingHabit = habit
                                } label: {
                                    Text(habit.name)
                                        .foregroundStyle(Theme.ink)
                                }
                                .accessibilityLabel("\(habit.name), habit")
                                .accessibilityHint("Opens habit editor")
                            }
                        } header: {
                            Text("Habits")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if !matchingRecipes.isEmpty {
                        Section {
                            ForEach(matchingRecipes) { recipe in
                                NavigationLink {
                                    RecipeDetailView(
                                        recipe: recipe,
                                        scaledServings: recipe.baseServings,
                                        reason: recipe.course.capitalized,
                                        proteinG: recipe.proteinGPerServing,
                                        calories: recipe.caloriesPerServing
                                    )
                                } label: {
                                    Text(recipeDisplayName(recipe.name))
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchRecipeLabel(recipe))
                                .accessibilityHint("Opens recipe details")
                            }
                        } header: {
                            Text("Recipes")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if !matchingGroceries.isEmpty {
                        Section {
                            ForEach(matchingGroceries, id: \.persistentModelID) { item in
                                Button {
                                    dismiss()
                                    appModel.requestedMainTab = 2
                                    appModel.requestedOpenShop = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.ingredientName)
                                            .foregroundStyle(Theme.ink)
                                        Text(item.category)
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchGroceryLabel(item))
                                .accessibilityHint("Opens shop list on Meals tab")
                            }
                        } header: {
                            Text("Shop")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if !matchingSettings.isEmpty {
                        Section {
                            ForEach(matchingSettings) { match in
                                Button {
                                    appModel.pendingSettingsRoute = match.route
                                    appModel.showSettingsSheet = true
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(match.title)
                                            .foregroundStyle(Theme.ink)
                                        Text(match.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(globalSearchSettingsLabel(match))
                                .accessibilityHint("Opens this settings screen")
                            }
                        } header: {
                            Text("Settings")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("global-search-close")
                        .accessibilityHint("Closes search")
                }
            }
            .onAppear {
                searchFieldFocused = true
            }
            .onChange(of: query) { _, newValue in
                scheduleSearchQuery(newValue)
            }
            .onChange(of: searchQuery) { _, committed in
                if !committed.trimmingCharacters(in: .whitespaces).isEmpty, hasAnyResults {
                    PlannerPreferences.recordSearchQuery(committed)
                    searchRecents = PlannerPreferences.searchRecents()
                }
            }
            .onDisappear { searchDebounceTask?.cancel() }
            .accessibilityIdentifier("global-search-sheet")
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task)
            }
            .sheet(item: $editingHabit) { habit in
                NewHabitSheet(habit: habit)
            }
            .sheet(item: $editingEvent) { context in
                PlannerEventSheet(context: context)
            }
        }
    }

    private var searchEmptyState: some View {
        Group {
            if !searchRecents.isEmpty {
                Section {
                    ForEach(searchRecents, id: \.self) { recent in
                        Button {
                            query = recent
                            searchQuery = recent
                        } label: {
                            Label(recent, systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityHint("Runs this search again")
                    }
                } header: {
                    Text("Recent")
                        .accessibilityAddTraits(.isHeader)
                }
            }
            Section {
                searchQuickJump("Tonight's dinner", icon: "fork.knife") {
                    if let recipe = tonightRecipeName {
                        query = recipe
                        searchQuery = recipe
                    } else {
                        dismiss()
                        appModel.requestedMainTab = 2
                    }
                }
                searchQuickJump("Shop list", icon: "basket") {
                    dismiss()
                    appModel.requestedMainTab = 2
                    appModel.requestedOpenShop = true
                }
                if let workout = WorkoutIntegration.scheduledSession(on: .now, workoutsEnabled: true) {
                    searchQuickJump("\(workout.name) workout", icon: "dumbbell") {
                        query = workout.name
                        searchQuery = workout.name
                    }
                }
                searchQuickJump("Settings", icon: "gearshape") {
                    appModel.showSettingsSheet = true
                    dismiss()
                }
            } header: {
                Text("Quick jumps")
                    .accessibilityAddTraits(.isHeader)
            } footer: {
                Text("Tasks, habits, events, recipes, shop, and settings")
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel("Search scope: tasks, habits, events, recipes, shop, and settings")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var tonightRecipeName: String? {
        guard let plan = try? modelContext.fetch(FetchDescriptor<WeeklyPlanEntity>()).first?.decoded(),
              let dinner = plan.meal(day: MealPlanView.mondayBasedDayIndex(), slot: .dinner),
              let recipe = appModel.recipeDB.recipe(id: dinner.recipeID)
        else { return nil }
        return Theme.recipeDisplayName(recipe.name)
    }

    private func searchQuickJump(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .foregroundStyle(Theme.ink)
        }
        .accessibilityHint("Opens \(title.lowercased())")
    }

    private func scheduleSearchQuery(_ newValue: String) {
        searchDebounceTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searchQuery = ""
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(searchDebounceMs))
            guard !Task.isCancelled else { return }
            searchQuery = newValue
        }
    }
}
