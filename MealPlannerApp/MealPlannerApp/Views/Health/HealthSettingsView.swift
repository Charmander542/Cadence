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
                SettingsPageHero(
                    systemImage: "heart.text.square",
                    title: "Body · Apple Health",
                    subtitle: "Bevel-style strain, recovery, and sleep from HealthKit / Apple Watch, plus the Lift program.",
                    tint: Theme.accent
                )
            }

            Section {
                Toggle("Show Body on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.health, value)
                        showStatus(value ? "Health shown on dial." : "Health hidden from dial.", tone: .neutral)
                    }
            } header: {
                settingsDetailSectionHeader("Sub-app")
            } footer: {
                Text("Turn off to hide Body (Health + Lift) without deleting snapshots or workout logs.")
                    .accessibilityAddTraits(.isStaticText)
            }

            Section {
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
                settingsDetailSectionHeader("Goals")
            } footer: {
                Text("Used by the Bevel-style sleep duration score (Time Asleep vs goal).")
                    .accessibilityAddTraits(.isStaticText)
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
                    Label(busy ? "Working…" : "Connect Apple Health", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                }
                .disabled(busy)
                .accessibilityHint("Requests HealthKit read access and pulls today’s samples")

                if HealthPreferences.didRequestAuthorization {
                    Theme.MetaPill(text: "Authorization requested", tone: .accent)
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
                    Label("Reload demo day", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                }
            } header: {
                settingsDetailSectionHeader("Apple Health")
            } footer: {
                Text("Cadence reads sleep stages, overnight RHR, HRV, SpO₂, respiratory rate, workouts, exercise minutes, steps, and active energy. Scores follow Bevel’s published Strain / Recovery / Sleep components. See docs/APPLE_HEALTH_SETUP.md.")
                    .accessibilityAddTraits(.isStaticText)
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
