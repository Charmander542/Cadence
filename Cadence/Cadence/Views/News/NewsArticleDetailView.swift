import SwiftUI
import SwiftData

struct NewsArticleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Bindable var article: NewsArticleEntity

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    NewsChrome.RemoteImage(url: article.imageURL, height: 240)
                        .padding(.horizontal, Theme.Space.lg)

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        HStack {
                            Label(article.topic.title.uppercased(), systemImage: article.topic.systemImage)
                                .font(.caption2.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.accent)
                            Spacer()
                            Text(article.sourceName)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Text(article.title)
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    Theme.Card {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(article.aiBrief.isEmpty ? "DIGEST" : "AI BRIEF")
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.muted)
                            Text(article.digestText)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if !article.whyItMatters.isEmpty {
                                Divider().overlay(Theme.gridDivider)
                                Text("WHY IT MATTERS")
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.7)
                                    .foregroundStyle(Theme.muted)
                                Text(article.whyItMatters)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)

                    if !article.rawSummary.isEmpty, article.rawSummary != article.aiBrief {
                        Theme.Card {
                            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                                Text("FROM THE FEED")
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(Theme.muted)
                                Text(article.rawSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.horizontal, Theme.Space.lg)
                    }

                    Theme.PrimaryButton(title: "OPEN ARTICLE", systemImage: "safari") {
                        article.isRead = true
                        if let url = article.url {
                            openURL(url)
                        }
                    }
                    .padding(.horizontal, Theme.Space.lg)
                    .accessibilityHint("Opens the original story in Safari")
                    .disabled(article.url == nil)
                }
                .padding(.vertical, Theme.Space.lg)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cta)
                }
            }
            .onAppear { article.isRead = true }
        }
    }
}
