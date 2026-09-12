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
        case .entertainment: return "theatermasks"
        case .income: return "arrow.down.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .other: return "ellipsis.circle"
        }
    }

    /// Rocket Money–style pastel accents for pie segments + category wells.
    var tint: Color {
        switch self {
        case .groceries: return Color(red: 0.45, green: 0.78, blue: 0.62)      // mint
        case .dining: return Color(red: 0.72, green: 0.62, blue: 0.92)         // lavender
        case .transport: return Color(red: 0.35, green: 0.78, blue: 0.86)      // cyan
        case .shopping: return Color(red: 0.95, green: 0.82, blue: 0.42)       // soft yellow
        case .health: return Color(red: 0.95, green: 0.55, blue: 0.62)         // coral
        case .home: return Color(red: 0.45, green: 0.62, blue: 0.95)           // periwinkle
        case .subscriptions: return Color(red: 0.62, green: 0.48, blue: 0.92)  // violet
        case .entertainment: return Color(red: 0.98, green: 0.62, blue: 0.38)  // peach
        case .income: return Color(red: 0.35, green: 0.78, blue: 0.52)         // green
        case .transfer: return Color(red: 0.55, green: 0.58, blue: 0.65)       // slate
        case .other: return Color(red: 0.62, green: 0.64, blue: 0.70)          // gray
        }
    }

    /// Categories that appear in spending breakdown / budgets (excludes money-in & transfers).
    static var spendingCases: [SpendCategory] {
        allCases.filter { $0 != .income && $0 != .transfer }
    }

    /// Map Plaid `personal_finance_category` (+ merchant keywords) → Cadence category.
    /// Prefers PFC primary/detailed labels from the bank feed, then falls back to merchant text.
    static func infer(from merchant: String, tellerCategory: String?) -> SpendCategory {
        let pfc = (tellerCategory ?? "").uppercased()

        // --- Plaid PFC detailed (most specific) ---
        if pfc.contains("GROCER") || pfc.contains("SUPERMARKET") { return .groceries }
        if pfc.contains("RESTAURANT") || pfc.contains("FAST_FOOD")
            || pfc.contains("COFFEE") || pfc.contains("BEER")
            || pfc.contains("WINE") || pfc.contains("BAR") { return .dining }
        if pfc.contains("GAS") || pfc.contains("PARKING")
            || pfc.contains("TAXIS") || pfc.contains("RIDE")
            || pfc.contains("PUBLIC_TRANSIT") || pfc.contains("TOLLS") { return .transport }
        if pfc.contains("GYM") || pfc.contains("PHARMACY")
            || pfc.contains("DENTAL") || pfc.contains("EYECARE")
            || pfc.contains("PRIMARY_CARE") || pfc.contains("HOSPITAL") { return .health }
        if pfc.contains("STREAMING") || pfc.contains("VIDEO_GAMES")
            || pfc.contains("MUSIC") || pfc.contains("CASINO")
            || pfc.contains("TV_AND_MOVIES") || pfc.contains("SPORTING") { return .entertainment }
        if pfc.contains("RENT") || pfc.contains("UTILITIES")
            || pfc.contains("INTERNET") || pfc.contains("TELEPHONE")
            || pfc.contains("HOME_IMPROVEMENT") || pfc.contains("FURNITURE") { return .home }
        if pfc.contains("LOAN") || pfc.contains("CREDIT_CARD_PAYMENT") { return .transfer }
        if pfc.contains("SUBSCRIPTION") || pfc.contains("TELECOMMUNICATION") { return .subscriptions }

        // --- Plaid PFC primary ---
        if pfc.hasPrefix("INCOME") { return .income }
        if pfc.contains("TRANSFER") { return .transfer }
        if pfc.hasPrefix("FOOD_AND_DRINK") {
            return (pfc.contains("GROCER") || pfc.contains("SUPERMARKET")) ? .groceries : .dining
        }
        if pfc.hasPrefix("TRANSPORTATION") || pfc.hasPrefix("TRAVEL") { return .transport }
        if pfc.hasPrefix("GENERAL_MERCHANDISE") { return .shopping }
        if pfc.hasPrefix("ENTERTAINMENT") { return .entertainment }
        if pfc.hasPrefix("PERSONAL_CARE") || pfc.hasPrefix("MEDICAL")
            || pfc.hasPrefix("HEALTHCARE") { return .health }
        if pfc.hasPrefix("RENT_AND_UTILITIES") || pfc.hasPrefix("HOME_IMPROVEMENT") { return .home }
        if pfc.hasPrefix("GENERAL_SERVICES") { return .other }
        if pfc.hasPrefix("BANK_FEES") || pfc.hasPrefix("LOAN_PAYMENTS") { return .transfer }
        if pfc.hasPrefix("GOVERNMENT") { return .other }

        // Legacy Plaid `category` strings + merchant keywords.
        let hay = "\(merchant) \(tellerCategory ?? "")".lowercased()
        if hay.contains("salary") || hay.contains("payroll") || hay.contains("direct dep") { return .income }
        if hay.contains("transfer") || hay.contains("venmo") || hay.contains("zelle")
            || hay.contains("cash app") { return .transfer }
        if hay.contains("grocery") || hay.contains("whole foods") || hay.contains("trader joe")
            || hay.contains("kroger") || hay.contains("safeway") || hay.contains("costco") { return .groceries }
        if hay.contains("restaurant") || hay.contains("cafe") || hay.contains("coffee")
            || hay.contains("starbucks") || hay.contains("doordash") || hay.contains("ubereats") { return .dining }
        if hay.contains("uber") || hay.contains("lyft") || hay.contains("shell")
            || hay.contains("chevron") || hay.contains("exxon") || hay.contains("parking") { return .transport }
        if hay.contains("netflix") || hay.contains("spotify") || hay.contains("hulu")
            || hay.contains("disney+") || hay.contains("apple.com/bill")
            || hay.contains("subscription") { return .subscriptions }
        if hay.contains("amazon") || hay.contains("target") || hay.contains("walmart")
            || hay.contains("ikea") || hay.contains("best buy") { return .shopping }
        if hay.contains("pharmacy") || hay.contains("cvs") || hay.contains("walgreens")
            || hay.contains("gym") || hay.contains("doctor") { return .health }
        if hay.contains("rent") || hay.contains("utility") || hay.contains("electric")
            || hay.contains("pg&e") || hay.contains("home depot") || hay.contains("lowe") { return .home }
        if hay.contains("movie") || hay.contains("ticket") || hay.contains("amc")
            || hay.contains("steam") || hay.contains("concert") { return .entertainment }
        return .other
    }
}

