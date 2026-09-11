import SwiftUI
import SwiftData

/// Shared workout scheduling UI — surfaces the program on Today, Calendar, and Habits.
enum WorkoutIntegration {
    static func scheduledSession(on date: Date, workoutsEnabled: Bool = true) -> WorkoutSessionTemplate? {
        guard workoutsEnabled else { return nil }
        let weekday = Calendar.current.component(.weekday, from: date)
        return WorkoutProgram.scheduledSession(for: weekday)
    }

    static func workoutsEnabled(in context: ModelContext) -> Bool {
        guard CadenceAppsPreferences.isVisible(.workout) else { return false }
        let profiles = (try? context.fetch(FetchDescriptor<UserProfileEntity>())) ?? []
        return profiles.first?.workoutsEnabled ?? true
    }

    static func status(on date: Date = .now, plan: WorkoutPlanState) -> WorkoutScheduler.DayStatus {
        WorkoutScheduler.status(for: date, plan: plan)
    }

    static func defaultWorkoutHour(on date: Date) -> Int { 7 }

    static func workoutBlockDate(on day: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = defaultWorkoutHour(on: day)
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? day
    }
}

struct WorkoutDayCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfileEntity]
    @Query(sort: \WorkoutLogEntity.finishedAt, order: .reverse) private var logs: [WorkoutLogEntity]

    var date: Date = .now
    var compact = false
    var promoted = false

    @State private var planEntity: WorkoutPlanEntity?

    @State private var previewSession: WorkoutSessionTemplate?
    @State private var showLiftHub = false

    private var workoutsEnabled: Bool {
        CadenceAppsPreferences.isVisible(.workout) && (profiles.first?.workoutsEnabled ?? true)
    }

    private var scheduled: WorkoutSessionTemplate? {
        WorkoutIntegration.scheduledSession(on: date, workoutsEnabled: workoutsEnabled)
    }

    private var todaySession: WorkoutSessionTemplate? {
        let plan = planEntity?.decoded() ?? .fresh
        let status = WorkoutIntegration.status(on: date, plan: plan)
        if case .workout(let session) = status.kind { return session }
        return scheduled
    }

    private var dayLog: WorkoutLogEntity? {
        logs.first { Calendar.current.isDate($0.finishedAt, inSameDayAs: date) }
    }

    var body: some View {
        if !workoutsEnabled {
            EmptyView()
        } else {
            workoutCard
        }
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if let session = scheduled ?? todaySession {
                liftHubHeader {
                    HStack(spacing: 12) {
                        Image(systemName: dayLog != nil ? "checkmark.circle.fill" : "dumbbell.fill")
                            .font(compact ? .title3 : .title2)
                            .foregroundStyle(dayLog != nil ? Theme.accent : Theme.cta)
                            .frame(width: 36, height: 36)
                            .background((dayLog != nil ? Theme.accent : Theme.cta).opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name)
                                .font(compact ? .headline : .title3.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text(session.focus)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        if Calendar.current.isDateInToday(date) {
                            Text("TODAY")
                                .font(.caption.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }

                if Calendar.current.isDateInToday(date), dayLog == nil {
                    WorkoutTodayActions(session: session)
                } else if let log = dayLog, let workout = log.decoded() {
                    WorkoutLogSummary(workout: workout, log: log)
                }
            } else {
                liftHubHeader {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .font(compact ? .title3 : .title2)
                            .foregroundStyle(Theme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rest day")
                                .font(compact ? .headline : .title3.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text("Recover — or open Lift for the full program.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(compact ? 12 : 14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(promoted ? Theme.cta.opacity(0.22) : Theme.hairline, lineWidth: 1)
        )
        .shadow(color: promoted ? Theme.cta.opacity(0.16) : Theme.cardShadow, radius: promoted ? 14 : 10, y: promoted ? 5 : 4)
        .onAppear { planEntity = WorkoutStore.plan(in: modelContext) }
        .workoutPreviewSheet(session: $previewSession, planEntity: planEntity)
        .sheet(isPresented: $showLiftHub) {
            WorkoutHomeView()
        }
    }

    private func liftHubHeader<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button {
            showLiftHub = true
        } label: {
            HStack(spacing: 8) {
                content()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(workoutDayCardAccessibilityLabel)
        .accessibilityHint("Opens full Lift program and workout history")
    }

    private var workoutDayCardAccessibilityLabel: String {
        if let session = scheduled ?? todaySession {
            var parts = [session.name, session.focus]
            if dayLog != nil {
                parts.append("logged today")
            } else if Calendar.current.isDateInToday(date) {
                parts.append("scheduled today")
            }
            return parts.joined(separator: ", ")
        }
        return "Rest day. Recover, or open Lift for the full program."
    }

    private var cardBackground: AnyShapeStyle {
        promoted
            ? AnyShapeStyle(Theme.heroGradient(tint: Theme.cta))
            : AnyShapeStyle(Theme.surface)
    }
}

/// Single-row workout affordance for Habits tab (no duplicate full card).
struct WorkoutCompactBanner: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfileEntity]

    var date: Date = .now

    @State private var showLiftHub = false

    private var workoutsEnabled: Bool {
        CadenceAppsPreferences.isVisible(.workout) && (profiles.first?.workoutsEnabled ?? true)
    }

    private var scheduled: WorkoutSessionTemplate? {
        WorkoutIntegration.scheduledSession(on: date, workoutsEnabled: workoutsEnabled)
    }

    var body: some View {
        if workoutsEnabled, let session = scheduled, Calendar.current.isDateInToday(date) {
            Theme.Card(padding: 12) {
                HStack(spacing: 10) {
                    Theme.IconWell(systemImage: "dumbbell.fill", tint: Theme.cta, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(session.focus)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        showLiftHub = true
                    } label: {
                        Text("Lift")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.cta)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Lift program")
                    .accessibilityHint("Opens full workout program and history")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(session.name), \(session.focus). Use Lift for full program.")
            .sheet(isPresented: $showLiftHub) {
                WorkoutHomeView()
            }
        }
    }
}

struct LiveWorkoutHost: ViewModifier {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @State private var planEntity: WorkoutPlanEntity?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: Binding(
                get: { appModel.showLiveWorkout && appModel.liveWorkout != nil },
                set: { presented in
                    if presented {
                        appModel.showLiveWorkout = true
                    } else {
                        appModel.discardLiveWorkoutNavigation()
                    }
                }
            )) {
                NavigationStack {
                    ActiveWorkoutView(planEntity: planEntity ?? WorkoutStore.plan(in: modelContext))
                }
            }
            .onAppear {
                planEntity = WorkoutStore.plan(in: modelContext)
            }
    }
}

extension View {
    func liveWorkoutHost() -> some View {
        modifier(LiveWorkoutHost())
    }
}

struct WorkoutWeekStrip: View {
    @Query private var profiles: [UserProfileEntity]
    @Query(sort: \WorkoutLogEntity.finishedAt, order: .reverse) private var logs: [WorkoutLogEntity]
    var onSelectDay: ((Date, WorkoutSessionTemplate?) -> Void)?

    private var workoutsEnabled: Bool {
        CadenceAppsPreferences.isVisible(.workout) && (profiles.first?.workoutsEnabled ?? true)
    }

    var body: some View {
        if !workoutsEnabled {
            EmptyView()
        } else {
            weekStripContent
        }
    }

    private var weekStripContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            Text("Lift program")
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Theme.Space.sm - 2) {
                ForEach(2...8, id: \.self) { raw in
                    let weekday = raw == 8 ? 1 : raw
                    let session = WorkoutProgram.scheduledSession(for: weekday)
                    let dayDate = dateForWeekday(weekday)
                    let isToday = Calendar.current.isDateInToday(dayDate)
                    let logged = session.map { loggedSession($0, on: dayDate) } ?? false
                    Button {
                        onSelectDay?(dayDate, session)
                    } label: {
                        VStack(spacing: Theme.Space.sm - 2) {
                            Text(shortDay(weekday))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isToday ? Theme.accent : Theme.muted)
                            Text(session?.shortName ?? "Rest")
                                .font(.caption2)
                                .foregroundStyle(session == nil ? Theme.muted : Theme.ink)
                                .lineLimit(1)
                            Circle()
                                .fill(logged ? Theme.accent : Theme.sunken)
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm + 2)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(isToday ? Theme.accent.opacity(0.14) : Theme.sunken)
                        )
                        .overlay {
                            if isToday {
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .shadow(
                            color: isToday ? Theme.accent.opacity(0.22) : .clear,
                            radius: 5,
                            y: 1
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(workoutWeekStripLabel(weekday: weekday, session: session, logged: logged, isToday: isToday))
                    .accessibilityHint(
                        isToday
                            ? (session == nil ? "Today, rest day" : "Today’s workout, opens details")
                            : (session == nil ? "Rest day, no workout scheduled" : "Opens workout details for this day")
                    )
                    .accessibilityAddTraits(isToday ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private func workoutWeekStripLabel(weekday: Int, session: WorkoutSessionTemplate?, logged: Bool, isToday: Bool) -> String {
        var parts = [shortDay(weekday)]
        if isToday { parts.append("today") }
        parts.append(session?.name ?? "Rest day")
        if logged { parts.append("logged") }
        return parts.joined(separator: ", ")
    }

    private func dateForWeekday(_ weekday: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let todayWeekday = cal.component(.weekday, from: today)
        let delta = weekday - todayWeekday
        return cal.date(byAdding: .day, value: delta, to: today) ?? today
    }

    private func loggedSession(_ session: WorkoutSessionTemplate, on day: Date) -> Bool {
        logs.contains { log in
            log.sessionID == session.id && Calendar.current.isDate(log.finishedAt, inSameDayAs: day)
        }
    }

    private func shortDay(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols[max(0, min(symbols.count - 1, weekday - 1))]
    }
}

struct TonightMealCard: View {
    @EnvironmentObject private var appModel: AppModel
    @Query private var plans: [WeeklyPlanEntity]
    @State private var selectedDay = MealPlanView.mondayBasedDayIndex()

    var compact = false
    var promoted = false

    private static let mealsTabIndex = 2

    var body: some View {
        if !CadenceAppsPreferences.isVisible(.meals) {
            EmptyView()
        } else {
        Group {
            if let plan = plans.first?.decoded(),
               let dinner = plan.meal(day: selectedDay, slot: .dinner),
               let recipe = appModel.recipeDB.recipe(id: dinner.recipeID) {
                NavigationLink {
                    RecipeDetailView(
                        recipe: recipe,
                        scaledServings: dinner.scaledServings,
                        reason: dinner.reason,
                        proteinG: MealNutrition.plate(main: recipe, side: dinner.sideRecipeID.flatMap { appModel.recipeDB.recipe(id: $0) }).proteinG,
                        calories: MealNutrition.plate(main: recipe, side: dinner.sideRecipeID.flatMap { appModel.recipeDB.recipe(id: $0) }).calories,
                        side: dinner.sideRecipeID.flatMap { appModel.recipeDB.recipe(id: $0) }
                    )
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "fork.knife", tint: Theme.cta, size: 40)
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("Tonight's dinner")
                                .font(.caption2.weight(.bold))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.muted)
                            Text(Theme.recipeDisplayName(recipe.name))
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(compact ? Theme.Space.sm + 2 : Theme.Space.md + 2)
                    .background(mealCardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(promoted ? Theme.cta.opacity(0.22) : Theme.hairline, lineWidth: 1)
                    )
                    .shadow(color: promoted ? Theme.cta.opacity(0.16) : Theme.cardShadow, radius: promoted ? 14 : 10, y: promoted ? 5 : 4)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(tonightDinnerAccessibilityLabel(recipe: recipe, dinner: dinner))
                .accessibilityHint("Opens recipe details")
            } else {
                Button {
                    appModel.requestedMainTab = Self.mealsTabIndex
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        Theme.IconWell(systemImage: "fork.knife", tint: Theme.cta, size: 40)
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("Tonight's dinner")
                                .font(.caption2.weight(.bold))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.muted)
                            Text("No dinner planned")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Theme.MetaPill(text: "TAP TO PLAN", tone: .cta)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(compact ? Theme.Space.sm + 2 : Theme.Space.md + 2)
                    .background(mealCardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(promoted ? Theme.cta.opacity(0.22) : Theme.hairline, lineWidth: 1)
                    )
                    .shadow(color: promoted ? Theme.cta.opacity(0.16) : Theme.cardShadow, radius: promoted ? 14 : 10, y: promoted ? 5 : 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("No dinner planned. Tap to plan on Meals")
                .accessibilityHint("Opens Meals tab to plan tonight’s dinner")
            }
        }
        .onAppear { selectedDay = MealPlanView.mondayBasedDayIndex() }
        }
    }

    private var mealCardBackground: AnyShapeStyle {
        promoted
            ? AnyShapeStyle(Theme.heroGradient(tint: Theme.cta))
            : AnyShapeStyle(Theme.surface)
    }

    private func tonightDinnerAccessibilityLabel(recipe: Recipe, dinner: PlannedMeal) -> String {
        var parts = ["Tonight's dinner", Theme.recipeDisplayName(recipe.name)]
        if let sideID = dinner.sideRecipeID,
           let side = appModel.recipeDB.recipe(id: sideID) {
            parts.append("with \(Theme.recipeDisplayName(side.name))")
        }
        if !dinner.reason.isEmpty {
            parts.append(dinner.reason)
        }
        if !recipe.cookbookTitle.isEmpty {
            parts.append("from \(recipe.cookbookTitle)")
        }
        return parts.joined(separator: ", ")
    }
}
