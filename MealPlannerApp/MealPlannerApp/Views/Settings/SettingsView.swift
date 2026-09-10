import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfileEntity
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if !PlannerPreferences.settingsIntroSeen {
                    Section {
                        Text("Tap a category to change profile, meals, reminders, or calendar sync.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }

                Section {
                    SettingsQuickTweaks(path: $path)
                }

                Section("You") {
                    NavigationLink(value: SettingsRoute.profile) {
                        SettingsCategoryRow(
                            title: "Profile & goals",
                            subtitle: profileGoalsSubtitle,
                            systemImage: "person.crop.circle"
                        )
                    }
                    NavigationLink(value: SettingsRoute.nutrition) {
                        SettingsCategoryRow(
                            title: "Nutrition targets",
                            subtitle: nutritionSubtitle,
                            systemImage: "chart.bar.doc.horizontal"
                        )
                    }
                }

                Section("Planning") {
                    NavigationLink(value: SettingsRoute.meals) {
                        SettingsCategoryRow(
                            title: "Meals & cooking",
                            subtitle: mealsSubtitle,
                            systemImage: "fork.knife"
                        )
                    }
                    NavigationLink(value: SettingsRoute.recipes) {
                        SettingsCategoryRow(
                            title: "Recipes & weekly plan",
                            subtitle: recipesSubtitle,
                            systemImage: "book.closed"
                        )
                    }
                    NavigationLink(value: SettingsRoute.lift) {
                        SettingsCategoryRow(
                            title: "Lift & workouts",
                            subtitle: liftSubtitle,
                            systemImage: "dumbbell"
                        )
                    }
                }

                Section("Integrations") {
                    NavigationLink(value: SettingsRoute.reminders) {
                        SettingsCategoryRow(
                            title: "Reminders",
                            subtitle: remindersSubtitle,
                            systemImage: "bell.badge"
                        )
                    }
                    NavigationLink(value: SettingsRoute.calendar) {
                        SettingsCategoryRow(
                            title: "Calendar sync",
                            subtitle: calendarSubtitle,
                            systemImage: "calendar.badge.clock"
                        )
                    }
                    NavigationLink(value: SettingsRoute.ai) {
                        SettingsCategoryRow(
                            title: "AI",
                            subtitle: aiSubtitle,
                            systemImage: "sparkles"
                        )
                    }
                }

                Section("About") {
                    LabeledContent("App") {
                        Text("Cadence")
                    }
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        LabeledContent("Version", value: version)
                    }
                    Text("Cadence is the product name. The Xcode target remains MealPlannerApp; bundle ID com.musclemeal.app is unchanged for data and widget compatibility.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                settingsDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes settings")
                }
            }
            .settingsFormChrome()
        }
        .onAppear(perform: openPendingRoute)
        .onDisappear {
            PlannerPreferences.settingsIntroSeen = true
        }
        .onChange(of: appModel.pendingSettingsRoute) { _, _ in
            openPendingRoute()
        }
    }

    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute) -> some View {
        switch route {
        case .profile:
            ProfileGoalsSettingsView(profile: profile)
        case .nutrition:
            NutritionTargetsSettingsView(profile: profile)
        case .meals:
            MealsCookingSettingsView(profile: profile)
        case .recipes:
            RecipesPlanSettingsView(profile: profile)
        case .lift:
            LiftWorkoutsSettingsView(profile: profile)
        case .reminders:
            RemindersSettingsView()
        case .calendar:
            CalendarSyncSettingsView()
        case .ai:
            AISettingsView()
        }
    }

    private func openPendingRoute() {
        guard let route = appModel.pendingSettingsRoute else { return }
        path.append(route)
        appModel.pendingSettingsRoute = nil
    }

    private var profileGoalsSubtitle: String {
        let goal = GoalType(rawValue: profile.goalRaw)?.title ?? "Goal"
        let activity = ActivityLevel(rawValue: profile.activityRaw)?.title ?? "Activity"
        return "Age \(profile.age) · \(goal) · \(activity)"
    }

    private var nutritionSubtitle: String {
        "\(Int(profile.targetCalories.rounded())) kcal · \(Int(profile.targetProteinG.rounded()))g protein"
    }

    private var mealsSubtitle: String {
        let diet = DietProfile(rawValue: profile.dietRaw)?.title ?? "Any diet"
        return "\(diet) · \(RecipeComplexity.title(for: profile.cookingComplexity))"
    }

    private var recipesSubtitle: String {
        "\(profile.enabledSources.count) cookbooks · \(appModel.recipeDB.count()) recipes"
    }

    private var liftSubtitle: String {
        profile.workoutsEnabled ? "Schedule on" : "Schedule off"
    }

    private var remindersSubtitle: String {
        PlannerPreferences.notificationsEnabled ? "Notifications on" : "Notifications off"
    }

    private var calendarSubtitle: String {
        let appleCount = PlannerPreferences.appleCalendarIdentifiers.count
        let googleCount = PlannerPreferences.googleCalendarIDs.count
        var parts: [String] = []
        if PlannerPreferences.syncTasksToAppleCalendar
            || PlannerPreferences.syncWorkoutsToAppleCalendar
            || PlannerPreferences.syncMealsToAppleCalendar {
            parts.append(appleCount == 1 ? "1 Apple calendar" : "\(appleCount) Apple calendars")
        }
        if GoogleCalendarService.shared.isSignedIn,
           PlannerPreferences.syncTasksToGoogleCalendar
            || PlannerPreferences.syncWorkoutsToGoogleCalendar
            || PlannerPreferences.syncMealsToGoogleCalendar {
            parts.append(googleCount == 1 ? "1 Google calendar" : "\(googleCount) Google calendars")
        }
        if parts.isEmpty {
            if GoogleCalendarService.shared.isConfigured && !GoogleCalendarService.shared.isSignedIn {
                return "Pick calendars to sync"
            }
            return "Pick calendars to sync"
        }
        return parts.joined(separator: " · ")
    }

    private var aiSubtitle: String {
        appModel.hasKeyForSelectedProvider()
            ? "\(appModel.selectedProvider.title) key saved"
            : "Optional · no key saved"
    }
}

private struct SettingsQuickTweaks: View {
    @Binding var path: NavigationPath

    var body: some View {
        HStack(spacing: 10) {
            quickChip("Units", icon: "ruler") {
                path.append(SettingsRoute.profile)
            }
            quickChip("Reminders", icon: "bell") {
                path.append(SettingsRoute.reminders)
            }
            quickChip("Meals", icon: "fork.knife") {
                path.append(SettingsRoute.recipes)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .accessibilityElement(children: .contain)
    }

    private func quickChip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.cta)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.cta.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title.lowercased()) settings")
    }
}
