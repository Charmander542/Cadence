import SwiftUI
import SwiftData
import Charts

/// Category drill-down — subcategory pie, budgets, and purchases (Rocket Money spending detail).
struct SpendCategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel

    let category: SpendCategory
    var userCategory: SpendUserCategoryEntity? = nil
    let month: Date

    @Query(sort: \SpendTransactionEntity.postedAt, order: .reverse)
    private var transactions: [SpendTransactionEntity]
    @Query(sort: \SpendSubcategoryEntity.sortOrder)
    private var subcategories: [SpendSubcategoryEntity]
    @Query private var budgets: [SpendBudgetEntity]
    @Query(sort: \SpendUserCategoryEntity.sortOrder)
    private var userCategories: [SpendUserCategoryEntity]

    @State private var budgetText = ""
    @State private var showAddSub = false
    @State private var selectedTransaction: SpendTransactionEntity?

    private var range: (start: Date, end: Date) {
        SpendStore.monthBounds(containing: month)
    }

    private var slices: [SpendCategorySlice] {
        SpendStore.subcategorySlices(
            for: category,
            transactions: transactions,
            subcategories: subcategories,
            budgets: budgets,
            in: range
        )
    }

    private var total: Double {
        if userCategory != nil {
            return purchases.map { abs($0.amount) }.reduce(0, +)
        }
        return slices.map(\.amount).reduce(0, +)
    }

    private var categoryBudget: Double? {
        SpendStore.budgetAmount(
            for: category,
            subcategoryID: nil,
            userCategoryID: userCategory?.id,
            budgets: budgets
        )
    }

    private var kids: [SpendSubcategoryEntity] {
        subcategories.filter { $0.parentCategory == category }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var purchases: [SpendTransactionEntity] {
        SpendStore.spendingTransactions(
            transactions,
            in: range,
            category: userCategory == nil ? category : nil,
            userCategoryID: userCategory?.id
        )
        .sorted { $0.postedAt > $1.postedAt }
    }

    private var displayTitle: String {
        userCategory?.name ?? category.title
    }

    private var displayTint: Color {
        userCategory?.tint ?? category.tint
    }

    private var displayImage: String {
        userCategory?.systemImage ?? category.systemImage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    headerCard
                        .padding(.horizontal, Theme.Space.lg)

                    if userCategory == nil, !slices.isEmpty {
                        subDonut
                            .padding(.horizontal, Theme.Space.lg)
                        subList
                    }

                    budgetEditor
                        .padding(.horizontal, Theme.Space.lg)

                    if userCategory == nil {
                        subManage
                    }
                    purchasesSection
                }
                .padding(.vertical, Theme.Space.md)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("DONE") { dismiss() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.cta)
                }
            }
            .onAppear {
                if let budget = categoryBudget {
                    budgetText = String(format: "%.0f", budget)
                }
                if appModel.requestedOpenSpendCategoryPurchase {
                    appModel.requestedOpenSpendCategoryPurchase = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        selectedTransaction = purchases.first
                    }
                }
            }
            .sheet(isPresented: $showAddSub) {
                NewSubcategorySheet(parent: category)
            }
            .sheet(item: $selectedTransaction) { tx in
                SpendCategoryTransactionEditor(
                    transaction: tx,
                    subcategories: subcategories,
                    userCategories: userCategories
                )
            }
        }
    }

    private var headerCard: some View {
        Theme.Card {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: displayImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(displayTint)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(displayTint.opacity(0.22)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS MONTH")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                    Text(SpendFormat.money(total))
                        .font(Theme.display(.title))
                        .foregroundStyle(Theme.ink)
                    if let budget = categoryBudget {
                        let left = budget - total
                        Text(left >= 0
                             ? "\(SpendFormat.money(left)) left of \(SpendFormat.money(budget))"
                             : "\(SpendFormat.money(abs(left))) over \(SpendFormat.money(budget))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(left >= 0 ? Theme.ink : Theme.danger)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var subDonut: some View {
        Theme.Card {
            ZStack {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Amount", max(slice.amount, 0.01)),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(2)
                }
                .frame(height: 180)
                .chartLegend(.hidden)

                VStack(spacing: 2) {
                    Text("SPLIT")
                        .font(.caption2.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                    Text("\(slices.count)")
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.ink)
                    Text("groups")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var subList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("SUBCATEGORIES")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.lg)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                VStack(spacing: 0) {
                    ForEach(slices) { slice in
                        HStack(spacing: Theme.Space.sm) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slice.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("\(Int((slice.percent(of: total) * 100).rounded()))%")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text(SpendFormat.money(slice.amount))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            if let rem = slice.remaining {
                                Text(rem >= 0 ? "left" : "over")
                                    .font(.caption2)
                                    .foregroundStyle(rem >= 0 ? Theme.ink : Theme.danger)
                            }
                        }
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm)
                        if slice.id != slices.last?.id {
                            Divider().overlay(Theme.gridDivider)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.lg)
        }
    }

    private var budgetEditor: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("MONTHLY BUDGET")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                HStack {
                    Text("$")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.muted)
                    TextField("0", text: $budgetText)
                        .keyboardType(.decimalPad)
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button("SAVE") {
                        let value = Double(budgetText) ?? 0
                        SpendStore.setBudget(
                            value,
                            for: category,
                            subcategoryID: nil,
                            userCategoryID: userCategory?.id,
                            in: modelContext
                        )
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.cta)
                    .accessibilityHint("Saves \(displayTitle) monthly budget")
                }
                Text("Optional. Clear and save 0 to remove.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var subManage: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text("CUSTOMIZE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    showAddSub = true
                } label: {
                    Text("+ SUBCATEGORY")
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.cta)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Adds a subcategory like Kitchen under \(category.title)")
            }
            .padding(.horizontal, Theme.Space.lg)

            if kids.isEmpty {
                Text("Add Kitchen, Utilities, or anything you care about under \(category.title).")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.Space.lg)
            } else {
                Theme.Card {
                    VStack(spacing: 0) {
                        ForEach(kids, id: \.id) { sub in
                            SubcategoryBudgetRow(category: category, subcategory: sub)
                            if sub.id != kids.last?.id {
                                Divider().overlay(Theme.gridDivider)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
            }
        }
    }

    private var purchasesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("PURCHASES")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.lg)
                .accessibilityAddTraits(.isHeader)

            if purchases.isEmpty {
                Text("No purchases in this category this month.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.Space.lg)
            } else {
                Theme.Card {
                    VStack(spacing: 0) {
                        ForEach(purchases.prefix(30), id: \.id) { tx in
                            Button {
                                selectedTransaction = tx
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(tx.merchant)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Theme.ink)
                                                .lineLimit(1)
                                            if !tx.trimmedDescription.isEmpty {
                                                Text(tx.trimmedDescription)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Theme.muted)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Text(subLabel(for: tx))
                                            .font(.caption2)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Text(SpendFormat.money(tx.amount))
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(Theme.ink)
                                }
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.sm)
                            }
                            .buttonStyle(.plain)
                            if tx.id != purchases.prefix(30).last?.id {
                                Divider().overlay(Theme.gridDivider)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
            }
        }
    }

    private func subLabel(for tx: SpendTransactionEntity) -> String {
        if let id = tx.subcategoryID,
           let name = kids.first(where: { $0.id == id })?.name {
            return name
        }
        return tx.postedAt.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct SubcategoryBudgetRow: View {
    @Environment(\.modelContext) private var modelContext
    let category: SpendCategory
    @Bindable var subcategory: SpendSubcategoryEntity
    @Query private var budgets: [SpendBudgetEntity]
    @State private var text = ""
    @State private var confirmDelete = false

    private var current: Double? {
        SpendStore.budgetAmount(for: category, subcategoryID: subcategory.id, budgets: budgets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Image(systemName: subcategory.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(subcategory.tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(subcategory.tint.opacity(0.22)))
                Text(subcategory.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(subcategory.name)")
                .accessibilityHint("Removes this subcategory. Purchases stay under \(category.title).")
            }
            HStack {
                Text("Budget $")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                TextField("optional", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.subheadline.weight(.semibold))
                Button("Save") {
                    SpendStore.setBudget(Double(text) ?? 0, for: category, subcategoryID: subcategory.id, in: modelContext)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.cta)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .onAppear {
            if let current {
                text = String(format: "%.0f", current)
            }
        }
        .confirmationDialog(
            "Delete \(subcategory.name)?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete subcategory", role: .destructive) {
                SpendStore.deleteSubcategory(subcategory, in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Purchases stay in \(category.title). This subcategory’s budget is removed.")
        }
    }
}

private struct NewSubcategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let parent: SpendCategory
    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex = ""

    private let icons = [
        "tag", "fork.knife.circle", "bolt.fill", "cup.and.saucer.fill",
        "sofa.fill", "wrench.and.screwdriver", "gift.fill", "leaf.fill",
        "gamecontroller.fill", "pawprint.fill", "book.fill", "basket.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Kitchen)", text: $name)
                    Picker("Parent", selection: .constant(parent)) {
                        Text(parent.title).tag(parent)
                    }
                    .disabled(true)
                } header: {
                    Text("Subcategory")
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { symbol in
                            Button {
                                icon = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.body)
                                    .foregroundStyle(icon == symbol ? Color.white : Theme.ink)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(icon == symbol ? parent.tint : Theme.sunken))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                        }
                    }
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            colorDot(hex: "", label: "Parent")
                            ForEach(SpendColor.palette, id: \.hex) { swatch in
                                colorDot(hex: swatch.hex, label: swatch.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = SpendStore.addSubcategory(
                            name: name,
                            parent: parent,
                            systemImage: icon,
                            colorHex: colorHex,
                            in: modelContext
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(Theme.cta)
                }
            }
            .settingsFormChrome()
        }
    }

    private func colorDot(hex: String, label: String) -> some View {
        let fill = SpendColor.color(hex: hex) ?? parent.tint
        let selected = colorHex == hex
        return Button {
            colorHex = hex
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(fill)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Theme.ink.opacity(selected ? 0.9 : 0), lineWidth: 2))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SpendCategoryTransactionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var transaction: SpendTransactionEntity
    let subcategories: [SpendSubcategoryEntity]
    var userCategories: [SpendUserCategoryEntity] = []

    private var categorySubs: [SpendSubcategoryEntity] {
        subcategories.filter { $0.parentCategory == transaction.category }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Merchant", value: transaction.merchant)
                    LabeledContent("Amount", value: SpendFormat.money(transaction.amount))
                }
                Section("Description") {
                    TextField("What was this for?", text: Binding(
                        get: { transaction.notes },
                        set: { newValue in
                            transaction.notes = newValue
                            SpendStore.syncTrackedTitle(from: transaction, in: modelContext)
                            try? modelContext.save()
                        }
                    ), axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityLabel("Description")
                    .accessibilityHint("Optional note used as the cost per use name")
                }
                Section("Category") {
                    SpendCategoryAssignmentFields(
                        transaction: transaction,
                        userCategories: userCategories,
                        subcategories: categorySubs
                    )
                }
            }
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cta)
                }
            }
            .settingsFormChrome()
        }
    }
}
