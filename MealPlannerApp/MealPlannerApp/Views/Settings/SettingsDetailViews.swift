import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared chrome
// Mobbin detail patterns: [Gentler Streak Settings](https://mobbin.com/screens/07d9ec6a-cb0e-4cb3-9a3c-4505d32f74ab)
// (grouped form + footers, no hero), [Telegram Data](https://mobbin.com/screens/454ba629-4f5e-4c00-ae0a-a0fa1c4325ee)
// (intro as section footer), [Future Pro App Settings](https://mobbin.com/screens/89b8a60f-b3fc-4dc9-beba-8c329632d511)
// (toggle + blurb), [Wispr Flow](https://mobbin.com/screens/af36a034-bc88-48f0-90eb-8af699250f0d)
// (inline title + section cards).

func settingsDetailSectionHeader(_ title: String) -> some View {
    Text(title.uppercased())
        .font(.caption2.weight(.bold))
        .tracking(0.8)
        .foregroundStyle(Theme.muted)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
}

/// Alma-style page blurb — use as the first section’s `footer`, not a separate hero card.
func settingsDetailIntro(_ text: String) -> some View {
    Text(text)
        .font(.footnote)
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isStaticText)
}

@ViewBuilder
func settingsCTALabel(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.cta)
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
            // Amie: saturated circular glyph wells, white symbol
            ZStack {
                Circle()
                    .fill(tint)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: Theme.Space.sm)
            if let status {
                Text(status)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.map { "\(title). \(subtitle). \($0)" } ?? "\(title). \(subtitle)")
        .contentShape(Rectangle())
    }
}

/// Compact page intro — Bevel/WHOOP: one blurb under the nav title, no second headline.
struct SettingsPageHero: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            ZStack {
                Circle().fill(tint.opacity(0.18))
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
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
            // Do NOT attach a SwiftUI tap gesture here — it steals NavigationLink taps.
            .scrollDismissesKeyboard(.interactively)
    }

    /// Dismiss keyboard on background taps without blocking buttons / NavigationLinks.
    /// Uses a UIKit gesture with `cancelsTouchesInView = false` — SwiftUI `TapGesture`
    /// / `simultaneousGesture` was swallowing Settings row taps.
    func cadenceDismissKeyboardOnTap() -> some View {
        background(CadenceKeyboardDismissInstaller())
    }
}

/// Installs a non-cancelling tap recognizer on the nearest hosting view.
private struct CadenceKeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        // Defer install until we're in the hierarchy so we can attach to a superview.
        DispatchQueue.main.async {
            context.coordinator.install(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var host: UIView?
        private var recognizer: UITapGestureRecognizer?

        func install(from probe: UIView) {
            // Prefer the scroll/form container, not the zero-size probe itself.
            guard let target = probe.superview ?? probe.window else { return }
            if host === target, recognizer != nil { return }
            if let old = recognizer {
                old.view?.removeGestureRecognizer(old)
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            tap.requiresExclusiveTouchType = false
            tap.delegate = self
            target.addGestureRecognizer(tap)
            host = target
            recognizer = tap
        }

        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            // Don't fight controls — only dismiss when tapping non-control chrome.
            if touch.view is UIControl { return false }
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                // UICollectionViewListCell / buttons inside list rows
                if String(describing: type(of: current)).contains("Button") { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
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
            } footer: {
                settingsDetailIntro("Body metrics and goals drive BMR, TDEE, and daily macro targets.")
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
                settingsDetailSectionHeader("Nutrition")
            }

            Section {
                Button {
                    Task { await recalculate(useAI: false) }
                } label: {
                    settingsCTALabel(
                        appModel.isComputingMacros ? "Working…" : "Recalculate macros",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(appModel.isComputingMacros)
                .accessibilityHint("Updates protein and calorie targets from profile")

                if appModel.hasKeyForSelectedProvider() {
                    Button {
                        Task { await recalculate(useAI: true) }
                    } label: {
                        settingsCTALabel("Recalculate with AI", systemImage: "sparkles")
                    }
                    .disabled(appModel.isComputingMacros)
                    .accessibilityHint("Uses your AI provider to refine macro targets")
                }
            } footer: {
                settingsDetailIntro("Edit targets above, or recalculate from weight, activity, and goal.")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
    }

    private func recalculate(useAI: Bool) async {
        await appModel.recomputeMacros(profile: profile, useAI: useAI)
        statusMessage = useAI
            ? "Macros updated with AI · \(Int(profile.targetCalories.rounded())) kcal"
            : "Macros updated · \(Int(profile.targetCalories.rounded())) kcal · \(Int(profile.targetProteinG.rounded()))g protein"
    }
}

// MARK: - Meals & cooking

struct MealsCookingSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfileEntity
    @Query private var grocery: [GroceryItemEntity]
    @State private var confirmRegenerate = false
    @State private var statusMessage: String?

    private let allSources = [
        "joy-of-cooking", "food-lab", "the-wok", "food-network-magazine",
        "nigella-express", "sheet-pan-suppers", "martha-one-pot",
        "salt-fat-acid-heat", "keep-it-simple", "based-cooking-web",
    ]

    var body: some View {
        Form {
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
                settingsDetailSectionHeader("Diet")
            } footer: {
                settingsDetailIntro("Diet filters, cookbooks, and regenerate this week’s plan — all in one place.")
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
                settingsDetailSectionHeader("Cooking")
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
                NavigationLink {
                    BrowseView()
                } label: {
                    Text("Browse cookbooks")
                }
                .accessibilityHint("Browse bundled recipe cookbooks")
                LabeledContent("Bundled recipes", value: "\(appModel.recipeDB.count())")
            } header: {
                settingsDetailSectionHeader("Plan & library")
            }

            Section {
                Button {
                    if grocery.contains(where: { !$0.isChecked }) {
                        confirmRegenerate = true
                    } else {
                        Task { await regenerate() }
                    }
                } label: {
                    settingsCTALabel(
                        appModel.isGeneratingPlan ? "Working…" : "Regenerate this week’s plan",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(appModel.isGeneratingPlan)
                .accessibilityHint("Creates a new weekly meal plan and shop list")
            } footer: {
                settingsDetailIntro("Regenerating replaces this week’s meals and rebuilds the shop list.")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("Meals")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Legacy aliases (search / deep links map here — no second pages)

/// Kept so older search hits for “nutrition” land on the merged You page.
struct NutritionTargetsSettingsView: View {
    @Bindable var profile: UserProfileEntity
    var body: some View { ProfileGoalsSettingsView(profile: profile) }
}

/// Kept so older search hits for “recipes” land on the merged Meals page.
struct RecipesPlanSettingsView: View {
    @Bindable var profile: UserProfileEntity
    var body: some View { MealsCookingSettingsView(profile: profile) }
}

/// Lift visibility lives in Apps & wheel (and Body). No separate settings page.
struct LiftWorkoutsSettingsView: View {
    @Bindable var profile: UserProfileEntity
    var body: some View { AppsSettingsView(profile: profile) }
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
                    settingsCTALabel("Save keys to Keychain", systemImage: "key.fill")
                }
                .accessibilityHint("Stores API keys securely on this device")
            } header: {
                settingsDetailSectionHeader("Providers")
            } footer: {
                settingsDetailIntro(
                    appModel.hasKeyForSelectedProvider()
                        ? "\(appModel.selectedProvider.title) key is ready for macros and News digests."
                        : "Meal plans work offline. Paste a key, then Save — empty keys clear Keychain."
                )
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
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
