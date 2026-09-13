import SwiftUI
import SwiftData

/// Item detail — edit title/price/mode, log uses, delete tracker.
struct SpendItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: SpendTrackedItemEntity
    @Query private var allLogs: [SpendUseLogEntity]
    @State private var priceText: String = ""
    @State private var confirmDelete = false

    private var logs: [SpendUseLogEntity] {
        allLogs
            .filter { $0.itemID == item.id }
            .sorted { $0.usedAt > $1.usedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    hero
                    editCard
                    if item.useMode == .tapToLog {
                        Theme.PrimaryButton(title: "LOG USE", systemImage: "plus.circle.fill") {
                            SpendStore.logUse(item, in: modelContext)
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .accessibilityHint("Adds one use and updates cost per use")
                    }
                    history
                    deleteSection
                }
                .padding(.vertical, Theme.Space.md)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(item.title.isEmpty ? "Tracked item" : item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("DONE") {
                        persistPriceIfNeeded()
                        dismiss()
                    }
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.cta)
                }
            }
            .onAppear {
                priceText = priceText(from: item.purchasePrice)
            }
            .confirmationDialog(
                "Remove tracked item?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    SpendStore.deleteTrackedItem(item, in: modelContext)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Stops cost-per-use for this item. Purchase history stays in Spend.")
            }
        }
    }

    private var hero: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text(item.useMode == .dailyAmortize ? "AVERAGE PER DAY" : "COST TO USE IT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Text(item.costPerUse.map { item.useMode == .dailyAmortize ? "\(SpendFormat.money($0)) / day" : SpendFormat.money($0) } ?? "Log a use to begin")
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.cta)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(item.useMode == .tapToLog
                     ? "\(item.useCount) logged uses · \(SpendFormat.money(item.purchasePrice)) paid"
                     : "\(item.effectiveUseCount) days · \(SpendFormat.money(item.purchasePrice)) paid")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Space.lg)
        .accessibilityElement(children: .combine)
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("EDIT")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.lg)
                .accessibilityAddTraits(.isHeader)

            Theme.Card {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        TextField("Item name", text: Binding(
                            get: { item.title },
                            set: { newValue in
                                item.title = newValue
                                CadenceCloudStore.save(modelContext, label: "trackedTitle")
                            }
                        ))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityLabel("Item name")
                    }

                    Divider().overlay(Theme.gridDivider)

                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Purchase price")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .onChange(of: priceText) { _, _ in
                                persistPriceIfNeeded()
                            }
                            .accessibilityLabel("Purchase price")
                    }

                    Divider().overlay(Theme.gridDivider)

                    DatePicker(
                        "Purchased",
                        selection: Binding(
                            get: { item.purchasedAt },
                            set: { newDate in
                                SpendStore.updateTrackedItem(item, purchasedAt: newDate, in: modelContext)
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .font(.subheadline)
                    .accessibilityHint("Changes the purchase date used for daily cost")

                    Divider().overlay(Theme.gridDivider)

                    Picker("Category", selection: Binding(
                        get: { item.category },
                        set: { SpendStore.updateTrackedItem(item, category: $0, in: modelContext) }
                    )) {
                        ForEach(SpendCategory.spendingCases) { cat in
                            Text(cat.title).tag(cat)
                        }
                    }
                    .accessibilityHint("Category for this tracked item")

                    Divider().overlay(Theme.gridDivider)

                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Text("Use mode")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Picker("Use mode", selection: Binding(
                            get: { item.useMode },
                            set: { SpendStore.updateTrackedItem(item, useMode: $0, in: modelContext) }
                        )) {
                            ForEach(SpendUseMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint("Switch between tap to log and daily cost")
                        Text(item.useMode.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }

                    if let last = item.lastUsedAt, item.useMode == .tapToLog {
                        Divider().overlay(Theme.gridDivider)
                        HStack {
                            Text("Last use")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            Text(last.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.lg)
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label("Remove tracked item", systemImage: "trash")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.red.opacity(0.95))
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.sm)
        .accessibilityHint("Stops tracking this item for cost per use")
    }

    @ViewBuilder
    private var history: some View {
        if item.useMode == .tapToLog {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("USE LOG")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, Theme.Space.lg)
                    .accessibilityAddTraits(.isHeader)
                if logs.isEmpty {
                    Theme.Card {
                        VStack(spacing: Theme.Space.sm) {
                            Theme.IconWell(systemImage: "hand.tap", tint: Theme.muted, size: 40)
                            Text("NO USES YET")
                                .font(.caption2.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.muted)
                            Text("Log a use to start cost-per-use.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md)
                    }
                    .padding(.horizontal, Theme.Space.lg)
                } else {
                    Theme.Card {
                        VStack(spacing: 0) {
                            ForEach(logs.prefix(20), id: \.id) { log in
                                HStack {
                                    Text(log.usedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                    Spacer()
                                    if !log.note.isEmpty {
                                        Text(log.note)
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Button {
                                        SpendStore.deleteUseLog(log, item: item, in: modelContext)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Color.red.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove this use")
                                }
                                .padding(.vertical, Theme.Space.sm)
                                if log.id != logs.prefix(20).last?.id {
                                    Divider().overlay(Theme.gridDivider)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                }
            }
        }
    }

    private func priceText(from value: Double) -> String {
        if value == floor(value) { return String(Int(value)) }
        return String(format: "%.2f", value)
    }

    private func persistPriceIfNeeded() {
        let cleaned = priceText.replacingOccurrences(of: ",", with: ".")
        guard let price = Double(cleaned), price > 0 else { return }
        guard abs(price - item.purchasePrice) > 0.000_1 else { return }
        SpendStore.updateTrackedItem(item, purchasePrice: price, in: modelContext)
    }
}
