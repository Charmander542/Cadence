import SwiftUI
import SwiftData

struct EventSheetContext: Identifiable {
    let id = UUID()
    var task: PlannerTaskEntity?
    var startDate: Date
}

struct PlannerEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskListEntity.sortOrder) private var lists: [TaskListEntity]
    @Query(sort: \PlannerTagEntity.name) private var allTags: [PlannerTagEntity]

    var context: EventSheetContext

    @State private var title = ""
    @State private var notes = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isAllDay = false
    @State private var recurrence: TaskRecurrence = .none
    @State private var recurrenceWeekdayMask = 0
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var priority: TaskPriority = .none
    @State private var listID: UUID?
    @State private var isCompleted = false
    @State private var colorHex = PlannerColor.palette[0]
    @State private var selectedTags: Set<String> = []

    private var parsed: ParsedTaskTitle { TaskTitleParser.parse(title) }
    private var isEditing: Bool { context.task != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var pickerLists: [TaskListEntity] {
        PlannerStore.visibleTaskLists(lists)
    }

    private var selectedListName: String {
        pickerLists.first { $0.id == listID }?.name ?? "Inbox"
    }

    private func eventDateTimeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .onChange(of: title) { _, _ in applyParsedHints() }
                        .accessibilityLabel("Title")
                        .accessibilityValue(title.isEmpty ? "Empty" : title)
                        .accessibilityHint("Event name shown on calendar")
                    SmartTitleHints(parsed: parsed, tagColors: tagColorMap)
                    LocationField(text: $location, mapsHint: "Opens event location in Apple Maps")
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Notes")
                        .accessibilityValue(notes.isEmpty ? "Empty" : notes)
                        .accessibilityHint("Optional notes for this event")
                }

                Section {
                    ColorSwatchGrid(
                        selectedHex: $colorHex,
                        swatchHint: "Sets accent color for calendar event",
                        swatchNamePrefix: "Event color"
                    )
                } header: {
                    eventSectionHeader("COLOR")
                }

                Section {
                    if allTags.isEmpty {
                        Text("Use #tag in the title or manage tags from the menu.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    FlowLayoutTags(allTags: allTags, selected: $selectedTags)
                } header: {
                    eventSectionHeader("TAGS")
                }

                Section {
                    Toggle("All-day", isOn: $isAllDay)
                        .accessibilityLabel("All-day, \(isAllDay ? "on" : "off")")
                        .accessibilityValue(isAllDay ? "All day event" : "Timed event")
                        .accessibilityHint("Treats event as full day without specific times")
                    if isAllDay {
                        PlannerDateTimeRow(
                            label: "Starts",
                            date: $startDate,
                            includeTime: false,
                            hint: "Opens start date picker"
                        )
                    } else {
                        PlannerDateTimeRow(
                            label: "Starts",
                            date: Binding(
                                get: { startDate },
                                set: { startDate = DateSnapping.tenMinutes($0) }
                            ),
                            hint: "Opens start date and time picker in five-minute steps"
                        )
                        PlannerDateTimeRow(
                            label: "Ends",
                            date: Binding(
                                get: { endDate },
                                set: { endDate = DateSnapping.tenMinutes($0) }
                            ),
                            hint: "Opens end date and time picker in five-minute steps"
                        )
                    }
                    Picker("Repeat", selection: $recurrence) {
                        ForEach(TaskRecurrence.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .accessibilityLabel("Repeat, \(recurrence.title)")
                    .accessibilityHint("Sets how often this event repeats")
                    if recurrence == .customWeekly {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(RecurrenceWeekdayMask.summary(recurrenceWeekdayMask))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .accessibilityAddTraits(.isStaticText)
                            HStack(spacing: Theme.Space.sm - 2) {
                                ForEach(RecurrenceWeekdayMask.labels(), id: \.weekday) { item in
                                    let on = RecurrenceWeekdayMask.contains(item.weekday, in: recurrenceWeekdayMask)
                                    Button {
                                        recurrenceWeekdayMask = RecurrenceWeekdayMask.toggle(item.weekday, in: recurrenceWeekdayMask)
                                    } label: {
                                        Text(item.short)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(on ? .black : Theme.ink)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Theme.Space.sm)
                                            .background(on ? Theme.accent : Theme.sunken, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(item.short), \(on ? "repeats" : "does not repeat")")
                                    .accessibilityHint("Double tap to toggle recurring event on this weekday")
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Reminder", isOn: $hasReminder)
                        .accessibilityLabel("Reminder, \(hasReminder ? "on" : "off")")
                        .accessibilityHint("Schedules notification before the event")
                    if hasReminder {
                        PlannerDateTimeRow(
                            label: "Alert",
                            date: Binding(
                                get: { reminderDate },
                                set: { reminderDate = DateSnapping.tenMinutes($0) }
                            ),
                            hint: "Opens alert time picker in five-minute steps"
                        )
                    }
                }

                if isEditing, let task = context.task {
                    Section {
                        HStack {
                            Label("Countdown widget", systemImage: "star")
                            Spacer()
                            CountdownTrackButton(eventID: task.id)
                        }
                        Text("Star one event to show it on the Countdown widget. Tapping the star again clears it.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { item in
                            HStack(spacing: Theme.Space.sm + 2) {
                                PriorityFlagIcon(priority: item)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                    Text("Matrix \(item.matrixQuadrant.roman)")
                                        .font(.caption)
                                        .foregroundStyle(item.matrixQuadrant.tint)
                                }
                            }
                            .tag(item)
                        }
                    }
                    .accessibilityLabel("Priority, \(priority.title)")
                    .accessibilityHint("Sets event priority flag")
                    Picker("List", selection: $listID) {
                        ForEach(pickerLists) { list in
                            Text(list.name).tag(Optional(list.id))
                        }
                    }
                    .accessibilityLabel("List, \(selectedListName)")
                    .accessibilityHint("Task list that owns this event")
                    if isEditing {
                        Toggle("Completed", isOn: $isCompleted)
                            .accessibilityLabel("Completed, \(isCompleted ? "on" : "off")")
                            .accessibilityHint("Marks event done or reopens it")
                    }
                }
            }
            .scrollDismissesKeyboard(.never)
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .accessibilityHint("Discards event without saving")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "DONE" : "ADD") { save() }
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.cta)
                        .disabled(!canSave)
                        .accessibilityHint(canSave ? "Saves calendar event" : "Enter an event title to save")
                }
                if isEditing, let task = context.task {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("DELETE", role: .destructive) { delete(task) }
                            .font(.caption.weight(.bold))
                            .tracking(0.5)
                            .accessibilityHint("Permanently removes this event")
                    }
                }
            }
            .onAppear(perform: load)
            .onChange(of: startDate) { _, newStart in
                if endDate <= newStart { endDate = newStart.addingTimeInterval(3600) }
            }
            .onChange(of: isAllDay) { _, allDay in
                if allDay {
                    startDate = Calendar.current.startOfDay(for: startDate)
                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                }
            }
            .onChange(of: recurrence) { _, value in
                if value == .customWeekly, recurrenceWeekdayMask == 0 {
                    recurrenceWeekdayMask = RecurrenceWeekdayMask.from(startDate: startDate)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var tagColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: allTags.map { ($0.name, PlannerColor.from(hex: $0.colorHex)) })
    }

    private func load() {
        if let task = context.task {
            title = task.title
            notes = task.notes
            location = task.location
            startDate = task.dueAt ?? context.startDate
            let duration = max(task.durationMinutes, 15)
            endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
            isAllDay = !hasTimeComponent(startDate)
            recurrence = task.recurrence
            recurrenceWeekdayMask = task.recurrenceWeekdayMask
            hasReminder = task.reminderAt != nil
            reminderDate = task.reminderAt ?? startDate.addingTimeInterval(-900)
            priority = task.priority
            listID = task.list?.id
            isCompleted = task.isCompleted
            colorHex = task.colorHex.isEmpty ? PlannerColor.palette[0] : task.colorHex
            selectedTags = Set(task.tags)
        } else {
            startDate = DateSnapping.tenMinutes(context.startDate)
            endDate = DateSnapping.tenMinutes(context.startDate.addingTimeInterval(3600))
            listID = lists.first { $0.name == "Inbox" }?.id
            reminderDate = DateSnapping.tenMinutes(context.startDate.addingTimeInterval(-900))
            recurrenceWeekdayMask = RecurrenceWeekdayMask.from(startDate: startDate)
        }
        startDate = DateSnapping.tenMinutes(startDate)
        endDate = DateSnapping.tenMinutes(endDate)
        reminderDate = DateSnapping.tenMinutes(reminderDate)
    }

    private func applyParsedHints() {
        let p = TaskTitleParser.parse(title)
        if let date = p.dueDate {
            startDate = date
            endDate = date.addingTimeInterval(3600)
        }
        for tag in p.tags {
            selectedTags.insert(tag)
            TagCatalog.ensureTag(tag, in: modelContext)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parsed = TaskTitleParser.parse(trimmed)
        let finalTitle = parsed.cleanTitle.isEmpty ? trimmed : parsed.cleanTitle
        var due = isAllDay ? Calendar.current.startOfDay(for: startDate) : DateSnapping.tenMinutes(startDate)
        if let parsedDue = parsed.dueDate {
            due = isAllDay ? Calendar.current.startOfDay(for: parsedDue) : DateSnapping.tenMinutes(parsedDue)
        }

        let duration = max(Int(endDate.timeIntervalSince(startDate) / 60), isAllDay ? 1440 : 15)
        var resolvedList = lists.first { $0.id == listID }

        var mergedTags = selectedTags.union(parsed.tags)
        TagCatalog.ensureTags(Array(mergedTags), in: modelContext)

        let task: PlannerTaskEntity
        if let existing = context.task {
            task = existing
        } else {
            task = PlannerTaskEntity(title: finalTitle, dueAt: due, priority: priority, list: resolvedList)
            modelContext.insert(task)
        }

        task.title = finalTitle
        task.notes = notes
        task.location = location
        task.dueAt = due
        task.durationMinutes = duration
        task.recurrence = recurrence
        task.recurrenceWeekdayMask = recurrence == .customWeekly ? recurrenceWeekdayMask : 0
        task.priority = priority
        task.list = resolvedList
        task.tags = Array(mergedTags)
        task.colorHex = colorHex
        task.isEvent = true
        task.isCompleted = isCompleted
        task.completedAt = isCompleted ? (task.completedAt ?? .now) : nil
        task.reminderAt = hasReminder ? reminderDate : nil
        if isCompleted {
            CountdownTracking.clearIfTracked(task.id, in: modelContext)
        }

        try? modelContext.save()
        Task { await PlannerSyncCoordinator.shared.taskDidChange(task, in: modelContext) }
        dismiss()
    }

    private func delete(_ task: PlannerTaskEntity) {
        CountdownTracking.clearIfTracked(task.id, in: modelContext)
        Task {
            try? CalendarSyncService.shared.deleteTask(task)
            try? await GoogleCalendarService.shared.deleteTaskEvent(task)
        }
        modelContext.delete(task)
        try? modelContext.save()
        dismiss()
    }

    private func hasTimeComponent(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
    }

    private func eventSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct FlowLayoutTags: View {
    var allTags: [PlannerTagEntity]
    @Binding var selected: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Theme.Space.sm)], spacing: Theme.Space.sm) {
            ForEach(allTags) { tag in
                let on = selected.contains(tag.name)
                Button {
                    if on { selected.remove(tag.name) } else { selected.insert(tag.name) }
                } label: {
                    Text("#\(tag.name)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Space.sm + 2)
                        .padding(.vertical, Theme.Space.sm - 2)
                        .frame(maxWidth: .infinity)
                        .background(PlannerColor.from(hex: tag.colorHex).opacity(on ? 1 : 0.35), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(on ? "Tag \(tag.name), selected" : "Tag \(tag.name)")
                .accessibilityHint("Double tap to add or remove tag from event")
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
