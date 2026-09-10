import Foundation

/// Port of Based-Cooking `plan.py`: shared grocery overlap + flavor variety, no LLM.
enum WeekPlanner {
    private static let pantry: Set<String> = [
        "salt", "pepper", "water", "oil", "olive oil", "vegetable oil", "sugar", "flour",
        "butter", "onion", "garlic", "shallot", "scallion", "carrot", "celery", "lemon", "lime", "parsley",
    ]

    private static let proteinNeedles: [(String, [String])] = [
        ("chicken", ["chicken", "hen", "turkey"]),
        ("beef", ["beef", "steak", "burger"]),
        ("pork", ["pork", "bacon", "ham", "sausage", "prosciutto"]),
        ("lamb", ["lamb"]),
        ("fish", ["salmon", "tuna", "cod", "fish", "trout", "halibut"]),
        ("shellfish", ["shrimp", "prawn", "crab", "lobster", "clam", "mussel", "scallop"]),
        ("egg", ["egg"]),
        ("tofu", ["tofu", "tempeh"]),
        ("bean", ["bean", "lentil", "chickpea", "black bean"]),
    ]

    private static let flavorNeedles: [(String, [String])] = [
        ("tomato", ["tomato", "marinara", "passata"]),
        ("soy", ["soy sauce", "ginger", "sesame", "miso", "teriyaki"]),
        ("spicy", ["chili", "chilli", "cayenne", "jalapeno", "jalapeño", "hot sauce", "gochujang", "harissa"]),
        ("herb", ["basil", "parsley", "thyme", "rosemary", "oregano", "cilantro", "dill", "mint"]),
        ("citrus", ["lemon", "lime", "orange"]),
        ("cream", ["cream", "cheese", "yogurt", "ricotta", "parmesan", "cheddar"]),
        ("curry", ["curry", "cumin", "turmeric", "garam", "coriander", "cardamom"]),
        ("smoky", ["smoked", "bacon", "paprika", "chipotle"]),
        ("garlic", ["garlic"]),
        ("sweet", ["honey", "maple", "brown sugar"]),
        ("nutty", ["peanut", "almond", "walnut", "sesame"]),
    ]

    private static let dishFamilies: [(String, [String])] = [
        ("soup", ["soup", "chowder", "bisque", "stew", "chili", "chilli", "gumbo"]),
        ("pasta", ["pasta", "spaghetti", "lasagna", "lasagne", "noodle", "ramen", "macaroni"]),
        ("salad", ["salad", "slaw"]),
        ("sandwich", ["sandwich", "panini", "burger", "taco", "burrito", "wrap"]),
        ("pizza", ["pizza"]),
        ("stir-fry", ["stir-fry", "stir fry", "wok", "fried rice"]),
        ("roast", ["roast", "baked", "sheet pan"]),
        ("curry", ["curry", "tikka", "masala"]),
        ("grill", ["grill", "kebab", "broil"]),
        ("casserole", ["casserole", "gratin", "bake"]),
        ("breakfast", ["pancake", "waffle", "omelet", "omelette", "scramble"]),
    ]

    private static let stop: Set<String> = pantry.union([
        "fresh", "dried", "ground", "minced", "chopped", "sliced", "large", "small", "medium",
        "optional", "white", "black", "red", "green", "cup", "tbsp", "tsp", "ounce", "ounces",
        "pound", "pounds", "the", "and", "with", "for",
    ])

    private static let proteinTokens: Set<String> = [
        "chicken", "turkey", "hen", "duck", "beef", "steak", "burger", "pork", "bacon", "ham", "sausage",
        "prosciutto", "lamb", "salmon", "tuna", "cod", "fish", "trout", "halibut", "shrimp", "prawn",
        "crab", "lobster", "mussel", "clam", "scallop", "tofu", "tempeh", "egg", "eggs", "bean", "beans",
        "lentil", "lentils", "chickpea", "chickpeas", "breast", "thigh", "fillet", "tenderloin",
        "sirloin", "brisket", "chop", "chops", "ribs",
    ]

    struct FlavorProfile {
        var items: Set<String>
        var proteins: Set<String>
        var flavors: Set<String>
        var dishFamily: String
        var nameTokens: Set<String>
        var overlapTokens: Set<String>
    }

    struct Result {
        var mains: [Recipe]
        var sides: [Recipe]
        var scores: [String: Double]
    }

    struct Settings: Sendable {
        let dietRaw: String
        let dietaryRestrictionsText: String
        let enabledSources: [String]
        let cookingComplexity: Int

        init(_ profile: UserProfileEntity) {
            dietRaw = profile.dietRaw
            dietaryRestrictionsText = profile.dietaryRestrictionsText
            enabledSources = profile.enabledSources
            cookingComplexity = profile.cookingComplexity
        }

        init(
            dietRaw: String = "none",
            dietaryRestrictionsText: String = "",
            enabledSources: [String] = [],
            cookingComplexity: Int = 3
        ) {
            self.dietRaw = dietRaw
            self.dietaryRestrictionsText = dietaryRestrictionsText
            self.enabledSources = enabledSources
            self.cookingComplexity = cookingComplexity
        }

        var dietKey: String? { DietProfile(rawValue: dietRaw)?.storeKey }
        var dislikes: [String] { DislikeMatcher.parse(dietaryRestrictionsText) }
    }

