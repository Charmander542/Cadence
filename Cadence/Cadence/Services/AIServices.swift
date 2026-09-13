import Foundation

enum ProfileAIService {
    struct ProfilePayload: Codable {
        let weight_lbs: Double
        let height_inches: Double
        let age: Int
        let sex: String
        let activity_level: String
        let goal: String
        let servings_per_recipe: Int
        let dietary_restrictions_text: String
    }

    struct MacroResponse: Codable {
        let bmr: Double
        let tdee: Double
        let target_calories: Double
        let target_protein_g: Double
        let target_carbs_g: Double
        let target_fat_g: Double
        let rationale: String
        let dietary_filters: [String]?
    }

    static let systemPrompt = """
    You are a sports-nutrition assistant for a muscle-gain meal planner.
    Compute macros and return ONLY JSON (no markdown):
    {
      "bmr": number,
      "tdee": number,
      "target_calories": number,
      "target_protein_g": number,
      "target_carbs_g": number,
      "target_fat_g": number,
      "rationale": "short plain-language explanation",
      "dietary_filters": ["normalized disliked or restricted ingredients"]
    }
    Baseline: Mifflin-St Jeor for BMR. For muscle gain, treat ~1g protein per lb bodyweight as a FLOOR,
    then adjust thoughtfully for edge cases (very high bodyweight, fat-loss vs bulk, sex, activity).
    Do not invent rigid formulas beyond that — reason and adjust.
    Parse free-text dietary restrictions into a short lowercase filter list of ingredients/patterns to avoid.
    """

    static func computeMacros(
        client: LLMClient,
        profile: ProfilePayload
    ) async throws -> MacroResponse {
        let user = try String(data: JSONEncoder().encode(profile), encoding: .utf8) ?? "{}"
        let text = try await client.completeJSON(system: systemPrompt, user: "Profile JSON:\n\(user)")
        guard let data = text.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return try JSONDecoder().decode(MacroResponse.self, from: data)
    }
}

enum MealPlanAIService {
    struct CandidateRecipe: Codable {
        let id: String
        let title: String
        let tags: [String]
        let protein_g_per_serving: Double?
        let calories_per_serving: Double?
        let base_servings: Int
        let ingredients: [String]
    }

    struct SelectionResponse: Codable {
        struct Pick: Codable {
            let recipe_id: String
            let reason: String
        }
        let selected: [Pick]
        let summary: String?
    }

    static let systemPrompt = """
    You select a weekly meal-prep set from a candidate recipe pool for muscle-gain macros.
    Return ONLY JSON:
    {
      "selected": [{"recipe_id": 1, "reason": "one-line why"}],
      "summary": "one sentence overall"
    }
    Goals:
    - Collectively support the user's weekly protein/calorie targets when cooked at the given batch size.
    - Maximize shared ingredients across picks (same proteins, overlapping produce, shared pantry) to shrink the grocery list.
    - Keep some variety (not the same meal every day).
    - Respect dietary_filters: never pick recipes whose ingredient list clearly conflicts.
    - Pick exactly the requested number of distinct recipes (recipe_count).
    - Prefer recipes that are NOT near-duplicates of recently_used titles (avoid same dish / same protein+method combo when alternatives exist in the candidate pool).
    Only use recipe_id values from the provided candidates.
    """

