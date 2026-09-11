import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared chrome
// Patterns: Apple Fitness settings hub (avatar + stacked list), Tonal/WHOOP preference pages
// (hero blurb, status toast, primary connect CTAs), system Settings deep-links when denied.

func settingsDetailSectionHeader(_ title: String) -> some View {
    Text(title.uppercased())
        .font(.caption2.weight(.bold))
        .tracking(0.8)
        .foregroundStyle(Theme.muted)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
}

struct SettingsCategoryRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    /// Place tint for identity/nav destinations; CTA for action-heavy hubs.
    var tint: Color = Theme.accent
    var status: String? = nil
    var statusTone: Theme.MetaPill.MetaTone = .neutral

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Theme.IconWell(systemImage: systemImage, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let status {
                Theme.MetaPill(text: status, tone: statusTone)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.map { "\(title). \(subtitle). \($0)" } ?? "\(title). \(subtitle)")
    }
}

/// Compact page intro under the nav title (Fitness / Tonal preference pattern).
struct SettingsPageHero: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Theme.IconWell(systemImage: systemImage, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

struct SettingsStatusBanner: View {
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tone: Theme.MetaPill.MetaTone = .accent

    private var tint: Color {
        switch tone {
        case .accent: return Theme.accent
        case .cta: return Theme.cta
        case .danger: return Theme.danger
        case .neutral: return Theme.muted
        }
    }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct SettingsOpenSystemSettingsButton: View {
    var label: String = "Open iOS Settings"

    var body: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            Label(label, systemImage: "gear")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.cta)
        }
        .accessibilityHint("Opens Cadence permissions in the iOS Settings app")
    }
}

extension View {
    func settingsFormChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .tint(Theme.cta)
            .scrollDismissesKeyboard(.interactively)
            .cadenceDismissKeyboardOnTap()
    }

    /// Tap outside fields to dismiss the system keyboard (and custom focus).
    func cadenceDismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}

// MARK: - Profile & goals

struct ProfileGoalsSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Bindable var profile: UserProfileEntity
    @AppStorage("usesMetricUnits") private var usesMetricUnits = false
    @State private var statusMessage: String?

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
                SettingsPageHero(
                    systemImage: "person.crop.circle",
                    title: "Body & goals",
                    subtitle: "Used to calculate BMR, TDEE, and daily macro targets.",
                    tint: Theme.accent
                )
            }

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
            } header: {
                settingsDetailSectionHeader("Profile")
            }

            Section {
                Button {
                    Task { await recalculate(useAI: false) }
                } label: {
                    Label(
                        appModel.isComputingMacros ? "Working…" : "Recalculate macros",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cta)
                }
                .disabled(appModel.isComputingMacros)
                .accessibilityHint("Updates protein and calorie targets from profile")

                if appModel.hasKeyForSelectedProvider() {
                    Button {
                        Task { await recalculate(useAI: true) }
                    } label: {
                        Label("Recalculate with AI", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.cta)
                    }
                    .disabled(appModel.isComputingMacros)
                    .accessibilityHint("Uses your AI provider to refine macro targets")
                }
            } footer: {
                Text("Results show under Nutrition targets. Recalculate after changing weight, activity, or goal.")
                    .accessibilityAddTraits(.isStaticText)
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("Profile & goals")
        .settingsFormChrome()
    }

    private func recalculate(useAI: Bool) async {
        await appModel.recomputeMacros(profile: profile, useAI: useAI)
        statusMessage = useAI
            ? "Macros updated with AI · \(Int(profile.targetCalories.rounded())) kcal"
            : "Macros updated · \(Int(profile.targetCalories.rounded())) kcal · \(Int(profile.targetProteinG.rounded()))g protein"
    }
}

// MARK: - Lift & workouts

