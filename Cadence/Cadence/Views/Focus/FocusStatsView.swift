import SwiftUI
import SwiftData

/// Focus statistics — Focus To-Do summary grid + Me+/Brick details & trends.
struct FocusStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let sessions: [FocusSessionEntity]

    @State private var detailsPeriod: DetailsPeriod = .day
    @State private var detailsAnchor = Date()
    @State private var trendsPeriod: TrendsPeriod = .week
    @State private var trendsAnchor = Date()
    @State private var showManualAdd = false
    @State private var manualMinutes = 25
    @State private var manualMode: FocusMode = .pomo

    private var completed: [FocusSessionEntity] {
        FocusStore.completed(sessions)
    }

    private var todayPomo: Int { FocusStore.pomoCount(in: completed, day: .now) }
    private var todayFocus: Int { FocusStore.totalSeconds(in: completed, day: .now) }
    private var totalPomo: Int { completed.filter { $0.mode == .pomo }.count }
    private var totalFocus: Int { completed.map(\.durationSeconds).reduce(0, +) }

    private var yesterdayPomo: Int {
        let y = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        return FocusStore.pomoCount(in: completed, day: y)
    }

    private var yesterdayFocus: Int {
        let y = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        return FocusStore.totalSeconds(in: completed, day: y)
    }

    private var recent: [FocusSessionEntity] {
        Array(completed.prefix(40))
    }

    private var detailsRange: (start: Date, end: Date) {
        let cal = Calendar.current
        switch detailsPeriod {
        case .day, .custom:
            let start = cal.startOfDay(for: detailsAnchor)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            return (start, end)
        case .week:
            let start = cal.dateInterval(of: .weekOfYear, for: detailsAnchor)?.start
                ?? cal.startOfDay(for: detailsAnchor)
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .month:
            let start = cal.dateInterval(of: .month, for: detailsAnchor)?.start
                ?? cal.startOfDay(for: detailsAnchor)
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
        }
    }

    private var detailsBreakdown: (pomo: Int, stopwatch: Int) {
        FocusStore.modeBreakdown(in: completed, from: detailsRange.start, to: detailsRange.end)
    }

    private var detailsTotal: Int { detailsBreakdown.pomo + detailsBreakdown.stopwatch }

    private var trendBars: [(label: String, seconds: Int)] {
        switch trendsPeriod {
        case .week:
            return FocusStore.dailyTotals(in: completed, endingOn: trendsAnchor, dayCount: 7).map { item in
                let fmt = DateFormatter()
                fmt.dateFormat = "EEE"
                return (fmt.string(from: item.date), item.seconds)
            }
        case .month:
            return FocusStore.dailyTotals(in: completed, endingOn: trendsAnchor, dayCount: 30).enumerated().map { idx, item in
                let label: String
                if idx == 0 || idx == 14 || idx == 29 {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "d"
                    label = fmt.string(from: item.date)
                } else {
                    label = " "
                }
                return (label, item.seconds)
            }
        case .year:
            return FocusStore.weeklyTotals(in: completed, endingNear: trendsAnchor, weekCount: 12).enumerated().map { idx, item in
                ("W\(idx + 1)", item.seconds)
            }
        }
    }

    private var trendsCanGoNext: Bool {
        let cal = Calendar.current
        switch trendsPeriod {
        case .week:
            return !cal.isDate(trendsAnchor, equalTo: Date(), toGranularity: .weekOfYear)
        case .month:
            return !cal.isDate(trendsAnchor, equalTo: Date(), toGranularity: .month)
        case .year:
            return !cal.isDate(trendsAnchor, equalTo: Date(), toGranularity: .year)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    summaryGrid
                    focusRecord
                    detailsCard
                    trendsCard
                }
                .padding(.horizontal, Theme.Space.lg)
                .padding(.vertical, Theme.Space.md)
                .padding(.bottom, Theme.Space.xxl)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Focus Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showManualAdd) {
                manualAddSheet
            }
        }
    }

    // MARK: - Summary (2×2)

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Space.sm),
                GridItem(.flexible(), spacing: Theme.Space.sm)
            ],
            spacing: Theme.Space.sm
        ) {
            statCard(
                title: "Today's Pomo",
                value: "\(todayPomo)",
                delta: deltaLine(today: todayPomo, yesterday: yesterdayPomo, suffix: "from yesterday")
            )
            statCard(
                title: "Today's Focus",
                value: FocusStore.formatDuration(todayFocus),
                delta: deltaLine(
                    today: todayFocus,
                    yesterday: yesterdayFocus,
                    suffix: "from yesterday",
                    format: FocusStore.formatDurationCompact
                )
            )
            statCard(title: "Total Pomo", value: "\(totalPomo)", delta: nil)
            statCard(title: "Total Focus Duration", value: FocusStore.formatDuration(totalFocus), delta: nil)
        }
    }

    private func statCard(title: String, value: String, delta: DeltaInfo?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let delta {
                HStack(spacing: 4) {
                    Image(systemName: delta.up ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(delta.text)
                        .font(.caption2)
                }
                .foregroundStyle(delta.up ? Color(red: 0.35, green: 0.82, blue: 0.55) : Theme.danger)
            }

            Text(value)
                .font(Theme.display(.title, weight: .bold))
                .foregroundStyle(Theme.accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private struct DeltaInfo {
        var text: String
        var up: Bool
    }

    private func deltaLine(
        today: Int,
        yesterday: Int,
        suffix: String,
        format: ((Int) -> String)? = nil
    ) -> DeltaInfo {
        let diff = today - yesterday
        let amount = format?(abs(diff)) ?? "\(abs(diff))"
        return DeltaInfo(text: "\(amount) \(suffix)", up: diff >= 0)
    }

    // MARK: - Focus Record

    private var focusRecord: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text("Focus Record")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { showManualAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Add focus session")
            }

            if recent.isEmpty {
                Text("No focus sessions yet. Start a Pomo or Stopwatch.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent, id: \.id) { session in
                        sessionRow(session)
                        if session.id != recent.last?.id {
                            Divider().overlay(Theme.gridDivider)
                        }
                    }
                }
            }
        }
        .padding(Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func sessionRow(_ session: FocusSessionEntity) -> some View {
        let day = DateFormatter()
        day.dateFormat = "MMM d"
        let time = DateFormatter()
        time.dateFormat = "h:mm a"
        let end = session.endedAt.map { time.string(from: $0) } ?? ""
        let start = time.string(from: session.startedAt)

        return HStack(spacing: Theme.Space.md) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: session.mode == .pomo ? "timer" : "stopwatch")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(day.string(from: session.startedAt))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(start)\(end.isEmpty ? "" : " – \(end)")")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(FocusStore.formatDuration(session.durationSeconds))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, Theme.Space.sm + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.label), \(FocusStore.formatDuration(session.durationSeconds)), \(day.string(from: session.startedAt))")
        .contextMenu {
            Button("Delete", role: .destructive) {
                FocusStore.delete(session, in: modelContext)
            }
        }
    }

    // MARK: - Details (donut + period)

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text("Details")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                periodNavigator(
                    label: detailsNavigatorLabel,
                    onPrev: { shiftDetails(-1) },
                    onNext: { shiftDetails(1) },
                    canGoNext: detailsCanGoNext
                )
            }

            periodChips(
                titles: DetailsPeriod.allCases.map(\.title),
                selected: detailsPeriod.title
            ) { title in
                if let p = DetailsPeriod.allCases.first(where: { $0.title == title }) {
                    detailsPeriod = p
                }
            }

            FocusDonutChart(
                pomoSeconds: detailsBreakdown.pomo,
                stopwatchSeconds: detailsBreakdown.stopwatch
            )
            .frame(height: 200)
            .padding(.vertical, Theme.Space.sm)

            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("Focus Ranking")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                if detailsTotal == 0 {
                    Text("None")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 2)
                } else {
                    rankingRow(title: "Pomo", seconds: detailsBreakdown.pomo, total: detailsTotal, color: Theme.accent)
                    rankingRow(title: "Stopwatch", seconds: detailsBreakdown.stopwatch, total: detailsTotal, color: Theme.cta)
                }
            }
        }
        .padding(Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var detailsCanGoNext: Bool {
        let cal = Calendar.current
        switch detailsPeriod {
        case .day, .custom:
            return !cal.isDateInToday(detailsAnchor)
        case .week:
            return !cal.isDate(detailsAnchor, equalTo: Date(), toGranularity: .weekOfYear)
        case .month:
            return !cal.isDate(detailsAnchor, equalTo: Date(), toGranularity: .month)
        }
    }

    private var detailsNavigatorLabel: String {
        let cal = Calendar.current
        switch detailsPeriod {
        case .day, .custom:
            if cal.isDateInToday(detailsAnchor) { return "Today" }
            if cal.isDateInYesterday(detailsAnchor) { return "Yesterday" }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: detailsAnchor)
        case .week:
            if cal.isDate(detailsAnchor, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: detailsRange.start)
        case .month:
            let f = DateFormatter()
            f.dateFormat = "MMM yyyy"
            return f.string(from: detailsAnchor)
        }
    }

    private func shiftDetails(_ dir: Int) {
        let cal = Calendar.current
        switch detailsPeriod {
        case .day:
            if let d = cal.date(byAdding: .day, value: dir, to: detailsAnchor) {
                detailsAnchor = min(d, Date())
            }
        case .week:
            if let d = cal.date(byAdding: .weekOfYear, value: dir, to: detailsAnchor) {
                detailsAnchor = min(d, Date())
            }
        case .month:
            if let d = cal.date(byAdding: .month, value: dir, to: detailsAnchor) {
                detailsAnchor = min(d, Date())
            }
        case .custom:
            break
        }
    }

    private func rankingRow(title: String, seconds: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Int(round(Double(seconds) / Double(total) * 100)) : 0
        return HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("\(FocusStore.formatDuration(seconds)) · \(pct)%")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: - Trends

    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                Text("Trends")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                periodNavigator(
                    label: trendsNavigatorLabel,
                    onPrev: { shiftTrends(-1) },
                    onNext: { shiftTrends(1) },
                    canGoNext: trendsCanGoNext
                )
            }

            periodChips(
                titles: TrendsPeriod.allCases.map(\.title),
                selected: trendsPeriod.title
            ) { title in
                if let p = TrendsPeriod.allCases.first(where: { $0.title == title }) {
                    trendsPeriod = p
                }
            }

            FocusBarChart(bars: trendBars)
                .frame(height: 140)
                .padding(.top, Theme.Space.sm)
        }
        .padding(Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var trendsNavigatorLabel: String {
        switch trendsPeriod {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }

    private func shiftTrends(_ dir: Int) {
        let cal = Calendar.current
        switch trendsPeriod {
        case .week:
            if let d = cal.date(byAdding: .weekOfYear, value: dir, to: trendsAnchor) {
                trendsAnchor = min(d, Date())
            }
        case .month:
            if let d = cal.date(byAdding: .month, value: dir, to: trendsAnchor) {
                trendsAnchor = min(d, Date())
            }
        case .year:
            if let d = cal.date(byAdding: .year, value: dir, to: trendsAnchor) {
                trendsAnchor = min(d, Date())
            }
        }
    }

    // MARK: - Shared chrome

    private func periodNavigator(
        label: String,
        onPrev: @escaping () -> Void,
        onNext: @escaping () -> Void,
        canGoNext: Bool
    ) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
            }
            .accessibilityLabel("Previous")

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .disabled(!canGoNext)
            .opacity(canGoNext ? 1 : 0.35)
            .accessibilityLabel("Next")
        }
        .foregroundStyle(Theme.accent)
    }

    private func periodChips(
        titles: [String],
        selected: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: Theme.Space.xs) {
            ForEach(titles, id: \.self) { title in
                Button {
                    onSelect(title)
                } label: {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected == title ? Color.white : Theme.muted)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm - 1)
                        .frame(maxWidth: .infinity)
                        .background {
                            Capsule().fill(selected == title ? Theme.accent : Theme.sunken)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(selected == title ? .isSelected : [])
            }
        }
    }

    // MARK: - Manual add

    private var manualAddSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $manualMode) {
                        ForEach(FocusMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    Stepper(value: $manualMinutes, in: 1...180, step: 1) {
                        LabeledContent("Duration", value: "\(manualMinutes) min")
                    }
                } footer: {
                    Text("Adds a completed session for right now.")
                }
            }
            .navigationTitle("Add Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let secs = manualMinutes * 60
                        let end = Date()
                        FocusStore.recordCompleted(
                            mode: manualMode,
                            startedAt: end.addingTimeInterval(-TimeInterval(secs)),
                            endedAt: end,
                            durationSeconds: secs,
                            label: manualMode.title,
                            in: modelContext
                        )
                        showManualAdd = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Periods

private enum DetailsPeriod: CaseIterable {
    case day, week, month, custom
    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .custom: return "Custom"
        }
    }
}

