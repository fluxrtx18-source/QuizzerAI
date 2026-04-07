import SwiftUI
import SwiftData
import BackgroundTasks
import os

@main
struct QuizzerAIApp: App {

    // MARK: - SwiftData container

    /// Single persistent container shared across the entire app.
    ///
    /// Points at `SchemaV2` — the latest schema version. On first launch after
    /// the update, SwiftData runs `QuizzerAIMigrationPlan` which applies the
    /// lightweight V1→V2 migration (adds `tags: [String]` to Flashcard).
    ///
    /// On schema migration failure (e.g. OS upgrade edge case), we fall back to an
    /// in-memory store rather than crashing. The user loses no data that was already
    /// persisted — the persistent store is still there on disk; the app just can't
    /// open it in this run. A future launch after the OS resolves the migration will
    /// succeed. `try!` on the fallback is intentional: in-memory store creation
    /// cannot fail.
    let container: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: QuizzerAIMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            AppLog.app.warning("SwiftData persistent store failed, falling back to in-memory: \(error.localizedDescription, privacy: .public)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    // MARK: - Store Manager

    /// Owns the StoreKit 2 lifecycle: product loading, entitlement checks,
    /// and the long-lived Transaction.updates listener.
    @StateObject private var storeManager = StoreManager()

    // MARK: - Init

    init() {
        BackgroundProcessor.registerTask()
        // BackgroundProcessor.activeContainer is @MainActor. App.init() is nonisolated
        // in Swift 6, so we must hop to the main actor asynchronously.
        let c = container
        Task { @MainActor in
            BackgroundProcessor.activeContainer = c
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(storeManager)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didEnterBackgroundNotification
                    )
                ) { _ in
                    BackgroundProcessor.scheduleIfNeeded(container: container)
                }
        }
    }
}
