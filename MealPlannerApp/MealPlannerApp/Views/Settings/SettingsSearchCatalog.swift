import Foundation

enum SettingsRoute: Hashable {
    case profile
    case nutrition
    case meals
    case recipes
    case lift
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
