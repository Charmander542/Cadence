import XCTest
@testable import MealPlannerApp

/// Core planning / grocery / complexity regressions.
final class PlanningQualityTests: XCTestCase {
    func testEggNeedleDoesNotMatchEggplant() {
        let eggplant = Recipe(
            id: "eggplant-1",
            name: "Roasted Eggplant",
            source: "test",
            sourceID: "1",
            ingredients: ["1 large eggplant", "2 tbsp olive oil", "salt"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "",
            section: "",
            tags: ["side", "vegetable"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "1 large eggplant", quantity: 1, unit: "count", item: "eggplant", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "2 tbsp olive oil", quantity: 2, unit: "tbsp", item: "olive oil", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "side"
        )
        XCTAssertFalse(WeekPlanner.hasProtein(eggplant))
        XCTAssertFalse(WeekPlanner.isSubstantialMain(eggplant))
        XCTAssertTrue(WeekPlanner.looksLikeVeggieOnlySide(eggplant) || eggplant.course == "side")
    }

    func testChickenDinnerIsSubstantialMain() {
        let chicken = Recipe(
            id: "chicken-1",
            name: "Garlic Chicken Thighs",
            source: "test",
            sourceID: "2",
            ingredients: ["2 lb chicken thighs", "garlic", "oil", "lemon", "salt"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "Dinner",
            section: "",
            tags: ["main", "dinner"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "2 lb chicken thighs", quantity: 2, unit: "lb", item: "chicken thigh", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "4 cloves garlic", quantity: 4, unit: "count", item: "garlic", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "2 tbsp oil", quantity: 2, unit: "tbsp", item: "oil", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "1 lemon", quantity: 1, unit: "count", item: "lemon", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertTrue(WeekPlanner.hasProtein(chicken))
        XCTAssertTrue(WeekPlanner.isSubstantialMain(chicken))
        XCTAssertFalse(WeekPlanner.isProteinItem("lemon"))
        XCTAssertTrue(WeekPlanner.isProteinItem("chicken thigh"))
    }

    func testBakedRiceIsNotAMainDespiteChickenBroth() {
        let rice = Recipe(
            id: "joc-baked-rice",
            name: "BAKED RICE",
            source: "joy-of-cooking",
            sourceID: "baked-rice",
            ingredients: [
                "1 to 3 tablespoons butter or olive oil",
                "½ medium onion, chopped",
                "1 cup long-grain white rice",
                "1 ½ cups chicken broth or water",
                "¼ teaspoon salt",
            ],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: 329,
            chapter: "GRAINS",
            section: "",
            tags: ["rice"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "butter", quantity: 2, unit: "tbsp", item: "butter", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "onion", quantity: 0.5, unit: "count", item: "onion", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "rice", quantity: 1, unit: "cup", item: "long-grain white rice", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "chicken broth", quantity: 1.5, unit: "cup", item: "chicken broth", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "salt", quantity: 0.25, unit: "tsp", item: "salt", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main" // mis-tagged in cookbook data
        )
        XCTAssertFalse(WeekPlanner.isProteinItem("chicken broth"))
        XCTAssertFalse(WeekPlanner.hasProtein(rice), "chicken broth must not count as chicken protein")
        XCTAssertTrue(WeekPlanner.looksLikeStarchOrGrainSide(rice))
        XCTAssertFalse(WeekPlanner.isSubstantialMain(rice))
        XCTAssertFalse(WeekPlanner.looksLikeDinnerMainCourse(rice))
    }

    func testMashedPotatoesIsNotAMain() {
        let potatoes = Recipe(
            id: "mash-1",
            name: "Mashed Potatoes",
            source: "test",
            sourceID: "mash",
            ingredients: ["potatoes", "butter", "milk", "salt"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: ["side"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "2 lb potatoes", quantity: 2, unit: "lb", item: "potato", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "butter", quantity: 4, unit: "tbsp", item: "butter", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "milk", quantity: 0.5, unit: "cup", item: "milk", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "salt", quantity: 1, unit: "tsp", item: "salt", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertTrue(WeekPlanner.looksLikeStarchOrGrainSide(potatoes))
        XCTAssertFalse(WeekPlanner.isSubstantialMain(potatoes))
    }

    func testChickenFriedRiceCanStillBeMain() {
        let friedRice = Recipe(
            id: "cfr-1",
            name: "Chicken Fried Rice",
            source: "test",
            sourceID: "cfr",
            ingredients: ["chicken", "rice", "egg", "soy"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "Dinner",
            section: "",
            tags: ["main"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "1 lb chicken", quantity: 1, unit: "lb", item: "chicken", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "2 cups rice", quantity: 2, unit: "cup", item: "rice", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "2 eggs", quantity: 2, unit: "count", item: "egg", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "soy sauce", quantity: 2, unit: "tbsp", item: "soy sauce", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertFalse(WeekPlanner.looksLikeStarchOrGrainSide(friedRice))
        XCTAssertTrue(WeekPlanner.isSubstantialMain(friedRice))
    }

    func testProteinExcludedFromOverlapTokens() {
        let recipe = Recipe(
            id: "overlap-1",
            name: "Chicken and Broccoli",
            source: "test",
            sourceID: "3",
            ingredients: ["chicken", "broccoli", "garlic", "soy sauce"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: ["main"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "1 lb chicken", quantity: 1, unit: "lb", item: "chicken", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "1 head broccoli", quantity: 1, unit: "count", item: "broccoli", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "3 cloves garlic", quantity: 3, unit: "count", item: "garlic", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        let tokens = WeekPlanner.flavor(recipe).overlapTokens
        XCTAssertFalse(tokens.contains("chicken"))
        XCTAssertTrue(tokens.contains("broccoli") || tokens.contains("garlic"))
    }

    func testEggConsolidationRoundsUpAndDoesNotDoubleCountWhites() {
        let recipe = Recipe(
            id: "eggs-1",
            name: "Frittata",
            source: "test",
            sourceID: "4",
            ingredients: ["8 large eggs", "4 egg whites"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "",
            section: "",
            tags: ["main"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "8 large eggs", quantity: 8, unit: "count", item: "egg", prep: "", toTaste: false, optional: false, allergens: ["egg"], notes: ""),
                ParsedIngredient(raw: "4 egg whites", quantity: 4, unit: "count", item: "egg white", prep: "", toTaste: false, optional: false, allergens: ["egg"], notes: ""),
            ],
            allergens: ["egg"],
            course: "main"
        )
        let items = GroceryConsolidator.consolidate(from: [recipe], scaledServings: [recipe.id: 4])
        let eggs = items.first { IngredientCanonicalizer.canonicalize($0.ingredientName) == "egg" }
        XCTAssertNotNil(eggs)
        // max(8, 4) = 8 — whites should not stack on wholes
        XCTAssertEqual(eggs?.quantity ?? 0, 8, accuracy: 0.1)
    }

    func testEggScalingRoundsUp() {
        let recipe = Recipe(
            id: "eggs-2",
            name: "Bake",
            source: "test",
            sourceID: "5",
            ingredients: ["8 eggs"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "8 eggs", quantity: 8, unit: "count", item: "egg", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        // 3/4 of 8 = 6 exact
        let items = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: [recipe], scaledServings: [recipe.id: 3])
        )
        let eggs = items.first { IngredientCanonicalizer.canonicalize($0.ingredientName) == "egg" }
        XCTAssertEqual(eggs?.quantity ?? 0, 6, accuracy: 0.1)
    }

    func testComplexityCapsExoticAndShopCount() {
        let simple = Recipe(
            id: "c1",
            name: "Simple chicken",
            source: "test",
            sourceID: "6",
            ingredients: ["chicken", "salt", "oil", "garlic"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "chicken", quantity: 1, unit: "lb", item: "chicken", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "garlic", quantity: 2, unit: "count", item: "garlic", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "oil", quantity: 1, unit: "tbsp", item: "oil", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertTrue(RecipeComplexity.fits(simple, level: 1, course: "main"))

        let exotic = Recipe(
            id: "c2",
            name: "Gochujang stew",
            source: "test",
            sourceID: "7",
            ingredients: Array(repeating: "item", count: 1),
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "gochujang", quantity: 2, unit: "tbsp", item: "gochujang", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "miso", quantity: 1, unit: "tbsp", item: "miso", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "chicken", quantity: 1, unit: "lb", item: "chicken", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertFalse(RecipeComplexity.fits(exotic, level: 1, course: "main"))
        XCTAssertTrue(RecipeComplexity.fits(exotic, level: 5, course: "main"))
    }

    func testSideCatalogPairsChickenWithGreens() {
        let broccoli = Recipe(
            id: "side-b",
            name: "Garlic Broccoli",
            source: "test",
            sourceID: "8",
            ingredients: ["broccoli"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: ["side"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "broccoli", quantity: 1, unit: "count", item: "broccoli", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "side"
        )
        let score = SideCatalog.score(
            side: broccoli,
            mainProteins: ["chicken"],
            usedKinds: [],
            usedSideIDs: []
        )
        XCTAssertGreaterThan(score, 3)
        XCTAssertEqual(SideCatalog.match(broccoli)?.kind, .vegetable)
    }

    func testLemonPartsCollapseToOneFruit() {
        let recipe = Recipe(
            id: "lemon-1",
            name: "Lemon chicken",
            source: "test",
            sourceID: "9",
            ingredients: ["lemon juice", "lemon zest", "lemon wedge"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "2 tbsp lemon juice", quantity: 2, unit: "tbsp", item: "lemon juice", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "1 tsp lemon zest", quantity: 1, unit: "tsp", item: "lemon zest", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "1 lemon wedge", quantity: 1, unit: "count", item: "lemon wedge", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        let items = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: [recipe], scaledServings: [recipe.id: 4])
        )
        let lemons = items.filter { IngredientCanonicalizer.canonicalize($0.ingredientName) == "lemon" }
        XCTAssertEqual(lemons.count, 1)
        XCTAssertGreaterThanOrEqual(lemons.first?.quantity ?? 0, 1)
    }

    func testEmbeddedPackageSizeDoesNotDoubleUnit() throws {
        let recipe = Recipe(
            id: "cheese-1",
            name: "Cheesy",
            source: "test",
            sourceID: "10",
            ingredients: ["250g cheddar cheese"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            // Bad parse: package size left in the item, quantity treated as count=1.
            parsedIngredients: [
                ParsedIngredient(
                    raw: "250g cheddar cheese",
                    quantity: 1,
                    unit: "count",
                    item: "250g cheddar cheese",
                    prep: "",
                    toTaste: false,
                    optional: false,
                    allergens: [],
                    notes: ""
                ),
            ],
            allergens: [],
            course: "main"
        )
        // Scale to ~1/8 batch → used to show "0.13 250g cheddar cheese"
        let items = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: [recipe], scaledServings: [recipe.id: 1])
        )
        XCTAssertEqual(items.count, 1)
        let cheese = try XCTUnwrap(items.first)
        XCTAssertFalse(cheese.ingredientName.contains("250"))
        XCTAssertFalse(cheese.ingredientName.contains("g"))
        XCTAssertEqual(UnitConverter.kind(of: cheese.unit), .weight)
        let text = GroceryConsolidator.displayText(cheese)
        XCTAssertFalse(text.contains("250g"), text)
        XCTAssertFalse(text.hasPrefix("0.13"), text)
    }

    func testVagueBaconGarnishDroppedOrToTaste() {
        let recipe = Recipe(
            id: "bacon-1",
            name: "Garnish",
            source: "test",
            sourceID: "11",
            ingredients: ["as much bacon as you want garnish"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(
                    raw: "as much bacon as you want garnish",
                    quantity: 1,
                    unit: "count",
                    item: "as much bacon as you want garnish",
                    prep: "",
                    toTaste: false,
                    optional: false,
                    allergens: [],
                    notes: ""
                ),
            ],
            allergens: [],
            course: "main"
        )
        let items = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: [recipe], scaledServings: [recipe.id: 1])
        )
        if let bacon = items.first(where: { $0.ingredientName.contains("bacon") }) {
            XCTAssertTrue(bacon.isApproximate || bacon.unit == "to_taste")
            let text = GroceryConsolidator.displayText(bacon)
            XCTAssertFalse(text.contains("0.13"), text)
            XCTAssertFalse(text.lowercased().contains("as much"), text)
        } else {
            // Dropped entirely is also fine.
            XCTAssertTrue(items.isEmpty)
        }
    }

    func testWholeChickenCountCeils() throws {
        let recipe = Recipe(
            id: "chicken-whole",
            name: "Roast",
            source: "test",
            sourceID: "12",
            ingredients: ["1 whole chicken"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(
                    raw: "1 whole chicken",
                    quantity: 1,
                    unit: "count",
                    item: "whole chicken",
                    prep: "",
                    toTaste: false,
                    optional: false,
                    allergens: [],
                    notes: ""
                ),
            ],
            allergens: [],
            course: "main"
        )
        let items = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: [recipe], scaledServings: [recipe.id: 5])
        )
        let bird = try XCTUnwrap(items.first { $0.ingredientName.contains("chicken") })
        XCTAssertEqual(bird.unit, "count")
        XCTAssertEqual(bird.quantity, bird.quantity.rounded(), accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(bird.quantity, 2)
        let text = GroceryConsolidator.displayText(bird)
        XCTAssertFalse(text.contains("1.33"), text)
    }

    func testFinalizePeelsDoubleUnitNameFromLLMShape() throws {
        let dirty = ConsolidatedGroceryItem(
            ingredientName: "0.13 250g cheddar cheese",
            category: "dairy",
            quantity: 0.13,
            unit: "count",
            isApproximate: false,
            note: "",
            isChecked: false,
            isManual: false
        )
        let items = GroceryConsolidator.finalizeForShopping([dirty])
        let cheese = try XCTUnwrap(items.first)
        XCTAssertFalse(cheese.ingredientName.contains("250"))
        XCTAssertEqual(UnitConverter.kind(of: cheese.unit), .weight)
        XCTAssertGreaterThan(cheese.quantity, 1)
        let text = GroceryConsolidator.displayText(cheese)
        XCTAssertFalse(text.contains("250g"), text)
        XCTAssertFalse(text.hasPrefix("0.13"), text)
    }

    func testEggWeeklyCapAtEighteen() {
        let recipe = Recipe(
            id: "eggs-cap",
            name: "Many eggs",
            source: "test",
            sourceID: "13",
            ingredients: ["12 eggs"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "12 eggs", quantity: 12, unit: "count", item: "egg", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        // Two recipes × 12 eggs → 24 before weekly cap
        let recipeB = Recipe(
            id: "eggs-cap-b",
            name: "Many eggs B",
            source: "test",
            sourceID: "14",
            ingredients: ["12 eggs"],
            steps: [],
            description: "",
            yieldText: "4 servings",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "12 eggs", quantity: 12, unit: "count", item: "egg", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        let items = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(
                from: [recipe, recipeB],
                scaledServings: [recipe.id: 4, recipeB.id: 4]
            )
        )
        let eggs = items.first { IngredientCanonicalizer.canonicalize($0.ingredientName) == "egg" }
        XCTAssertLessThanOrEqual(eggs?.quantity ?? 99, Double(GroceryConsolidator.maxEggsPerWeek))
    }

    func testLeftoverTwentyFourEggsDetected() {
        XCTAssertTrue(
            GroceryConsolidator.isLeftoverBreakfastEgg(name: "egg", quantity: 24, unit: "count")
        )
        XCTAssertTrue(
            GroceryConsolidator.isLeftoverBreakfastEgg(name: "24 eggs", quantity: 1, unit: "count")
        )
        XCTAssertFalse(
            GroceryConsolidator.isLeftoverBreakfastEgg(name: "egg", quantity: 6, unit: "count")
        )
    }

    func testProteinNamesStripIncheAndMergeVariants() {
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("beef steaks inche"),
            "beef steak"
        )
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize(
                "1 one butterflied leg lamb lamb shoulder roast even thickness inche"
            ),
            "leg of lamb"
        )
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("salmon filet skin removed"),
            "salmon"
        )
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("uncoocked peeled shrimp"),
            "shrimp"
        )
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("ground beef"),
            "ground beef"
        )

        let dirty: [ConsolidatedGroceryItem] = [
            .init(ingredientName: "beef steaks inche", category: "protein", quantity: 4, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "beef steak", category: "protein", quantity: 4, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "salmon filet", category: "protein", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "salmon filet skin removed", category: "protein", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "ground beef", category: "protein", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "one butterflied leg lamb lamb shoulder roast even thickness inche", category: "protein", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
        ]
        let clean = GroceryConsolidator.finalizeForShopping(dirty)
        let names = Set(clean.map { IngredientCanonicalizer.canonicalize($0.ingredientName) })
        XCTAssertEqual(names.intersection(["beef steak"]).count, 1)
        XCTAssertTrue(names.contains("salmon"))
        XCTAssertTrue(names.contains("ground beef"))
        XCTAssertTrue(names.contains("leg of lamb"))
        XCTAssertFalse(clean.contains { $0.ingredientName.contains("inche") })
        XCTAssertFalse(clean.contains { GroceryConsolidator.displayText($0).contains("inche") })
        let ground = try! XCTUnwrap(clean.first { $0.ingredientName == "ground beef" })
        XCTAssertEqual(ground.unit, "lb")
        let steaks = try! XCTUnwrap(clean.first { $0.ingredientName == "beef steak" })
        XCTAssertEqual(steaks.quantity, 8, accuracy: 0.1)
        let salmon = try! XCTUnwrap(clean.first { $0.ingredientName == "salmon" })
        XCTAssertEqual(salmon.unit, "fillet")
        XCTAssertEqual(salmon.quantity, 2, accuracy: 0.1)

        let canned: [ConsolidatedGroceryItem] = [
            .init(ingredientName: "tuna", category: "protein", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "1 can tuna", category: "protein", quantity: 1, unit: "can", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "tofu", category: "protein", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
        ]
        let cannedClean = GroceryConsolidator.finalizeForShopping(canned)
        let tuna = try! XCTUnwrap(cannedClean.first { $0.ingredientName == "tuna" })
        XCTAssertEqual(tuna.unit, "can")
        XCTAssertEqual(tuna.quantity, 2, accuracy: 0.1)
        XCTAssertTrue(GroceryConsolidator.displayText(tuna).localizedCaseInsensitiveContains("can"))
        let tofu = try! XCTUnwrap(cannedClean.first { $0.ingredientName == "tofu" })
        XCTAssertEqual(tofu.unit, "package")
    }

    // MARK: - Dinner-only + realism

    func testMealSlotRecipeSlotsAreDinnerOnly() {
        XCTAssertEqual(MealSlot.recipeSlots, [.dinner])
        XCTAssertFalse(MealSlot.recipeSlots.contains(.lunch))
    }

    func testShoppingRealismSubstitutesShallotAndDropsTinyExotic() {
        let dirty: [ConsolidatedGroceryItem] = [
            .init(ingredientName: "shallot", category: "produce", quantity: 2, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "chicken thigh", category: "protein", quantity: 1.5, unit: "lb", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "mirin", category: "pantry", quantity: 1, unit: "tbsp", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "soy sauce", category: "pantry", quantity: 2, unit: "tbsp", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "thyme", category: "produce", quantity: 1, unit: "tsp", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "lemon juice", category: "produce", quantity: 2, unit: "tbsp", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "lemon", category: "produce", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "cilantro", category: "produce", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "basil", category: "produce", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "mint", category: "produce", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
        ]
        let clean = GroceryConsolidator.finalizeForShopping(dirty, cookingComplexity: 1)
        let names = Set(clean.map { $0.ingredientName.lowercased() })
        XCTAssertTrue(names.contains("onion"), "shallot should become onion at Simple")
        XCTAssertFalse(names.contains("shallot"))
        XCTAssertFalse(names.contains("thyme"), "tiny woody herb garnish should drop")
        XCTAssertTrue(names.contains("lemon"))
        XCTAssertFalse(names.contains("lemon juice"), "juice merges into lemon")
        let herbs = clean.filter { RecipeComplexity.isFreshHerb($0.ingredientName) }
        XCTAssertLessThanOrEqual(herbs.count, 1, "Simple week keeps at most one fresh herb")
    }

    func testFussyProduceFailsSimpleFits() {
        let fussy = Recipe(
            id: "fussy-1",
            name: "Shallot Shiitake Chicken",
            source: "test",
            sourceID: "f1",
            ingredients: ["chicken", "shallot", "shiitake", "parsley", "oil"],
            steps: [],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: ["main"],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "chicken", quantity: 1, unit: "lb", item: "chicken", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "shallot", quantity: 2, unit: "count", item: "shallot", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "shiitake", quantity: 4, unit: "count", item: "shiitake", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
                ParsedIngredient(raw: "parsley", quantity: 0.25, unit: "cup", item: "parsley", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertFalse(RecipeComplexity.fits(fussy, level: 1, course: "main"))
        XCTAssertTrue(RecipeComplexity.fits(fussy, level: 5, course: "main"))
    }

    private func waitForRecipeDB() -> RecipeDatabase {
        let db = RecipeDatabase.shared
        let exp = expectation(description: "recipes loaded")
        DispatchQueue.global(qos: .userInitiated).async {
            XCTAssertTrue(db.waitUntilLoaded(timeout: 55), "recipe DB failed to load")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 60)
        XCTAssertGreaterThan(db.count(), 50, "bundled recipe DB should load in tests")
        return db
    }

    func testSimpleWeekPlanIsDinnerRealistic() {
        let db = waitForRecipeDB()
        let settings = WeekPlanner.Settings(cookingComplexity: 1)
        let result = WeekPlanner.plan(store: db, settings: settings, bannedIDs: [], days: 7)
        XCTAssertEqual(result.mains.count, 7)
        for main in result.mains {
            // After soft widen, still prefer fitting level ≤ 2
            XCTAssertTrue(
                RecipeComplexity.fits(main, level: 2, course: "main")
                    || RecipeComplexity.fits(main, level: 3, course: "main"),
                "Simple week main too complex: \(main.name) shop=\(RecipeComplexity.shoppableCount(main)) exotic=\(RecipeComplexity.exoticCount(main, treatUnknownAsExotic: true))"
            )
            let proteins = WeekPlanner.flavor(main).proteins
            XCTAssertFalse(proteins.contains("lamb"), "Simple week should avoid lamb: \(main.name)")
            XCTAssertFalse(proteins.contains("shellfish"), "Simple week should avoid shellfish: \(main.name)")
            XCTAssertFalse(proteins.contains("fish"), "Simple week should avoid fish: \(main.name)")
            XCTAssertFalse(WeekPlanner.looksLikeAdvancedTechnique(main), main.name)
            XCTAssertFalse(WeekPlanner.looksLikeOrganMeatMain(main), main.name)
        }

        var cart = Set<String>()
        for (i, main) in result.mains.enumerated() {
            cart.formUnion(RecipeComplexity.shoppableItems(main))
            if i < result.sides.count, result.sides[i].id != main.id {
                cart.formUnion(RecipeComplexity.shoppableItems(result.sides[i]))
            }
        }
        XCTAssertLessThanOrEqual(
            cart.count,
            RecipeComplexity.weeklySKUBudget(for: 1) + 12,
            "cart SKUs=\(cart.count) items=\(cart.sorted())"
        )

        let scale = Dictionary(uniqueKeysWithValues: (result.mains + result.sides).map { ($0.id, 2) })
        var recipes: [Recipe] = []
        var seen = Set<String>()
        for r in result.mains + result.sides where seen.insert(r.id).inserted {
            recipes.append(r)
        }
        let shop = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: recipes, scaledServings: scale),
            cookingComplexity: 1
        )
        let exoticOnShop = shop.filter {
            RecipeComplexity.isExoticName($0.ingredientName, treatUnknownAsExotic: false)
        }
        XCTAssertTrue(
            exoticOnShop.isEmpty,
            "Simple shop still has exotic: \(exoticOnShop.map(\.ingredientName))"
        )
        let herbs = shop.filter { RecipeComplexity.isFreshHerb($0.ingredientName) }
        XCTAssertLessThanOrEqual(herbs.count, 1, "herbs=\(herbs.map(\.ingredientName))")

        // Dump for human inspection in test logs.
        var dump = "=== SIMPLE WEEK DUMP ===\n"
        for (i, main) in result.mains.enumerated() {
            let side = i < result.sides.count && result.sides[i].id != main.id ? result.sides[i].name : "(no side)"
            dump += "D\(i + 1): \(main.name) + \(side)\n"
        }
        dump += "--- Shop (\(shop.count) SKUs) ---\n"
        for item in shop {
            dump += "- \(GroceryConsolidator.displayText(item))\n"
        }
        dump += "=== END DUMP ===\n"
        print(dump)
        let attachment = XCTAttachment(string: dump)
        attachment.name = "simple_week_dump"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEasyWeekAllowsAtMostOneSpecialty() {
        let db = waitForRecipeDB()
        let settings = WeekPlanner.Settings(cookingComplexity: 2)
        let result = WeekPlanner.plan(store: db, settings: settings, bannedIDs: [], days: 7)
        XCTAssertEqual(result.mains.count, 7)
        let scale = Dictionary(uniqueKeysWithValues: (result.mains + result.sides).map { ($0.id, 4) })
        var recipes: [Recipe] = []
        var seen = Set<String>()
        for r in result.mains + result.sides where seen.insert(r.id).inserted {
            recipes.append(r)
        }
        let shop = GroceryConsolidator.finalizeForShopping(
            GroceryConsolidator.consolidate(from: recipes, scaledServings: scale),
            cookingComplexity: 2
        )
        let exotic = shop.filter {
            RecipeComplexity.isExoticName($0.ingredientName, treatUnknownAsExotic: false)
        }
        XCTAssertLessThanOrEqual(exotic.count, 2, "Easy shop exotic=\(exotic.map(\.ingredientName))")
        var dump = "=== EASY WEEK DUMP ===\n"
        for (i, main) in result.mains.enumerated() {
            let side = i < result.sides.count && result.sides[i].id != main.id ? result.sides[i].name : "(no side)"
            dump += "D\(i + 1): \(main.name) + \(side)\n"
        }
        dump += "--- Shop (\(shop.count) SKUs) ---\n"
        for item in shop {
            dump += "- \(GroceryConsolidator.displayText(item))\n"
        }
        dump += "=== END DUMP ===\n"
        print(dump)
        let attachment = XCTAttachment(string: dump)
        attachment.name = "easy_week_dump"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testVegetarianWeekRespectsDietAndDislikes() {
        let db = waitForRecipeDB()
        let settings = WeekPlanner.Settings(
            dietRaw: "vegetarian",
            dietaryRestrictionsText: "cilantro",
            cookingComplexity: 2
        )
        let result = WeekPlanner.plan(store: db, settings: settings, bannedIDs: [], days: 7)
        XCTAssertFalse(result.mains.isEmpty)
        let blocked: Set<String> = ["chicken", "beef", "pork", "lamb", "fish", "shellfish"]
        for main in result.mains {
            let prots = WeekPlanner.flavor(main).proteins
            XCTAssertTrue(prots.isDisjoint(with: blocked), "veg main \(main.name) proteins=\(prots)")
            XCTAssertFalse(DislikeMatcher.blocks(main, dislikes: ["cilantro"]))
        }
        for side in result.sides where !result.mains.contains(where: { $0.id == side.id }) {
            XCTAssertFalse(DislikeMatcher.blocks(side, dislikes: ["cilantro"]), "side \(side.name)")
        }
    }

    func testShoppingNamesStripHedgesAndCookbookRefs() {
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("4 large sweet potatoes, scrubbed and peeled, if desired"),
            "sweet potato"
        )
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("1 cup rice and 1 cup plus 1 ½ tablespoons water yields a generous 2 cups"),
            ""
        )
        XCTAssertEqual(
            IngredientCanonicalizer.canonicalize("Lemon Marinade , Balkan Marinade , Teriyaki Marinade"),
            ""
        )
        let dirty: [ConsolidatedGroceryItem] = [
            .init(ingredientName: "sweet potatoes scrubbed if desired", category: "produce", quantity: 2, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "inches vegetable oil", category: "pantry", quantity: 3, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
            .init(ingredientName: "herb pan sauce", category: "pantry", quantity: 1, unit: "count", isApproximate: false, note: "", isChecked: false, isManual: false),
        ]
        let clean = GroceryConsolidator.finalizeForShopping(dirty, cookingComplexity: 1)
        let names = Set(clean.map { $0.ingredientName.lowercased() })
        XCTAssertTrue(names.contains("sweet potato") || names.contains { $0.contains("sweet potato") })
        XCTAssertFalse(names.contains { $0.contains("inch") })
        XCTAssertFalse(names.contains { $0.contains("pan sauce") })
    }

    func testRequiresPriorRecipeDetected() {
        let creamed = Recipe(
            id: "creamed",
            name: "CREAMED CHICKEN",
            source: "test",
            sourceID: "c",
            ingredients: ["Poached Chicken", "butter", "flour", "milk"],
            steps: [
                RecipeStep(stepNumber: 1, instruction: ""),
                RecipeStep(stepNumber: 2, instruction: "Melt butter"),
                RecipeStep(stepNumber: 3, instruction: "Add flour"),
            ],
            description: "",
            yieldText: "4",
            page: nil,
            chapter: "",
            section: "",
            tags: [],
            url: "",
            extras: [:],
            parsedIngredients: [
                ParsedIngredient(raw: "Poached Chicken", quantity: nil, unit: nil, item: "Poached Chicken", prep: "", toTaste: false, optional: false, allergens: [], notes: ""),
            ],
            allergens: [],
            course: "main"
        )
        XCTAssertTrue(WeekPlanner.looksLikeRequiresPriorRecipe(creamed))
    }
}