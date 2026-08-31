import Foundation

/// Local unit conversion + grocery consolidation (no AI).
enum UnitConverter {
    enum Kind { case volume, weight, count, taste }

    static func kind(of unit: String) -> Kind {
        switch unit.lowercased() {
        case "tsp", "tbsp", "cup", "ml", "l": return .volume
        case "g", "kg", "oz", "lb": return .weight
        case "to_taste": return .taste
        default: return .count
        }
    }

    static func toCanonical(quantity: Double, unit: String) -> (qty: Double, unit: String)? {
        let u = unit.lowercased()
        switch kind(of: u) {
        case .taste:
            return (1, "to_taste")
        case .count:
            return (quantity, "count")
        case .volume:
            let tbsp: Double
            switch u {
            case "tsp": tbsp = quantity / 3.0
            case "tbsp": tbsp = quantity
            case "cup": tbsp = quantity * 16.0
            case "ml": tbsp = quantity / 14.7868
            case "l": tbsp = quantity * 67.628
            default: return nil
            }
            if tbsp >= 16 { return (tbsp / 16.0, "cup") }
            if tbsp < 1 { return (tbsp * 3.0, "tsp") }
            return (tbsp, "tbsp")
        case .weight:
            let grams: Double
            switch u {
            case "g": grams = quantity
            case "kg": grams = quantity * 1000
            case "oz": grams = quantity * 28.3495
            case "lb": grams = quantity * 453.592
            default: return nil
            }
            if grams >= 453.592 { return (grams / 453.592, "lb") }
            if grams >= 28.3495 { return (grams / 28.3495, "oz") }
            return (grams, "g")
        }
    }

    static func convert(_ quantity: Double, from: String, to: String) -> Double? {
        let fromU = from.lowercased()
        let toU = to.lowercased()
        guard kind(of: fromU) == kind(of: toU), kind(of: fromU) != .taste else { return nil }
        let baseA = baseAmount(quantity: quantity, unit: fromU)
        let basePerTo = baseAmount(quantity: 1, unit: toU)
        guard let baseA, let basePerTo, basePerTo != 0 else { return nil }
        return baseA / basePerTo
    }

    private static func baseAmount(quantity: Double, unit: String) -> Double? {
        switch unit.lowercased() {
        case "tsp": return quantity
        case "tbsp": return quantity * 3
        case "cup": return quantity * 48
        case "ml": return quantity / 4.92892
        case "l": return quantity * 202.884
        case "g": return quantity
        case "kg": return quantity * 1000
        case "oz": return quantity * 28.3495
        case "lb": return quantity * 453.592
        case "count": return quantity
        default: return nil
        }
    }
}

/// Collapse grocery-name variants so "boneless skinless chicken breasts" and
/// "chicken pieces" share one line (turkey stays separate from chicken).
enum IngredientCanonicalizer {
    private static let stripWords: Set<String> = [
        "fresh", "frozen", "dried", "ground", "minced", "chopped", "sliced", "diced",
        "optional", "boneless", "skinless", "bone-in", "bonein", "large", "medium", "small",
        "whole", "halved", "trimmed", "thinly", "thick", "extra", "virgin", "low", "sodium",
        "unsalted", "salted", "organic", "raw", "cooked", "uncooked", "uncoocked", "lean",
        "free", "range", "package",
        "pack", "can", "cans", "about", "approximately", "roughly", "plus", "more",
        "bunch", "bunches", "head", "heads", "bag", "bags", "bush", "bushes",
        "toasted", "roasted", "smoked", "unrefined", "refined",
        "dark", "light", "pure", "cold", "pressed",
        "finely", "freshly", "grated",
        "lightly", "packed", "firmly", "loosely", "heaping", "scant", "rounded",
        "ripe", "unripe", "shredded", "coarsely",
        "cup", "cups", "tbsp", "tsp", "tablespoon", "tablespoons", "teaspoon", "teaspoons",
        "ounce", "ounces", "pound", "pounds", "lb", "lbs", "oz",
        "up", "mixed",
        // Cookbook size/prep leftovers that must never appear on Shop
        "inch", "inches", "inche", "cm", "mm",
        "thickness", "thicknes", "even", "butterflied", "butterfly",
        "deveined", "devein", "peeled", "skinned", "skin", "removed",
        "thawed", "defrosted", "room", "temperature",
        "piece", "pieces", "chunks", "chunk", "strips", "strip",
        "cut", "into", "crosswise", "lengthwise",
    ]

    private static let fillerWords: Set<String> = [
        "of", "a", "an", "the", "and", "with", "for", "to", "from", "or",
        "one", "two", "some", "any", "your",
    ]

    /// Color/packing leftovers that are not buyable on their own.
    /// Keep "greens", "green onion", "green bean" — those are real foods.
    private static let weakGroceryNames: Set<String> = [
        "green", "red", "white", "black", "yellow", "brown", "purple", "pink",
        "gold", "golden", "light", "dark",
        "packed", "lightly packed", "firmly packed", "loosely packed",
        "meat", "leaves", "leaf", "cup", "cups", "tbsp", "tsp",
        "such", "combination",
        // Parser often stops at "or": "vegetable or olive oil" → "vegetable"
        "vegetable", "olive", "canola", "neutral", "shortening",
        "vinaigrette", "up vinaigrette",
    ]

    private static let colorWords: Set<String> = [
        "green", "red", "white", "black", "yellow", "brown", "purple", "pink",
        "gold", "golden", "dark", "light",
    ]

    private static let keepPlural: Set<String> = [
        "greens", "molasses", "asparagus", "oats", "grits", "hummus",
    ]

    /// 1 packed cup of ground meat ≈ 8 oz.
    private static let groundMeatLbPerCup = 0.5

    /// Juice/zest/wedge of the same fruit share one grocery line.
    static let wholeFruitKeys: Set<String> = ["lemon", "lime"]

    /// Approximate retail weights so count↔weight lines can merge for proteins (not eggs).
    private static let countToLb: [String: Double] = [
        "chicken breast": 0.5,
        "chicken thigh": 0.35,
        "chicken drumstick": 0.25,
        "chicken wing": 0.1,
        "chicken piece": 0.4,
        "chicken": 0.5,
    ]

    /// Large egg ≈ 50g.
    private static let eggGrams = 50.0
    private static let herbBunchKeys: Set<String> = [
        "parsley", "cilantro", "mint", "basil", "arugula", "dill", "thyme",
    ]

    /// Shopping-list name for a parsed line. Uses the cookbook `raw` line first so
    /// "vegetable or olive oil" does not shop as "vegetable".
    static func groceryName(for ing: ParsedIngredient) -> String {
        groceryName(item: ing.item, prep: ing.prep, raw: ing.raw)
    }

    static func groceryName(item: String, prep: String = "", raw: String = "") -> String {
        var seen = Set<String>()
        // Cookbook line first: parser `item` often stops at "or" ("vegetable or olive oil").
        var sources: [String] = []
        if !raw.isEmpty { sources.append(raw) }
        if !item.isEmpty, !prep.isEmpty { sources.append("\(item) \(prep)") }
        if !item.isEmpty { sources.append(item) }
        if !prep.isEmpty { sources.append(prep) }
        for source in sources {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            let key = canonicalize(trimmed)
            if !key.isEmpty { return key }
        }
        return ""
    }

