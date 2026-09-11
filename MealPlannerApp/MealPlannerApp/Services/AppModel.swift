import Foundation
import SwiftData
import SwiftUI
import UIKit
import AudioToolbox

@MainActor
final class AppModel: ObservableObject {
    let recipeDB = RecipeDatabase.shared
    let llm = LLMClient()
    private var didRefreshGroceryThisSession = false
    private var didAttemptShopPopulate = false
    private var workoutTicker: Timer?

    @Published var isGeneratingPlan = false
    @Published var planGeneratingMinimized = false
    @Published var showSettingsSheet = false
    @Published var pendingSettingsRoute: SettingsRoute?
    @Published var showGlobalSearchSheet = false
    /// When set, `MainTabView` switches tabs then clears this value.
    @Published var requestedMainTab: Int?
    /// When set, `MainTabView` selects a wheel destination by raw id (e.g. `spend`) then clears.
    @Published var requestedWheelId: String?
    /// When set, `MainTabView` opens the shop list on Meals then clears.
    @Published var requestedOpenShop = false
    /// When set, `MainTabView` opens the planner drawer then clears.
    @Published var requestedOpenDrawer = false
    /// When set, `MainTabView` closes the planner drawer then clears.
    @Published var requestedCloseDrawer = false
    /// When set, the active page opens its FAB action (quick add / event / habit) then clears.
    @Published var requestedFABAction: FABAction?
    @Published var generatingStatus = "Planning your week"
    @Published var isBuildingShopList = false
    @Published var isRefreshingGrocery = false
    @Published var isComputingMacros = false
    @Published var errorMessage: String?
    /// In-progress workout survives tab switches; only Finish clears it.
    @Published var liveWorkout: LiveWorkoutController?
    /// Whether the Workout tab should push the active session screen.
    @Published var showLiveWorkout = false
    @Published var selectedProvider: AIProvider = KeychainStore.selectedProvider {
        didSet { KeychainStore.selectedProvider = selectedProvider }
    }
    @Published var anthropicKeyDraft: String = KeychainStore.loadAPIKey(for: .anthropic) ?? ""
    @Published var openAIKeyDraft: String = KeychainStore.loadAPIKey(for: .openai) ?? ""

    var activeKeyDraft: String {
        get {
            switch selectedProvider {
            case .anthropic: return anthropicKeyDraft
            case .openai: return openAIKeyDraft
            }
        }
        set {
            switch selectedProvider {
            case .anthropic: anthropicKeyDraft = newValue
            case .openai: openAIKeyDraft = newValue
            }
        }
    }

    func saveAPIKeys() throws {
        try KeychainStore.saveAPIKey(
            anthropicKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            for: .anthropic
        )
        try KeychainStore.saveAPIKey(
            openAIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            for: .openai
        )
        KeychainStore.selectedProvider = selectedProvider
    }

