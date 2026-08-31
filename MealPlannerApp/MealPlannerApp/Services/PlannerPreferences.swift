import Foundation

/// On-device planner notification + calendar sync preferences.
enum PlannerPreferences {
    private static let defaults = UserDefaults.standard

    // MARK: - Notifications

    static var notificationsEnabled: Bool {
        get { defaults.object(forKey: "planner.notificationsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "planner.notificationsEnabled") }
    }

    static var taskRemindersEnabled: Bool {
        get { defaults.object(forKey: "planner.taskRemindersEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "planner.taskRemindersEnabled") }
    }

    static var habitRemindersEnabled: Bool {
        get { defaults.object(forKey: "planner.habitRemindersEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "planner.habitRemindersEnabled") }
    }

    static var workoutRemindersEnabled: Bool {
        get { defaults.object(forKey: "planner.workoutRemindersEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "planner.workoutRemindersEnabled") }
    }

    static var mealRemindersEnabled: Bool {
        get { defaults.object(forKey: "planner.mealRemindersEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "planner.mealRemindersEnabled") }
    }

    /// Default reminder offset when a task has a due time but no explicit reminder.
    static var defaultTaskReminderMinutesBefore: Int {
        get {
            let v = defaults.integer(forKey: "planner.defaultTaskReminderMinutesBefore")
            return v > 0 ? v : 15
        }
        set { defaults.set(newValue, forKey: "planner.defaultTaskReminderMinutesBefore") }
    }

    static var workoutReminderMinutesBefore: Int {
        get {
            let v = defaults.integer(forKey: "planner.workoutReminderMinutesBefore")
            return v > 0 ? v : 30
        }
        set { defaults.set(newValue, forKey: "planner.workoutReminderMinutesBefore") }
    }

    static var lunchReminderHour: Int {
        get {
            let v = defaults.integer(forKey: "planner.lunchReminderHour")
            return defaults.object(forKey: "planner.lunchReminderHour") == nil ? 12 : v
        }
        set { defaults.set(newValue, forKey: "planner.lunchReminderHour") }
    }

    static var dinnerReminderHour: Int {
        get {
            let v = defaults.integer(forKey: "planner.dinnerReminderHour")
            return defaults.object(forKey: "planner.dinnerReminderHour") == nil ? 17 : v
        }
        set { defaults.set(newValue, forKey: "planner.dinnerReminderHour") }
    }

    // MARK: - Apple Calendar (EventKit)

    static var syncTasksToAppleCalendar: Bool {
        get { defaults.bool(forKey: "planner.syncTasksToAppleCalendar") }
        set { defaults.set(newValue, forKey: "planner.syncTasksToAppleCalendar") }
    }

    static var syncWorkoutsToAppleCalendar: Bool {
        get { defaults.bool(forKey: "planner.syncWorkoutsToAppleCalendar") }
        set { defaults.set(newValue, forKey: "planner.syncWorkoutsToAppleCalendar") }
    }

    static var syncMealsToAppleCalendar: Bool {
        get { defaults.bool(forKey: "planner.syncMealsToAppleCalendar") }
        set { defaults.set(newValue, forKey: "planner.syncMealsToAppleCalendar") }
    }

    static var appleCalendarIdentifier: String? {
        get { defaults.string(forKey: "planner.appleCalendarIdentifier") }
        set { defaults.set(newValue, forKey: "planner.appleCalendarIdentifier") }
    }

    /// Selected Apple sub-calendars for export. Empty after explicit init means sync to none.
    static var appleCalendarIdentifiers: Set<String> {
        get {
            if let stored = stringSet(forKey: "planner.appleCalendarIdentifiers") {
                return stored
            }
            if let legacy = appleCalendarIdentifier, !legacy.isEmpty {
                return [legacy]
            }
            return []
        }
        set {
            setStringSet(newValue, forKey: "planner.appleCalendarIdentifiers")
            appleCalendarsSelectionInitialized = true
        }
    }

    static var appleCalendarsSelectionInitialized: Bool {
        get { defaults.bool(forKey: "planner.appleCalendarsSelectionInitialized") }
        set { defaults.set(newValue, forKey: "planner.appleCalendarsSelectionInitialized") }
    }

    static func setAppleCalendarEnabled(_ calendarID: String, enabled: Bool) {
        var set = appleCalendarIdentifiers
        if enabled {
            set.insert(calendarID)
        } else {
            set.remove(calendarID)
        }
        appleCalendarIdentifiers = set
    }

    static func isAppleCalendarEnabled(_ calendarID: String) -> Bool {
        appleCalendarIdentifiers.contains(calendarID)
    }

    // MARK: - Google Calendar (API)

    static var syncTasksToGoogleCalendar: Bool {
        get { defaults.bool(forKey: "planner.syncTasksToGoogleCalendar") }
        set { defaults.set(newValue, forKey: "planner.syncTasksToGoogleCalendar") }
    }

    static var syncWorkoutsToGoogleCalendar: Bool {
        get { defaults.bool(forKey: "planner.syncWorkoutsToGoogleCalendar") }
        set { defaults.set(newValue, forKey: "planner.syncWorkoutsToGoogleCalendar") }
    }

    static var syncMealsToGoogleCalendar: Bool {
        get { defaults.bool(forKey: "planner.syncMealsToGoogleCalendar") }
        set { defaults.set(newValue, forKey: "planner.syncMealsToGoogleCalendar") }
    }

    static var googleCalendarID: String? {
        get { defaults.string(forKey: "planner.googleCalendarID") }
        set { defaults.set(newValue, forKey: "planner.googleCalendarID") }
    }

    static var googleCalendarIDs: Set<String> {
        get {
            if let stored = stringSet(forKey: "planner.googleCalendarIdentifiers") {
                return stored
            }
            if let legacy = googleCalendarID, !legacy.isEmpty {
                return [legacy]
            }
            return []
        }
        set {
            setStringSet(newValue, forKey: "planner.googleCalendarIdentifiers")
            googleCalendarsSelectionInitialized = true
            googleCalendarID = newValue.sorted().first
            googleCalendarTitle = nil
        }
    }

    static var googleCalendarsSelectionInitialized: Bool {
        get { defaults.bool(forKey: "planner.googleCalendarsSelectionInitialized") }
        set { defaults.set(newValue, forKey: "planner.googleCalendarsSelectionInitialized") }
    }

    static func setGoogleCalendarEnabled(_ calendarID: String, enabled: Bool) {
        var set = googleCalendarIDs
        if enabled {
            set.insert(calendarID)
        } else {
            set.remove(calendarID)
        }
        googleCalendarIDs = set
    }

    static func isGoogleCalendarEnabled(_ calendarID: String) -> Bool {
        googleCalendarIDs.contains(calendarID)
    }

    static var googleCalendarTitle: String? {
        get { defaults.string(forKey: "planner.googleCalendarTitle") }
        set { defaults.set(newValue, forKey: "planner.googleCalendarTitle") }
    }

    // MARK: - Helpers

    private static func stringSet(forKey key: String) -> Set<String>? {
        guard defaults.object(forKey: key) != nil,
              let array = defaults.array(forKey: key) as? [String]
        else { return nil }
        return Set(array)
    }

    private static func setStringSet(_ value: Set<String>, forKey key: String) {
        defaults.set(Array(value).sorted(), forKey: key)
    }
}
