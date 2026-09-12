import SwiftUI
import SwiftData

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
                }
            } header: {
                Text("Your categories")
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

/// Category + optional subcategory pickers shared by purchase editors.
struct SpendCategoryAssignmentFields: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var transaction: SpendTransactionEntity
    var userCategories: [SpendUserCategoryEntity]
    var subcategories: [SpendSubcategoryEntity]

    var body: some View {
        Picker("Category", selection: Binding(
            get: { currentTag },
            set: { apply(tag: $0) }
        )) {
            ForEach(SpendCategory.spendingCases) { cat in
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
    }
}
