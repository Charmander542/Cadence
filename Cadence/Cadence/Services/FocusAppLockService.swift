import Foundation
import FamilyControls
import ManagedSettings

/// Screen Time shields for Focus sessions — blocks other apps while a timer is running.
/// iOS cannot force-quit apps; this applies the system shield instead.
enum FocusAppLockService {
    private static let storeName = ManagedSettingsStore.Name("focus.session")
    private static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: storeName)
    }

    static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    static var authorizationStatus: AuthorizationStatus {
        AuthorizationCenter.shared.authorizationStatus
    }

    @MainActor
    static func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return isAuthorized
        } catch {
            return false
        }
    }

    /// Shields all app categories for the duration of a Focus session.
    @MainActor
    static func engageLock() {
        guard FocusPreferences.lockAppsDuringSession, isAuthorized else { return }
        store.shield.applicationCategories = .all()
    }

    /// Clears Focus session shields (pause / finish / reset / crash recovery).
    @MainActor
    static func releaseLock() {
        store.clearAllSettings()
    }

    /// Requests auth if needed, then engages. Returns whether the lock is active.
    @MainActor
    @discardableResult
    static func engageLockIfEnabled() async -> Bool {
        guard FocusPreferences.lockAppsDuringSession else { return false }
        if !isAuthorized {
            let ok = await requestAuthorization()
            guard ok else { return false }
        }
        engageLock()
        return true
    }
}
