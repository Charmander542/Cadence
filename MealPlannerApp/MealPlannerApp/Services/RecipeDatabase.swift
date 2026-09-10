import Foundation
import SQLite3

/// Read-only Based-Cooking store (`recipes.sqlite3`), cached in memory.
final class RecipeDatabase: @unchecked Sendable {
    static let shared = RecipeDatabase()

    private var db: OpaquePointer?
    private let lock = NSLock()
    private var byID: [String: Recipe] = [:]
    private var ordered: [Recipe] = []
    private var isLoaded = false
    private var isLoading = false

    private init() { open() }

    private func open() {
        let candidates = [
            Bundle.main.url(forResource: "recipes", withExtension: "sqlite3"),
        ].compactMap { $0 }
        guard let url = candidates.first else {
            print("RecipeDatabase: no bundled recipes.sqlite3")
            return
        }
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("RecipeDatabase: failed to open \(url.path)")
            db = nil
        }
    }

    deinit { if let db { sqlite3_close(db) } }

    /// Prefetch on a background queue so UI never waits on SQLite decode.
    func warmCache() {
        lock.lock()
        if isLoaded || isLoading {
            lock.unlock()
            return
        }
        isLoading = true
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async {
            self.finishLoad()
        }
    }

    /// Block until the in-memory cache is ready (tests / tooling). Safe to call from any thread.
    @discardableResult
    func waitUntilLoaded(timeout: TimeInterval = 60) -> Bool {
        warmCache()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            lock.lock()
            let ready = isLoaded
            let loading = isLoading
            lock.unlock()
            if ready { return true }
            if !loading, !Thread.isMainThread {
                // Nobody is loading (open failed or race) — try once more synchronously.
                lock.lock()
                if !isLoaded && !isLoading {
                    isLoading = true
                    lock.unlock()
                    finishLoad()
                } else {
                    lock.unlock()
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        lock.lock()
        defer { lock.unlock() }
        return isLoaded
    }

    /// Returns true when the in-memory cache is ready. Never blocks the main thread on a cold load.
    @discardableResult
    private func ensureLoaded() -> Bool {
        lock.lock()
        if isLoaded {
            lock.unlock()
            return true
        }
        let alreadyLoading = isLoading
        if !alreadyLoading {
            isLoading = true
        }
        lock.unlock()

        if alreadyLoading {
            return false
        }

        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async {
                self.finishLoad()
            }
            return false
        }

        finishLoad()
        lock.lock()
        let ready = isLoaded
        lock.unlock()
        return ready
    }

    private func finishLoad() {
        let recipes = loadAll()
        // Bundled data should be unique, but never crash if a duplicate id slips in.
        var map = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var orderedRecipes = recipes
        if map.count != orderedRecipes.count {
            var seen = Set<String>()
            orderedRecipes = orderedRecipes.filter { seen.insert($0.id).inserted }
            map = Dictionary(uniqueKeysWithValues: orderedRecipes.map { ($0.id, $0) })
        }

        lock.lock()
        ordered = orderedRecipes
        byID = map
        isLoaded = true
        isLoading = false
        lock.unlock()
    }

    func allRecipes(includeDetails: Bool = true) -> [Recipe] {
        _ = ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return ordered
    }

    func recipe(id: String) -> Recipe? {
        _ = ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return byID[id]
    }

    func recipes(ids: [String]) -> [Recipe] {
        ids.compactMap { recipe(id: $0) }
    }

    func recipesByID() -> [String: Recipe] {
        _ = ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return byID
    }

    func count() -> Int {
        _ = ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return ordered.count
    }

    func search(_ query: String, course: String? = nil, limit: Int = 40) -> [Recipe] {
        _ = ensureLoaded()
        lock.lock()
        let snapshot = ordered
        lock.unlock()

        let tokens = query.lowercased().split(separator: " ").map(String.init).filter { $0.count > 1 }
        var hits = snapshot
        if let course, !course.isEmpty {
            hits = hits.filter { $0.course == course }
        }
        guard !tokens.isEmpty else { return Array(hits.prefix(limit)) }
        return hits
            .map { recipe -> (Recipe, Int) in
                let blob = (
                    [recipe.name, recipe.course, recipe.source, recipe.chapter]
                        + recipe.tags
                        + recipe.ingredients
                        + recipe.parsedIngredients.map(\.item)
                ).joined(separator: " ").lowercased()
                let name = recipe.name.lowercased()
                var score = 0
                for token in tokens {
                    if name == query.lowercased() { score += 12 }
                    if name.contains(token) { score += 6 }
                    if blob.contains(token) { score += 2 }
                }
                return (recipe, score)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    func mains(excluding banned: Set<String> = []) -> [Recipe] {
        _ = ensureLoaded()
        lock.lock()
        let snapshot = ordered
        lock.unlock()
        return snapshot.filter { $0.course == "main" && !banned.contains($0.id) && $0.parsedIngredients.count >= 3 }
    }

    func sides(excluding banned: Set<String> = []) -> [Recipe] {
        _ = ensureLoaded()
        lock.lock()
        let snapshot = ordered
        lock.unlock()
        return snapshot.filter { $0.course == "side" && !banned.contains($0.id) && $0.parsedIngredients.count >= 2 }
    }

    private func loadAll() -> [Recipe] {
        guard let db else { return [] }
        let sql = """
        SELECT id, name, source, source_id, description, yield_text, page, chapter, section, url, course,
               ingredients_json, steps_json, tags_json, extras_json, parsed_ingredients_json, allergens_json
        FROM recipes
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var recipes: [Recipe] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let recipe = decodeRow(stmt) { recipes.append(recipe) }
        }
        return recipes
    }

    private func decodeRow(_ stmt: OpaquePointer?) -> Recipe? {
        guard let id = string(stmt, 0), let name = string(stmt, 1) else { return nil }
        let stepsRaw = jsonArray(string(stmt, 12))
        var steps: [RecipeStep] = []
        for (i, item) in stepsRaw.enumerated() {
            if let obj = item as? [String: Any] {
                steps.append(
                    RecipeStep(
                        stepNumber: i + 1,
                        instruction: (obj["text"] as? String) ?? (obj["instruction"] as? String) ?? "",
                        ingredients: (obj["ingredients"] as? [String]) ?? []
                    )
                )
            } else if let text = item as? String {
                steps.append(RecipeStep(stepNumber: i + 1, instruction: text))
            }
        }
        let parsed = decodeParsed(string(stmt, 15))
        let extras = decodeExtras(string(stmt, 14))
        return Recipe(
            id: id,
            name: name,
            source: string(stmt, 2) ?? "",
            sourceID: string(stmt, 3) ?? "",
            ingredients: jsonStringArray(string(stmt, 11)),
            steps: steps,
            description: string(stmt, 4) ?? "",
            yieldText: string(stmt, 5) ?? "",
            page: intOrNil(stmt, 6),
            chapter: string(stmt, 7) ?? "",
            section: string(stmt, 8) ?? "",
            tags: jsonStringArray(string(stmt, 13)),
            url: string(stmt, 9) ?? "",
            extras: extras,
            parsedIngredients: parsed,
            allergens: jsonStringArray(string(stmt, 16)),
            course: string(stmt, 10) ?? "other"
        )
    }

    private func decodeParsed(_ raw: String?) -> [ParsedIngredient] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ParsedIngredient].self, from: data)) ?? []
    }

    private func decodeExtras(_ raw: String?) -> [String: AnyCodable] {
        guard let raw, let data = raw.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: AnyCodable].self, from: data)) ?? [:]
    }

    private func jsonStringArray(_ raw: String?) -> [String] {
        jsonArray(raw).compactMap { $0 as? String }
    }

    private func jsonArray(_ raw: String?) -> [Any] {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return [] }
        return obj
    }

    private func string(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: c)
    }

    private func intOrNil(_ stmt: OpaquePointer?, _ idx: Int32) -> Int? {
        if sqlite3_column_type(stmt, idx) == SQLITE_NULL { return nil }
        return Int(sqlite3_column_int(stmt, idx))
    }
}
