import Foundation
import SwiftUI
import Combine

/// Unified visibility + order for wheel / app grid.
/// Mobbin patterns: Garmin Edit Tabs, Binance Services ±, Todoist Navigation, Sonos Edit Home.
/// Today is pinned; Settings stays reachable from the drawer.
enum CadenceAppsPreferences {
    static let didChange = Notification.Name("CadenceAppsPreferences.didChange")

    private static let orderKey = "cadence_apps_order_v1"
    private static let hiddenKeyPrefix = "cadence_app_hidden_"

    /// Destinations users can show/hide on the dial + app grid.
    static let configurable: [WheelDestination] = [
        .calendar, .meals, .matrix, .habits, .inbox, .browse,
        .spend, .health, .news,
    ]

    /// Always present on the dial (home).
    static let pinned: [WheelDestination] = [.today]

    static var orderedVisibleDialDestinations: [WheelDestination] {
        var result: [WheelDestination] = pinned.filter { isVisible($0) }
        for id in savedOrder() {
            guard let dest = WheelDestination(rawValue: id),
                  configurable.contains(dest),
                  isVisible(dest),
                  !result.contains(dest) else { continue }
            result.append(dest)
        }
        for dest in configurable where isVisible(dest) && !result.contains(dest) {
            result.append(dest)
        }
        return result
    }

    static var hiddenConfigurable: [WheelDestination] {
        configurable.filter { !isVisible($0) }
    }

    static func isVisible(_ destination: WheelDestination) -> Bool {
        switch destination {
        case .today, .settings:
            return true
        case .shop:
            return isVisible(.meals)
        case .spend:
            return SpendPreferences.isEnabled
        case .health:
            return HealthPreferences.isEnabled
        case .workout:
            // Folded into Body (Health) — keep deep links working via RootView remap.
            return false
        case .news:
            return NewsPreferences.isEnabled
        default:
            let key = hiddenKeyPrefix + destination.rawValue
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return !UserDefaults.standard.bool(forKey: key)
        }
    }

    static func setVisible(_ destination: WheelDestination, _ visible: Bool) {
        switch destination {
        case .today, .settings:
            return
        case .shop:
            setVisible(.meals, visible)
            return
        case .spend:
            SpendPreferences.isEnabled = visible
        case .health:
            HealthPreferences.isEnabled = visible
            // Keep Lift toggle in sync with Body visibility.
            UserDefaults.standard.set(!visible, forKey: hiddenKeyPrefix + WheelDestination.workout.rawValue)
        case .workout:
            setVisible(.health, visible)
            return
        case .news:
            NewsPreferences.isEnabled = visible
        default:
            UserDefaults.standard.set(!visible, forKey: hiddenKeyPrefix + destination.rawValue)
        }
        notify()
    }

    static func toggleVisible(_ destination: WheelDestination) {
        setVisible(destination, !isVisible(destination))
    }

    static var orderedConfigurableVisible: [WheelDestination] {
        orderedVisibleDialDestinations.filter { configurable.contains($0) }
    }

    /// Replaces the configurable dial order (Today stays pinned first).
    static func setOrder(_ destinations: [WheelDestination]) {
        let cleaned = destinations.filter { configurable.contains($0) }.map(\.rawValue)
        UserDefaults.standard.set(cleaned, forKey: orderKey)
        notify()
    }

    static func reorderConfigurableVisible(from source: IndexSet, to destination: Int) {
        var items = orderedConfigurableVisible
        items.move(fromOffsets: source, toOffset: destination)
        setOrder(items)
    }

    /// Moves a configurable dial app in front of `before` (or to the end if nil).
    /// Today stays pinned first and cannot be reordered.
    static func moveDialDestination(_ moving: WheelDestination, before: WheelDestination?) {
        guard configurable.contains(moving) else { return }
        var order = orderedConfigurableVisible.filter { $0 != moving }
        if let before {
            if before == .today {
                order.insert(moving, at: 0)
            } else if let idx = order.firstIndex(of: before) {
                order.insert(moving, at: idx)
            } else {
                order.append(moving)
            }
        } else {
            order.append(moving)
        }
        setOrder(order)
    }

