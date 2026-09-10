import Foundation

/// Structured ingredient line (Based-Cooking `ParsedIngredient`).
struct ParsedIngredient: Identifiable, Hashable, Codable {
    var id: String { "\(item)|\(unit ?? "")|\(raw)" }
    var raw: String
    var quantity: Double?
    var unit: String?
    var item: String
    var prep: String
    var toTaste: Bool
    var optional: Bool
    var allergens: [String]
    var notes: String

    enum CodingKeys: String, CodingKey {
        case raw, quantity, unit, item, prep, optional, allergens, notes
        case toTaste = "to_taste"
    }

    /// Cookbook sub-lists like "For the tofu" / "For the sauce:" — not shoppable lines.
    var isSectionHeader: Bool {
        let text = (raw.isEmpty ? item : raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let lower = text.lowercased()
        if text.hasPrefix("[") && text.hasSuffix("]") { return true }
        if lower.hasPrefix("for the ") || lower.hasPrefix("for a ") { return true }
        if lower.hasPrefix("for ") && quantity == nil { return true }
        if lower.hasPrefix("to serve") || lower.hasPrefix("to make") { return true }
        if text.hasSuffix(":") && quantity == nil && text.count < 48 { return true }
        let compact = lower.replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
        if ["sauce", "marinade", "dressing", "topping", "garnish", "rub", "glaze", "filling", "crust"].contains(compact) {
            return true
        }
        return false
    }

    var headerTitle: String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "[]:"))
        t = t.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
        if t.isEmpty { t = item }
        return t
    }

    func display(includePrep: Bool = true) -> String {
        if isSectionHeader { return headerTitle }
        if toTaste, quantity == nil {
            return "\((item.isEmpty ? raw : item)) to taste"
        }
        var parts: [String] = []
        if let quantity { parts.append(Self.formatQty(quantity)) }
        if let unit, unit != "each" { parts.append(unit) }
        parts.append(item.isEmpty ? raw : item)
        var text = parts.joined(separator: " ")
        if includePrep, !prep.isEmpty { text += ", \(prep)" }
        if toTaste, quantity != nil { text += " (to taste)" }
        return text
    }

    func scaled(by factor: Double) -> ParsedIngredient {
        var copy = self
        if let quantity { copy.quantity = quantity * factor }
        return copy
    }

    static func formatQty(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.02 { return String(Int(value.rounded())) }
        let table: [(Double, String)] = [
            (0.125, "1/8"), (0.25, "1/4"), (1.0 / 3, "1/3"), (0.375, "3/8"),
            (0.5, "1/2"), (0.625, "5/8"), (2.0 / 3, "2/3"), (0.75, "3/4"), (0.875, "7/8"),
        ]
        for (target, label) in table where abs(value - target) < 0.02 { return label }
        let whole = Int(value)
        let frac = value - Double(whole)
        if whole > 0, frac > 0.05 { return "\(whole) \(formatQty(frac))" }
        return String(format: "%.2f", value).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

struct RecipeStep: Identifiable, Hashable, Codable {
    var id: Int { stepNumber }
    var stepNumber: Int
    var instruction: String
    var ingredients: [String] = []
}

/// Cookbook / web recipe from the Based-Cooking SQLite store.
struct Recipe: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var source: String
    var sourceID: String
    var ingredients: [String]
    var steps: [RecipeStep]
    var description: String
    var yieldText: String
    var page: Int?
    var chapter: String
    var section: String
    var tags: [String]
    var url: String
    var extras: [String: AnyCodable]
    var parsedIngredients: [ParsedIngredient]
    var allergens: [String]
    var course: String

    var title: String { name }
    var sourceURL: String { url }
    var imageURL: String? {
        if case let .string(s)? = extras["image_url"]?.value, !s.isEmpty { return s }
        return nil
    }
    var equipment: [String] {
        if case let .array(arr)? = extras["equipment"]?.value {
            return arr.compactMap {
                if case let .string(s) = $0 { return s }
                return nil
            }
        }
        return []
    }
    var proteinGPerServing: Double? { extras["protein_g_per_serving"]?.doubleValue }
    var caloriesPerServing: Double? { extras["calories_per_serving"]?.doubleValue }
    var baseServings: Int {
        if let n = extras["base_servings"]?.doubleValue { return max(1, Int(n.rounded())) }
        return max(1, Int(Servings.parse(yieldText).rounded()))
    }

    /// Human cookbook title (Joy of Cooking, The Food Lab, …).
    var cookbookTitle: String { Self.cookbookTitle(for: source) }

    static func cookbookTitle(for source: String) -> String {
        switch source {
        case "joy-of-cooking": return "Joy of Cooking"
        case "keep-it-simple": return "Keep It Simple, Y'all"
        case "martha-one-pot": return "Martha Stewart One Pot"
        case "nigella-express": return "Nigella Express"
        case "salt-fat-acid-heat": return "Salt, Fat, Acid, Heat"
        case "sheet-pan-suppers": return "Sheet Pan Suppers"
        case "food-lab": return "The Food Lab"
        case "the-wok": return "The Wok"
        case "food-network-magazine": return "Food Network Magazine"
        case "based-cooking-web": return "based.cooking"
        default:
            return source
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    /// e.g. "Joy of Cooking · p. 214" or "based.cooking"
    var sourceCitation: String {
        if let page, page > 0 {
            return "\(cookbookTitle) · p. \(page)"
        }
        if !chapter.isEmpty, source != "based-cooking-web" {
            return "\(cookbookTitle) · \(chapter)"
        }
        return cookbookTitle
    }

    var webLink: URL? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let link = URL(string: trimmed), link.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return link
    }

    enum CodingKeys: String, CodingKey {
        case id, name, source, ingredients, steps, description, page, chapter, section, tags, url, extras, allergens, course
        case sourceID = "source_id"
        case yieldText = "yield_text"
        case parsedIngredients = "parsed_ingredients"
    }
}

/// Minimal JSON blob for extras that aren't a fixed schema.
struct AnyCodable: Hashable, Codable {
    enum Value: Hashable {
        case null, bool(Bool), int(Int), double(Double), string(String), array([Value]), object([String: Value])
    }
    var value: Value

    init(_ value: Value) { self.value = value }

    var doubleValue: Double? {
        switch value {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = .null; return }
        if let b = try? c.decode(Bool.self) { value = .bool(b); return }
        if let i = try? c.decode(Int.self) { value = .int(i); return }
        if let d = try? c.decode(Double.self) { value = .double(d); return }
        if let s = try? c.decode(String.self) { value = .string(s); return }
        if let a = try? c.decode([AnyCodable].self) { value = .array(a.map(\.value)); return }
        if let o = try? c.decode([String: AnyCodable].self) {
            value = .object(o.mapValues(\.value)); return
        }
        value = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v.map(AnyCodable.init))
        case .object(let v): try c.encode(v.mapValues(AnyCodable.init))
        }
    }
}

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// Slots the weekly generator fills. Lunch is user-managed — dinners only.
    static var recipeSlots: [MealSlot] { [.dinner] }
}

