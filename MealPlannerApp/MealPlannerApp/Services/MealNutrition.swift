import Foundation

struct MacroEstimate: Hashable {
    var proteinG: Double
    var calories: Double
    var matched: Int
    var total: Int
    var isEstimated: Bool

    var coverage: Double { total == 0 ? 0 : Double(matched) / Double(total) }

    static let empty = MacroEstimate(proteinG: 0, calories: 0, matched: 0, total: 0, isEstimated: true)
}

/// Per-meal protein/calorie math. Cookbook extras rarely include nutrition, so we
/// estimate from parsed ingredients and scale with the batch size.
enum MealNutrition {
    private static var cache: [String: MacroEstimate] = [:]
    private static let lock = NSLock()

    /// One plated serving of a recipe (lunch or dinner portion).
    static func perServing(of recipe: Recipe) -> (protein: Double?, calories: Double?) {
        let est = estimate(recipe)
        let p = est.proteinG
        let c = est.calories
        if p <= 0, c <= 0 { return (recipe.proteinGPerServing, recipe.caloriesPerServing) }
        return (p, c)
    }

    static func plate(main: Recipe, side: Recipe?) -> MacroEstimate {
        let a = estimate(main)
        guard let side else { return a }
        let b = estimate(side)
        return MacroEstimate(
            proteinG: a.proteinG + b.proteinG,
            calories: a.calories + b.calories,
            matched: a.matched + b.matched,
            total: a.total + b.total,
            isEstimated: a.isEstimated || b.isEstimated
        )
    }

    /// Macros for one serving. Independent of how big a batch you cook.
    static func estimate(_ recipe: Recipe) -> MacroEstimate {
        let batch = estimateBatch(recipe)
        let n = Double(max(recipe.baseServings, 1))
        return MacroEstimate(
            proteinG: batch.proteinG / n,
            calories: batch.calories / n,
            matched: batch.matched,
            total: batch.total,
            isEstimated: batch.isEstimated
        )
    }

    /// Whole-batch macros if you cook `servings` portions of the same size.
    static func batch(_ recipe: Recipe, servings: Int) -> MacroEstimate {
        let one = estimate(recipe)
        let n = Double(max(servings, 1))
        return MacroEstimate(
            proteinG: one.proteinG * n,
            calories: one.calories * n,
            matched: one.matched,
            total: one.total,
            isEstimated: one.isEstimated
        )
    }

    static func formatProtein(_ g: Double?) -> String {
        guard let g, g > 0 else { return "—" }
        return String(format: "%.0fg protein", g)
    }

    static func formatCalories(_ c: Double?) -> String {
        guard let c, c > 0 else { return "—" }
        return String(format: "%.0f cal", c)
    }

    static func formatPair(protein: Double?, calories: Double?, estimated: Bool = false) -> String {
        let core = "\(formatProtein(protein)) · \(formatCalories(calories))"
        return estimated && (protein ?? 0) + (calories ?? 0) > 0 ? "~\(core)" : core
    }

    static func formatEstimate(_ est: MacroEstimate) -> String {
        formatPair(protein: est.proteinG, calories: est.calories, estimated: est.isEstimated)
    }

    // MARK: - Batch (whole recipe as written)

    private static func estimateBatch(_ recipe: Recipe) -> MacroEstimate {
        lock.lock()
        if let hit = cache[recipe.id] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let storedP = recipe.proteinGPerServing
        let storedC = recipe.caloriesPerServing
        let servings = Double(max(recipe.baseServings, 1))
        if let storedP, let storedC, storedP > 0, storedC > 0 {
            let est = MacroEstimate(
                proteinG: storedP * servings,
                calories: storedC * servings,
                matched: recipe.parsedIngredients.count,
                total: recipe.parsedIngredients.count,
                isEstimated: false
            )
            lock.lock()
            cache[recipe.id] = est
            lock.unlock()
            return est
        }

        let lines = recipe.parsedIngredients.filter { !$0.isSectionHeader }
        var protein = 0.0
        var calories = 0.0
        var matched = 0
        for ing in lines {
            guard let macros = macros(for: ing) else { continue }
            protein += macros.protein
            calories += macros.calories
            matched += 1
        }
        if let storedP, storedP > 0 { protein = storedP * servings }
        if let storedC, storedC > 0 { calories = storedC * servings }
        let est = MacroEstimate(
            proteinG: protein,
            calories: calories,
            matched: matched,
            total: lines.count,
            isEstimated: true
        )
        lock.lock()
        cache[recipe.id] = est
        lock.unlock()
        return est
    }

    private static func macros(for ing: ParsedIngredient) -> (protein: Double, calories: Double)? {
        if ing.toTaste { return nil }
        let key = lookupKey(ing.item.isEmpty ? ing.raw : ing.item)
        guard !key.isEmpty, key != "water" else { return nil }
        guard let food = food(for: key) else { return nil }
        let qty = ing.quantity ?? (ing.unit == nil ? 1 : 1)
        let unit = (ing.unit == "each" ? "count" : (ing.unit ?? "count")).lowercased()
        guard let grams = grams(qty: qty, unit: unit, food: food) else { return nil }
        return (food.proteinPer100g * grams / 100, food.kcalPer100g * grams / 100)
    }

