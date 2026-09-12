import SwiftUI

/// Dial Browse page — cookbook search with drawer affordance (not a Coming Soon stub).
struct BrowseHomeView: View {
    var onOpenDrawer: () -> Void

    var body: some View {
        NavigationStack {
            BrowseView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: onOpenDrawer) {
                            Image(systemName: "line.3.horizontal")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open sidebar")
                        .accessibilityHint("Opens the sidebar")
                    }
                }
        }
        .tint(Theme.cta)
    }
}

/// Lightweight stand-in page for wheel destinations that are not fully built yet.
struct PlaceholderPageView: View {
    var title: String
    var systemImage: String
    var subtitle: String = "Coming soon — this is a placeholder so the wheel can show more sections."
    var onOpenDrawer: (() -> Void)? = nil
    var onGoToday: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let onOpenDrawer {
                PlannerScreenHeader(title: title, onMenu: onOpenDrawer) {
                    EmptyView()
                }
            }

            VStack(spacing: Theme.Space.lg) {
                Spacer(minLength: Theme.Space.xxl)
                Theme.IconWell(systemImage: systemImage, tint: Theme.muted, size: 72)
                Theme.MetaPill(text: "COMING SOON", tone: .accent)
                Text(title)
                    .font(Theme.title(.title2))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Space.xxl)
                if let onGoToday {
                    Theme.PrimaryButton(title: "Back to Today", systemImage: "sun.max") {
                        onGoToday()
                    }
                    .padding(.horizontal, Theme.Space.xxl + Theme.Space.md)
                    .accessibilityLabel("Back to Today")
                    .accessibilityHint("Returns to the Today screen")
                }
                Spacer()
            }
            .padding(Theme.Space.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas.ignoresSafeArea())
    }
}