struct PlannedMeal: Identifiable, Hashable, Codable {
    var id: String { "\(dayIndex)-\(slot.rawValue)-\(recipeID)" }
    let dayIndex: Int
    let slot: MealSlot
    let recipeID: String
    let reason: String
    let scaledServings: Int
    var proteinG: Double?
    var calories: Double?
    var sideRecipeID: String?

    init(
        dayIndex: Int,
        slot: MealSlot,
        recipeID: String,
        reason: String,
        scaledServings: Int,
        proteinG: Double? = nil,
        calories: Double? = nil,
        sideRecipeID: String? = nil
    ) {
        self.dayIndex = dayIndex
        self.slot = slot
        self.recipeID = recipeID
        self.reason = reason
        self.scaledServings = scaledServings
        self.proteinG = proteinG
        self.calories = calories
        self.sideRecipeID = sideRecipeID
    }
}

struct BreakfastItem: Hashable, Codable {
    let name: String
    let quantity: Double
    let unit: String
    let category: String
    let proteinG: Double
    let calories: Double
}

struct BreakfastPlan: Hashable, Codable, Identifiable {
    var id: Int { dayIndex }
    let dayIndex: Int
    let title: String
    let items: [BreakfastItem]
    let proteinG: Double
    let calories: Double
    let note: String
    var includesShake: Bool {
        items.contains { $0.name.localizedCaseInsensitiveContains("protein powder") }
    }
}

struct WeeklyPlan: Codable, Hashable {
    var generatedAt: Date
    var meals: [PlannedMeal]
    var rationaleSummary: String
    var breakfasts: [BreakfastPlan]
    var scores: [String: Double] = [:]

    func breakfast(forDay day: Int) -> BreakfastPlan? {
        breakfasts.first(where: { $0.dayIndex == day }) ?? breakfasts.first
    }

    func meal(day: Int, slot: MealSlot) -> PlannedMeal? {
        meals.first(where: { $0.dayIndex == day && $0.slot == slot })
    }

    var hasLegacyBreakfast: Bool {
        !breakfasts.isEmpty || meals.contains { $0.slot == .breakfast }
    }

