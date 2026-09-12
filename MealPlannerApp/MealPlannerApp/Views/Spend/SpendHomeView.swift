import SwiftUI
import SwiftData
import Charts

/// Spend home — Rocket Money–inspired: colorful category donut, budgets, subcategories, purchases, cost/use.
/// Mobbin refs: Rocket Money Spending breakdown, Budget, Categories.
struct SpendHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}

    @Query(sort: \SpendTransactionEntity.postedAt, order: .reverse)
    private var transactions: [SpendTransactionEntity]
    @Query(sort: \SpendTrackedItemEntity.createdAt, order: .reverse)
    private var tracked: [SpendTrackedItemEntity]
    @Query private var enrollments: [SpendEnrollmentEntity]
    @Query(sort: \SpendSubcategoryEntity.sortOrder)
    private var subcategories: [SpendSubcategoryEntity]
    @Query private var budgets: [SpendBudgetEntity]
    @Query(sort: \SpendUserCategoryEntity.sortOrder)
    private var userCategories: [SpendUserCategoryEntity]

    @State private var segment: Segment = .overview
    @State private var categoryFilter: SpendCategory?
    @State private var monthOffset: Int = 0
    @State private var selectedTransaction: SpendTransactionEntity?
    @State private var selectedItem: SpendTrackedItemEntity?
    @State private var selectedCategory: SpendCategory?
    @State private var selectedUserCategory: UserCategorySheetItem?
    @State private var pieFocus: SpendCategory?
    @State private var pieFocusUserID: UUID?
    @State private var pieHighlightID: String?
    /// Bumps whenever the expanded slice is interacted with; stale timers ignore themselves.
    @State private var pieCollapseGeneration = 0
    /// Set when a tap hit the donut so overview-wide dismiss doesn’t immediately undo it.
    @State private var pieTapConsumed = false
    @State private var showAddTracked = false
    @State private var showConnectInfo = false
    @State private var showBudgets = false
    @State private var showCategories = false
    @State private var isSyncing = false
    @State private var syncMessage: String?

    private enum Segment: String, CaseIterable, Identifiable {
        case overview, purchases, trackers
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .purchases: return "Purchases"
            case .trackers: return "Cost / use"
            }
        }
    }

    private var focusMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthRange: (start: Date, end: Date) {
        SpendStore.monthBounds(containing: focusMonth)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: monthRange.start)
    }

    private var shortMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: monthRange.start)
    }

    private var categorySlices: [SpendCategorySlice] {
        SpendStore.categorySlices(
            transactions: transactions,
            budgets: budgets,
            userCategories: userCategories,
            in: monthRange
        )
    }

    /// Pie stays spend-only; breakdown also lists unused custom categories so new ones are visible.
    private var breakdownSlices: [SpendCategorySlice] {
        var rows = categorySlices
        let seen = Set(rows.compactMap(\.userCategoryID))
        for cat in userCategories where !seen.contains(cat.id) {
            rows.append(
                SpendCategorySlice(
                    category: .other,
                    subcategoryID: nil,
                    userCategoryID: cat.id,
                    title: cat.name,
                    systemImage: cat.systemImage,
                    color: cat.tint,
                    amount: 0,
                    budget: nil,
                    transactionCount: 0
                )
            )
        }
        return rows
    }

    /// Full-ring sectors: other categories stay put; the focused category’s wedge expands
    /// and splits into subcategory pieces (same total angle — not a new full donut).
    private var pieSectors: [PieSector] {
        categorySlices.flatMap { cat -> [PieSector] in
            if let userID = cat.userCategoryID {
                return [PieSector(from: cat, expanded: pieFocusUserID == userID, splitChild: false)]
            }
            guard cat.category == pieFocus, pieFocusUserID == nil else {
                return [PieSector(from: cat, expanded: false, splitChild: false)]
            }
            let subs = SpendStore.subcategorySlices(
                for: cat.category,
                transactions: transactions,
                subcategories: subcategories,
                budgets: budgets,
                in: monthRange
            ).filter { $0.amount > 0 }
            let canSplit = subs.count >= 2 || subs.contains(where: { $0.subcategoryID != nil })
            if canSplit {
                return subs.map { PieSector(from: $0, expanded: true, splitChild: true) }
            }
            return [PieSector(from: cat, expanded: true, splitChild: false)]
        }
    }

    private var focusedCategoryAmount: Double {
        if let pieFocusUserID {
            return categorySlices.first(where: { $0.userCategoryID == pieFocusUserID })?.amount ?? 0
        }
        guard let pieFocus else { return 0 }
        return categorySlices.first(where: { $0.userCategoryID == nil && $0.category == pieFocus })?.amount ?? 0
    }

    private var focusedPieTitle: String? {
        if let pieFocusUserID {
            return userCategories.first(where: { $0.id == pieFocusUserID })?.name
        }
        return pieFocus?.title
    }

    private var monthSpend: Double {
        categorySlices.map(\.amount).reduce(0, +)
    }

    private var totalBudget: Double {
        SpendStore.totalBudgeted(budgets: budgets)
    }

    private var budgetRemaining: Double? {
        guard totalBudget > 0 else { return nil }
        return totalBudget - monthSpend
    }

    private var visibleTransactions: [SpendTransactionEntity] {
        let txs = SpendStore.spendingTransactions(transactions, in: monthRange, category: categoryFilter)
        return txs.sorted { $0.postedAt > $1.postedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "Spend", onMenu: onOpenDrawer)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    monthNavigator
                        .padding(.horizontal, Theme.Space.lg)

                    Picker("Section", selection: $segment) {
                        ForEach(Segment.allCases) { seg in
                            Text(seg.title.uppercased()).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Space.lg)
                    .accessibilityLabel("Spend section")

                    switch segment {
                    case .overview:
                        overviewContent
                    case .purchases:
                        categoryChips
                            .padding(.horizontal, Theme.Space.lg)
                        purchasesList
                    case .trackers:
                        trackersList
                    }

                    connectBanner
                        .padding(.horizontal, Theme.Space.lg)
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
            // Heal empty Plaid history after a store wipe left a stale sync cursor.
            let hasPlaidTxs = transactions.contains { !$0.remoteID.hasPrefix("demo-") }
            if !enrollments.isEmpty, !hasPlaidTxs, !isSyncing {
                Task { await syncNow() }
            }
        }
        .onChange(of: monthOffset) { _, _ in
            collapsePieFocus()
        }
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .addSpendItem else { return }
            showAddTracked = true
            appModel.requestedFABAction = nil
        }
        .onChange(of: appModel.requestedOpenSpendCategories) { _, open in
            guard open else { return }
            showCategories = true
            appModel.requestedOpenSpendCategories = false
        }
        .onChange(of: appModel.requestedOpenSpendCategoryPurchase) { _, open in
            guard open else { return }
            openFirstCategoryPurchase()
        }
        .onAppear {
            if appModel.requestedOpenSpendCategories {
                showCategories = true
                appModel.requestedOpenSpendCategories = false
            }
            if appModel.requestedOpenSpendCategoryPurchase {
                openFirstCategoryPurchase()
            }
        }
        .sheet(item: $selectedTransaction) { tx in
            SpendTransactionSheet(transaction: tx, subcategories: subcategories, userCategories: userCategories)
        }
        .sheet(item: $selectedItem) { item in
            SpendItemDetailView(item: item)
        }
        .sheet(item: $selectedCategory) { cat in
            SpendCategoryDetailView(category: cat, month: focusMonth)
        }
        .sheet(item: $selectedUserCategory) { item in
            if let user = userCategories.first(where: { $0.id == item.id }) {
                SpendCategoryDetailView(category: .other, userCategory: user, month: focusMonth)
            }
        }
        .sheet(isPresented: $showAddTracked) {
            AddTrackedItemSheet()
        }
        .sheet(isPresented: $showBudgets) {
            NavigationStack {
                SpendBudgetsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showBudgets = false }
                                .foregroundStyle(Theme.cta)
                        }
                    }
            }
        }
        .sheet(isPresented: $showCategories) {
            NavigationStack {
                SpendCategoriesManageView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showCategories = false }
                                .foregroundStyle(Theme.cta)
                        }
                    }
            }
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

    // MARK: - Month nav

    private var monthNavigator: some View {
        HStack {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.sunken))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()
            Text(monthLabel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()

            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(monthOffset >= 0 ? Theme.muted : Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.sunken))
            }
            .buttonStyle(.plain)
            .disabled(monthOffset >= 0)
            .accessibilityLabel("Next month")
        }
    }

    // MARK: - Overview (Rocket Money)

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            budgetSummaryCard
                .padding(.horizontal, Theme.Space.lg)

            donutCard
                .padding(.horizontal, Theme.Space.lg)

            categoryBreakdown
        }
        // Tap anywhere outside the wheel collapses an expanded slice.
        .simultaneousGesture(
            TapGesture().onEnded {
                if pieTapConsumed {
                    pieTapConsumed = false
                    return
                }
                collapsePieFocus()
            }
        )
    }

    private var budgetSummaryCard: some View {
        Theme.Card {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack {
                    Theme.IconWell(systemImage: "chart.pie.fill", tint: Theme.accent, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(shortMonthLabel.uppercased()) BUDGET")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.muted)
                        if let remaining = budgetRemaining {
                            Text(remaining >= 0
                                 ? "\(SpendFormat.money(remaining)) left"
                                 : "\(SpendFormat.money(abs(remaining))) over")
                                .font(Theme.display(.title2))
                                .foregroundStyle(remaining >= 0 ? Theme.ink : Theme.danger)
                        } else {
                            Text("Set category budgets")
                                .font(Theme.display(.title3))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        showBudgets = true
                    } label: {
                        Text(totalBudget > 0 ? "EDIT" : "SET")
                            .font(.caption.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.cta)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens budget editor")
                }

                if totalBudget > 0 {
                    GeometryReader { geo in
                        let progress = min(monthSpend / max(totalBudget, 1), 1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.sunken)
                            Capsule()
                                .fill(monthSpend > totalBudget ? Theme.danger : Theme.accent)
                                .frame(width: max(8, geo.size.width * progress))
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text("\(SpendFormat.money(monthSpend)) spent")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text("of \(SpendFormat.money(totalBudget))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    Text("Budgets keep spending helpful — set limits per category or subcategory like Kitchen.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var donutCard: some View {
        Theme.Card {
            VStack(spacing: Theme.Space.md) {
                ZStack {
                    if pieSectors.isEmpty {
                        Circle()
                            .stroke(Theme.sunken, lineWidth: 28)
                            .frame(width: 200, height: 200)
                    } else {
                        // Avoid Chart `.animation` + unstable sector IDs — that combo can
                        // EXC_BREAKPOINT / freeze inside Swift Charts when a wedge splits.
                        Chart(pieSectors) { sector in
                            SectorMark(
                                angle: .value("Amount", max(sector.amount, 0.01)),
                                innerRadius: .ratio(0.58),
                                outerRadius: .ratio(sector.expanded ? 1.16 : 1.0),
                                angularInset: 1.5
                            )
                            .foregroundStyle(sector.color)
                            .opacity(pieDimOpacity(for: sector))
                            .cornerRadius(3)
                        }
                        .frame(width: 236, height: 236)
                        .chartLegend(.hidden)
                        .transaction { $0.animation = nil }
                        .chartOverlay { _ in
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        handlePieTap(at: location, in: geo.size)
                                    }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(pieAccessibilityLabel)
                        .accessibilityHint(pieFocus == nil && pieFocusUserID == nil
                                           ? "Double tap a slice to expand and split it"
                                           : "Tap outside the wheel to show the full pie again, or wait 7 seconds")
                    }

                    pieCenterLabel
                }
                .frame(maxWidth: .infinity)

                if let focused = pieFocus {
                    expandedSliceLegend(for: focused)
                } else if categorySlices.isEmpty {
                    Text("No purchases this month yet.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("Tap a slice to expand · tap elsewhere or wait 7s to collapse")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    private func expandedSliceLegend(for category: SpendCategory) -> some View {
        let parts = pieSectors.filter { $0.expanded }
        if !parts.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(category.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                ForEach(parts) { part in
                    HStack(spacing: Theme.Space.sm) {
                        Circle()
                            .fill(part.color)
                            .frame(width: 8, height: 8)
                        Text(part.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                        Text(SpendFormat.money(part.amount))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Space.xs)
        }
    }

    private var pieCenterLabel: some View {
        let focusedTitle = focusedPieTitle
        let title = focusedTitle?.uppercased() ?? "TOTAL SPEND"
        let amount = focusedTitle == nil ? monthSpend : focusedCategoryAmount
        let subtitle: String = {
            if focusedTitle != nil {
                let pct = monthSpend > 0 ? Int((focusedCategoryAmount / monthSpend * 100).rounded()) : 0
                return "\(pct)% of \(shortMonthLabel)"
            }
            return shortMonthLabel
        }()

        return VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
            Text(SpendFormat.money(amount))
                .font(Theme.display(.title))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 118)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(focusedTitle == nil
                            ? "Total spend \(SpendFormat.money(monthSpend)) in \(monthLabel)"
                            : "\(focusedTitle ?? ""), \(SpendFormat.money(focusedCategoryAmount)). Tap outside the wheel to collapse")
    }

    private var pieAccessibilityLabel: String {
        if let title = focusedPieTitle {
            let parts = pieSectors.filter(\.expanded).map { "\($0.title) \(SpendFormat.money($0.amount))" }.joined(separator: ", ")
            return "\(title) expanded: \(parts)"
        }
        return "Spending pie by category"
    }

    private func pieDimOpacity(for sector: PieSector) -> Double {
        guard pieFocus != nil || pieFocusUserID != nil else { return 1 }
        return sector.expanded ? 1 : 0.34
    }

    private func collapsePieFocus() {
        guard pieFocus != nil || pieFocusUserID != nil else { return }
        pieFocus = nil
        pieFocusUserID = nil
        pieHighlightID = nil
        pieCollapseGeneration += 1
    }

    private func schedulePieAutoCollapse() {
        guard pieFocus != nil || pieFocusUserID != nil else { return }
        pieCollapseGeneration += 1
        let generation = pieCollapseGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(7))
            guard generation == pieCollapseGeneration, pieFocus != nil || pieFocusUserID != nil else { return }
            pieFocus = nil
            pieFocusUserID = nil
            pieHighlightID = nil
        }
    }

    private func handlePieTap(at point: CGPoint, in size: CGSize) {
        guard !pieSectors.isEmpty, monthSpend > 0, size.width > 0, size.height > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = hypot(dx, dy)
        let outer = min(size.width, size.height) / 2
        let inner = outer * 0.58

        // Hole / outside the ring → treat as “not the wheel” and collapse.
        if radius < inner * 0.92 || radius > outer * 1.05 {
            pieTapConsumed = true
            collapsePieFocus()
            return
        }

        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * Double.pi }

        let total = monthSpend
        var cursor = 0.0
        var hit: PieSector?
        for sector in pieSectors {
            cursor += (sector.amount / total) * 2 * Double.pi
            if angle <= cursor + 0.0001 {
                hit = sector
                break
            }
        }
        guard let hit else {
            pieTapConsumed = true
            collapsePieFocus()
            return
        }

        pieTapConsumed = true
        if let userID = hit.userCategoryID {
            pieFocus = nil
            pieFocusUserID = userID
            pieHighlightID = hit.id
        } else if pieFocus == hit.category, pieFocusUserID == nil {
            pieHighlightID = hit.id
        } else {
            pieFocus = hit.category
            pieFocusUserID = nil
            pieHighlightID = hit.id
        }
        schedulePieAutoCollapse()
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text("BREAKDOWN")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    showCategories = true
                } label: {
                    Text("CATEGORIES")
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.cta)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Create and manage spending categories")
            }
            .padding(.horizontal, Theme.Space.lg)

            if breakdownSlices.isEmpty {
                Theme.EmptyState(
                    systemImage: "chart.pie",
                    title: "Nothing to break down",
                    message: "Connect a bank or wait for purchases — categories color the pie automatically.",
                    cta: "CONNECT PLAID",
                    ctaHint: "Opens Spend settings"
                ) {
                    showConnectInfo = true
                }
                .padding(.horizontal, Theme.Space.lg)
            } else {
                Theme.Card {
                    VStack(spacing: 0) {
                        ForEach(breakdownSlices) { slice in
                            Button {
                                if let userID = slice.userCategoryID {
                                    selectedUserCategory = UserCategorySheetItem(id: userID)
                                } else {
                                    selectedCategory = slice.category
                                }
                            } label: {
                                categoryRow(slice)
                            }
                            .buttonStyle(.plain)
                            if slice.id != breakdownSlices.last?.id {
                                Divider().overlay(Theme.gridDivider)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.lg)
            }
        }
    }

    private func budgetPercentLabel(for slice: SpendCategorySlice) -> String {
        guard let budget = slice.budget, budget > 0 else { return "No budget" }
        let pct = Int((slice.amount / budget * 100).rounded())
        return "\(pct)% of budget"
    }

    private func categoryRow(_ slice: SpendCategorySlice) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.sm + 2) {
                Image(systemName: slice.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(slice.color)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(slice.color.opacity(0.22)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(slice.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(budgetPercentLabel(for: slice)) · \(slice.transactionCount) \(slice.transactionCount == 1 ? "purchase" : "purchases")")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: Theme.Space.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SpendFormat.money(slice.amount))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    if let remaining = slice.remaining {
                        Text(remaining >= 0
                             ? "\(SpendFormat.money(remaining)) left"
                             : "\(SpendFormat.money(abs(remaining))) over")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(remaining >= 0 ? Theme.ink : Theme.danger)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            if let progress = slice.budgetProgress, let budget = slice.budget {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.sunken)
                        Capsule()
                            .fill(slice.isOverBudget ? Theme.danger : slice.color)
                            .frame(width: max(6, geo.size.width * min(progress, 1)))
                    }
                }
                .frame(height: 6)
                .accessibilityLabel("Budget \(SpendFormat.money(budget)), spent \(SpendFormat.money(slice.amount))")
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm + 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(slice.title) details and subcategories")
    }

    // MARK: - Connect / purchases / trackers (preserved)

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
            if let syncMessage {
                Text(syncMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                chip(title: "All", color: Theme.accent, selected: categoryFilter == nil) {
                    categoryFilter = nil
                }
                ForEach(SpendCategory.spendingCases) { cat in
                    chip(title: cat.title, color: cat.tint, selected: categoryFilter == cat) {
                        categoryFilter = cat
                    }
                }
                ForEach(userCategories, id: \.id) { cat in
                    chip(title: cat.name, color: cat.tint, selected: false) {
                        selectedUserCategory = UserCategorySheetItem(id: cat.id)
                    }
                }
            }
        }
    }

    private func chip(title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(selected ? Color.white : Theme.ink)
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? color : Theme.sunken)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var purchasesList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("PURCHASES")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, Theme.Space.lg)
                .accessibilityAddTraits(.isHeader)

            if visibleTransactions.isEmpty {
                Theme.EmptyState(
                    systemImage: "creditcard",
                    title: "No purchases yet",
                    message: "Connect Plaid or switch months — categorized buys show up here.",
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
        let tint = tx.category.tint
        let subName = subcategories.first(where: { $0.id == tx.subcategoryID })?.name
        return HStack(spacing: Theme.Space.sm + 2) {
            Image(systemName: tx.category.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.22)))
            VStack(alignment: .leading, spacing: 1) {
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
                Text("\(shortDate(tx.postedAt)) · \(subName ?? tx.category.title)")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Space.sm)
            Text(SpendFormat.money(tx.amount))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(tx.amount >= 0 ? Theme.cta : Theme.ink)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var parts = [tx.merchant, SpendFormat.money(tx.amount), subName ?? tx.category.title]
            if !tx.trimmedDescription.isEmpty { parts.insert(tx.trimmedDescription, at: 1) }
            return parts.joined(separator: ", ")
        }())
        .accessibilityHint("Opens purchase details")
    }

    private var trackersList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack {
                Text("COST PER USE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
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
                        .tracking(0.7)
                        .foregroundStyle(Theme.muted)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.useMode == .dailyAmortize ? "COST / DAY" : "COST / USE")
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
                        if item.useMode == .dailyAmortize {
                            Text(item.costPerUse.map { "\(SpendFormat.money($0)) / day" } ?? "—")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        } else {
                            Text("\(item.effectiveUseCount) uses")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
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
        .accessibilityLabel({
            if item.useMode == .dailyAmortize {
                return "\(item.title), average \(item.costPerUse.map(SpendFormat.money) ?? "none") per day"
            }
            return "\(item.title), cost per use \(item.costPerUse.map(SpendFormat.money) ?? "none yet")"
        }())
    }

    private func openFirstCategoryPurchase() {
        guard let slice = categorySlices.first else {
            appModel.requestedOpenSpendCategoryPurchase = false
            return
        }
        if let userID = slice.userCategoryID {
            selectedUserCategory = UserCategorySheetItem(id: userID)
        } else {
            selectedCategory = slice.category
        }
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
    let subcategories: [SpendSubcategoryEntity]
    var userCategories: [SpendUserCategoryEntity] = []
    @State private var trackMode: SpendUseMode = .tapToLog

    private var categorySubs: [SpendSubcategoryEntity] {
        subcategories.filter { $0.parentCategory == transaction.category }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Merchant", value: transaction.merchant)
                    LabeledContent("Amount", value: SpendFormat.money(transaction.amount))
                    LabeledContent("Date", value: transaction.postedAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Account", value: transaction.accountName.isEmpty ? "—" : transaction.accountName)
                } header: {
                    spendSheetSectionHeader("PURCHASE")
                }

                Section {
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
                } header: {
                    spendSheetSectionHeader("DESCRIPTION")
                } footer: {
                    Text("This name is used in Cost / Use instead of the merchant.")
                        .font(.caption)
                }

                Section {
                    SpendCategoryAssignmentFields(
                        transaction: transaction,
                        userCategories: userCategories,
                        subcategories: categorySubs
                    )
                } header: {
                    spendSheetSectionHeader("CATEGORY")
                } footer: {
                    Text("Create your own categories from Overview → Categories. Subcategories like Kitchen live under a parent.")
                        .font(.caption)
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
                        spendSheetSectionHeader("COST / USE")
                    } footer: {
                        Text(trackMode.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("DONE") { dismiss() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
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
    @State private var purchasedAt = Date()
    @State private var mode: SpendUseMode = .tapToLog
    @State private var category: SpendCategory = .shopping

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $title)
                        .font(.body.weight(.semibold))
                        .accessibilityLabel("Item name")
                    TextField("Purchase price", text: $priceText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Purchase price")
                    DatePicker(
                        "Purchase date",
                        selection: $purchasedAt,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .accessibilityHint("Date used for daily cost and history")
                    Picker("Category", selection: $category) {
                        ForEach(SpendCategory.spendingCases) { cat in
                            Text(cat.title).tag(cat)
                        }
                    }
                } header: {
                    spendSheetSectionHeader("ITEM")
                }

                Section {
                    Picker("Use mode", selection: $mode) {
                        ForEach(SpendUseMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                } header: {
                    spendSheetSectionHeader("HOW YOU USE")
                } footer: {
                    Text(mode.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationTitle("Track item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SAVE") { save() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
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
            purchasedAt: purchasedAt,
            mode: mode,
            category: category,
            in: modelContext
        )
        dismiss()
    }
}

private struct UserCategorySheetItem: Identifiable {
    let id: UUID
}

/// One wedge in the Spend overview donut (category or expanded subcategory piece).
private struct PieSector: Identifiable {
    let id: String
    let category: SpendCategory
    let subcategoryID: UUID?
    let userCategoryID: UUID?
    let title: String
    let color: Color
    let amount: Double
    let expanded: Bool
    let splitChild: Bool

    init(from slice: SpendCategorySlice, expanded: Bool, splitChild: Bool) {
        // Stable identity (no expand flag) so Charts doesn't thrash/crash on split.
        id = slice.id
        category = slice.category
        subcategoryID = slice.subcategoryID
        userCategoryID = slice.userCategoryID
        title = slice.title
        color = slice.color
        amount = slice.amount
        self.expanded = expanded
        self.splitChild = splitChild
    }
}

private func spendSheetSectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.caption2.weight(.bold))
        .tracking(0.7)
        .foregroundStyle(Theme.muted)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
}
