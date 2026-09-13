import Foundation
import SwiftData

@MainActor
enum SpendStore {
    static func seedDemoIfNeeded(in context: ModelContext) {
        seedDefaultSubcategoriesIfNeeded(in: context)
        seedDefaultBudgetsIfNeeded(in: context)
        removeDemoTrackedItemsIfNeeded(in: context)

        guard !SpendPreferences.hasDemoSeed else { return }
        var descriptor = FetchDescriptor<SpendTransactionEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.isEmpty == false {
            SpendPreferences.hasDemoSeed = true
            return
        }

        let cal = Calendar.current
        let kitchen = ensureSubcategory(named: "Kitchen", parent: .home, systemImage: "fork.knife.circle", in: context)
        let utilities = ensureSubcategory(named: "Utilities", parent: .home, systemImage: "bolt.fill", in: context)
        _ = ensureSubcategory(named: "Coffee", parent: .dining, systemImage: "cup.and.saucer.fill", in: context)

        let samples: [(String, Double, Int, SpendCategory, UUID?)] = [
            ("Whole Foods Market", -86.42, 0, .groceries, nil),
            ("Trader Joe's", -54.18, 6, .groceries, nil),
            ("Blue Bottle Coffee", -6.75, 1, .dining, nil),
            ("Mokafe", -28.40, 8, .dining, nil),
            ("Shell Gas", -54.10, 2, .transport, nil),
            ("Uber", -18.25, 9, .transport, nil),
            ("Apple Services", -16.99, 3, .subscriptions, nil),
            ("Spotify", -11.99, 10, .subscriptions, nil),
            ("Patagonia Nano Puff", -229.00, 5, .shopping, nil),
            ("Target", -67.52, 7, .shopping, nil),
            ("AMC Theatres", -32.00, 4, .entertainment, nil),
            ("IKEA kitchen gear", -124.00, 3, .home, kitchen.id),
            ("PG&E", -98.40, 8, .home, utilities.id),
            ("CVS Pharmacy", -22.15, 9, .health, nil),
            ("Payroll Deposit", 2400.00, 4, .income, nil),
        ]

        for (merchant, amount, daysAgo, category, subID) in samples {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let tx = SpendTransactionEntity(
                remoteID: "demo-\(merchant)-\(daysAgo)",
                accountName: "Checking ••1234",
                merchant: merchant,
                amount: amount,
                postedAt: day,
                category: category,
                subcategoryID: subID,
                tellerCategory: category.title
            )
            context.insert(tx)
        }

        setBudget(450, for: .groceries, subcategoryID: nil, in: context)
        setBudget(200, for: .dining, subcategoryID: nil, in: context)
        setBudget(180, for: .transport, subcategoryID: nil, in: context)
        setBudget(300, for: .shopping, subcategoryID: nil, in: context)
        setBudget(250, for: .home, subcategoryID: nil, in: context)
        setBudget(150, for: .home, subcategoryID: kitchen.id, in: context)
        setBudget(120, for: .entertainment, subcategoryID: nil, in: context)
        setBudget(80, for: .subscriptions, subcategoryID: nil, in: context)

        try? context.save()
        SpendPreferences.hasDemoSeed = true
    }

    /// Strip shipped sample cost-per-use trackers (Patagonia / AeroPress) if still present.
    static func removeDemoTrackedItemsIfNeeded(in context: ModelContext) {
        let flag = "spend_demo_trackers_cleared_v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let demoTitles: Set<String> = ["Patagonia Nano Puff", "AeroPress"]
        let existing = (try? context.fetch(FetchDescriptor<SpendTrackedItemEntity>())) ?? []
        for item in existing where demoTitles.contains(item.title) {
            context.delete(item)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flag)
    }

    static func seedDefaultSubcategoriesIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<SpendSubcategoryEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.isEmpty == false { return }
        _ = ensureSubcategory(named: "Kitchen", parent: .home, systemImage: "fork.knife.circle", in: context)
        _ = ensureSubcategory(named: "Utilities", parent: .home, systemImage: "bolt.fill", in: context)
        _ = ensureSubcategory(named: "Coffee", parent: .dining, systemImage: "cup.and.saucer.fill", in: context)
        try? context.save()
    }

    static func seedDefaultBudgetsIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<SpendBudgetEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.isEmpty == false { return }
        // Leave empty so first-run users set their own; demo seed fills budgets when seeding txs.
    }

    @discardableResult
    static func ensureSubcategory(
        named name: String,
        parent: SpendCategory,
        systemImage: String,
        colorHex: String = "",
        in context: ModelContext
    ) -> SpendSubcategoryEntity {
        let existing = (try? context.fetch(FetchDescriptor<SpendSubcategoryEntity>())) ?? []
        if let found = existing.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.parentCategory == parent
        }) {
            return found
        }
        let row = SpendSubcategoryEntity(
            name: name,
            parent: parent,
            systemImage: systemImage,
            colorHex: colorHex,
            sortOrder: existing.count
        )
        context.insert(row)
        return row
    }

    @discardableResult
    static func addUserCategory(
        name: String,
        systemImage: String = "tag",
        colorHex: String = "",
        in context: ModelContext
    ) -> SpendUserCategoryEntity {
        let existing = (try? context.fetch(FetchDescriptor<SpendUserCategoryEntity>())) ?? []
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = SpendUserCategoryEntity(
            name: trimmed.isEmpty ? "Untitled" : trimmed,
            systemImage: systemImage,
            colorHex: colorHex,
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(row)
        try? context.save()
        return row
    }

    static func deleteUserCategory(_ category: SpendUserCategoryEntity, in context: ModelContext) {
        let txs = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
        for tx in txs where tx.userCategoryID == category.id {
            tx.userCategoryID = nil
        }
        context.delete(category)
        try? context.save()
    }

    static func addSubcategory(
        name: String,
        parent: SpendCategory,
        systemImage: String = "tag",
        colorHex: String = "",
        in context: ModelContext
    ) -> SpendSubcategoryEntity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = ensureSubcategory(
            named: trimmed.isEmpty ? "Untitled" : trimmed,
            parent: parent,
            systemImage: systemImage,
            colorHex: colorHex,
            in: context
        )
        try? context.save()
        return row
    }

    static func deleteSubcategory(_ sub: SpendSubcategoryEntity, in context: ModelContext) {
        let txs = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
        for tx in txs where tx.subcategoryID == sub.id {
            tx.subcategoryID = nil
        }
        let budgets = (try? context.fetch(FetchDescriptor<SpendBudgetEntity>())) ?? []
        for budget in budgets where budget.subcategoryID == sub.id {
            context.delete(budget)
        }
        context.delete(sub)
        try? context.save()
    }

    static func setBudget(
        _ amount: Double,
        for category: SpendCategory,
        subcategoryID: UUID?,
        in context: ModelContext
    ) {
        let budgets = (try? context.fetch(FetchDescriptor<SpendBudgetEntity>())) ?? []
        let match = budgets.first { budget in
            budget.category == category && budget.subcategoryID == subcategoryID
        }
        if amount <= 0 {
            if let match { context.delete(match) }
            try? context.save()
            return
        }
        if let match {
            match.monthlyAmount = amount
            match.updatedAt = Date()
        } else {
            context.insert(SpendBudgetEntity(category: category, subcategoryID: subcategoryID, monthlyAmount: amount))
        }
        try? context.save()
    }

    static func budgetAmount(
        for category: SpendCategory,
        subcategoryID: UUID?,
        budgets: [SpendBudgetEntity]
    ) -> Double? {
        budgets.first { $0.category == category && $0.subcategoryID == subcategoryID }?.monthlyAmount
    }

    /// Outflows in `[start, end)`.
    static func monthBounds(containing date: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: comps) ?? date
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date
        return (start, end)
    }

    static func spendingTransactions(
        _ transactions: [SpendTransactionEntity],
        in range: (start: Date, end: Date),
        category: SpendCategory? = nil,
        subcategoryID: UUID? = nil,
        userCategoryID: UUID? = nil
    ) -> [SpendTransactionEntity] {
        transactions.filter { tx in
            !tx.isHidden
                && tx.amount < 0
                && tx.postedAt >= range.start
                && tx.postedAt < range.end
                && tx.category != .income
                && tx.category != .transfer
                && (userCategoryID == nil || tx.userCategoryID == userCategoryID)
                && (userCategoryID != nil || category == nil || (tx.userCategoryID == nil && tx.category == category))
                && (subcategoryID == nil || tx.subcategoryID == subcategoryID)
        }
    }

    static func categorySlices(
        transactions: [SpendTransactionEntity],
        budgets: [SpendBudgetEntity],
        userCategories: [SpendUserCategoryEntity] = [],
        in range: (start: Date, end: Date)
    ) -> [SpendCategorySlice] {
        let txs = spendingTransactions(transactions, in: range)
        var totals: [SpendCategory: (amount: Double, count: Int)] = [:]
        var userTotals: [UUID: (amount: Double, count: Int)] = [:]
        for tx in txs {
            if let uid = tx.userCategoryID {
                let entry = userTotals[uid] ?? (0, 0)
                userTotals[uid] = (entry.amount + abs(tx.amount), entry.count + 1)
            } else {
                let entry = totals[tx.category] ?? (0, 0)
                totals[tx.category] = (entry.amount + abs(tx.amount), entry.count + 1)
            }
        }
        let builtIn = SpendCategory.spendingCases.compactMap { cat -> SpendCategorySlice? in
            guard let entry = totals[cat], entry.amount > 0 else { return nil }
            return SpendCategorySlice(
                category: cat,
                subcategoryID: nil,
                title: cat.title,
                systemImage: cat.systemImage,
                color: cat.tint,
                amount: entry.amount,
                budget: budgetAmount(for: cat, subcategoryID: nil, budgets: budgets),
                transactionCount: entry.count
            )
        }
        let custom = userCategories.compactMap { cat -> SpendCategorySlice? in
            guard let entry = userTotals[cat.id], entry.amount > 0 else { return nil }
            return SpendCategorySlice(
                category: .other,
                subcategoryID: nil,
                userCategoryID: cat.id,
                title: cat.name,
                systemImage: cat.systemImage,
                color: cat.tint,
                amount: entry.amount,
                budget: nil,
                transactionCount: entry.count
            )
        }
        return (builtIn + custom).sorted { $0.amount > $1.amount }
    }

    static func subcategorySlices(
        for category: SpendCategory,
        transactions: [SpendTransactionEntity],
        subcategories: [SpendSubcategoryEntity],
        budgets: [SpendBudgetEntity],
        in range: (start: Date, end: Date)
    ) -> [SpendCategorySlice] {
        let txs = spendingTransactions(transactions, in: range, category: category)
        let kids = subcategories.filter { $0.parentCategory == category }.sorted { $0.sortOrder < $1.sortOrder }
        var bySub: [UUID?: (amount: Double, count: Int)] = [:]
        for tx in txs {
            let key = tx.subcategoryID
            let entry = bySub[key] ?? (0, 0)
            bySub[key] = (entry.amount + abs(tx.amount), entry.count + 1)
        }
        var slices: [SpendCategorySlice] = []
        for sub in kids {
            let entry = bySub[sub.id] ?? (0, 0)
            guard entry.amount > 0 || budgetAmount(for: category, subcategoryID: sub.id, budgets: budgets) != nil else { continue }
            slices.append(
                SpendCategorySlice(
                    category: category,
                    subcategoryID: sub.id,
                    title: sub.name,
                    systemImage: sub.systemImage,
                    color: sub.tint,
                    amount: entry.amount,
                    budget: budgetAmount(for: category, subcategoryID: sub.id, budgets: budgets),
                    transactionCount: entry.count
                )
            )
        }
        if let uncategorized = bySub[nil], uncategorized.amount > 0 {
            slices.append(
                SpendCategorySlice(
                    category: category,
                    subcategoryID: nil,
                    title: "General",
                    systemImage: category.systemImage,
                    color: category.tint.opacity(0.75),
                    amount: uncategorized.amount,
                    budget: nil,
                    transactionCount: uncategorized.count
                )
            )
        }
        return slices.sorted { $0.amount > $1.amount }
    }

    static func totalBudgeted(budgets: [SpendBudgetEntity]) -> Double {
        budgets.filter { $0.subcategoryID == nil }.map(\.monthlyAmount).reduce(0, +)
    }

    /// Persist a newly linked Plaid Item, then sync transactions.
    @discardableResult
    static func enrollPlaidItem(
        itemID: String,
        institutionName: String,
        isSandbox: Bool,
        in context: ModelContext
    ) async throws -> SpendEnrollmentEntity {
        let existing = try context.fetch(FetchDescriptor<SpendEnrollmentEntity>())
        let enrollment: SpendEnrollmentEntity
        if let found = existing.first(where: { $0.enrollmentID == itemID }) {
            found.institutionName = institutionName
            found.isSandbox = isSandbox
            found.accessTokenKeychainAccount = "plaid_access_\(itemID)"
            enrollment = found
        } else {
            enrollment = SpendEnrollmentEntity(
                accessTokenKeychainAccount: "plaid_access_\(itemID)",
                institutionName: institutionName,
                enrollmentID: itemID,
                isSandbox: isSandbox
            )
            context.insert(enrollment)
        }
        KeychainStore.upsertPlaidItemRecord(
            itemID: itemID,
            institutionName: institutionName,
            isSandbox: isSandbox
        )
        try context.save()
        _ = try await syncEnrollment(enrollment, in: context)
        return enrollment
    }

    /// Rebuild SwiftData enrollments from Keychain after a store wipe / reinstall that left tokens behind.
    /// Returns how many enrollments were restored.
    @MainActor
    @discardableResult
    static func restorePlaidEnrollmentsIfNeeded(in context: ModelContext) async -> Int {
        KeychainStore.migratePlaidKeychainAccessibilityIfNeeded()

        let existing: [SpendEnrollmentEntity]
        do {
            existing = try context.fetch(FetchDescriptor<SpendEnrollmentEntity>())
        } catch {
            return 0
        }
        let known = Set(existing.map(\.enrollmentID))
        let registry = Dictionary(
            uniqueKeysWithValues: KeychainStore.loadPlaidItemRegistry().map { ($0.itemID, $0) }
        )
        let orphanIDs = KeychainStore.listPlaidAccessTokenItemIDs().filter { !known.contains($0) }
        guard !orphanIDs.isEmpty else {
            // Keep registry in sync for already-linked Items (first run after this feature).
            for enrollment in existing {
                KeychainStore.upsertPlaidItemRecord(
                    itemID: enrollment.enrollmentID,
                    institutionName: enrollment.institutionName,
                    isSandbox: enrollment.isSandbox
                )
            }
            return 0
        }

        var restored = 0
        for itemID in orphanIDs {
            let meta = registry[itemID]
            let name = meta?.institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let institution = (name?.isEmpty == false) ? name! : "Linked bank"
            let isSandbox = meta?.isSandbox ?? (SpendPreferences.environment == .sandbox)
            let enrollment = SpendEnrollmentEntity(
                accessTokenKeychainAccount: "plaid_access_\(itemID)",
                institutionName: institution,
                enrollmentID: itemID,
                isSandbox: isSandbox
            )
            // Local SwiftData was wiped; any Keychain sync cursor is stale and would
            // make /transactions/sync return only empty deltas (no historical txs).
            enrollment.syncCursor = ""
            KeychainStore.savePlaidSyncCursor("", itemID: itemID)
            context.insert(enrollment)
            KeychainStore.upsertPlaidItemRecord(
                itemID: itemID,
                institutionName: institution,
                isSandbox: isSandbox
            )
            restored += 1
        }
        try? context.save()

        // Refresh names + transactions in the background when credentials exist.
        if SpendPreferences.isConfigured {
            for itemID in orphanIDs {
                guard let enrollment = (try? context.fetch(FetchDescriptor<SpendEnrollmentEntity>()))?
                    .first(where: { $0.enrollmentID == itemID })
                else { continue }
                if let refreshed = try? await refreshInstitutionName(for: enrollment) {
                    enrollment.institutionName = refreshed
                    KeychainStore.upsertPlaidItemRecord(
                        itemID: itemID,
                        institutionName: refreshed,
                        isSandbox: enrollment.isSandbox
                    )
                }
                _ = try? await syncEnrollment(enrollment, in: context, forceFullResync: true)
            }
            try? context.save()
        }
        return restored
    }

    private static func refreshInstitutionName(for enrollment: SpendEnrollmentEntity) async throws -> String? {
        guard let secret = KeychainStore.loadPlaidSecret(), !secret.isEmpty,
              let accessToken = KeychainStore.plaidAccessToken(itemID: enrollment.enrollmentID),
              !accessToken.isEmpty
        else { return nil }
        let client = PlaidClient()
        let env: SpendPreferences.PlaidEnvironment = enrollment.isSandbox ? .sandbox : .production
        let accounts = try await client.fetchAccounts(
            clientID: SpendPreferences.clientID,
            secret: secret,
            environment: env,
            accessToken: accessToken
        )
        if let institutionID = accounts.item?.institution_id {
            let name = try? await client.fetchInstitutionName(
                clientID: SpendPreferences.clientID,
                secret: secret,
                environment: env,
                institutionID: institutionID
            )
            if let name, !name.isEmpty { return name }
        }
        return accounts.accounts.first?.displayName
    }

    /// Exchange a public token (Link or sandbox helper) and sync.
    static func completePublicToken(
        _ publicToken: String,
        institutionNameHint: String?,
        in context: ModelContext
    ) async throws -> SpendEnrollmentEntity {
        guard let secret = KeychainStore.loadPlaidSecret(), !secret.isEmpty else {
            throw PlaidClient.PlaidError.missingCredentials
        }
        let client = PlaidClient()
        let exchanged = try await client.exchangePublicToken(
            clientID: SpendPreferences.clientID,
            secret: secret,
            environment: SpendPreferences.environment,
            publicToken: publicToken
        )
        KeychainStore.savePlaidAccessToken(exchanged.access_token, itemID: exchanged.item_id)

        var institution = institutionNameHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if institution.isEmpty {
            let accounts = try await client.fetchAccounts(
                clientID: SpendPreferences.clientID,
                secret: secret,
                environment: SpendPreferences.environment,
                accessToken: exchanged.access_token
            )
            if let institutionID = accounts.item?.institution_id {
                institution = (try? await client.fetchInstitutionName(
                    clientID: SpendPreferences.clientID,
                    secret: secret,
                    environment: SpendPreferences.environment,
                    institutionID: institutionID
                )) ?? institutionID
            }
            if institution.isEmpty {
                institution = accounts.accounts.first?.displayName ?? "Linked account"
            }
        }

        return try await enrollPlaidItem(
            itemID: exchanged.item_id,
            institutionName: institution,
            isSandbox: SpendPreferences.environment == .sandbox,
            in: context
        )
    }

    @discardableResult
    static func syncEnrollment(
        _ enrollment: SpendEnrollmentEntity,
        in context: ModelContext,
        forceFullResync: Bool = false
    ) async throws -> Int {
        guard let secret = KeychainStore.loadPlaidSecret(), !secret.isEmpty else {
            throw PlaidClient.PlaidError.missingCredentials
        }
        guard let accessToken = KeychainStore.plaidAccessToken(itemID: enrollment.enrollmentID),
              !accessToken.isEmpty else {
            throw PlaidClient.PlaidError.missingCredentials
        }

        let env: SpendPreferences.PlaidEnvironment = enrollment.isSandbox ? .sandbox : .production
        let client = PlaidClient()
        let accounts = try await client.fetchAccounts(
            clientID: SpendPreferences.clientID,
            secret: secret,
            environment: env,
            accessToken: accessToken
        )
        let accountNames = Dictionary(uniqueKeysWithValues: accounts.accounts.map { ($0.account_id, $0.displayName) })

        // User SYNC (and store-wipe heal) always clears the cursor so Plaid returns the full
        // available history as "added", not just deltas since the last cursor.
        var cursor = enrollment.syncCursor.isEmpty
            ? KeychainStore.plaidSyncCursor(itemID: enrollment.enrollmentID)
            : enrollment.syncCursor
        if forceFullResync || (!cursor.isEmpty && !hasLocalPlaidTransactions(in: context)) {
            cursor = ""
            enrollment.syncCursor = ""
            KeychainStore.savePlaidSyncCursor("", itemID: enrollment.enrollmentID)
            // Ask the institution for a fresh extract before re-reading history.
            try? await client.refreshTransactions(
                clientID: SpendPreferences.clientID,
                secret: secret,
                environment: env,
                accessToken: accessToken
            )
            // Give Plaid a beat to finish the refresh before the empty-cursor pull.
            try? await Task.sleep(for: .milliseconds(800))
        }

        let result = try await client.syncAllTransactions(
            clientID: SpendPreferences.clientID,
            secret: secret,
            environment: env,
            accessToken: accessToken,
            cursor: cursor
        )

        try upsertTransactions(
            result.added + result.modified,
            accountNames: accountNames,
            in: context
        )
        try removeTransactions(remoteIDs: result.removedIDs, in: context)

        enrollment.syncCursor = result.nextCursor
        enrollment.lastSyncedAt = Date()
        KeychainStore.savePlaidSyncCursor(result.nextCursor, itemID: enrollment.enrollmentID)
        try context.save()
        return result.added.count + result.modified.count
    }

    /// True when SwiftData already holds at least one non-demo Plaid/Teller transaction.
    private static func hasLocalPlaidTransactions(in context: ModelContext) -> Bool {
        let rows = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
        return rows.contains { !$0.remoteID.hasPrefix("demo-") }
    }

    /// Count of non-demo transactions currently stored (for SYNC status copy).
    static func localPlaidTransactionCount(in context: ModelContext) -> Int {
        let rows = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
        return rows.filter { !$0.remoteID.hasPrefix("demo-") }.count
    }

    static func syncAllEnrollments(
        in context: ModelContext,
        forceFullResync: Bool = false
    ) async throws -> Int {
        let enrollments = try context.fetch(FetchDescriptor<SpendEnrollmentEntity>())
        var total = 0
        for enrollment in enrollments {
            total += try await syncEnrollment(enrollment, in: context, forceFullResync: forceFullResync)
        }
        return total
    }

    static func upsertTransactions(
        _ remote: [PlaidClient.TransactionDTO],
        accountNames: [String: String],
        in context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<SpendTransactionEntity>())
        var byRemote: [String: SpendTransactionEntity] = [:]
        byRemote.reserveCapacity(existing.count)
        for row in existing {
            byRemote[row.remoteID] = row
        }
        let ruleMap = merchantRuleMap(in: context)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        for dto in remote {
            // Include pending — otherwise early syncs look almost empty.
            let posted = formatter.date(from: dto.date) ?? Date()
            let merchant = dto.merchantName
            let plaidLabel = dto.categoryLabel ?? ""
            let resolved = resolveCategory(
                merchant: merchant,
                plaidLabel: plaidLabel,
                rules: ruleMap
            )
            // Plaid: positive = money out. Cadence UI: negative = money out.
            let amount = -dto.amount
            let accountName = accountNames[dto.account_id ?? ""] ?? enrollmentFallbackAccountName(dto.account_id)

            if let row = byRemote[dto.id] {
                row.merchant = merchant
                row.amount = amount
                row.postedAt = posted
                row.tellerCategory = plaidLabel
                row.accountName = accountName
                applyResolvedCategory(resolved, to: row, overwriteManual: ruleMap[normalizeMerchantKey(merchant)] != nil)
            } else {
                let row = SpendTransactionEntity(
                    remoteID: dto.id,
                    accountName: accountName,
                    merchant: merchant,
                    amount: amount,
                    postedAt: posted,
                    category: resolved.category,
                    tellerCategory: plaidLabel
                )
                if let uid = resolved.userCategoryID {
                    row.assign(userCategoryID: uid)
                }
                context.insert(row)
            }
        }
        try context.save()
    }

    // MARK: - Merchant category rules

    /// Collapse merchant strings so "STARBUCKS #123" and "Starbucks Store" can share a rule.
    static func normalizeMerchantKey(_ merchant: String) -> String {
        var key = merchant.lowercased()
        key = key.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // Drop store numbers / trailing codes.
        key = key.replacingOccurrences(of: #"[#*]?\s*\d{2,}.*$"#, with: "", options: .regularExpression)
        key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return key
    }

    private static func merchantRuleMap(in context: ModelContext) -> [String: SpendMerchantRuleEntity] {
        let rules = (try? context.fetch(FetchDescriptor<SpendMerchantRuleEntity>())) ?? []
        var map: [String: SpendMerchantRuleEntity] = [:]
        for rule in rules where !rule.merchantKey.isEmpty {
            map[rule.merchantKey] = rule
        }
        return map
    }

    static func merchantRule(for merchant: String, in context: ModelContext) -> SpendMerchantRuleEntity? {
        let key = normalizeMerchantKey(merchant)
        guard !key.isEmpty else { return nil }
        return merchantRuleMap(in: context)[key]
    }

    private struct ResolvedCategory {
        var category: SpendCategory
        var userCategoryID: UUID?
    }

    private static func resolveCategory(
        merchant: String,
        plaidLabel: String,
        rules: [String: SpendMerchantRuleEntity]
    ) -> ResolvedCategory {
        let key = normalizeMerchantKey(merchant)
        if let rule = rules[key] {
            if let uid = rule.userCategoryID {
                return ResolvedCategory(category: .other, userCategoryID: uid)
            }
            return ResolvedCategory(category: rule.category, userCategoryID: nil)
        }
        return ResolvedCategory(
            category: SpendCategory.infer(from: merchant, tellerCategory: plaidLabel.isEmpty ? nil : plaidLabel),
            userCategoryID: nil
        )
    }

    private static func applyResolvedCategory(
        _ resolved: ResolvedCategory,
        to row: SpendTransactionEntity,
        overwriteManual: Bool
    ) {
        if overwriteManual {
            if let uid = resolved.userCategoryID {
                row.assign(userCategoryID: uid)
            } else {
                row.assign(builtIn: resolved.category)
            }
            return
        }
        // Auto-fill only when still uncategorized / default Other.
        guard row.userCategoryID == nil, row.category == .other else { return }
        if let uid = resolved.userCategoryID {
            row.assign(userCategoryID: uid)
        } else if resolved.category != .other {
            row.assign(builtIn: resolved.category)
        }
    }

    /// Pin a store to a category for all current + future purchases.
    @discardableResult
    static func setMerchantRule(
        merchant: String,
        category: SpendCategory?,
        userCategoryID: UUID?,
        applyToExisting: Bool = true,
        in context: ModelContext
    ) -> SpendMerchantRuleEntity? {
        let key = normalizeMerchantKey(merchant)
        guard !key.isEmpty else { return nil }
        let display = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let rules = (try? context.fetch(FetchDescriptor<SpendMerchantRuleEntity>())) ?? []
        let rule: SpendMerchantRuleEntity
        if let existing = rules.first(where: { $0.merchantKey == key }) {
            rule = existing
        } else {
            rule = SpendMerchantRuleEntity(
                merchantKey: key,
                merchantDisplay: display.isEmpty ? key : display
            )
            context.insert(rule)
        }
        rule.merchantDisplay = display.isEmpty ? rule.merchantDisplay : display
        rule.updatedAt = Date()
        if let uid = userCategoryID {
            rule.userCategoryID = uid
            rule.category = .other
        } else if let category {
            rule.userCategoryID = nil
            rule.category = category
        }
        if applyToExisting {
            applyMerchantRule(rule, in: context)
        }
        try? context.save()
        return rule
    }

    static func clearMerchantRule(for merchant: String, in context: ModelContext) {
        let key = normalizeMerchantKey(merchant)
        guard !key.isEmpty else { return }
        let rules = (try? context.fetch(FetchDescriptor<SpendMerchantRuleEntity>())) ?? []
        for rule in rules where rule.merchantKey == key {
            context.delete(rule)
        }
        try? context.save()
    }

    static func applyMerchantRule(_ rule: SpendMerchantRuleEntity, in context: ModelContext) {
        let txs = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
        for tx in txs where normalizeMerchantKey(tx.merchant) == rule.merchantKey {
            if let uid = rule.userCategoryID {
                tx.assign(userCategoryID: uid)
            } else {
                tx.assign(builtIn: rule.category)
            }
        }
    }

    /// Re-run Plaid/PFC auto-categorization for purchases still on Other (no merchant rule).
    static func refreshAutoCategories(in context: ModelContext) {
        let ruleMap = merchantRuleMap(in: context)
        let txs = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
        for tx in txs {
            let key = normalizeMerchantKey(tx.merchant)
            if let rule = ruleMap[key] {
                if let uid = rule.userCategoryID {
                    tx.assign(userCategoryID: uid)
                } else {
                    tx.assign(builtIn: rule.category)
                }
                continue
            }
            guard tx.userCategoryID == nil, tx.category == .other else { continue }
            let inferred = SpendCategory.infer(
                from: tx.merchant,
                tellerCategory: tx.tellerCategory.isEmpty ? nil : tx.tellerCategory
            )
            if inferred != .other {
                tx.assign(builtIn: inferred)
            }
        }
        try? context.save()
    }

    private static func enrollmentFallbackAccountName(_ accountID: String?) -> String {
        guard let accountID, !accountID.isEmpty else { return "Account" }
        return "Account \(accountID.suffix(4))"
    }

    static func removeTransactions(remoteIDs: [String], in context: ModelContext) throws {
        guard !remoteIDs.isEmpty else { return }
        let existing = try context.fetch(FetchDescriptor<SpendTransactionEntity>())
        let removeSet = Set(remoteIDs)
        for row in existing where removeSet.contains(row.remoteID) {
            context.delete(row)
        }
        try context.save()
    }

    static func trackPurchase(
        from transaction: SpendTransactionEntity,
        useMode: SpendUseMode,
        in context: ModelContext
    ) -> SpendTrackedItemEntity {
        transaction.isTracked = true
        let item = SpendTrackedItemEntity(
            title: transaction.costUseTitle,
            purchasePrice: abs(transaction.amount),
            purchasedAt: transaction.postedAt,
            useMode: useMode,
            category: transaction.category,
            linkedTransactionRemoteID: transaction.remoteID
        )
        context.insert(item)
        CadenceCloudStore.save(context, label: "trackPurchase")
        return item
    }

    /// Keep a linked cost/use title in sync when the purchase description changes.
    static func syncTrackedTitle(from transaction: SpendTransactionEntity, in context: ModelContext) {
        guard transaction.isTracked, !transaction.remoteID.isEmpty else { return }
        let remoteID = transaction.remoteID
        let title = transaction.costUseTitle
        guard let items = try? context.fetch(FetchDescriptor<SpendTrackedItemEntity>()) else { return }
        for item in items where item.linkedTransactionRemoteID == remoteID {
            item.title = title
        }
        CadenceCloudStore.save(context, label: "syncTrackedTitle")
    }

    static func logUse(
        _ item: SpendTrackedItemEntity,
        note: String = "",
        in context: ModelContext
    ) {
        guard item.useMode == .tapToLog else { return }
        item.useCount += 1
        item.lastUsedAt = Date()
        context.insert(SpendUseLogEntity(itemID: item.id, note: note))
        CadenceCloudStore.save(context, label: "logUse")
    }

    @discardableResult
    static func addManualTrackedItem(
        title: String,
        price: Double,
        purchasedAt: Date = Date(),
        mode: SpendUseMode,
        category: SpendCategory,
        in context: ModelContext
    ) -> SpendTrackedItemEntity {
        let item = SpendTrackedItemEntity(
            title: title,
            purchasePrice: price,
            purchasedAt: purchasedAt,
            useMode: mode,
            category: category
        )
        context.insert(item)
        CadenceCloudStore.save(context, label: "addManualTrackedItem")
        return item
    }

    static func trackedItem(
        linkedTo transaction: SpendTransactionEntity,
        in context: ModelContext
    ) -> SpendTrackedItemEntity? {
        guard transaction.isTracked, !transaction.remoteID.isEmpty else { return nil }
        let remoteID = transaction.remoteID
        let items = (try? context.fetch(FetchDescriptor<SpendTrackedItemEntity>())) ?? []
        return items.first { $0.linkedTransactionRemoteID == remoteID }
    }

    static func updateTrackedItem(
        _ item: SpendTrackedItemEntity,
        title: String? = nil,
        purchasePrice: Double? = nil,
        purchasedAt: Date? = nil,
        useMode: SpendUseMode? = nil,
        category: SpendCategory? = nil,
        notes: String? = nil,
        in context: ModelContext
    ) {
        if let title {
            item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let purchasePrice {
            item.purchasePrice = abs(purchasePrice)
        }
        if let purchasedAt {
            item.purchasedAt = purchasedAt
        }
        if let useMode {
            item.useMode = useMode
        }
        if let category {
            item.category = category
        }
        if let notes {
            item.notes = notes
        }
        CadenceCloudStore.save(context, label: "updateTrackedItem")
    }

    static func deleteTrackedItem(_ item: SpendTrackedItemEntity, in context: ModelContext) {
        let itemID = item.id
        let remoteID = item.linkedTransactionRemoteID
        let logs = (try? context.fetch(FetchDescriptor<SpendUseLogEntity>())) ?? []
        for log in logs where log.itemID == itemID {
            context.delete(log)
        }
        if !remoteID.isEmpty {
            let txs = (try? context.fetch(FetchDescriptor<SpendTransactionEntity>())) ?? []
            for tx in txs where tx.remoteID == remoteID {
                tx.isTracked = false
            }
        }
        context.delete(item)
        CadenceCloudStore.save(context, label: "deleteTrackedItem")
    }

    static func deleteUseLog(_ log: SpendUseLogEntity, item: SpendTrackedItemEntity, in context: ModelContext) {
        guard log.itemID == item.id else { return }
        context.delete(log)
        item.useCount = max(0, item.useCount - 1)
        let remaining = ((try? context.fetch(FetchDescriptor<SpendUseLogEntity>())) ?? [])
            .filter { $0.itemID == item.id }
            .sorted { $0.usedAt > $1.usedAt }
        item.lastUsedAt = remaining.first?.usedAt
        CadenceCloudStore.save(context, label: "deleteUseLog")
    }

    /// Manual cash / card purchase (not from bank sync). Amount is money out (stored negative).
    @discardableResult
    static func addManualPurchase(
        merchant: String,
        amount: Double,
        postedAt: Date = Date(),
        category: SpendCategory = .other,
        userCategoryID: UUID? = nil,
        subcategoryID: UUID? = nil,
        notes: String = "",
        in context: ModelContext
    ) -> SpendTransactionEntity {
        let spend = -abs(amount)
        let tx = SpendTransactionEntity(
            remoteID: "manual-\(UUID().uuidString)",
            accountName: "Manual",
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: spend,
            postedAt: postedAt,
            category: category,
            subcategoryID: subcategoryID,
            tellerCategory: "Manual"
        )
        if let userCategoryID {
            tx.assign(userCategoryID: userCategoryID)
        }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tx.notes = trimmed
        }
        context.insert(tx)
        try? context.save()
        return tx
    }

    static func disconnectEnrollment(_ enrollment: SpendEnrollmentEntity, in context: ModelContext) {
        KeychainStore.deletePlaidAccessToken(itemID: enrollment.enrollmentID)
        context.delete(enrollment)
        try? context.save()
    }
}

enum SpendFormat {
    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    static func money(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}