/// Snapshot used by pie chart + budget rows.
struct SpendCategorySlice: Identifiable {
    var id: String {
        if let userCategoryID { return "user-\(userCategoryID.uuidString)" }
        return category.rawValue + (subcategoryID?.uuidString ?? "") + title
    }
    let category: SpendCategory
    let subcategoryID: UUID?
    let userCategoryID: UUID?
    let title: String
    let systemImage: String
    let color: Color
    let amount: Double
    let budget: Double?
    let transactionCount: Int

    func percent(of total: Double) -> Double {
        total > 0 ? amount / total : 0
    }

    var budgetProgress: Double? {
        guard let budget, budget > 0 else { return nil }
        return min(amount / budget, 1.5)
    }

    var remaining: Double? {
        guard let budget else { return nil }
        return budget - amount
    }

    var isOverBudget: Bool {
        guard let budget, budget > 0 else { return false }
        return amount > budget
    }

    init(
        category: SpendCategory,
        subcategoryID: UUID?,
        userCategoryID: UUID? = nil,
        title: String,
        systemImage: String,
        color: Color,
        amount: Double,
        budget: Double?,
        transactionCount: Int
    ) {
        self.category = category
        self.subcategoryID = subcategoryID
        self.userCategoryID = userCategoryID
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.amount = amount
        self.budget = budget
        self.transactionCount = transactionCount
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
        case .dailyAmortize: return "Spreads the price across each day since purchase. Shows average cost per day."
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
    /// Optional custom subcategory (e.g. Kitchen under Home).
    var subcategoryID: UUID?
    var tellerCategory: String = ""
    var notes: String = ""
    var isTracked: Bool = false
    var isHidden: Bool = false
    /// User-created top-level category. When set, this overrides `category` for grouping.
    var userCategoryID: UUID?

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Manual note shown as Description on the purchase. Used as the cost/use title when set.
    var trimmedDescription: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cost/use tracker name: description if the user wrote one, otherwise merchant.
    var costUseTitle: String {
        trimmedDescription.isEmpty ? merchant : trimmedDescription
    }

    func assign(builtIn category: SpendCategory) {
        userCategoryID = nil
        if self.category != category { subcategoryID = nil }
        self.category = category
    }

    func assign(userCategoryID: UUID) {
        self.userCategoryID = userCategoryID
        subcategoryID = nil
        category = .other
    }

    init(
        remoteID: String = UUID().uuidString,
        accountName: String = "",
        merchant: String,
        amount: Double,
        postedAt: Date = Date(),
        category: SpendCategory = .other,
        subcategoryID: UUID? = nil,
        tellerCategory: String = ""
    ) {
        self.remoteID = remoteID
        self.accountName = accountName
        self.merchant = merchant
        self.amount = amount
        self.postedAt = postedAt
        categoryRaw = category.rawValue
        self.subcategoryID = subcategoryID
        self.tellerCategory = tellerCategory
    }
}

/// User-defined subcategory nested under a parent `SpendCategory` (Kitchen, Utilities, etc.).
@Model
final class SpendSubcategoryEntity {
    var id: UUID = UUID()
    var name: String = ""
    var parentCategoryRaw: String = SpendCategory.home.rawValue
    var systemImage: String = "tag"
    /// Optional override hex (RRGGBB). Empty = inherit parent tint.
    var colorHex: String = ""
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    var parentCategory: SpendCategory {
        get { SpendCategory(rawValue: parentCategoryRaw) ?? .other }
        set { parentCategoryRaw = newValue.rawValue }
    }

