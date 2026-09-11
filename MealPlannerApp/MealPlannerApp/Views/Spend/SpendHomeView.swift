import SwiftUI
import SwiftData

/// Spend home — Starling/Monzo-inspired: summary + chips + purchase list + cost-per-use trackers.
/// Mobbin refs: Starling Spending, Monzo category trends, KOHO expense rows, Orbit subscription detail.
struct SpendHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}

    @Query(sort: \SpendTransactionEntity.postedAt, order: .reverse)
    private var transactions: [SpendTransactionEntity]
    @Query(sort: \SpendTrackedItemEntity.createdAt, order: .reverse)
    private var tracked: [SpendTrackedItemEntity]
    @Query private var enrollments: [SpendEnrollmentEntity]

    @State private var segment: Segment = .purchases
    @State private var categoryFilter: SpendCategory?
    @State private var selectedTransaction: SpendTransactionEntity?
    @State private var selectedItem: SpendTrackedItemEntity?
    @State private var showAddTracked = false
    @State private var showConnectInfo = false
    @State private var isSyncing = false
    @State private var syncMessage: String?

    private enum Segment: String, CaseIterable, Identifiable {
        case purchases, trackers
        var id: String { rawValue }
        var title: String {
            switch self {
            case .purchases: return "Purchases"
            case .trackers: return "Cost / use"
            }
        }
    }

    private var visibleTransactions: [SpendTransactionEntity] {
        transactions.filter { tx in
            !tx.isHidden
                && (categoryFilter == nil || tx.category == categoryFilter)
        }
    }

    private var monthSpend: Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return visibleTransactions
            .filter { $0.postedAt >= start && $0.amount < 0 }
            .map(\.amount)
            .reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "Spend", onMenu: onOpenDrawer)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    summaryCard
                        .padding(.horizontal, Theme.Space.lg)

                    connectBanner
                        .padding(.horizontal, Theme.Space.lg)

                    Picker("Section", selection: $segment) {
                        ForEach(Segment.allCases) { seg in
                            Text(seg.title.uppercased()).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Space.lg)
                    .accessibilityLabel("Spend section")

                    if segment == .purchases {
                        categoryChips
                            .padding(.horizontal, Theme.Space.lg)
                        purchasesList
                    } else {
                        trackersList
                    }
                }
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, 110)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .onAppear {
            SpendPreferences.ingestLocalSecretsIfNeeded()
            SpendStore.seedDemoIfNeeded(in: modelContext)
        }
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .addSpendItem else { return }
            showAddTracked = true
            appModel.requestedFABAction = nil
        }
        .sheet(item: $selectedTransaction) { tx in
            SpendTransactionSheet(transaction: tx)
        }
        .sheet(item: $selectedItem) { item in
            SpendItemDetailView(item: item)
        }
        .sheet(isPresented: $showAddTracked) {
            AddTrackedItemSheet()
        }
        .sheet(isPresented: $showConnectInfo) {
            NavigationStack {
                SpendSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showConnectInfo = false }
                                .foregroundStyle(Theme.cta)
                        }
                    }
            }
        }
    }

    private var summaryCard: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("THIS MONTH")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                HStack(alignment: .firstTextBaseline) {
                    Text(SpendFormat.money(abs(monthSpend)))
                        .font(Theme.display(.largeTitle))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(visibleTransactions.filter { $0.amount < 0 }.count) buys")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                if let syncMessage {
                    Text(syncMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This month spent \(SpendFormat.money(abs(monthSpend)))")
    }

    @ViewBuilder
    private var connectBanner: some View {
        let connected = !enrollments.isEmpty
        Theme.Card {
            HStack(spacing: Theme.Space.md) {
                Theme.IconWell(
                    systemImage: connected ? "link.circle.fill" : "building.columns",
                    tint: connected ? Theme.cta : Theme.accent,
                    size: 36
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(connected ? "Bank linked" : "Link purchases")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(connected
                         ? (enrollments.first?.institutionName ?? "Plaid connection")
                         : "Connect with Plaid to import and categorize buys.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if connected {
                    Button {
                        Task { await syncNow() }
                    } label: {
                        Text(isSyncing ? "…" : "SYNC")
                            .font(.caption.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.cta)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyncing)
                    .accessibilityHint("Syncs purchases from linked banks")
                }
                Button {
                    showConnectInfo = true
                } label: {
                    Text(connected ? "MANAGE" : "CONNECT")
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.cta)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Spend and Plaid settings")
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                chip(title: "All", selected: categoryFilter == nil) {
                    categoryFilter = nil
                }
                ForEach(SpendCategory.allCases.filter { $0 != .income && $0 != .transfer }) { cat in
                    chip(title: cat.title, selected: categoryFilter == cat) {
                        categoryFilter = cat
                    }
                }
            }
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.4)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.accent : Theme.sunken)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var purchasesList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("PURCHASES")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.lg)
                .accessibilityAddTraits(.isHeader)

            if visibleTransactions.isEmpty {
                Theme.EmptyState(
                    systemImage: "creditcard",
                    title: "No purchases yet",
                    message: "Connect Plaid or add a tracked item to get started.",
                    cta: "CONNECT PLAID",
                    ctaHint: "Opens Spend settings"
                ) {
                    showConnectInfo = true
                }
                .padding(.horizontal, Theme.Space.lg)
            } else {
                Theme.Card {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleTransactions.prefix(40)), id: \.id) { tx in
                            Button {
                                selectedTransaction = tx
                            } label: {
                                transactionRow(tx)
                            }
                            .buttonStyle(.plain)
                            if tx.id != visibleTransactions.prefix(40).last?.id {
                                Divider().overlay(Theme.gridDivider)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
            }
        }
    }

    private func transactionRow(_ tx: SpendTransactionEntity) -> some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: tx.category.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(shortDate(tx.postedAt)) · \(tx.category.title)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Text(SpendFormat.money(tx.amount))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tx.amount >= 0 ? Theme.cta : Theme.ink)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, Theme.Space.sm + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tx.merchant), \(SpendFormat.money(tx.amount)), \(tx.category.title)")
        .accessibilityHint("Opens purchase details")
    }

    private var trackersList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text("COST PER USE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    showAddTracked = true
                } label: {
                    Text("ADD ITEM")
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.cta)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Tracks a new purchase for cost-per-use")
            }
            .padding(.horizontal, Theme.Space.lg)

            if tracked.isEmpty {
                Theme.EmptyState(
                    systemImage: "gauge.with.dots.needle.33percent",
                    title: "Nothing tracked",
                    message: "Track a purchase to see what each use is worth — tap to log, or amortize daily.",
                    cta: "ADD ITEM",
                    ctaHint: "Opens new tracked item form"
                ) {
                    showAddTracked = true
                }
                .padding(.horizontal, Theme.Space.lg)
            } else {
                ForEach(tracked, id: \.id) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        trackerCard(item)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Space.lg)
                }
            }
        }
    }

    private func trackerCard(_ item: SpendTrackedItemEntity) -> some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(item.useMode.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("COST / USE")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                        Text(item.costPerUse.map(SpendFormat.money) ?? "—")
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.cta)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SpendFormat.money(item.purchasePrice))
                            .font(.subheadline.weight(.semibold))
                        Text("\(item.effectiveUseCount) uses")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                if item.useMode == .tapToLog {
                    Theme.PrimaryButton(title: "LOG USE", systemImage: "plus.circle.fill") {
                        SpendStore.logUse(item, in: modelContext)
                    }
                    .accessibilityHint("Adds one use and updates cost per use")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.title), cost per use \(item.costPerUse.map(SpendFormat.money) ?? "none yet")")
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    @MainActor
    private func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let count = try await SpendStore.syncAllEnrollments(in: modelContext)
            syncMessage = count == 0 ? "Up to date" : "Synced \(count) updates"
        } catch {
            syncMessage = error.localizedDescription
        }
    }
}

