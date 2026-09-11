import SwiftUI
import SwiftData

struct MealPlanView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity
    @Binding var openShop: Bool
    var onOpenDrawer: () -> Void = {}
    var onShopDismiss: () -> Void = {}
    @Query private var plans: [WeeklyPlanEntity]
    @Query private var grocery: [GroceryItemEntity]
    @State private var confirmRegenerate = false
    @State private var showShop = false
    @State private var showBrowse = false
    /// Mon=0 … Sun=6 (same as `todayIndex` / plan dayIndex). Never use Calendar weekday (1…7).
    @State private var selectedDay = MealPlanView.mondayBasedDayIndex()
    @State private var swappingDay: Int?
    @State private var cachedPlan: WeeklyPlan?
    @State private var cachedRecipeLookup: [String: Recipe] = [:]

    init(
        profile: UserProfileEntity,
        openShop: Binding<Bool> = .constant(false),
        onOpenDrawer: @escaping () -> Void = {},
        onShopDismiss: @escaping () -> Void = {}
    ) {
        self.profile = profile
        _openShop = openShop
        self.onOpenDrawer = onOpenDrawer
        self.onShopDismiss = onShopDismiss
    }

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var todayIndex: Int { Self.mondayBasedDayIndex() }

    /// Always 0…6 so `dayNames[day]` can never crash (Sat used to be Calendar weekday 7).
    private var safeSelectedDay: Int {
        min(max(selectedDay, 0), dayNames.count - 1)
    }

    /// Convert Calendar weekday (1=Sun … 7=Sat) to Mon=0 … Sun=6.
    static func mondayBasedDayIndex(for date: Date = .now) -> Int {
        let wd = Calendar.current.component(.weekday, from: date)
        return (wd + 5) % 7
    }

    private func dayLabel(_ day: Int) -> String {
        let i = min(max(day, 0), dayNames.count - 1)
        return dayNames[i]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab-specific actions (browse, shop, plan week) — use PlannerScreenHeader, not PlannerTitleHeader.
                PlannerScreenHeader(title: "Meals", onMenu: onOpenDrawer) {
                    HStack(spacing: 4) {
                        Button {
                            showBrowse = true
                        } label: {
                            Image(systemName: "book")
                                .font(.body)
                                .foregroundStyle(Theme.muted)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Browse cookbooks")
                        .accessibilityHint("Search and open recipes from bundled cookbooks")
                        Button {
                            showShop = true
                        } label: {
                            Image(systemName: "basket")
                                .font(.body)
                                .foregroundStyle(Theme.muted)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Shop")
                        .accessibilityHint("Opens your grocery shop list")
                        Button {
                            if grocery.contains(where: { !$0.isChecked }) && !grocery.isEmpty {
                                confirmRegenerate = true
                            } else {
                                Task { await generate() }
                            }
                        } label: {
                            if appModel.isGeneratingPlan {
                                ProgressView()
                                    .frame(width: 36, height: 36)
                            } else {
                                Text(plans.isEmpty ? "PLAN WEEK" : "NEW WEEK")
                                    .font(.caption.weight(.bold))
                                    .tracking(0.6)
                                    .foregroundStyle(Theme.cta)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(appModel.isGeneratingPlan)
                        .accessibilityLabel(plans.isEmpty ? "Plan week" : "Generate new week")
                        .accessibilityHint(plans.isEmpty ? "Creates your first weekly meal plan" : "Replaces current week with a new meal plan")
                    }
                }

                Group {
                    if let plan = cachedPlan {
                        weekScroll(plan: plan, recipes: cachedRecipeLookup)
                    } else {
                        emptyState
                    }
                }
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showBrowse) {
                BrowseView()
            }
            .sheet(isPresented: $showShop, onDismiss: onShopDismiss) {
                GroceryListView(profile: profile)
            }
            .confirmationDialog("Replace this week’s groceries?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
                Button("Generate new plan", role: .destructive) { Task { await generate() } }
                    .accessibilityHint("Replaces current meal plan and clears unchecked shop items")
                Button("Cancel", role: .cancel) {}
                    .accessibilityHint("Keeps current meal plan and shop list")
            } message: {
                Text("Unchecked grocery items will be cleared.")
                    .accessibilityAddTraits(.isStaticText)
            }
            .onAppear {
                selectedDay = todayIndex
                refreshPlanCache()
                // Drawer/shop deep-link may set openShop before this view exists — onChange won't fire.
                if openShop {
                    showShop = true
                    openShop = false
                }
            }
            .onChange(of: plans.count) { _, _ in refreshPlanCache() }
            .onChange(of: plans.first?.planJSON) { _, _ in refreshPlanCache() }
            .onChange(of: openShop) { _, shouldOpen in
                if shouldOpen {
                    showShop = true
                    openShop = false
                }
            }
        }
    }

    private var emptyState: some View {
        // Oura/Garmin empty meals: muted caps cue via meta pills + clear primary CTA.
        Theme.EmptyState(
            systemImage: "fork.knife.circle.fill",
            title: "No meals this week",
            message: "Build seven protein dinners with sides. Your shop list fills in automatically.",
            meta: ["7 DINNERS", "AUTO SHOP"],
            cta: "Build this week",
            ctaHint: "Generates weekly meal plan and shop list",
            busy: appModel.isGeneratingPlan
        ) {
            Task { await generate() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No meals this week. Build seven protein dinners with sides. Your shop list fills in automatically.")
    }

    private func weekScroll(plan: WeeklyPlan, recipes: [String: Recipe]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                if !plan.rationaleSummary.isEmpty {
                    Text(plan.rationaleSummary)
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.Space.xs)
                        .accessibilityAddTraits(.isStaticText)
                }

                dayPicker

                todayHero(plan: plan, recipes: recipes, day: safeSelectedDay)

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Theme.SectionHeader(title: "Rest of week", subtitle: "Tap a day to jump")
                    ForEach(0..<7, id: \.self) { day in
                        if day != safeSelectedDay {
                            dayRow(plan: plan, recipes: recipes, day: day)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                ForEach(0..<7, id: \.self) { day in
                    Theme.DayChip(
                        label: dayLabel(day),
                        selected: day == safeSelectedDay,
                        isToday: day == todayIndex
                    ) {
                        selectedDay = day
                    }
                }
            }
            .padding(.horizontal, Theme.Space.xs / 2)
            .padding(.vertical, Theme.Space.xs / 2)
        }
    }

    @ViewBuilder
    private func todayHero(plan: WeeklyPlan, recipes: [String: Recipe], day: Int) -> some View {
        let dinner = plan.meal(day: day, slot: .dinner)
        let recipe = dinner.flatMap { recipes[$0.recipeID] }
        let side = dinner?.sideRecipeID.flatMap { recipes[$0] }

        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text(day == todayIndex ? "Tonight" : dayLabel(day))
                    .font(Theme.title(.title2))
                Spacer()
                if day == todayIndex { Theme.Pill(text: "Today", emphasized: true) }
            }

            if let dinner, let recipe {
                let plate = MealNutrition.plate(main: recipe, side: side)
                NavigationLink {
                    RecipeDetailView(recipe: recipe, scaledServings: dinner.scaledServings, reason: dinner.reason, proteinG: plate.proteinG, calories: plate.calories, side: side)
                } label: {
                    Theme.HeroPanel(tint: Theme.cta) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                                Theme.Pill(text: "Dinner · cook once", tint: Theme.cta)
                                Text(Theme.recipeDisplayName(recipe.name))
                                    .font(Theme.title(.title3))
                                    .foregroundStyle(Theme.ink)
                                Text(recipe.sourceCitation)
                                    .font(Theme.body(.subheadline))
                                    .foregroundStyle(Theme.muted)
                                HStack(spacing: 8) {
                                    Theme.MetaPill(text: MealNutrition.formatEstimate(plate), tone: .neutral)
                                    if recipe.webLink != nil {
                                        Theme.MetaPill(text: "Link", tone: .accent)
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, Theme.Space.xs)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(mealsHeroAccessibilityLabel(day: day, recipe: recipe, side: side, plate: plate))
                .accessibilityHint("Opens dinner recipe details")

                if let side {
                    NavigationLink {
                        RecipeDetailView(
                            recipe: side,
                            scaledServings: dinner.scaledServings,
                            reason: "",
                            proteinG: side.proteinGPerServing,
                            calories: side.caloriesPerServing
                        )
                    } label: {
                        HStack(spacing: Theme.Space.sm) {
                            Theme.Pill(text: "Side")
                            Text(Theme.recipeDisplayName(side.name))
                                .font(Theme.body(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.md)
                        .background(
                            Theme.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .shadow(color: Theme.cardShadow, radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open side, \(side.name)")
                    .accessibilityHint("Opens side recipe details")
                }

                HStack {
                    Spacer()
                    Button {
                        swappingDay = day
                        Task {
                            _ = await appModel.swapDinner(day: day, plan: plan, profile: profile, modelContext: modelContext)
                            swappingDay = nil
                        }
                    } label: {
                        if swappingDay == day { ProgressView() }
                        else { Label("Swap", systemImage: "arrow.triangle.2.circlepath") }
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel("Swap dinner")
                    .accessibilityHint("Picks a different dinner recipe for this day")
                }
            } else {
                // Garmin/Oura empty meal: icon + title + muted cue + primary CTAs.
                Theme.Card {
                    VStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "fork.knife", tint: Theme.muted, size: 40)
                        Text("No dinner planned")
                            .font(Theme.display(.headline))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("Pick a recipe or swap one in.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                        HStack(spacing: Theme.Space.sm + 2) {
                            Button {
                                swappingDay = day
                                Task {
                                    _ = await appModel.swapDinner(day: day, plan: plan, profile: profile, modelContext: modelContext)
                                    swappingDay = nil
                                }
                            } label: {
                                if swappingDay == day {
                                    ProgressView()
                                } else {
                                    Label("SWAP IN DINNER", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.subheadline.weight(.bold))
                                        .tracking(0.3)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.cta)
                            .accessibilityHint("Picks a new dinner recipe for this day")
                            Theme.SecondaryButton(title: "BROWSE", systemImage: "book") {
                                showBrowse = true
                            }
                            .accessibilityHint("Browse cookbook to assign a recipe")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No dinner planned for \(day == todayIndex ? "tonight" : dayLabel(day)). Swap in dinner or browse cookbooks.")
                    .accessibilityHint("Choose an action below")
                }
            }
        }
    }

    private func dayRow(plan: WeeklyPlan, recipes: [String: Recipe], day: Int) -> some View {
        let dinner = plan.meal(day: day, slot: .dinner)
        let recipe = dinner.flatMap { recipes[$0.recipeID] }
        return Button { selectedDay = day } label: {
            HStack(spacing: Theme.Space.md) {
                Text(dayLabel(day))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(day == todayIndex ? Theme.accent : Theme.ink)
                    .frame(width: 40, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.map { Theme.recipeDisplayName($0.name) } ?? "No dinner")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if let recipe {
                        Text(recipe.sourceCitation)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    } else {
                        Theme.MetaPill(text: "TAP TO PLAN", tone: .cta)
                    }
                }
                Spacer(minLength: 0)
                if day == todayIndex {
                    Theme.Pill(text: "Today", emphasized: true)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(Theme.Space.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(
                        day == todayIndex ? Theme.accent.opacity(0.35) : Theme.hairline,
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.cardShadow, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mealsDayRowLabel(day: day, recipe: recipe))
        .accessibilityHint("Double tap to open day details")
    }

    private func mealsDayRowLabel(day: Int, recipe: Recipe?) -> String {
        let dayName = dayLabel(day)
        if let recipe {
            return "\(dayName), \(Theme.recipeDisplayName(recipe.name)), \(recipe.sourceCitation)"
        }
        return "\(dayName), no dinner planned"
    }

    private func mealsHeroAccessibilityLabel(
        day: Int,
        recipe: Recipe,
        side: Recipe?,
        plate: MacroEstimate
    ) -> String {
        var parts = [
            day == todayIndex ? "Tonight" : dayLabel(day),
            Theme.recipeDisplayName(recipe.name),
            recipe.sourceCitation,
            MealNutrition.formatEstimate(plate)
        ]
        if side != nil { parts.append("side dish included") }
        if recipe.webLink != nil { parts.append("link available") }
        return parts.joined(separator: ", ")
    }

    private func recipeLookup(for plan: WeeklyPlan) -> [String: Recipe] {
        var ids = Set(plan.meals.map(\.recipeID))
        ids.formUnion(plan.meals.compactMap(\.sideRecipeID))
        return Dictionary(
            ids.compactMap { id in
                appModel.recipeDB.recipe(id: id).map { (id, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func refreshPlanCache() {
        guard let entity = plans.first, let plan = entity.decoded() else {
            cachedPlan = nil
            cachedRecipeLookup = [:]
            return
        }
        cachedPlan = plan
        cachedRecipeLookup = recipeLookup(for: plan)
    }

    private func generate() async {
        _ = await appModel.generateWeeklyPlan(profile: profile, modelContext: modelContext, existingGroceryUnchecked: false)
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    let scaledServings: Int
    let reason: String
    var proteinG: Double?
    var calories: Double?
    var side: Recipe?

    @State private var pane = CookPane.main
    @State private var servings: Int
    @State private var checked: Set<String> = []
    @State private var settling: Set<String> = []

    private enum CookPane: String, Hashable {
        case main, side
    }

    init(
        recipe: Recipe,
        scaledServings: Int,
        reason: String,
        proteinG: Double? = nil,
        calories: Double? = nil,
        side: Recipe? = nil
    ) {
        self.recipe = recipe
        self.scaledServings = scaledServings
        self.reason = reason
        self.proteinG = proteinG
        self.calories = calories
        self.side = side
        _servings = State(initialValue: max(1, scaledServings))
    }

    private var active: Recipe {
        pane == .side ? (side ?? recipe) : recipe
    }

    private var cookPaneAccessibilityLabel: String {
        let selected = pane == .main ? "Main dish" : "Side dish"
        return "Recipe pane, \(selected) selected"
    }

    var body: some View {
        let scaled = ServingScaler.scale(active, to: servings)
        let macros = MealNutrition.estimate(active)
        let batch = MealNutrition.batch(active, servings: servings)
        List {
            Section {
                SourceCitationView(recipe: active)
            }

            Section {
                HStack(spacing: Theme.Space.sm) {
                    Theme.MetaPill(text: MealNutrition.formatEstimate(macros), tone: .neutral)
                    Theme.MetaPill(text: "Batch · \(MealNutrition.formatEstimate(batch))", tone: .cta)
                }
                .listRowInsets(EdgeInsets(top: Theme.Space.sm + 2, leading: Theme.Space.lg, bottom: Theme.Space.sm - 2, trailing: Theme.Space.lg))
                LabeledContent("Per serving", value: MealNutrition.formatEstimate(macros))
                LabeledContent("This batch", value: MealNutrition.formatEstimate(batch))
                Stepper("Servings: \(servings)", value: $servings, in: 1...12)
                    .accessibilityLabel("Servings, \(servings)")
                    .accessibilityHint("Adjusts ingredient amounts and batch size")
                if !reason.isEmpty, pane == .main {
                    Text(reason).font(.footnote).foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
            } header: {
                Text("PLATE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }

            ingredientSections(scaled)

            if !active.steps.isEmpty {
                Section {
                    ForEach(active.steps) { step in
                        RecipeStepRow(
                            step: step,
                            scaleFactor: Double(servings) / Double(max(active.baseServings, 1))
                        )
                    }
                } header: {
                    Text("STEPS")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: settling)
        .navigationTitle(Theme.recipeDisplayName(active.name))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            if side != nil {
                Picker("Recipe", selection: $pane) {
                    Text("MAIN").tag(CookPane.main)
                    Text("SIDE").tag(CookPane.side)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.sm)
                .background(.bar)
                .accessibilityLabel(cookPaneAccessibilityLabel)
                .accessibilityHint("Switch between main dish and side recipe")
            }
        }
        .onChange(of: pane) { _, _ in
            checked = []
            settling = []
        }
    }

    @ViewBuilder
    private func ingredientSections(_ lines: [ParsedIngredient]) -> some View {
        let groups = groupedIngredients(lines)
        ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
            Section {
                ForEach(ordered(group.rows), id: \.id) { row in
                    ingredientButton(row)
                }
            } header: {
                Text((group.title ?? "Ingredients").uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func ingredientButton(_ row: IngredientRow) -> some View {
        let isOn = checked.contains(row.id)
        let ing = row.ingredient
        return Button {
            toggleIngredient(row.id)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Theme.CheckGlyph(checked: isOn)
                ingredientColoredLabel(ing, checked: isOn)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ing.display(includePrep: true))
        .accessibilityValue(isOn ? "Checked off" : "Not checked")
        .accessibilityHint("Double tap to toggle while cooking")
    }

    @ViewBuilder
    private func ingredientColoredLabel(_ ing: ParsedIngredient, checked: Bool) -> some View {
        let ink = checked ? Theme.muted : Theme.ink
        let qty = checked ? Theme.muted : Theme.cta
        if ing.toTaste, ing.quantity == nil {
            Text("\((ing.item.isEmpty ? ing.raw : ing.item)) to taste")
                .strikethrough(checked)
                .foregroundStyle(ink)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let quantity = ing.quantity {
                    Text(ParsedIngredient.formatQty(quantity))
                        .fontWeight(.semibold)
                        .foregroundStyle(qty)
                        .strikethrough(checked)
                    if let unit = ing.unit, unit != "each" {
                        Text(unit)
                            .fontWeight(.semibold)
                            .foregroundStyle(qty)
                            .strikethrough(checked)
                    }
                }
                Text(ing.item.isEmpty ? ing.raw : ing.item)
                    .foregroundStyle(ink)
                    .strikethrough(checked)
                if !ing.prep.isEmpty {
                    Text(", \(ing.prep)")
                        .foregroundStyle(Theme.muted)
                        .strikethrough(checked)
                }
                if ing.toTaste, ing.quantity != nil {
                    Text("(to taste)")
                        .foregroundStyle(Theme.muted)
                        .strikethrough(checked)
                }
            }
        }
    }

    private func toggleIngredient(_ id: String) {
        if checked.contains(id) {
            settling.remove(id)
            checked.remove(id)
            return
        }
        checked.insert(id)
        settling.insert(id)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeInOut(duration: 0.28)) {
                settling.remove(id)
            }
        }
    }

    private func ordered(_ rows: [IngredientRow]) -> [IngredientRow] {
        rows.sorted { a, b in
            let aSettled = checked.contains(a.id) && !settling.contains(a.id)
            let bSettled = checked.contains(b.id) && !settling.contains(b.id)
            if aSettled != bSettled { return !aSettled && bSettled }
            return a.index < b.index
        }
    }

    private struct IngredientRow: Identifiable {
        let id: String
        let index: Int
        let ingredient: ParsedIngredient
    }

    private struct IngredientGroup {
        var title: String?
        var rows: [IngredientRow]
    }

    private func groupedIngredients(_ lines: [ParsedIngredient]) -> [IngredientGroup] {
        var groups: [IngredientGroup] = []
        var title: String?
        var rows: [IngredientRow] = []
        for (i, ing) in lines.enumerated() {
            if ing.isSectionHeader {
                if !rows.isEmpty || title != nil {
                    groups.append(IngredientGroup(title: title, rows: rows))
                }
                title = ing.headerTitle
                rows = []
            } else {
                rows.append(IngredientRow(id: "\(i)|\(ing.raw)", index: i, ingredient: ing))
            }
        }
        if !rows.isEmpty || title != nil {
            groups.append(IngredientGroup(title: title, rows: rows))
        }
        if groups.isEmpty {
            groups.append(IngredientGroup(title: "Ingredients", rows: []))
        }
        return groups
    }
}

private struct RecipeStepRow: View {
    let step: RecipeStep
    let scaleFactor: Double

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Text("\(step.stepNumber)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(Theme.cta, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.sm - 2) {
                if !step.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(step.instruction)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(step.ingredients.enumerated()), id: \.offset) { _, line in
                    Text(ServingScaler.scaleLine(line, by: scaleFactor))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.cta)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, Theme.Space.xs / 2)
                }
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stepAccessibilityLabel)
    }

    private var stepAccessibilityLabel: String {
        var parts = ["Step \(step.stepNumber)", step.instruction]
        let ingredients = step.ingredients.map { ServingScaler.scaleLine($0, by: scaleFactor) }
        if !ingredients.isEmpty {
            parts.append("Ingredients: \(ingredients.joined(separator: ", "))")
        }
        return parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: ". ")
    }
}

/// Cookbook + page, with a large open-link control when a URL exists.
struct SourceCitationView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.md) {
                Theme.IconWell(systemImage: "book", tint: Theme.accent, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.cookbookTitle)
                        .font(.headline)
                    if let page = recipe.page, page > 0 {
                        Text("Page \(page)")
                            .font(.title3.weight(.semibold))
                    } else if !recipe.chapter.isEmpty {
                        Text(recipe.chapter)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
            }
            if let url = recipe.webLink {
                Link(destination: url) {
                    Label("Open original recipe", systemImage: "arrow.up.right.square")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm + 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.cta)
                .accessibilityHint("Opens recipe in Safari")
                Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sourceCitationLabel)
        .accessibilityHint(recipe.webLink != nil ? "Open link below for original recipe" : "Recipe source citation")
    }

    private var sourceCitationLabel: String {
        var parts = [recipe.cookbookTitle]
        if let page = recipe.page, page > 0 {
            parts.append("page \(page)")
        } else if !recipe.chapter.isEmpty {
            parts.append(recipe.chapter)
        }
        if recipe.webLink != nil {
            parts.append("web link available")
        }
        return parts.joined(separator: ", ")
    }
}
