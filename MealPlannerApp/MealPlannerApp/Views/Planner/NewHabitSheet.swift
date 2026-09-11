import SwiftUI
import SwiftData

struct NewHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitEntity.sortOrder) private var habits: [HabitEntity]

    var habit: HabitEntity?

    @State private var name = ""
    @State private var selectedIcon = HabitIconCatalog.options[0]
    @State private var frequency: HabitFrequency = .daily
    @State private var weekdayMask = HabitWeekdayMask.allDays
    @State private var period: HabitPeriod = .morning

    private var isEditing: Bool { habit != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (frequency == .daily || weekdayMask != 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nameField
                    iconSection
                    frequencySection
                    if frequency == .weekly {
                        weekdaySection
                    }
                    periodSection
                }
                .padding(16)
                .padding(.bottom, Theme.Space.xl * 4)
            }
            .background(Theme.canvas)
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.accent)
                        .accessibilityHint("Discards habit changes")
                }
                if isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", role: .destructive) { deleteHabit() }
                            .accessibilityHint("Permanently removes this habit and its history")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Theme.PrimaryButton(title: "SAVE") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .accessibilityLabel("Save habit")
                    .accessibilityHint(canSave ? "Saves habit changes" : "Enter a name and schedule to save")
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.sm + 2)
                    .background(Theme.canvas)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: loadFromHabit)
    }

    private var nameField: some View {
        TextField("Daily Check-in", text: $name)
            .font(.title3)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .accessibilityLabel("Habit name")
            .accessibilityValue(name.isEmpty ? "Empty" : name)
            .accessibilityHint("Name shown on habits list and Today")
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            habitSectionHeader("Icon")
            HStack(spacing: Theme.Space.lg) {
                HabitIconBadge(symbol: selectedIcon.symbol, colorHex: selectedIcon.colorHex, size: 56, selected: false)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Icon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Tap below to change")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Selected habit icon, \(habitIconName(selectedIcon))")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.md), count: 7), spacing: Theme.Space.md) {
                ForEach(HabitIconCatalog.options) { option in
                    Button {
                        selectedIcon = option
                    } label: {
                        HabitIconBadge(
                            symbol: option.symbol,
                            colorHex: option.colorHex,
                            size: 40,
                            selected: option == selectedIcon
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(habitIconLabel(option))
                    .accessibilityAddTraits(option == selectedIcon ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint("Sets habit icon color and symbol")
                }
            }
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            habitSectionHeader("Frequency")
            HStack(spacing: Theme.Space.sm) {
                ForEach(HabitFrequency.allCases) { item in
                    pill(item.title, selected: frequency == item, hint: "Sets how often this habit repeats") {
                        frequency = item
                        if item == .daily {
                            weekdayMask = HabitWeekdayMask.allDays
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Frequency, \(frequency.title) selected")
        }
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            habitSectionHeader("Pick Days")
            HStack(spacing: Theme.Space.sm - 2) {
                ForEach(HabitWeekdayMask.labels(), id: \.weekday) { item in
                    let on = HabitWeekdayMask.contains(item.weekday, in: weekdayMask)
                    Button {
                        weekdayMask = HabitWeekdayMask.toggle(item.weekday, in: weekdayMask)
                    } label: {
                        Text(item.short.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.3)
                            .foregroundStyle(on ? .black : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Space.sm + 2)
                            .background(on ? Theme.accent : Theme.sunken, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.short), \(on ? "scheduled" : "not scheduled")")
                    .accessibilityHint("Double tap to toggle habit on this weekday")
                }
            }
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            habitSectionHeader("Section")
            HStack(spacing: Theme.Space.sm) {
                ForEach(HabitPeriod.allCases, id: \.self) { item in
                    pill(item.title, selected: period == item, hint: "Shows habit in the \(item.title.lowercased()) section on Today") { period = item }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Time of day, \(period.title) selected")
        }
    }

    private func habitSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }

    private func pill(_ title: String, selected: Bool, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .padding(.horizontal, Theme.Space.md + 2)
                .padding(.vertical, Theme.Space.sm + 2)
                .background(selected ? Theme.accent : Theme.sunken, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? Theme.accent.opacity(0.25) : Theme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "\(title), selected" : title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func habitIconName(_ option: HabitIconOption) -> String {
        option.symbol
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
    }

    private func habitIconLabel(_ option: HabitIconOption) -> String {
        let name = habitIconName(option)
        return option == selectedIcon ? "\(name), selected" : name
    }

    private func loadFromHabit() {
        guard let habit else { return }
        name = habit.name
        period = habit.period
        frequency = habit.frequency
        weekdayMask = habit.weekdayMask
        selectedIcon = HabitIconCatalog.options.first { $0.symbol == habit.icon && $0.colorHex == habit.iconColorHex }
            ?? HabitIconOption(symbol: habit.icon, colorHex: habit.iconColorHex)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let habit {
            habit.name = trimmed
            habit.icon = selectedIcon.symbol
            habit.iconColorHex = selectedIcon.colorHex
            habit.period = period
            habit.frequency = frequency
            habit.weekdayMask = frequency == .daily ? HabitWeekdayMask.allDays : weekdayMask
            try? modelContext.save()
            Task { await PlannerSyncCoordinator.shared.habitDidChange(habit) }
        } else {
            let order = (habits.map(\.sortOrder).max() ?? 0) + 1
            let newHabit = HabitEntity(
                name: trimmed,
                icon: selectedIcon.symbol,
                iconColorHex: selectedIcon.colorHex,
                period: period,
                frequency: frequency,
                weekdayMask: frequency == .daily ? HabitWeekdayMask.allDays : weekdayMask
            )
            newHabit.sortOrder = order
            modelContext.insert(newHabit)
            try? modelContext.save()
            Task { await PlannerSyncCoordinator.shared.habitDidChange(newHabit) }
        }
        dismiss()
    }

    private func deleteHabit() {
        guard let habit else { return }
        modelContext.delete(habit)
        try? modelContext.save()
        dismiss()
    }
}
