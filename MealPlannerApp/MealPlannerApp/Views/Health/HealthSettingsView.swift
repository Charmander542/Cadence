import SwiftUI
import SwiftData

struct HealthSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var enabled = HealthPreferences.isEnabled
    @State private var demoFallback = HealthPreferences.preferDemoFallback
    @State private var sleepGoal = HealthPreferences.sleepGoalHours
    @State private var status: String?
    @State private var statusTone: Theme.MetaPill.MetaTone = .accent
    @State private var statusIcon = "checkmark.circle.fill"
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                Toggle("Show Body on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.health, value)
                        showStatus(value ? "Body shown on dial." : "Body hidden from dial.", tone: .neutral)
                    }
                Stepper(
                    "Sleep goal: \(String(format: "%.1f", sleepGoal)) h",
                    value: $sleepGoal,
                    in: 5...10,
                    step: 0.5
                )
                .onChange(of: sleepGoal) { _, value in
                    HealthPreferences.sleepGoalHours = value
                }
            } header: {
                settingsDetailSectionHeader("On dial")
            } footer: {
                settingsDetailIntro("Hide Body without deleting Health snapshots or Lift logs. Sleep goal feeds Bevel-style duration scoring.")
            }

            Section {
                Toggle("Demo data when Health is empty", isOn: $demoFallback)
                    .tint(Theme.cta)
                    .onChange(of: demoFallback) { _, value in
                        HealthPreferences.preferDemoFallback = value
                    }

                Button {
                    Task { await connect() }
                } label: {
                    settingsCTALabel(busy ? "Working…" : "Connect Apple Health", systemImage: "heart.text.square")
                }
                .disabled(busy)
                .accessibilityHint("Requests HealthKit read access and pulls today’s samples")

                if HealthPreferences.didRequestAuthorization {
                    LabeledContent("Authorization", value: "Requested")
                }

                Button {
                    _ = try? HealthStore.upsertSnapshot(
                        day: Date(),
                        raw: HealthStore.demoRaw(),
                        source: .demo,
                        in: modelContext
                    )
                    showStatus("Demo day refreshed.")
                } label: {
                    settingsCTALabel("Reload demo day", systemImage: "sparkles")
                }
            } header: {
                settingsDetailSectionHeader("Apple Health")
            } footer: {
                settingsDetailIntro("Reads sleep stages, overnight RHR, HRV, SpO₂, workouts, exercise minutes, steps, and active energy. See docs/APPLE_HEALTH_SETUP.md.")
            }

            if let status {
                Section {
                    SettingsStatusBanner(message: status, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Link("Apple HealthKit docs", destination: URL(string: "https://developer.apple.com/documentation/healthkit")!)
            } header: {
                settingsDetailSectionHeader("Docs")
            }
        }
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .onAppear {
            enabled = HealthPreferences.isEnabled
            demoFallback = HealthPreferences.preferDemoFallback
        }
    }

    private func showStatus(_ message: String, tone: Theme.MetaPill.MetaTone = .accent, icon: String = "checkmark.circle.fill") {
        statusTone = tone
        statusIcon = icon
        status = message
    }

    @MainActor
    private func connect() async {
        busy = true
        defer { busy = false }
        let client = HealthKitClient()
        guard await client.isAvailable else {
            showStatus("HealthKit unavailable — using demo data.", tone: .neutral, icon: "info.circle.fill")
            HealthStore.ensureDemoSnapshot(in: modelContext)
            return
        }
        do {
            try await client.requestAuthorization()
            HealthPreferences.didRequestAuthorization = true
            let raw = try await client.fetchDayMetrics()
            _ = try HealthStore.upsertSnapshot(day: Date(), raw: raw, source: .healthKit, in: modelContext)
            if !enabled {
                enabled = true
                CadenceAppsPreferences.setVisible(.health, true)
            }
            showStatus("Connected. Pulled today’s samples (empty metrics may still show demo fallback).")
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }
}
