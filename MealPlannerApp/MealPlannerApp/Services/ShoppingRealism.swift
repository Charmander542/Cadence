import Foundation

/// Post-process a consolidated shop list so Simple/Easy weeks look like a realistic
/// once-a-week supermarket trip: substitute fussy items, drop garnish-only SKUs,
/// merge near-duplicates, and cap fresh herbs.
enum ShoppingRealism {
    static func refine(
        _ items: [ConsolidatedGroceryItem],
        complexity raw: Int
    ) -> [ConsolidatedGroceryItem] {
        let level = RecipeComplexity.clamped(raw)
        var working = items

        // Light merges always (lemon juice + lemon, herb stems, etc.).
        working = mergeNearDuplicates(working)

        if level >= 3 {
            return dropJunkLines(mergeNearDuplicates(working))
        }

        working = working.compactMap { substituteOrDrop($0, level: level, cart: working) }
        working = mergeNearDuplicates(working)
        working = capFreshHerbs(working, maxHerbs: RecipeComplexity.freshHerbCap(for: level))
        working = dropGarnishOnlySKUs(working, level: level)
        working = dropJunkLines(working)
        working = capFryingOil(working, level: level)
        return mergeNearDuplicates(working)
    }

    /// Drop unusable / nonsense shop lines that survive cookbook parse noise.
    private static func dropJunkLines(_ items: [ConsolidatedGroceryItem]) -> [ConsolidatedGroceryItem] {
        items.filter { item in
            let name = item.ingredientName.lowercased()
            if name.contains("water") && !name.contains("watermelon") && !name.contains("coconut water") {
                return false
            }
            if name.contains("salt") && name.contains("pepper") { return false }
            if name == "salt" || name == "black pepper" || name == "pepper" { return false }
            if name.contains("meurette") || name.contains("flavored butter") { return false }
            if name == "taste" || name.hasPrefix("taste ") { return false }
            if name.contains("to taste") { return false }
            if item.isApproximate, item.unit == "to_taste", name.contains("pepper flake") || name.contains("red pepper") {
                return false
            }
            if !item.isApproximate, item.quantity <= 0.05 { return false }
            if name.count > 48 { return false }
            if name.contains("yield") { return false }
            if name.contains("marinade") && !name.contains("oil") { return false }
            if name.contains("pan sauce") { return false }
            // Deep-fry depth ("3 inches oil") should never appear as a count SKU.
            if name.contains("inch") && name.contains("oil") { return false }
            return true
        }
    }

    private static func capFryingOil(_ items: [ConsolidatedGroceryItem], level: Int) -> [ConsolidatedGroceryItem] {
        items.map { item in
            let name = item.ingredientName.lowercased()
            guard name.contains("oil"), !name.contains("olive"), !name.contains("sesame") else { return item }
            // Deep-fry recipes often ask for cups / "inches" of oil — buy a bottle.
            var copy = item
            if item.unit == "cup", item.quantity > 1 {
                copy.quantity = 1
                copy.note = [item.note, "bottle for frying"].filter { !$0.isEmpty }.joined(separator: "; ")
            } else if item.unit == "count" || item.unit.isEmpty {
                copy.quantity = 1
                copy.unit = "bottle"
                copy.note = [item.note, "for frying"].filter { !$0.isEmpty }.joined(separator: "; ")
            }
            return copy
        }
    }

    // MARK: - Substitute / drop

