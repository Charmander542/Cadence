import SwiftUI
import SwiftData

struct SpendSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendEnrollmentEntity.connectedAt, order: .reverse)
    private var enrollments: [SpendEnrollmentEntity]

    @State private var applicationID: String = SpendPreferences.applicationID
    @State private var environment: SpendPreferences.TellerEnvironment = SpendPreferences.environment
    @State private var enabled: Bool = SpendPreferences.isEnabled
    @State private var sandboxToken: String = ""
    @State private var statusMessage: String?
    @State private var statusTone: Theme.MetaPill.MetaTone = .accent
    @State private var statusIcon = "checkmark.circle.fill"
    @State private var isBusy = false

    var body: some View {
        Form {
            Section {
                SettingsPageHero(
                    systemImage: "creditcard",
                    title: "Spend & Teller",
                    subtitle: "Bank purchases and cost-per-use trackers. Sandbox tokens stay on-device.",
                    tint: Theme.cta
                )
            }

            Section {
                Toggle("Show Spend on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.spend, value)
                        showStatus(value ? "Spend shown on dial." : "Spend hidden from dial.", tone: .neutral)
                    }
            } header: {
                settingsDetailSectionHeader("Sub-app")
            } footer: {
                Text("Turn off to hide Spend without deleting purchases or trackers.")
                    .accessibilityAddTraits(.isStaticText)
            }

            Section {
                TextField("Application ID", text: $applicationID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: applicationID) { _, value in
                        SpendPreferences.applicationID = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                Picker("Environment", selection: $environment) {
                    ForEach(SpendPreferences.TellerEnvironment.allCases) { env in
                        Text(env.title).tag(env)
                    }
                }
                .onChange(of: environment) { _, value in
                    SpendPreferences.environment = value
                }
            } header: {
                settingsDetailSectionHeader("Teller")
            } footer: {
                Text("Follow docs/TELLER_SETUP.md. Never embed your mTLS private key in the app — use sandbox tokens here, and a backend for development/production.")
                    .accessibilityAddTraits(.isStaticText)
            }

            Section {
                if enrollments.isEmpty {
                    Text("No enrollments yet. Paste a sandbox access token below to pull demo bank data, or wire TellerKit Connect.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                } else {
                    ForEach(enrollments, id: \.id) { enrollment in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(enrollment.institutionName)
                                    .font(.subheadline.weight(.semibold))
                                Text(enrollment.isSandbox ? "Sandbox" : "Live")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Theme.MetaPill(text: enrollment.isSandbox ? "Sandbox" : "Live", tone: .cta)
                        }
                    }
                }

                if environment == .sandbox {
                    SecureField("Sandbox access token", text: $sandboxToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await connectSandboxToken() }
                    } label: {
                        Label(isBusy ? "Working…" : "Sync sandbox accounts", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.cta)
                    }
                    .disabled(sandboxToken.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
                }
            } header: {
                settingsDetailSectionHeader("Enrollments")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Link("Teller developer docs", destination: URL(string: "https://teller.io/docs")!)
                Link("Environments guide", destination: URL(string: "https://teller.io/docs/guides/environments")!)
            } header: {
                settingsDetailSectionHeader("Docs")
            }
        }
        .navigationTitle("Spend & Teller")
        .settingsFormChrome()
        .onAppear {
            enabled = SpendPreferences.isEnabled
            applicationID = SpendPreferences.applicationID
            environment = SpendPreferences.environment
        }
    }

    private func showStatus(_ message: String, tone: Theme.MetaPill.MetaTone = .accent, icon: String = "checkmark.circle.fill") {
        statusTone = tone
        statusIcon = icon
        statusMessage = message
    }

    @MainActor
    private func connectSandboxToken() async {
        let token = sandboxToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let client = TellerClient()
            let accounts = try await client.fetchAccounts(accessToken: token)
            guard let first = accounts.first else {
                showStatus("No accounts returned for this token.", tone: .danger, icon: "exclamationmark.triangle.fill")
                return
            }
            let enrollmentID = first.id
            KeychainStore.saveTellerAccessToken(token, enrollmentID: enrollmentID)
            let enrollment = SpendEnrollmentEntity(
                accessTokenKeychainAccount: "teller_access_\(enrollmentID)",
                institutionName: first.institution?.name ?? first.name ?? "Sandbox bank",
                enrollmentID: enrollmentID,
                isSandbox: true
            )
            enrollment.lastSyncedAt = Date()
            modelContext.insert(enrollment)

            let txs = try await client.fetchTransactions(accessToken: token, accountID: first.id)
            let accountLabel = [first.name, first.last_four.map { "••\($0)" }]
                .compactMap { $0 }
                .joined(separator: " ")
            try SpendStore.upsertTransactions(txs, accountName: accountLabel, in: modelContext)
            showStatus("Synced \(txs.count) transactions from \(enrollment.institutionName).")
            sandboxToken = ""
            if !enabled {
                enabled = true
                CadenceAppsPreferences.setVisible(.spend, true)
            }
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }
}
