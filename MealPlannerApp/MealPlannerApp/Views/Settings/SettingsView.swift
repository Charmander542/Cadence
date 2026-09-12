import SwiftUI
import SwiftData

/// Settings hub — Mobbin: [Amie](https://mobbin.com/screens/fc4d99c1-9a44-45a3-96e7-856a2ffa5909)
/// profile card + USER/APP sections; [Apple Fitness](https://mobbin.com/screens/f618bfa8-e996-4cb6-b7b8-f138e29963b1)
/// grouped cards; no duplicate destinations.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfileEntity
    @State private var path = NavigationPath()
    @State private var searchText = ""

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if !isSearching {
                    Section {
                        settingsLink(.profile) { profileCard }
                            .listRowInsets(EdgeInsets(
                                top: Theme.Space.md,
                                leading: Theme.Space.md,
                                bottom: Theme.Space.sm,
                                trailing: Theme.Space.md
                            ))
                            .listRowBackground(Color.clear)
                    }
                }

                if isSearching, matches(.profile) {
                    Section {
                        settingsLink(.profile) {
                            SettingsCategoryRow(
                                title: "You",
                                subtitle: profileGoalsSubtitle,
                                systemImage: "person.fill",
                                tint: Theme.accent,
                                status: "\(Int(profile.targetCalories.rounded())) kcal"
                            )
                        }
                    } header: {
                        settingsSectionHeader("You")
                    }
                }

                // Amie "APP SETTINGS" + Fitness "Health & Data" — dial + meals first
                if showsSection(.app) {
                    Section {
                        if matches(.apps) {
                            settingsLink(.apps) {
                                SettingsCategoryRow(
                                    title: "Apps & wheel",
                                    subtitle: appsSubtitle,
                                    systemImage: "square.grid.2x2",
                                    tint: Theme.accent,
                                    status: "\(CadenceAppsPreferences.orderedVisibleDialDestinations.count)"
                                )
                            }
                        }
                        if matches(.meals) {
                            settingsLink(.meals) {
                                SettingsCategoryRow(
                                    title: "Meals",
                                    subtitle: mealsSubtitle,
                                    systemImage: "fork.knife",
                                    tint: Color(red: 0.95, green: 0.55, blue: 0.2)
                                )
                            }
                        }
                    } header: {
                        settingsSectionHeader("App")
                    }
                }

                // Fitness-style module group — Body / Spend / News (one page each)
                if showsSection(.modules) {
                    Section {
                        if matches(.health) {
                            settingsLink(.health) {
                                SettingsCategoryRow(
                                    title: "Body",
                                    subtitle: healthSubtitle,
                                    systemImage: "heart.text.square",
                                    tint: Color(red: 0.95, green: 0.35, blue: 0.45),
                                    status: HealthPreferences.isEnabled
                                        ? (HealthPreferences.didRequestAuthorization ? "Linked" : "Connect")
                                        : "Off"
                                )
                            }
                        }
                        if matches(.spend) {
                            settingsLink(.spend) {
                                SettingsCategoryRow(
                                    title: "Spend",
                                    subtitle: spendSubtitle,
                                    systemImage: "creditcard",
                                    tint: Theme.cta,
                                    status: SpendPreferences.isEnabled
                                        ? (SpendPreferences.isConfigured ? "Linked" : "Setup")
                                        : "Off"
                                )
                            }
                        }
                        if matches(.news) {
                            settingsLink(.news) {
                                SettingsCategoryRow(
                                    title: "News",
                                    subtitle: newsSubtitle,
                                    systemImage: "newspaper",
                                    tint: Color(red: 0.45, green: 0.55, blue: 0.95),
                                    status: NewsPreferences.isEnabled
                                        ? (NewsPreferences.hasAIKey ? "AI" : "RSS")
                                        : "Off"
                                )
                            }
                        }
                        if matches(.focus) {
                            settingsLink(.focus) {
                                SettingsCategoryRow(
                                    title: "Focus",
                                    subtitle: focusSubtitle,
                                    systemImage: "target",
                                    tint: Theme.accent,
                                    status: FocusPreferences.isEnabled ? "On" : "Off"
                                )
                            }
                        }
                    } header: {
                        settingsSectionHeader("Modules")
                    }
                }

                // Amie "USER SETTINGS" / Integrations
                if showsSection(.connections) {
                    Section {
                        if matches(.reminders) {
                            settingsLink(.reminders) {
                                SettingsCategoryRow(
                                    title: "Reminders",
                                    subtitle: remindersSubtitle,
                                    systemImage: "bell.badge",
                                    tint: Color(red: 1.0, green: 0.55, blue: 0.2),
                                    status: PlannerPreferences.notificationsEnabled ? "On" : "Off"
                                )
                            }
                        }
                        if matches(.calendar) {
                            settingsLink(.calendar) {
                                SettingsCategoryRow(
                                    title: "Calendar",
                                    subtitle: calendarSubtitle,
                                    systemImage: "calendar",
                                    tint: Color(red: 0.95, green: 0.75, blue: 0.2)
                                )
                            }
                        }
                        if matches(.ai) {
                            settingsLink(.ai) {
                                SettingsCategoryRow(
                                    title: "AI",
                                    subtitle: aiSubtitle,
                                    systemImage: "sparkles",
                                    tint: Color(red: 0.65, green: 0.45, blue: 0.95),
                                    status: appModel.hasKeyForSelectedProvider() ? "Key" : "Optional"
                                )
                            }
                        }
                    } header: {
                        settingsSectionHeader("Connections")
                    }
                }

                if !isSearching {
                    // Calm: version footer under About
                    Section {
                        LabeledContent("Cadence") {
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                Text("v\(version)")
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Text("One dial for meals, Body, habits, and optional Spend & News.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                            .accessibilityAddTraits(.isStaticText)
                    } header: {
                        settingsSectionHeader("About")
                    }
                } else if filteredRoutes.isEmpty {
                    Section {
                        ContentUnavailableView.search(text: searchText)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .searchable(text: $searchText, prompt: "Search settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                settingsDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cta)
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

    private func settingsLink<Label: View>(
        _ route: SettingsRoute,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            path.append(canonicalRoute(route))
        } label: {
            HStack(spacing: Theme.Space.sm) {
                label()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func canonicalRoute(_ route: SettingsRoute) -> SettingsRoute {
        switch route {
        case .nutrition: return .profile
        case .recipes: return .meals
        case .lift: return .apps
        default: return route
        }
    }

    /// Amie profile header — avatar + name + secondary meta.
    private var profileCard: some View {
        HStack(spacing: Theme.Space.md) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                Image(systemName: "person.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(profileGoalsSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Text(nutritionSubtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.cta)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.md + 2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You. \(profileGoalsSubtitle). \(nutritionSubtitle)")
        .accessibilityHint("Opens profile, goals, and nutrition targets")
    }

    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute) -> some View {
        switch canonicalRoute(route) {
        case .profile, .nutrition:
            ProfileGoalsSettingsView(profile: profile)
        case .meals, .recipes:
            MealsCookingSettingsView(profile: profile)
        case .lift, .apps:
            AppsSettingsView(profile: profile)
        case .spend:
            SpendSettingsView()
        case .health:
            HealthSettingsView()
        case .news:
            NewsSettingsView()
        case .focus:
            FocusSettingsView()
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
        path.append(canonicalRoute(route))
        appModel.pendingSettingsRoute = nil
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }

    private enum HubSection { case app, modules, connections }

    private var filteredRoutes: [SettingsRoute] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return SettingsSearchMatch.hubRoutes }
        return SettingsSearchMatch.matches(query: q).map { canonicalRoute($0.route) }
            .reduce(into: [SettingsRoute]()) { result, route in
                if !result.contains(route) { result.append(route) }
            }
    }

    private func matches(_ route: SettingsRoute) -> Bool {
        if !isSearching { return SettingsSearchMatch.hubRoutes.contains(route) }
        return filteredRoutes.contains(canonicalRoute(route))
    }

    private func showsSection(_ section: HubSection) -> Bool {
        switch section {
        case .app:
            return matches(.apps) || matches(.meals)
        case .modules:
            return matches(.health) || matches(.spend) || matches(.news)
        case .connections:
            return matches(.reminders) || matches(.calendar) || matches(.ai)
        }
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

    private var healthSubtitle: String {
        if !HealthPreferences.isEnabled { return "Hidden from wheel" }
        return HealthPreferences.didRequestAuthorization ? "Apple Health · Bevel scores" : "Connect Apple Health"
    }

    private var appsSubtitle: String {
        let count = CadenceAppsPreferences.orderedVisibleDialDestinations.count
        return "\(count) on the dial · hold empty space to edit"
    }

    private var spendSubtitle: String {
        if !SpendPreferences.isEnabled { return "Hidden from wheel" }
        return SpendPreferences.isConfigured ? "Plaid configured" : "Connect Plaid"
    }

    private var newsSubtitle: String {
        if !NewsPreferences.isEnabled { return "Hidden from wheel" }
        return NewsPreferences.hasAIKey ? "AI digests on" : "RSS · add AI key for briefs"
    }

    private var focusSubtitle: String {
        if !FocusPreferences.isEnabled { return "Hidden from wheel" }
        return "\(FocusPreferences.pomoMinutes) min pomo · stopwatch"
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
        if parts.isEmpty { return "Pick calendars to sync" }
        return parts.joined(separator: " · ")
    }

    private var aiSubtitle: String {
        appModel.hasKeyForSelectedProvider()
            ? "\(appModel.selectedProvider.title) key saved"
            : "Optional · no key saved"
    }
}
