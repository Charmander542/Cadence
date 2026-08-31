import EventKit
import SwiftUI
import SwiftData
import UserNotifications

struct RemindersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var statusMessage: String?
    @State private var isBusy = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: Binding(
                    get: { PlannerPreferences.notificationsEnabled },
                    set: { newValue in
                        PlannerPreferences.notificationsEnabled = newValue
                        Task { await refreshNotifications() }
                    }
                ))
                .accessibilityLabel("Enable notifications, \(PlannerPreferences.notificationsEnabled ? "on" : "off")")
                .accessibilityHint("Master switch for Cadence reminders")

                if notificationStatus == .denied {
                    Text("Notifications are off in iOS Settings. Enable them to get task, habit, workout, and meal reminders.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
            }

            if PlannerPreferences.notificationsEnabled {
                Section("Reminder types") {
                    Toggle("Task reminders", isOn: boolBinding { PlannerPreferences.taskRemindersEnabled } set: { PlannerPreferences.taskRemindersEnabled = $0 })
                        .accessibilityLabel("Task reminders, \(PlannerPreferences.taskRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies before tasks are due")
                    Toggle("Habit reminders", isOn: boolBinding { PlannerPreferences.habitRemindersEnabled } set: { PlannerPreferences.habitRemindersEnabled = $0 })
                        .accessibilityLabel("Habit reminders, \(PlannerPreferences.habitRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies for daily and weekly habits")
                    Toggle("Workout reminders", isOn: boolBinding { PlannerPreferences.workoutRemindersEnabled } set: { PlannerPreferences.workoutRemindersEnabled = $0 })
                        .accessibilityLabel("Workout reminders, \(PlannerPreferences.workoutRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies before scheduled lift sessions")
                    Toggle("Meal reminders", isOn: boolBinding { PlannerPreferences.mealRemindersEnabled } set: { PlannerPreferences.mealRemindersEnabled = $0 })
                        .accessibilityLabel("Meal reminders, \(PlannerPreferences.mealRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies for lunch and dinner on plan days")
                }

                Section("Timing") {
                    Stepper(
                        "Task reminder: \(PlannerPreferences.defaultTaskReminderMinutesBefore) min before",
                        value: Binding(
                            get: { PlannerPreferences.defaultTaskReminderMinutesBefore },
                            set: { PlannerPreferences.defaultTaskReminderMinutesBefore = $0 }
                        ),
                        in: 5...120,
                        step: 5
                    )
                    .accessibilityLabel("Task reminder, \(PlannerPreferences.defaultTaskReminderMinutesBefore) minutes before")
                    .accessibilityHint("How early task notifications fire before due time")
                    Stepper(
                        "Workout reminder: \(PlannerPreferences.workoutReminderMinutesBefore) min before",
                        value: Binding(
                            get: { PlannerPreferences.workoutReminderMinutesBefore },
                            set: { PlannerPreferences.workoutReminderMinutesBefore = $0 }
                        ),
                        in: 5...120,
                        step: 5
                    )
                    .accessibilityLabel("Workout reminder, \(PlannerPreferences.workoutReminderMinutesBefore) minutes before")
                    .accessibilityHint("How early lift session notifications fire")
                    Stepper(
                        "Lunch reminder: \(PlannerPreferences.lunchReminderHour):00",
                        value: Binding(
                            get: { PlannerPreferences.lunchReminderHour },
                            set: { PlannerPreferences.lunchReminderHour = $0 }
                        ),
                        in: 6...14
                    )
                    .accessibilityLabel("Lunch reminder, \(PlannerPreferences.lunchReminderHour) o'clock")
                    .accessibilityHint("Hour of day for lunch reminders on plan days")
                    Stepper(
                        "Dinner reminder: \(PlannerPreferences.dinnerReminderHour):00",
                        value: Binding(
                            get: { PlannerPreferences.dinnerReminderHour },
                            set: { PlannerPreferences.dinnerReminderHour = $0 }
                        ),
                        in: 15...21
                    )
                    .accessibilityLabel("Dinner reminder, \(PlannerPreferences.dinnerReminderHour) o'clock")
                    .accessibilityHint("Hour of day for dinner reminders on plan days")
                }
            }

            Section {
                Button("Refresh all reminders") {
                    Task { await refreshNotifications() }
                }
                .disabled(isBusy)
                .accessibilityHint("Reschedules task, habit, workout, and meal notifications")
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(statusMessage)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .navigationTitle("Reminders")
        .settingsFormChrome()
        .task { notificationStatus = await NotificationScheduler.authorizationStatus() }
    }

    private func boolBinding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(
            get: get,
            set: { newValue in
                set(newValue)
                Task { await refreshNotifications() }
            }
        )
    }

    private func refreshNotifications() async {
        isBusy = true
        defer { isBusy = false }
        if PlannerPreferences.notificationsEnabled {
            _ = await NotificationScheduler.requestAuthorization()
        }
        notificationStatus = await NotificationScheduler.authorizationStatus()
        await PlannerSyncCoordinator.shared.refreshAll(in: modelContext)
        statusMessage = "Reminders updated."
    }
}