    func strippingBreakfast() -> WeeklyPlan {
        WeeklyPlan(
            generatedAt: generatedAt,
            meals: meals.filter { $0.slot != .breakfast },
            rationaleSummary: rationaleSummary,
            breakfasts: [],
            scores: scores
        )
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt, meals, rationaleSummary, breakfasts, breakfast, scores
    }

    init(
        generatedAt: Date,
        meals: [PlannedMeal],
        rationaleSummary: String,
        breakfasts: [BreakfastPlan],
        scores: [String: Double] = [:]
    ) {
        self.generatedAt = generatedAt
        self.meals = meals
        self.rationaleSummary = rationaleSummary
        self.breakfasts = breakfasts
        self.scores = scores
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        meals = (try? c.decode([PlannedMeal].self, forKey: .meals)) ?? []
        rationaleSummary = (try? c.decode(String.self, forKey: .rationaleSummary)) ?? ""
        breakfasts = (try? c.decode([BreakfastPlan].self, forKey: .breakfasts)) ?? []
        scores = (try? c.decode([String: Double].self, forKey: .scores)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(generatedAt, forKey: .generatedAt)
        try c.encode(meals, forKey: .meals)
        try c.encode(rationaleSummary, forKey: .rationaleSummary)
        try c.encode(breakfasts, forKey: .breakfasts)
        try c.encode(scores, forKey: .scores)
    }
}

struct MacroTargets: Codable, Hashable {
    var bmr: Double
    var tdee: Double
    var targetCalories: Double
    var targetProteinG: Double
    var targetCarbsG: Double
    var targetFatG: Double
    var rationale: String
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, veryActive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .veryActive: return "Very active"
        }
    }
    var tdeeMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .veryActive: return 1.725
        }
    }
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case muscleGain, maintenance, fatLoss
    var id: String { rawValue }
    var title: String {
        switch self {
        case .muscleGain: return "Muscle gain"
        case .maintenance: return "Maintenance"
        case .fatLoss: return "Fat loss"
        }
    }
}

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male, female, other
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CookingTool: String, Codable, CaseIterable, Identifiable {
    case stove, oven, microwave, airFryer, instantPot, slowCooker, grill, blender, foodProcessor, standMixer, sousVide
    var id: String { rawValue }
    var storageKey: String {
        switch self {
        case .stove: return "stove"
        case .oven: return "oven"
        case .microwave: return "microwave"
        case .airFryer: return "air_fryer"
        case .instantPot: return "instant_pot"
        case .slowCooker: return "slow_cooker"
        case .grill: return "grill"
        case .blender: return "blender"
        case .foodProcessor: return "food_processor"
        case .standMixer: return "stand_mixer"
        case .sousVide: return "sous_vide"
        }
    }
    var title: String {
        switch self {
        case .stove: return "Stove / cooktop"
        case .oven: return "Oven"
        case .microwave: return "Microwave"
        case .airFryer: return "Air fryer"
        case .instantPot: return "Instant Pot / pressure cooker"
        case .slowCooker: return "Slow cooker"
        case .grill: return "Grill"
        case .blender: return "Blender"
        case .foodProcessor: return "Food processor"
        case .standMixer: return "Stand mixer"
        case .sousVide: return "Sous vide"
        }
    }
    static var defaults: [CookingTool] { [.stove, .oven, .microwave] }
}

enum DietProfile: String, CaseIterable, Identifiable {
    case none, vegetarian, vegan, pescatarian, dairyFree, glutenFree, nutFree, eggFree
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "No diet filter"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .dairyFree: return "Dairy-free"
        case .glutenFree: return "Gluten-free"
        case .nutFree: return "Nut-free"
        case .eggFree: return "Egg-free"
        }
    }
    var storeKey: String? {
        switch self {
        case .none: return nil
        case .dairyFree: return "dairy_free"
        case .glutenFree: return "gluten_free"
        case .nutFree: return "nut_free"
        case .eggFree: return "egg_free"
        default: return rawValue
        }
    }
}

enum Servings {
    static func parse(_ yieldText: String, defaultValue: Double = 4) -> Double {
        let text = yieldText.lowercased()
        let pattern = #"(?:serves?|yields?|makes?|about)?\s*(\d+(?:\.\d+)?)(?:\s*(?:-|–|to)\s*(\d+(?:\.\d+)?))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return defaultValue }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return defaultValue }
        func num(_ i: Int) -> Double? {
            guard let r = Range(match.range(at: i), in: text) else { return nil }
            return Double(text[r])
        }
        guard let a = num(1) else { return defaultValue }
        if let b = num(2) { return (a + b) / 2 }
        return a
    }
}