    static func plan(
        store: RecipeDatabase,
        profile: UserProfileEntity,
        bannedIDs: Set<String>,
        days: Int = 7
    ) -> Result {
        plan(store: store, settings: Settings(profile), bannedIDs: bannedIDs, days: days)
    }

    static func plan(
        store: RecipeDatabase,
        settings: Settings,
        bannedIDs: Set<String>,
        days: Int = 7
    ) -> Result {
        let diet = settings.dietKey
        let exclude = settings.dislikes
        let sources = Set(settings.enabledSources.map { $0.lowercased() })
        let complexity = RecipeComplexity.clamped(settings.cookingComplexity)
        let preferredProteins = preferredCoreProteins(diet: diet)

        // Prefer staying in-band; only widen one step for Simple, two for Easy.
        var mainsPool = candidatePool(
            store.allRecipes(),
            course: "main",
            diet: diet,
            exclude: exclude,
            banned: bannedIDs,
            sources: sources,
            complexity: complexity,
            minCount: days * 3,
            maxWiden: complexity <= 1 ? 1 : (complexity == 2 ? 2 : 4)
        )
        if mainsPool.count < days {
            // Last resort: still avoid dumping level-5 exotics into a Simple week.
            let rescueLevel = min(5, complexity + (complexity <= 2 ? 2 : 4))
            mainsPool += candidatePool(
                store.allRecipes(),
                course: "main",
                diet: diet,
                exclude: exclude,
                banned: bannedIDs,
                sources: sources,
                complexity: rescueLevel,
                minCount: days,
                maxWiden: 0
            )
            var seen = Set<String>()
            mainsPool = mainsPool.filter { seen.insert($0.id).inserted }
        }
        mainsPool = Array(mainsPool.prefix(800))
        do {
            var seen = Set<String>()
            mainsPool = mainsPool.filter { seen.insert($0.id).inserted }
        }
        guard !mainsPool.isEmpty else {
            return Result(mains: [], sides: [], scores: [:])
        }

        var profiles = Dictionary(mainsPool.map { ($0.id, flavor($0)) }, uniquingKeysWith: { first, _ in first })
        let idf = idfWeights(Array(profiles.values))
        let partners = partnerCounts(profiles)

        var selected: [Recipe] = []
        var remaining = mainsPool
        var cartSKUs: Set<String> = []
        for _ in 0..<min(days, remaining.count) {
            let pick = pickNext(
                remaining: remaining,
                selected: selected,
                profiles: profiles,
                idf: idf,
                partners: partners,
                complexity: complexity,
                preferredProteins: preferredProteins,
                cartSKUs: cartSKUs
            )
            selected.append(pick)
            cartSKUs.formUnion(RecipeComplexity.shoppableItems(pick))
            remaining.removeAll { $0.id == pick.id }
        }

        var sidesPool = candidatePool(
            store.allRecipes(),
            course: "side",
            diet: diet,
            exclude: exclude,
            banned: bannedIDs.union(Set(selected.map(\.id))),
            sources: sources,
            complexity: complexity,
            minCount: days * 3,
            maxWiden: complexity <= 1 ? 1 : (complexity == 2 ? 2 : 4)
        )
        if sidesPool.count < days {
            let extra = store.allRecipes().filter { recipe in
                if selected.contains(where: { $0.id == recipe.id }) { return false }
                if recipe.course == "dessert" || recipe.course == "drink" || recipe.course == "sauce" { return false }
                if looksLikeBreakfast(recipe) || looksLikeCondiment(recipe) { return false }
                if !matchesDiet(recipe, diet: diet) { return false }
                if DislikeMatcher.blocks(recipe, dislikes: exclude) { return false }
                if !RecipeComplexity.fits(recipe, level: min(5, complexity + 1), course: "side") { return false }
                return !isSubstantialMain(recipe)
            }
            var seen = Set(sidesPool.map(\.id) + selected.map(\.id))
            sidesPool += extra.filter { seen.insert($0.id).inserted }
        }

        var usedSides: Set<String> = []
        var usedKinds: Set<SideCatalog.Entry.Kind> = []
        var sides: [Recipe] = []
        for main in selected {
            let mainProf = profiles[main.id] ?? flavor(main)
            if let side = pickSide(
                sidesPool,
                main: main,
                used: usedSides,
                usedKinds: usedKinds,
                mainProfile: mainProf,
                exclude: exclude,
                complexity: complexity,
                cartSKUs: cartSKUs
            ) {
                usedSides.insert(side.id)
                cartSKUs.formUnion(RecipeComplexity.shoppableItems(side))
                if let kind = SideCatalog.match(side)?.kind {
                    usedKinds.insert(kind)
                }
                sides.append(side)
            } else {
                sides.append(main) // placeholder unused; caller should check id uniqueness
            }
        }

        return Result(mains: selected, sides: sides, scores: planScores(selected, profiles: profiles, idf: idf))
    }

