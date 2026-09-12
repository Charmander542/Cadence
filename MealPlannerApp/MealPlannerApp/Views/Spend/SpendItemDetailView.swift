import SwiftUI
import SwiftData

/// Item detail — Klima/Blackbird/Orbit style key-values + cost-per-use hero + log history.
struct SpendItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: SpendTrackedItemEntity
    @Query private var allLogs: [SpendUseLogEntity]

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
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text("DETAILS")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, Theme.Space.lg)
                            .accessibilityAddTraits(.isHeader)
                        detailsCard
                    }
                    if item.useMode == .tapToLog {
                        Theme.PrimaryButton(title: "LOG USE", systemImage: "plus.circle.fill") {
                            SpendStore.logUse(item, in: modelContext)
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .accessibilityHint("Adds one use and updates cost per use")
                    }
                    history
                }
                .padding(.vertical, Theme.Space.md)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("DONE") { dismiss() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.cta)
                }
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

    private var detailsCard: some View {
        Theme.Card {
            VStack(spacing: 0) {
                row("Mode", item.useMode.title)
                Divider().overlay(Theme.gridDivider)
                row("Category", item.category.title)
                Divider().overlay(Theme.gridDivider)
                DatePicker(
                    "Purchased",
                    selection: Binding(
                        get: { item.purchasedAt },
                        set: { newDate in
                            item.purchasedAt = newDate
                            try? modelContext.save()
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .font(.subheadline)
                .padding(.vertical, Theme.Space.sm)
                .accessibilityHint("Changes the purchase date used for daily cost")
                if let last = item.lastUsedAt {
                    Divider().overlay(Theme.gridDivider)
                    row("Last use", last.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .padding(.horizontal, Theme.Space.lg)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, Theme.Space.sm)
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
}