/// How fussy a recipe is to shop and cook: ingredient count + hard-to-find items.
enum RecipeComplexity {
    static func clamped(_ raw: Int) -> Int {
        let n = raw == 0 ? 3 : raw
        return min(5, max(1, n))
    }

    static func title(for raw: Int) -> String {
        switch clamped(raw) {
        case 1: return "Simple"
        case 2: return "Easy"
        case 3: return "Typical"
        case 4: return "Involved"
        default: return "Anything"
        }
    }

    static func subtitle(for raw: Int) -> String {
        switch clamped(raw) {
        case 1: return "One weekly supermarket trip; short ingredient lists."
        case 2: return "Weeknight cooking — maybe one specialty item."
        case 3: return "Normal cookbook dinners."
        case 4: return "Longer lists and more specialty-aisle ingredients."
        default: return "No cap on ingredient count or exotic items."
        }
    }

    /// Soft cap on unique non-pantry shop SKUs across a 7-dinner week (before pantry filter).
    static func weeklySKUBudget(for raw: Int) -> Int {
        switch clamped(raw) {
        case 1: return 20
        case 2: return 28
        case 3: return 36
        case 4: return 48
        default: return 80
        }
    }

    static func freshHerbCap(for raw: Int) -> Int {
        switch clamped(raw) {
        case 1: return 1
        case 2: return 2
        default: return 8
        }
    }

    static func fits(_ recipe: Recipe, level raw: Int, course: String) -> Bool {
        let level = clamped(raw)
        if level >= 5 { return true }
        let shop = shoppableCount(recipe)
        let exotic = exoticCount(recipe, treatUnknownAsExotic: level <= 2)
        let fussy = fussyCount(recipe)
        let shopCap: Int
        let exoticCap: Int
        let fussyCap: Int
        switch level {
        case 1:
            shopCap = course == "side" ? 4 : 6
            exoticCap = 0
            fussyCap = course == "side" ? 1 : 1
        case 2:
            shopCap = course == "side" ? 7 : 9
            exoticCap = 1
            fussyCap = course == "side" ? 2 : 2
        case 3:
            shopCap = course == "side" ? 12 : 15
            exoticCap = 2
            fussyCap = 4
        default:
            shopCap = course == "side" ? 16 : 22
            exoticCap = 5
            fussyCap = 8
        }
        if shop > shopCap || exotic > exoticCap || fussy > fussyCap { return false }
        // Simple/Easy: reject long multi-step recipes when we have step data.
        if level <= 2, recipe.steps.count > (level == 1 ? 8 : 12) { return false }
        return true
    }

    /// Lower is simpler; used to prefer easier recipes inside the allowed band.
    static func penalty(_ recipe: Recipe, level raw: Int) -> Double {
        let level = clamped(raw)
        if level >= 5 { return 0 }
        let shop = Double(shoppableCount(recipe))
        let exotic = Double(exoticCount(recipe, treatUnknownAsExotic: level <= 2))
        let fussy = Double(fussyCount(recipe))
        let steps = Double(max(0, recipe.steps.count - 4))
        let weight = [0, 1.4, 0.95, 0.45, 0.2, 0][level]
        return weight * ((shop / 8.0) + 1.6 * exotic + 0.7 * fussy + 0.08 * steps)
    }

    static func shoppableCount(_ recipe: Recipe) -> Int {
        shoppableItems(recipe).count
    }

    static func shoppableItems(_ recipe: Recipe) -> [String] {
        let lines = recipe.parsedIngredients.isEmpty
            ? recipe.ingredients.map { IngredientCanonicalizer.canonicalize($0) }
            : recipe.parsedIngredients.compactMap { ing -> String? in
                if ing.isSectionHeader || ing.toTaste { return nil }
                let name = IngredientCanonicalizer.groceryName(for: ing)
                return name.isEmpty ? nil : name
            }
        return lines.filter { name in
            !staples.contains(name) && name != "water" && name != "ice"
        }
    }

    static func exoticCount(_ recipe: Recipe, treatUnknownAsExotic: Bool) -> Int {
        shoppableItems(recipe).filter { isExotic($0, treatUnknownAsExotic: treatUnknownAsExotic) }.count
    }

    /// Produce / herbs that are common in cookbooks but annoying for a minimal weekly shop.
    static func fussyCount(_ recipe: Recipe) -> Int {
        shoppableItems(recipe).filter { isFussy($0) }.count
    }

    static func isFreshHerb(_ name: String) -> Bool {
        let n = name.lowercased()
        return freshHerbs.contains(where: { n == $0 || n.hasPrefix($0 + " ") || n.hasSuffix(" " + $0) })
    }