struct LiftWorkoutsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity

    private var showWorkout: Binding<Bool> {
        Binding(
            get: { CadenceAppsPreferences.isVisible(.workout) && profile.workoutsEnabled },
            set: { on in
                profile.workoutsEnabled = on
                CadenceAppsPreferences.setVisible(.workout, on)
                Task { await PlannerSyncCoordinator.shared.refreshAll(in: modelContext) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                SettingsPageHero(
                    systemImage: "dumbbell",
                    title: "Lift on the dial",
                    subtitle: "Hide the program without deleting past workout logs.",
                    tint: Theme.accent
                )
            }

            Section {
                Toggle("Show workout schedule", isOn: showWorkout)
                    .accessibilityLabel("Show workout schedule, \(showWorkout.wrappedValue ? "on" : "off")")
                    .accessibilityHint("Shows or hides Lift on the wheel, Today, Habits, and Calendar")
            } footer: {
                Text("Also editable from the swipe-up app grid or Apps & wheel. Past workout logs are kept.")
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
            Section {
                SettingsPageHero(
                    systemImage: "fork.knife",
                    title: "How you cook",
                    subtitle: "Diet filters, tools, and cookbooks shape weekly meal plans.",
                    tint: Theme.cta
                )
            }

            Section {
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
            } header: {
                settingsDetailSectionHeader("Diet & restrictions")
            }

            Section {
                VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
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
            } header: {
                settingsDetailSectionHeader("Cooking preferences")
            }

            Section {
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
            } header: {
                settingsDetailSectionHeader("Cookbooks")
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
            } header: {
                settingsDetailSectionHeader("Variety")
            }
        }
        .navigationTitle("Meals & cooking")
        .settingsFormChrome()
    }
}

// MARK: - Nutrition targets

struct NutritionTargetsSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Bindable var profile: UserProfileEntity
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                SettingsPageHero(
                    systemImage: "chart.bar.doc.horizontal",
                    title: "Daily targets",
                    subtitle: "Edit calories and protein directly, or recalculate from your profile.",
                    tint: Theme.cta
                )
            }

            Section {
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
            } header: {
                settingsDetailSectionHeader("Daily targets")
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
                settingsDetailSectionHeader("Calculated")
            }

            Section {
                Button {
                    Task {
                        await appModel.recomputeMacros(profile: profile, useAI: false)
                        statusMessage = "Recalculated from profile · \(Int(profile.targetCalories.rounded())) kcal"
                    }
                } label: {
                    Label(
                        appModel.isComputingMacros ? "Working…" : "Recalculate from profile",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cta)
                }
                .disabled(appModel.isComputingMacros)
                .accessibilityHint("Updates targets from weight, activity, and goal")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
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
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                SettingsPageHero(
                    systemImage: "book.closed",
                    title: "Recipes & plan",
                    subtitle: "Browse cookbooks or rebuild this week’s meals and shop list.",
                    tint: Theme.accent
                )
            }

            Section {
                NavigationLink {
                    BrowseView()
                } label: {
                    Label("Browse cookbooks", systemImage: "book")
                }
                .accessibilityHint("Browse bundled recipe cookbooks")
                LabeledContent("Bundled recipes", value: "\(appModel.recipeDB.count())")
            } header: {
                settingsDetailSectionHeader("Library")
            }

            Section {
                Button {
                    if grocery.contains(where: { !$0.isChecked }) {
                        confirmRegenerate = true
                    } else {
                        Task { await regenerate() }
                    }
                } label: {
                    Label(
                        appModel.isGeneratingPlan ? "Working…" : "Regenerate this week’s plan",
                        systemImage: "arrow.clockwise"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cta)
                }
                .disabled(appModel.isGeneratingPlan)
                .accessibilityHint("Creates a new weekly meal plan and shop list")
            } footer: {
                Text("Regenerating replaces this week’s meals and rebuilds the shop list.")
                    .accessibilityAddTraits(.isStaticText)
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
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
        statusMessage = "Weekly plan regenerated."
    }
}

// MARK: - AI

struct AISettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var statusMessage: String?
    @State private var statusTone: Theme.MetaPill.MetaTone = .accent
    @State private var statusIcon = "checkmark.circle.fill"

    var body: some View {
        Form {
            Section {
                SettingsPageHero(
                    systemImage: "sparkles",
                    title: "Optional AI",
                    subtitle: "Cadence meal plans work offline. Keys are only used when you choose AI.",
                    tint: Theme.cta
                )
            }

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
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Anthropic API key")
                    .accessibilityHint("Stored securely in Keychain when saved")
                SecureField("OpenAI key (sk-…)", text: $appModel.openAIKeyDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("OpenAI API key")
                    .accessibilityHint("Stored securely in Keychain when saved")
                Button {
                    saveKeys()
                } label: {
                    Label("Save keys to Keychain", systemImage: "key.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                }
                .accessibilityHint("Stores API keys securely on this device")
            } header: {
                settingsDetailSectionHeader("Providers")
            } footer: {
                Text(appModel.hasKeyForSelectedProvider()
                     ? "\(appModel.selectedProvider.title) key is ready for macro recalculation and News digests."
                     : "Paste a key, then Save. Empty keys clear Keychain for that provider.")
                    .accessibilityAddTraits(.isStaticText)
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("AI")
        .settingsFormChrome()
    }

    private func saveKeys() {
        do {
            try appModel.saveAPIKeys()
            statusTone = .accent
            statusIcon = "checkmark.circle.fill"
            statusMessage = appModel.hasKeyForSelectedProvider()
                ? "Saved · \(appModel.selectedProvider.title) ready"
                : "Saved · no active key for \(appModel.selectedProvider.title)"
        } catch {
            statusTone = .danger
            statusIcon = "exclamationmark.triangle.fill"
            statusMessage = error.localizedDescription
        }
    }
}
