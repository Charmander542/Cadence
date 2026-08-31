import Foundation
import SwiftData

/// SwiftData models for local-only persistence (v1: no multi-device sync).
@Model
final class UserProfileEntity {
    var weightLbs: Double
    var heightInches: Double
    var age: Int
    var sexRaw: String
    var activityRaw: String
    var goalRaw: String
    var servingsPerRecipe: Int
    var dietaryRestrictionsText: String
    var dietaryFilterJSON: String
    var enabledSourcesJSON: String
    var availableToolsJSON: String = #"["stove","oven","microwave"]"#
    /// Days before the same recipe can be recommended again.
    var recipeCooldownDays: Int = 21
    /// vegetarian / vegan / gluten_free / none / …
    var dietRaw: String = "none"
    /// 1 = simple supermarket dinners … 5 = anything goes. 0 means unset (treat as 3).
    var cookingComplexity: Int = 3
    /// When false, hide Lift schedule cards, calendar chips, and workout reminders.
    var workoutsEnabled: Bool = true

    var bmr: Double
    var tdee: Double
    var targetCalories: Double
    var targetProteinG: Double
    var targetCarbsG: Double
    var targetFatG: Double
    var rationale: String
    var onboardingComplete: Bool
    var updatedAt: Date

    init() {
        weightLbs = 165
        heightInches = 70
        age = 30
        sexRaw = BiologicalSex.male.rawValue
        activityRaw = ActivityLevel.moderate.rawValue
        goalRaw = GoalType.muscleGain.rawValue
        servingsPerRecipe = 4
        dietaryRestrictionsText = ""
        dietaryFilterJSON = "[]"
        enabledSourcesJSON = "[]"
        availableToolsJSON = String(
            data: (try? JSONEncoder().encode(CookingTool.defaults.map(\.storageKey))) ?? Data("[]".utf8),
            encoding: .utf8
        ) ?? #"["stove","oven","microwave"]"#
        recipeCooldownDays = 21
        dietRaw = DietProfile.none.rawValue
        cookingComplexity = 3
        workoutsEnabled = true
        bmr = 0
        tdee = 0
        targetCalories = 0
        targetProteinG = 0
        targetCarbsG = 0
        targetFatG = 0
        rationale = ""
        onboardingComplete = false
        updatedAt = .now
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }

    var goal: GoalType {
        get { GoalType(rawValue: goalRaw) ?? .muscleGain }
        set { goalRaw = newValue.rawValue }
    }