    /// Swap one main for the next-best unused candidate.
    static func swapMain(
        current: Recipe,
        keep: [Recipe],
        store: RecipeDatabase,
        profile: UserProfileEntity,
        bannedIDs: Set<String>
    ) -> Recipe? {
        let settings = Settings(profile)
        let diet = settings.dietKey
        let complexity = RecipeComplexity.clamped(settings.cookingComplexity)
        let preferredProteins = preferredCoreProteins(diet: diet)
        let candidates = candidatePool(
            store.allRecipes(),
            course: "main",
            diet: diet,
            exclude: settings.dislikes,
            banned: bannedIDs.union([current.id]),
            sources: Set(settings.enabledSources.map { $0.lowercased() }),
            complexity: complexity,
            minCount: 24,
            maxWiden: complexity <= 2 ? 2 : 4
        )
        let profiles = Dictionary(
            (keep + candidates).map { ($0.id, flavor($0)) },
            uniquingKeysWith: { first, _ in first }
        )
        let idf = idfWeights(Array(profiles.values))
        let partners = partnerCounts(profiles)
        let remaining = candidates.filter { rec in !keep.contains(where: { $0.id == rec.id }) }
        guard !remaining.isEmpty else { return nil }
        var cart: Set<String> = []
        for r in keep { cart.formUnion(RecipeComplexity.shoppableItems(r)) }
        return pickNext(
            remaining: remaining,
            selected: keep,
            profiles: profiles,
            idf: idf,
            partners: partners,
            complexity: complexity,
            preferredProteins: preferredProteins,
            cartSKUs: cart
        )
    }

    static func scale(_ recipe: Recipe, servings: Double) -> Recipe {
        let base = Double(recipe.baseServings)
        let factor = servings / max(base, 1)
        var copy = recipe
        copy.parsedIngredients = recipe.parsedIngredients.map { $0.scaled(by: factor) }
        copy.ingredients = copy.parsedIngredients.map { $0.display() }
        copy.yieldText = "\(ParsedIngredient.formatQty(servings)) servings"
        return copy
    }

    // MARK: - Filters

    static func matchesDiet(_ allergens: [String], diet: String?) -> Bool {
        guard let diet else { return true }
        let blocked: Set<String>
        switch diet {
        case "vegetarian": blocked = ["meat", "fish", "shellfish"]
        case "vegan": blocked = ["meat", "fish", "shellfish", "dairy", "egg", "honey"]
        case "pescatarian": blocked = ["meat"]
        case "dairy_free": blocked = ["dairy"]
        case "gluten_free": blocked = ["gluten"]
        case "nut_free": blocked = ["peanut", "tree_nut"]
        case "egg_free": blocked = ["egg"]
        case "soy_free": blocked = ["soy"]
        case "shellfish_free": blocked = ["shellfish"]
        default: return true
        }
        return Set(allergens.map { $0.lowercased() }).isDisjoint(with: blocked)
    }

    /// Allergen tags are incomplete in cookbook data — also gate on detected proteins.
    static func matchesDiet(_ recipe: Recipe, diet: String?) -> Bool {
        guard matchesDiet(recipe.allergens, diet: diet) else { return false }
        guard let diet else { return true }
        let proteins = flavor(recipe).proteins
        switch diet {
        case "vegetarian", "vegan":
            let animal: Set<String> = ["chicken", "beef", "pork", "lamb", "fish", "shellfish"]
            if !proteins.isDisjoint(with: animal) { return false }
            if diet == "vegan", proteins.contains("egg") { return false }
            return true
        case "pescatarian":
            let land: Set<String> = ["chicken", "beef", "pork", "lamb"]
            return proteins.isDisjoint(with: land)
        default:
            return true
        }
    }

    private static func filtered(
        _ all: [Recipe],
        course: String,
        diet: String?,
        exclude: [String],
        banned: Set<String>,
        sources: Set<String> = [],
        complexity: Int = 5
    ) -> [Recipe] {
        all.filter { recipe in
            if banned.contains(recipe.id) { return false }
            if !sources.isEmpty {
                let src = recipe.source.lowercased()
                if !sources.contains(where: { src.contains($0) }) { return false }
            }
            if recipe.course != course {
                // Legacy recipes often tagged as main course in tags.
                if course == "main" {
                    if !looksLikeDinnerMainCourse(recipe) { return false }
                } else if recipe.course != course {
                    return false
                }
            }
            if looksLikeBreakfast(recipe) { return false }
            let minIngredients = course == "side" ? 2 : 4
            if recipe.parsedIngredients.count < minIngredients { return false }
            // Missing instructions = not cookable from this DB entry.
            if recipe.steps.isEmpty { return false }
            if !matchesDiet(recipe, diet: diet) { return false }
            if looksLikeCondiment(recipe) { return false }
            if DislikeMatcher.blocks(recipe, dislikes: exclude) { return false }
            if !RecipeComplexity.fits(recipe, level: complexity, course: course) { return false }
            // Dinners must be substantial protein mains — light/veggie dishes are sides.
            if course == "main", !isSubstantialMain(recipe) { return false }
            if complexity <= 2, looksLikeAdvancedTechnique(recipe) { return false }
            if complexity <= 2, looksLikeRequiresPriorRecipe(recipe) { return false }
            if complexity <= 2, course == "main", looksLikeOrganMeatMain(recipe) { return false }
            if complexity <= 2, course == "main", looksLikeStarchForwardMain(recipe) { return false }
            if complexity <= 2, course == "main", hasNicheProtein(recipe, level: complexity) { return false }
            if complexity <= 2, course == "side", looksLikeFussySide(recipe) { return false }
            return true
        }
    }