    static func selectRecipes(
        client: LLMClient,
        profile: UserProfileEntity,
        candidates: [Recipe],
        recipeCount: Int,
        recentlyUsed: [(id: String, title: String, daysAgo: Int)] = []
    ) async throws -> SelectionResponse {
        let trimmed = candidates.map { r in
            CandidateRecipe(
                id: r.id,
                title: r.title,
                tags: r.tags,
                protein_g_per_serving: r.proteinGPerServing,
                calories_per_serving: r.caloriesPerServing,
                base_servings: r.baseServings,
                ingredients: r.ingredients
            )
        }
        let payload: [String: Any] = [
            "recipe_count": recipeCount,
            "batch_servings": profile.servingsPerRecipe,
            "daily_targets": [
                "calories": profile.targetCalories,
                "protein_g": profile.targetProteinG,
                "carbs_g": profile.targetCarbsG,
                "fat_g": profile.targetFatG,
            ],
            "goal": profile.goalRaw,
            "dietary_filters": profile.dietaryFilters,
            "recently_used": recentlyUsed.prefix(40).map { row -> [String: Any] in
                [
                    "recipe_id": row.id,
                    "title": row.title,
                    "days_ago": row.daysAgo,
                ]
            },
            "candidates": trimmed.map { c -> [String: Any] in
                [
                    "id": c.id,
                    "title": c.title,
                    "tags": c.tags,
                    "protein_g_per_serving": c.protein_g_per_serving as Any,
                    "calories_per_serving": c.calories_per_serving as Any,
                    "base_servings": c.base_servings,
                    "ingredients": c.ingredients,
                ]
            },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let user = String(data: data, encoding: .utf8) ?? "{}"
        let text = try await client.completeJSON(system: systemPrompt, user: user, maxTokens: 2048)
        guard let respData = text.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return try JSONDecoder().decode(SelectionResponse.self, from: respData)
    }
}

enum RecipeFilter {
    /// Pre-filter local DB before sending a ~40–60 candidate pool to Claude.
    static func candidates(
        from all: [Recipe],
        profile: UserProfileEntity,
        history: [RecipeHistoryEntity] = [],
        poolSize: Int = 50
    ) -> [Recipe] {
        let filters = DislikeMatcher.parse(profile.dietaryRestrictionsText)
        let enabled = Set(profile.enabledSources.map { $0.lowercased() })
        let tools = Set(profile.availableTools.map { $0.lowercased() })
        let exactCooldown = max(7, profile.recipeCooldownDays)
        let similarCooldown = max(7, exactCooldown * 2 / 3)
        // Specialty appliances that should exclude a recipe if the user lacks them.
        let specialty: Set<String> = [
            "air_fryer", "instant_pot", "slow_cooker", "grill",
            "blender", "food_processor", "stand_mixer", "sous_vide",
        ]

        var scored: [(Recipe, Double)] = []
        scored.reserveCapacity(min(all.count, poolSize * 4))
        for recipe in all {
            if !enabled.isEmpty {
                if !enabled.contains(recipe.source.lowercased()) {
                    // Keep unmatched sources if the list is the old host-based one.
                    let host = URL(string: recipe.sourceURL)?.host?.lowercased() ?? ""
                    let matchedSource = enabled.contains { host.contains($0) || recipe.source.lowercased().contains($0) }
                    if !matchedSource { continue }
                }
            }

            if DislikeMatcher.blocks(recipe, dislikes: filters) { continue }
            if !RecipeComplexity.fits(recipe, level: profile.cookingComplexity, course: recipe.course.isEmpty ? "main" : recipe.course) {
                continue
            }

            // Drop recipes that require specialty tools the user doesn't have.
            let requiredSpecialty = Set(recipe.equipment.map { $0.lowercased() }).intersection(specialty)
            if !requiredSpecialty.isSubset(of: tools) { continue }

            let repeatPenalty = RecipeHistory.penalty(
                for: recipe,
                history: history,
                exactCooldownDays: exactCooldown,
                similarCooldownDays: similarCooldown
            )
            if repeatPenalty >= 10_000 { continue } // still inside hard cooldown

            var score = 0.0
            if let p = recipe.proteinGPerServing {
                score += min(p, 60) // protein-dense weighted higher for muscle gain
            }
            if profile.goal == .muscleGain {
                if recipe.tags.contains(where: { $0.contains("high-protein") || $0.contains("chicken") || $0.contains("beef") }) {
                    score += 8
                }
            }
            if recipe.caloriesPerServing != nil { score += 2 }
            score -= RecipeComplexity.penalty(recipe, level: profile.cookingComplexity)
            score -= repeatPenalty
            scored.append((recipe, score))
        }

        scored.shuffle()
        scored.sort { $0.1 > $1.1 }
        return Array(scored.prefix(poolSize).map(\.0))
    }

    /// Distinct recipes needed for the week from batch size.
    /// Decision: lunch+dinner × 7 days / servingsPerRecipe, clamped 3...7.
    static func recipeCount(servingsPerRecipe: Int) -> Int {
        let meals = 14.0
        let count = Int(ceil(meals / Double(max(servingsPerRecipe, 1))))
        return min(7, max(3, count))
    }
}

/// Optional LLM polish for main↔side pairing after rules pick a week.
enum SidePairingAIService {
    struct DayPick: Codable {
        var day: Int
        var main_id: String
        var main_name: String
        var side_id: String?
        var side_name: String?
        var protein: [String]
    }

    struct Candidate: Codable {
        var id: String
        var name: String
        var kind: String?
    }

    struct Response: Codable {
        struct Pair: Codable {
            var day: Int
            var side_id: String
            var reason: String?
        }
        var pairs: [Pair]
    }

    static let systemPrompt = """
    You pair sides with protein dinners for a fitness-focused cook.
    Return ONLY JSON: {"pairs":[{"day":0,"side_id":"...","reason":"short"}]}
    Rules:
    - Every day needs an interesting side (starch, vegetable, salad, or greens) — not another protein main.
    - Prefer variety across the week (not rice every night).
    - side_id MUST be chosen from the provided candidates list.
    - Think like a coach plating a real dinner: chicken + greens, salmon + potato, beef + slaw, etc.
    - Do not invent ids.
    """

