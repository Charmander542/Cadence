import Foundation

enum SettingsRoute: Hashable {
    case profile
    /// Legacy — opens the merged You page (profile + nutrition).
    case nutrition
    case meals
    /// Legacy — opens the merged Meals page.
    case recipes
    /// Legacy — opens Apps & wheel (lift visibility lives there).
    case lift
    case apps
    case spend
    case health
    case news
    case reminders
    case calendar
    case ai
}

struct SettingsSearchMatch: Identifiable {
    var id: SettingsRoute { route }
    let route: SettingsRoute
    let title: String
    let subtitle: String
    let keywords: String

    /// Routes shown on the Settings hub (no duplicate pages).
    static let hubRoutes: [SettingsRoute] = [
        .profile, .apps, .meals, .health, .spend, .news, .reminders, .calendar, .ai,
    ]

    static let catalog: [SettingsSearchMatch] = [
        SettingsSearchMatch(
            route: .profile,
            title: "You",
            subtitle: "Weight, goals, calories, protein, BMR, and TDEE",
            keywords: "profile you weight height age sex activity goal metric imperial recalculate macros nutrition calories protein carbs fat bmr tdee targets units"
        ),
        SettingsSearchMatch(
            route: .meals,
            title: "Meals",
            subtitle: "Diet, cookbooks, tools, and regenerate the weekly plan",
            keywords: "meals diet cooking complexity servings tools cookbooks restrictions skip foods recipes plan weekly regenerate browse shop grocery"
        ),
        SettingsSearchMatch(
            route: .apps,
            title: "Apps & wheel",
            subtitle: "Choose which apps appear on the dial, including Lift",
            keywords: "apps wheel customize navigation tabs hide meals workout lift dumbbell spend health news grid edit schedule"
        ),
        SettingsSearchMatch(
            route: .spend,
            title: "Spend",
            subtitle: "Bank purchases, categories, and cost-per-use",
            keywords: "spend budget plaid bank card purchases transactions cost per use tracking money"
        ),
        SettingsSearchMatch(
            route: .health,
            title: "Body",
            subtitle: "Strain, recovery, sleep, Apple Health, and Lift",
            keywords: "health body apple healthkit recovery strain sleep hrv heart energy bevel vitals workout lift"
        ),
        SettingsSearchMatch(
            route: .news,
            title: "News",
            subtitle: "Daily top stories, AI briefs, and article links",
            keywords: "news digest rss headlines science world ai summarize articles briefing"
        ),
        SettingsSearchMatch(
            route: .reminders,
            title: "Reminders",
            subtitle: "Task, habit, workout, and meal notifications",
            keywords: "reminders notifications tasks habits workouts meals alerts timing"
        ),
        SettingsSearchMatch(
            route: .calendar,
            title: "Calendar",
            subtitle: "Apple Calendar and Google Calendar export",
            keywords: "calendar sync apple google export events tasks workouts meals integration"
        ),
        SettingsSearchMatch(
            route: .ai,
            title: "AI",
            subtitle: "API keys and macro recalculation provider",
            keywords: "ai anthropic openai claude api key macros llm"
        ),
    ]

    static func matches(query: String) -> [SettingsSearchMatch] {
        let tokens = query.lowercased().split(separator: " ").map(String.init).filter { $0.count > 1 }
        guard !tokens.isEmpty else { return [] }
        return catalog.filter { item in
            let hay = "\(item.title) \(item.subtitle) \(item.keywords)".lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
    }
}
