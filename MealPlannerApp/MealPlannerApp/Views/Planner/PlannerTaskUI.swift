import SwiftUI
import SwiftData

struct TaskTagChips: View {
    var tags: [String]
    var colorMap: [String: Color] = [:]

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    let color = colorMap[tag] ?? Theme.accent
                    Text("#\(tag)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.85), in: Capsule())
                }
            }
        }
    }
}

struct SmartTitleHints: View {
    var parsed: ParsedTaskTitle
    var tagColors: [String: Color] = [:]

    var body: some View {
        let hasHints = parsed.dueDate != nil || !parsed.tags.isEmpty
        if hasHints {
            HStack(spacing: 8) {
                if let due = parsed.dueDate {
                    Label(PlannerDate.shortDue(due), systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.danger)
                }
                ForEach(parsed.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tagColors[tag] ?? Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(smartTitleHintsLabel)
        }
    }

    private var smartTitleHintsLabel: String {
        var parts: [String] = []
        if let due = parsed.dueDate {
            parts.append("Due \(PlannerDate.shortDue(due))")
        }
        if !parsed.tags.isEmpty {
            parts.append(parsed.tags.map { "#\($0)" }.joined(separator: ", "))
        }
        return parts.joined(separator: ". ")
    }
}

struct PriorityFlagIcon: View {
    var priority: TaskPriority
    var size: Font = .body

    var body: some View {
        Image(systemName: "flag.fill")
            .font(size)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(priority.flagColor)
    }
}

struct PriorityFlagLabel: View {
    var priority: TaskPriority
    var showMatrixHint: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            PriorityFlagIcon(priority: priority)
            VStack(alignment: .leading, spacing: 1) {
                Text(priority.title)
                    .foregroundStyle(Theme.ink)
                if showMatrixHint {
                    Text("Matrix \(priority.matrixQuadrant.roman)")
                        .font(.caption)
                        .foregroundStyle(priority.matrixQuadrant.tint)
                }
            }
        }
    }
}

struct PriorityPickerMenu<LabelContent: View>: View {
    @Binding var priority: TaskPriority
    @ViewBuilder var label: () -> LabelContent

    var body: some View {
        Menu {
            ForEach(TaskPriority.allCases) { item in
                Button {
                    priority = item
                } label: {
                    PriorityFlagLabel(priority: item)
                }
                .tint(item.flagColor)
            }
        } label: {
            label()
        }
        .accessibilityLabel("Priority, \(priority.title), Matrix \(priority.matrixQuadrant.roman)")
        .accessibilityHint("Sets task priority flag")
    }
}

struct ColorSwatchGrid: View {
    @Binding var selectedHex: String
    var columns: Int = 5
    var swatchHint: String = "Sets accent color"
    var swatchNamePrefix: String = "Color"

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(Array(PlannerColor.palette.enumerated()), id: \.element) { index, hex in
                Button {
                    selectedHex = hex
                } label: {
                    Circle()
                        .fill(PlannerColor.from(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selectedHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(colorSwatchLabel(index: index, hex: hex))
                .accessibilityHint(swatchHint)
                .accessibilityAddTraits(selectedHex == hex ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func colorSwatchLabel(index: Int, hex: String) -> String {
        let name = "\(swatchNamePrefix) \(index + 1)"
        return selectedHex == hex ? "\(name), selected" : name
    }
}

struct DueDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    @Binding var hasDue: Bool

    private var dueDateAccessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return "Due date, \(formatter.string(from: date))"
    }

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .background(Theme.canvas)
                .accessibilityLabel(dueDateAccessibilityLabel)
                .accessibilityHint("Choose due date for this task")
                .navigationTitle("Due date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("No date") { hasDue = false; dismiss() }
                            .accessibilityHint("Clears due date for this task")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { hasDue = true; dismiss() }
                            .foregroundStyle(Theme.accent)
                            .accessibilityHint("Sets due date to selected day")
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TagManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannerTagEntity.name) private var tags: [PlannerTagEntity]
    @State private var editingTag: PlannerTagEntity?

    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    Text("Tags appear when you use #tag in a task title, or add one below.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Color.clear)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No tags yet. Tags appear when you use hash tag in a task title, or add one below.")
                        .accessibilityAddTraits(.isStaticText)
                }
                ForEach(tags) { tag in
                    Button {
                        editingTag = tag
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(PlannerColor.from(hex: tag.colorHex))
                                .frame(width: 28, height: 28)
                            Text("#\(tag.name)")
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .listRowBackground(Theme.surface)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tag \(tag.name)")
                    .accessibilityHint("Double tap to edit tag name and color")
                }
                .onDelete(perform: deleteTags)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                        .accessibilityHint("Closes tag manager")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { addTag() }
                        .accessibilityHint("Creates a new task tag")
                }
            }
            .sheet(item: $editingTag) { tag in
                TagEditorSheet(tag: tag)
            }
        }
    }

    private func addTag() {
        let count = tags.count
        let name = "tag\(count + 1)"
        let entity = PlannerTagEntity(name: name, colorHex: PlannerColor.defaultHex(for: count))
        modelContext.insert(entity)
        try? modelContext.save()
        editingTag = entity
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
        try? modelContext.save()
    }
}

struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var tag: PlannerTagEntity
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("tag name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Tag name")
                        .accessibilityValue(name.isEmpty ? "Empty" : name)
                        .accessibilityHint("Tag name used when typing #tag in tasks")
                } header: {
                    Text("Name")
                        .accessibilityAddTraits(.isHeader)
                }
                Section {
                    ColorSwatchGrid(
                        selectedHex: $tag.colorHex,
                        swatchHint: "Sets tag color",
                        swatchNamePrefix: "Tag color"
                    )
                } header: {
                    Text("Color")
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityHint("Discards tag edits")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if !trimmed.isEmpty { tag.name = trimmed }
                        try? modelContext.save()
                        dismiss()
                    }
                    .accessibilityHint("Saves tag name and color")
                }
            }
            .onAppear { name = tag.name }
        }
        .presentationDetents([.medium])
    }
}

struct ListSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var list: TaskListEntity

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(list.name)
                        .font(.headline)
                        .accessibilityLabel("List name, \(list.name)")
                } header: {
                    Text("List")
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    Toggle("Show in Today", isOn: $list.showInToday)
                        .accessibilityLabel("Show in Today, \(list.showInToday ? "on" : "off")")
                        .accessibilityHint("Shows undated tasks from this list on Today tab")
                    Text("Undated tasks in this list appear on Today when enabled.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }

                if !list.isSystem {
                    Section {
                        Button("Delete list", role: .destructive) {
                            modelContext.delete(list)
                            try? modelContext.save()
                            dismiss()
                        }
                        .accessibilityHint("Permanently removes this list and its tasks")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle("List settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .accessibilityHint("Saves list settings and closes")
                }
            }
        }
        .presentationDetents([.medium])
    }
}
