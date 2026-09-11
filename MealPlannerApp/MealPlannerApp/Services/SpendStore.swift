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

    static func upsertTransactions(
        _ remote: [TellerClient.TransactionDTO],
        accountName: String,
        in context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<SpendTransactionEntity>())
        let byRemote = Dictionary(uniqueKeysWithValues: existing.map { ($0.remoteID, $0) })
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        for dto in remote {
            let posted = formatter.date(from: dto.date) ?? Date()
            let merchant = dto.merchantName
            let category = SpendCategory.infer(from: merchant, tellerCategory: dto.details?.category)
            if let row = byRemote[dto.id] {
                row.merchant = merchant
                row.amount = -abs(dto.amountValue) // Teller amounts are typically positive; treat as outflow
                if dto.type?.lowercased() == "deposit" || category == .income {
                    row.amount = abs(dto.amountValue)
                }
                row.postedAt = posted
                row.tellerCategory = dto.details?.category ?? ""
                row.accountName = accountName
                if row.categoryRaw == SpendCategory.other.rawValue {
                    row.category = category
                }
            } else {
                var amount = -abs(dto.amountValue)
                if dto.type?.lowercased() == "deposit" || category == .income {
                    amount = abs(dto.amountValue)
                }
                let row = SpendTransactionEntity(
                    remoteID: dto.id,
                    accountName: accountName,
                    merchant: merchant,
                    amount: amount,
                    postedAt: posted,
                    category: category,
                    tellerCategory: dto.details?.category ?? ""
                )
                context.insert(row)
            }
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
