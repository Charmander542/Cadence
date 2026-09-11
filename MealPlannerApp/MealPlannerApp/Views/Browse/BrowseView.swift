import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var query = ""
    @State private var searchQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var course = "all"
    @State private var displayLimit = 50

    private let courses = ["all", "main", "side", "dessert", "other"]
    private let pageSize = 50
    private let searchDebounceMs = 350

    private var filtered: [Recipe] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            let all = appModel.recipeDB.allRecipes()
            if course == "all" { return all }
            return all.filter { $0.course == course }
        }
        return appModel.recipeDB.search(q, course: course == "all" ? nil : course, limit: 200)
    }

    private var results: [Recipe] {
        Array(filtered.prefix(displayLimit))
    }

    private var hasMore: Bool {
        filtered.count > displayLimit
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.sm) {
                        ForEach(courses, id: \.self) { c in
                            Button {
                                course = c
                            } label: {
                                Text(c.capitalized)
                                    .font(.subheadline.weight(course == c ? .bold : .semibold))
                                    .foregroundStyle(course == c ? Color.white : Theme.ink)
                                    .padding(.horizontal, Theme.Space.md + 2)
                                    .padding(.vertical, Theme.Space.sm)
                                    .background(
                                        Capsule().fill(course == c ? Theme.accent : Theme.sunken)
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(
                                            course == c ? Theme.accent.opacity(0.2) : Theme.hairline,
                                            lineWidth: 1
                                        )
                                    )
                                    .shadow(
                                        color: course == c ? Theme.accent.opacity(0.28) : .clear,
                                        radius: 6,
                                        y: 2
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(c.capitalized) course filter")
                            .accessibilityAddTraits(course == c ? [.isButton, .isSelected] : .isButton)
                        }
                        // Recime: Clear all beside active filters.
                        if course != "all" || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                course = "all"
                                query = ""
                                searchQuery = ""
                                displayLimit = pageSize
                            } label: {
                                Text("CLEAR ALL")
                                    .font(.caption.weight(.bold))
                                    .tracking(0.6)
                                    .foregroundStyle(Theme.cta)
                                    .padding(.horizontal, Theme.Space.sm)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear all filters")
                            .accessibilityHint("Resets course filter and search")
                        }
                    }
                    .padding(.vertical, Theme.Space.xs)
                }
                .listRowInsets(EdgeInsets(top: Theme.Space.sm, leading: Theme.Space.lg, bottom: Theme.Space.sm, trailing: Theme.Space.lg))
                .listRowBackground(Color.clear)
            } footer: {
                Text("Search above by recipe name or ingredient.")
                    .accessibilityAddTraits(.isStaticText)
            }
            if filtered.isEmpty {
                Section {
                    VStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "magnifyingglass", tint: Theme.muted, size: 48)
                        Text("NO MATCHES")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.muted)
                        Text("No recipes match")
                            .font(Theme.display(.headline))
                            .foregroundStyle(Theme.ink)
                        Text("Try another course filter or search term.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                        Button {
                            course = "all"
                            query = ""
                            searchQuery = ""
                            displayLimit = pageSize
                        } label: {
                            Theme.MetaPill(text: "CLEAR FILTERS", tone: .cta)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear filters")
                        .accessibilityHint("Resets course filter and search")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.xxl)
                    .accessibilityElement(children: .contain)
                }
            } else {
            ForEach(results) { recipe in
                NavigationLink {
                    RecipeDetailView(
                        recipe: recipe,
                        scaledServings: recipe.baseServings,
                        reason: recipe.course.capitalized,
                        proteinG: recipe.proteinGPerServing,
                        calories: recipe.caloriesPerServing
                    )
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        Theme.IconWell(
                            systemImage: courseIcon(recipe.course),
                            tint: Theme.cta,
                            size: 40
                        )
                        VStack(alignment: .leading, spacing: Theme.Space.sm - 2) {
                            Text(Theme.recipeDisplayName(recipe.name)).font(.body.weight(.semibold))
                            HStack(spacing: Theme.Space.sm) {
                                Theme.MetaPill(
                                    text: recipe.course.isEmpty ? "recipe" : recipe.course,
                                    tone: .accent
                                )
                                Text(recipe.sourceCitation)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                                if recipe.webLink != nil {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .foregroundStyle(Theme.cta)
                                }
                            }
                        }
                    }
                    .padding(.vertical, Theme.Space.xs / 2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(browseRecipeRowLabel(recipe))
                .accessibilityHint("Opens recipe details")
            }
            if hasMore {
                Button("Show more recipes (\(filtered.count - displayLimit) remaining)") {
                    displayLimit += pageSize
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.cta)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("Show more recipes")
                .accessibilityHint("Loads \(min(pageSize, filtered.count - displayLimit)) more of \(filtered.count) matching recipes")
            }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle("Recipes")
        .searchable(text: $query, prompt: "Chicken, sheet pan, mushrooms…")
        .onChange(of: query) { _, newValue in
            scheduleSearchQuery(newValue)
        }
        .onChange(of: course) { _, _ in displayLimit = pageSize }
        .onDisappear { searchDebounceTask?.cancel() }
    }

    private func courseIcon(_ course: String) -> String {
        switch course.lowercased() {
        case "main": return "fork.knife"
        case "side": return "leaf"
        case "dessert": return "birthday.cake"
        default: return "book"
        }
    }

    private func scheduleSearchQuery(_ newValue: String) {
        searchDebounceTask?.cancel()
        displayLimit = pageSize
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searchQuery = ""
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(searchDebounceMs))
            guard !Task.isCancelled else { return }
            searchQuery = newValue
        }
    }

    private func browseRecipeRowLabel(_ recipe: Recipe) -> String {
        let name = Theme.recipeDisplayName(recipe.name)
        let courseLabel = recipe.course.isEmpty ? "recipe" : recipe.course
        var parts = [name, courseLabel]
        if !recipe.sourceCitation.isEmpty {
            parts.append(recipe.sourceCitation)
        }
        if recipe.webLink != nil {
            parts.append("web link available")
        }
        return parts.joined(separator: ", ")
    }
}
