import SwiftUI
import SwiftData

struct HabitsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}
    @Query(sort: \HabitEntity.sortOrder) private var habits: [HabitEntity]
    @Query private var profiles: [UserProfileEntity]
    @State private var showAdd = false
    @State private var editingHabit: HabitEntity?
    @State private var selectedDay = Date()

    private var workoutsEnabled: Bool {
        CadenceAppsPreferences.isVisible(.workout) && (profiles.first?.workoutsEnabled ?? true)
    }

    private var grouped: [(HabitPeriod, [HabitEntity])] {
        HabitPeriod.allCases.compactMap { period in
            let items = habits.filter { $0.period == period }
            return items.isEmpty ? nil : (period, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "Habits", onMenu: onOpenDrawer)

            weekStrip
                .padding(.top, 4)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    WorkoutCompactBanner(date: selectedDay)
                        .padding(.horizontal, Theme.Space.lg)

                    if habits.isEmpty {
                        Theme.EmptyState(
                            systemImage: "repeat.circle",
                            title: "No habits yet",
                            message: "Track daily routines like water, meds, or stretching.",
                            cta: "ADD HABIT",
                            ctaHint: "Opens new habit form"
                        ) {
                            showAdd = true
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, Theme.Space.lg)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No habits yet. Track daily routines like water, meds, or stretching.")
                    } else if habits.count < 3 {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
                            Text("Consistency compounds.")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                            Spacer(minLength: 0)
                            Button {
                                showAdd = true
                            } label: {
                                Text("ADD HABIT")
                                    .font(.caption.weight(.bold))
                                    .tracking(0.7)
                                    .foregroundStyle(Theme.cta)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add habit")
                            .accessibilityHint("Opens new habit form")
                        }
                        .padding(.horizontal, Theme.Space.lg)
                    }

                    ForEach(grouped, id: \.0) { period, items in
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            HStack(spacing: Theme.Space.sm) {
                                Text(period.title.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.7)
                                    .foregroundStyle(Theme.muted)
                                Theme.CountBadge(count: items.count)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Theme.Space.lg)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("\(period.title), \(items.count) habits")
                            ForEach(items) { habit in
                                habitCard(habit)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 110)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .addHabit else { return }
            showAdd = true
            appModel.requestedFABAction = nil
        }
        .sheet(isPresented: $showAdd) {
            NewHabitSheet()
        }
        .sheet(item: $editingHabit) { habit in
            NewHabitSheet(habit: habit)
        }
    }

    private var weekStrip: some View {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return HStack(spacing: 2) {
            ForEach(days, id: \.self) { day in
                Theme.SoftDayCell(
                    weekday: shortWeek(day),
                    dayNumber: "\(cal.component(.day, from: day))",
                    selected: cal.isDate(selectedDay, inSameDayAs: day),
                    isToday: cal.isDateInToday(day),
                    badge: workoutsEnabled
                        ? WorkoutIntegration.scheduledSession(on: day, workoutsEnabled: true)?.shortName.uppercased()
                        : nil
                ) {
                    selectedDay = day
                }
                .accessibilityLabel(habitWeekStripLabel(for: day))
                .accessibilityHint("Shows habits for this day")
                .accessibilityAddTraits(cal.isDate(selectedDay, inSameDayAs: day) ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, Theme.Space.sm)
        .padding(.vertical, Theme.Space.xs)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Space.lg)
    }

    private func habitWeekStripLabel(for day: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        let name = f.string(from: day)
        if cal.isDate(selectedDay, inSameDayAs: day) {
            return "\(name), selected"
        }
        if cal.isDateInToday(day) {
            return "\(name), today"
        }
        return name
    }

    private func habitCard(_ habit: HabitEntity) -> some View {
        let scheduled = habit.isScheduled(on: selectedDay)
        let done = habit.isDone(on: selectedDay)
        return HStack(spacing: Theme.Space.md) {
            Button {
                guard scheduled else { return }
                if let existing = habit.log(on: selectedDay) {
                    modelContext.delete(existing)
                } else {
                    modelContext.insert(HabitLogEntity(day: selectedDay, status: .done, habit: habit))
                }
                try? modelContext.save()
            } label: {
                HabitIconBadge(
                    symbol: habit.icon,
                    colorHex: habit.iconColorHex,
                    size: 36,
                    completed: done
                )
                .opacity(scheduled || done ? 1 : 0.35)
            }
            .disabled(!scheduled && !done)
            .accessibilityLabel(done ? "Mark \(habit.name) incomplete" : "Complete \(habit.name)")
            .accessibilityHint(scheduled ? "Double tap to mark habit complete or incomplete" : "Not scheduled on this day")
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(done ? Theme.muted : (scheduled ? Theme.ink : Theme.muted))
                    .strikethrough(done, color: Theme.muted.opacity(0.7))
                Text(habitSubtitle(habit))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .opacity(done ? 0.75 : 1)
            }
            .opacity(done ? 0.85 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingHabit = habit }
            Spacer()
            miniWeek(habit)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(habitMiniWeekLabel(habit))
        }
        .padding(Theme.Space.md)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(done ? Theme.accent.opacity(0.35) : Theme.hairline, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 8, y: 3)
        .padding(.horizontal, Theme.Space.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(habitRowAccessibilityLabel(habit, scheduled: scheduled, done: done))
        .accessibilityHint("Use complete button to toggle. Double tap habit name to edit.")
    }

    private func habitRowAccessibilityLabel(_ habit: HabitEntity, scheduled: Bool, done: Bool) -> String {
        var parts = [habit.name, habitSubtitle(habit), habitMiniWeekLabel(habit)]
        if done {
            if Calendar.current.isDateInToday(selectedDay) {
                parts.append("completed today")
            } else {
                let f = DateFormatter()
                f.dateFormat = "EEEE"
                parts.append("completed on \(f.string(from: selectedDay))")
            }
        }
        if !scheduled { parts.append("not scheduled on this day") }
        return parts.joined(separator: ", ")
    }

    private func habitSubtitle(_ habit: HabitEntity) -> String {
        switch habit.frequency {
        case .daily:
            return "\(habit.totalDoneCount()) total"
        case .weekly:
            return "Weekly · \(habit.totalDoneCount()) total"
        }
    }

    private func habitMiniWeekLabel(_ habit: HabitEntity) -> String {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        var done = 0
        var scheduled = 0
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: start) ?? .now
            if habit.isScheduled(on: day) { scheduled += 1 }
            if habit.isDone(on: day) { done += 1 }
        }
        return "This week, \(done) of \(scheduled) days completed"
    }

    private func miniWeek(_ habit: HabitEntity) -> some View {
        // timespent/QUITTR: solid accent = done; dashed ring = scheduled open; faint = off-day.
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let doneDays = Set(
            habit.logs
                .filter { $0.status == .done }
                .map { cal.startOfDay(for: $0.day) }
        )
        return HStack(spacing: Theme.Space.xs) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? .now
                let dayStart = cal.startOfDay(for: day)
                let scheduled = habit.isScheduled(on: day)
                let filled = doneDays.contains(dayStart)
                ZStack {
                    if filled {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                    } else if scheduled {
                        Circle()
                            .strokeBorder(
                                Theme.muted.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 1.5])
                            )
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Theme.flagNone.opacity(0.28))
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 8, height: 8)
            }
        }
    }

    private func shortWeek(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(2))
    }
}
