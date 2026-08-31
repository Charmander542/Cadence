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
                Section {
                    Text("Tap a category to change profile, meals, reminders, or calendar sync.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
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
        var parts: [String] = []
        if PlannerPreferences.syncTasksToAppleCalendar
            || PlannerPreferences.syncWorkoutsToAppleCalendar
            || PlannerPreferences.syncMealsToAppleCalendar {
            parts.append("Apple")
        }
        if GoogleCalendarService.shared.isSignedIn,
           PlannerPreferences.syncTasksToGoogleCalendar
            || PlannerPreferences.syncWorkoutsToGoogleCalendar
            || PlannerPreferences.syncMealsToGoogleCalendar {
            parts.append("Google")
        }
        if parts.isEmpty {
            if GoogleCalendarService.shared.isConfigured && !GoogleCalendarService.shared.isSignedIn {
                return "Apple ready · Google not connected"
            }
            return "Not syncing"
        }
        return parts.joined(separator: " & ") + " sync on"
    }

    private var aiSubtitle: String {
        appModel.hasKeyForSelectedProvider()
            ? "\(appModel.selectedProvider.title) key saved"
            : "Optional · no key saved"
    }
}
