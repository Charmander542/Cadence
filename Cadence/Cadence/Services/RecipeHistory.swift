import Foundation
import SwiftData

/// Remembers recipes used in past weekly plans so we can avoid repeats/near-duplicates.
@Model
final class RecipeHistoryEntity {
    var recipeID: String = ""
    var title: String = ""
    /// Compact similarity key: sorted tags + primary protein tokens from the title/ingredients.
    var fingerprint: String = ""
    var usedAt: Date = Date()

    init(recipeID: String, title: String, fingerprint: String, usedAt: Date = .now) {
        self.recipeID = recipeID
        self.title = title
        self.fingerprint = fingerprint
        self.usedAt = usedAt
    }
}

enum RecipeHistory {
    /// Exact recipe cooldown (won't be offered again until this many days pass).
    static let defaultExactCooldownDays = 21
    /// Similar recipe cooldown (title/tags/protein family overlap).
    static let defaultSimilarCooldownDays = 14

    static func fingerprint(for recipe: Recipe) -> String {
        var parts = Set(recipe.tags.map { $0.lowercased() })
        let titleTokens = tokenize(recipe.name)
        parts.formUnion(titleTokens)
        parts.formUnion(proteinTokens(in: recipe))
        return parts.sorted().joined(separator: "|")
    }

    static func tokenize(_ text: String) -> Set<String> {
        let stop: Set<String> = [
            "a", "an", "the", "and", "or", "with", "of", "in", "on", "for", "to",
            "recipe", "easy", "best", "quick", "homemade", "style",
        ]
        let cleaned = text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
        return Set(
            cleaned.split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
    }

    static func proteinTokens(in recipe: Recipe) -> Set<String> {
        let proteins = [
            "chicken", "beef", "pork", "turkey", "salmon", "tuna", "shrimp",
            "tofu", "tempeh", "lamb", "cod", "egg", "bacon", "sausage",
        ]
        let blob = (
            [recipe.name.lowercased()]
                + recipe.tags.map { $0.lowercased() }
                + recipe.parsedIngredients.prefix(12).map { $0.item.lowercased() }
        ).joined(separator: " ")
        return Set(proteins.filter { blob.contains($0) })
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let sa = Set(a.split(separator: "|").map(String.init))
        let sb = Set(b.split(separator: "|").map(String.init))
        guard !sa.isEmpty, !sb.isEmpty else { return 0 }
        let inter = Double(sa.intersection(sb).count)
        let union = Double(sa.union(sb).count)
        return union == 0 ? 0 : inter / union
    }

    static func record(recipes: [Recipe], in context: ModelContext, at date: Date = .now) throws {
        let unique = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        for recipe in unique {
            context.insert(
                RecipeHistoryEntity(
                    recipeID: recipe.id,
                    title: recipe.title,
                    fingerprint: fingerprint(for: recipe),
                    usedAt: date
                )
            )
        }
        // Cap history growth — keep ~1 year of entries.
        let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: date) ?? date
        let old = try context.fetch(
            FetchDescriptor<RecipeHistoryEntity>(
                predicate: #Predicate { $0.usedAt < cutoff }
            )
        )
        for row in old { context.delete(row) }
    }

    static func loadRecent(in context: ModelContext, withinDays days: Int) -> [RecipeHistoryEntity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let descriptor = FetchDescriptor<RecipeHistoryEntity>(
            predicate: #Predicate { $0.usedAt >= cutoff },
            sortBy: [SortDescriptor(\.usedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Score penalty (0 = fine, larger = more discouraged). Exact recent hits are effectively banned.
    static func penalty(
        for recipe: Recipe,
        history: [RecipeHistoryEntity],
        exactCooldownDays: Int,
        similarCooldownDays: Int
    ) -> Double {
        let fp = fingerprint(for: recipe)
        let now = Date.now
        var penalty = 0.0

        for entry in history {
            let daysAgo = max(0, Calendar.current.dateComponents([.day], from: entry.usedAt, to: now).day ?? 0)

            if entry.recipeID == recipe.id {
                if daysAgo < exactCooldownDays {
                    return 10_000 // hard exclude via filter
                }
                // Soft fade for a bit after the hard window
                if daysAgo < exactCooldownDays + 14 {
                    penalty = max(penalty, 25)
                }
                continue
            }

            if daysAgo < similarCooldownDays {
                let sim = similarity(fp, entry.fingerprint)
                if sim >= 0.45 {
                    // Strong near-duplicate (same protein family + overlapping title/tags)
                    penalty = max(penalty, 40 + sim * 40)
                } else if sim >= 0.28 {
                    penalty = max(penalty, 15 + sim * 20)
                }
            }
        }
        return penalty
    }
}