    var tint: Color {
        if let custom = SpendColor.color(hex: colorHex) { return custom }
        return parentCategory.tint
    }

    init(
        name: String,
        parent: SpendCategory,
        systemImage: String = "tag",
        colorHex: String = "",
        sortOrder: Int = 0
    ) {
        self.name = name
        parentCategoryRaw = parent.rawValue
        self.systemImage = systemImage
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        createdAt = Date()
    }
}

/// User-created top-level spending category (Pets, Kids, etc.).
@Model
final class SpendUserCategoryEntity {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = "tag"
    var colorHex: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    var tint: Color {
        SpendColor.color(hex: colorHex) ?? Color(red: 0.62, green: 0.64, blue: 0.70)
    }

    init(name: String, systemImage: String = "tag", colorHex: String = "", sortOrder: Int = 0) {
        self.name = name
        self.systemImage = systemImage
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        createdAt = Date()
    }
}

/// Monthly budget for a parent category, subcategory, or custom user category.
@Model
final class SpendBudgetEntity {
    var id: UUID = UUID()
    /// Parent category raw value. Always set (even for subcategory budgets — for grouping).
    var categoryRaw: String = SpendCategory.other.rawValue
    /// When set, this budget applies to the subcategory instead of the whole category.
    var subcategoryID: UUID?
    /// When set, this budget applies to a custom user category (pie slice).
    var userCategoryID: UUID?
    var monthlyAmount: Double = 0
    var updatedAt: Date = Date()

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        category: SpendCategory,
        subcategoryID: UUID? = nil,
        userCategoryID: UUID? = nil,
        monthlyAmount: Double
    ) {
        categoryRaw = category.rawValue
        self.subcategoryID = subcategoryID
        self.userCategoryID = userCategoryID
        self.monthlyAmount = monthlyAmount
        updatedAt = Date()
    }
}

enum SpendColor {
    static func color(hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    static let palette: [(name: String, hex: String)] = [
        ("Mint", "73C79E"),
        ("Lavender", "B89EEB"),
        ("Cyan", "59C7DB"),
        ("Butter", "F2D16B"),
        ("Coral", "F28C9E"),
        ("Periwinkle", "739EFF"),
        ("Violet", "9E7AEB"),
        ("Peach", "FA9E61"),
        ("Fig", "9B6B9E"),
        ("Slate", "8C94A3"),
    ]
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

/// User rule: always map this merchant/store to a category (built-in or custom).
@Model
final class SpendMerchantRuleEntity {
    var id: UUID = UUID()
    /// Lowercased / collapsed merchant key for matching.
    var merchantKey: String = ""
    /// Display name shown in UI (original merchant spelling).
    var merchantDisplay: String = ""
    var categoryRaw: String = SpendCategory.other.rawValue
    var userCategoryID: UUID?
    var updatedAt: Date = Date()

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        merchantKey: String,
        merchantDisplay: String,
        category: SpendCategory = .other,
        userCategoryID: UUID? = nil
    ) {
        self.merchantKey = merchantKey
        self.merchantDisplay = merchantDisplay
        categoryRaw = category.rawValue
        self.userCategoryID = userCategoryID
        updatedAt = Date()
    }
}