// MARK: - Transaction sheet

private struct SpendTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var transaction: SpendTransactionEntity
    @State private var trackMode: SpendUseMode = .tapToLog

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Merchant", value: transaction.merchant)
                    LabeledContent("Amount", value: SpendFormat.money(transaction.amount))
                    LabeledContent("Date", value: transaction.postedAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Account", value: transaction.accountName.isEmpty ? "—" : transaction.accountName)
                } header: {
                    Text("PURCHASE")
                }

                Section {
                    Picker("Category", selection: Binding(
                        get: { transaction.category },
                        set: { transaction.category = $0; try? modelContext.save() }
                    )) {
                        ForEach(SpendCategory.allCases) { cat in
                            Label(cat.title, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                } header: {
                    Text("CHARACTERIZE")
                }

                if transaction.amount < 0 {
                    Section {
                        Picker("Use mode", selection: $trackMode) {
                            ForEach(SpendUseMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        Button {
                            _ = SpendStore.trackPurchase(from: transaction, useMode: trackMode, in: modelContext)
                            dismiss()
                        } label: {
                            Label(transaction.isTracked ? "ALREADY TRACKED" : "TRACK COST / USE", systemImage: "gauge.with.dots.needle.33percent")
                        }
                        .disabled(transaction.isTracked)
                        .foregroundStyle(Theme.cta)
                    } header: {
                        Text("WORTH IT?")
                    } footer: {
                        Text(trackMode.detail)
                    }
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

// MARK: - Add tracked item

private struct AddTrackedItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var priceText = ""
    @State private var mode: SpendUseMode = .tapToLog
    @State private var category: SpendCategory = .shopping

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $title)
                    TextField("Purchase price", text: $priceText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(SpendCategory.allCases.filter { $0 != .income && $0 != .transfer }) { cat in
                            Text(cat.title).tag(cat)
                        }
                    }
                    Picker("Use mode", selection: $mode) {
                        ForEach(SpendUseMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                } footer: {
                    Text(mode.detail)
                }
            }
            .navigationTitle("Track item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.cta)
                        .disabled(!canSave)
                }
            }
            .settingsFormChrome()
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(priceText) ?? 0) > 0
    }

    private func save() {
        guard let price = Double(priceText), price > 0 else { return }
        _ = SpendStore.addManualTrackedItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            price: price,
            mode: mode,
            category: category,
            in: modelContext
        )
        dismiss()
    }
}
