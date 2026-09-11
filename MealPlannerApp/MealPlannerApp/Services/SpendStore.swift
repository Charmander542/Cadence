import Foundation
import SwiftData

@MainActor
enum SpendStore {
    static func seedDemoIfNeeded(in context: ModelContext) {
        guard !SpendPreferences.hasDemoSeed else { return }
        var descriptor = FetchDescriptor<SpendTransactionEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.isEmpty == false {
            SpendPreferences.hasDemoSeed = true
            return
        }

        let cal = Calendar.current
        let samples: [(String, Double, Int, SpendCategory)] = [
            ("Whole Foods Market", -86.42, 0, .groceries),
            ("Blue Bottle Coffee", -6.75, 1, .dining),
            ("Shell Gas", -54.10, 2, .transport),
            ("Apple Services", -16.99, 3, .subscriptions),
            ("Patagonia Nano Puff", -229.00, 5, .shopping),
            ("Payroll Deposit", 2400.00, 4, .income),
        ]

        for (merchant, amount, daysAgo, category) in samples {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let tx = SpendTransactionEntity(
                remoteID: "demo-\(merchant)-\(daysAgo)",
                accountName: "Checking ••1234",
                merchant: merchant,
                amount: amount,
                postedAt: day,
                category: category,
                tellerCategory: category.title
            )
            context.insert(tx)
        }

        let jacket = SpendTrackedItemEntity(
            title: "Patagonia Nano Puff",
            purchasePrice: 229,
            purchasedAt: cal.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            useMode: .tapToLog,
            category: .shopping,
            linkedTransactionRemoteID: "demo-Patagonia Nano Puff-5"
        )
        jacket.useCount = 3
        jacket.lastUsedAt = cal.date(byAdding: .day, value: -1, to: Date())
        context.insert(jacket)

        let coffee = SpendTrackedItemEntity(
            title: "AeroPress",
            purchasePrice: 39.95,
            purchasedAt: cal.date(byAdding: .day, value: -40, to: Date()) ?? Date(),
            useMode: .dailyAmortize,
            category: .home
        )
        context.insert(coffee)

        try? context.save()
        SpendPreferences.hasDemoSeed = true
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
        try context.save()
        _ = try await syncEnrollment(enrollment, in: context)
        return enrollment
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
        in context: ModelContext
    ) async throws -> Int {
        guard let secret = KeychainStore.loadPlaidSecret(), !secret.isEmpty else {
            throw PlaidClient.PlaidError.missingCredentials
        }
        guard let accessToken = KeychainStore.plaidAccessToken(itemID: enrollment.enrollmentID),
              !accessToken.isEmpty else {
            throw PlaidClient.PlaidError.missingCredentials
        }

        let client = PlaidClient()
        let accounts = try await client.fetchAccounts(
            clientID: SpendPreferences.clientID,
            secret: secret,
            environment: SpendPreferences.environment,
            accessToken: accessToken
        )
        let accountNames = Dictionary(uniqueKeysWithValues: accounts.accounts.map { ($0.account_id, $0.displayName) })

        let cursor = enrollment.syncCursor.isEmpty
            ? KeychainStore.plaidSyncCursor(itemID: enrollment.enrollmentID)
            : enrollment.syncCursor

        let result = try await client.syncAllTransactions(
            clientID: SpendPreferences.clientID,
            secret: secret,
            environment: SpendPreferences.environment,
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

    static func syncAllEnrollments(in context: ModelContext) async throws -> Int {
        let enrollments = try context.fetch(FetchDescriptor<SpendEnrollmentEntity>())
        var total = 0
        for enrollment in enrollments {
            total += try await syncEnrollment(enrollment, in: context)
        }
        return total
    }

    static func upsertTransactions(
        _ remote: [PlaidClient.TransactionDTO],
        accountNames: [String: String],
        in context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<SpendTransactionEntity>())
        let byRemote = Dictionary(uniqueKeysWithValues: existing.map { ($0.remoteID, $0) })
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        for dto in remote {
            if dto.pending == true { continue }
            let posted = formatter.date(from: dto.date) ?? Date()
            let merchant = dto.merchantName
            let category = SpendCategory.infer(from: merchant, tellerCategory: dto.categoryLabel)
            // Plaid: positive = money out. Cadence UI: negative = money out.
            let amount = -dto.amount
            let accountName = accountNames[dto.account_id ?? ""] ?? enrollmentFallbackAccountName(dto.account_id)

            if let row = byRemote[dto.id] {
                row.merchant = merchant
                row.amount = amount
                row.postedAt = posted
                row.tellerCategory = dto.categoryLabel ?? ""
                row.accountName = accountName
                if row.categoryRaw == SpendCategory.other.rawValue {
                    row.category = category
                }
            } else {
                let row = SpendTransactionEntity(
                    remoteID: dto.id,
                    accountName: accountName,
                    merchant: merchant,
                    amount: amount,
                    postedAt: posted,
                    category: category,
                    tellerCategory: dto.categoryLabel ?? ""
                )
                context.insert(row)
            }
        }
        try context.save()
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
            title: transaction.merchant,
            purchasePrice: abs(transaction.amount),
            purchasedAt: transaction.postedAt,
            useMode: useMode,
            category: transaction.category,
            linkedTransactionRemoteID: transaction.remoteID
        )
        context.insert(item)
        try? context.save()
        return item
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
        try? context.save()
    }

    @discardableResult
    static func addManualTrackedItem(
        title: String,
        price: Double,
        mode: SpendUseMode,
        category: SpendCategory,
        in context: ModelContext
    ) -> SpendTrackedItemEntity {
        let item = SpendTrackedItemEntity(
            title: title,
            purchasePrice: price,
            useMode: mode,
            category: category
        )
        context.insert(item)
        try? context.save()
        return item
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
