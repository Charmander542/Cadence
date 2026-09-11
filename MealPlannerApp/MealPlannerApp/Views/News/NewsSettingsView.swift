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
                SettingsPageHero(
                    systemImage: "newspaper",
                    title: "News digest",
                    subtitle: "Ten stories a day from public RSS. Optional AI briefs use your Settings → AI key.",
                    tint: Theme.cta
                )
            }

            Section {
                Toggle("Show News on wheel", isOn: $enabled)
                    .tint(Theme.cta)
                    .onChange(of: enabled) { _, value in
                        CadenceAppsPreferences.setVisible(.news, value)
                        showStatus(value ? "News shown on dial." : "News hidden from dial.", tone: .neutral)
                    }
            } header: {
                settingsDetailSectionHeader("Sub-app")
            }

            Section {
                Toggle("AI digests after refresh", isOn: $autoAI)
                    .tint(Theme.cta)
                    .onChange(of: autoAI) { _, value in
                        NewsPreferences.autoSummarizeWithAI = value
                    }
                Text(NewsPreferences.hasAIKey
                     ? "Using \(KeychainStore.selectedProvider.title) from Settings → AI."
                     : "Add an AI key in Settings → AI to rewrite digests. Feeds still work without it.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isStaticText)

                if !NewsPreferences.hasAIKey {
                    NavigationLink(value: SettingsRoute.ai) {
                        Label("Open AI settings", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.cta)
                    }
                }

                Button {
                    Task { await refresh() }
                } label: {
                    Label(busy ? "Working…" : "Refresh today’s 10", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
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
                    Label("Reload demo slate", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                }
            } header: {
                settingsDetailSectionHeader("Digest")
            } footer: {
                Text("Stories come from public RSS (BBC, NPR, NASA, ScienceDaily, The Verge, CNBC, Smithsonian). See docs/NEWS_SETUP.md.")
                    .accessibilityAddTraits(.isStaticText)
            }

            if let status {
                Section {
                    SettingsStatusBanner(message: status, systemImage: statusIcon, tone: statusTone)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .navigationTitle("News")
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
