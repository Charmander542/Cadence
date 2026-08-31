import SwiftUI
import SwiftData

struct GroceryListView: View {
    @Bindable var profile: UserProfileEntity
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \GroceryItemEntity.sortOrder) private var items: [GroceryItemEntity]
    @Query(sort: \PantryItemEntity.name) private var pantryItems: [PantryItemEntity]
    @Query private var plans: [WeeklyPlanEntity]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draftItemNames: [String: String] = [:]
    @State private var settling = Set<PersistentIdentifier>()
    @State private var showPantry = false

    private var canRefreshIngredients: Bool {
        !appModel.isRefreshingGrocery
            && !appModel.isBuildingShopList
            && !appModel.isGeneratingPlan
            && plans.first?.decoded() != nil
    }

    private var pantryNames: Set<String> {
        Set(pantryItems.map { PantryMatcher.key($0.name) })
    }

    private var pantryKeys: Set<String> {
        Set(pantryItems.map { PantryMatcher.key($0.name) })
    }

    private var grouped: [(String, [GroceryItemEntity])] {
        let order = GroceryConsolidator.categoryOrder
        let keys = pantryKeys
        var dict: [String: [GroceryItemEntity]] = [:]
        for item in items where !Self.isStaleBreakfastEggs(item)
            && (item.isManual || !PantryMatcher.covers(item.ingredientName, pantryKeys: keys))
        {
            dict[item.category, default: []].append(item)
        }
        return order.compactMap { cat in
            guard var rows = dict[cat], !rows.isEmpty else { return nil }
            rows.sort {
                let aSettled = $0.isChecked && !settling.contains($0.persistentModelID)
                let bSettled = $1.isChecked && !settling.contains($1.persistentModelID)
                if aSettled != bSettled { return !aSettled && bSettled }
                return $0.ingredientName < $1.ingredientName
            }
            return (cat, rows)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if appModel.isBuildingShopList && grouped.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Building shop list…")
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Building shop list")
                    .accessibilityAddTraits(.updatesFrequently)
                } else if grouped.isEmpty {
                    Theme.EmptyState(
                        systemImage: "basket",
                        title: "Shop list empty",
                        message: groceryEmptyMessage,
                        cta: groceryEmptyCTA,
                        ctaHint: hasMealPlan ? "Generates ingredients from your meal plan" : "Opens Meals tab to create a weekly plan",
                        busy: appModel.isRefreshingGrocery || appModel.isBuildingShopList
                    ) {
                        handleGroceryEmptyAction()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Shop list empty. \(groceryEmptyMessage)")
                } else {
                    ForEach(grouped, id: \.0) { category, rows in
                        Section {
                            ForEach(rows) { item in
                                GroceryRow(item: item) {
                                    toggle(item)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .accessibilityLabel("Delete \(item.ingredientName)")
                                    .accessibilityHint("Removes item from shop list")
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Pantry.toggle(item.ingredientName, in: modelContext)
                                    } label: {
                                        Label("Pantry", systemImage: "cabinet")
                                    }
                                    .tint(.orange)
                                    .accessibilityLabel("Move \(item.ingredientName) to pantry")
                                    .accessibilityHint("Keeps item off future shop lists")
                                }
                            }
                            HStack {
                                TextField("Add item…", text: draftNameBinding(for: category))
                                    .textInputAutocapitalization(.never)
                                    .accessibilityHint("Name of item to add to \(category) section")
                                    .onSubmit { addManual(category: category) }
                                Button("Add") { addManual(category: category) }
                                    .fontWeight(.semibold)
                                    .disabled(draftItemNames[category, default: ""].trimmingCharacters(in: .whitespaces).isEmpty)
                                    .accessibilityHint("Adds typed item to \(category) section")
                            }
                        } header: {
                            Text(category.capitalized)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityLabel(groceryCategoryHeaderLabel(category: category, count: rows.count))
                        }
                    }
                }
            }
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Pantry.seedIfNeeded(in: modelContext)
                        showPantry = true
                    } label: {
                        Label("Pantry", systemImage: "cabinet")
                    }
                    .accessibilityHint("Edit staples kept off the shop list")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshIngredients() }
                    } label: {
                        if appModel.isRefreshingGrocery || appModel.isBuildingShopList {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Rebuild shop list")
                    .accessibilityHint(canRefreshIngredients ? "Regenerates ingredients from your meal plan" : "Requires an active weekly plan")
                    .disabled(!canRefreshIngredients)
                    Menu {
                        ForEach(GroceryConsolidator.categoryOrder, id: \.self) { cat in
                            Button(cat.capitalized) {
                                addManual(category: cat)
                            }
                            .accessibilityHint("Adds custom item to \(cat) section")
                        }
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                    .accessibilityHint("Adds a custom item to a category")
                }
            }
            .overlay {
                if appModel.isRefreshingGrocery {
                    IngredientRefreshOverlay()
                }
            }
            .sheet(isPresented: $showPantry) {
                PantryEditor()
            }
            .task {
                if items.isEmpty, plans.first?.decoded() != nil {
                    _ = appModel.populateShopListIfEmpty(modelContext: modelContext)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
        }
    }

    private static func isStaleBreakfastEggs(_ item: GroceryItemEntity) -> Bool {
        GroceryConsolidator.isLeftoverBreakfastEgg(
            name: item.ingredientName,
            quantity: item.quantity,
            unit: item.unit
        )
    }

    private func refreshIngredients() async {
        _ = await appModel.refreshGroceryFromCurrentPlan(modelContext: modelContext)
    }

    private var hasMealPlan: Bool {
        plans.first?.decoded() != nil
    }

    private var groceryEmptyMessage: String {
        if hasMealPlan {
            return "Your plan is ready — build a shop list from this week’s dinners."
        }
        return "Build a week and we’ll turn dinners into a clean shopping list."
    }

    private var groceryEmptyCTA: String {
        hasMealPlan ? "Build shop list" : "Plan this week"
    }

    private func handleGroceryEmptyAction() {
        if hasMealPlan {
            Task { await refreshIngredients() }
        } else {
            dismiss()
            appModel.requestedMainTab = 2
        }
    }

    private func groceryCategoryHeaderLabel(category: String, count: Int) -> String {
        "\(category.capitalized), \(count) item\(count == 1 ? "" : "s")"
    }

    private func draftNameBinding(for category: String) -> Binding<String> {
        Binding(
            get: { draftItemNames[category, default: ""] },
            set: { draftItemNames[category] = $0 }
        )
    }

    private func toggle(_ item: GroceryItemEntity) {
        if item.isChecked {
            appModel.taskCompletionHaptic()
            var t = Transaction(animation: nil)
            withTransaction(t) {
                settling.remove(item.persistentModelID)
                item.isChecked = false
            }
            try? modelContext.save()
            return
        }
        appModel.taskCompletionHaptic()
        var t = Transaction(animation: nil)
        withTransaction(t) {
            item.isChecked = true
            settling.insert(item.persistentModelID)
        }
        try? modelContext.save()
        let id = item.persistentModelID
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard settling.contains(id) else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                settling.remove(id)
            }
        }
    }

    private func addManual(category: String) {
        let name = draftItemNames[category, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if PantryMatcher.covers(name, pantry: pantryNames) {
            draftItemNames[category] = ""
            return
        }
        let entity = GroceryItemEntity(
            from: ConsolidatedGroceryItem(
                ingredientName: name.lowercased(),
                category: category,
                quantity: 1,
                unit: "count",
                isApproximate: true,
                note: "",
                isChecked: false,
                isManual: true
            ),
            planGeneratedAt: items.first?.planGeneratedAt ?? .now,
            sortOrder: (items.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(entity)
        draftItemNames[category] = ""
        try? modelContext.save()
    }
}

struct GroceryRow: View {
    @Bindable var item: GroceryItemEntity
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline) {
                Theme.CheckGlyph(checked: item.isChecked)
                Text(GroceryConsolidator.displayText(item.asConsolidated()))
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? Theme.muted : Theme.ink)
                Spacer()
                if item.isManual {
                    Text("manual")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(groceryRowAccessibilityLabel)
        .accessibilityHint("Double tap to toggle while shopping")
    }

    private var groceryRowAccessibilityLabel: String {
        let name = GroceryConsolidator.displayText(item.asConsolidated())
        let prefix = item.isChecked ? "Uncheck" : "Check off"
        let manual = item.isManual ? ", manual entry" : ""
        return "\(prefix) \(name)\(manual)"
    }
}

struct PantryEditor: View {
    @Query(sort: \PantryItemEntity.name) private var items: [PantryItemEntity]
    @Query(sort: \GroceryItemEntity.sortOrder) private var groceries: [GroceryItemEntity]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var query = ""

    private var visibleItems: [PantryItemEntity] {
        items.filter { PantryMatcher.matchesQuery($0.name, query: query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("These stay off the shop list. Salt, oil, spices, and other bottles you already keep.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
                Section("Staples") {
                    ForEach(visibleItems) { item in
                        Text(item.name.capitalized)
                            .accessibilityLabel("\(item.name.capitalized), pantry staple")
                            .swipeActions(edge: .leading) {
                                Button {
                                    addToShop(item)
                                } label: {
                                    Label("Add to Shop", systemImage: "cart")
                                }
                                .tint(.green)
                                .accessibilityLabel("Add \(item.name) to shop list")
                                .accessibilityHint("Adds staple to this week's shop list")
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                    try? modelContext.save()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .accessibilityLabel("Remove \(item.name) from pantry")
                                .accessibilityHint("Stops keeping this staple off shop lists")
                            }
                    }
                    if visibleItems.isEmpty, !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("No staples match “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                            .foregroundStyle(Theme.muted)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No staples match \(query.trimmingCharacters(in: .whitespacesAndNewlines))")
                            .accessibilityAddTraits(.isStaticText)
                    }
                    HStack {
                        TextField("Add staple", text: $newName)
                            .accessibilityHint("Staple to keep off future shop lists")
                            .onSubmit { add() }
                        Button("Add") { add() }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityHint("Adds staple to pantry so it stays off the shop list")
                    }
                }
            }
            .navigationTitle("Pantry")
            .searchable(text: $query, prompt: "Salt, spice, oil…")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes pantry editor")
                }
            }
            .onAppear { Pantry.seedIfNeeded(in: modelContext) }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
        }
    }

    private func add() {
        let name = PantryMatcher.key(newName)
        guard !name.isEmpty else { return }
        if !items.contains(where: { PantryMatcher.key($0.name) == name }) {
            modelContext.insert(PantryItemEntity(name: name))
            try? modelContext.save()
        }
        newName = ""
    }

    private func addToShop(_ pantryItem: PantryItemEntity) {
        let key = PantryMatcher.key(pantryItem.name)
        guard !key.isEmpty else { return }
        if let existing = groceries.first(where: { PantryMatcher.key($0.ingredientName) == key }) {
            if existing.isChecked {
                existing.isChecked = false
                try? modelContext.save()
            }
            return
        }
        let entity = GroceryItemEntity(
            from: ConsolidatedGroceryItem(
                ingredientName: key,
                category: IngredientCanonicalizer.category(for: key),
                quantity: 1,
                unit: "count",
                isApproximate: true,
                note: "",
                isChecked: false,
                isManual: true
            ),
            planGeneratedAt: groceries.first?.planGeneratedAt ?? .now,
            sortOrder: (groceries.map(\.sortOrder).max() ?? 0) + 1
        )
        modelContext.insert(entity)
        try? modelContext.save()
    }
}
