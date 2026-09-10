import SwiftUI
import SwiftData

// MARK: - Shared chrome

struct SettingsCategoryRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

extension View {
    func settingsFormChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.canvas)
    }
}

// MARK: - Profile & goals

struct ProfileGoalsSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Bindable var profile: UserProfileEntity
    @AppStorage("usesMetricUnits") private var usesMetricUnits = false

    private var weightKgBinding: Binding<Double> {
        Binding(
            get: { profile.weightLbs / 2.20462 },
            set: { profile.weightLbs = max(1, $0 * 2.20462) }
        )
    }

    private var heightCmBinding: Binding<Double> {
        Binding(
            get: { profile.heightInches * 2.54 },
            set: { profile.heightInches = max(1, $0 / 2.54) }
        )
    }

    private var settingsWeightAccessibilityLabel: String {
        if usesMetricUnits {
            let kg = profile.weightLbs / 2.20462
            return "Weight, \(String(format: "%.1f", kg)) kilograms"
        }
        return "Weight, \(Int(profile.weightLbs.rounded())) pounds"
    }

    private var settingsHeightAccessibilityLabel: String {
        if usesMetricUnits {
            let cm = profile.heightInches * 2.54
            return "Height, \(Int(cm.rounded())) centimeters"
        }
        return "Height, \(Int(profile.heightInches.rounded())) inches"
    }

    var body: some View {
        Form {
            Section {
                Toggle("Use metric units", isOn: $usesMetricUnits)
                    .accessibilityLabel("Use metric units, \(usesMetricUnits ? "on" : "off")")
                    .accessibilityValue(usesMetricUnits ? "Metric units" : "Imperial units")
                    .accessibilityHint("Switches profile weight and height fields between pounds and inches or kilograms and centimeters")
                HStack {
                    Text(usesMetricUnits ? "Weight (kg)" : "Weight (lb)")
                    Spacer()
                    if usesMetricUnits {
                        TextField("75", value: weightKgBinding, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    } else {
                        TextField("165", value: $profile.weightLbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(settingsWeightAccessibilityLabel)
                .accessibilityHint("Used to calculate macro targets")
                HStack {
                    Text(usesMetricUnits ? "Height (cm)" : "Height (in)")
                    Spacer()
                    if usesMetricUnits {
                        TextField("178", value: heightCmBinding, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    } else {
                        TextField("70", value: $profile.heightInches, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(settingsHeightAccessibilityLabel)
                .accessibilityHint("Used to calculate macro targets")
                Stepper("Age: \(profile.age)", value: $profile.age, in: 14...90)
                    .accessibilityLabel("Age, \(profile.age)")
                    .accessibilityHint("Age used for macro calculations")
                Picker("Sex", selection: $profile.sexRaw) {
                    ForEach(BiologicalSex.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .accessibilityLabel("Sex, \(BiologicalSex(rawValue: profile.sexRaw)?.title ?? profile.sexRaw.capitalized)")
                .accessibilityHint("Used to calculate macro targets")
                Picker("Activity", selection: $profile.activityRaw) {
                    ForEach(ActivityLevel.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .accessibilityLabel("Activity, \(ActivityLevel(rawValue: profile.activityRaw)?.title ?? profile.activityRaw.capitalized)")
                .accessibilityHint("Adjusts calorie targets for daily movement")
                Picker("Goal", selection: $profile.goalRaw) {
                    ForEach(GoalType.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .accessibilityLabel("Goal, \(GoalType(rawValue: profile.goalRaw)?.title ?? profile.goalRaw.capitalized)")
                .accessibilityHint("Sets whether you cut, maintain, or bulk")
            }

            Section {
                Button(appModel.isComputingMacros ? "Updating…" : "Recalculate macros") {
                    Task { await appModel.recomputeMacros(profile: profile, useAI: false) }
                }
                .disabled(appModel.isComputingMacros)
                .accessibilityHint("Updates protein and calorie targets from profile")
                if appModel.hasKeyForSelectedProvider() {
                    Button("Recalculate with AI") {
                        Task { await appModel.recomputeMacros(profile: profile, useAI: true) }
                    }
                    .disabled(appModel.isComputingMacros)
                    .accessibilityHint("Uses your AI provider to refine macro targets")
                }
            } footer: {
                Text("Macro targets appear under Nutrition targets. Recalculate after changing weight, activity, or goal.")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .navigationTitle("Profile & goals")
        .settingsFormChrome()
    }
}

// MARK: - Lift & workouts

struct LiftWorkoutsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity

    var body: some View {
        Form {
            Section {
                Toggle("Show workout schedule", isOn: $profile.workoutsEnabled)
                    .accessibilityLabel("Show workout schedule, \(profile.workoutsEnabled ? "on" : "off")")
                    .accessibilityHint("Shows or hides Lift cards on Today, Habits, and Calendar")
                    .onChange(of: profile.workoutsEnabled) { _, _ in
                        Task { await PlannerSyncCoordinator.shared.refreshAll(in: modelContext) }
                    }
            } footer: {
                Text("Turn off to hide the Lift program, calendar workout chips, and workout reminders. Past workout logs are kept.")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .navigationTitle("Lift & workouts")
        .settingsFormChrome()
    }
}

// MARK: - Meals & cooking

struct MealsCookingSettingsView: View {
    @Bindable var profile: UserProfileEntity

    private let allSources = [
        "joy-of-cooking", "food-lab", "the-wok", "food-network-magazine",
        "nigella-express", "sheet-pan-suppers", "martha-one-pot",
        "salt-fat-acid-heat", "keep-it-simple", "based-cooking-web",
    ]

    var body: some View {
        Form {
            Section("Diet & restrictions") {
                Picker("Diet filter", selection: $profile.dietRaw) {
                    ForEach(DietProfile.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .accessibilityLabel("Diet filter, \(DietProfile(rawValue: profile.dietRaw)?.title ?? profile.dietRaw.capitalized)")
                .accessibilityHint("Filters recipes by dietary preference")
                TextField("Skip: tomato, cilantro, shellfish", text: $profile.dietaryRestrictionsText, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityLabel("Foods to skip")
                    .accessibilityValue(profile.dietaryRestrictionsText.isEmpty ? "Empty" : profile.dietaryRestrictionsText)
                    .accessibilityHint("Comma-separated foods to exclude from meal plans")
            }

            Section("Cooking preferences") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Simple")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text(RecipeComplexity.title(for: profile.cookingComplexity))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Anything")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(RecipeComplexity.clamped(profile.cookingComplexity)) },
                            set: { profile.cookingComplexity = Int($0.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    .accessibilityLabel("Cooking complexity, \(RecipeComplexity.title(for: profile.cookingComplexity))")
                    .accessibilityValue(RecipeComplexity.subtitle(for: profile.cookingComplexity))
                    .accessibilityHint("Adjusts how complex recipes can be in your meal plan")
                    Text(RecipeComplexity.subtitle(for: profile.cookingComplexity))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
                Stepper("Servings / recipe: \(profile.servingsPerRecipe)", value: $profile.servingsPerRecipe, in: 1...12)
                    .accessibilityLabel("Servings per recipe, \(profile.servingsPerRecipe)")
                    .accessibilityHint("Scales each dinner cook and the shop list amounts")
                ForEach(CookingTool.allCases) { tool in
                    Toggle(tool.title, isOn: Binding(
                        get: { profile.availableTools.contains(tool.storageKey) },
                        set: { on in
                            var set = Set(profile.availableTools)
                            if on { set.insert(tool.storageKey) } else { set.remove(tool.storageKey) }
                            if set.isEmpty { set.insert(CookingTool.stove.storageKey) }
                            profile.availableTools = Array(set).sorted()
                        }
                    ))
                    .accessibilityLabel("\(tool.title), \(profile.availableTools.contains(tool.storageKey) ? "on" : "off")")
                    .accessibilityHint("Includes or excludes recipes requiring \(tool.title.lowercased())")
                }
            }

            Section("Cookbooks") {
                ForEach(allSources, id: \.self) { source in
                    Toggle(Recipe.cookbookTitle(for: source), isOn: Binding(
                        get: { profile.enabledSources.contains(source) },
                        set: { on in
                            var set = Set(profile.enabledSources)
                            if on { set.insert(source) } else { set.remove(source) }
                            profile.enabledSources = Array(set).sorted()
                        }
                    ))
                    .accessibilityLabel("\(Recipe.cookbookTitle(for: source)), \(profile.enabledSources.contains(source) ? "on" : "off")")
                    .accessibilityHint("Includes or excludes recipes from this cookbook in meal plans")
                }
            }

            Section {
                Stepper(
                    "Avoid same recipe for \(profile.recipeCooldownDays) days",
                    value: $profile.recipeCooldownDays,
                    in: 7...60,
                    step: 7
                )
                .accessibilityLabel("Avoid same recipe, \(profile.recipeCooldownDays) days")
                .accessibilityHint("Minimum days before a recipe can repeat in your plan")
            }
        }
        .navigationTitle("Meals & cooking")
        .settingsFormChrome()
    }
}

// MARK: - Nutrition targets

struct NutritionTargetsSettingsView: View {
    @Bindable var profile: UserProfileEntity

    var body: some View {
        Form {
            Section("Daily targets") {
                HStack {
                    Text("Calories / day")
                    Spacer()
                    TextField("3000", value: $profile.targetCalories, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Calories per day, \(Int(profile.targetCalories.rounded()))")
                .accessibilityHint("Daily calorie target for meal planning")
                HStack {
                    Text("Protein / day (g)")
                    Spacer()
                    TextField("165", value: $profile.targetProteinG, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Protein grams per day, \(Int(profile.targetProteinG.rounded()))")
                .accessibilityHint("Daily protein target in grams")
            }

            Section {
                LabeledContent("BMR", value: String(format: "%.0f", profile.bmr))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("BMR, \(Int(profile.bmr.rounded())) calories per day")
                    .accessibilityAddTraits(.isStaticText)
                LabeledContent("TDEE", value: String(format: "%.0f", profile.tdee))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("TDEE, \(Int(profile.tdee.rounded())) calories per day")
                    .accessibilityAddTraits(.isStaticText)
                LabeledContent("Carbs", value: String(format: "%.0fg", profile.targetCarbsG))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Carbs, \(Int(profile.targetCarbsG.rounded())) grams per day")
                    .accessibilityAddTraits(.isStaticText)
                LabeledContent("Fat", value: String(format: "%.0fg", profile.targetFatG))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Fat, \(Int(profile.targetFatG.rounded())) grams per day")
                    .accessibilityAddTraits(.isStaticText)
                if !profile.rationale.isEmpty {
                    Text(profile.rationale)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityLabel("Macro rationale, \(profile.rationale)")
                        .accessibilityAddTraits(.isStaticText)
                }
            } header: {
                Text("Calculated")
            } footer: {
                Text("Update profile details and tap Recalculate macros under Profile & goals to refresh BMR and TDEE.")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .navigationTitle("Nutrition targets")
        .settingsFormChrome()
    }
}

// MARK: - Recipes & plan

struct RecipesPlanSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity
    @Query private var grocery: [GroceryItemEntity]
    @State private var confirmRegenerate = false

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    BrowseView()
                } label: {
                    Label("Browse cookbooks", systemImage: "book")
                }
                .accessibilityHint("Browse bundled recipe cookbooks")
                LabeledContent("Bundled recipes", value: "\(appModel.recipeDB.count())")
            }

            Section {
                Button("Regenerate current week’s plan") {
                    if grocery.contains(where: { !$0.isChecked }) {
                        confirmRegenerate = true
                    } else {
                        Task { await regenerate() }
                    }
                }
                .disabled(appModel.isGeneratingPlan)
                .accessibilityHint("Creates a new weekly meal plan and shop list")
            } footer: {
                Text("Regenerating replaces this week’s meals and rebuilds the shop list.")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .navigationTitle("Recipes & plan")
        .settingsFormChrome()
        .confirmationDialog("Replace grocery list?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Regenerate", role: .destructive) {
                Task { await regenerate() }
            }
            .accessibilityHint("Regenerates meal plan and clears unchecked shop items")
            Button("Cancel", role: .cancel) {}
                .accessibilityHint("Keeps current meal plan and shop list")
        } message: {
            Text("Unchecked grocery items will be cleared.")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func regenerate() async {
        _ = await appModel.generateWeeklyPlan(
            profile: profile,
            modelContext: modelContext,
            existingGroceryUnchecked: false
        )
    }
}

// MARK: - AI

struct AISettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $appModel.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Provider, \(appModel.selectedProvider.title)")
                .accessibilityHint("Chooses AI provider for macro recalculation")
                SecureField("Claude key (sk-ant-…)", text: $appModel.anthropicKeyDraft)
                    .accessibilityLabel("Anthropic API key")
                    .accessibilityHint("Stored securely in Keychain when saved")
                SecureField("OpenAI key (sk-…)", text: $appModel.openAIKeyDraft)
                    .accessibilityLabel("OpenAI API key")
                    .accessibilityHint("Stored securely in Keychain when saved")
                Button("Save keys to Keychain") {
                    try? appModel.saveAPIKeys()
                }
                .accessibilityHint("Stores API keys securely on this device")
            } footer: {
                Text("AI is optional. Cadence works offline for meal planning; keys are only used when you choose AI macro recalculation.")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .navigationTitle("AI")
        .settingsFormChrome()
    }
}