private enum TrendsPeriod: CaseIterable {
    case week, month, year
    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Charts (pure SwiftUI)

private struct FocusDonutChart: View {
    let pomoSeconds: Int
    let stopwatchSeconds: Int

    private var total: Int { pomoSeconds + stopwatchSeconds }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Theme.gridDivider, lineWidth: 22)
                    .frame(width: side * 0.72, height: side * 0.72)

                if total > 0 {
                    let pomoFrac = CGFloat(pomoSeconds) / CGFloat(total)
                    Circle()
                        .trim(from: 0, to: pomoFrac)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                        .frame(width: side * 0.72, height: side * 0.72)
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .trim(from: pomoFrac, to: 1)
                        .stroke(Theme.cta, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                        .frame(width: side * 0.72, height: side * 0.72)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text(FocusStore.formatDuration(total))
                            .font(Theme.display(.title2, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Focused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    Text("No Data")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct FocusBarChart: View {
    let bars: [(label: String, seconds: Int)]

    private var maxSeconds: Int {
        max(bars.map(\.seconds).max() ?? 0, 1)
    }

    var body: some View {
        if bars.allSatisfy({ $0.seconds == 0 }) {
            Text("No focus time in this range.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(bar.seconds > 0 ? Theme.accent : Theme.sunken)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(4, CGFloat(bar.seconds) / CGFloat(maxSeconds) * 100))
                        Text(bar.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Focus trend chart")
        }
    }
}
