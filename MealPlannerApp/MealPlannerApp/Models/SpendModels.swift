import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum SpendCategory: String, CaseIterable, Identifiable, Codable {
    case groceries
    case dining
    case transport
    case shopping
    case health
    case home
    case subscriptions
    case entertainment
    case income
    case transfer
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groceries: return "Groceries"
        case .dining: return "Dining"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .health: return "Health"
        case .home: return "Home"
        case .subscriptions: return "Subscriptions"
        case .entertainment: return "Entertainment"
        case .income: return "Income"
        case .transfer: return "Transfer"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .groceries: return "cart"
        case .dining: return "fork.knife"
        case .transport: return "car"
        case .shopping: return "bag"
        case .health: return "heart"
        case .home: return "house"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .entertainment: return "film"
        case .income: return "arrow.down.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .other: return "ellipsis.circle"
        }
    }

    static func infer(from merchant: String, tellerCategory: String?) -> SpendCategory {
        let hay = "\(merchant) \(tellerCategory ?? "")".lowercased()
        if hay.contains("salary") || hay.contains("payroll") || hay.contains("deposit") { return .income }
        if hay.contains("transfer") || hay.contains("venmo") || hay.contains("zelle") { return .transfer }
        if hay.contains("uber") || hay.contains("lyft") || hay.contains("gas") || hay.contains("shell") { return .transport }
        if hay.contains("netflix") || hay.contains("spotify") || hay.contains("apple.com/bill") { return .subscriptions }
        if hay.contains("whole foods") || hay.contains("trader joe") || hay.contains("kroger") || hay.contains("grocery") { return .groceries }
        if hay.contains("restaurant") || hay.contains("cafe") || hay.contains("coffee") || hay.contains("starbucks") { return .dining }
        if hay.contains("amazon") || hay.contains("target") || hay.contains("walmart") { return .shopping }
        if hay.contains("pharmacy") || hay.contains("cvs") || hay.contains("gym") { return .health }
        if hay.contains("rent") || hay.contains("utility") || hay.contains("electric") { return .home }
        if hay.contains("movie") || hay.contains("ticket") { return .entertainment }
        return .other
    }
}

/// How cost-per-use is computed for a tracked item.
enum SpendUseMode: String, CaseIterable, Identifiable, Codable {
    /// User taps “Log use”; cost = purchasePrice / useCount.
    case tapToLog
    /// Cost declines each calendar day since purchase (or since tracking started).
    case dailyAmortize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tapToLog: return "Tap to log"
        case .dailyAmortize: return "Daily use"
        }
    }

    var detail: String {
        switch self {
        case .tapToLog: return "Each tap counts one use. Cost per use drops as you log."
        case .dailyAmortize: return "Assumes one use per day from the purchase date."
        }
    }
}

// MARK: - SwiftData

@Model
final class SpendEnrollmentEntity {
    var id: UUID = UUID()
    /// Opaque Plaid Item access-token Keychain account (never log raw tokens).
    var accessTokenKeychainAccount: String = ""
    var institutionName: String = ""
    /// Plaid `item_id`.
    var enrollmentID: String = ""
    var connectedAt: Date = Date()
    var lastSyncedAt: Date?
    var isSandbox: Bool = true
    /// `/transactions/sync` cursor for this Item.
    var syncCursor: String = ""

    init(
        accessTokenKeychainAccount: String,
        institutionName: String,
        enrollmentID: String,
        isSandbox: Bool = true
    ) {
        self.accessTokenKeychainAccount = accessTokenKeychainAccount
        self.institutionName = institutionName
        self.enrollmentID = enrollmentID
        self.isSandbox = isSandbox
        connectedAt = Date()
    }
}

@Model
final class SpendTransactionEntity {
    var id: UUID = UUID()
    /// Stable Plaid `transaction_id` when synced; local UUID string for manual rows.
    var remoteID: String = ""
    var accountName: String = ""
    var merchant: String = ""
    var amount: Double = 0
    /// Negative = money out (typical purchase).
    var postedAt: Date = Date()
    var categoryRaw: String = SpendCategory.other.rawValue
    var tellerCategory: String = ""
    var notes: String = ""
    var isTracked: Bool = false
    var isHidden: Bool = false

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        remoteID: String = UUID().uuidString,
        accountName: String = "",
        merchant: String,
        amount: Double,
        postedAt: Date = Date(),
        category: SpendCategory = .other,
        tellerCategory: String = ""
    ) {
        self.remoteID = remoteID
        self.accountName = accountName
        self.merchant = merchant
        self.amount = amount
        self.postedAt = postedAt
        categoryRaw = category.rawValue
        self.tellerCategory = tellerCategory
    }
}

@Model
final class SpendTrackedItemEntity {
    var id: UUID = UUID()
    var title: String = ""
    var purchasePrice: Double = 0
    var purchasedAt: Date = Date()
    var useModeRaw: String = SpendUseMode.tapToLog.rawValue
    var useCount: Int = 0
    var lastUsedAt: Date?
    var notes: String = ""
    var linkedTransactionRemoteID: String = ""
    var categoryRaw: String = SpendCategory.shopping.rawValue
    var createdAt: Date = Date()

    var useMode: SpendUseMode {
        get { SpendUseMode(rawValue: useModeRaw) ?? .tapToLog }
        set { useModeRaw = newValue.rawValue }
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .shopping }
        set { categoryRaw = newValue.rawValue }
    }

    /// Effective uses for cost math.
    var effectiveUseCount: Int {
        switch useMode {
        case .tapToLog:
            return max(useCount, 0)
        case .dailyAmortize:
            let start = Calendar.current.startOfDay(for: purchasedAt)
            let today = Calendar.current.startOfDay(for: Date())
            let days = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
            return max(days + 1, 1)
        }
    }

    /// Purchase price divided by effective uses. Nil until at least one use (tap mode).
    var costPerUse: Double? {
        let uses = effectiveUseCount
        guard purchasePrice > 0 else { return nil }
        switch useMode {
        case .tapToLog:
            guard uses > 0 else { return nil }
            return purchasePrice / Double(uses)
        case .dailyAmortize:
            return purchasePrice / Double(uses)
        }
    }

    init(
        title: String,
        purchasePrice: Double,
        purchasedAt: Date = Date(),
        useMode: SpendUseMode = .tapToLog,
        category: SpendCategory = .shopping,
        linkedTransactionRemoteID: String = ""
    ) {
        self.title = title
        self.purchasePrice = purchasePrice
        self.purchasedAt = purchasedAt
        useModeRaw = useMode.rawValue
        categoryRaw = category.rawValue
        self.linkedTransactionRemoteID = linkedTransactionRemoteID
        createdAt = Date()
    }
}

@Model
final class SpendUseLogEntity {
    var id: UUID = UUID()
    var itemID: UUID = UUID()
    var usedAt: Date = Date()
    var note: String = ""

    init(itemID: UUID, usedAt: Date = Date(), note: String = "") {
        self.itemID = itemID
        self.usedAt = usedAt
        self.note = note
    }
}
