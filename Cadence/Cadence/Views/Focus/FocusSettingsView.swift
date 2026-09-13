import SwiftUI

struct FocusSettingsView: View {
    @State private var enabled = FocusPreferences.isEnabled
    @State private var pomoMinutes = FocusPreferences.pomoMinutes
    @State private var lockApps = FocusPreferences.lockAppsDuringSession
    @State private var status: String?
    @State private var isRequestingAuth = false

    var body: some View {
        Form {
            Section {
                Toggle("Show Focus on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.focus, value)
                        status = value ? "Focus shown on dial." : "Focus hidden from dial."
                    }
            } header: {
                settingsDetailSectionHeader("On dial")
            } footer: {
                settingsDetailIntro("Pomodoro countdown and stopwatch with a stats log. Tap the time on the timer to set session length in 5-minute steps.")
            }

            Section {
                Stepper(value: $pomoMinutes, in: 5...90, step: 5) {
                    LabeledContent("Default Pomo", value: "\(pomoMinutes) min")
                }
                .onChange(of: pomoMinutes) { _, value in
                    FocusPreferences.pomoMinutes = FocusPreferences.snapMinutes(value)
                    pomoMinutes = FocusPreferences.pomoMinutes
                }
            } header: {
                settingsDetailSectionHeader("Timer")
            }

            Section {
                Toggle("Lock other apps during session", isOn: $lockApps)
                    .tint(Theme.cta)
                    .disabled(isRequestingAuth)
                    .onChange(of: lockApps) { _, value in
                        Task { await setLockApps(value) }
                    }
            } header: {
                settingsDetailSectionHeader("App lock")
            } footer: {
                Text("Uses Screen Time to block other apps while a session is running. Cadence cannot force-quit apps. Requires Screen Time permission; full lock works on a physical device.")
                    .font(.footnote)
            }

            if let status {
                Section {
                    SettingsStatusBanner(message: status, systemImage: "checkmark.circle.fill", tone: .accent)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .onAppear {
            enabled = FocusPreferences.isEnabled
            pomoMinutes = FocusPreferences.pomoMinutes
            lockApps = FocusPreferences.lockAppsDuringSession
        }
    }

    @MainActor
    private func setLockApps(_ value: Bool) async {
        if value {
            isRequestingAuth = true
            defer { isRequestingAuth = false }
            if !FocusAppLockService.isAuthorized {
                let ok = await FocusAppLockService.requestAuthorization()
                if !ok {
                    lockApps = false
                    FocusPreferences.lockAppsDuringSession = false
                    status = "Screen Time permission is required to lock apps."
                    return
                }
            }
            FocusPreferences.lockAppsDuringSession = true
            status = "Other apps will be blocked while a session runs."
        } else {
            FocusPreferences.lockAppsDuringSession = false
            FocusAppLockService.releaseLock()
            status = "App lock turned off."
        }
    }
}
