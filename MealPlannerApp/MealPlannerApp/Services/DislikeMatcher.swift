import Foundation

/// Smart dislike matching: "tomato" blocks cherry/grape/roma/diced tomatoes,
/// but not tomato sauce or tomato paste.
enum DislikeMatcher {
    /// Pull food tokens out of free text ("I don't like tomato, cilantro").
    static func parse(_ text: String) -> [String] {
        var original = normalize(text)
        original = original.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        original = collapse(original)
        guard !original.isEmpty else { return [] }

        // "tomato sauce" as the whole dislike means they want to skip sauce,
        // not the fresh-tomato rule.
        if isExactProcessedDislike(original) {
            return [original]
        }

        var s = stripProcessedTomato(original)
        for phrase in allAllowPhrases {
            s = s.replacingOccurrences(of: phrase, with: " ")
        }
        for phrase in junkPhrases {
            s = s.replacingOccurrences(of: phrase, with: " ")
        }
        s = collapse(s)

        var keys: [String] = []
        for food in knownFoods {
            if containsWord(food, in: s) {
                keys.append(canonicalizeDislike(food))
                s = s.replacingOccurrences(of: food, with: " ")
            }
        }
        s = collapse(s)

        let parts = s.split { ",;/\n".contains($0) }
            .flatMap { $0.split(separator: " ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { token in
                token.count >= 3 && !stopwords.contains(token)
            }
        keys.append(contentsOf: parts.map { canonicalizeDislike($0) })

        var seen = Set<String>()
        return keys.filter { key in
            guard !key.isEmpty, !stopwords.contains(key) else { return false }
            return seen.insert(key).inserted
        }
    }

    static func blocks(_ recipe: Recipe, dislikes: [String]) -> Bool {
        let keys = dislikes.flatMap { parse($0) }
        guard !keys.isEmpty else { return false }
        for ing in recipe.parsedIngredients {
            let blob = [ing.item, ing.raw, ing.prep, ing.notes].joined(separator: " ")
            if keys.contains(where: { hits($0, in: blob) }) { return true }
        }
        for line in recipe.ingredients {
            if keys.contains(where: { hits($0, in: line) }) { return true }
        }
        return false
    }

    /// True when this ingredient line is something the user actually wants to avoid.
    static func hits(_ dislike: String, in raw: String) -> Bool {
        let dislikeKey = canonicalizeDislike(dislike)
        guard !dislikeKey.isEmpty else { return false }
        let original = normalize(raw)
        guard !original.isEmpty else { return false }

        if let rule = rules[dislikeKey] {
            var text = original
            if dislikeKey == "tomato" {
                text = stripProcessedTomato(text)
            }
            for phrase in rule.allowPhrases {
                text = text.replacingOccurrences(of: phrase, with: " ")
            }
            text = collapse(text)
            return rule.blockAliases.contains(where: { containsWord($0, in: text) })
                || containsWord(dislikeKey, in: text)
        }

        return containsWord(dislikeKey, in: original)
    }

    // MARK: - Rules

    private struct Rule {
        /// Extra names that still mean the disliked food (cherry tomato, cilantro leaf).
        let blockAliases: [String]
        /// Phrases that are OK even though they contain the word (tomato paste).
        let allowPhrases: [String]
    }

    private static let rules: [String: Rule] = [
        "tomato": Rule(
            blockAliases: [
                "cherry tomato", "grape tomato", "roma tomato", "plum tomato",
                "heirloom tomato", "beefsteak tomato", "campari tomato",
                "cocktail tomato", "vine tomato", "on the vine tomato",
                "sun dried tomato", "sundried tomato",
                "diced tomato", "crushed tomato", "chopped tomato",
                "whole tomato", "stewed tomato", "fresh tomato",
                "peeled tomato", "canned tomato", "tin tomato",
                "tomato salad", "tomato slice", "tomato wedge",
                "pomodoro",
            ],
            allowPhrases: tomatoAllowPhrases
        ),
        "cilantro": Rule(
            blockAliases: ["coriander leaf", "coriander leaves", "chinese parsley", "fresh coriander"],
            allowPhrases: ["coriander seed", "ground coriander", "coriander powder"]
        ),
        "pepper": Rule(
            blockAliases: [
                "bell pepper", "sweet pepper", "capsicum", "chili pepper",
                "chilli pepper", "jalapeno", "poblano", "anaheim",
            ],
            allowPhrases: [
                "black pepper", "white pepper", "peppercorn", "ground pepper",
                "cracked pepper", "cayenne",
            ]
        ),
        "onion": Rule(
            blockAliases: ["yellow onion", "white onion", "red onion", "sweet onion", "spanish onion"],
            allowPhrases: ["green onion", "spring onion", "scallion", "onion powder", "onion salt"]
        ),
        "mushroom": Rule(
            blockAliases: [
                "cremini", "crimini", "shiitake", "portobello", "portabella",
                "button mushroom", "porcini", "oyster mushroom", "maitake",
            ],
            allowPhrases: []
        ),
    ]

    /// Processed tomato products the user is OK eating when they dislike "tomato".
    private static let tomatoAllowPhrases: [String] = [
        "tomato ketchup", "tomato paste", "tomato sauce", "tomato puree",
        "tomato concentrate", "ketchup", "catsup", "passata", "marinara",
        "pizza sauce", "pomodoro sauce",
    ].sorted { $0.count > $1.count }

    /// Drop "tomato paste/sauce/puree" so leftover tomato words can be judged on their own.
    private static func stripProcessedTomato(_ raw: String) -> String {
        let pattern = #"\btomato(es)?\s+((pasta|pizza|marinara|pomodoro|spaghetti)\s+)?(ketchup|paste|sauce|puree|concentrate)s?\b"#
        let stripped = raw.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        return collapse(stripped)
    }

    private static var allAllowPhrases: [String] {
        rules.values.flatMap(\.allowPhrases).sorted { $0.count > $1.count }
    }

    /// Longest first so "cherry tomato" wins over "tomato".
    private static let knownFoods: [String] = [
        "cherry tomatoes", "grape tomatoes", "roma tomatoes", "plum tomatoes",
        "heirloom tomatoes", "beefsteak tomatoes", "sun dried tomatoes",
        "cherry tomato", "grape tomato", "roma tomato", "bell peppers",
        "bell pepper", "shellfish", "cilantro", "coriander", "mushrooms",
        "mushroom", "tomatoes", "tomato", "onions", "onion", "peppers",
        "shrimp", "prawns",
    ].sorted { $0.count > $1.count }

    private static let junkPhrases: [String] = [
        "i do not like", "i don't like", "i dont like", "i will have",
        "i hate", "i dislike", "hate ", "dislike ", "except ",
        "please ", "because ", "pretty ",
    ].sorted { $0.count > $1.count }

    private static let stopwords: Set<String> = [
        "the", "and", "but", "not", "dont", "don't", "hate", "like",
        "will", "have", "they", "them", "some", "ways", "say", "etc",
        "fine", "okay", "ok", "sauce", "paste", "puree", "except",
        "please", "just", "really", "also", "avoid", "eat", "food",
        "foods", "are", "can", "with", "for", "from", "that", "this",
        "those", "these", "there", "here", "how", "still", "show",
        "mind", "want", "does", "did", "yes", "nope",
        "fresh", "any", "all",
    ]

    private static func isExactProcessedDislike(_ s: String) -> Bool {
        let t = s.replacingOccurrences(of: "no ", with: "")
            .trimmingCharacters(in: .whitespaces)
        return tomatoAllowPhrases.contains { t == $0 || t == "\($0)s" }
    }

    private static func canonicalizeDislike(_ raw: String) -> String {
        let s = normalize(raw)
        let aliases: [String: String] = [
            "tomatoes": "tomato",
            "tomatoe": "tomato",
            "cherry tomatoes": "tomato",
            "cherry tomato": "tomato",
            "grape tomatoes": "tomato",
            "grape tomato": "tomato",
            "roma tomatoes": "tomato",
            "roma tomato": "tomato",
            "plum tomatoes": "tomato",
            "heirloom tomatoes": "tomato",
            "sun dried tomatoes": "tomato",
            "cilantro": "cilantro",
            "coriander": "cilantro",
            "peppers": "pepper",
            "bell pepper": "pepper",
            "bell peppers": "pepper",
            "onions": "onion",
            "mushrooms": "mushroom",
            "prawns": "shrimp",
        ]
        if let mapped = aliases[s] { return mapped }
        if s.hasSuffix("es"), let mapped = aliases[String(s.dropLast(2))] { return mapped }
        if s.hasSuffix("s"), let mapped = aliases[String(s.dropLast())] { return mapped }
        return s
    }

    private static func normalize(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: "é", with: "e")
        s = s.replacingOccurrences(of: "ñ", with: "n")
        s = s.replacingOccurrences(of: "-", with: " ")
        s = s.replacingOccurrences(of: "/", with: " ")
        s = collapse(s)
        return s
    }

    private static func collapse(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func containsWord(_ needle: String, in haystack: String) -> Bool {
        let n = needle.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return false }
        if n.contains(" ") {
            return haystack.contains(n)
        }
        guard let regex = try? NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: n))(es|s)?\\b"
        ) else {
            return haystack.contains(n)
        }
        let range = NSRange(haystack.startIndex..., in: haystack)
        return regex.firstMatch(in: haystack, range: range) != nil
    }
}