    private static func candidatePool(
        _ all: [Recipe],
        course: String,
        diet: String?,
        exclude: [String],
        banned: Set<String>,
        sources: Set<String>,
        complexity: Int,
        minCount: Int,
        maxWiden: Int = 4
    ) -> [Recipe] {
        var level = complexity
        var result = filtered(all, course: course, diet: diet, exclude: exclude, banned: banned, sources: sources, complexity: level)
        var widened = 0
        while result.count < minCount, level < 5, widened < maxWiden {
            level += 1
            widened += 1
            result = filtered(all, course: course, diet: diet, exclude: exclude, banned: banned, sources: sources, complexity: level)
        }
        return result
    }

    /// Proteins that feel realistic for a weekly supermarket shop under the given diet.
    static func preferredCoreProteins(diet: String?) -> Set<String> {
        switch diet {
        case "vegan":
            return ["tofu", "bean"]
        case "vegetarian":
            return ["tofu", "bean", "egg"]
        case "pescatarian":
            return ["fish", "egg", "tofu", "bean"]
        default:
            return ["chicken", "beef", "pork", "egg", "tofu", "bean"]
        }
    }

    private static func looksLikeCondiment(_ recipe: Recipe) -> Bool {
        let name = recipe.name.lowercased()
        return ["pickle", "vinaigrette", "dressing", "marinade", "seasoning", "syrup", "stock", "broth"]
            .contains { name.contains($0) }
    }

    /// Gear / technique that a Simple/Easy once-a-week cook is unlikely to want.
    static func looksLikeAdvancedTechnique(_ recipe: Recipe) -> Bool {
        let blob = ([recipe.name, recipe.chapter, recipe.section] + recipe.tags + recipe.ingredients)
            .joined(separator: " ")
            .lowercased()
        let needles = [
            "sous-vide", "sous vide", "immersion circulator",
            "pressure can", "molecular", "spherif",
            "deep-fried", "deep fried", "deep fry", "fritur", "deep-fryer", "deep fryer",
            "confit", "torch", "smoke gun", "cryo",
            "wonton", "dumpling wrapper", "gyoza wrapper",
            "tempura", "pâte à choux", "pate a choux",
        ]
        return needles.contains { blob.contains($0) }
    }

    /// Depends on another cookbook recipe first (Poached Chicken, Lemon Marinade, …).
    static func looksLikeRequiresPriorRecipe(_ recipe: Recipe) -> Bool {
        let lines = recipe.parsedIngredients.isEmpty
            ? recipe.ingredients
            : recipe.parsedIngredients.map { $0.item.isEmpty ? $0.raw : $0.item }
        for line in lines {
            let l = line.lowercased()
            if l.range(of: #"^(poached|roasted|grilled|braised)\s+(chicken|beef|pork|turkey)\b"#, options: .regularExpression) != nil {
                return true
            }
            if l.contains("marinade") && (l.contains(" or ") || l.contains(",")) { return true }
            if l.contains("pan sauce") && l.contains(" or ") { return true }
        }
        let stepBlob = recipe.steps.map(\.instruction).joined(separator: " ").lowercased()
        if stepBlob.contains("see here"), stepBlob.contains("pan sauce") { return true }
        // Joy-of-Cooking "Have ready:" stubs with no quantities in the step itself.
        let stubs = recipe.steps.filter {
            let t = $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return t == "have ready:" || t == "season with:" || t == "pat dry:" || t.hasPrefix("have ready")
        }
        if stubs.count >= 2 { return true }
        if recipe.steps.contains(where: {
            $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.ingredients.isEmpty
        }) {
            return true
        }
        return false
    }

    static func looksLikeOrganMeatMain(_ recipe: Recipe) -> Bool {
        let blob = ([recipe.name] + recipe.ingredients + recipe.parsedIngredients.map(\.item))
            .joined(separator: " ")
            .lowercased()
        return ["liver", "kidney", "heart", "tongue", "tripe", "sweetbread", "gizzard", "offal"]
            .contains { blob.contains($0) }
    }

    /// Potato bakes / cheese crisps / wonton plates that sneak through as "mains".
    static func looksLikeStarchForwardMain(_ recipe: Recipe) -> Bool {
        let name = recipe.name.lowercased()
        let starchTitles = [
            "potato bake", "scalloped potato", "au gratin", "frico", "cheese crisp",
            "mashed potato", "french fries", "sweet potato fries", "hash brown",
            "mac and cheese", "macaroni and cheese", "grilled cheese",
            "egg drop soup", "shrimp salad", "tuna salad", "chicken salad",
        ]
        if starchTitles.contains(where: { name.contains($0) }) { return true }
        let proteins = flavor(recipe).proteins
        if proteins.isEmpty || proteins == ["egg"] {
            if looksLikeStarchOrGrainSide(recipe) { return true }
        }
        return false
    }

    static func looksLikeFussySide(_ recipe: Recipe) -> Bool {
        let name = recipe.name.lowercased()
        return ["frico", "cheese crisp", "soufflé", "souffle", "puff pastry", "phyllo", "filo"]
            .contains { name.contains($0) }
    }