    private static func lookupKey(_ raw: String) -> String {
        IngredientCanonicalizer.canonicalize(raw)
    }

    private static func food(for key: String) -> Food? {
        if let direct = foods[key] { return direct }
        if key.hasSuffix("s"), let direct = foods[String(key.dropLast())] { return direct }
        guard key.count >= 4 else { return nil }
        for (name, food) in foods {
            if key == name { return food }
            if key.contains(name), name.count >= 4 { return food }
        }
        return nil
    }

    private static func grams(qty: Double, unit: String, food: Food) -> Double? {
        if let per = food.gramsPerUnit[unit] { return qty * per }
        switch unit {
        case "g": return qty
        case "kg": return qty * 1000
        case "oz": return qty * 28.35
        case "lb": return qty * 453.6
        case "ml": return qty * (food.gramsPerUnit["ml"] ?? 1)
        case "l": return qty * 1000 * (food.gramsPerUnit["ml"] ?? 1)
        case "cup": return qty * (food.gramsPerUnit["cup"] ?? 150)
        case "tbsp": return qty * (food.gramsPerUnit["tbsp"] ?? food.gramsPerUnit["cup"].map { $0 / 16 } ?? 15)
        case "tsp": return qty * (food.gramsPerUnit["tsp"] ?? food.gramsPerUnit["tbsp"].map { $0 / 3 } ?? 5)
        case "count", "each", "clove", "head", "bunch", "slice", "can", "package", "stick", "fillet":
            if let per = food.gramsPerUnit["count"] ?? food.gramsPerUnit[unit] { return qty * per }
            return food.gramsPerUnit["each"]
        default:
            return food.gramsPerUnit[unit] ?? food.gramsPerUnit["count"]
        }
    }

    private struct Food {
        var proteinPer100g: Double
        var kcalPer100g: Double
        var gramsPerUnit: [String: Double]
    }

