import Foundation

/// Curated sides a coach would actually plate with a protein main.
/// Prefer these over random veggie “mains” demoted to sides.
enum SideCatalog {
    struct Entry: Hashable, Identifiable {
        var id: String { slug }
        var slug: String
        var title: String
        /// Search needles against recipe name / tags / chapter.
        var needles: [String]
        /// When the main’s protein family matches, boost this side.
        var pairsWellWith: Set<String>
        /// Carb / veg / salad — for variety across the week.
        var kind: Kind

        enum Kind: String, Hashable {
            case starch, vegetable, salad, green
        }
    }

    static let entries: [Entry] = [
        Entry(slug: "rice", title: "Rice", needles: ["rice", "pilaf", "risotto"], pairsWellWith: ["chicken", "beef", "pork", "fish", "shellfish", "tofu", "bean"], kind: .starch),
        Entry(slug: "potato", title: "Potatoes", needles: ["potato", "hash brown", "fries", "tater"], pairsWellWith: ["chicken", "beef", "pork", "fish", "egg"], kind: .starch),
        Entry(slug: "sweet-potato", title: "Sweet potato", needles: ["sweet potato", "yam"], pairsWellWith: ["chicken", "pork", "fish", "bean"], kind: .starch),
        Entry(slug: "broccoli", title: "Broccoli", needles: ["broccoli"], pairsWellWith: ["chicken", "beef", "pork", "fish", "tofu"], kind: .vegetable),
        Entry(slug: "asparagus", title: "Asparagus", needles: ["asparagus"], pairsWellWith: ["chicken", "fish", "shellfish", "egg"], kind: .vegetable),
        Entry(slug: "green-beans", title: "Green beans", needles: ["green bean", "haricot"], pairsWellWith: ["chicken", "beef", "pork", "fish"], kind: .vegetable),
        Entry(slug: "salad", title: "Salad", needles: ["salad", "slaw"], pairsWellWith: ["chicken", "fish", "shellfish", "egg", "tofu", "bean"], kind: .salad),
        Entry(slug: "spinach", title: "Spinach / greens", needles: ["spinach", "kale", "swiss chard", "collard", "sautéed green", "sauteed green"], pairsWellWith: ["chicken", "beef", "pork", "fish", "egg", "tofu"], kind: .green),
        Entry(slug: "roasted-veg", title: "Roasted vegetables", needles: ["roasted vegetable", "roasted veg", "sheet pan vegetable"], pairsWellWith: ["chicken", "beef", "pork", "lamb", "tofu"], kind: .vegetable),
        Entry(slug: "coleslaw", title: "Slaw", needles: ["coleslaw", "cabbage slaw", "slaw"], pairsWellWith: ["pork", "chicken", "fish"], kind: .salad),
        Entry(slug: "corn", title: "Corn", needles: ["corn on the cob", "elote", "creamed corn", "corn salad"], pairsWellWith: ["chicken", "beef", "pork", "fish"], kind: .vegetable),
        Entry(slug: "quinoa", title: "Quinoa / grain", needles: ["quinoa", "farro", "couscous", "bulgur"], pairsWellWith: ["chicken", "fish", "tofu", "bean", "lamb"], kind: .starch),
    ]

    static func match(_ recipe: Recipe) -> Entry? {
        let blob = ([recipe.name, recipe.chapter, recipe.section, recipe.course] + recipe.tags)
            .joined(separator: " ")
            .lowercased()
        return entries.first { entry in
            entry.needles.contains { blob.contains($0) }
        }
    }

    /// Score a candidate side against a main’s protein profile + week variety.
    static func score(
        side: Recipe,
        mainProteins: Set<String>,
        usedKinds: Set<Entry.Kind>,
        usedSideIDs: Set<String>
    ) -> Double {
        guard !usedSideIDs.contains(side.id) else { return -1e9 }
        var score = 1.0
        if let entry = match(side) {
            score += 3.0
            if !mainProteins.isDisjoint(with: entry.pairsWellWith) {
                score += 2.5
            }
            if usedKinds.contains(entry.kind) {
                score -= 1.8
            } else {
                score += 1.2
            }
        } else {
            // Unknown side recipes still ok, but prefer catalog hits.
            score += 0.4
        }
        // Prefer true side-course recipes.
        if side.course == "side" { score += 1.5 }
        if WeekPlanner.hasProtein(side), SideCatalog.match(side) == nil {
            // Protein-heavy “sides” are usually wrong.
            score -= 2.0
        }
        return score
    }
}
