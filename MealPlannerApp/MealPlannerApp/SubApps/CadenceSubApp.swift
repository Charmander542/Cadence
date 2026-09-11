import Foundation
import SwiftUI

/// Registry for first-class Cadence “sub-apps” (Spend, Health, News, …).
enum CadenceSubAppID: String, CaseIterable, Identifiable, Hashable {
    case spend
    case health
    case news

    var id: String { rawValue }
}

struct CadenceSubAppManifest: Identifiable, Hashable {
    let id: CadenceSubAppID
    let title: String
    let systemImage: String
    let blurb: String
    let wheelDestination: WheelDestination
    let settingsRoute: SettingsRoute
    let docsPath: String

    var isEnabled: Bool {
        switch id {
        case .spend: return SpendPreferences.isEnabled
        case .health: return HealthPreferences.isEnabled
        case .news: return NewsPreferences.isEnabled
        }
    }
}

enum CadenceSubAppRegistry {
    static let all: [CadenceSubAppManifest] = [
        CadenceSubAppManifest(
            id: .spend,
            title: "Spend",
            systemImage: "creditcard",
            blurb: "Bank purchases via Teller, categorize, and track cost-per-use.",
            wheelDestination: .spend,
            settingsRoute: .spend,
            docsPath: "docs/TELLER_SETUP.md"
        ),
        CadenceSubAppManifest(
            id: .health,
            title: "Health",
            systemImage: "heart.text.square",
            blurb: "Apple Health vitals with Bevel-like rings, energy, and playful scrubbing.",
            wheelDestination: .health,
            settingsRoute: .health,
            docsPath: "docs/APPLE_HEALTH_SETUP.md"
        ),
        CadenceSubAppManifest(
            id: .news,
            title: "News",
            systemImage: "newspaper",
            blurb: "Daily top-10 digest with AI briefs, mixed topics, and article photos.",
            wheelDestination: .news,
            settingsRoute: .news,
            docsPath: "docs/NEWS_SETUP.md"
        ),
    ]

    static var enabled: [CadenceSubAppManifest] {
        all.filter(\.isEnabled)
    }

    static func manifest(for id: CadenceSubAppID) -> CadenceSubAppManifest? {
        all.first { $0.id == id }
    }

    static func isWheelEnabled(_ destination: WheelDestination) -> Bool {
        CadenceAppsPreferences.isVisible(destination)
    }
}
