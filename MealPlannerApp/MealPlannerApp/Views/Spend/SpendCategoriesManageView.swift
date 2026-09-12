import SwiftUI
import SwiftData

/// Manage custom subcategories — Rocket Money Categories / New Category flow.
struct SpendCategoriesManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendSubcategoryEntity.sortOrder)
    private var subcategories: [SpendSubcategoryEntity]

    @State private var showNew = false
    @State private var draftParent: SpendCategory = .home

    var body: some View {
        List {
            Section {
                Text("Create nested groups like Kitchen under Home. Assign purchases to them for a clearer pie and per-group budgets.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .listRowBackground(Theme.surface)
            }

            ForEach(SpendCategory.spendingCases) { cat in
                let kids = subcategories.filter { $0.parentCategory == cat }
                if !kids.isEmpty {
                    Section {
                        ForEach(kids, id: \.id) { sub in
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
                                    Text(cat.title)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    SpendStore.deleteSubcategory(sub, in: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Theme.surface)
                        }
                    } header: {
                        Label(cat.title, systemImage: cat.systemImage)
                    }
                }
            }

            Section {
                Button {
                    draftParent = .home
                    showNew = true
                } label: {
                    Label("New subcategory", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.cta)
                }
                .listRowBackground(Theme.surface)
            } footer: {
                Text("Default spending types (Groceries, Dining, …) stay fixed. Customize with subcategories.")
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .sheet(isPresented: $showNew) {
            ManageNewSubcategorySheet(initialParent: draftParent)
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
