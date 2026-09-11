import SwiftUI
import SwiftData

/// Daily News — Perplexity/Apple News–style cards with AI digests.
/// Mobbin: Perplexity Discover, Apple News Today, Particle hero, theScore featured.
struct NewsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appModel: AppModel
    var onOpenDrawer: () -> Void = {}

    @Query(sort: \NewsArticleEntity.sortOrder)
    private var articles: [NewsArticleEntity]
    @Query(sort: \NewsBriefingEntity.dayStart, order: .reverse)
    private var briefings: [NewsBriefingEntity]

    @State private var topicFilter: NewsTopic?
    @State private var selected: NewsArticleEntity?
    @State private var showSettings = false
    @State private var isRefreshing = false
    @State private var statusMessage: String?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var todayArticles: [NewsArticleEntity] {
        articles.filter { Calendar.current.isDate($0.dayStart, inSameDayAs: today) }
    }

    private var visible: [NewsArticleEntity] {
        guard let topicFilter else { return todayArticles }
        return todayArticles.filter { $0.topic == topicFilter }
    }

    private var briefing: NewsBriefingEntity? {
        briefings.first { Calendar.current.isDate($0.dayStart, inSameDayAs: today) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerTitleHeader(title: "News", onMenu: onOpenDrawer)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    headerBlock
                        .padding(.horizontal, Theme.Space.lg)

                    topicChips
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.vertical, Theme.Space.xs)
                        .padding(.bottom, Theme.Space.md)
                        .zIndex(1)

                    if visible.isEmpty {
                        Theme.EmptyState(
                            systemImage: "newspaper",
                            title: "No stories yet",
                            message: "Refresh to pull today’s top mix from public feeds, then AI can tighten the digests.",
                            cta: "REFRESH DIGEST",
                            ctaHint: "Fetches RSS and optional AI summaries"
                        ) {
                            Task { await refresh() }
                        }
                        .padding(.horizontal, Theme.Space.lg)
                    } else {
                        LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                            ForEach(Array(visible.enumerated()), id: \.element.id) { index, article in
                                NewsChrome.ArticleCard(article: article, hero: index == 0 && topicFilter == nil) {
                                    selected = article
                                }
                                .padding(.horizontal, Theme.Space.lg)
                            }
                        }
                    }
                }
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, 110)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas.ignoresSafeArea())
        .onAppear {
            NewsStore.seedDemoIfNeeded(in: modelContext)
        }
        .onChange(of: appModel.requestedFABAction) { _, action in
            guard action == .refreshNews else { return }
            Task { await refresh() }
            appModel.requestedFABAction = nil
        }
        .sheet(item: $selected) { article in
            NewsArticleDetailView(article: article)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                NewsSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSettings = false }
                                .foregroundStyle(Theme.cta)
                        }
                    }
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(briefing?.headline ?? "Daily digest")
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.ink)
                    Text(briefing?.blurb ?? "Ten stories · world, science, tech, and more")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Space.sm)
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.cta)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .accessibilityLabel("Refresh digest")
                .disabled(isRefreshing)

                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("News settings")
            }

            HStack(spacing: Theme.Space.sm) {
                metaPill(
                    icon: briefing?.usedAI == true ? "sparkles" : "dot.radiowaves.left.and.right",
                    text: briefing?.usedAI == true ? "AI BRIEFS" : "RSS MIX"
                )
                metaPill(
                    icon: "calendar",
                    text: syncLabel
                )
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
        }
    }

    private var syncLabel: String {
        if let at = NewsPreferences.lastSyncAt {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return "SYNCED \(f.string(from: at).uppercased())"
        }
        return "DEMO"
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.cta)
            Text(text)
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, Theme.Space.sm + 2)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.sunken))
    }

    private var topicChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                Button {
                    topicFilter = nil
                } label: {
                    Text("ALL")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(topicFilter == nil ? Color.white : Theme.ink)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.vertical, Theme.Space.sm + 2)
                        .background(Capsule().fill(topicFilter == nil ? Theme.accent : Theme.sunken))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All topics")
                .accessibilityAddTraits(topicFilter == nil ? [.isButton, .isSelected] : .isButton)

                ForEach([NewsTopic.world, .science, .tech, .business, .culture, .health]) { topic in
                    NewsChrome.TopicChip(topic: topic, selected: topicFilter == topic) {
                        topicFilter = topic
                    }
                }
            }
            .padding(.vertical, 2)
        }
        // Keep chip taps from competing with the first article card.
        .contentShape(Rectangle())
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await NewsStore.refresh(llm: appModel.llm, in: modelContext)
            statusMessage = NewsPreferences.hasAIKey ? "Updated with AI" : "Feeds updated"
        } catch {
            statusMessage = error.localizedDescription
            if todayArticles.isEmpty {
                NewsStore.seedDemoIfNeeded(in: modelContext)
            }
        }
    }
}