    static func isFryingOil(_ raw: String) -> Bool {
        let s = raw.lowercased()
        return s.contains("oil") && s.range(of: #"\binch(?:es)?\b"#, options: .regularExpression) != nil
    }

    static func canonicalize(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: #"\*+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\(.*?\)"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: ",", with: " ")
        s = s.replacingOccurrences(of: "-", with: " ")
        s = s.replacingOccurrences(of: #"\boptional\b:?"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\bup to\b"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        s = resolveOrAlternatives(s)

        // Eggs always collapse to "egg" (not eggplant / egg noodles).
        // Whites and yolks stay distinct so one recipe doesn't buy two eggs per egg.
        if s.contains("eggplant") || s.contains("egg wash") || s.contains("egg noodle") || s.contains("egg drop") {
            // fall through
        } else if s.contains("egg white") {
            return "egg white"
        } else if s.contains("egg yolk") {
            return "egg yolk"
        } else if isEggName(s) {
            return "egg"
        }

        if s.contains("garlic powder") || s.contains("garlic salt") {
            return s.contains("salt") ? "garlic salt" : "garlic powder"
        }
        if s.contains("onion powder") || s.contains("onion salt") {
            return s.contains("salt") ? "onion salt" : "onion powder"
        }
        if s.contains("oil") {
            return collapseOil(s)
        }
        if s.contains("tortilla") {
            return "tortilla"
        }
        if let flour = collapseFlour(s) {
            return flour
        }
        if let ref = collapseCookbookRef(s) {
            return ref
        }
        if s.contains("mayonnaise") || s.range(of: #"\bmayo\b"#, options: .regularExpression) != nil {
            return "mayonnaise"
        }
        // Before chicken/beef: "vegetable or chicken stock" is broth, not poultry.
        if s.range(of: #"\b(stock|broth|bouillon)\b"#, options: .regularExpression) != nil {
            return "stock"
        }
        if s.contains("vinegar") {
            return "vinegar"
        }
        if s.contains("wine") {
            return "wine"
        }
        if s.contains("miso") { return "miso" }
        if s.contains("garlic") {
            return "garlic"
        }
        if s.contains("ginger") && !s.contains("ale") {
            return "ginger"
        }
        if let citrus = collapseCitrus(s) {
            return citrus
        }
        if s.contains("green onion") || s.contains("scallion") || s.contains("spring onion") {
            return "green onion"
        }
        if s.contains("green bean") {
            return "green bean"
        }
        if s.contains("red onion") {
            return "red onion"
        }
        if s.contains("onion") {
            return "onion"
        }

        // Protein family collapses — shop-friendly cuts only
        if let protein = collapseProtein(s) {
            return protein
        }

        // Common produce / pantry shopping names
        if s.contains("brown sugar") { return "brown sugar" }
        if s.contains("broccoli") { return "broccoli" }
        if s.contains("cauliflower") { return "cauliflower" }
        if s.contains("spinach") { return "spinach" }
        if s.contains("kale") { return "kale" }
        if s.contains("celery") { return "celery" }
        if s.contains("asparagus") { return "asparagus" }
        if s.contains("cabbage") { return "cabbage" }
        if s.contains("lettuce") || s.contains("romaine") { return "lettuce" }
        if s.contains("bell pepper") || s.contains("capsicum") { return "bell pepper" }
        if s.contains("lentil") { return "lentils" }
        if s.contains("arugula") || s.contains("rocket") { return "arugula" }
        if s.contains("parsley") { return "parsley" }
        if s.contains("cilantro") { return "cilantro" }
        if s.contains("mint") && !s.contains("extract") { return "mint" }
        if s.contains("basil") { return "basil" }
        if s.range(of: #"\bolives?\b"#, options: .regularExpression) != nil { return "olives" }
        if s.contains("cardamom") { return "cardamom" }
        if s.contains("peanut") && !s.contains("butter") { return "peanuts" }

        let tokens = s.split(separator: " ").compactMap { part -> String? in
            let token = String(part).trimmingCharacters(in: .punctuationCharacters)
            if token.isEmpty { return nil }
            if stripWords.contains(token) || fillerWords.contains(token) { return nil }
            if isMeasureToken(token) { return nil }
            return token
        }
        // Drop repeated words from bad merges: "lamb lamb", "filet filet"
        var deduped: [String] = []
        for token in tokens {
            if deduped.last == token { continue }
            deduped.append(token)
        }
        var name = deduped.joined(separator: " ")
        name = singularizeGroceryName(name)
        if isWeakGroceryName(name) {
            return ""
        }
        return name
    }

    /// Collapse protein lines to what you'd actually buy.
    private static func collapseProtein(_ s: String) -> String? {
        if s.contains("ground turkey") { return "ground turkey" }
        if s.contains("ground beef") || s.contains("hamburger") || s.contains("mince beef") {
            return "ground beef"
        }
        if s.contains("ground chicken") { return "ground chicken" }
        if s.contains("ground pork") { return "ground pork" }
        if s.contains("ground lamb") { return "ground lamb" }
        if s.contains("ground veal") { return "ground veal" }
        if s.contains("ground meat") { return "ground meat" }

        if s.contains("turkey") && (s.contains("breast") || s.contains("cutlet")) {
            return "turkey breast"
        }
        if s.contains("chicken") {
            if s.contains("thigh") { return "chicken thigh" }
            if s.contains("drumstick") || (s.contains("leg") && !s.contains("legume")) {
                return "chicken drumstick"
            }
            if s.contains("wing") { return "chicken wing" }
            if s.contains("breast") || s.contains("tender") || s.contains("cutlet") {
                return "chicken breast"
            }
            if s.contains("piece") || s.contains("parts") || s.contains("meat") {
                return "chicken breast"
            }
            if s.contains("whole") { return "whole chicken" }
            return "chicken"
        }

        if s.contains("lamb") {
            if s.contains("chop") { return "lamb chop" }
            if s.contains("shank") { return "lamb shank" }
            if s.contains("shoulder") || s.contains("leg") || s.contains("butterfl") {
                return "leg of lamb"
            }
            return "lamb"
        }

        if s.contains("beef") || s.contains("steak"), !s.contains("tomato") {
            if s.contains("stew") || s.contains("chuck") || s.contains("brisket") {
                return "beef"
            }
            if s.contains("steak") || s.contains("sirloin") || s.contains("ribeye")
                || s.contains("rib eye") || s.contains("strip") || s.contains("tenderloin") {
                return "beef steak"
            }
            if s.contains("roast") { return "beef roast" }
            if s.contains("beef") { return "beef" }
        }

        if s.contains("pork") {
            if s.contains("chop") { return "pork chop" }
            if s.contains("loin") || s.contains("tenderloin") { return "pork loin" }
            if s.contains("belly") || s.contains("bacon") { return s.contains("bacon") ? "bacon" : "pork belly" }
            if s.contains("sausage") { return "sausage" }
            return "pork"
        }

        if s.contains("salmon") { return "salmon" }
        if s.contains("tuna") && !s.contains("cactus") { return "tuna" }
        if s.contains("cod") { return "cod" }
        if s.contains("shrimp") || s.contains("prawn") { return "shrimp" }
        if s.contains("tofu") { return "tofu" }
        if s.contains("tempeh") { return "tempeh" }
        if s.contains("bacon") { return "bacon" }
        return nil
    }

    /// "green or red cabbage" → keep the side that is actually a food, not a color leftover.
    private static func resolveOrAlternatives(_ s: String) -> String {
        guard s.contains(" or ") else { return s }
        let parts = s.components(separatedBy: " or ").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        guard parts.count >= 2 else { return s }
        if isModifierOnly(parts[0]) {
            return parts.dropFirst().joined(separator: " or ")
        }
        return s
    }

    private static func isModifierOnly(_ part: String) -> Bool {
        let tokens = part.split(separator: " ").compactMap { piece -> String? in
            let token = String(piece).trimmingCharacters(in: .punctuationCharacters).lowercased()
            if token.isEmpty { return nil }
            if Double(token) != nil { return nil }
            return token
        }
        if tokens.isEmpty { return true }
        let modifiers = colorWords
            .union(stripWords)
            .union(fillerWords)
        return tokens.allSatisfy { modifiers.contains($0) }
    }

    static func isWeakGroceryName(_ name: String) -> Bool {
        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return true }
        if weakGroceryNames.contains(n) { return true }
        if isVagueAmountPhrase(n) { return true }
        let tokens = Set(
            n.split(separator: " ").map { String($0).trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty }
        )
        let modifiers = colorWords.union(["packed", "lightly", "firmly", "loosely", "fresh", "dried"])
        return !tokens.isEmpty && tokens.isSubset(of: modifiers)
    }

    /// "as much bacon as you want", "for garnish", etc. — not shoppable quantities.
    static func isVagueAmountPhrase(_ raw: String) -> Bool {
        let s = raw.lowercased()
        if s.range(of: #"\bas much\b.+\bas you want\b"#, options: .regularExpression) != nil {
            return true
        }
        if s.range(of: #"\b(to taste|as needed|as desired)\b"#, options: .regularExpression) != nil {
            return true
        }
        if s.contains("for garnish"), s.range(of: #"\d"#, options: .regularExpression) == nil {
            return true
        }
        return false
    }

    /// Pull glued package sizes out of names: "250g cheddar", "0.13 275ml milk", "30g+ butter".
    static func peelEmbeddedMeasure(from raw: String) -> (qty: Double, unit: String, rest: String)? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // Optional leading scale ("0.13 ") then qty+unit (glued or spaced), then the food name.
        let pattern =
            #"^(?:(\d+(?:\.\d+)?)\s+)?(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb|lbs|tsp|tbsp|cup|cups)\+?\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let qtyRange = Range(match.range(at: 2), in: s),
              let unitRange = Range(match.range(at: 3), in: s),
              let restRange = Range(match.range(at: 4), in: s),
              let qty = Double(s[qtyRange])
        else { return nil }
        var unit = String(s[unitRange]).lowercased()
        if unit == "lbs" { unit = "lb" }
        if unit == "cups" { unit = "cup" }
        let rest = String(s[restRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty, qty > 0 else { return nil }
        var scale = 1.0
        if match.range(at: 1).location != NSNotFound,
           let scaleRange = Range(match.range(at: 1), in: s),
           let scaleVal = Double(s[scaleRange]),
           scaleVal > 0, scaleVal < 5 {
            scale = scaleVal
        }
        return (qty * scale, unit, rest)
    }

    /// True when a token is only a measure like "250g" / "30g+" / "1½".
    private static func isMeasureToken(_ token: String) -> Bool {
        let t = token.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if t.isEmpty { return false }
        if Double(t) != nil { return true }
        if t.unicodeScalars.allSatisfy({ fractionScalars.contains($0) }) { return true }
        return t.range(
            of: #"^\d+(\.\d+)?(g|kg|ml|l|oz|lb|lbs|tsp|tbsp|cup|cups)?\+?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func singularizeGroceryName(_ name: String) -> String {
        var name = name
        if name.hasSuffix("oes") {
            name = String(name.dropLast(2))
        } else if name.hasSuffix("ies") {
            name = String(name.dropLast(3)) + "y"
        } else if name.hasSuffix("s"), !name.hasSuffix("ss"), !name.contains(" ") {
            if !keepPlural.contains(name) {
                name = String(name.dropLast())
            }
        } else if name.hasSuffix("es") && (name.hasSuffix("ches") || name.hasSuffix("oes")) {
            name = String(name.dropLast())
        }
        if name.hasSuffix(" breasts") {
            name = String(name.dropLast(1))
        }
        if name.hasSuffix("s") && name.contains(" ") {
            let parts = name.split(separator: " ").map(String.init)
            if var last = parts.last, last.hasSuffix("s"), !last.hasSuffix("ss") {
                if last == "leaves" {
                    last = "leaf"
                } else if last == "inches" || last == "inche" {
                    // Never leave "inche" on a shop line — drop the size word.
                    return parts.dropLast().joined(separator: " ")
                } else if !keepPlural.contains(last) {
                    last = String(last.dropLast())
                }
                name = (parts.dropLast() + [last]).joined(separator: " ")
            }
        }
        return name
    }

    private static func isEggName(_ s: String) -> Bool {
        if s.contains("eggplant") || s.contains("egg wash") || s.contains("egg noodle") {
            return false
        }
        return s.range(of: #"\beggs?\b"#, options: .regularExpression) != nil
    }

    /// Lemon juice / zest / wedge shop as whole lemons (same for limes).
    private static func collapseCitrus(_ s: String) -> String? {
        if s.contains("lemongrass") || s.contains("lemon grass") { return nil }
        if s.contains("lemon pepper") || s.contains("lemon extract") { return nil }
        if s.contains("preserved lemon") || s.contains("lemonade") || s.contains("lemon curd") {
            return nil
        }
        if s.contains("lemon") { return "lemon" }
        if s.contains("kaffir") || s.contains("makrut") || s.contains("lime leaf") {
            return nil
        }
        if s.contains("limeade") { return nil }
        if s.contains("lime") { return "lime" }
        return nil
    }

    /// AP / all-purpose / white flour shop as flour. Bread, cake, almond stay separate.
    private static func collapseFlour(_ s: String) -> String? {
        guard s.contains("flour") else { return nil }
        let specials: [(String, String)] = [
            ("almond", "almond flour"),
            ("coconut", "coconut flour"),
            ("chickpea", "chickpea flour"),
            ("besan", "chickpea flour"),
            ("gram flour", "chickpea flour"),
            ("bread", "bread flour"),
            ("cake", "cake flour"),
            ("pastry", "pastry flour"),
            ("whole wheat", "whole wheat flour"),
            ("wholewheat", "whole wheat flour"),
            ("rye", "rye flour"),
            ("buckwheat", "buckwheat flour"),
            ("rice", "rice flour"),
            ("corn", "corn flour"),
            ("masa", "masa"),
            ("self rising", "self-rising flour"),
            ("gluten free", "gluten-free flour"),
            ("00", "00 flour"),
            ("tipo", "00 flour"),
        ]
        for (needle, name) in specials where s.contains(needle) {
            return name
        }
        return "flour"
    }

    /// Joy-style "Up to ¾ cup Vinaigrette or … mayonnaise" is a recipe pointer, not a food.
    private static func collapseCookbookRef(_ s: String) -> String? {
        let refs = [
            "vinaigrette", "chimichurri", "gremolata",
            "aioli", "aïoli", "remoulade", "rémoulade", "marinara",
        ]
        guard refs.contains(where: { s.contains($0) }) else { return nil }
        if s.contains("mayonnaise") || s.range(of: #"\bmayo\b"#, options: .regularExpression) != nil {
            return "mayonnaise"
        }
        if s.contains("sour cream") { return "sour cream" }
        if s.contains("yogurt") || s.contains("yoghurt") { return "yogurt" }
        return ""
    }

    private static let fractionScalars = CharacterSet(charactersIn: "½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞")

    /// toasted/roasted sesame oil → sesame oil; EVOO → olive oil. Generic "oil" stays separate.
    private static func collapseOil(_ s: String) -> String {
        if s.contains("sesame") { return "sesame oil" }
        if s.contains("olive") { return "olive oil" }
        if s.contains("chili") || s.contains("chilli") || s.contains("chile") { return "chili oil" }
        if s.contains("peanut") { return "peanut oil" }
        if s.contains("coconut") { return "coconut oil" }
        if s.contains("avocado") { return "avocado oil" }
        if s.contains("walnut") { return "walnut oil" }
        if s.contains("truffle") { return "truffle oil" }
        if s.contains("garlic") { return "garlic oil" }
        if s.contains("grapeseed") { return "grapeseed oil" }
        if s.contains("canola") || s.contains("vegetable") || s.contains("neutral")
            || s.contains("sunflower") || s.contains("cooking oil") {
            return "vegetable oil"
        }
        return "vegetable oil"
    }

    static func category(for name: String) -> String {
        let n = name.lowercased()
        if n == "egg" || n.hasPrefix("egg ") {
            return "protein"
        }
        if ["chicken", "beef", "pork", "turkey", "salmon", "tuna", "shrimp", "tofu", "tempeh", "lamb", "meat"].contains(where: { n.contains($0) }) {
            return "protein"
        }
        if ["milk", "yogurt", "cheese", "butter", "cream", "feta"].contains(where: { n.contains($0) }) {
            return "dairy"
        }
        if ["salt", "pepper", "cumin", "paprika", "oregano", "thyme", "cinnamon", "chili"].contains(where: { n.contains($0) }) {
            return "spice"
        }
        if ["lettuce", "spinach", "broccoli", "tomato", "onion", "garlic", "lemon", "lime", "pepper", "carrot", "kale", "cucumber", "potato", "avocado", "celery", "parsley", "cilantro", "mint", "basil", "arugula", "cabbage"].contains(where: { n.contains($0) }) {
            return "produce"
        }
        if n.contains("frozen") { return "frozen" }
        return "pantry"
    }

    /// Normalize quantity into a merge-friendly unit for this ingredient.
    static func mergeableAmount(name: String, quantity: Double, unit: String) -> (qty: Double, unit: String) {
        let u = unit.lowercased()
        let key = canonicalize(name)

        if key == "garlic" {
            return (garlicHeads(quantity: quantity, unit: u), "head")
        }
        if key == "onion" || key == "red onion" {
            return (onionCount(quantity: quantity, unit: u, key: key), "count")
        }
        if key == "lemon" || key == "lime" {
            return (citrusCount(quantity: quantity, unit: u), "count")
        }
        if key == "ginger" {
            return (gingerOz(quantity: quantity, unit: u), "oz")
        }
        if key.hasPrefix("ground ") {
            if UnitConverter.kind(of: u) == .volume {
                if let cups = UnitConverter.convert(quantity, from: u, to: "cup") {
                    return (cups * groundMeatLbPerCup, "lb")
                }
            }
        }

        // Eggs are always a count — never list by weight.
        if key == "egg" {
            if UnitConverter.kind(of: u) == .weight {
                let grams = UnitConverter.convert(quantity, from: u, to: "g") ?? (quantity * 28.35)
                return (max(1, (grams / eggGrams).rounded()), "count")
            }
            if u == "dozen" {
                return (quantity * 12, "count")
            }
            return (quantity, "count")
        }

        // Produce that shops by bunch/head: accumulate in lb, then convert for display.
        if let shop = ShopFriendlyUnits.rule(for: key), shop.mergeAsWeight {
            if UnitConverter.kind(of: u) == .weight {
                if let lb = UnitConverter.convert(quantity, from: u, to: "lb") {
                    return (lb, "lb")
                }
            }
            if u == "count" || u == shop.unit || u == "bunch" || u == "head" || u == "bag" || u == "bush" {
                return (quantity * shop.lbPerUnit, "lb")
            }
            if u == "cup", herbBunchKeys.contains(key) {
                return (quantity * 0.06, "lb")
            }
            if (u == "tbsp" || u == "tsp"), herbBunchKeys.contains(key) {
                let cups = UnitConverter.convert(quantity, from: u, to: "cup") ?? (quantity / 16)
                return (cups * 0.06, "lb")
            }
            if u == "cup" && key == "spinach" {
                // Loose cups of spinach ≈ 1 oz
                return (quantity * 0.0625, "lb")
            }
        }

        if UnitConverter.kind(of: u) == .weight {
            if let lb = UnitConverter.convert(quantity, from: u, to: "lb") {
                return (lb, "lb")
            }
        }
        if u == "count" || UnitConverter.kind(of: u) == .count {
            if let per = countToLb[key] {
                return (quantity * per, "lb")
            }
        }
        if let canon = UnitConverter.toCanonical(quantity: quantity, unit: u) {
            return (canon.qty, canon.unit)
        }
        return (quantity, u)
    }

    /// 1 head ≈ 10 cloves ≈ 10 tsp minced ≈ 3.3 tbsp.
    private static func garlicHeads(quantity: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "head", "heads": return quantity
        case "clove", "cloves", "each", "count": return quantity / 10.0
        case "tsp": return quantity / 10.0
        case "tbsp": return quantity / (10.0 / 3.0)
        case "cup": return quantity * 4.8
        case "g": return quantity / 36.0
        case "oz": return quantity / 1.27
        case "lb": return quantity / 0.08
        default:
            if UnitConverter.kind(of: unit) == .volume {
                let tbsp = UnitConverter.convert(quantity, from: unit, to: "tbsp") ?? quantity
                return tbsp / (10.0 / 3.0)
            }
            return quantity / 10.0
        }
    }

    /// 1 onion ≈ 1 cup chopped ≈ 16 tbsp.
    private static func onionCount(quantity: Double, unit: String, key: String) -> Double {
        switch unit.lowercased() {
        case "count", "each": return quantity
        case "cup": return quantity
        case "tbsp": return quantity / 16.0
        case "tsp": return quantity / 48.0
        case "g": return quantity / 150.0
        case "oz": return quantity / 5.3
        case "lb": return quantity / 0.5
        default:
            if let shop = ShopFriendlyUnits.rule(for: key), UnitConverter.kind(of: unit) == .weight {
                if let lb = UnitConverter.convert(quantity, from: unit, to: "lb") {
                    return lb / shop.lbPerUnit
                }
            }
            return quantity
        }
    }

    /// 1 lemon ≈ 3 tbsp juice ≈ 1 tbsp zest; wedges are slices of that fruit.
    private static func citrusCount(quantity: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "count", "each", "whole": return quantity
        case "wedge", "wedges", "slice", "slices": return quantity / 8.0
        case "tsp": return quantity / 9.0
        case "tbsp": return quantity / 3.0
        case "cup": return quantity / 0.1875
        case "ml": return quantity / 45.0
        case "floz", "fl oz": return quantity / 1.5
        case "g": return quantity / 90.0
        case "oz": return quantity / 3.2
        case "lb": return quantity / 0.2
        default:
            if UnitConverter.kind(of: unit) == .volume {
                let tbsp = UnitConverter.convert(quantity, from: unit, to: "tbsp") ?? quantity
                return tbsp / 3.0
            }
            return quantity
        }
    }

    /// Fold knobs, tbsp, and weight into ounces.
    private static func gingerOz(quantity: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "oz": return quantity
        case "g": return quantity / 28.35
        case "lb": return quantity * 16
        case "tbsp": return quantity * 0.25
        case "tsp": return quantity * 0.08
        case "count", "each", "knob", "inch": return quantity * 0.5
        default: return quantity
        }
    }
}

/// Convert consolidated weights into how you'd actually buy produce at the store.
enum ShopFriendlyUnits {
    /// Dinner meal-prep only — never list more than this many eggs for the week.
    static let maxEggsPerWeek = 18

    struct Rule {
        let unit: String // bunch, head, bag, count
        let lbPerUnit: Double
        let mergeAsWeight: Bool
        let plural: String
    }

    private static let rules: [String: Rule] = [
        // User asked for broccoli → bushes/bunches; ~1 lb per bunch.
        "broccoli": Rule(unit: "bunch", lbPerUnit: 1.0, mergeAsWeight: true, plural: "bunches"),
        "cauliflower": Rule(unit: "head", lbPerUnit: 2.0, mergeAsWeight: true, plural: "heads"),
        "cabbage": Rule(unit: "head", lbPerUnit: 2.0, mergeAsWeight: true, plural: "heads"),
        "lettuce": Rule(unit: "head", lbPerUnit: 0.75, mergeAsWeight: true, plural: "heads"),
        "spinach": Rule(unit: "bag", lbPerUnit: 0.5, mergeAsWeight: true, plural: "bags"),
        "kale": Rule(unit: "bunch", lbPerUnit: 0.5, mergeAsWeight: true, plural: "bunches"),
        "celery": Rule(unit: "bunch", lbPerUnit: 1.0, mergeAsWeight: true, plural: "bunches"),
        "asparagus": Rule(unit: "bunch", lbPerUnit: 1.0, mergeAsWeight: true, plural: "bunches"),
        "green onion": Rule(unit: "bunch", lbPerUnit: 0.25, mergeAsWeight: true, plural: "bunches"),
        "carrot": Rule(unit: "bag", lbPerUnit: 1.0, mergeAsWeight: true, plural: "bags"),
        "onion": Rule(unit: "count", lbPerUnit: 0.5, mergeAsWeight: true, plural: ""),
        "potato": Rule(unit: "count", lbPerUnit: 0.5, mergeAsWeight: true, plural: ""),
        "sweet potato": Rule(unit: "count", lbPerUnit: 0.6, mergeAsWeight: true, plural: ""),
        "avocado": Rule(unit: "count", lbPerUnit: 0.4, mergeAsWeight: true, plural: ""),
        "lemon": Rule(unit: "count", lbPerUnit: 0.2, mergeAsWeight: true, plural: ""),
        "lime": Rule(unit: "count", lbPerUnit: 0.15, mergeAsWeight: true, plural: ""),
        "bell pepper": Rule(unit: "count", lbPerUnit: 0.4, mergeAsWeight: true, plural: ""),
        "tomato": Rule(unit: "count", lbPerUnit: 0.35, mergeAsWeight: true, plural: ""),
        "garlic": Rule(unit: "head", lbPerUnit: 0.12, mergeAsWeight: true, plural: "heads"),
        "banana": Rule(unit: "count", lbPerUnit: 0.26, mergeAsWeight: true, plural: ""),
        "parsley": Rule(unit: "bunch", lbPerUnit: 0.12, mergeAsWeight: true, plural: "bunches"),
        "cilantro": Rule(unit: "bunch", lbPerUnit: 0.12, mergeAsWeight: true, plural: "bunches"),
        "mint": Rule(unit: "bunch", lbPerUnit: 0.08, mergeAsWeight: true, plural: "bunches"),
        "basil": Rule(unit: "bunch", lbPerUnit: 0.1, mergeAsWeight: true, plural: "bunches"),
        "arugula": Rule(unit: "bag", lbPerUnit: 0.3, mergeAsWeight: true, plural: "bags"),
    ]

    static func rule(for name: String) -> Rule? {
        let key = IngredientCanonicalizer.canonicalize(name)
        if let direct = rules[key] { return direct }
        // Partial match for "broccoli florets" etc. already canonicalized.
        return rules.first(where: { key.contains($0.key) })?.value
    }

    /// Round up so the shopper buys enough.
    static func toShopFriendly(name: String, quantity: Double, unit: String) -> (qty: Double, unit: String) {
        let key = IngredientCanonicalizer.canonicalize(name)

        if key == "egg" {
            let count: Double
            if UnitConverter.kind(of: unit) == .weight {
                let grams = UnitConverter.convert(quantity, from: unit, to: "g") ?? quantity
                count = max(1, (grams / 50.0).rounded(.up))
            } else {
                count = max(1, quantity.rounded(.up))
            }
            return (min(count, Double(maxEggsPerWeek)), "count")
        }

        guard let rule = rule(for: key) else {
            return (quantity, unit)
        }

        let lb: Double
        if UnitConverter.kind(of: unit) == .weight {
            lb = UnitConverter.convert(quantity, from: unit, to: "lb") ?? quantity
        } else if unit == "count" || unit == rule.unit || unit == "bunch" || unit == "head" || unit == "bag" {
            // Already in shop units
            return (max(1, quantity.rounded(.up)), rule.unit == "count" ? "count" : rule.unit)
        } else {
            return (quantity, unit)
        }

        let units = max(1, (lb / rule.lbPerUnit).rounded(.up))
        return (units, rule.unit)
    }
}

struct ConsolidatedGroceryItem: Identifiable, Hashable {
    var id: String { "\(category)|\(ingredientName)|\(isApproximate)" }
    let ingredientName: String
    let category: String
    var quantity: Double
    var unit: String
    var isApproximate: Bool
    var note: String
    var isChecked: Bool
    var isManual: Bool
}

enum GroceryConsolidator {
    static let categoryOrder = ["produce", "protein", "dairy", "pantry", "spice", "frozen", "other"]
    /// Weekly shop cap once breakfast staples were removed (user rule).
    static let maxEggsPerWeek = ShopFriendlyUnits.maxEggsPerWeek

    /// Name-encoded breakfast staples ("24 eggs") or any egg count above the weekly cap.
    private static let leftoverEggNameCounts: Set<Int> = [12, 14, 18, 21, 24, 28, 30, 36]

    static func isLeftoverBreakfastEgg(name: String, quantity: Double, unit: String) -> Bool {
        let raw = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = IngredientCanonicalizer.canonicalize(name)
        if let match = raw.range(of: #"^(\d+)(\.0+)?\s*eggs?$"#, options: .regularExpression) {
            let digits = raw[match].prefix(while: { $0.isNumber })
            if let n = Int(digits), leftoverEggNameCounts.contains(n) {
                return true
            }
        }
        guard key == "egg" || key == "eggs" else { return false }
        var count = quantity
        if unit.lowercased() == "dozen" { count = quantity * 12 }
        return count > Double(maxEggsPerWeek) + 0.4
    }

    static func consolidate(from recipes: [Recipe], scaledServings: [String: Int]) -> [ConsolidatedGroceryItem] {
        struct Acc {
            var qty: Double
            var unit: String
            var category: String
            var approx: Bool
            var notes: Set<String>
        }
        var map: [String: Acc] = [:]

        func add(_ key: String, _ incoming: Acc) {
            if var acc = map[key] {
                if acc.approx, !incoming.approx {
                    map[key] = incoming
                    return
                }
                if incoming.approx {
                    return
                }
                if let converted = UnitConverter.convert(incoming.qty, from: incoming.unit, to: acc.unit) {
                    acc.qty += converted
                } else if let converted = UnitConverter.convert(acc.qty, from: acc.unit, to: incoming.unit) {
                    acc.qty = converted + incoming.qty
                    acc.unit = incoming.unit
                } else if acc.unit == incoming.unit {
                    acc.qty += incoming.qty
                } else {
                    acc.notes.insert("+\(formatQty(incoming.qty)) \(incoming.unit)")
                }
                acc.notes.formUnion(incoming.notes)
                if incoming.category == "protein" { acc.category = "protein" }
                map[key] = acc
            } else {
                map[key] = incoming
            }
        }

        for recipe in recipes {
            let target = Double(scaledServings[recipe.id] ?? recipe.baseServings)
            let base = Double(max(recipe.baseServings, 1))
            let factor = target / base
            let lines = recipe.parsedIngredients.isEmpty
                ? recipe.ingredients.map { ParsedIngredient(raw: $0, quantity: 1, unit: "each", item: $0, prep: "", toTaste: false, optional: false, allergens: [], notes: "") }
                : recipe.parsedIngredients
            // Juice + zest + wedge of one fruit in a recipe is one piece of produce.
            var fruitMax: [String: Acc] = [:]
            var eggWhole = 0.0
            var eggWhite = 0.0
            var eggYolk = 0.0
            for ing in lines where !ing.isSectionHeader {
                if IngredientCanonicalizer.isVagueAmountPhrase(ing.raw)
                    || IngredientCanonicalizer.isVagueAmountPhrase(ing.item) {
                    let vagueKey = IngredientCanonicalizer.groceryName(for: ing)
                    // Try to salvage a real food word ("bacon") from garnish fluff.
                    let salvage = vagueKey.isEmpty
                        ? IngredientCanonicalizer.canonicalize(
                            ing.item.isEmpty ? ing.raw : ing.item
                                .replacingOccurrences(
                                    of: #"\bas much\b|\bas you want\b|\bfor garnish\b|\bgarnish\b"#,
                                    with: " ",
                                    options: .regularExpression
                                )
                        )
                        : vagueKey
                    if !salvage.isEmpty, !IngredientCanonicalizer.isWeakGroceryName(salvage) {
                        let category = IngredientCanonicalizer.category(for: salvage)
                        add(salvage, Acc(qty: 0, unit: "to_taste", category: category, approx: true, notes: []))
                    }
                    continue
                }
                let key = IngredientCanonicalizer.groceryName(for: ing)
                guard !key.isEmpty else { continue }
                let fryingOil = IngredientCanonicalizer.isFryingOil(ing.raw)
                var unit = fryingOil ? "cup" : (ing.unit == "each" ? "count" : (ing.unit ?? "count"))
                var scaledQty = fryingOil ? 2.0 : (ing.quantity ?? 1) * factor
                // Bad cookbook rows often leave "250g cheddar" in the item with count=1.
                if !fryingOil,
                   let peeled = IngredientCanonicalizer.peelEmbeddedMeasure(from: ing.item)
                    ?? IngredientCanonicalizer.peelEmbeddedMeasure(from: ing.raw) {
                    let unitKind = UnitConverter.kind(of: unit)
                    let countLike = unit == "count" || unit == "each" || unitKind == .count
                    if countLike {
                        scaledQty = (ing.quantity ?? 1) * peeled.qty * factor
                        unit = peeled.unit
                    }
                }
                let category = IngredientCanonicalizer.category(for: key)
                let notes = Set(ing.prep.isEmpty ? [] : [ing.prep])
                if ing.toTaste || unit == "to_taste" {
                    // Don't let "zest to taste" block a real lemon from the same recipe.
                    if IngredientCanonicalizer.wholeFruitKeys.contains(key) { continue }
                    add(key, Acc(qty: 0, unit: "to_taste", category: category, approx: true, notes: notes))
                    continue
                }
                if !fryingOil, ing.quantity == nil, ing.unit == nil,
                   ["mayonnaise", "mustard"].contains(key) {
                    add(key, Acc(qty: 0, unit: "to_taste", category: category, approx: true, notes: notes))
                    continue
                }

                let merged = IngredientCanonicalizer.mergeableAmount(
                    name: key == "egg white" || key == "egg yolk" ? "egg" : key,
                    quantity: scaledQty,
                    unit: unit
                )
                if key == "egg" {
                    eggWhole += merged.qty
                    continue
                }
                if key == "egg white" {
                    eggWhite += merged.qty
                    continue
                }
                if key == "egg yolk" {
                    eggYolk += merged.qty
                    continue
                }
                let row = Acc(
                    qty: merged.qty,
                    unit: merged.unit,
                    category: category,
                    approx: false,
                    notes: notes
                )
                if IngredientCanonicalizer.wholeFruitKeys.contains(key) {
                    if var acc = fruitMax[key] {
                        if row.qty > acc.qty {
                            acc.qty = row.qty
                            acc.unit = row.unit
                        }
                        acc.notes.formUnion(row.notes)
                        fruitMax[key] = acc
                    } else {
                        fruitMax[key] = row
                    }
                    continue
                }
                add(key, row)
            }
            for (key, acc) in fruitMax {
                add(key, acc)
            }
            // Whites/yolks from the same eggs shouldn't stack on whole eggs.
            // Buy enough whole eggs for the larger of wholes vs whites vs yolks.
            let eggs = max(eggWhole, eggWhite, eggYolk)
            if eggs > 0 {
                // Always round up so a scaled 7.2-egg batter still buys 8.
                add("egg", Acc(qty: eggs.rounded(.up), unit: "count", category: "protein", approx: false, notes: []))
            }
        }

        return map.map { name, acc in
            let pretty: (Double, String) = acc.approx
                ? (0, "to_taste")
                : (acc.qty, acc.unit)
            return ConsolidatedGroceryItem(
                ingredientName: name,
                category: acc.category,
                quantity: pretty.0,
                unit: pretty.1,
                isApproximate: acc.approx,
                note: acc.notes.sorted().joined(separator: "; "),
                isChecked: false,
                isManual: false
            )
        }
        .sorted { a, b in
            let ai = categoryOrder.firstIndex(of: a.category) ?? 99
            let bi = categoryOrder.firstIndex(of: b.category) ?? 99
            if ai != bi { return ai < bi }
            return a.ingredientName < b.ingredientName
        }
    }

    /// Round quantities into how you'd buy them (bunches, heads, egg counts).
    /// Always re-canonicalizes names and merges duplicates so LLM leftovers can't linger.
    static func finalizeForShopping(_ items: [ConsolidatedGroceryItem]) -> [ConsolidatedGroceryItem] {
        let normalized = mergeByCanonicalName(items.compactMap(sanitizeItem(_:)))
        return normalized.sorted { a, b in
            let ai = categoryOrder.firstIndex(of: a.category) ?? 99
            let bi = categoryOrder.firstIndex(of: b.category) ?? 99
            if ai != bi { return ai < bi }
            return a.ingredientName < b.ingredientName
        }
    }

    /// Re-run canonicalize + shop units on every line (rules or LLM).
    private static func sanitizeItem(_ item: ConsolidatedGroceryItem) -> ConsolidatedGroceryItem? {
        var name = item.ingredientName
        var qty = item.quantity
        var unit = item.unit
        var approx = item.isApproximate
        var category = item.category

        if let peeled = IngredientCanonicalizer.peelEmbeddedMeasure(from: name) {
            let cleaned = IngredientCanonicalizer.canonicalize(peeled.rest)
            if !cleaned.isEmpty {
                name = cleaned
                if unit == "count" || unit.isEmpty || UnitConverter.kind(of: unit) == .count {
                    qty = peeled.qty
                    unit = peeled.unit
                }
            }
        }

        name = IngredientCanonicalizer.canonicalize(name)
        guard !name.isEmpty, !IngredientCanonicalizer.isWeakGroceryName(name) else {
            return nil
        }
        // Drop size leftovers that survived older builds ("… inche").
        if name.contains(" inche") || name.hasSuffix(" inche") || name == "inche" {
            name = name
                .replacingOccurrences(of: #"\binches?\b"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            name = IngredientCanonicalizer.canonicalize(name)
            guard !name.isEmpty else { return nil }
        }

        category = IngredientCanonicalizer.category(for: name)

        if IngredientCanonicalizer.isVagueAmountPhrase(name)
            || IngredientCanonicalizer.isVagueAmountPhrase(item.ingredientName) {
            if approx || unit == "to_taste" { return nil }
            return nil
        }

        if approx || unit == "to_taste" {
            return ConsolidatedGroceryItem(
                ingredientName: name,
                category: category,
                quantity: 0,
                unit: "to_taste",
                isApproximate: true,
                note: item.note,
                isChecked: item.isChecked,
                isManual: item.isManual
            )
        }

        if UnitConverter.kind(of: unit) == .volume,
           let canon = UnitConverter.toCanonical(quantity: qty, unit: unit) {
            qty = canon.qty
            unit = canon.unit
        }

        // Ground meats shop by weight — never "1 ground beef".
        if name.hasPrefix("ground "), unit == "count" || unit.isEmpty {
            unit = "lb"
            qty = max(1, qty)
        }

        if unit == "count", category == "protein" || name.contains("chicken") || name.contains("artichoke") {
            qty = max(1, qty.rounded(.up))
        }

        let shop = ShopFriendlyUnits.toShopFriendly(
            name: name,
            quantity: qty,
            unit: unit
        )
        return ConsolidatedGroceryItem(
            ingredientName: name,
            category: category,
            quantity: shop.qty,
            unit: shop.unit,
            isApproximate: false,
            note: item.note,
            isChecked: item.isChecked,
            isManual: item.isManual
        )
    }

    private static func mergeByCanonicalName(_ items: [ConsolidatedGroceryItem]) -> [ConsolidatedGroceryItem] {
        var map: [String: ConsolidatedGroceryItem] = [:]
        for item in items {
            let key = IngredientCanonicalizer.canonicalize(item.ingredientName)
            guard !key.isEmpty else { continue }
            if let existing = map[key] {
                map[key] = mergeShopItems(existing, item)
            } else {
                map[key] = item
            }
        }
        return Array(map.values)
    }

    private static func mergeShopItems(
        _ a: ConsolidatedGroceryItem,
        _ b: ConsolidatedGroceryItem
    ) -> ConsolidatedGroceryItem {
        if a.isApproximate && !b.isApproximate { return b }
        if b.isApproximate && !a.isApproximate { return a }
        var qty = a.quantity
        var unit = a.unit
        if a.unit == b.unit {
            qty = a.quantity + b.quantity
        } else if let bInA = UnitConverter.convert(b.quantity, from: b.unit, to: a.unit) {
            qty = a.quantity + bInA
        } else if let aInB = UnitConverter.convert(a.quantity, from: a.unit, to: b.unit) {
            qty = b.quantity + aInB
            unit = b.unit
        } else {
            qty = max(a.quantity, b.quantity)
        }
        let shop = ShopFriendlyUnits.toShopFriendly(name: a.ingredientName, quantity: qty, unit: unit)
        return ConsolidatedGroceryItem(
            ingredientName: a.ingredientName,
            category: a.category == "protein" || b.category == "protein" ? "protein" : a.category,
            quantity: shop.qty,
            unit: shop.unit,
            isApproximate: false,
            note: [a.note, b.note].filter { !$0.isEmpty }.joined(separator: "; "),
            isChecked: a.isChecked || b.isChecked,
            isManual: a.isManual || b.isManual
        )
    }

    static func formatQty(_ q: Double) -> String {
        if abs(q - q.rounded()) < 0.05 { return String(Int(q.rounded())) }
        // Prefer one decimal for shop-friendly fractions (0.5 cup), else two.
        if abs(q * 10 - (q * 10).rounded()) < 0.05 {
            return String(format: "%.1f", q)
        }
        return String(format: "%.2f", q)
    }

    static func displayText(_ item: ConsolidatedGroceryItem) -> String {
        if item.isApproximate || item.unit == "to_taste" {
            return "\(item.ingredientName.capitalized) — to taste"
        }
        let qty = formatQty(item.quantity)
        let n = Int(item.quantity.rounded(.up))
        let name = item.ingredientName

        // Never print "2 g 250g cheddar" — name must be unit-free.
        let safeName: String = {
            if let peeled = IngredientCanonicalizer.peelEmbeddedMeasure(from: name) {
                let cleaned = IngredientCanonicalizer.canonicalize(peeled.rest)
                return cleaned.isEmpty ? name : cleaned
            }
            return name
        }()

        switch item.unit {
        case "count":
            if safeName == "egg" {
                return "\(qty) egg\(n == 1 ? "" : "s")"
            }
            if n != 1, let plural = countPlurals[safeName] {
                return "\(qty) \(plural)"
            }
            return "\(qty) \(safeName)"
        case "bunch":
            return "\(qty) bunch\(n == 1 ? "" : "es") \(safeName)"
        case "head":
            return "\(qty) head\(n == 1 ? "" : "s") \(safeName)"
        case "bag":
            return "\(qty) bag\(n == 1 ? "" : "s") \(safeName)"
        case "cup":
            return "\(qty) cup\(n == 1 ? "" : "s") \(safeName)"
        case "tbsp":
            return "\(qty) tbsp \(safeName)"
        case "g", "ml", "oz", "lb", "kg", "tsp", "l":
            return "\(qty) \(item.unit) \(safeName)"
        default:
            // Avoid "0.13 count foo" style; omit empty/unknown units.
            if item.unit.isEmpty || item.unit == "each" {
                return "\(qty) \(safeName)"
            }
            return "\(qty) \(item.unit) \(safeName)"
        }
    }

    private static let countPlurals: [String: String] = [
        "onion": "onions",
        "red onion": "red onions",
        "lemon": "lemons",
        "lime": "limes",
        "avocado": "avocados",
        "tomato": "tomatoes",
        "potato": "potatoes",
        "carrot": "carrots",
        "artichoke": "artichokes",
        "whole chicken": "whole chickens",
        "beef steak": "beef steaks",
        "lamb chop": "lamb chops",
        "pork chop": "pork chops",
        "salmon": "salmon",
    ]

    static func applyPantry(_ items: [ConsolidatedGroceryItem], names: Set<String>) -> [ConsolidatedGroceryItem] {
        items.filter { !PantryMatcher.covers($0.ingredientName, pantry: names) }
    }

    static let defaultPantry: [String] = [
        "salt", "pepper", "olive oil", "vegetable oil", "soy sauce",
        "vinegar", "sugar", "flour", "baking powder", "baking soda",
        "paprika", "cumin", "oregano", "thyme", "cinnamon", "red pepper flake",
        "garlic powder", "onion powder", "chili powder", "bay leaf",
        "cornstarch", "black pepper",
    ]
}

/// Match pantry staples to grocery lines: "kosher salt" is salt, "bell pepper" is not pepper.
enum PantryMatcher {
    static func key(_ raw: String) -> String {
        var s = IngredientCanonicalizer.canonicalize(raw)
        for prefix in ["ground ", "dried ", "fresh ", "powdered ", "cracked ", "granulated ", "toasted ", "roasted ", "smoked ", "dark ", "light ", "flaky ", "flake "] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        }
        if let mapped = aliases[s] { return mapped }
        for (alias, mapped) in aliases.sorted(by: { $0.key.count > $1.key.count }) where alias.count >= 4 {
            if s == alias || s.hasSuffix(" " + alias) || s.hasPrefix(alias + " ") { return mapped }
        }
        if isCookingSalt(s) { return "salt" }
        return s
    }

    static func covers(_ groceryName: String, pantry: Set<String>) -> Bool {
        covers(groceryName, pantryKeys: Set(pantry.map { key($0) }))
    }

    static func covers(_ groceryName: String, pantryKeys: Set<String>) -> Bool {
        let item = key(groceryName)
        if pantryKeys.contains(item) { return true }
        if pantryKeys.contains("oil"), cookingOils.contains(item) { return true }
        if pantryKeys.contains("vinegar"), basicVinegars.contains(item) { return true }
        if pantryKeys.contains("pepper"), peppercorns.contains(item) { return true }
        if pantryKeys.contains("salt"), isCookingSalt(item) || salts.contains(item) { return true }
        if pantryKeys.contains("flour"), flours.contains(item) { return true }
        if pantryKeys.contains("sugar"), sugars.contains(item) { return true }
        if pantryKeys.contains("soy sauce"), soy.contains(item) { return true }
        return false
    }

    /// Pantry editor search: "salt" hits kosher salt; "spice" hits salt, pepper, cumin.
    static func matchesQuery(_ name: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let raw = name.lowercased()
        let item = key(name)
        if raw.contains(q) || item.contains(q) { return true }
        if let mapped = aliases[q], mapped == item { return true }
        if q.count >= 3 {
            for (alias, mapped) in aliases where alias.hasPrefix(q) || alias == q || mapped == q {
                if mapped == item { return true }
            }
        }
        let cat = IngredientCanonicalizer.category(for: name)
        if spiceQueries.contains(q) {
            return cat == "spice" || isCookingSalt(item) || peppercorns.contains(item)
        }
        return false
    }

    /// Kosher / sea / Maldon etc. — not garlic salt, salt pork, saltines.
    static func isCookingSalt(_ name: String) -> Bool {
        let s = name.lowercased()
        if salts.contains(s) { return true }
        let tokens = Set(s.split(whereSeparator: { !$0.isLetter }).map(String.init))
        guard tokens.contains("salt") else { return false }
        if tokens.contains(where: { flavoredSaltTokens.contains($0) }) { return false }
        if s.contains("saltine") { return false }
        return true
    }

    private static let spiceQueries: Set<String> = ["spice", "spices", "seasoning", "seasonings"]
    private static let flavoredSaltTokens: Set<String> = [
        "garlic", "onion", "celery", "seasoning", "lawry", "lawrys",
        "pork", "cod", "fish", "caramel", "peanut", "pretzel", "cracker",
    ]

    private static let aliases: [String: String] = [
        "kosher salt": "salt", "sea salt": "salt", "table salt": "salt",
        "fine salt": "salt", "coarse salt": "salt", "iodized salt": "salt",
        "maldon salt": "salt", "flake salt": "salt", "flaky salt": "salt",
        "himalayan salt": "salt", "pink salt": "salt", "rock salt": "salt",
        "pickling salt": "salt", "canning salt": "salt", "finishing salt": "salt",
        "diamond crystal": "salt", "morton salt": "salt",
        "black pepper": "pepper", "white pepper": "pepper",
        "ground pepper": "pepper", "peppercorn": "pepper",
        "extra virgin olive oil": "olive oil", "evoo": "olive oil",
        "virgin olive oil": "olive oil",
        "toasted sesame oil": "sesame oil", "roasted sesame oil": "sesame oil",
        "dark sesame oil": "sesame oil", "light sesame oil": "sesame oil",
        "sesame seed oil": "sesame oil",
        "canola oil": "oil", "vegetable oil": "oil", "neutral oil": "oil",
        "cooking oil": "oil", "grapeseed oil": "oil", "sunflower oil": "oil",
        "all purpose flour": "flour", "ap flour": "flour", "white flour": "flour",
        "unbleached flour": "flour", "plain flour": "flour",
        "granulated sugar": "sugar", "white sugar": "sugar", "cane sugar": "sugar",
        "apple cider vinegar": "vinegar", "white vinegar": "vinegar",
        "distilled vinegar": "vinegar", "cider vinegar": "vinegar",
        "red wine vinegar": "vinegar", "white wine vinegar": "vinegar",
        "tamari": "soy sauce", "shoyu": "soy sauce", "light soy sauce": "soy sauce",
        "dark soy sauce": "soy sauce", "low sodium soy sauce": "soy sauce",
        "granulated garlic": "garlic powder", "dried oregano": "oregano",
        "dried thyme": "thyme", "chili flake": "red pepper flake",
        "crushed red pepper": "red pepper flake", "red pepper flakes": "red pepper flake",
        "cayenne": "chili powder",
    ]

    private static let cookingOils: Set<String> = [
        "oil", "vegetable oil", "canola oil", "neutral oil", "cooking oil",
        "grapeseed oil", "sunflower oil",
    ]
    private static let basicVinegars: Set<String> = [
        "vinegar", "white vinegar", "apple cider vinegar", "cider vinegar",
        "distilled vinegar", "red wine vinegar", "white wine vinegar",
    ]
    private static let peppercorns: Set<String> = ["pepper", "black pepper", "white pepper", "peppercorn"]
    private static let salts: Set<String> = [
        "salt", "kosher salt", "sea salt", "table salt", "fine salt", "coarse salt",
        "maldon salt", "flake salt", "flaky salt", "himalayan salt", "pink salt",
    ]
    private static let flours: Set<String> = [
        "flour", "all purpose flour", "ap flour", "white flour", "unbleached flour", "plain flour",
    ]
    private static let sugars: Set<String> = ["sugar", "white sugar", "granulated sugar"]
    private static let soy: Set<String> = ["soy sauce", "tamari", "shoyu"]
}
