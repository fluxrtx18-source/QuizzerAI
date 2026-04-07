import SwiftUI
import VisionKit
import SwiftData
import os

/// Wraps VNDocumentCameraViewController for use in SwiftUI.
///
/// **Normal mode** (`replacementCard == nil`):
///   Inserts one new `Flashcard` per scanned page into `deck`.
///
/// **Replacement mode** (`replacementCard != nil`):
///   Updates the existing card's `rawPhotoData` with the *first* scanned page,
///   resets its state to `.pending` (so AI re-processes it), and clears any
///   previously extracted Q&A. No new cards are inserted.
struct DocumentScannerView: UIViewControllerRepresentable {
    let deck: Deck
    /// When set, replaces this card's photo instead of creating new cards.
    var replacementCard: Flashcard? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager

    // Called back with the count of pages saved (1 in replacement mode).
    var onComplete: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            deck: deck,
            replacementCard: replacementCard,
            modelContext: modelContext,
            dismiss: dismiss,
            store: store,
            onComplete: onComplete
        )
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    // MARK: - Coordinator

    // VNDocumentCameraViewControllerDelegate callbacks are always delivered on the main
    // thread, so @MainActor is correct. @preconcurrency suppresses the conformance
    // isolation diagnostic — the ObjC protocol predates Swift concurrency.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let deck: Deck
        private let replacementCard: Flashcard?
        private let modelContext: ModelContext
        private let dismiss: DismissAction
        private let store: StoreManager
        private let onComplete: ((Int) -> Void)?

        init(
            deck: Deck,
            replacementCard: Flashcard?,
            modelContext: ModelContext,
            dismiss: DismissAction,
            store: StoreManager,
            onComplete: ((Int) -> Void)?
        ) {
            self.deck = deck
            self.replacementCard = replacementCard
            self.modelContext = modelContext
            self.dismiss = dismiss
            self.store = store
            self.onComplete = onComplete
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            if let target = replacementCard {
                // ── Replacement mode ─────────────────────────────────────────
                // Take only the first page and overwrite the existing card.
                guard
                    scan.pageCount > 0,
                    let data = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.8)
                else {
                    dismiss()
                    return
                }
                target.rawPhotoData = data
                // Reset AI-extracted fields so the engine re-processes from scratch.
                target.question    = nil
                target.answer      = nil
                target.explanation = nil
                target.difficulty  = nil
                target.state       = .pending

                do {
                    try modelContext.save()
                    onComplete?(1)
                } catch {
                    AppLog.camera.warning("DocumentScanner rescan save failed: \(error.localizedDescription, privacy: .public)")
                    onComplete?(0)
                }
            } else {
                // ── Normal mode ───────────────────────────────────────────────
                // Insert one new Flashcard per scanned page, respecting the free-tier limit.
                //
                // A local shadow counter (`freeCardsQueued`) tracks how many free cards
                // this batch intends to consume. The loop checks the store's published
                // remaining count minus this local offset so that a user with 1 free
                // card left can't scan 20 pages. Actual Keychain writes are deferred
                // until AFTER `modelContext.save()` succeeds — matching the safe
                // pattern in ScanHomeView's gallery-import path.
                var saved = 0
                var freeCardsQueued = 0
                for pageIndex in 0 ..< scan.pageCount {
                    let canCreate = store.isPro || (store.freeCardsRemaining - freeCardsQueued) > 0
                    guard canCreate else { break }

                    let image = scan.imageOfPage(at: pageIndex)
                    guard let data = image.jpegData(compressionQuality: 0.8) else { continue }

                    let card = Flashcard(rawPhotoData: data)
                    card.deck = deck
                    deck.flashcards.append(card)
                    modelContext.insert(card)
                    if !store.isPro { freeCardsQueued += 1 }
                    saved += 1
                }

                do {
                    try modelContext.save()
                    // Consume free cards AFTER successful save so the Keychain
                    // counter stays in sync with persisted cards. If save fails,
                    // no free cards are wasted.
                    for _ in 0 ..< freeCardsQueued { store.consumeFreeCard() }
                    onComplete?(saved)
                } catch {
                    AppLog.camera.warning("DocumentScanner save failed: \(error.localizedDescription, privacy: .public)")
                    onComplete?(0)
                }
            }

            dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            AppLog.camera.warning("DocumentScanner error: \(error.localizedDescription, privacy: .public)")
            onComplete?(0)
            dismiss()
        }
    }
}