    private static func substituteOrDrop(
        _ item: ConsolidatedGroceryItem,
        level: Int,
        cart: [ConsolidatedGroceryItem]
    ) -> ConsolidatedGroceryItem? {
        let name = item.ingredientName.lowercased()

        // Shallot → onion (always at Simple/Easy).
        if name == "shallot" || name.hasPrefix("shallot ") {
            return renamed(item, to: "onion")
        }

        // Specialty Asian sauces → soy sauce only when soy is already on the list / pantry-ish
        // and complexity is Simple; otherwise drop tiny amounts.
        if level == 1, ["fish sauce", "oyster sauce", "mirin", "sake", "shaoxing", "rice wine"].contains(where: { name.contains($0) }) {
            if cartContains(cart, needles: ["soy sauce", "soy"]) {
                return renamed(item, to: "soy sauce")
            }
            if isTinyAmount(item) { return nil }
            return nil
        }

        if level <= 2, ["mirin", "sake", "shaoxing"].contains(where: { name.contains($0) }) {
            if isTinyAmount(item) { return nil }
            if cartContains(cart, needles: ["rice vinegar", "vinegar"]) {
                return renamed(item, to: "rice vinegar")
            }
            return nil
        }

        // Fresh woody herbs at garnish scale → drop (dried usually in pantry).
        if level <= 2, isWoodyHerb(name), isTinyAmount(item) {
            return nil
        }

        // Exotic specialty pastes as a lone tsp → drop at Simple.
        if level == 1, RecipeComplexity.isExoticName(name), isTinyAmount(item) {
            return nil
        }

        return item
    }

    private static func renamed(_ item: ConsolidatedGroceryItem, to name: String) -> ConsolidatedGroceryItem {
        ConsolidatedGroceryItem(
            ingredientName: name,
            category: IngredientCanonicalizer.category(for: name),
            quantity: item.quantity,
            unit: item.unit,
            isApproximate: item.isApproximate,
            note: item.note,
            isChecked: item.isChecked,
            isManual: item.isManual
        )
    }

    private static func cartContains(_ cart: [ConsolidatedGroceryItem], needles: [String]) -> Bool {
        cart.contains { item in
            let n = item.ingredientName.lowercased()
            return needles.contains { n == $0 || n.contains($0) }
        }
    }

    private static func isTinyAmount(_ item: ConsolidatedGroceryItem) -> Bool {
        if item.isApproximate || item.unit == "to_taste" { return true }
        switch UnitConverter.kind(of: item.unit) {
        case .volume:
            // Rough tbsp-equivalent: anything ≤ 2 tbsp is garnish-scale.
            if let canon = UnitConverter.toCanonical(quantity: item.quantity, unit: item.unit) {
                switch canon.unit {
                case "tsp": return canon.qty <= 6
                case "tbsp": return canon.qty <= 2
                case "cup": return canon.qty <= 0.125
                default: return canon.qty <= 2
                }
            }
            return item.quantity <= 2
        case .count:
            return item.quantity <= 2
        case .weight:
            if let canon = UnitConverter.toCanonical(quantity: item.quantity, unit: item.unit) {
                // grams
                let grams: Double
                switch canon.unit {
                case "g": grams = canon.qty
                case "kg": grams = canon.qty * 1000
                case "oz": grams = canon.qty * 28.35
                case "lb": grams = canon.qty * 453.6
                default: grams = canon.qty
                }
                return grams <= 30
            }
            return item.quantity <= 1
        case .taste:
            return true
        }
    }

    private static func isWoodyHerb(_ name: String) -> Bool {
        ["thyme", "rosemary", "sage", "oregano", "marjoram", "tarragon"].contains {
            name == $0 || name.hasPrefix($0 + " ") || name.hasSuffix(" " + $0)
        }
    }

    // MARK: - Merge near-duplicates

    private static func mergeNearDuplicates(_ items: [ConsolidatedGroceryItem]) -> [ConsolidatedGroceryItem] {
        var buckets: [String: ConsolidatedGroceryItem] = [:]
        var order: [String] = []

        for item in items {
            let key = mergeKey(for: item.ingredientName)
            if var existing = buckets[key] {
                existing = merge(existing, item)
                buckets[key] = existing
            } else {
                buckets[key] = item
                order.append(key)
            }
        }
        return order.compactMap { buckets[$0] }
    }

