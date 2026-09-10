import Foundation
import SwiftData
import SwiftUI

/// Deep-link automation for simulator UX testing. Invoked via `cadence://` URLs from
/// `scripts/cadence_sim.py` while the app is running (no relaunch needed).
enum CadenceAutomation {
    private static let tabNames: [String: Int] = [
        "today": 0, "calendar": 1, "meals": 2, "matrix": 3, "habits": 4,
    ]

    @MainActor
    static func handle(_ url: URL, appModel: AppModel) {
        guard url.scheme?.lowercased() == "cadence" else { return }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/").map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "tab":
            guard parts.count >= 2 else { return }
            let token = parts[1].lowercased()
            if let index = Int(token), (0...4).contains(index) {
                appModel.requestedMainTab = index
            } else if let index = tabNames[token] {
                appModel.requestedMainTab = index
            }
            log("tab", token)

        case "open":
            guard parts.count >= 2 else { return }
            switch parts[1].lowercased() {
            case "settings":
                appModel.showSettingsSheet = true
                log("open", "settings")
            case "search":
                appModel.showGlobalSearchSheet = true
                log("open", "search")
            case "shop":
                appModel.requestedOpenShop = true
                log("open", "shop")
            case "drawer":
                appModel.requestedOpenDrawer = true
                log("open", "drawer")
            default:
                break
            }

        case "close":
            guard parts.count >= 2 else { return }
            switch parts[1].lowercased() {
            case "settings":
                appModel.showSettingsSheet = false
                log("close", "settings")
            case "search":
                appModel.showGlobalSearchSheet = false
                log("close", "search")
            case "drawer":
                appModel.requestedCloseDrawer = true
                log("close", "drawer")
            case "all":
                appModel.showSettingsSheet = false
                appModel.showGlobalSearchSheet = false
                appModel.requestedCloseDrawer = true
                log("close", "all")
            default:
                break
            }

        default:
            break
        }
    }

    /// Marks onboarding complete for fresh simulator installs during automation.
    @MainActor
    static func skipOnboardingIfRequested(modelContext: ModelContext, profiles: [UserProfileEntity]) {
        guard ProcessInfo.processInfo.arguments.contains("-cadenceSkipOnboarding") else { return }
        let profile = profiles.first ?? {
            let created = UserProfileEntity()
            modelContext.insert(created)
            return created
        }()
        guard !profile.onboardingComplete else { return }
        LocalMacros.apply(LocalMacros.compute(profile: profile), to: profile)
        profile.onboardingComplete = true
        try? modelContext.save()
        log("skip", "onboarding")
    }

    private static func log(_ action: String, _ detail: String) {
        print("CADENCE_AUTOMATION action=\(action) detail=\(detail)")
    }
}
