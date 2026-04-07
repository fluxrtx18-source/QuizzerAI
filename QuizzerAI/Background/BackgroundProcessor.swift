import Foundation
import BackgroundTasks
import SwiftData
import os

/// Identifier must also appear in Info.plist under BGTaskSchedulerPermittedIdentifiers
let kBGProcessingTaskID = "com.quizzerai.process-flashcards"

// BGProcessingTask is an ObjC class with no Sendable conformance.
// We own the scheduling guarantee (BGTaskScheduler calls using: nil → main queue),
// so the box is safe even though the compiler can't verify it statically.
private final class BGTaskBox: @unchecked Sendable {
    let task: BGProcessingTask
    init(_ task: BGProcessingTask) { self.task = task }
}

/// Registers and handles the BGProcessingTask that chews through pending flashcards
/// while the device is plugged in overnight.
enum BackgroundProcessor {

    // MARK: - Registration (call from App init or scene willConnect)

    static func registerTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: kBGProcessingTaskID,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            // Wrap in @unchecked Sendable box so we can safely cross into @MainActor Task.
            // BGTaskScheduler guarantees main-queue delivery when using: nil.
            let box = BGTaskBox(processingTask)
            Task { @MainActor in handleTask(box.task) }
        }
    }

    // MARK: - Schedule

    /// Call this whenever the app moves to the background.
    @MainActor
    static func scheduleIfNeeded(container: ModelContainer) {
        // Only schedule if there are pending cards worth processing
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.stateRawValue == "pending" }
        )
        let count: Int
        do {
            count = try context.fetchCount(descriptor)
        } catch {
            AppLog.background.warning("scheduleIfNeeded fetchCount failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard count > 0 else { return }

        let request = BGProcessingTaskRequest(identifier: kBGProcessingTaskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true   // only run when plugged in
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // not sooner than 1 min

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLog.background.warning("BGProcessingTask schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Handler

    /// Encapsulates the mutable state shared between the processing task and the
    /// expiration handler. `@MainActor` makes the isolation guarantee explicit —
    /// both closures hop to the main actor before reading/writing, so there is no
    /// data race. Wrapping in a class (vs. local `var` captures) prevents future
    /// regressions if Apple ever changes `expirationHandler`'s threading contract.
    @MainActor
    private final class TaskState {
        var didComplete = false
        var processingTask: Task<Void, Never>?
    }

    @MainActor
    private static func handleTask(_ task: BGProcessingTask) {
        // Re-schedule before starting so overnight processing chains automatically,
        // even when the OS expires this task mid-run.
        if let container = activeContainer {
            scheduleIfNeeded(container: container)
        }

        let box = BGTaskBox(task)
        let state = TaskState()

        task.expirationHandler = {
            // expirationHandler fires on an arbitrary OS thread — hop to main actor
            // before touching the actor-isolated TaskState.
            Task { @MainActor in
                state.processingTask?.cancel()
                guard !state.didComplete else { return }
                state.didComplete = true
                box.task.setTaskCompleted(success: false)
            }
        }

        state.processingTask = Task { @MainActor in
            await processAllPending()
            guard !state.didComplete else { return }
            state.didComplete = true
            box.task.setTaskCompleted(success: !Task.isCancelled)
        }
    }

    // MARK: - Core processing loop

    /// Processes all pending flashcards in a deck.
    /// `@MainActor` because both `Flashcard` (@Model) and `ModelContext` are main-actor-bound
    /// in SwiftData — Swift 6 strict concurrency disallows sending them across actor boundaries.
    /// The main actor is still freed cooperatively at every `await` (OCR, LLM, Task.sleep).
    @MainActor
    static func processAllPending(container: ModelContainer? = nil) async {
        // Resolve the container — direct access is safe since we're already @MainActor.
        let resolvedContainer: ModelContainer
        if let c = container {
            resolvedContainer = c
        } else if let c = activeContainer {
            resolvedContainer = c
        } else {
            return
        }
        let context = ModelContext(resolvedContainer)

        let descriptor = FetchDescriptor<Flashcard>(
            predicate: #Predicate { $0.stateRawValue == "pending" }
        )

        let pendingCards: [Flashcard]
        do {
            pendingCards = try context.fetch(descriptor)
        } catch {
            AppLog.background.warning("processAllPending fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        for card in pendingCards {
            // Check for task cancellation between each card
            if Task.isCancelled { break }

            await AIEngine.shared.process(card: card, in: context)

            // Throttle: 1s gap prevents thermal issues and respects model rate limits.
            // Task.sleep throws CancellationError when the task is cancelled, so we
            // catch and break — this is now wired to the expiration handler above.
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { break }
        }
    }

    // Set this when the ModelContainer is created in the app.
    // @MainActor because every read/write happens on the main actor:
    // writes come from QuizzerAIApp.init(), reads from processAllPending().
    @MainActor static var activeContainer: ModelContainer?
}
