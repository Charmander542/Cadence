import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @Bindable var profile: UserProfileEntity
    @State private var step = 0
    @AppStorage("usesMetricUnits") private var usesMetricUnits = false

    private var progress: Double { Double(step + 1) / 3.0 }

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

    private var onboardingWeightAccessibilityLabel: String {
        if usesMetricUnits {
            let kg = profile.weightLbs / 2.20462
            return "Weight, \(String(format: "%.1f", kg)) kilograms"
        }
        return "Weight, \(Int(profile.weightLbs.rounded())) pounds"
    }

    private var onboardingHeightAccessibilityLabel: String {
        if usesMetricUnits {
            let cm = profile.heightInches * 2.54
            return "Height, \(Int(cm.rounded())) centimeters"
        }
        return "Height, \(Int(profile.heightInches.rounded())) inches"
    }

    private var onboardingStepTitle: String {
        switch step {
        case 0: return "Welcome"
        case 1: return "Goals"
        default: return "Preferences"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProgressView(value: progress) {
                        Text("Step \(step + 1) of 3")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Onboarding progress, step \(step + 1) of 3, \(onboardingStepTitle)")
                    .accessibilityValue("\(Int(progress * 100)) percent complete")
                }

                if step == 0 {
                    Section {
                        VStack(spacing: 12) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            Text("Cadence")
                                .font(.title2.weight(.bold))
                            Text("Your day, in rhythm.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isStaticText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Cadence. Your day, in rhythm.")
                    }
                    Section("You") {
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
                        .accessibilityLabel(onboardingWeightAccessibilityLabel)
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
                        .accessibilityLabel(onboardingHeightAccessibilityLabel)
                        .accessibilityHint("Used to calculate macro targets")
                        Stepper("Age: \(profile.age)", value: $profile.age, in: 14...90)
                            .accessibilityLabel("Age, \(profile.age)")
                            .accessibilityHint("Age used for macro calculations")
                        Picker("Sex", selection: $profile.sexRaw) {
                            ForEach(BiologicalSex.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        .accessibilityLabel("Sex, \(BiologicalSex(rawValue: profile.sexRaw)?.title ?? profile.sexRaw.capitalized)")
                        .accessibilityHint("Used to calculate macro targets")
                    }
                } else if step == 1 {
                    Section("Activity & goal") {
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
                        Stepper("Servings / batch: \(profile.servingsPerRecipe)", value: $profile.servingsPerRecipe, in: 1...12)
                            .accessibilityLabel("Servings per batch, \(profile.servingsPerRecipe)")
                            .accessibilityHint("Default batch size for generated recipes")
                        Text("Servings per cooked batch — scales each dinner and the shop list.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    Section("Cooking tools I have") {
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
                    Section("Cooking style") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(RecipeComplexity.title(for: profile.cookingComplexity))
                                .font(.headline)
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
                    }
                } else {
                    Section("Foods to skip") {
                        TextField("tomato, cilantro, shellfish", text: $profile.dietaryRestrictionsText, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityLabel("Foods to skip")
                            .accessibilityValue(profile.dietaryRestrictionsText.isEmpty ? "Empty" : profile.dietaryRestrictionsText)
                            .accessibilityHint("Comma-separated foods to exclude from meal plans")
                        Text("Tomato skips fresh, cherry, grape, roma, and diced tomatoes. Sauce and paste still show up.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    Section("Diet") {
                        Picker("Filter", selection: $profile.dietRaw) {
                            ForEach(DietProfile.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        .accessibilityLabel("Diet filter, \(DietProfile(rawValue: profile.dietRaw)?.title ?? profile.dietRaw.capitalized)")
                        .accessibilityHint("Filters recipes by dietary preference")
                    }
                    Section {
                        Text("AI keys and macro tuning live in Settings after setup.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas)
            .navigationTitle(step == 0 ? "Welcome" : step == 1 ? "Goals" : "Preferences")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if step < 2 {
                        Button("Next") { step += 1 }
                            .accessibilityHint("Continues to the next setup step")
                    } else {
                        Button(appModel.isComputingMacros ? "Working…" : "Finish") {
                            Task { await finishOnboarding() }
                        }
                        .disabled(appModel.isComputingMacros)
                        .accessibilityHint("Completes onboarding and opens the app")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .accessibilityHint("Returns to the previous setup step")
                    } else {
                        Button("Skip setup") {
                            Task { await finishOnboarding() }
                        }
                        .foregroundStyle(Theme.muted)
                        .accessibilityHint("Completes setup with default preferences")
                    }
                }
                if step == 1 {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Skip to finish") {
                            step = 2
                        }
                        .font(.footnote)
                        .accessibilityHint("Skips goal details and opens preferences")
                    }
                }
            }
        }
    }

    private func finishOnboarding() async {
        await appModel.recomputeMacros(profile: profile, useAI: false)
    }
}