    private static func mergeKey(for name: String) -> String {
        var n = name.lowercased()
        n = n.replacingOccurrences(of: #"\bstems?\b"#, with: "", options: .regularExpression)
        n = n.replacingOccurrences(of: #"\bleaves\b"#, with: "", options: .regularExpression)
        n = n.replacingOccurrences(of: #"\bjuice\b"#, with: "", options: .regularExpression)
        n = n.replacingOccurrences(of: #"\bzest\b"#, with: "", options: .regularExpression)
        n = n.replacingOccurrences(of: #"\bwedges?\b"#, with: "", options: .regularExpression)
        n = n.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        // Collapse potato variants into one shop SKU (except sweet potato).
        if n.contains("sweet potato") {
            return "sweet potato"
        }
        if n.contains("potato") || n == "russet" || n.contains("russet") {
            return "potato"
        }
        if n.isEmpty { return name.lowercased() }
        return IngredientCanonicalizer.canonicalize(n)
    }

    private static func merge(_ a: ConsolidatedGroceryItem, _ b: ConsolidatedGroceryItem) -> ConsolidatedGroceryItem {
        var qty = a.quantity
        var unit = a.unit
        var approx = a.isApproximate || b.isApproximate
        if a.unit == b.unit || UnitConverter.kind(of: a.unit) == UnitConverter.kind(of: b.unit) {
            if let ca = UnitConverter.toCanonical(quantity: a.quantity, unit: a.unit),
               let cb = UnitConverter.toCanonical(quantity: b.quantity, unit: b.unit),
               ca.unit == cb.unit {
                qty = ca.qty + cb.qty
                unit = ca.unit
            } else if a.unit == b.unit {
                qty = a.quantity + b.quantity
            } else {
                approx = true
            }
        } else {
            approx = true
            qty = max(a.quantity, b.quantity)
        }
        let preferredName: String = {
            // Prefer whole fruit/veg name over juice/zest.
            let an = a.ingredientName.lowercased()
            let bn = b.ingredientName.lowercased()
            if an.contains("juice") || an.contains("zest") { return b.ingredientName }
            if bn.contains("juice") || bn.contains("zest") { return a.ingredientName }
            return a.ingredientName.count <= b.ingredientName.count ? a.ingredientName : b.ingredientName
        }()
        return ConsolidatedGroceryItem(
            ingredientName: preferredName,
            category: IngredientCanonicalizer.category(for: preferredName),
            quantity: qty,
            unit: unit,
            isApproximate: approx,
            note: [a.note, b.note].filter { !$0.isEmpty }.joined(separator: "; "),
            isChecked: a.isChecked || b.isChecked,
            isManual: a.isManual || b.isManual
        )
    }

    // MARK: - Herb cap / garnish

    private static func capFreshHerbs(
        _ items: [ConsolidatedGroceryItem],
        maxHerbs: Int
    ) -> [ConsolidatedGroceryItem] {
        var keptHerbs = 0
        var result: [ConsolidatedGroceryItem] = []
        // Prefer keeping parsley/cilantro/basil over niche herbs; sort herbs first by priority.
        let (herbs, rest) = items.reduce(into: ([ConsolidatedGroceryItem](), [ConsolidatedGroceryItem]())) { acc, item in
            if RecipeComplexity.isFreshHerb(item.ingredientName) {
                acc.0.append(item)
            } else {
                acc.1.append(item)
            }
        }
        let ranked = herbs.sorted { herbPriority($0.ingredientName) > herbPriority($1.ingredientName) }
        for herb in ranked {
            if keptHerbs < maxHerbs {
                result.append(herb)
                keptHerbs += 1
            }
            // else drop
        }
        return rest + result
    }

    private static func herbPriority(_ name: String) -> Int {
        let n = name.lowercased()
        if n.contains("parsley") { return 5 }
        if n.contains("cilantro") || n.contains("basil") { return 4 }
        if n.contains("green onion") || n.contains("scallion") || n.contains("chive") { return 3 }
        if n.contains("dill") || n.contains("mint") { return 2 }
        return 1
    }

    private static func dropGarnishOnlySKUs(
        _ items: [ConsolidatedGroceryItem],
        level: Int
    ) -> [ConsolidatedGroceryItem] {
        items.filter { item in
            let name = item.ingredientName.lowercased()
            // Zest-only / wedge-only as standalone after merge should already be fruit;
            // drop microgreens and garnish fluff.
            if name.contains("microgreen") || name.contains("edible flower") { return false }
            if level == 1, isWoodyHerb(name), isTinyAmount(item) { return false }
            return true
        }
    }
}
