import SwiftUI
import SwiftData

/// Settings hub — Apple Fitness pattern: profile card + searchable stacked categories.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfileEntity
    @State private var path = NavigationPath()
    @State private var searchText = ""

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        NavigationLink(value: SettingsRoute.profile) {
                            profileCard
                        }
                        .listRowInsets(EdgeInsets(top: Theme.Space.sm, leading: Theme.Space.md, bottom: Theme.Space.sm, trailing: Theme.Space.md))
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        SettingsQuickTweaks(path: $path)
                    }
                }

                if showsSection(.you) {
                    Section {
                        if matches(.profile) {
                            NavigationLink(value: SettingsRoute.profile) {
                                SettingsCategoryRow(
                                    title: "Profile & goals",
                                    subtitle: profileGoalsSubtitle,
                                    systemImage: "person.crop.circle",
                                    tint: Theme.accent
                                )
                            }
                        }
                        if matches(.nutrition) {
                            NavigationLink(value: SettingsRoute.nutrition) {
                                SettingsCategoryRow(
                                    title: "Nutrition targets",
                                    subtitle: nutritionSubtitle,
                                    systemImage: "chart.bar.doc.horizontal",
                                    tint: Theme.cta,
                                    status: "\(Int(profile.targetCalories.rounded())) kcal",
                                    statusTone: .cta
                                )
                            }
                        }
                    } header: {
                        settingsSectionHeader("You")
                    }
                }

                if showsSection(.apps) {
                    Section {
                        if matches(.apps) {
                            NavigationLink(value: SettingsRoute.apps) {
                                SettingsCategoryRow(
                                    title: "Apps & wheel",
                                    subtitle: appsSubtitle,
                                    systemImage: "square.grid.2x2",
                                    tint: Theme.accent,
                                    status: "\(CadenceAppsPreferences.orderedVisibleDialDestinations.count)",
                                    statusTone: .accent
                                )
                            }
                        }
                        if matches(.meals) {
                            NavigationLink(value: SettingsRoute.meals) {
                                SettingsCategoryRow(
                                    title: "Meals & cooking",
                                    subtitle: mealsSubtitle,
                                    systemImage: "fork.knife",
                                    tint: Theme.cta
                                )
                            }
                        }
                        if matches(.recipes) {
                            NavigationLink(value: SettingsRoute.recipes) {
                                SettingsCategoryRow(
                                    title: "Recipes & weekly plan",
                                    subtitle: recipesSubtitle,
                                    systemImage: "book.closed",
                                    tint: Theme.accent
                                )
                            }
                        }
                        if matches(.lift) {
                            NavigationLink(value: SettingsRoute.lift) {
                                SettingsCategoryRow(
                                    title: "Lift & workouts",
                                    subtitle: liftSubtitle,
                                    systemImage: "dumbbell",
                                    tint: Theme.accent,
                                    status: CadenceAppsPreferences.isVisible(.workout) && profile.workoutsEnabled ? "On" : "In Body",
                                    statusTone: .accent
                                )
                            }
                        }
                        if matches(.spend) {
                            NavigationLink(value: SettingsRoute.spend) {
                                SettingsCategoryRow(
                                    title: "Spend & Teller",
                                    subtitle: spendSubtitle,
                                    systemImage: "creditcard",
                                    tint: Theme.cta,
                                    status: SpendPreferences.isEnabled ? (SpendPreferences.isConfigured ? "Linked" : "Setup") : "Hidden",
                                    statusTone: SpendPreferences.isEnabled ? .cta : .neutral
                                )
                            }
                        }
                        if matches(.health) {
                            NavigationLink(value: SettingsRoute.health) {
                                SettingsCategoryRow(
                                    title: "Body",
                                    subtitle: healthSubtitle,
                                    systemImage: "heart.text.square",
                                    tint: Theme.accent,
                                    status: HealthPreferences.isEnabled ? (HealthPreferences.didRequestAuthorization ? "Linked" : "Connect") : "Hidden",
                                    statusTone: HealthPreferences.isEnabled ? .accent : .neutral
                                )
                            }
                        }
                        if matches(.news) {
                            NavigationLink(value: SettingsRoute.news) {
                                SettingsCategoryRow(
                                    title: "News digest",
                                    subtitle: newsSubtitle,
                                    systemImage: "newspaper",
                                    tint: Theme.cta,
                                    status: NewsPreferences.isEnabled ? (NewsPreferences.hasAIKey ? "AI" : "RSS") : "Hidden",
                                    statusTone: NewsPreferences.isEnabled ? .cta : .neutral
                                )
                            }
                        }
                    } header: {
                        settingsSectionHeader("Apps")
                    }
                }

                if showsSection(.integrations) {
                    Section {
                        if matches(.reminders) {
                            NavigationLink(value: SettingsRoute.reminders) {
                                SettingsCategoryRow(
                                    title: "Reminders",
                                    subtitle: remindersSubtitle,
                                    systemImage: "bell.badge",
                                    tint: Theme.cta,
                                    status: PlannerPreferences.notificationsEnabled ? "On" : "Off",
                                    statusTone: PlannerPreferences.notificationsEnabled ? .cta : .neutral
                                )
                            }
                        }
                        if matches(.calendar) {
                            NavigationLink(value: SettingsRoute.calendar) {
                                SettingsCategoryRow(
                                    title: "Calendar sync",
                                    subtitle: calendarSubtitle,
                                    systemImage: "calendar.badge.clock",
                                    tint: Theme.accent
                                )
                            }
                        }
                        if matches(.ai) {
                            NavigationLink(value: SettingsRoute.ai) {
                                SettingsCategoryRow(
                                    title: "AI",
                                    subtitle: aiSubtitle,
                                    systemImage: "sparkles",
                                    tint: Theme.cta,
                                    status: appModel.hasKeyForSelectedProvider() ? "Key" : "Optional",
                                    statusTone: appModel.hasKeyForSelectedProvider() ? .cta : .neutral
                                )
                            }
                        }
                    } header: {
                        settingsSectionHeader("Integrations")
                    }
                }

                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        LabeledContent("App") {
                            Text("Cadence")
                                .foregroundStyle(Theme.ink)
                        }
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            LabeledContent("Version", value: version)
                        }
                        Text("Meal planning, workouts, habits, and optional Spend, Health, and News — all on one dial.")
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

    private var profileCard: some View {
        HStack(spacing: Theme.Space.md + 2) {
            Theme.IconWell(systemImage: "person.fill", tint: Theme.accent, size: 56)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Your Cadence")
                    .font(Theme.title(.title3))
                    .foregroundStyle(Theme.ink)
                Text(profileGoalsSubtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                Theme.MetaPill(text: nutritionSubtitle, tone: .cta)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, Theme.Space.sm)
        .padding(.horizontal, Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .shadow(color: Theme.cardShadow, radius: 8, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Cadence. \(profileGoalsSubtitle). \(nutritionSubtitle)")
        .accessibilityHint("Opens profile and goals")
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
        case .apps:
            AppsSettingsView(profile: profile)
        case .spend:
            SpendSettingsView()
        case .health:
            HealthSettingsView()
        case .news:
            NewsSettingsView()
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

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }

    private enum HubSection { case you, apps, integrations }

    private var filteredRoutes: [SettingsRoute] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return SettingsSearchMatch.catalog.map(\.route) }
        return SettingsSearchMatch.matches(query: q).map(\.route)
    }

    private func matches(_ route: SettingsRoute) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        return filteredRoutes.contains(route)
    }

    private func showsSection(_ section: HubSection) -> Bool {
        switch section {
        case .you: return matches(.profile) || matches(.nutrition)
        case .apps:
            return matches(.apps) || matches(.meals) || matches(.recipes) || matches(.lift)
                || matches(.spend) || matches(.health) || matches(.news)
        case .integrations:
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

    private var recipesSubtitle: String {
        let cookbooks = profile.enabledSources.isEmpty
            ? "All cookbooks"
            : "\(profile.enabledSources.count) cookbooks"
        return "\(cookbooks) · \(appModel.recipeDB.count()) recipes"
    }

    private var liftSubtitle: String {
        profile.workoutsEnabled ? "On Body · Lift tab" : "Hidden from Body"
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
        return SpendPreferences.isConfigured ? "Teller configured" : "Connect Teller"
    }

    private var newsSubtitle: String {
        if !NewsPreferences.isEnabled { return "Hidden from wheel" }
        return NewsPreferences.hasAIKey ? "AI digests on" : "RSS · add AI key for briefs"
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

private struct SettingsQuickTweaks: View {
    @Binding var path: NavigationPath

    var body: some View {
        HStack(spacing: Theme.Space.sm + 2) {
            quickChip("Units", icon: "ruler") {
                path.append(SettingsRoute.profile)
            }
            quickChip("Reminders", icon: "bell") {
                path.append(SettingsRoute.reminders)
            }
            quickChip("Meals", icon: "fork.knife") {
                path.append(SettingsRoute.meals)
            }
        }
        .listRowInsets(EdgeInsets(top: Theme.Space.sm, leading: Theme.Space.md, bottom: Theme.Space.sm, trailing: Theme.Space.md))
        .accessibilityElement(children: .contain)
    }

    private func quickChip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.sm) {
                Theme.IconWell(systemImage: icon, tint: Theme.cta, size: 36)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title.lowercased()) settings")
    }
}
