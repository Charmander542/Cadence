import SwiftUI

enum NewsChrome {
    struct RemoteImage: View {
        let url: URL?
        var height: CGFloat = 180
        var cornerRadius: CGFloat = Theme.Radius.lg

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Theme.sunken, Theme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderIcon
                        case .empty:
                            ProgressView()
                                .tint(Theme.cta)
                        @unknown default:
                            placeholderIcon
                        }
                    }
                } else {
                    placeholderIcon
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }

        private var placeholderIcon: some View {
            Image(systemName: "newspaper.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.muted)
        }
    }

    struct TopicChip: View {
        let topic: NewsTopic
        var selected = false
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: topic.systemImage)
                        .font(.caption2.weight(.bold))
                    Text(topic.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                }
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm + 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.accent : Theme.sunken)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(topic.title)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
    }

    struct ArticleCard: View {
        let article: NewsArticleEntity
        var hero = false
        var onOpen: () -> Void

        var body: some View {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
                    ZStack(alignment: .bottomLeading) {
                        NewsChrome.RemoteImage(
                            url: article.imageURL,
                            height: hero ? 210 : 150
                        )
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: hero ? 210 : 150)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                        .allowsHitTesting(false)

                        Text(article.topic.title.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.accent.opacity(0.92)))
                            .padding(Theme.Space.md)
                            .allowsHitTesting(false)
                    }

                    Text(article.title)
                        .font(hero ? Theme.display(.title3) : .headline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.digestText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(hero ? 4 : 3)

                    HStack {
                        Text("\(article.sourceName) · \(relative(article.publishedAt))")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        if !article.aiBrief.isEmpty {
                            Text("AI BRIEF")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(Theme.cta)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(Theme.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(article.topic.title). \(article.title). \(article.digestText)")
            .accessibilityHint("Opens digest and article link")
        }

        private func relative(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
}
