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
    @State private var addItemCategory: String?
    @State private var addItemName = ""
    @FocusState private var focusedDraftCategory: String?

    private var canRefreshIngredients: Bool {
        !appModel.isRefreshingGrocery
            && !appModel.isBuildingShopList
            && !appModel.isGeneratingPlan
            && plans.first?.decoded() != nil
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

    private var uncheckedCount: Int {
        let keys = pantryKeys
        return items.filter { item in
            !item.isChecked
                && !Self.isStaleBreakfastEggs(item)
                && (item.isManual || !PantryMatcher.covers(item.ingredientName, pantryKeys: keys))
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                if appModel.isBuildingShopList && grouped.isEmpty {
                    HStack(spacing: Theme.Space.sm + 2) {
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

                    Section {
                        HStack {
                            TextField("Add item…", text: draftNameBinding(for: "produce"))
                                .textInputAutocapitalization(.never)
                                .focused($focusedDraftCategory, equals: "produce")
                                .accessibilityHint("Name of item to add")
                                .onSubmit { addManual(category: "produce") }
                            Button("Add") { addManual(category: "produce") }
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.cta)
                                .disabled(draftItemNames["produce", default: ""].trimmingCharacters(in: .whitespaces).isEmpty)
                                .accessibilityHint("Adds typed item to Produce")
                        }
                    } footer: {
                        Text("Or type a one-off item above.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
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
                                    .tint(Theme.cta)
                                    .accessibilityLabel("Move \(item.ingredientName) to pantry")
                                    .accessibilityHint("Keeps item off future shop lists")
                                }
                            }
                            HStack {
                                TextField("Add item…", text: draftNameBinding(for: category))
                                    .textInputAutocapitalization(.never)
                                    .focused($focusedDraftCategory, equals: category)
                                    .accessibilityHint("Name of item to add to \(category) section")
                                    .onSubmit { addManual(category: category) }
                                Button("Add") { addManual(category: category) }
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.cta)
                                    .disabled(draftItemNames[category, default: ""].trimmingCharacters(in: .whitespaces).isEmpty)
                                    .accessibilityHint("Adds typed item to \(category) section")
                            }
                        } header: {
                            let open = rows.filter { !$0.isChecked || settling.contains($0.persistentModelID) }.count
                            return HStack {
                                Text(category.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(Theme.cta)
                                    .textCase(nil)
                                Spacer()
                                Theme.CountBadge(count: open)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel(groceryCategoryHeaderLabel(category: category, count: rows.count))
                        }
                    }
                }
            }
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Pantry.seedIfNeeded(in: modelContext)
                        showPantry = true
                    } label: {
                        Image(systemName: "cabinet")
                            .foregroundStyle(Theme.cta)
                    }
                    .accessibilityLabel("Pantry")
                    .accessibilityHint("Edit staples kept off the shop list")
                    Button {
                        Task { await refreshIngredients() }
                    } label: {
                        if appModel.isRefreshingGrocery || appModel.isBuildingShopList {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Theme.cta)
                        }
                    }
                    .accessibilityLabel("Rebuild shop list")
                    .accessibilityHint(canRefreshIngredients ? "Regenerates ingredients from your meal plan" : "Requires an active weekly plan")
                    .disabled(!canRefreshIngredients)
                    Menu {
                        ForEach(GroceryConsolidator.categoryOrder, id: \.self) { cat in
                            Button(cat.capitalized) {
                                beginAddItem(category: cat)
                            }
                            .accessibilityHint("Add a custom item under \(cat)")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.cta)
                    }
                    .accessibilityLabel("Add item")
                    .accessibilityHint("Choose a category, then enter an item name")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: Theme.Space.sm) {
                    HStack {
                        Button("DONE") { dismiss() }
                            .font(.caption.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.cta)
                            .accessibilityLabel("Done")
                            .accessibilityHint("Closes shop and returns to Meals")
                            .accessibilityIdentifier("shop-done")
                        Spacer()
                        if !grouped.isEmpty {
                            Text(uncheckedCount == 0 ? "ALL PICKED UP" : "\(uncheckedCount) LEFT")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(uncheckedCount == 0 ? Theme.accent : Theme.muted)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if !items.isEmpty {
                        let total = max(items.filter { !Self.isStaleBreakfastEggs($0) }.count, 1)
                        let done = total - uncheckedCount
                        Theme.ProgressTrack(
                            progress: Double(max(done, 0)) / Double(total),
                            tint: uncheckedCount == 0 ? Theme.accent : Theme.cta,
                            height: 6
                        )
                        .accessibilityLabel("Shopping progress")
                        .accessibilityValue("\(max(done, 0)) of \(total) items checked")
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.sm + 2)
                .background(Theme.canvas.opacity(0.95))
            }
            .overlay {
                if appModel.isRefreshingGrocery {
                    IngredientRefreshOverlay()
                }
            }
            .sheet(isPresented: $showPantry) {
                PantryEditor()
            }
            .alert("Add item", isPresented: Binding(
                get: { addItemCategory != nil },
                set: { if !$0 { addItemCategory = nil; addItemName = "" } }
            )) {
                TextField("Item name", text: $addItemName)
                    .textInputAutocapitalization(.never)
                Button("Add") {
                    if let cat = addItemCategory {
                        draftItemNames[cat] = addItemName
                        addManual(category: cat)
                    }
                    addItemCategory = nil
                    addItemName = ""
                }
                .disabled(addItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Adds the named item to the chosen category")
                Button("Cancel", role: .cancel) {
                    addItemCategory = nil
                    addItemName = ""
                }
            } message: {
                if let cat = addItemCategory {
                    Text("Adds to \(cat.capitalized).")
                }
            }
            .task {
                if items.isEmpty, plans.first?.decoded() != nil {
                    _ = appModel.populateShopListIfEmpty(modelContext: modelContext)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .scrollDismissesKeyboard(.interactively)
            .cadenceDismissKeyboardOnTap()
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

    private func beginAddItem(category: String) {
        // Prefer focusing the inline field when that section already exists.
        if grouped.contains(where: { $0.0 == category }) {
            focusedDraftCategory = category
            return
        }
        addItemName = ""
        addItemCategory = category
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
        // Explicit manual adds always land on the list (even if also in pantry).
        let key = name.lowercased()
        if let existing = items.first(where: { PantryMatcher.key($0.ingredientName) == PantryMatcher.key(key) }) {
            if existing.isChecked {
                existing.isChecked = false
            }
            existing.isManual = true
            // Manual entries represent a concrete item the user typed,
            // so they should not be labeled "to taste" just because they are "approximate".
            existing.isApproximate = false
            draftItemNames[category] = ""
            try? modelContext.save()
            return
        }
        let entity = GroceryItemEntity(
            from: ConsolidatedGroceryItem(
                ingredientName: key,
                category: category,
                quantity: 1,
                unit: "count",
                // Manual adds should look like concrete quantities (not "to taste").
                isApproximate: false,
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
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm + 2) {
                Theme.CheckGlyph(checked: item.isChecked)
                Text(nameLabel)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? Theme.muted : (item.isManual ? Theme.cta : Theme.ink))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Space.sm)
                // Centr/Amazon: bold trailing qty for aisle scan; blue reserved for CTAs.
                Text(quantityLabel)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(item.isChecked ? Theme.muted : Theme.ink)
                    .strikethrough(item.isChecked)
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

    private var nameLabel: String {
        let c = item.asConsolidated()
        if c.isApproximate || c.unit == "to_taste" {
            return c.ingredientName.capitalized
        }
        if let peeled = IngredientCanonicalizer.peelEmbeddedMeasure(from: c.ingredientName) {
            let cleaned = IngredientCanonicalizer.canonicalize(peeled.rest)
            return (cleaned.isEmpty ? c.ingredientName : cleaned).capitalized
        }
        return c.ingredientName.capitalized
    }

    private var quantityLabel: String {
        let c = item.asConsolidated()
        if c.isApproximate || c.unit == "to_taste" {
            return "to taste"
        }
        let qty = GroceryConsolidator.formatQty(c.quantity)
        let n = Int(c.quantity.rounded(.up))
        switch c.unit {
        case "count":
            // Produce counts stay numeric ("2" · Onion). Proteins should already
            // be cans/fillets/lb from consolidation — if not, show a clear piece label.
            if c.category == "protein" {
                return "\(qty) pc"
            }
            return qty
        case "to_taste":
            return "to taste"
        case "can":
            return "\(qty) can\(n == 1 ? "" : "s")"
        case "jar":
            return "\(qty) jar\(n == 1 ? "" : "s")"
        case "package":
            return "\(qty) pkg"
        case "fillet":
            return "\(qty) fillet\(n == 1 ? "" : "s")"
        case "block":
            return "\(qty) block\(n == 1 ? "" : "s")"
        case "bottle":
            return "\(qty) bottle\(n == 1 ? "" : "s")"
        case "bunch":
            return "\(qty) bunch\(n == 1 ? "" : "es")"
        case "head":
            return "\(qty) head\(n == 1 ? "" : "s")"
        case "bag":
            return "\(qty) bag\(n == 1 ? "" : "s")"
        default:
            return "\(qty) \(c.unit)"
        }
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
                Section {
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
                        VStack(spacing: Theme.Space.sm) {
                            Theme.IconWell(systemImage: "magnifyingglass", tint: Theme.muted, size: 40)
                            Text("NO MATCHES")
                                .font(.caption2.weight(.bold))
                                .tracking(0.6)
                                .foregroundStyle(Theme.muted)
                            Text("No staples match “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No staples match \(query.trimmingCharacters(in: .whitespacesAndNewlines))")
                        .accessibilityAddTraits(.isStaticText)
                    }
                    HStack {
                        TextField("Add staple", text: $newName)
                            .accessibilityHint("Staple to keep off future shop lists")
                            .onSubmit { add() }
                        Button("Add") { add() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.cta)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityHint("Adds staple to pantry so it stays off the shop list")
                    }
                } header: {
                    Text("STAPLES")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .navigationTitle("Pantry")
            .searchable(text: $query, prompt: "Salt, spice, oil…")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cta)
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