    /// Shellfish / lamb / game — fine for adventurous cooks, not Simple/Easy supermarket weeks.
    static func hasNicheProtein(_ recipe: Recipe, level: Int) -> Bool {
        let proteins = flavor(recipe).proteins
        if proteins.contains("shellfish") { return true }
        if level <= 1, proteins.contains("fish") { return true }
        if proteins.contains("lamb") { return true }
        let blob = ([recipe.name] + recipe.parsedIngredients.map(\.item) + recipe.ingredients)
            .joined(separator: " ")
            .lowercased()
        let game = ["venison", "bison", "elk", "duck", "quail", "rabbit", "goat", "cornish hen", "guinea hen"]
        return game.contains { blob.contains($0) }
    }

    static func looksLikeBreakfast(_ recipe: Recipe) -> Bool {
        if recipe.course == "breakfast" { return true }
        let blob = ([recipe.course, recipe.name, recipe.chapter, recipe.section] + recipe.tags)
            .joined(separator: " ")
            .lowercased()
        if blob.contains("breakfast") || blob.contains("brunch") { return true }
        let name = recipe.name.lowercased()
        return ["pancake", "waffle", "omelet", "omelette", "scramble", "french toast", "overnight oat"]
            .contains { name.contains($0) }
    }

    // MARK: - Flavor

    static func flavor(_ recipe: Recipe) -> FlavorProfile {
        let items = Set(recipe.parsedIngredients.map { $0.item.lowercased() }.filter { !$0.isEmpty })
        let rawBlob = ([recipe.name, recipe.chapter] + recipe.ingredients + Array(items)).joined(separator: " ").lowercased()
        let blob = proteinScanBlob(rawBlob)
        var proteins: Set<String> = []
        for (label, needles) in proteinNeedles {
            if label == "egg" {
                // "egg" must not match eggplant / egg noodles.
                if blob.range(of: #"\beggs?\b"#, options: .regularExpression) != nil,
                   !blob.contains("eggplant"),
                   !blob.contains("egg noodle"),
                   !blob.contains("egg wash") {
                    proteins.insert(label)
                }
                continue
            }
            if needles.contains(where: { blob.contains($0) }) {
                proteins.insert(label)
            }
        }
        var flavors: Set<String> = []
        for (label, needles) in flavorNeedles where needles.contains(where: { rawBlob.contains($0) }) {
            flavors.insert(label)
        }
        var dish = "other"
        for (label, needles) in dishFamilies where needles.contains(where: { rawBlob.contains($0) }) {
            dish = label
            break
        }
        let nameTokens = Set(
            recipe.name.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 3 && !["the", "and", "with", "for", "from"].contains($0) }
        )
        var overlap: Set<String> = []
        for item in items where !pantry.contains(item) {
            // Proteins never drive grocery-overlap scoring (only produce/pantry/etc.).
            if isProteinItem(item) { continue }
            for tok in item.split { !$0.isLetter }.map(String.init) where tok.count >= 3 {
                if stop.contains(tok) || proteinTokens.contains(tok) { continue }
                overlap.insert(tok)
            }
        }
        return FlavorProfile(items: items, proteins: proteins, flavors: flavors, dishFamily: dish, nameTokens: nameTokens, overlapTokens: overlap)
    }

