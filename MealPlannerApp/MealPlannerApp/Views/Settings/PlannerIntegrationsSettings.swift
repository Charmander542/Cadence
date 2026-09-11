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
                .tint(Theme.cta)
                .accessibilityLabel("Enable notifications, \(PlannerPreferences.notificationsEnabled ? "on" : "off")")
                .accessibilityHint("Master switch for Cadence reminders")

                if notificationStatus == .denied {
                    Text("Notifications are off in iOS Settings. Enable them to get task, habit, workout, and meal reminders.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                    SettingsOpenSystemSettingsButton()
                } else if notificationStatus == .notDetermined, PlannerPreferences.notificationsEnabled {
                    Text("Cadence will ask for notification permission when you refresh reminders.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
            } header: {
                settingsDetailSectionHeader("Master")
            } footer: {
                settingsDetailIntro("Task, habit, workout, and meal notifications on your schedule.")
            }

            if PlannerPreferences.notificationsEnabled {
                Section {
                    Toggle("Task reminders", isOn: boolBinding { PlannerPreferences.taskRemindersEnabled } set: { PlannerPreferences.taskRemindersEnabled = $0 })
                        .tint(Theme.cta)
                        .accessibilityLabel("Task reminders, \(PlannerPreferences.taskRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies before tasks are due")
                    Toggle("Habit reminders", isOn: boolBinding { PlannerPreferences.habitRemindersEnabled } set: { PlannerPreferences.habitRemindersEnabled = $0 })
                        .tint(Theme.cta)
                        .accessibilityLabel("Habit reminders, \(PlannerPreferences.habitRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies for daily and weekly habits")
                    Toggle("Workout reminders", isOn: boolBinding { PlannerPreferences.workoutRemindersEnabled } set: { PlannerPreferences.workoutRemindersEnabled = $0 })
                        .tint(Theme.cta)
                        .accessibilityLabel("Workout reminders, \(PlannerPreferences.workoutRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies before scheduled lift sessions")
                    Toggle("Meal reminders", isOn: boolBinding { PlannerPreferences.mealRemindersEnabled } set: { PlannerPreferences.mealRemindersEnabled = $0 })
                        .tint(Theme.cta)
                        .accessibilityLabel("Meal reminders, \(PlannerPreferences.mealRemindersEnabled ? "on" : "off")")
                        .accessibilityHint("Notifies for lunch and dinner on plan days")
                } header: {
                    settingsDetailSectionHeader("Reminder types")
                }

                Section {
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
                } header: {
                    settingsDetailSectionHeader("Timing")
                }
            }

            Section {
                Button {
                    Task { await refreshNotifications() }
                } label: {
                    settingsCTALabel(isBusy ? "Working…" : "Refresh all reminders", systemImage: "arrow.clockwise")
                }
                .disabled(isBusy)
                .accessibilityHint("Reschedules task, habit, workout, and meal notifications")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
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
    @State private var statusTone: Theme.MetaPill.MetaTone = .accent
    @State private var statusIcon = "checkmark.circle.fill"
    @State private var isBusy = false

    var body: some View {
        Form {
            appleCalendarSection
            googleCalendarSection
            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .task { await onAppearLoad() }
    }

    private var appleCalendarSection: some View {
        Section {
            Toggle("Sync tasks", isOn: syncBinding { PlannerPreferences.syncTasksToAppleCalendar } set: { PlannerPreferences.syncTasksToAppleCalendar = $0 })
                .tint(Theme.cta)
                .accessibilityLabel("Sync tasks to Apple Calendar, \(PlannerPreferences.syncTasksToAppleCalendar ? "on" : "off")")
                .accessibilityHint("Exports due tasks to Apple Calendar")
            Toggle("Sync workouts", isOn: syncBinding { PlannerPreferences.syncWorkoutsToAppleCalendar } set: { PlannerPreferences.syncWorkoutsToAppleCalendar = $0 })
                .tint(Theme.cta)
                .accessibilityLabel("Sync workouts to Apple Calendar, \(PlannerPreferences.syncWorkoutsToAppleCalendar ? "on" : "off")")
                .accessibilityHint("Exports scheduled lift sessions to Apple Calendar")
            Toggle("Sync meals", isOn: syncBinding { PlannerPreferences.syncMealsToAppleCalendar } set: { PlannerPreferences.syncMealsToAppleCalendar = $0 })
                .tint(Theme.cta)
                .accessibilityLabel("Sync meals to Apple Calendar, \(PlannerPreferences.syncMealsToAppleCalendar ? "on" : "off")")
                .accessibilityHint("Exports planned dinners to Apple Calendar")

            if calendarStatus == .denied || calendarStatus == .restricted {
                Text("Calendar access is denied. Enable Full Calendar Access in iOS Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
                SettingsOpenSystemSettingsButton()
            }

            if appleCalendars.isEmpty {
                Text("Request calendar access to load your sub-calendars.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
            } else {
                ForEach(appleCalendars) { cal in
                    Toggle(isOn: appleCalendarBinding(cal.id)) {
                        Text("\(cal.title) · \(cal.sourceKind.title)")
                    }
                    .tint(Theme.cta)
                    .accessibilityLabel("\(cal.title), \(cal.sourceKind.title), \(PlannerPreferences.isAppleCalendarEnabled(cal.id) ? "on" : "off")")
                    .accessibilityHint("Exports Cadence items to this calendar when sync is enabled")
                }
            }

            Button {
                Task { await requestCalendarAccess() }
            } label: {
                settingsCTALabel(isBusy ? "Working…" : "Request calendar access", systemImage: "calendar.badge.plus")
            }
            .disabled(isBusy)
            .accessibilityHint("Allows syncing tasks, workouts, and meals to Apple Calendar")
        } header: {
            settingsDetailSectionHeader("Apple Calendar")
        } footer: {
            settingsDetailIntro("Export tasks, workouts, and meals. Turn on any sub-calendars where Cadence should write — Google calendars added to iOS appear here too.")
        }
    }

    private var googleCalendarSection: some View {
        Section {
            if GoogleCalendarService.shared.isConfigured {
                if GoogleCalendarService.shared.isSignedIn {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                    Button("Disconnect Google") {
                        GoogleCalendarService.shared.signOut()
                        googleCalendars = []
                        showStatus("Google account disconnected.", tone: .neutral, icon: "link.badge.minus")
                    }
                    .foregroundStyle(Theme.danger)
                    .accessibilityHint("Stops syncing with Google Calendar")
                } else {
                    Button {
                        Task { await connectGoogle() }
                    } label: {
                        settingsCTALabel(isBusy ? "Working…" : "Connect Google account", systemImage: "person.crop.circle.badge.plus")
                    }
                    .disabled(isBusy)
                    .accessibilityHint("Signs in to sync with Google Calendar")
                }

                Toggle("Sync tasks", isOn: syncBinding { PlannerPreferences.syncTasksToGoogleCalendar } set: { PlannerPreferences.syncTasksToGoogleCalendar = $0 })
                    .tint(Theme.cta)
                    .accessibilityLabel("Sync tasks to Google Calendar, \(PlannerPreferences.syncTasksToGoogleCalendar ? "on" : "off")")
                    .accessibilityHint("Exports due tasks to Google Calendar")
                Toggle("Sync workouts", isOn: syncBinding { PlannerPreferences.syncWorkoutsToGoogleCalendar } set: { PlannerPreferences.syncWorkoutsToGoogleCalendar = $0 })
                    .tint(Theme.cta)
                    .accessibilityLabel("Sync workouts to Google Calendar, \(PlannerPreferences.syncWorkoutsToGoogleCalendar ? "on" : "off")")
                    .accessibilityHint("Exports scheduled lift sessions to Google Calendar")
                Toggle("Sync meals", isOn: syncBinding { PlannerPreferences.syncMealsToGoogleCalendar } set: { PlannerPreferences.syncMealsToGoogleCalendar = $0 })
                    .tint(Theme.cta)
                    .accessibilityLabel("Sync meals to Google Calendar, \(PlannerPreferences.syncMealsToGoogleCalendar ? "on" : "off")")
                    .accessibilityHint("Exports planned dinners to Google Calendar")

                if googleCalendars.isEmpty, GoogleCalendarService.shared.isSignedIn {
                    Button {
                        Task { await loadGoogleCalendars() }
                    } label: {
                        settingsCTALabel("Load calendars", systemImage: "arrow.down.circle")
                    }
                    .accessibilityHint("Fetches available Google calendars to sync")
                } else if GoogleCalendarService.shared.isSignedIn {
                    ForEach(googleCalendars) { cal in
                        Toggle(isOn: googleCalendarBinding(cal.id)) {
                            Text(cal.title)
                        }
                        .tint(Theme.cta)
                        .accessibilityLabel("\(cal.title), \(PlannerPreferences.isGoogleCalendarEnabled(cal.id) ? "on" : "off")")
                        .accessibilityHint("Exports Cadence items to this Google calendar when sync is enabled")
                    }
                }

            } else {
                Text("Add a Google OAuth iOS client ID as GoogleOAuthClientID in Info.plist to enable direct Google Calendar sync.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)
            }
        } header: {
            settingsDetailSectionHeader("Google Calendar")
        } footer: {
            if !GoogleCalendarService.shared.isConfigured {
                EmptyView()
            } else {
                settingsDetailIntro("Turn on any Google calendars where Cadence should export. Workout and meal sync creates new events; toggling off does not yet remove past events.")
            }
        }
    }

    private func showStatus(_ message: String, tone: Theme.MetaPill.MetaTone = .accent, icon: String = "checkmark.circle.fill") {
        statusTone = tone
        statusIcon = icon
        statusMessage = message
    }

    private func appleCalendarBinding(_ calendarID: String) -> Binding<Bool> {
        Binding(
            get: { PlannerPreferences.isAppleCalendarEnabled(calendarID) },
            set: { enabled in
                PlannerPreferences.setAppleCalendarEnabled(calendarID, enabled: enabled)
                Task { await syncCalendars() }
            }
        )
    }

    private func googleCalendarBinding(_ calendarID: String) -> Binding<Bool> {
        Binding(
            get: { PlannerPreferences.isGoogleCalendarEnabled(calendarID) },
            set: { enabled in
                PlannerPreferences.setGoogleCalendarEnabled(calendarID, enabled: enabled)
                Task { await syncCalendars() }
            }
        )
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
        CalendarSyncService.shared.initializeAppleCalendarSelectionIfNeeded()
        await syncCalendars()
    }

    private func syncCalendars() async {
        isBusy = true
        defer { isBusy = false }
        await PlannerSyncCoordinator.shared.syncCalendars(in: modelContext)
        showStatus("Calendar sync updated.")
    }

    private func connectGoogle() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await GoogleCalendarService.shared.signIn()
            await loadGoogleCalendars()
            showStatus("Google account connected.")
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }

    private func loadGoogleCalendars() async {
        do {
            googleCalendars = try await GoogleCalendarService.shared.listCalendars()
            GoogleCalendarService.shared.initializeGoogleCalendarSelectionIfNeeded(with: googleCalendars)
            showStatus("Loaded \(googleCalendars.count) Google calendars.")
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }

    private func onAppearLoad() async {
        calendarStatus = CalendarSyncService.shared.authorizationStatus
        appleCalendars = CalendarSyncService.shared.availableCalendars()
        CalendarSyncService.shared.initializeAppleCalendarSelectionIfNeeded()
        if GoogleCalendarService.shared.isSignedIn {
            await loadGoogleCalendars()
        }
    }
}