    /// Compact USDA-style table. Values are typical grocery/cooked-recipe amounts.
    private static let foods: [String: Food] = {
        func f(_ p: Double, _ k: Double, _ units: [String: Double] = [:]) -> Food {
            Food(proteinPer100g: p, kcalPer100g: k, gramsPerUnit: units)
        }
        return [
            "chicken breast": f(31, 165, ["count": 170, "lb": 453.6]),
            "chicken thigh": f(26, 209, ["count": 120, "lb": 453.6]),
            "chicken": f(27, 190, ["count": 150, "lb": 453.6]),
            "whole chicken": f(17, 215, ["count": 1400]),
            "turkey breast": f(30, 135, ["count": 170, "lb": 453.6]),
            "turkey": f(29, 189, ["count": 170]),
            "ground turkey": f(27, 170, ["lb": 453.6]),
            "ground beef": f(26, 250, ["lb": 453.6]),
            "beef": f(26, 250, ["count": 170, "lb": 453.6, "steak": 220]),
            "steak": f(27, 271, ["count": 220, "lb": 453.6]),
            "pork": f(27, 242, ["count": 170, "lb": 453.6]),
            "pork chop": f(27, 231, ["count": 180]),
            "bacon": f(37, 541, ["slice": 8, "count": 8]),
            "sausage": f(13, 301, ["count": 75, "link": 75]),
            "ham": f(21, 145, ["slice": 28]),
            "lamb": f(25, 294, ["count": 170, "lb": 453.6]),
            "salmon": f(20, 208, ["count": 170, "fillet": 170, "lb": 453.6]),
            "tuna": f(29, 132, ["can": 140, "count": 140]),
            "cod": f(18, 82, ["count": 170, "fillet": 170]),
            "shrimp": f(24, 99, ["count": 8, "lb": 453.6]),
            "tofu": f(8, 76, ["count": 400, "block": 400, "cup": 250, "oz": 28.35]),
            "tempeh": f(20, 192, ["count": 200]),
            "egg": f(13, 143, ["count": 50, "each": 50]),
            "egg white": f(11, 52, ["count": 33]),
            "egg yolk": f(16, 322, ["count": 17]),
            "black bean": f(9, 132, ["cup": 172, "can": 425]),
            "bean": f(9, 140, ["cup": 170, "can": 425]),
            "chickpea": f(9, 164, ["cup": 164, "can": 425]),
            "lentil": f(9, 116, ["cup": 198]),
            "rice": f(7, 365, ["cup": 185, "tbsp": 12]),
            "brown rice": f(8, 370, ["cup": 190]),
            "pasta": f(13, 371, ["cup": 100, "oz": 28.35, "lb": 453.6]),
            "noodle": f(14, 384, ["cup": 90, "oz": 28.35]),
            "quinoa": f(14, 368, ["cup": 170]),
            "oat": f(13, 389, ["cup": 80]),
            "bread": f(9, 265, ["slice": 30, "count": 30]),
            "tortilla": f(8, 237, ["count": 45]),
            "flour": f(10, 364, ["cup": 120, "tbsp": 8]),
            "milk": f(3.4, 61, ["cup": 244, "tbsp": 15]),
            "yogurt": f(10, 59, ["cup": 245]),
            "greek yogurt": f(10, 59, ["cup": 245]),
            "cheese": f(25, 402, ["cup": 113, "oz": 28.35, "slice": 21]),
            "parmesan": f(38, 431, ["cup": 100, "tbsp": 5, "oz": 28.35]),
            "cheddar": f(25, 403, ["cup": 113, "oz": 28.35, "slice": 21]),
            "mozzarella": f(22, 280, ["cup": 112, "oz": 28.35]),
            "feta": f(14, 264, ["cup": 150, "oz": 28.35]),
            "cream": f(2, 340, ["cup": 238, "tbsp": 15]),
            "sour cream": f(2.4, 198, ["cup": 230, "tbsp": 12]),
            "butter": f(0.9, 717, ["tbsp": 14, "stick": 113, "cup": 227]),
            "olive oil": f(0, 884, ["tbsp": 14, "tsp": 4.5, "cup": 216]),
            "oil": f(0, 884, ["tbsp": 14, "tsp": 4.5, "cup": 218]),
            "vegetable oil": f(0, 884, ["tbsp": 14, "cup": 218]),
            "sesame oil": f(0, 884, ["tbsp": 14, "tsp": 4.5]),
            "peanut butter": f(24, 588, ["tbsp": 16, "cup": 258]),
            "almond": f(21, 579, ["cup": 95, "count": 1.2]),
            "walnut": f(15, 654, ["cup": 117]),
            "peanut": f(26, 567, ["cup": 146]),
            "onion": f(1.1, 40, ["count": 150, "cup": 160, "tbsp": 10]),
            "garlic": f(6.4, 149, ["clove": 3, "head": 36, "count": 3, "tbsp": 8, "tsp": 2.8]),
            "shallot": f(2.5, 72, ["count": 40, "tbsp": 10]),
            "ginger": f(1.8, 80, ["tbsp": 6, "tsp": 2, "count": 15]),
            "tomato": f(0.9, 18, ["count": 120, "cup": 180]),
            "tomato paste": f(4.3, 82, ["tbsp": 16, "can": 170]),
            "tomato sauce": f(1.3, 29, ["cup": 245, "can": 425]),
            "bell pepper": f(1, 31, ["count": 160, "cup": 150]),
            "spinach": f(2.9, 23, ["cup": 30, "bag": 227]),
            "broccoli": f(2.8, 34, ["cup": 91, "bunch": 450, "head": 450]),
            "cauliflower": f(1.9, 25, ["cup": 100, "head": 600]),
            "carrot": f(0.9, 41, ["count": 60, "cup": 128]),
            "celery": f(0.7, 16, ["stalk": 40, "count": 40, "cup": 100]),
            "potato": f(2, 77, ["count": 170, "cup": 150]),
            "sweet potato": f(1.6, 86, ["count": 200]),
            "zucchini": f(1.2, 17, ["count": 200, "cup": 124]),
            "mushroom": f(3.1, 22, ["cup": 70, "count": 18]),
            "avocado": f(2, 160, ["count": 200, "cup": 150]),
            "lettuce": f(1.4, 15, ["head": 350, "cup": 36]),
            "cabbage": f(1.3, 25, ["head": 900, "cup": 90]),
            "kale": f(2.9, 35, ["cup": 20, "bunch": 150]),
            "cucumber": f(0.7, 15, ["count": 300, "cup": 100]),
            "lemon": f(1.1, 29, ["count": 84, "tbsp": 15]),
            "lime": f(0.7, 30, ["count": 67, "tbsp": 15]),
            "orange": f(0.9, 47, ["count": 130]),
            "apple": f(0.3, 52, ["count": 180]),
            "banana": f(1.1, 89, ["count": 118]),
            "berry": f(0.7, 57, ["cup": 140]),
            "corn": f(3.3, 86, ["ear": 90, "count": 90, "cup": 145, "can": 425]),
            "pea": f(5.4, 81, ["cup": 145]),
            "green bean": f(1.8, 31, ["cup": 100]),
            "soy sauce": f(8, 53, ["tbsp": 16, "tsp": 5]),
            "fish sauce": f(5, 35, ["tbsp": 18]),
            "vinegar": f(0, 18, ["tbsp": 15, "cup": 240]),
            "honey": f(0.3, 304, ["tbsp": 21, "tsp": 7]),
            "sugar": f(0, 387, ["tbsp": 12.5, "cup": 200, "tsp": 4]),
            "maple syrup": f(0, 260, ["tbsp": 20]),
            "coconut milk": f(2.3, 230, ["cup": 240, "can": 400, "tbsp": 15]),
            "stock": f(0.5, 8, ["cup": 240]),
            "broth": f(0.5, 8, ["cup": 240]),
            "wine": f(0.1, 85, ["cup": 236, "tbsp": 15]),
            "salt": f(0, 0, ["tsp": 6, "tbsp": 18]),
            "pepper": f(10, 251, ["tsp": 2.3, "tbsp": 7]),
        ]
    }()
}