struct CalendarSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var calendarStatus: EKAuthorizationStatus = .notDetermined
    @State private var appleCalendars: [CalendarChoice] = []
    @State private var googleCalendars: [GoogleCalendarSummary] = []
    @State private var statusMessage: String?
    @State private var isBusy = false

    var body: some View {
        Form {
            appleCalendarSection
            googleCalendarSection
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(statusMessage)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .navigationTitle("Calendar sync")
        .settingsFormChrome()
        .task { await onAppearLoad() }
    }

    private var appleCalendarSection: some View {
        Section {
            Toggle("Sync tasks", isOn: syncBinding { PlannerPreferences.syncTasksToAppleCalendar } set: { PlannerPreferences.syncTasksToAppleCalendar = $0 })
                .accessibilityLabel("Sync tasks to Apple Calendar, \(PlannerPreferences.syncTasksToAppleCalendar ? "on" : "off")")
                .accessibilityHint("Exports due tasks to Apple Calendar")
            Toggle("Sync workouts", isOn: syncBinding { PlannerPreferences.syncWorkoutsToAppleCalendar } set: { PlannerPreferences.syncWorkoutsToAppleCalendar = $0 })
                .accessibilityLabel("Sync workouts to Apple Calendar, \(PlannerPreferences.syncWorkoutsToAppleCalendar ? "on" : "off")")
                .accessibilityHint("Exports scheduled lift sessions to Apple Calendar")
            Toggle("Sync meals", isOn: syncBinding { PlannerPreferences.syncMealsToAppleCalendar } set: { PlannerPreferences.syncMealsToAppleCalendar = $0 })
                .accessibilityLabel("Sync meals to Apple Calendar, \(PlannerPreferences.syncMealsToAppleCalendar ? "on" : "off")")
                .accessibilityHint("Exports planned dinners to Apple Calendar")

            if calendarStatus == .denied || calendarStatus == .restricted {
                Text("Calendar access is denied. Enable Full Calendar Access in iOS Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
            }

            Picker("Target calendar", selection: Binding(
                get: { PlannerPreferences.appleCalendarIdentifier ?? "" },
                set: { PlannerPreferences.appleCalendarIdentifier = $0.isEmpty ? nil : $0 }
            )) {
                Text("Default").tag("")
                ForEach(appleCalendars) { cal in
                    Text("\(cal.title) · \(cal.sourceKind.title)").tag(cal.id)
                }
            }
            .accessibilityLabel("Target calendar, \(selectedAppleCalendarLabel)")
            .accessibilityHint("Apple Calendar used for task, workout, and meal sync")

            Button("Request calendar access") {
                Task { await requestCalendarAccess() }
            }
            .disabled(isBusy)
            .accessibilityHint("Allows syncing tasks, workouts, and meals to Apple Calendar")
        } header: {
            Text("Apple Calendar")
        } footer: {
            Text("Google calendars added to iOS also appear in the picker above.")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private var googleCalendarSection: some View {
        Section {
            if GoogleCalendarService.shared.isConfigured {
                if GoogleCalendarService.shared.isSignedIn {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("Disconnect Google") {
                        GoogleCalendarService.shared.signOut()
                        googleCalendars = []
                    }
                    .accessibilityHint("Stops syncing with Google Calendar")
                } else {
                    Button("Connect Google account") {
                        Task { await connectGoogle() }
                    }
                    .disabled(isBusy)
                    .accessibilityHint("Signs in to sync with Google Calendar")
                }

                Toggle("Sync tasks", isOn: syncBinding { PlannerPreferences.syncTasksToGoogleCalendar } set: { PlannerPreferences.syncTasksToGoogleCalendar = $0 })
                    .accessibilityLabel("Sync tasks to Google Calendar, \(PlannerPreferences.syncTasksToGoogleCalendar ? "on" : "off")")
                    .accessibilityHint("Exports due tasks to Google Calendar")
                Toggle("Sync workouts", isOn: syncBinding { PlannerPreferences.syncWorkoutsToGoogleCalendar } set: { PlannerPreferences.syncWorkoutsToGoogleCalendar = $0 })
                    .accessibilityLabel("Sync workouts to Google Calendar, \(PlannerPreferences.syncWorkoutsToGoogleCalendar ? "on" : "off")")
                    .accessibilityHint("Exports scheduled lift sessions to Google Calendar")
                Toggle("Sync meals", isOn: syncBinding { PlannerPreferences.syncMealsToGoogleCalendar } set: { PlannerPreferences.syncMealsToGoogleCalendar = $0 })
                    .accessibilityLabel("Sync meals to Google Calendar, \(PlannerPreferences.syncMealsToGoogleCalendar ? "on" : "off")")
                    .accessibilityHint("Exports planned dinners to Google Calendar")

                Picker("Google calendar", selection: Binding(
                    get: { PlannerPreferences.googleCalendarID ?? "" },
                    set: { newID in
                        PlannerPreferences.googleCalendarID = newID.isEmpty ? nil : newID
                        PlannerPreferences.googleCalendarTitle = googleCalendars.first { $0.id == newID }?.title
                    }
                )) {
                    Text("Primary").tag("")
                    ForEach(googleCalendars) { cal in
                        Text(cal.title).tag(cal.id)
                    }
                }
                .accessibilityLabel("Google calendar, \(selectedGoogleCalendarLabel)")
                .accessibilityHint("Google Calendar used for task, workout, and meal sync")

                if googleCalendars.isEmpty, GoogleCalendarService.shared.isSignedIn {
                    Button("Load calendars") {
                        Task { await loadGoogleCalendars() }
                    }
                    .accessibilityHint("Fetches available Google calendars to sync")
                }
            } else {
                Text("Add a Google OAuth iOS client ID as GoogleOAuthClientID in Info.plist to enable direct Google Calendar sync.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
            }
        } header: {
            Text("Google Calendar")
        } footer: {
            if !GoogleCalendarService.shared.isConfigured {
                EmptyView()
            } else {
                Text("Workout and meal sync to Google creates new events; toggling sync off does not yet remove past Google events.")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var selectedAppleCalendarLabel: String {
        let id = PlannerPreferences.appleCalendarIdentifier ?? ""
        guard !id.isEmpty else { return "Default" }
        if let cal = appleCalendars.first(where: { $0.id == id }) {
            return "\(cal.title), \(cal.sourceKind.title)"
        }
        return "Default"
    }

    private var selectedGoogleCalendarLabel: String {
        let id = PlannerPreferences.googleCalendarID ?? ""
        guard !id.isEmpty else { return "Primary" }
        if let cal = googleCalendars.first(where: { $0.id == id }) {
            return cal.title
        }
        return PlannerPreferences.googleCalendarTitle ?? "Primary"
    }

    private func syncBinding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(
            get: get,
            set: { newValue in
                set(newValue)
                Task { await syncCalendars() }
            }
        )
    }

    private func requestCalendarAccess() async {
        isBusy = true
        defer { isBusy = false }
        _ = try? await CalendarSyncService.shared.requestAccess()
        calendarStatus = CalendarSyncService.shared.authorizationStatus
        appleCalendars = CalendarSyncService.shared.availableCalendars()
        await syncCalendars()
    }

    private func syncCalendars() async {
        isBusy = true
        defer { isBusy = false }
        await PlannerSyncCoordinator.shared.syncCalendars(in: modelContext)
        statusMessage = "Calendar sync updated."
    }

    private func connectGoogle() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await GoogleCalendarService.shared.signIn()
            await loadGoogleCalendars()
            statusMessage = "Google account connected."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadGoogleCalendars() async {
        do {
            googleCalendars = try await GoogleCalendarService.shared.listCalendars()
            if PlannerPreferences.googleCalendarID == nil,
               let primary = googleCalendars.first(where: \.primary) {
                PlannerPreferences.googleCalendarID = primary.id
                PlannerPreferences.googleCalendarTitle = primary.title
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func onAppearLoad() async {
        calendarStatus = CalendarSyncService.shared.authorizationStatus
        appleCalendars = CalendarSyncService.shared.availableCalendars()
        if GoogleCalendarService.shared.isSignedIn {
            await loadGoogleCalendars()
        }
    }
}
