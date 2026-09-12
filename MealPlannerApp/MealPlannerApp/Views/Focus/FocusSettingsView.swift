import SwiftUI

struct FocusSettingsView: View {
    @State private var enabled = FocusPreferences.isEnabled
    @State private var pomoMinutes = FocusPreferences.pomoMinutes
    @State private var status: String?

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
        }
    }
}
