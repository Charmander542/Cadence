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

struct OrangeFAB: View {
    var systemImage: String = "plus"
    var accessibilityLabel: String = "Add task"
    var accessibilityHint: String = "Opens quick add"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
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
                    Text("Lists")
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
                        drawerRow("Today", icon: "sun.max", dest: .today, hint: "Shows today’s tasks and habits")
                        drawerRow("Next 7 Days", icon: "calendar", dest: .next7, hint: "Shows tasks due in the next week")
                        drawerRow("Inbox", icon: "tray", dest: .inbox, hint: "Shows tasks without a due date")
                        Divider().overlay(Theme.gridDivider).padding(.vertical, 8)
                        ForEach(navigableLists) { list in
                            listDrawerRow(list)
                        }
                        Button {
                            showNewList = true
                        } label: {
                            Label("New list", systemImage: "plus.circle")
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Creates a custom task list")
                        Divider().overlay(Theme.gridDivider).padding(.vertical, 8)
                        drawerRow("Shop", icon: "basket", dest: .shop, hint: "Opens grocery shop list on Meals tab")
                        Button(action: onManageTags) {
                            Label("Manage tags", systemImage: "number")
                                .foregroundStyle(Theme.accent)
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
                        .foregroundStyle(Theme.accent)
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

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(completed ? Theme.accent : (overdue ? Theme.danger : Theme.muted.opacity(0.45)), lineWidth: 1.6)
                    .frame(width: 22, height: 22)
                if completed {
                    Circle().fill(Theme.accent).frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(completed ? "Mark incomplete" : (overdue ? "Mark complete, overdue task" : "Mark complete"))
        .accessibilityHint(completed ? "Reopens task" : "Marks task complete")
        .accessibilityAddTraits(.isButton)
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
    @State private var editingTask: PlannerTaskEntity?
    @State private var editingHabit: HabitEntity?
    @State private var editingEvent: EventSheetContext?
    @FocusState private var searchFieldFocused: Bool

    private var tokens: [String] {
        query.lowercased().split(separator: " ").map(String.init).filter { $0.count > 1 }
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
        return appModel.recipeDB.search(query, limit: 20)
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
        SettingsSearchMatch.matches(query: query)
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
                    Text("Tasks, habits, events, recipes, shop, and settings")
                        .foregroundStyle(Theme.muted)
                        .accessibilityLabel("Search scope: tasks, habits, events, recipes, shop, and settings")
                        .accessibilityAddTraits(.isStaticText)
                } else if !hasAnyResults {
                    Text("No results for “\(query)”")
                        .foregroundStyle(Theme.muted)
                        .accessibilityLabel("No results for \(query)")
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
}