    static func isExoticName(_ name: String, treatUnknownAsExotic: Bool = false) -> Bool {
        isExotic(name, treatUnknownAsExotic: treatUnknownAsExotic)
    }

    private static func isExotic(_ name: String, treatUnknownAsExotic: Bool) -> Bool {
        if exoticNeedles.contains(where: { name.contains($0) }) { return true }
        if common.contains(name) { return false }
        if common.contains(where: { $0.count >= 4 && (name.contains($0) || $0.contains(name)) }) {
            return false
        }
        return treatUnknownAsExotic
    }

    private static func isFussy(_ name: String) -> Bool {
        let n = name.lowercased()
        if fussyNeedles.contains(where: { n.contains($0) }) { return true }
        if isFreshHerb(n) { return true }
        return false
    }

    private static let staples: Set<String> = [
        "salt", "pepper", "oil", "olive oil", "vegetable oil", "sugar", "flour",
        "water", "ice", "cooking spray",
    ]

    private static let common: Set<String> = [
        "chicken", "chicken breast", "chicken thigh", "chicken drumstick", "whole chicken",
        "turkey", "turkey breast", "ground turkey", "ground beef", "ground chicken",
        "beef", "steak", "pork", "bacon", "ham", "sausage", "egg", "salmon", "tuna",
        "cod", "shrimp", "tofu", "bean", "black bean", "chickpea", "lentil",
        "onion", "red onion", "garlic", "ginger", "shallot", "green onion", "scallion",
        "tomato", "potato", "sweet potato", "carrot", "celery", "lettuce", "spinach",
        "broccoli", "cauliflower", "bell pepper", "cucumber", "lemon", "lime", "orange",
        "apple", "banana", "avocado", "mushroom", "cabbage", "kale", "zucchini",
        "corn", "pea", "green bean", "parsley", "cilantro", "basil", "mint",
        "rosemary", "thyme", "oregano", "dill", "jalapeno", "chili",
        "milk", "butter", "cheese", "yogurt", "greek yogurt", "cream", "sour cream",
        "parmesan", "cheddar", "mozzarella", "feta",
        "rice", "brown rice", "pasta", "noodle", "bread", "tortilla", "oat", "flour",
        "sugar", "honey", "maple syrup", "peanut butter", "oil", "olive oil",
        "vegetable oil", "soy sauce", "vinegar", "salt", "pepper", "stock", "broth",
        "tomato sauce", "tomato paste", "coconut milk", "wine",
        "cumin", "paprika", "cinnamon", "chili powder", "garlic powder", "onion powder",
        "baking powder", "baking soda", "cornstarch", "red pepper flake", "bay leaf",
    ]

    private static let exoticNeedles: [String] = [
        "gochujang", "gochugaru", "miso", "mirin", "sake", "shaoxing", "lemongrass",
        "galangal", "kaffir", "makrut", "pandan", "tamarind", "tahini", "harissa",
        "sumac", "zaatar", "za'atar", "pomegranate molasses", "preserved lemon",
        "fenugreek", "asafoetida", "hing", "curry leaf", "star anise", "sichuan",
        "saffron", "truffle", "yuzu", "shiso", "wakame", "kombu", "bonito", "dashi",
        "doubanjiang", "fermented black", "sambal", "kecap", "paneer", "halloumi",
        "labneh", "dukkah", "ras el hanout", "berbere", "nutritional yeast",
        "seitan", "jackfruit", "masa harina", "calamansi", "palm sugar",
        "coconut aminos", "black garlic", "chili crisp", "furikake", "togarashi",
        "fennel pollen", "ghee", "fish sauce", "oyster sauce", "hoisin",
        "rice wine", "nori", "kimchi", "gochugaru", "five spice", "szechuan",
    ]

    private static let fussyNeedles: [String] = [
        "shallot", "fennel bulb", "fennel seed", "leek", "radicchio", "endive", "frisee", "watercress",
        "microgreen", "shiitake", "oyster mushroom", "chanterelle",
        "morel", "enoki", "bok choy", "napa cabbage", "daikon",
        "jicama", "rutabaga", "celeriac", "kohlrabi", "rainbow chard", "swiss chard",
        "haricot", "haricots verts", "broccolini", "romanesco", "pattypan",
        "sun-dried tomato", "piquillo", "anaheim", "poblano", "serrano", "habanero",
    ]

    private static let freshHerbs: Set<String> = [
        "parsley", "cilantro", "basil", "mint", "dill", "chive", "chives",
        "rosemary", "thyme", "oregano", "sage", "tarragon", "marjoram",
        "lemongrass", "chervil",
    ]
}
