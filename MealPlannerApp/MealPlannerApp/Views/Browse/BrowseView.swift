import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var query = ""
    @State private var course = "all"
    @State private var displayLimit = 50

    private let courses = ["all", "main", "side", "dessert", "other"]
    private let pageSize = 50

    private var filtered: [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces)
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
                Picker("Course", selection: $course) {
                    ForEach(courses, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Course filter, \(course.capitalized)")
                .accessibilityValue(course.capitalized)
                .accessibilityHint("Filters recipes by course type")
            } footer: {
                Text("Search above by recipe name or ingredient.")
                    .accessibilityAddTraits(.isStaticText)
            }
            if filtered.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("No recipes match")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text("Try another course filter or search term.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No recipes match. Try another course filter or search term.")
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Theme.recipeDisplayName(recipe.name)).font(.body.weight(.medium))
                        HStack(spacing: 8) {
                            Theme.Pill(text: recipe.course.isEmpty ? "recipe" : recipe.course)
                            Text(recipe.sourceCitation)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            if recipe.webLink != nil {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
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
        .onChange(of: query) { _, _ in displayLimit = pageSize }
        .onChange(of: course) { _, _ in displayLimit = pageSize }
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
