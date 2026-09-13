import SwiftUI
import SwiftData
import UIKit

/// Manage custom subcategories — Rocket Money Categories / New Category flow.
struct SpendCategoriesManageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \SpendSubcategoryEntity.sortOrder)
    private var subcategories: [SpendSubcategoryEntity]
    @Query(sort: \SpendUserCategoryEntity.sortOrder)
    private var userCategories: [SpendUserCategoryEntity]

    @State private var showNew = false
    @State private var showNewCategory = false
    @State private var draftParent: SpendCategory = .home

    var body: some View {
        List {
            Section {
                Text("Add your own categories (Pets, Kids, …) or nest groups like Kitchen under Home.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.surface)
            }

            Section {
                HStack(alignment: .top, spacing: Theme.Space.sm) {
                    Image(systemName: SpendCategory.ignore.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SpendCategory.ignore.tint)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(SpendCategory.ignore.tint.opacity(0.22)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SpendCategory.ignore.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Savings-account activity is filed here automatically. It stays off the pie and does not count toward your budget.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .listRowBackground(Theme.surface)
            } header: {
                Text("Ignore")
            }

            Section {
                Button {
                    showNewCategory = true
                } label: {
                    Label("New category", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.cta)
                }
                .listRowBackground(Theme.surface)
                .accessibilityHint("Creates a new spending category for the pie and purchases")

                if userCategories.isEmpty {
                    Text("No custom categories yet.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.surface)
                } else {
                    ForEach(userCategories, id: \.id) { cat in
                        HStack(spacing: Theme.Space.sm) {
                            Image(systemName: cat.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(cat.tint)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(cat.tint.opacity(0.22)))
                            Text(cat.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button {
                                SpendStore.deleteUserCategory(cat, in: modelContext)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.danger)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(cat.name)")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                SpendStore.deleteUserCategory(cat, in: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        let ordered = userCategories
                        for index in offsets {
                            guard ordered.indices.contains(index) else { continue }
                            SpendStore.deleteUserCategory(ordered[index], in: modelContext)
                        }
                    }
                }
            } header: {
                Text("Your categories")
            }

            ForEach(SpendCategory.spendingCases) { cat in
                let kids = subcategories.filter { $0.parentCategory == cat }
                if !kids.isEmpty {
                    Section {
                        ForEach(kids, id: \.id) { sub in
                            subcategoryRow(sub, parentTitle: cat.title)
                        }
                        .onDelete { offsets in
                            let ordered = kids
                            for index in offsets {
                                guard ordered.indices.contains(index) else { continue }
                                SpendStore.deleteSubcategory(ordered[index], in: modelContext)
                            }
                        }
                    } header: {
                        Label(cat.title, systemImage: cat.systemImage)
                    } footer: {
                        Text("Swipe left or tap trash to remove a subcategory. Purchases stay under \(cat.title).")
                            .font(.caption2)
                    }
                }
            }

            Section {
                Button {
                    draftParent = .home
                    showNew = true
                } label: {
                    Label("New subcategory", systemImage: "plus")
                        .foregroundStyle(Theme.cta)
                }
                .listRowBackground(Theme.surface)
            } footer: {
                Text("Built-in types stay available. Custom categories show on the pie once purchases are assigned.")
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .sheet(isPresented: $showNew) {
            ManageNewSubcategorySheet(initialParent: draftParent)
        }
        .sheet(isPresented: $showNewCategory) {
            ManageNewUserCategorySheet()
        }
        .onChange(of: appModel.requestedOpenSpendNewCategory) { _, open in
            guard open else { return }
            presentNewCategory()
        }
        .onAppear {
            if appModel.requestedOpenSpendNewCategory {
                presentNewCategory()
            }
        }
    }

    @ViewBuilder
    private func subcategoryRow(_ sub: SpendSubcategoryEntity, parentTitle: String) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: sub.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(sub.tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(sub.tint.opacity(0.22)))
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(parentTitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                SpendStore.deleteSubcategory(sub, in: modelContext)
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(sub.name)")
            .accessibilityHint("Removes this subcategory")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                SpendStore.deleteSubcategory(sub, in: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                SpendStore.deleteSubcategory(sub, in: modelContext)
            } label: {
                Label("Delete subcategory", systemImage: "trash")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func presentNewCategory() {
        appModel.requestedOpenSpendNewCategory = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showNewCategory = true
        }
    }
}

private struct ManageNewSubcategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let initialParent: SpendCategory

    @State private var name = ""
    @State private var parent: SpendCategory
    @State private var icon = "tag"
    @State private var colorHex = ""

    private let icons = [
        "tag", "fork.knife.circle", "bolt.fill", "cup.and.saucer.fill",
        "sofa.fill", "wrench.and.screwdriver", "gift.fill", "leaf.fill",
        "gamecontroller.fill", "pawprint.fill", "book.fill", "basket.fill",
    ]

    init(initialParent: SpendCategory) {
        self.initialParent = initialParent
        _parent = State(initialValue: initialParent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Parent category", selection: $parent) {
                        ForEach(SpendCategory.spendingCases) { cat in
                            Label(cat.title, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                } header: {
                    Text("Details")
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { symbol in
                            Button {
                                icon = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .foregroundStyle(icon == symbol ? Color.white : Theme.ink)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(icon == symbol ? parent.tint : Theme.sunken))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            swatch(hex: "", label: "Parent", fill: parent.tint)
                            ForEach(SpendColor.palette, id: \.hex) { item in
                                swatch(hex: item.hex, label: item.name, fill: SpendColor.color(hex: item.hex) ?? parent.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = SpendStore.addSubcategory(
                            name: name,
                            parent: parent,
                            systemImage: icon,
                            colorHex: colorHex,
                            in: modelContext
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(Theme.cta)
                }
            }
            .settingsFormChrome()
        }
    }

    private func swatch(hex: String, label: String, fill: Color) -> some View {
        Button {
            colorHex = hex
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(fill)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(colorHex == hex ? 0.9 : 0), lineWidth: 2))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ManageNewUserCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex = SpendColor.palette.first?.hex ?? "8C94A3"

    private let icons = [
        "tag", "pawprint.fill", "person.2.fill", "car.fill",
        "gift.fill", "leaf.fill", "book.fill", "gamecontroller.fill",
        "heart.fill", "house.fill", "bag.fill", "fork.knife",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Pets)", text: $name)
                } header: {
                    Text("Category")
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .foregroundStyle(icon == symbol ? Color.white : Theme.ink)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(icon == symbol ? swatchFill : Theme.sunken))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SpendColor.palette, id: \.hex) { item in
                                Button { colorHex = item.hex } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(SpendColor.color(hex: item.hex) ?? Theme.muted)
                                            .frame(width: 28, height: 28)
                                            .overlay(Circle().strokeBorder(Theme.ink.opacity(colorHex == item.hex ? 0.9 : 0), lineWidth: 2))
                                        Text(item.name)
                                            .font(.caption2)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = SpendStore.addUserCategory(
                            name: name,
                            systemImage: icon,
                            colorHex: colorHex,
                            in: modelContext
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(Theme.cta)
                }
            }
            .settingsFormChrome()
        }
    }

    private var swatchFill: Color {
        SpendColor.color(hex: colorHex) ?? Theme.cta
    }
}

/// Isolated from SwiftData so keystrokes don’t refresh the purchase sheet.
struct SpendPurchaseDescriptionField: View {
    let initial: String
    var onCommit: (String) -> Void
    @State private var draft: String

    init(initial: String, onCommit: @escaping (String) -> Void) {
        self.initial = initial
        self.onCommit = onCommit
        _draft = State(initialValue: initial)
    }

    var body: some View {
        SpendUntrackedTextView(text: $draft, placeholder: "What was this for?")
            .frame(minHeight: 88, maxHeight: 120)
            .accessibilityLabel("Description")
            .accessibilityHint("Optional note used as the cost per use name")
            .onDisappear { onCommit(draft) }
    }
}

/// UIKit text view — SwiftUI TextField inside a SwiftData List was dropping frames.
private struct SpendUntrackedTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 6, left: -4, bottom: 6, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.isScrollEnabled = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.placeholder = placeholder
        view.text = text.isEmpty ? placeholder : text
        view.textColor = text.isEmpty ? .placeholderText : .label
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.placeholder = placeholder
        if !uiView.isFirstResponder, uiView.text != text, !(text.isEmpty && uiView.text == placeholder) {
            uiView.text = text.isEmpty ? placeholder : text
            uiView.textColor = text.isEmpty ? .placeholderText : .label
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SpendUntrackedTextView
        var placeholder: String = ""

        init(_ parent: SpendUntrackedTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textView.text = placeholder
                textView.textColor = .placeholderText
                parent.text = ""
            }
        }
    }
}

/// Category + optional subcategory pickers shared by purchase editors.
struct SpendCategoryAssignmentFields: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var transaction: SpendTransactionEntity
    var userCategories: [SpendUserCategoryEntity]
    var subcategories: [SpendSubcategoryEntity]

    private var merchantLabel: String {
        let name = transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "this store" : name
    }

    private var hasMerchantRule: Bool {
        SpendStore.merchantRule(for: transaction.merchant, in: modelContext) != nil
    }

    var body: some View {
        Picker("Category", selection: Binding(
            get: { currentTag },
            set: { apply(tag: $0) }
        )) {
            ForEach(SpendCategory.pickerCases) { cat in
                Label(cat.title, systemImage: cat.systemImage).tag("b-\(cat.rawValue)")
            }
            ForEach(userCategories, id: \.id) { cat in
                Label(cat.name, systemImage: cat.systemImage).tag("u-\(cat.id.uuidString)")
            }
        }
        .accessibilityHint("Moves this purchase to another category")

        if transaction.userCategoryID == nil, !subcategories.isEmpty {
            Picker("Subcategory", selection: Binding(
                get: { transaction.subcategoryID },
                set: { transaction.subcategoryID = $0; try? modelContext.save() }
            )) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(subcategories, id: \.id) { sub in
                    Text(sub.name).tag(Optional(sub.id))
                }
            }
        }

        if !transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Toggle(isOn: Binding(
                get: { hasMerchantRule },
                set: { enabled in
                    if enabled {
                        pinCurrentCategoryAsMerchantRule()
                    } else {
                        SpendStore.clearMerchantRule(for: transaction.merchant, in: modelContext)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Always for \(merchantLabel)")
                    Text("Future purchases from this store use this category")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            .tint(Theme.cta)
            .accessibilityHint("Saves a rule so every purchase from this store gets the same category")
        }

        if !transaction.tellerCategory.isEmpty {
            LabeledContent("Bank category", value: friendlyPlaidLabel(transaction.tellerCategory))
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var currentTag: String {
        if let uid = transaction.userCategoryID { return "u-\(uid.uuidString)" }
        return "b-\(transaction.category.rawValue)"
    }

    private func apply(tag: String) {
        if tag.hasPrefix("u-"), let uuid = UUID(uuidString: String(tag.dropFirst(2))) {
            transaction.assign(userCategoryID: uuid)
        } else if tag.hasPrefix("b-"),
                  let cat = SpendCategory(rawValue: String(tag.dropFirst(2))) {
            transaction.assign(builtIn: cat)
        }
        try? modelContext.save()
        // Keep an existing store rule in sync with the new pick.
        if hasMerchantRule {
            pinCurrentCategoryAsMerchantRule()
        }
    }

    private func pinCurrentCategoryAsMerchantRule() {
        _ = SpendStore.setMerchantRule(
            merchant: transaction.merchant,
            category: transaction.userCategoryID == nil ? transaction.category : nil,
            userCategoryID: transaction.userCategoryID,
            applyToExisting: true,
            in: modelContext
        )
    }

    private func friendlyPlaidLabel(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}
