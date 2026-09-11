import Foundation

enum SettingsRoute: Hashable {
    case profile
    case nutrition
    case meals
    case recipes
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

    static let catalog: [SettingsSearchMatch] = [
        SettingsSearchMatch(
            route: .profile,
            title: "Profile & goals",
            subtitle: "Weight, height, age, activity, and goals",
            keywords: "profile weight height age sex activity goal metric imperial recalculate macros"
        ),
        SettingsSearchMatch(
            route: .nutrition,
            title: "Nutrition targets",
            subtitle: "Calories, protein, BMR, and TDEE",
            keywords: "nutrition calories protein carbs fat bmr tdee targets macros"
        ),
        SettingsSearchMatch(
            route: .meals,
            title: "Meals & cooking",
            subtitle: "Diet, tools, cookbooks, and complexity",
            keywords: "meals diet cooking complexity servings tools cookbooks restrictions skip foods"
        ),
        SettingsSearchMatch(
            route: .recipes,
            title: "Recipes & weekly plan",
            subtitle: "Browse cookbooks and regenerate your plan",
            keywords: "recipes plan weekly regenerate browse cookbooks shop grocery"
        ),
        SettingsSearchMatch(
            route: .lift,
            title: "Lift & workouts",
            subtitle: "Show or hide the workout schedule",
            keywords: "lift workout dumbbell schedule countdown training"
        ),
        SettingsSearchMatch(
            route: .apps,
            title: "Apps & wheel",
            subtitle: "Choose which apps appear on the dial",
            keywords: "apps wheel customize navigation tabs hide meals workout spend health news grid edit"
        ),
        SettingsSearchMatch(
            route: .spend,
            title: "Spend & Teller",
            subtitle: "Bank purchases, categories, and cost-per-use",
            keywords: "spend budget teller bank purchases transactions cost per use tracking money"
        ),
        SettingsSearchMatch(
            route: .health,
            title: "Body",
            subtitle: "Strain, recovery, sleep, Apple Health, and Lift",
            keywords: "health body apple healthkit recovery strain sleep hrv heart energy bevel vitals workout lift dumbbell"
        ),
        SettingsSearchMatch(
            route: .news,
            title: "News digest",
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
            title: "Calendar sync",
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
