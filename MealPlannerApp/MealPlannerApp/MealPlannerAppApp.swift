import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    @StateObject private var appModel = AppModel()

    var sharedModelContainer: ModelContainer = {
        Self.makeModelContainer()
    }()

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            UserProfileEntity.self,
            WeeklyPlanEntity.self,
            GroceryItemEntity.self,
            RecipeHistoryEntity.self,
            PantryItemEntity.self,
            WorkoutPlanEntity.self,
            WorkoutLogEntity.self,
            TaskListEntity.self,
            PlannerTaskEntity.self,
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
        ])
        // v6: News daily digest (RSS + optional AI briefs).
        let config = ModelConfiguration("musclemeal-v6", isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A failed lightweight migration can leave the SQLite store unusable.
            // Remove it once and recreate so the app can launch (simulator/dev recovery).
            Self.removeStoreFiles(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static func removeStoreFiles(at url: URL) {
        let fm = FileManager.default
        for candidate in [url, URL(fileURLWithPath: url.path + "-shm"), URL(fileURLWithPath: url.path + "-wal")] {
            try? fm.removeItem(at: candidate)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .tint(Theme.accent)
                .onOpenURL { url in
                    CadenceAutomation.handle(url, appModel: appModel)
                }
                .task {
                    await Task.yield()
                    let context = sharedModelContainer.mainContext
                    PlannerStore.seedIfNeeded(in: context)
                    Pantry.seedIfNeeded(in: context)
                    SpendStore.seedDemoIfNeeded(in: context)
                    HealthStore.ensureDemoSnapshot(in: context)
                    NewsStore.seedDemoIfNeeded(in: context)
                    WidgetSnapshotWriter.applyPendingToggles(in: context)
                    appModel.refreshGroceryFromSavedPlanIfNeeded(modelContext: context)
                    WidgetSnapshotWriter.publishImmediately(in: context)
                    Task.detached(priority: .utility) {
                        RecipeDatabase.shared.warmCache()
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await PlannerSyncCoordinator.shared.refreshAll(in: context)
                        WidgetSnapshotWriter.publishImmediately(in: context)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
