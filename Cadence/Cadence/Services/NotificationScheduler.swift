import Foundation
import UserNotifications
import SwiftData

@MainActor
enum NotificationScheduler {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func refreshAll(in context: ModelContext) async {
        guard PlannerPreferences.notificationsEnabled else {
            await removeAllPlannerNotifications()
            return
        }

        let status = await authorizationStatus()
        if status == .notDetermined {
            _ = await requestAuthorization()
        }

        let tasks = (try? context.fetch(FetchDescriptor<PlannerTaskEntity>())) ?? []
        let habits = (try? context.fetch(FetchDescriptor<HabitEntity>())) ?? []

        await removeAllPlannerNotifications()

        if PlannerPreferences.taskRemindersEnabled {
            for task in tasks where !task.isCompleted {
                await scheduleTaskReminder(task)
            }
        }

        if PlannerPreferences.habitRemindersEnabled {
            for habit in habits where habit.remindersEnabled {
                await scheduleHabitReminder(habit)
            }
        }

        if PlannerPreferences.workoutRemindersEnabled {
            await scheduleWorkoutReminders(in: context)
        }

        if PlannerPreferences.mealRemindersEnabled {
            await scheduleMealReminders(in: context)
        }
    }

    static func scheduleTaskReminder(_ task: PlannerTaskEntity) async {
        guard PlannerPreferences.notificationsEnabled,
              PlannerPreferences.taskRemindersEnabled,
              !task.isCompleted
        else {
            await cancel(id: taskNotificationID(task.id))
            return
        }

        guard let fireDate = effectiveReminderDate(for: task), fireDate > .now else {
            await cancel(id: taskNotificationID(task.id))
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Task reminder"
        content.body = task.title
        content.sound = .default
        content.userInfo = ["kind": "task", "taskID": task.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: taskNotificationID(task.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelTaskReminder(_ task: PlannerTaskEntity) async {
        await cancel(id: taskNotificationID(task.id))
    }

    static func scheduleHabitReminder(_ habit: HabitEntity) async {
        guard PlannerPreferences.notificationsEnabled,
              PlannerPreferences.habitRemindersEnabled,
              habit.remindersEnabled
        else {
            await cancel(id: habitNotificationID(habit.id))
            return
        }

        var components = DateComponents()
        components.hour = habit.reminderHour
        components.minute = habit.reminderMinute

        let content = UNMutableNotificationContent()
        content.title = "Habit check-in"
        content.body = habit.name
        content.sound = .default
        content.userInfo = ["kind": "habit", "habitID": habit.id.uuidString]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: habitNotificationID(habit.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func scheduleWorkoutReminders(in context: ModelContext) async {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfileEntity>())) ?? []
        guard profiles.first?.workoutsEnabled ?? true else { return }

        let cal = Calendar.current
        let minutesBefore = PlannerPreferences.workoutReminderMinutesBefore
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now)),
                  let session = WorkoutIntegration.scheduledSession(on: day, workoutsEnabled: true)
            else { continue }

            let workoutStart = WorkoutIntegration.workoutBlockDate(on: day)
            guard let fireDate = cal.date(byAdding: .minute, value: -minutesBefore, to: workoutStart),
                  fireDate > .now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Workout today"
            content.body = "\(session.name) · \(session.focus)"
            content.sound = .default
            content.userInfo = ["kind": "workout", "sessionID": session.id]

            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: workoutNotificationID(session.id, day: day),
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func scheduleMealReminders(in context: ModelContext) async {
        let plans = (try? context.fetch(FetchDescriptor<WeeklyPlanEntity>())) ?? []
        guard let plan = plans.first?.decoded() else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayIndex = MealPlanView.mondayBasedDayIndex(for: day)

            if let lunch = plan.meal(day: dayIndex, slot: .lunch) {
                await scheduleMealReminder(
                    title: "Lunch: \(mealTitle(for: lunch.recipeID))",
                    day: day,
                    hour: PlannerPreferences.lunchReminderHour,
                    minute: 0,
                    slot: .lunch,
                    dayIndex: dayIndex
                )
            }
            if let dinner = plan.meal(day: dayIndex, slot: .dinner) {
                await scheduleMealReminder(
                    title: "Dinner: \(mealTitle(for: dinner.recipeID))",
                    day: day,
                    hour: PlannerPreferences.dinnerReminderHour,
                    minute: 0,
                    slot: .dinner,
                    dayIndex: dayIndex
                )
            }
        }
    }

    // MARK: - Helpers

    private static func scheduleMealReminder(
        title: String,
        day: Date,
        hour: Int,
        minute: Int,
        slot: MealSlot,
        dayIndex: Int
    ) async {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        guard let fireDate = Calendar.current.date(from: components), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Meal plan"
        content.body = title
        content.sound = .default
        content.userInfo = ["kind": "meal", "slot": slot.rawValue, "dayIndex": dayIndex]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: mealNotificationID(dayIndex: dayIndex, slot: slot),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func mealTitle(for recipeID: String) -> String {
        RecipeDatabase.shared.recipe(id: recipeID)?.name ?? "Planned meal"
    }

    static func effectiveReminderDate(for task: PlannerTaskEntity) -> Date? {
        if let reminderAt = task.reminderAt { return reminderAt }
        guard let dueAt = task.dueAt else { return nil }
        return Calendar.current.date(
            byAdding: .minute,
            value: -PlannerPreferences.defaultTaskReminderMinutesBefore,
            to: dueAt
        )
    }

    private static func removeAllPlannerNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("planner.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func taskNotificationID(_ id: UUID) -> String { "planner.task.\(id.uuidString)" }
    private static func habitNotificationID(_ id: UUID) -> String { "planner.habit.\(id.uuidString)" }
    private static func workoutNotificationID(_ sessionID: String, day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return "planner.workout.\(sessionID).\(f.string(from: day))"
    }
    private static func mealNotificationID(dayIndex: Int, slot: MealSlot) -> String {
        "planner.meal.\(dayIndex).\(slot.rawValue)"
    }
}
