import SwiftUI

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
                Spacer(minLength: 24)
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Theme.cta)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if let onGoToday {
                    Button("Back to Today", action: onGoToday)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cta)
                        .accessibilityLabel("Back to Today")
                        .accessibilityHint("Returns to the Today screen")
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas.ignoresSafeArea())
    }
}
