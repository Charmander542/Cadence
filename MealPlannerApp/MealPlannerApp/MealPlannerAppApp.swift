import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        CadenceCloudStore.makeContainer()
    }()

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
                    SpendPreferences.ingestLocalSecretsIfNeeded()
                    let context = sharedModelContainer.mainContext
                    context.autosaveEnabled = true
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
                    Task { @MainActor in
                        _ = await SpendStore.restorePlaidEnrollmentsIfNeeded(in: context)
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await PlannerSyncCoordinator.shared.refreshAll(in: context)
                        WidgetSnapshotWriter.publishImmediately(in: context)
                    }
                    let iCloud = await CadenceCloudStore.refreshAccountStatus()
                    print("Cadence iCloud: \(iCloud); cloudKitStore=\(CadenceCloudStore.isCloudKitEnabled)")
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .inactive || phase == .background {
                        CadenceCloudStore.save(sharedModelContainer.mainContext, label: "scene-\(phase)")
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
