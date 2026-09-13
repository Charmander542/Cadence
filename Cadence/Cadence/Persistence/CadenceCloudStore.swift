import Foundation
import SwiftData
import CloudKit
import OSLog

/// Owns the SwiftData + CloudKit container. Never deletes the primary store on failure —
/// that was wiping cost/use and planner data when CloudKit briefly failed to open.
enum CadenceCloudStore {
    static let containerIdentifier = "iCloud.com.musclemeal.app"
    /// Stable store name — keep across CloudKit enablement so local rows stay put.
    static let storeName = "musclemeal-v10"

    private static let log = Logger(subsystem: "com.musclemeal.app", category: "CloudStore")

    static let schema = Schema([
        UserProfileEntity.self,
        WeeklyPlanEntity.self,
        GroceryItemEntity.self,
        RecipeHistoryEntity.self,
        PantryItemEntity.self,
        WorkoutPlanEntity.self,
        WorkoutLogEntity.self,
        TaskListEntity.self,
        PlannerTaskEntity.self,
        PlannerNoteEntity.self,
        PlannerTagEntity.self,
        HabitEntity.self,
        HabitLogEntity.self,
        SpendEnrollmentEntity.self,
        SpendTransactionEntity.self,
        SpendTrackedItemEntity.self,
        SpendUseLogEntity.self,
        HealthDaySnapshotEntity.self,
        NewsArticleEntity.self,
        NewsBriefingEntity.self,
        FocusSessionEntity.self,
        SpendSubcategoryEntity.self,
        SpendBudgetEntity.self,
        SpendUserCategoryEntity.self,
        SpendMerchantRuleEntity.self,
    ])

    /// True when the live container was opened with CloudKit (not local-only fallback).
    private(set) static var isCloudKitEnabled = false

    static func makeContainer() -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(containerIdentifier)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            isCloudKitEnabled = true
            log.info("Opened SwiftData store with CloudKit (\(containerIdentifier, privacy: .public))")
            return container
        } catch {
            // Do NOT delete store files. CloudKit validation / offline account issues
            // must not destroy local cost/use, planner, or meal data.
            log.error("CloudKit ModelContainer failed: \(String(describing: error), privacy: .public)")
        }

        let localConfig = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [localConfig])
            isCloudKitEnabled = false
            log.warning("Opened local-only SwiftData store (iCloud unavailable or schema rejected)")
            return container
        } catch {
            log.error("Local ModelContainer failed: \(String(describing: error), privacy: .public)")
            // Absolute last resort: in-memory so the app still launches. Data won't persist.
            let memory = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                isCloudKitEnabled = false
                return try ModelContainer(for: schema, configurations: [memory])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    @MainActor
    static func refreshAccountStatus() async -> String {
        let container = CKContainer(identifier: containerIdentifier)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return CadenceCloudStore.isCloudKitEnabled ? "On — syncing via iCloud" : "iCloud available (local store)"
            case .noAccount:
                return "Sign in to iCloud in Settings"
            case .restricted:
                return "iCloud restricted on this device"
            case .couldNotDetermine:
                return "Could not determine iCloud status"
            case .temporarilyUnavailable:
                return "iCloud temporarily unavailable"
            @unknown default:
                return "Unknown iCloud status"
            }
        } catch {
            return "iCloud check failed"
        }
    }

    static func save(_ context: ModelContext, label: String = "autosave") {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            log.error("Save failed (\(label, privacy: .public)): \(String(describing: error), privacy: .public)")
        }
    }
}
