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
        profiles.first?.workoutsEnabled ?? true
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
                .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    WorkoutCompactBanner(date: selectedDay)

                    if habits.isEmpty {
                        Theme.EmptyState(
                            systemImage: "repeat.circle",
                            title: "No habits yet",
                            message: "Track daily routines like water, meds, or stretching.",
                            cta: "Add habit",
                            ctaHint: "Opens new habit form"
                        ) {
                            showAdd = true
                        }
                        .frame(minHeight: 200)
                        .padding(.horizontal, 16)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No habits yet. Track daily routines like water, meds, or stretching.")
                    }

                    ForEach(grouped, id: \.0) { period, items in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(period.title.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.muted)
                                .padding(.horizontal, 16)
                            ForEach(items) { habit in
                                habitCard(habit)
                            }
                        }
                    }
                }
                .padding(.bottom, 88)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .dialFABChrome {
            OrangeFAB(
                accessibilityLabel: "Add habit",
                accessibilityHint: "Opens new habit form"
            ) {
                showAdd = true
            }
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
        return HStack {
            ForEach(days, id: \.self) { day in
                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: 4) {
                        Text(shortWeek(day))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        Text("\(cal.component(.day, from: day))")
                            .font(.subheadline.weight(cal.isDate(selectedDay, inSameDayAs: day) ? .bold : .regular))
                            .foregroundStyle(cal.isDate(selectedDay, inSameDayAs: day) ? Theme.accent : Theme.ink)
                        if workoutsEnabled, let session = WorkoutIntegration.scheduledSession(on: day, workoutsEnabled: true) {
                            Text(session.shortName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(habitWeekStripLabel(for: day))
                .accessibilityHint("Shows habits for this day")
                .accessibilityAddTraits(cal.isDate(selectedDay, inSameDayAs: day) ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 8)
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
        return HStack(spacing: 12) {
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
                    .foregroundStyle(scheduled ? Theme.ink : Theme.muted)
                Text(habitSubtitle(habit))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingHabit = habit }
            Spacer()
            miniWeek(habit)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(habitMiniWeekLabel(habit))
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(habitRowAccessibilityLabel(habit, scheduled: scheduled, done: done))
        .accessibilityHint("Use complete button to toggle. Double tap habit name to edit.")
    }

    private func habitRowAccessibilityLabel(_ habit: HabitEntity, scheduled: Bool, done: Bool) -> String {
        var parts = [habit.name, habitSubtitle(habit), habitMiniWeekLabel(habit)]
        if done { parts.append("completed today") }
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
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let doneDays = Set(
            habit.logs
                .filter { $0.status == .done }
                .map { cal.startOfDay(for: $0.day) }
        )
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? .now
                let dayStart = cal.startOfDay(for: day)
                let scheduled = habit.isScheduled(on: day)
                let filled = doneDays.contains(dayStart)
                Circle()
                    .fill(filled ? Theme.accent : (scheduled ? Theme.sunken : Theme.flagNone.opacity(0.35)))
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