    static func refine(
        client: LLMClient,
        days: [DayPick],
        candidates: [Candidate]
    ) async throws -> [Int: String] {
        struct Payload: Codable {
            var days: [DayPick]
            var candidates: [Candidate]
        }
        let data = try JSONEncoder().encode(Payload(days: days, candidates: candidates))
        let user = String(data: data, encoding: .utf8) ?? "{}"
        let text = try await client.completeJSON(
            system: systemPrompt,
            user: "Pair sides JSON:\n\(user)",
            maxTokens: 2048
        )
        guard let resp = text.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        let decoded = try JSONDecoder().decode(Response.self, from: resp)
        let allowed = Set(candidates.map(\.id))
        var map: [Int: String] = [:]
        for pair in decoded.pairs {
            guard allowed.contains(pair.side_id) else { continue }
            map[pair.day] = pair.side_id
        }
        return map
    }
}

/// Compact ingredient text for the LLM shop-list prompt (no steps — keeps tokens low).
enum GroceryRecipeCorpus {
    static func text(recipes: [Recipe], scaledServings: [String: Int]) -> String {
        recipes.enumerated().map { index, recipe in
            let servings = scaledServings[recipe.id] ?? recipe.baseServings
            let factor = Double(servings) / Double(max(recipe.baseServings, 1))
            var lines: [String] = []
            lines.append("\(index + 1). \(recipe.name) — \(servings) servings")
            lines.append("Ingredients:")
            let scaled = ServingScaler.scale(recipe, to: servings)
            if scaled.isEmpty {
                for raw in recipe.ingredients {
                    lines.append("- \(ServingScaler.scaleLine(raw, by: factor))")
                }
            } else {
                for ing in scaled where !ing.isSectionHeader {
                    lines.append("- \(ing.display())")
                }
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}

/// Shop list from full recipe text via LLM. Falls back to rules when no API key.
enum GroceryAIService {
    struct ShoppingListResponse: Codable {
        struct Item: Codable {
            var name: String
            var quantity: Double?
            var unit: String?
            var category: String?
            var approximate: Bool?
        }
        var items: [Item]
    }

    static let systemPrompt = """
    Build one consolidated grocery shopping list from the week's scaled recipe ingredients.
    Return ONLY JSON: {"items":[{"name":"cheddar cheese","quantity":250,"unit":"g","category":"dairy","approximate":false}]}
    Merge duplicates (sum quantities). Drop garnish fluff and non-shoppable prep words.
    name = food only (no qty/unit inside). category: produce, protein, dairy, pantry, spice, frozen, other.
    unit: cup, tbsp, tsp, lb, oz, g, ml, count, bunch, head, bag, to_taste.
    """

    static func generateShoppingList(
        client: LLMClient,
        recipes: [Recipe],
        scaledServings: [String: Int]
    ) async throws -> [ConsolidatedGroceryItem] {
        let corpus = GroceryRecipeCorpus.text(recipes: recipes, scaledServings: scaledServings)
        let fastModel = KeychainStore.selectedProvider.fastModel
        let text = try await client.completeJSON(
            system: systemPrompt,
            user: "Recipes:\n\n\(corpus)",
            maxTokens: 4096,
            model: fastModel
        )
        guard let respData = text.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        let decoded = try JSONDecoder().decode(ShoppingListResponse.self, from: respData)
        let items = parseItems(decoded)
        guard !items.isEmpty else { throw URLError(.cannotDecodeContentData) }
        return GroceryConsolidator.finalizeForShopping(items)
    }

    private static func parseItems(_ decoded: ShoppingListResponse) -> [ConsolidatedGroceryItem] {
        decoded.items.compactMap { row in
            var rawName = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            var quantity = row.quantity ?? 0
            var unit = (row.unit?.isEmpty == false ? row.unit! : "count")
            var approx = row.approximate ?? false

            if IngredientCanonicalizer.isVagueAmountPhrase(rawName) {
                approx = true
                unit = "to_taste"
                quantity = 0
                rawName = rawName
                    .replacingOccurrences(
                        of: #"\bas much\b|\bas you want\b|\bfor garnish\b|\bgarnish\b"#,
                        with: " ",
                        options: .regularExpression
                    )
            }

            if let peeled = IngredientCanonicalizer.peelEmbeddedMeasure(from: rawName) {
                rawName = peeled.rest
                if unit == "count" || UnitConverter.kind(of: unit) == .count {
                    quantity = peeled.qty
                    unit = peeled.unit
                }
            }

            let name = IngredientCanonicalizer.canonicalize(rawName)
            guard !name.isEmpty, !IngredientCanonicalizer.isWeakGroceryName(name) else { return nil }
            return ConsolidatedGroceryItem(
                ingredientName: name,
                category: row.category ?? IngredientCanonicalizer.category(for: name),
                quantity: quantity,
                unit: approx ? "to_taste" : unit,
                isApproximate: approx || unit == "to_taste",
                note: "",
                isChecked: false,
                isManual: false
            )
        }
    }
}