    func hasKeyForSelectedProvider() -> Bool {
        let key: String
        switch selectedProvider {
        case .anthropic: key = anthropicKeyDraft
        case .openai: key = openAIKeyDraft
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains("YOUR_")
    }

    func applyMacroResponse(_ response: ProfileAIService.MacroResponse, to profile: UserProfileEntity) {
        profile.bmr = response.bmr
        profile.tdee = response.tdee
        profile.targetCalories = response.target_calories
        profile.targetProteinG = response.target_protein_g
        profile.targetCarbsG = response.target_carbs_g
        profile.targetFatG = response.target_fat_g
        profile.rationale = response.rationale
        profile.updatedAt = .now
    }

    func recomputeMacros(profile: UserProfileEntity, useAI: Bool = false) async {
        isComputingMacros = true
        errorMessage = nil
        defer { isComputingMacros = false }
        if useAI, hasKeyForSelectedProvider() {
            do {
                let payload = ProfileAIService.ProfilePayload(
                    weight_lbs: profile.weightLbs,
                    height_inches: profile.heightInches,
                    age: profile.age,
                    sex: profile.sexRaw,
                    activity_level: profile.activityRaw,
                    goal: profile.goalRaw,
                    servings_per_recipe: profile.servingsPerRecipe,
                    dietary_restrictions_text: profile.dietaryRestrictionsText
                )
                try saveAPIKeys()
                let response = try await ProfileAIService.computeMacros(client: llm, profile: payload)
                applyMacroResponse(response, to: profile)
                profile.onboardingComplete = true
                return
            } catch {
                errorMessage = "AI macros failed — used the local estimate. \(error.localizedDescription)"
            }
        }
        LocalMacros.apply(LocalMacros.compute(profile: profile), to: profile)
        profile.onboardingComplete = true
    }

    func generateWeeklyPlan(
        profile: UserProfileEntity,
        modelContext: ModelContext,
        existingGroceryUnchecked: Bool
    ) async -> Bool {
        isGeneratingPlan = true
        planGeneratingMinimized = false
        errorMessage = nil
        defer { isGeneratingPlan = false }

        do {
            if profile.targetCalories <= 0 || profile.targetProteinG <= 0 {
                LocalMacros.apply(LocalMacros.compute(profile: profile), to: profile)
            }
            profile.dietaryFilters = DislikeMatcher.parse(profile.dietaryRestrictionsText)

            let historyWindow = max(40, profile.recipeCooldownDays + 14)
            let history = RecipeHistory.loadRecent(in: modelContext, withinDays: historyWindow)
            let banned = Set(
                history.filter {
                    let days = Calendar.current.dateComponents([.day], from: $0.usedAt, to: .now).day ?? 0
                    return days < profile.recipeCooldownDays
                }.map(\.recipeID)
            )

            generatingStatus = "Reading the cookbooks…"
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(200))

            let settings = WeekPlanner.Settings(profile)
            let bannedCopy = banned
            generatingStatus = "Picking dinners that share a shop list…"
            let result = await Task.detached(priority: .userInitiated) {
                WeekPlanner.plan(
                    store: RecipeDatabase.shared,
                    settings: settings,
                    bannedIDs: bannedCopy,
                    days: 7
                )
            }.value
            generatingStatus = "Pairing sides…"
            await Task.yield()
            guard !result.mains.isEmpty else {
                errorMessage = "Not enough main recipes after your filters."
                return false
            }

            let recipesByID = recipeDB.recipesByID()
            var sideByDay: [Int: Recipe] = [:]
            for day in 0..<min(7, result.mains.count) {
                let main = result.mains[day]
                if result.sides.indices.contains(day) {
                    let side = result.sides[day]
                    if side.id != main.id { sideByDay[day] = side }
                }
            }

            if hasLLMKey {
                generatingStatus = "Asking the coach about sides…"
                let candidates: [SidePairingAIService.Candidate] = Array(
                    Set(result.sides.map(\.id) + SideCatalog.entries.compactMap { entry -> String? in
                        // Pull a few catalog-matching recipes from the DB for the model.
                        recipeDB.allRecipes().first { SideCatalog.match($0)?.slug == entry.slug }?.id
                    })
                ).compactMap { id in
                    guard let r = recipesByID[id] ?? recipeDB.recipe(id: id) else { return nil }
                    return SidePairingAIService.Candidate(
                        id: r.id,
                        name: r.name,
                        kind: SideCatalog.match(r)?.kind.rawValue
                    )
                }
                // Also include a broader side pool.
                let extraCandidates = recipeDB.allRecipes()
                    .filter { $0.course == "side" || SideCatalog.match($0) != nil }
                    .prefix(40)
                    .map {
                        SidePairingAIService.Candidate(
                            id: $0.id,
                            name: $0.name,
                            kind: SideCatalog.match($0)?.kind.rawValue
                        )
                    }
                let allCandidates = Dictionary(
                    (candidates + extraCandidates).map { ($0.id, $0) },
                    uniquingKeysWith: { first, _ in first }
                ).values.map { $0 }
                let dayPicks: [SidePairingAIService.DayPick] = (0..<min(7, result.mains.count)).map { day in
                    let main = result.mains[day]
                    let side = sideByDay[day]
                    return SidePairingAIService.DayPick(
                        day: day,
                        main_id: main.id,
                        main_name: main.name,
                        side_id: side?.id,
                        side_name: side?.name,
                        protein: Array(WeekPlanner.flavor(main).proteins)
                    )
                }
                if let refined = try? await SidePairingAIService.refine(
                    client: llm,
                    days: dayPicks,
                    candidates: allCandidates
                ) {
                    for (day, sideID) in refined {
                        if let side = recipesByID[sideID] ?? recipeDB.recipe(id: sideID),
                           side.id != result.mains[day].id {
                            sideByDay[day] = side
                        }
                    }
                }
            }

            let batch = profile.servingsPerRecipe
            var meals: [PlannedMeal] = []
            let days = 7
            for day in 0..<days {
                let main = result.mains[day % result.mains.count]
                let side = sideByDay[day % max(result.mains.count, 1)]
                let sideID = side?.id
                let plate = MealNutrition.plate(main: main, side: side)
                let reason = "Protein dinner with a plate-ready side."
                meals.append(
                    PlannedMeal(
                        dayIndex: day,
                        slot: .dinner,
                        recipeID: main.id,
                        reason: reason,
                        scaledServings: batch,
                        proteinG: plate.proteinG > 0 ? plate.proteinG : nil,
                        calories: plate.calories > 0 ? plate.calories : nil,
                        sideRecipeID: sideID
                    )
                )
            }

            let overlap = result.scores["ingredient_overlap"].map { String(format: "%.0f%% shared pantry", $0 * 100) } ?? ""
            let diversity = result.scores["flavor_diversity"].map { String(format: "%.0f%% flavor spread", $0 * 100) } ?? ""
            let summary = [overlap, diversity].filter { !$0.isEmpty }.joined(separator: " · ")
            let plan = WeeklyPlan(
                generatedAt: .now,
                meals: meals,
                rationaleSummary: summary.isEmpty
                    ? "A week of dinners with overlapping groceries."
                    : "Seven dinners. \(summary).",
                breakfasts: [],
                scores: result.scores
            )

            generatingStatus = "Saving your week…"
            await Task.yield()
            let cleanPlan = plan.strippingBreakfast()
            let source = grocerySource(from: cleanPlan)
            try persistPlan(cleanPlan, in: modelContext)
            try RecipeHistory.record(recipes: source.recipes, in: modelContext, at: plan.generatedAt)
            try modelContext.save()
            await PlannerSyncCoordinator.shared.mealPlanDidChange(cleanPlan, in: modelContext)
            isGeneratingPlan = false

            isBuildingShopList = true
            defer { isBuildingShopList = false }
            let groceries = await buildShopList(
                from: source.recipes,
                scaledServings: source.scaleMap,
                cookingComplexity: profile.cookingComplexity
            )
            try persistGroceries(
                for: cleanPlan,
                in: modelContext,
                groceries: groceries,
                cookingComplexity: profile.cookingComplexity
            )
            try modelContext.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func swapDinner(
        day: Int,
        plan: WeeklyPlan,
        profile: UserProfileEntity,
        modelContext: ModelContext
    ) async -> Bool {
        guard let current = plan.meal(day: day, slot: .dinner),
              let currentRecipe = recipeDB.recipe(id: current.recipeID)
        else { return false }
        let keep = plan.meals.filter { $0.slot == .dinner && $0.dayIndex != day }
            .compactMap { recipeDB.recipe(id: $0.recipeID) }
        let history = RecipeHistory.loadRecent(in: modelContext, withinDays: profile.recipeCooldownDays)
        let banned = Set(history.map(\.recipeID))
        guard let next = WeekPlanner.swapMain(
            current: currentRecipe,
            keep: keep,
            store: recipeDB,
            profile: profile,
            bannedIDs: banned
        ) else {
            errorMessage = "No good swap found."
            return false
        }
        var meals = plan.meals
        // Re-pair a side that fits the new main (don't keep a leftover mismatch).
        let usedKinds = Set(
            plan.meals.filter { $0.slot == .dinner && $0.dayIndex != day }
                .compactMap { $0.sideRecipeID }
                .compactMap { recipeDB.recipe(id: $0) }
                .compactMap { SideCatalog.match($0)?.kind }
        )
        let sidePool = recipeDB.allRecipes().filter {
            ($0.course == "side" || SideCatalog.match($0) != nil)
                && $0.id != next.id
                && !WeekPlanner.looksLikeBreakfast($0)
        }
        let newSide = sidePool.max { a, b in
            SideCatalog.score(
                side: a,
                mainProteins: WeekPlanner.flavor(next).proteins,
                usedKinds: usedKinds,
                usedSideIDs: []
            ) < SideCatalog.score(
                side: b,
                mainProteins: WeekPlanner.flavor(next).proteins,
                usedKinds: usedKinds,
                usedSideIDs: []
            )
        }
        let sideID = newSide?.id
        let plate = MealNutrition.plate(main: next, side: newSide)
        for i in meals.indices where meals[i].dayIndex == day && meals[i].slot == .dinner {
            meals[i] = PlannedMeal(
                dayIndex: day,
                slot: .dinner,
                recipeID: next.id,
                reason: "Swapped in for variety.",
                scaledServings: meals[i].scaledServings,
                proteinG: plate.proteinG > 0 ? plate.proteinG : nil,
                calories: plate.calories > 0 ? plate.calories : nil,
                sideRecipeID: sideID
            )
        }
        // Drop any legacy leftover-lunch row for this day.
        meals.removeAll { $0.dayIndex == day && $0.slot == .lunch }
        let updated = WeeklyPlan(
            generatedAt: plan.generatedAt,
            meals: meals,
            rationaleSummary: plan.rationaleSummary,
            breakfasts: [],
            scores: plan.scores
        )
        do {
            try persistGrocery(for: updated.strippingBreakfast(), in: modelContext, preservingUserEdits: true)
            try modelContext.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Rebuild shop from dinners/sides when leftover breakfast egg staples were
    /// purged or the week still has legacy breakfast baked in.
    func refreshGroceryFromSavedPlanIfNeeded(modelContext: ModelContext) {
        guard !didRefreshGroceryThisSession else { return }
        didRefreshGroceryThisSession = true
        let purged = purgeLeftoverBreakfastEggs(in: modelContext)
        if purged { try? modelContext.save() }
        let plans = (try? modelContext.fetch(FetchDescriptor<WeeklyPlanEntity>())) ?? []
        guard let entity = plans.first, let plan = entity.decoded() else { return }
        guard purged || plan.hasLegacyBreakfast else { return }
        do {
            try persistGrocery(for: plan.strippingBreakfast(), in: modelContext, preservingUserEdits: true)
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete every leftover “18 eggs” breakfast staple from Shop. Returns true if any were removed.
    @discardableResult
    func purgeLeftoverBreakfastEggs(in modelContext: ModelContext) -> Bool {
        let existing = (try? modelContext.fetch(FetchDescriptor<GroceryItemEntity>())) ?? []
        var removed = false
        for item in existing where Self.isLeftoverBreakfastEgg(item) {
            modelContext.delete(item)
            removed = true
        }
        return removed
    }

    /// Fast local shop rebuild when the list is empty but a meal plan exists (no spinner overlay).
    @discardableResult
    func populateShopListIfEmpty(modelContext: ModelContext) -> Bool {
        guard !didAttemptShopPopulate else { return false }
        guard !isRefreshingGrocery, !isBuildingShopList else { return false }
        let existing = (try? modelContext.fetch(FetchDescriptor<GroceryItemEntity>())) ?? []
        guard existing.isEmpty else { return false }
        let plans = (try? modelContext.fetch(FetchDescriptor<WeeklyPlanEntity>())) ?? []
        guard let entity = plans.first, let plan = entity.decoded() else { return false }
        didAttemptShopPopulate = true
        do {
            try persistGrocery(for: plan.strippingBreakfast(), in: modelContext, preservingUserEdits: false)
            try modelContext.save()
            return true
        } catch {
            didAttemptShopPopulate = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Rebuild the shop list from dinner/side recipes for the saved week.
    func refreshGroceryFromCurrentPlan(modelContext: ModelContext) async -> Bool {
        didAttemptShopPopulate = false
        isRefreshingGrocery = true
        errorMessage = nil
        defer { isRefreshingGrocery = false }
        let plans = (try? modelContext.fetch(FetchDescriptor<WeeklyPlanEntity>())) ?? []
        guard let plan = plans.first?.decoded() else {
            errorMessage = "Build a week first — there’s nothing to refresh."
            return false
        }
        do {
            let clean = plan.strippingBreakfast()
            let source = grocerySource(from: clean)
            let profile = ((try? modelContext.fetch(FetchDescriptor<UserProfileEntity>())) ?? []).first
            let complexity = profile?.cookingComplexity ?? 3
            let groceries = await buildShopList(
                from: source.recipes,
                scaledServings: source.scaleMap,
                cookingComplexity: complexity
            )
            try persistGroceries(
                for: clean,
                in: modelContext,
                preservingUserEdits: true,
                groceries: groceries,
                cookingComplexity: complexity
            )
            try modelContext.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var hasLLMKey: Bool {
        guard let key = KeychainStore.loadAPIKey(for: selectedProvider) else { return false }
        return !key.isEmpty && !key.contains("YOUR_")
    }

    // MARK: - Live workout (tab-safe)

    func beginLiveWorkout(session: WorkoutSessionTemplate, plan: WorkoutPlanState) {
        let exercises = WorkoutProgression.buildActiveExercises(session: session, plan: plan)
        liveWorkout = LiveWorkoutController(session: session, exercises: exercises)
        showLiveWorkout = true
        startWorkoutTicker()
    }

    func resumeLiveWorkout() {
        guard liveWorkout != nil else { return }
        showLiveWorkout = true
        startWorkoutTicker()
    }

    func discardLiveWorkoutNavigation() {
        // Keep sets/timer; only pop the screen.
        showLiveWorkout = false
    }

    func minimizePlanGeneratingOverlay() {
        planGeneratingMinimized = true
    }

    func taskCompletionHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func startRest(seconds: Int) {
        guard let live = liveWorkout else { return }
        live.restTotal = max(1, seconds)
        live.restRemaining = max(1, seconds)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        startWorkoutTicker()
    }

    func skipRest() {
        guard let live = liveWorkout, live.restRemaining != 0 else { return }
        live.restRemaining = 0
        workoutTicker?.invalidate()
        workoutTicker = nil
    }

    func clearLiveWorkout() {
        workoutTicker?.invalidate()
        workoutTicker = nil
        liveWorkout = nil
        showLiveWorkout = false
    }

    func liveExercise(id: String) -> LiveExerciseController? {
        liveWorkout?.exercises.first(where: { $0.id == id })
    }

    func updateLiveSet(exerciseID: String, setID: Int, _ update: (inout ActiveSetRow) -> Void) {
        guard let exercise = liveExercise(id: exerciseID) else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            exercise.updateSet(id: setID, update)
            liveWorkout?.refreshCompletedCount()
        }
    }

    func bumpLiveExerciseWeight(id: String, by delta: Double) {
        guard let exercise = liveExercise(id: id) else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            exercise.bumpWeight(by: delta)
        }
    }

    func bumpLiveSetValue(exerciseID: String, setID: Int, by delta: Int, timed: Bool) {
        updateLiveSet(exerciseID: exerciseID, setID: setID) { row in
            if timed {
                let next = max(5, (row.durationSec ?? row.reps) + delta)
                row.durationSec = next
                row.reps = next
            } else {
                row.reps = max(0, row.reps + delta)
            }
        }
    }

    func bumpLiveSetRIR(exerciseID: String, setID: Int, by delta: Int) {
        updateLiveSet(exerciseID: exerciseID, setID: setID) { row in
            let base = row.rir ?? 2
            row.rir = max(0, min(5, base + delta))
        }
    }

    func setLiveSetWeight(exerciseID: String, setID: Int, weight: Double) {
        updateLiveSet(exerciseID: exerciseID, setID: setID) { row in
            row.weight = max(0, weight)
        }
    }

    func setLiveSetReps(exerciseID: String, setID: Int, reps: Int, durationSec: Int? = nil) {
        updateLiveSet(exerciseID: exerciseID, setID: setID) { row in
            row.reps = max(0, reps)
            if let durationSec {
                row.durationSec = max(5, durationSec)
                row.reps = row.durationSec ?? row.reps
            }
        }
    }

    func setLiveSetRIR(exerciseID: String, setID: Int, rir: Int) {
        updateLiveSet(exerciseID: exerciseID, setID: setID) { row in
            row.rir = max(0, rir)
        }
    }

    private func startWorkoutTicker() {
        guard workoutTicker == nil else { return }
        workoutTicker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickLiveWorkout()
            }
        }
    }

    private func tickLiveWorkout() {
        guard let live = liveWorkout else {
            workoutTicker?.invalidate()
            workoutTicker = nil
            return
        }
        // Mutate rest on the controller only — exercise cards observe themselves.
        guard live.restRemaining > 0 else {
            workoutTicker?.invalidate()
            workoutTicker = nil
            return
        }
        live.restRemaining -= 1
        if live.restRemaining == 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1005)
            workoutTicker?.invalidate()
            workoutTicker = nil
        }
    }

    private func grocerySource(from plan: WeeklyPlan) -> (recipes: [Recipe], scaleMap: [String: Int]) {
        let recipesByID = recipeDB.recipesByID()
        var scaleMap: [String: Int] = [:]
        var groceryRecipes: [Recipe] = []
        var seen: Set<String> = []
        for meal in plan.meals where meal.slot == .dinner {
            if seen.insert(meal.recipeID).inserted, let r = recipesByID[meal.recipeID] {
                if !WeekPlanner.looksLikeBreakfast(r) {
                    groceryRecipes.append(r)
                    scaleMap[r.id] = meal.scaledServings
                }
            }
            if let sid = meal.sideRecipeID, seen.insert(sid).inserted, let r = recipesByID[sid] {
                if !WeekPlanner.looksLikeBreakfast(r) {
                    groceryRecipes.append(r)
                    scaleMap[r.id] = meal.scaledServings
                }
            }
        }
        return (groceryRecipes, scaleMap)
    }

    private func buildShopList(
        from recipes: [Recipe],
        scaledServings: [String: Int],
        cookingComplexity: Int = 5
    ) async -> [ConsolidatedGroceryItem] {
        // Local consolidator is instant; LLM shopping lists blocked the Shop screen for seconds.
        consolidatedShopList(from: recipes, scaledServings: scaledServings, cookingComplexity: cookingComplexity)
    }

    private func consolidatedShopList(
        from recipes: [Recipe],
        scaledServings: [String: Int],
        cookingComplexity: Int = 5
    ) -> [ConsolidatedGroceryItem] {
        GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: recipes, scaledServings: scaledServings),
            cookingComplexity: cookingComplexity
        )
    }

    @discardableResult
    private func persistGrocery(
        for plan: WeeklyPlan,
        in modelContext: ModelContext,
        preservingUserEdits: Bool = false,
        groceries: [ConsolidatedGroceryItem]? = nil
    ) throws -> [Recipe] {
        let complexity = ((try? modelContext.fetch(FetchDescriptor<UserProfileEntity>())) ?? []).first?.cookingComplexity ?? 5
        try persistPlan(plan, in: modelContext)
        try persistGroceries(
            for: plan,
            in: modelContext,
            preservingUserEdits: preservingUserEdits,
            groceries: groceries,
            cookingComplexity: complexity
        )
        return grocerySource(from: plan.strippingBreakfast()).recipes
    }

    private func persistPlan(_ plan: WeeklyPlan, in modelContext: ModelContext) throws {
        let clean = plan.strippingBreakfast()
        try deleteAll(WeeklyPlanEntity.self, in: modelContext)
        modelContext.insert(WeeklyPlanEntity(plan: clean))
    }

    private func persistGroceries(
        for plan: WeeklyPlan,
        in modelContext: ModelContext,
        preservingUserEdits: Bool = false,
        groceries: [ConsolidatedGroceryItem]? = nil,
        cookingComplexity: Int = 5
    ) throws {
        let clean = plan.strippingBreakfast()
        let source = grocerySource(from: clean)
        var groceries = groceries ?? consolidatedShopList(from: source.recipes, scaledServings: source.scaleMap, cookingComplexity: cookingComplexity)
        groceries = groceries.filter { !Self.isLeftoverBreakfastStaple($0) }
        groceries = GroceryConsolidator.applyPantry(groceries, names: Pantry.names(in: modelContext))
        groceries = groceries.filter { !Self.isLeftoverBreakfastStaple($0) }
        try replaceGroceryEntities(
            groceries,
            planGeneratedAt: clean.generatedAt,
            in: modelContext,
            preservingUserEdits: preservingUserEdits
        )
    }

    private func replaceGroceryEntities(
        _ groceries: [ConsolidatedGroceryItem],
        planGeneratedAt: Date,
        in modelContext: ModelContext,
        preservingUserEdits: Bool
    ) throws {
        let existing = try modelContext.fetch(FetchDescriptor<GroceryItemEntity>())
        let checked: Set<String>
        let manuals: [ConsolidatedGroceryItem]
        if preservingUserEdits {
            checked = Set(existing.filter(\.isChecked).map { IngredientCanonicalizer.canonicalize($0.ingredientName) })
            manuals = existing.filter(\.isManual).compactMap { item in
                if Self.isLeftoverBreakfastEgg(item) { return nil }
                return item.asConsolidated()
            }
        } else {
            checked = []
            manuals = []
        }
        for item in existing {
            modelContext.delete(item)
        }
        let generatedKeys = Set(groceries.map { IngredientCanonicalizer.canonicalize($0.ingredientName) })
        for (idx, item) in groceries.enumerated() {
            var row = item
            if checked.contains(IngredientCanonicalizer.canonicalize(item.ingredientName)) {
                row.isChecked = true
            }
            modelContext.insert(GroceryItemEntity(from: row, planGeneratedAt: planGeneratedAt, sortOrder: idx))
        }
        var extra = groceries.count
        for manual in manuals {
            let key = IngredientCanonicalizer.canonicalize(manual.ingredientName)
            if generatedKeys.contains(key) { continue }
            extra += 1
            var row = manual
            row.isManual = true
            modelContext.insert(GroceryItemEntity(from: row, planGeneratedAt: planGeneratedAt, sortOrder: extra))
        }
    }

    /// Old breakfast mixer dumped a weekly egg staple (often named "18 eggs" / "24 eggs").
    private static func isLeftoverBreakfastStaple(_ item: ConsolidatedGroceryItem) -> Bool {
        GroceryConsolidator.isLeftoverBreakfastEgg(
            name: item.ingredientName,
            quantity: item.quantity,
            unit: item.unit
        )
    }

    private static func isLeftoverBreakfastEgg(_ item: GroceryItemEntity) -> Bool {
        GroceryConsolidator.isLeftoverBreakfastEgg(
            name: item.ingredientName,
            quantity: item.quantity,
            unit: item.unit
        )
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items { context.delete(item) }
    }
}

enum ServingScaler {
    static func scale(_ recipe: Recipe, to servings: Int) -> [ParsedIngredient] {
        let factor = Double(servings) / Double(max(recipe.baseServings, 1))
        let src: [ParsedIngredient]
        if recipe.parsedIngredients.isEmpty {
            src = recipe.ingredients.map {
                ParsedIngredient(
                    raw: $0,
                    quantity: nil,
                    unit: nil,
                    item: $0,
                    prep: "",
                    toTaste: false,
                    optional: false,
                    allergens: [],
                    notes: ""
                )
            }
        } else {
            src = recipe.parsedIngredients
        }
        return src.map { $0.isSectionHeader ? $0 : $0.scaled(by: factor) }
    }

    /// Scales a cookbook step-ingredient line like `"2 tablespoons olive oil"`.
    static func scaleLine(_ raw: String, by factor: Double) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard abs(factor - 1) > 0.02, !trimmed.isEmpty else { return trimmed }
        let pattern = #"^(\d+\s+\d+/\d+|\d+/\d+|\d+\.\d+|\d+|[½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let range = Range(match.range(at: 1), in: trimmed),
              let qty = parseLeadingQuantity(String(trimmed[range]))
        else { return trimmed }
        let rest = String(trimmed[range.upperBound...])
        return ParsedIngredient.formatQty(qty * factor) + rest
    }

    private static func parseLeadingQuantity(_ token: String) -> Double? {
        let fractions: [Character: Double] = [
            "½": 0.5, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "¼": 0.25, "¾": 0.75,
            "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
            "⅙": 1.0 / 6, "⅚": 5.0 / 6,
            "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
        ]
        if token.count == 1, let ch = token.first, let value = fractions[ch] {
            return value
        }
        if token.contains("/"), !token.contains(".") {
            let parts = token.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count == 2,
               let whole = Double(parts[0]),
               let frac = parseLeadingQuantity(String(parts[1])) {
                return whole + frac
            }
            let frac = token.split(separator: "/")
            if frac.count == 2, let n = Double(frac[0]), let d = Double(frac[1]), d != 0 {
                return n / d
            }
        }
        return Double(token.replacingOccurrences(of: ",", with: ""))
    }
}