    var dietaryFilters: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(dietaryFilterJSON.utf8))) ?? [] }
        set { dietaryFilterJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var enabledSources: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(enabledSourcesJSON.utf8))) ?? [] }
        set { enabledSourcesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var availableTools: [String] {
        get {
            let decoded = (try? JSONDecoder().decode([String].self, from: Data(availableToolsJSON.utf8))) ?? []
            return decoded.isEmpty ? CookingTool.defaults.map(\.storageKey) : decoded
        }
        set {
            availableToolsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    var macros: MacroTargets {
        MacroTargets(
            bmr: bmr,
            tdee: tdee,
            targetCalories: targetCalories,
            targetProteinG: targetProteinG,
            targetCarbsG: targetCarbsG,
            targetFatG: targetFatG,
            rationale: rationale
        )
    }
}

@Model
final class WeeklyPlanEntity {
    var generatedAt: Date
    var planJSON: String
    var rationaleSummary: String

    init(plan: WeeklyPlan) {
        generatedAt = plan.generatedAt
        rationaleSummary = plan.rationaleSummary
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        planJSON = (try? String(data: encoder.encode(plan), encoding: .utf8)) ?? "{}"
    }

    func decoded() -> WeeklyPlan? {
        guard let data = planJSON.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WeeklyPlan.self, from: data)
    }
}

@Model
final class GroceryItemEntity {
    var ingredientName: String
    var category: String
    var quantity: Double
    var unit: String
    var isApproximate: Bool
    var note: String
    var isChecked: Bool
    var isManual: Bool
    var sortOrder: Int
    var planGeneratedAt: Date

    init(from item: ConsolidatedGroceryItem, planGeneratedAt: Date, sortOrder: Int) {
        ingredientName = item.ingredientName
        category = item.category
        quantity = item.quantity
        unit = item.unit
        isApproximate = item.isApproximate
        note = item.note
        isChecked = item.isChecked
        isManual = item.isManual
        self.sortOrder = sortOrder
        self.planGeneratedAt = planGeneratedAt
    }

    func asConsolidated() -> ConsolidatedGroceryItem {
        ConsolidatedGroceryItem(
            ingredientName: ingredientName,
            category: category,
            quantity: quantity,
            unit: unit,
            isApproximate: isApproximate,
            note: note,
            isChecked: isChecked,
            isManual: isManual
        )
    }
}

@Model
final class PantryItemEntity {
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

enum Pantry {
    static func names(in context: ModelContext) -> Set<String> {
        seedIfNeeded(in: context)
        let items = (try? context.fetch(FetchDescriptor<PantryItemEntity>())) ?? []
        return Set(items.map { PantryMatcher.key($0.name) })
    }

    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<PantryItemEntity>())) ?? []
        guard existing.isEmpty else { return }
        for name in GroceryConsolidator.defaultPantry {
            context.insert(PantryItemEntity(name: name))
        }
        try? context.save()
    }

    static func contains(_ name: String, in context: ModelContext) -> Bool {
        PantryMatcher.covers(name, pantry: names(in: context))
    }

    static func toggle(_ name: String, in context: ModelContext) {
        let key = PantryMatcher.key(name)
        let items = (try? context.fetch(FetchDescriptor<PantryItemEntity>())) ?? []
        if let hit = items.first(where: { PantryMatcher.key($0.name) == key }) {
            context.delete(hit)
        } else {
            context.insert(PantryItemEntity(name: key))
        }
        try? context.save()
    }
}

// MARK: - Workouts

@Model
final class WorkoutPlanEntity {
    var planJSON: String
    var updatedAt: Date

    init(plan: WorkoutPlanState = .fresh) {
        updatedAt = .now
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        planJSON = (try? String(data: encoder.encode(plan), encoding: .utf8)) ?? "{}"
    }

    func decoded() -> WorkoutPlanState {
        guard let data = planJSON.data(using: .utf8) else { return .fresh }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var plan = (try? decoder.decode(WorkoutPlanState.self, from: data)) ?? .fresh
        WorkoutProgression.ensureStates(in: &plan)
        return plan
    }

    func save(_ plan: WorkoutPlanState) {
        var copy = plan
        WorkoutProgression.ensureStates(in: &copy)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        planJSON = (try? String(data: encoder.encode(copy), encoding: .utf8)) ?? planJSON
        updatedAt = .now
    }
}

@Model
final class WorkoutLogEntity {
    var id: UUID
    var sessionID: String
    var sessionName: String
    var startedAt: Date
    var finishedAt: Date
    var durationSec: Int
    var logJSON: String
    var loggedIncomplete: Bool

    init(workout: LoggedWorkout) {
        id = workout.id
        sessionID = workout.sessionID
        sessionName = workout.sessionName
        startedAt = workout.startedAt
        finishedAt = workout.finishedAt
        durationSec = workout.durationSec
        loggedIncomplete = workout.loggedIncomplete
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        logJSON = (try? String(data: encoder.encode(workout), encoding: .utf8)) ?? "{}"
    }

    func decoded() -> LoggedWorkout? {
        guard let data = logJSON.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LoggedWorkout.self, from: data)
    }
}

enum WorkoutStore {
    static func plan(in context: ModelContext) -> WorkoutPlanEntity {
        let existing = (try? context.fetch(FetchDescriptor<WorkoutPlanEntity>())) ?? []
        if let first = existing.first {
            for extra in existing.dropFirst() { context.delete(extra) }
            return first
        }
        var fresh = WorkoutPlanState.fresh
        WorkoutProgression.ensureStates(in: &fresh)
        let entity = WorkoutPlanEntity(plan: fresh)
        context.insert(entity)
        try? context.save()
        return entity
    }
}
