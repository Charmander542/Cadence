import SwiftUI
import SwiftData

struct SpendSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendEnrollmentEntity.connectedAt, order: .reverse)
    private var enrollments: [SpendEnrollmentEntity]

    @StateObject private var linkCoordinator = PlaidLinkCoordinator()

    @State private var clientID: String = SpendPreferences.clientID
    @State private var secretDraft: String = ""
    @State private var hasStoredSecret = false
    @State private var environment: SpendPreferences.PlaidEnvironment = SpendPreferences.environment
    @State private var redirectURI: String = SpendPreferences.redirectURI
    @State private var enabled: Bool = SpendPreferences.isEnabled
    @State private var statusMessage: String?
    @State private var statusTone: Theme.MetaPill.MetaTone = .accent
    @State private var statusIcon = "checkmark.circle.fill"
    @State private var isBusy = false

    var body: some View {
        Form {
            Section {
                Toggle("Show Spend on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.spend, value)
                        showStatus(value ? "Spend shown on dial." : "Spend hidden from dial.", tone: .neutral)
                    }
            } header: {
                settingsDetailSectionHeader("On dial")
            } footer: {
                settingsDetailIntro("Hide Spend without deleting purchases or cost-per-use trackers.")
            }

            Section {
                TextField("Client ID", text: $clientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: clientID) { _, value in
                        SpendPreferences.clientID = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                SecureField(hasStoredSecret ? "Secret (saved — paste to replace)" : "Secret", text: $secretDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    saveSecret()
                } label: {
                    settingsCTALabel("Save secret to Keychain", systemImage: "key.fill")
                }
                .disabled(secretDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Picker("Environment", selection: $environment) {
                    ForEach(SpendPreferences.PlaidEnvironment.allCases) { env in
                        Text(env.title).tag(env)
                    }
                }
                .onChange(of: environment) { _, value in
                    SpendPreferences.environment = value
                }

                TextField("Redirect URI (optional)", text: $redirectURI)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: redirectURI) { _, value in
                        SpendPreferences.redirectURI = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
            } header: {
                settingsDetailSectionHeader("Plaid")
            } footer: {
                settingsDetailIntro("Sandbox secret from Plaid Dashboard → Keys. Redirect URI is required for many OAuth banks (Chase, etc.) — see docs/PLAID_SETUP.md. Secret stays on-device in Keychain.")
            }

            Section {
                Button {
                    Task { await openLink() }
                } label: {
                    settingsCTALabel(
                        linkCoordinator.isPreparing ? "Preparing Link…" : "Connect bank or card",
                        systemImage: "building.columns.fill"
                    )
                }
                .disabled(isBusy || linkCoordinator.isPreparing || !SpendPreferences.isConfigured)

                if environment == .sandbox {
                    Button {
                        Task { await addSandboxItem() }
                    } label: {
                        settingsCTALabel(
                            isBusy ? "Working…" : "Add sandbox test bank",
                            systemImage: "hammer.fill"
                        )
                    }
                    .disabled(isBusy || !SpendPreferences.isConfigured)
                } else {
                    Text("Sandbox test bank needs a sandbox secret. Your current keys look like Production — use Connect above for real banks/cards.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                if !enrollments.isEmpty {
                    Button {
                        Task { await syncAll() }
                    } label: {
                        settingsCTALabel(isBusy ? "Syncing…" : "Sync transactions", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isBusy)
                }
            } header: {
                settingsDetailSectionHeader("Link")
            } footer: {
                settingsDetailIntro("Each connection uses one Plaid Trial Item (max 10). Prefer real Link for your banks; sandbox is for pipeline testing.")
            }

            Section {
                if enrollments.isEmpty {
                    Text("No banks linked yet.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                } else {
                    ForEach(enrollments, id: \.id) { enrollment in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(enrollment.institutionName) {
                                Text(enrollment.isSandbox ? "Sandbox" : "Live")
                                    .foregroundStyle(Theme.muted)
                            }
                            if let synced = enrollment.lastSyncedAt {
                                Text("Synced \(synced.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                SpendStore.disconnectEnrollment(enrollment, in: modelContext)
                                showStatus("Disconnected \(enrollment.institutionName).", tone: .neutral)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                settingsDetailSectionHeader("Connections")
            }

            if let statusMessage {
                Section {
                    SettingsStatusBanner(message: statusMessage, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Link("Plaid Dashboard", destination: URL(string: "https://dashboard.plaid.com/")!)
                Link("Link iOS docs", destination: URL(string: "https://plaid.com/docs/link/ios/")!)
                Link("Transactions API", destination: URL(string: "https://plaid.com/docs/api/products/transactions/")!)
            } header: {
                settingsDetailSectionHeader("Docs")
            } footer: {
                Text("Full checklist: docs/PLAID_SETUP.md in the repo.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Spend")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .onAppear {
            SpendPreferences.ingestLocalSecretsIfNeeded()
            enabled = SpendPreferences.isEnabled
            clientID = SpendPreferences.clientID
            environment = SpendPreferences.environment
            redirectURI = SpendPreferences.redirectURI
            hasStoredSecret = !(KeychainStore.loadPlaidSecret()?.isEmpty ?? true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .plaidItemLinked)) { note in
            Task { await handleLinkedNotification(note) }
        }
        .onChange(of: linkCoordinator.lastError) { _, value in
            if let value, !value.isEmpty {
                showStatus(value, tone: .danger, icon: "exclamationmark.triangle.fill")
            }
        }
        .onChange(of: linkCoordinator.statusMessage) { _, value in
            if let value, !value.isEmpty {
                showStatus(value)
            }
        }
        .sheet(isPresented: $linkCoordinator.isPresentingLink) {
            if let content = linkCoordinator.sheetContent() {
                content
                    .ignoresSafeArea()
            } else {
                ProgressView("Loading Plaid…")
                    .padding()
            }
        }
    }

    private func showStatus(_ message: String, tone: Theme.MetaPill.MetaTone = .accent, icon: String = "checkmark.circle.fill") {
        statusTone = tone
        statusIcon = icon
        statusMessage = message
    }

    private func saveSecret() {
        let secret = secretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else { return }
        do {
            try KeychainStore.savePlaidSecret(secret)
            secretDraft = ""
            hasStoredSecret = true
            showStatus("Plaid secret saved to Keychain.")
        } catch {
            showStatus("Could not save secret: \(error.localizedDescription)", tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }

    @MainActor
    private func openLink() async {
        await linkCoordinator.prepareAndOpen()
    }

    @MainActor
    private func handleLinkedNotification(_ note: Notification) async {
        guard let itemID = note.userInfo?["itemID"] as? String else { return }
        let institution = (note.userInfo?["institutionName"] as? String) ?? "Linked bank"
        let isSandbox = (note.userInfo?["isSandbox"] as? Bool) ?? (SpendPreferences.environment == .sandbox)
        isBusy = true
        defer { isBusy = false }
        do {
            let enrollment = try await SpendStore.enrollPlaidItem(
                itemID: itemID,
                institutionName: institution,
                isSandbox: isSandbox,
                in: modelContext
            )
            showStatus("Synced \(enrollment.institutionName).")
            if !enabled {
                enabled = true
                CadenceAppsPreferences.setVisible(.spend, true)
            }
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }

    @MainActor
    private func addSandboxItem() async {
        guard let secret = KeychainStore.loadPlaidSecret(), !secret.isEmpty else {
            showStatus(PlaidClient.PlaidError.missingCredentials.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            SpendPreferences.environment = .sandbox
            environment = .sandbox
            let client = PlaidClient()
            let publicToken = try await client.createSandboxPublicToken(
                clientID: SpendPreferences.clientID,
                secret: secret
            )
            let enrollment = try await SpendStore.completePublicToken(
                publicToken,
                institutionNameHint: "First Platypus Bank",
                in: modelContext
            )
            showStatus("Sandbox bank ready — pulled transactions for \(enrollment.institutionName).")
            if !enabled {
                enabled = true
                CadenceAppsPreferences.setVisible(.spend, true)
            }
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }

    @MainActor
    private func syncAll() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let count = try await SpendStore.syncAllEnrollments(in: modelContext)
            showStatus(count == 0 ? "Already up to date." : "Updated \(count) transactions.")
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }
}