    /// True when an ingredient line is (or is mostly) a protein.
    static func isProteinItem(_ item: String) -> Bool {
        let s = item.lowercased()
        if s.contains("eggplant") || s.contains("egg noodle") || s.contains("egg wash") || s.contains("egg drop") {
            return false
        }
        // Broth/stock/sauce are flavor bases, not a protein centerpiece.
        if s.contains("broth") || s.contains("stock") || s.contains("bouillon") { return false }
        if s.contains("fish sauce") || s.contains("oyster sauce") { return false }
        if s.range(of: #"\beggs?\b"#, options: .regularExpression) != nil { return true }
        for (label, needles) in proteinNeedles where label != "egg" {
            if needles.contains(where: { s.contains($0) }) { return true }
        }
        return false
    }

    /// Strip stock/sauce phrases so "chicken broth" does not count as chicken protein.
    private static func proteinScanBlob(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(
            of: #"\b(chicken|turkey|beef|veal|lamb|fish|seafood|vegetable|veggie|mushroom)\s+(broth|stock|bouillon)s?\b"#,
            with: " ",
            options: .regularExpression
        )
        s = s.replacingOccurrences(of: #"\bfish sauce\b"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\boyster sauce\b"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s
    }

    /// Non-pantry, non-protein ingredients — used for shared-grocery overlap.
    static func overlapItems(in profile: FlavorProfile) -> Set<String> {
        Set(profile.items.filter { !pantry.contains($0) && !isProteinItem($0) })
    }

    /// Dinner mains must include a real protein (meat, fish, egg, tofu, beans…).
    static func hasProtein(_ recipe: Recipe) -> Bool {
        !flavor(recipe).proteins.isEmpty
    }

    /// Strict dinner-main gate: protein centerpiece, not a light/veggie/side dish.
    static func isSubstantialMain(_ recipe: Recipe) -> Bool {
        // Starch-titled dishes (baked rice, mashed potatoes…) are sides even if
        // the cookbook miscategorized them as "main".
        if looksLikeStarchOrGrainSide(recipe) { return false }
        guard hasProtein(recipe) else { return false }
        if looksLikeVeggieOnlySide(recipe) { return false }
        if looksLikeLightOrSideDish(recipe) { return false }
        if !looksLikeDinnerMainCourse(recipe) { return false }
        if recipe.parsedIngredients.count < 4 { return false }

        let prof = flavor(recipe)
        // Egg alone (no meat/fish/tofu/beans) is not a dinner main.
        if prof.proteins == ["egg"] { return false }
        // Bean-only needs a real meal shape (chili/stew/curry/pasta…), not a salad or roast veg.
        if prof.proteins == ["bean"] {
            let ok: Set<String> = ["soup", "stew", "chili", "curry", "pasta", "casserole", "stir-fry"]
            if !ok.contains(prof.dishFamily) { return false }
        }
        return true
    }

    /// Course / tags must read as a dinner main — not a loose "other" or lunch leftover dish.
    /// Do not trust a wrong cookbook `course == main` when the title is clearly a side.
    static func looksLikeDinnerMainCourse(_ recipe: Recipe) -> Bool {
        if looksLikeStarchOrGrainSide(recipe) || looksLikeLightOrSideDish(recipe) {
            return false
        }
        if recipe.course == "main" { return true }
        let blob = ([recipe.course, recipe.name, recipe.chapter, recipe.section] + recipe.tags)
            .joined(separator: " ")
            .lowercased()
        if blob.contains("main") || blob.contains("dinner") || blob.contains("entree") || blob.contains("entrée") {
            return true
        }
        return false
    }

    /// Veggie-forward dishes belong as sides, not dinners.
    static func looksLikeVeggieOnlySide(_ recipe: Recipe) -> Bool {
        if hasProtein(recipe) { return false }
        let blob = ([recipe.course, recipe.name, recipe.chapter] + recipe.tags)
            .joined(separator: " ")
            .lowercased()
        if recipe.course == "side" { return true }
        return ["salad", "vegetable", "veggie", "slaw", "greens", "broccoli", "asparagus", "cauliflower", "cabbage", "spinach", "kale", "zucchini", "potato", "rice", "quinoa", "farro", "couscous", "polenta"]
            .contains { blob.contains($0) }
    }

    /// Rice / potato / grain dishes whose title is the starch (not "chicken and rice").
    static func looksLikeStarchOrGrainSide(_ recipe: Recipe) -> Bool {
        let name = recipe.name.lowercased()
        let starchNeedles = [
            "rice", "pilaf", "risotto", "potato", "polenta", "quinoa",
            "couscous", "farro", "bulgur", "grits", "orzo", "noodles", "pasta salad",
        ]
        guard starchNeedles.contains(where: { name.contains($0) }) else { return false }

        // Title names a dinner protein → can be a main (chicken fried rice, shrimp risotto).
        let titleProtein = [
            "chicken", "turkey", "beef", "pork", "lamb", "veal", "duck",
            "salmon", "tuna", "shrimp", "prawn", "cod", "fish", "tofu",
            "sausage", "bacon", "ham", "steak",
        ]
        if titleProtein.contains(where: { name.contains($0) }) { return false }

        // "Baked rice", "mashed potatoes", "mushroom risotto" without meat in the name.
        // If ingredients also lack real protein (broth doesn't count), definitely a side.
        if !hasProtein(recipe) { return true }

        // Even with a garnish protein, a starch title with a cooking-method pattern is a side.
        let sideShapes = [
            "baked rice", "steamed rice", "white rice", "brown rice", "coconut rice",
            "rice pilaf", "buttered rice", "simple rice",
            "mashed potato", "baked potato", "roasted potato", "scalloped potato",
            "boiled potato", "smashed potato",
            "plain polenta", "creamed polenta", "basic polenta",
        ]
        if sideShapes.contains(where: { name.contains($0) }) { return true }

        // Short starch titles: "Rice", "Potatoes", "Polenta", "Quinoa"
        let compact = name.replacingOccurrences(of: #"[^a-z\s]"#, with: "", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        let fillers: Set<String> = [
            "the", "a", "an", "and", "with", "of", "in", "basic", "simple", "plain",
            "baked", "boiled", "steamed", "roasted", "fried", "mashed", "scalloped",
            "creamed", "buttered", "perfect", "best", "easy", "classic", "joy",
        ]
        let core = compact.filter { !fillers.contains($0) }
        if core.count <= 2, core.contains(where: { starchNeedles.contains($0) || $0.hasPrefix("potato") }) {
            return true
        }
        return false
    }

    /// Appetizers, salads-as-meals without heft, snacks, breads — not dinner mains.
    static func looksLikeLightOrSideDish(_ recipe: Recipe) -> Bool {
        if recipe.course == "side" || recipe.course == "appetizer" || recipe.course == "snack"
            || recipe.course == "bread" || recipe.course == "dessert" || recipe.course == "drink"
            || recipe.course == "sauce" {
            return true
        }
        if looksLikeStarchOrGrainSide(recipe) { return true }
        let blob = ([recipe.course, recipe.name, recipe.chapter, recipe.section] + recipe.tags)
            .joined(separator: " ")
            .lowercased()
        let lightNeedles = [
            "appetizer", "starter", "snack", "dip", "spread", "relish", "garnish",
            "side dish", "side salad", "bread", "biscuit", "muffin", "crostini", "bruschetta",
            "roasted vegetable", "sauteed green", "sautéed green", "steamed vegetable",
            "filling", "stuffing",
        ]
        if lightNeedles.contains(where: { blob.contains($0) }) { return true }
        // Plain salads without a clear protein centerpiece title stay sides.
        let name = recipe.name.lowercased()
        if name.contains("salad"), !hasProtein(recipe) { return true }
        if name.hasSuffix(" salad") || name.contains(" salad ") {
            let prots = flavor(recipe).proteins
            // Chicken/tuna/shrimp salads can be mains; green/potato/cabbage salads cannot.
            if prots.isEmpty || prots == ["bean"] || prots == ["egg"] { return true }
        }
        return false
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty && b.isEmpty { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    private static func idfWeights(_ profiles: [FlavorProfile]) -> [String: Double] {
        let n = max(profiles.count, 1)
        var df: [String: Int] = [:]
        for p in profiles {
            for tok in p.overlapTokens { df[tok, default: 0] += 1 }
        }
        return df.mapValues { mathLog(Double(n + 1) / Double($0 + 1)) + 1 }
    }

    private static func weightedOverlap(_ items: Set<String>, pool: Set<String>, idf: [String: Double]) -> Double {
        guard !items.isEmpty else { return 0 }
        let num = items.intersection(pool).reduce(0) { $0 + (idf[$1] ?? 1) }
        let den = items.reduce(0) { $0 + (idf[$1] ?? 1) }
        return den == 0 ? 0 : num / den
    }

    private static func partnerCounts(_ profiles: [String: FlavorProfile]) -> [String: Int] {
        var inverted: [String: Set<String>] = [:]
        for (rid, prof) in profiles {
            for tok in prof.overlapTokens { inverted[tok, default: []].insert(rid) }
        }
        let df = inverted.mapValues(\.count)
        var counts: [String: Int] = [:]
        for (rid, prof) in profiles {
            var score = 0.0
            for tok in prof.overlapTokens {
                let n = df[tok] ?? 0
                if n >= 6 && n <= max(profiles.count / 3, 12) {
                    score += mathLog(Double(n))
                }
            }
            counts[rid] = Int(score * 100)
        }
        return counts
    }

    private static func pickNext(
        remaining: [Recipe],
        selected: [Recipe],
        profiles: [String: FlavorProfile],
        idf: [String: Double],
        partners: [String: Int],
        complexity: Int,
        preferredProteins: Set<String> = ["chicken", "beef", "pork", "egg", "tofu", "bean"],
        cartSKUs: Set<String> = []
    ) -> Recipe {
        let skuBudget = RecipeComplexity.weeklySKUBudget(for: complexity)
        let lowComplexity = complexity <= 2
        let overlapWeight = lowComplexity ? 3.4 : 2.6
        let varietyWeight = lowComplexity ? 0.55 : 1.0

        if selected.isEmpty {
            return remaining.min { a, b in
                let pa = profiles[a.id]!, pb = profiles[b.id]!
                let coreA = pa.proteins.isDisjoint(with: preferredProteins) ? 1 : 0
                let coreB = pb.proteins.isDisjoint(with: preferredProteins) ? 1 : 0
                let ta = (
                    coreA,
                    RecipeComplexity.penalty(a, level: complexity),
                    -(partners[a.id] ?? 0),
                    -pa.proteins.count,
                    -pa.overlapTokens.count
                )
                let tb = (
                    coreB,
                    RecipeComplexity.penalty(b, level: complexity),
                    -(partners[b.id] ?? 0),
                    -pb.proteins.count,
                    -pb.overlapTokens.count
                )
                return ta < tb
            } ?? remaining[0]
        }
        var pool: Set<String> = []
        let selectedProfs = selected.compactMap { profiles[$0.id] }
        for p in selectedProfs { pool.formUnion(p.overlapTokens) }
        var proteinCounts: [String: Int] = [:]
        var familyCounts: [String: Int] = [:]
        for p in selectedProfs {
            for prot in p.proteins { proteinCounts[prot, default: 0] += 1 }
            familyCounts[p.dishFamily, default: 0] += 1
        }
        let last = selectedProfs.last!
        var best: Recipe?
        var bestScore = -1e9
        for recipe in remaining {
            let prof = profiles[recipe.id] ?? flavor(recipe)
            let items = prof.overlapTokens
            let overlap = 0.5 * jaccard(items, pool) + 0.5 * weightedOverlap(items, pool: pool, idf: idf)
            let flavorSim = jaccard(prof.flavors, last.flavors)
            let nameSim = jaccard(prof.nameTokens, last.nameTokens)
            let weekFlavor = selectedProfs.map { jaccard(prof.flavors, $0.flavors) }.max() ?? 0
            let sameProtein = prof.proteins.isDisjoint(with: last.proteins) ? 0.0 : 1.0
            let sameFamily = (prof.dishFamily == last.dishFamily && prof.dishFamily != "other") ? 1.0 : 0.0
            let proteinRepeat = prof.proteins.map { proteinCounts[$0] ?? 0 }.max() ?? 0
            let familyRepeat = familyCounts[prof.dishFamily] ?? 0
            let variety = 1.0 - 0.5 * weekFlavor - 0.5 * flavorSim

            let newSKUs = Set(RecipeComplexity.shoppableItems(recipe)).subtracting(cartSKUs)
            let projected = cartSKUs.count + newSKUs.count
            let overBudget = max(0, projected - skuBudget)
            let skuPenalty = lowComplexity ? 0.35 * Double(overBudget) + 0.08 * Double(newSKUs.count) : 0.05 * Double(overBudget)

            let coreHit = prof.proteins.isDisjoint(with: preferredProteins) ? 0.0 : 1.0
            let specialtyProtein: Double = {
                if complexity > 2 { return 0 }
                let niche: Set<String> = ["lamb", "shellfish", "fish"]
                return prof.proteins.isDisjoint(with: niche) ? 0 : 1.0
            }()

            let score =
                overlapWeight * overlap
                + varietyWeight * variety
                + (lowComplexity ? 0.85 : 0.35) * coreHit
                - 2.8 * sameProtein
                - 2.5 * sameFamily
                - 2.2 * nameSim
                - 0.6 * Double(proteinRepeat)
                - 0.7 * Double(familyRepeat)
                - (lowComplexity ? 1.1 : 0.4) * specialtyProtein
                - skuPenalty
                - RecipeComplexity.penalty(recipe, level: complexity)
            if score > bestScore {
                bestScore = score
                best = recipe
            }
        }
        return best ?? remaining[0]
    }

    private static func pickSide(
        _ sides: [Recipe],
        main: Recipe,
        used: Set<String>,
        usedKinds: Set<SideCatalog.Entry.Kind>,
        mainProfile: FlavorProfile,
        exclude: [String] = [],
        complexity: Int = 5,
        cartSKUs: Set<String> = []
    ) -> Recipe? {
        // Produce/pantry overlap only — proteins never drive side pairing.
        let mainItems = overlapItems(in: mainProfile)
        let skuBudget = RecipeComplexity.weeklySKUBudget(for: complexity)
        var best: Recipe?
        var bestScore = -1e9
        for side in sides where !used.contains(side.id) {
            if DislikeMatcher.blocks(side, dislikes: exclude) { continue }
            if !RecipeComplexity.fits(side, level: complexity, course: "side") {
                if !RecipeComplexity.fits(side, level: min(5, complexity + 1), course: "side") {
                    continue
                }
            }
            let prof = flavor(side)
            let items = overlapItems(in: prof)
            let groceryOverlap = jaccard(items, mainItems)
            let tooClose = jaccard(prof.nameTokens, mainProfile.nameTokens)
            let catalog = SideCatalog.score(
                side: side,
                mainProteins: mainProfile.proteins,
                usedKinds: usedKinds,
                usedSideIDs: used
            )
            let newSKUs = Set(RecipeComplexity.shoppableItems(side)).subtracting(cartSKUs)
            let overBudget = max(0, cartSKUs.count + newSKUs.count - skuBudget)
            let skuPenalty = complexity <= 2
                ? 0.4 * Double(overBudget) + 0.12 * Double(newSKUs.count)
                : 0.05 * Double(overBudget)
            let score =
                2.4 * catalog
                + 1.4 * groceryOverlap
                - 1.6 * tooClose
                + 0.15 * Double(min(items.count, 6))
                - skuPenalty
                - RecipeComplexity.penalty(side, level: complexity)
            if score > bestScore {
                bestScore = score
                best = side
            }
        }
        return best
    }

    private static func planScores(_ mains: [Recipe], profiles: [String: FlavorProfile], idf: [String: Double]) -> [String: Double] {
        let profs = mains.compactMap { profiles[$0.id] }
        let itemSets = profs.map(\.overlapTokens)
        var pairwise: [Double] = []
        for i in itemSets.indices {
            for j in (i + 1)..<itemSets.count {
                pairwise.append(weightedOverlap(itemSets[i], pool: itemSets[j], idf: idf))
            }
        }
        var flavorPairs: [Double] = []
        for i in profs.indices {
            for j in (i + 1)..<profs.count {
                let a = profs[i].flavors.union(profs[i].proteins).union([profs[i].dishFamily])
                let b = profs[j].flavors.union(profs[j].proteins).union([profs[j].dishFamily])
                flavorPairs.append(jaccard(a, b))
            }
        }
        var adj = 0
        for (a, b) in zip(profs, profs.dropFirst()) where !a.proteins.isDisjoint(with: b.proteins) {
            adj += 1
        }
        let union = itemSets.reduce(into: Set<String>()) { $0.formUnion($1) }
        return [
            "ingredient_overlap": pairwise.isEmpty ? 0 : (pairwise.reduce(0, +) / Double(pairwise.count) * 1000).rounded() / 1000,
            "flavor_diversity": flavorPairs.isEmpty ? 0 : ((1 - flavorPairs.reduce(0, +) / Double(flavorPairs.count)) * 1000).rounded() / 1000,
            "unique_proteins": Double(Set(profs.flatMap(\.proteins)).count),
            "adjacent_protein_repeats": Double(adj),
            "shopping_skus": Double(union.count),
        ]
    }

    private static func mathLog(_ x: Double) -> Double { log(x) }
}