    /// Moves `moving` to the slot currently occupied by `target` among visible dial apps.
    static func moveDialDestination(_ moving: WheelDestination, onto target: WheelDestination) {
        guard configurable.contains(moving), moving != target else { return }
        if target == .today {
            moveDialDestination(moving, before: orderedConfigurableVisible.first)
            return
        }
        guard configurable.contains(target), isVisible(target) else { return }
        var order = orderedConfigurableVisible.filter { $0 != moving }
        if let idx = order.firstIndex(of: target) {
            order.insert(moving, at: idx)
        } else {
            order.append(moving)
        }
        setOrder(order)
    }

    /// Moves `destination` before `before` in the saved order (or to end if nil).
    static func move(_ destination: WheelDestination, before: WheelDestination?) {
        moveDialDestination(destination, before: before)
    }

    static func restoreDefaults() {
        for dest in configurable {
            UserDefaults.standard.removeObject(forKey: hiddenKeyPrefix + dest.rawValue)
        }
        SpendPreferences.isEnabled = true
        HealthPreferences.isEnabled = true
        NewsPreferences.isEnabled = true
        UserDefaults.standard.removeObject(forKey: orderKey)
        notify()
    }

    static func blurb(for destination: WheelDestination) -> String {
        switch destination {
        case .today: return "Home timeline — always on"
        case .calendar: return "3-day focus calendar"
        case .meals: return "Meal plan and shop list"
        case .matrix: return "Eisenhower matrix"
        case .habits: return "Habit tracking"
        case .inbox: return "Undated tasks"
        case .browse: return "Cookbook browser"
        case .workout: return "Merged into Body"
        case .spend: return "Purchases and cost-per-use"
        case .health: return "Strain, recovery, sleep & Lift"
        case .news: return "Daily digest with AI briefs"
        case .shop: return "Follows Meals"
        case .settings: return "Always available from the drawer"
        }
    }

    private static func savedOrder() -> [String] {
        UserDefaults.standard.stringArray(forKey: orderKey) ?? []
    }

    private static func notify() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// One-time: hide standalone Workout dial tile and keep Body (Health) visible if Lift was on.
    static func migrateWorkoutIntoBodyIfNeeded() {
        let flag = "cadence_migrated_workout_into_body_v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let workoutWasHiddenKey = hiddenKeyPrefix + WheelDestination.workout.rawValue
        let workoutExplicitlyHidden = UserDefaults.standard.object(forKey: workoutWasHiddenKey) != nil
            && UserDefaults.standard.bool(forKey: workoutWasHiddenKey)
        if !workoutExplicitlyHidden {
            HealthPreferences.isEnabled = true
        }
        UserDefaults.standard.set(true, forKey: workoutWasHiddenKey)
        // Drop workout from saved order.
        if var order = UserDefaults.standard.stringArray(forKey: orderKey) {
            order.removeAll { $0 == WheelDestination.workout.rawValue }
            if !order.contains(WheelDestination.health.rawValue) {
                order.append(WheelDestination.health.rawValue)
            }
            UserDefaults.standard.set(order, forKey: orderKey)
        }
        UserDefaults.standard.set(true, forKey: flag)
        notify()
    }
}

/// Observable bridge so SwiftUI refreshes when app visibility changes.
@MainActor
final class CadenceAppsModel: ObservableObject {
    @Published private(set) var revision: Int = 0

    init() {
        NotificationCenter.default.addObserver(
            forName: CadenceAppsPreferences.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.revision += 1
        }
    }

    var dialItems: [WheelNavItem] {
        _ = revision
        return CadenceAppsPreferences.orderedVisibleDialDestinations.map(\.navItem)
    }

    func isVisible(_ destination: WheelDestination) -> Bool {
        _ = revision
        return CadenceAppsPreferences.isVisible(destination)
    }
}
