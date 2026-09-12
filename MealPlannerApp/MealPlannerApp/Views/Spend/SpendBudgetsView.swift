import SwiftUI
import SwiftData

/// Set monthly budgets per category and subcategory — Rocket Money “Add Budget” style.
struct SpendBudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [SpendBudgetEntity]
    @Query(sort: \SpendSubcategoryEntity.sortOrder)
    private var subcategories: [SpendSubcategoryEntity]
    @Query(sort: \SpendUserCategoryEntity.sortOrder)
    private var userCategories: [SpendUserCategoryEntity]
    @Query(sort: \SpendTransactionEntity.postedAt, order: .reverse)
    private var transactions: [SpendTransactionEntity]

    private var range: (start: Date, end: Date) {
        SpendStore.monthBounds()
    }

    private var monthSpend: Double {
        SpendStore.categorySlices(
            transactions: transactions,
            budgets: budgets,
            userCategories: userCategories,
            in: range
        )
            .map(\.amount).reduce(0, +)
    }

    private var totalBudget: Double {
        SpendStore.totalBudgeted(budgets: budgets)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("This month")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    HStack(alignment: .firstTextBaseline) {
                        Text(SpendFormat.money(monthSpend))
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.ink)
                        Text("spent")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text(totalBudget > 0 ? SpendFormat.money(totalBudget) : "—")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.cta)
                    }
                    Text("Set a limit for each category. Nested budgets (Kitchen, Utilities) are optional extras.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Theme.surface)
            }

            if !userCategories.isEmpty {
                Section {
                    ForEach(userCategories, id: \.id) { cat in
                        BudgetAmountRow(
                            title: cat.name,
                            tint: cat.tint,
                            systemImage: cat.systemImage,
                            amount: SpendStore.budgetAmount(
                                for: .other,
                                subcategoryID: nil,
                                userCategoryID: cat.id,
                                budgets: budgets
                            ),
                            spent: spent(userCategoryID: cat.id)
                        ) { value in
                            SpendStore.setBudget(
                                value,
                                for: .other,
                                subcategoryID: nil,
                                userCategoryID: cat.id,
                                in: modelContext
                            )
                        }
                    }
                } header: {
                    Text("Your categories")
                }
            }

            ForEach(SpendCategory.spendingCases) { cat in
                Section {
                    BudgetAmountRow(
                        title: cat.title,
                        tint: cat.tint,
                        systemImage: cat.systemImage,
                        amount: SpendStore.budgetAmount(for: cat, subcategoryID: nil, budgets: budgets),
                        spent: spent(for: cat, subcategoryID: nil)
                    ) { value in
                        SpendStore.setBudget(value, for: cat, subcategoryID: nil, in: modelContext)
                    }

                    ForEach(subcategories.filter { $0.parentCategory == cat }, id: \.id) { sub in
                        BudgetAmountRow(
                            title: "  \(sub.name)",
                            tint: sub.tint,
                            systemImage: sub.systemImage,
                            amount: SpendStore.budgetAmount(for: cat, subcategoryID: sub.id, budgets: budgets),
                            spent: spent(for: cat, subcategoryID: sub.id)
                        ) { value in
                            SpendStore.setBudget(value, for: cat, subcategoryID: sub.id, in: modelContext)
                        }
                    }
                } header: {
                    Label(cat.title, systemImage: cat.systemImage)
                        .foregroundStyle(cat.tint)
                }
            }
        }
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
    }

    private func spent(for category: SpendCategory, subcategoryID: UUID?) -> Double {
        SpendStore.spendingTransactions(
            transactions,
            in: range,
            category: category,
            subcategoryID: subcategoryID
        )
        .map { abs($0.amount) }
        .reduce(0, +)
    }

    private func spent(userCategoryID: UUID) -> Double {
        SpendStore.spendingTransactions(
            transactions,
            in: range,
            userCategoryID: userCategoryID
        )
        .map { abs($0.amount) }
        .reduce(0, +)
    }
}

private struct BudgetAmountRow: View {
    let title: String
    let tint: Color
    let systemImage: String
    let amount: Double?
    let spent: Double
    let onSave: (Double) -> Void

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.opacity(0.2)))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if spent > 0 {
                    Text("\(SpendFormat.money(spent)) spent")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            HStack {
                Text("$")
                    .foregroundStyle(Theme.muted)
                TextField("No budget", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.body.weight(.semibold))
                Button("Save") {
                    onSave(Double(text) ?? 0)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.cta)
            }
            if let amount, amount > 0 {
                let progress = min(spent / amount, 1.2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.sunken)
                        Capsule()
                            .fill(spent > amount ? Theme.danger : tint)
                            .frame(width: max(4, geo.size.width * min(progress, 1)))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.surface)
        .onAppear {
            if let amount, amount > 0 {
                text = String(format: "%.0f", amount)
            }
        }
        .onChange(of: amount) { _, value in
            if let value, value > 0 {
                text = String(format: "%.0f", value)
            } else if value == nil || value == 0 {
                text = ""
            }
        }
    }
}
