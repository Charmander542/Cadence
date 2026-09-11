import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TaskTagChips: View {
    var tags: [String]
    var colorMap: [String: Color] = [:]

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: Theme.Space.xs) {
                ForEach(tags, id: \.self) { tag in
                    let color = colorMap[tag] ?? Theme.accent
                    Text("#\(tag)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Space.sm - 2)
                        .padding(.vertical, Theme.Space.xs / 2)
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
            HStack(spacing: Theme.Space.sm) {
                if let due = parsed.dueDate {
                    Theme.MetaPill(text: PlannerDate.shortDue(due), tone: .danger)
                }
                ForEach(parsed.tags, id: \.self) { tag in
                    Theme.MetaPill(text: "#\(tag)", tone: .accent)
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
        HStack(spacing: Theme.Space.sm + 2) {
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.sm + 2), count: columns), spacing: Theme.Space.sm + 2) {
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
                .tint(Theme.cta)
                .padding()
                .background(Theme.canvas)
                .accessibilityLabel(dueDateAccessibilityLabel)
                .accessibilityHint("Choose due date for this task")
                .navigationTitle("Due date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("No date") { hasDue = false; dismiss() }
                            .foregroundStyle(Theme.muted)
                            .accessibilityHint("Clears due date for this task")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { hasDue = true; dismiss() }
                            .foregroundStyle(Theme.cta)
                            .accessibilityHint("Sets due date to selected day")
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Date/time (5-minute steps, sheet picker keeps keyboard stable)

enum DateSnapping {
    static let minuteStep = 5

    static func snap(_ date: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        comps.minute = (minute / minuteStep) * minuteStep
        comps.second = 0
        comps.nanosecond = 0
        return cal.date(from: comps) ?? date
    }

    /// Compatibility alias for call sites that still say "ten minutes".
    static func tenMinutes(_ date: Date) -> Date { snap(date) }
}

struct TenMinuteDatePicker: UIViewRepresentable {
    @Binding var date: Date
    var mode: UIDatePicker.Mode = .dateAndTime

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = mode
        picker.minuteInterval = DateSnapping.minuteStep
        picker.preferredDatePickerStyle = .wheels
        picker.date = DateSnapping.snap(date)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        let snapped = DateSnapping.snap(date)
        if abs(picker.date.timeIntervalSince(snapped)) > 1 {
            picker.date = snapped
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    final class Coordinator: NSObject {
        var date: Binding<Date>

        init(date: Binding<Date>) {
            self.date = date
        }

        @MainActor @objc func changed(_ sender: UIDatePicker) {
            date.wrappedValue = DateSnapping.snap(sender.date)
        }
    }
}

struct PlannerDateTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    var title: String
    var includeTime = true

    var body: some View {
        NavigationStack {
            TenMinuteDatePicker(
                date: $date,
                mode: includeTime ? .dateAndTime : .date
            )
            .padding(.horizontal)
            .background(Theme.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        date = DateSnapping.snap(date)
                        dismiss()
                    }
                    .foregroundStyle(Theme.cta)
                    .accessibilityHint("Confirms selected date and time")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// Tappable due/reminder row — opens wheel picker in a sheet so the title keyboard stays put.
struct PlannerDateTimeRow: View {
    let label: String
    @Binding var date: Date
    var includeTime = true
    var hint: String

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(formatted)
                    .foregroundStyle(Theme.cta)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(formatted)")
        .accessibilityHint(hint)
        .sheet(isPresented: $showPicker) {
            PlannerDateTimePickerSheet(date: $date, title: label, includeTime: includeTime)
        }
    }

    private var formatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = includeTime ? .short : .none
        return f.string(from: date)
    }
}

// MARK: - Location + Apple Maps

enum MapsNavigation {
    @MainActor
    static func open(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

@MainActor
final class LocationSearchCompleter: ObservableObject {
    @Published var completions: [MKLocalSearchCompletion] = []
    private let bridge = LocationSearchCompleterBridge()

    init() {
        bridge.onResults = { [weak self] results in
            Task { @MainActor in
                self?.completions = results
            }
        }
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completions = []
            bridge.clear()
            return
        }
        bridge.update(query: trimmed)
    }

    static func displayString(for completion: MKLocalSearchCompletion) -> String {
        if completion.subtitle.isEmpty { return completion.title }
        return "\(completion.title), \(completion.subtitle)"
    }
}

private final class LocationSearchCompleterBridge: NSObject, MKLocalSearchCompleterDelegate {
    var onResults: (([MKLocalSearchCompletion]) -> Void)?
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func clear() {
        completer.queryFragment = ""
        onResults?([])
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults?(Array(completer.results.prefix(5)))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onResults?([])
    }
}

struct LocationField: View {
    @Binding var text: String
    var mapsHint = "Opens this place in Apple Maps"

    @StateObject private var search = LocationSearchCompleter()
    @FocusState private var focused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm - 2) {
            HStack(spacing: Theme.Space.sm) {
                TextField("Location", text: $text)
                    .focused($focused)
                    .onChange(of: text) { _, value in
                        search.update(query: value)
                    }
                    .accessibilityLabel("Location")
                    .accessibilityValue(trimmed.isEmpty ? "Empty" : trimmed)
                    .accessibilityHint("Address or place name; suggestions from Apple Maps")
                if !trimmed.isEmpty {
                    Button {
                        MapsNavigation.open(query: trimmed)
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.body)
                            .foregroundStyle(Theme.cta)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open in Maps")
                    .accessibilityHint(mapsHint)
                }
            }
            if focused, !search.completions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(search.completions.enumerated()), id: \.offset) { _, item in
                        Button {
                            text = LocationSearchCompleter.displayString(for: item)
                            focused = false
                            search.completions = []
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Theme.Space.sm)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(LocationSearchCompleter.displayString(for: item))
                        .accessibilityHint("Uses this Maps place for location")
                    }
                }
                .padding(.horizontal, Theme.Space.xs)
            }
        }
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
                    VStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "number", tint: Theme.muted, size: 48)
                        Text("NO TAGS")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.muted)
                        Text("Create your first tag")
                            .font(Theme.display(.headline))
                            .foregroundStyle(Theme.ink)
                        Text("Tags appear when you use #tag in a task title, or tap Add.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.xxl)
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No tags yet. Tags appear when you use hash tag in a task title, or add one below.")
                    .accessibilityAddTraits(.isStaticText)
                }
                ForEach(tags) { tag in
                    Button {
                        editingTag = tag
                    } label: {
                        HStack(spacing: Theme.Space.md) {
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
                        .foregroundStyle(Theme.cta)
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
                    Text("NAME")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isHeader)
                }
                Section {
                    ColorSwatchGrid(
                        selectedHex: $tag.colorHex,
                        swatchHint: "Sets tag color",
                        swatchNamePrefix: "Tag color"
                    )
                } header: {
                    Text("COLOR")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.muted)
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
                    Text("LIST")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
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
                } header: {
                    Text("VISIBILITY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }

                if !list.isSystem {
                    Section {
                        Button("DELETE LIST", role: .destructive) {
                            modelContext.delete(list)
                            try? modelContext.save()
                            dismiss()
                        }
                        .font(.subheadline.weight(.bold))
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
                    Button("DONE") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.cta)
                    .accessibilityHint("Saves list settings and closes")
                }
            }
        }
        .presentationDetents([.medium])
    }
}
