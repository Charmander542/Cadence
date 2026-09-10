import Foundation
import SwiftData

@MainActor
final class PlannerSyncCoordinator {
    static let shared = PlannerSyncCoordinator()

    private init() {}

    func refreshAll(in context: ModelContext) async {
        await NotificationScheduler.refreshAll(in: context)
        await syncCalendars(in: context)
    }

    func taskDidChange(_ task: PlannerTaskEntity, in context: ModelContext) async {
        if task.isCompleted {
            await NotificationScheduler.cancelTaskReminder(task)
            try? CalendarSyncService.shared.deleteTask(task)
            try? await GoogleCalendarService.shared.deleteTaskEvent(task)
        } else {
            await NotificationScheduler.scheduleTaskReminder(task)
            try? CalendarSyncService.shared.upsertTask(task)
            try? await GoogleCalendarService.shared.upsertTaskEvent(task)
        }
        try? context.save()
    }

    func habitDidChange(_ habit: HabitEntity) async {
        await NotificationScheduler.scheduleHabitReminder(habit)
    }

    func mealPlanDidChange(_ plan: WeeklyPlan, in context: ModelContext) async {
        let names = recipeNames(for: plan)
        try? CalendarSyncService.shared.syncMealPlan(plan, recipeNames: names)
        try? await GoogleCalendarService.shared.syncMealPlan(plan, recipeNames: names)
        await NotificationScheduler.scheduleMealReminders(in: context)
    }

    func workoutPreferencesDidChange(in context: ModelContext) async {
        if WorkoutIntegration.workoutsEnabled(in: context) {
            if PlannerPreferences.syncWorkoutsToAppleCalendar {
                try? CalendarSyncService.shared.syncWorkoutProgram()
            }
            if PlannerPreferences.syncWorkoutsToGoogleCalendar {
                try? await GoogleCalendarService.shared.syncWorkoutProgram()
            }
        } else {
            try? CalendarSyncService.shared.removeWorkoutProgramEvents()
        }
        await NotificationScheduler.refreshAll(in: context)
    }

    func syncCalendars(in context: ModelContext) async {
        let appleNeeded = PlannerPreferences.syncTasksToAppleCalendar
            || PlannerPreferences.syncWorkoutsToAppleCalendar
            || PlannerPreferences.syncMealsToAppleCalendar
        if appleNeeded {
            _ = try? await CalendarSyncService.shared.requestAccess()
        }

        if PlannerPreferences.syncWorkoutsToAppleCalendar {
            if WorkoutIntegration.workoutsEnabled(in: context) {
                try? CalendarSyncService.shared.syncWorkoutProgram()
            } else {
                try? CalendarSyncService.shared.removeWorkoutProgramEvents()
            }
        }
        if PlannerPreferences.syncMealsToAppleCalendar,
           let plan = (try? context.fetch(FetchDescriptor<WeeklyPlanEntity>()))?.first?.decoded() {
            try? CalendarSyncService.shared.syncMealPlan(plan, recipeNames: recipeNames(for: plan))
        }

        if WorkoutIntegration.workoutsEnabled(in: context),
           PlannerPreferences.syncWorkoutsToGoogleCalendar,
           GoogleCalendarService.shared.isSignedIn {
            try? await GoogleCalendarService.shared.syncWorkoutProgram()
        }
        if PlannerPreferences.syncMealsToGoogleCalendar,
           GoogleCalendarService.shared.isSignedIn,
           let plan = (try? context.fetch(FetchDescriptor<WeeklyPlanEntity>()))?.first?.decoded() {
            try? await GoogleCalendarService.shared.syncMealPlan(plan, recipeNames: recipeNames(for: plan))
        }

        let tasks = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        for (index, task) in tasks.enumerated() where !task.isCompleted {
            try? CalendarSyncService.shared.upsertTask(task)
            try? await GoogleCalendarService.shared.upsertTaskEvent(task)
            // Keep the UI responsive during large calendar backfills.
            if index % 8 == 7 {
                await Task.yield()
            }
        }
        try? context.save()
    }

    private func recipeNames(for plan: WeeklyPlan) -> [String: String] {
        var names: [String: String] = [:]
        for meal in plan.meals {
            if names[meal.recipeID] == nil {
                names[meal.recipeID] = RecipeDatabase.shared.recipe(id: meal.recipeID)?.name ?? "Planned meal"
            }
        }
        return names
    }
}
