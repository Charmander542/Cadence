import SwiftUI
import SwiftData

struct NewsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    @State private var enabled = NewsPreferences.isEnabled
    @State private var autoAI = NewsPreferences.autoSummarizeWithAI
    @State private var status: String?
    @State private var statusTone: Theme.MetaPill.MetaTone = .accent
    @State private var statusIcon = "checkmark.circle.fill"
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                Toggle("Show News on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.news, value)
                        showStatus(value ? "News shown on dial." : "News hidden from dial.", tone: .neutral)
                    }
            } header: {
                settingsDetailSectionHeader("On dial")
            } footer: {
                settingsDetailIntro("Ten stories a day from public RSS. Optional AI briefs use your AI key.")
            }

            Section {
                Toggle("AI digests after refresh", isOn: $autoAI)
                    .tint(Theme.cta)
                    .onChange(of: autoAI) { _, value in
                        NewsPreferences.autoSummarizeWithAI = value
                    }

                if NewsPreferences.hasAIKey {
                    LabeledContent("Provider", value: KeychainStore.selectedProvider.title)
                } else {
                    Text("Add an AI key under Connections → AI to rewrite digests. Feeds still work without it.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .accessibilityAddTraits(.isStaticText)
                    NavigationLink(value: SettingsRoute.ai) {
                        settingsCTALabel("Open AI settings", systemImage: "sparkles")
                    }
                }

                Button {
                    Task { await refresh() }
                } label: {
                    settingsCTALabel(busy ? "Working…" : "Refresh today’s 10", systemImage: "arrow.clockwise")
                }
                .disabled(busy)
                .accessibilityHint("Fetches RSS feeds and optionally runs AI digests")

                Button {
                    let day = Date()
                    NewsStore.upsert(NewsStore.demoArticles(for: day), day: day, in: modelContext)
                    NewsStore.upsertBriefing(
                        day: day,
                        headline: "Ten stories worth your attention",
                        blurb: "Demo slate for layout and image treatment.",
                        count: 10,
                        usedAI: false,
                        in: modelContext
                    )
                    showStatus("Demo slate loaded.")
                } label: {
                    settingsCTALabel("Reload demo slate", systemImage: "sparkles")
                }
            } header: {
                settingsDetailSectionHeader("Digest")
            } footer: {
                settingsDetailIntro("Sources: BBC, NPR, NASA, ScienceDaily, The Verge, CNBC, Smithsonian. See docs/NEWS_SETUP.md.")
            }

            if let status {
                Section {
                    SettingsStatusBanner(message: status, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
        .settingsFormChrome()
        .onAppear {
            enabled = NewsPreferences.isEnabled
            autoAI = NewsPreferences.autoSummarizeWithAI
        }
    }

    private func showStatus(_ message: String, tone: Theme.MetaPill.MetaTone = .accent, icon: String = "checkmark.circle.fill") {
        statusTone = tone
        statusIcon = icon
        status = message
    }

    @MainActor
    private func refresh() async {
        busy = true
        defer { busy = false }
        do {
            try await NewsStore.refresh(llm: appModel.llm, in: modelContext)
            if !enabled {
                enabled = true
                CadenceAppsPreferences.setVisible(.news, true)
            }
            showStatus("Digest refreshed.")
        } catch {
            showStatus(error.localizedDescription, tone: .danger, icon: "exclamationmark.triangle.fill")
        }
    }
}
