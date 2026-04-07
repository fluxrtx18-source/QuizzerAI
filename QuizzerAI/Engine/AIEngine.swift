import Foundation
import FoundationModels
import Vision
import UIKit
import SwiftData
import os

/// Drives all on-device AI extraction. Stateless — one shared instance is fine.
@MainActor
final class AIEngine: ObservableObject {

    static let shared = AIEngine()
    private init() {}

    // MARK: - Master Prompt

    private let systemPrompt = """
    You are a precise academic flashcard extractor. You receive the raw OCR text of a \
    textbook page, lecture slide, or handwritten note.

    Your job:
    1. Identify the SINGLE most important concept, definition, formula, or fact on the page.
    2. Write a clear, testable question about it.
    3. Write the direct, accurate answer.
    4. Rate difficulty 1–5 (1 = recall one word, 5 = synthesise multiple concepts).
    5. Write a brief memory hook or elaboration (or leave blank).

    Rules:
    - DO NOT invent information not present in the text.
    - DO NOT ask vague questions like "What does this page discuss?"
    - Questions must be answerable without seeing the original text again.
    - Prefer concrete facts, equations, and definitions over summaries.
    """

    // MARK: - Process One Card

    /// Pipeline: Vision OCR → text string → LanguageModelSession → structured output.
    /// - Parameter store: When provided, the free-tier gate is checked before processing.
    ///   Free-card consumption is handled by callers at insertion time.
    func process(card: Flashcard, in modelContext: ModelContext, store: StoreManager? = nil) async {
        // Free-tier gate: if the user isn't Pro and has exhausted their 20 free cards,
        // mark the card as failed with a user-visible explanation instead of processing.
        if let store, !store.canCreateCard {
            card.state = .failed
            card.explanation = "You've used all 20 free flashcards. Upgrade to Pro for unlimited scans."
            do { try modelContext.save() } catch { AppLog.ai.warning("Free-tier gate save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        guard
            let imageData = card.rawPhotoData,
            let uiImage = UIImage(data: imageData),
            let cgImage = uiImage.cgImage
        else {
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("Image guard save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        // Step 1 — OCR the image with Vision (fully offline, Neural Engine)
        let extractedText: String
        do {
            extractedText = try await ocrText(from: cgImage)
        } catch {
            AppLog.ai.warning("OCR failed for card \(card.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("OCR failure save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        guard !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppLog.ai.warning("OCR returned empty text for card \(card.id.uuidString, privacy: .public)")
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("Empty text save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        // Step 2 — Check on-device model availability
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            AppLog.ai.warning("On-device model not available: \(String(describing: model.availability), privacy: .public)")
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("Model unavailable save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        // Step 3 — Generate structured flashcard from extracted text
        let session = LanguageModelSession(instructions: systemPrompt)

        do {
            let response = try await session.respond(
                to: "Extract a flashcard from the following text:\n\n\(extractedText)",
                generating: ExtractedFlashcard.self
            )

            let result = response.content
            card.question = result.question
            card.answer = result.answer
            card.difficulty = min(max(result.difficulty, 1), 5)
            card.explanation = result.explanation.isEmpty ? nil : result.explanation
            card.state = .active
            // Store a 200 pt thumbnail before clearing the full-resolution scan.
            // This keeps per-card storage at ~10–30 KB instead of ~5–15 MB
            // while still showing a preview in card lists and the swipe queue.
            card.thumbnailData = uiImage.scaledDown(toWidth: 200)
                .jpegData(compressionQuality: 0.72)
            // Release the raw JPEG — thumbnail is sufficient for all UI needs.
            card.rawPhotoData = nil
            // Note: free card consumption is handled by callers (DocumentScannerView,
            // ScanHomeView) at insertion time — not here — to prevent double-counting.

        } catch {
            AppLog.ai.warning("AI extraction failed for card \(card.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            card.state = .failed
        }

        do { try modelContext.save() } catch { AppLog.ai.warning("Final save failed: \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Vision OCR (private)

    /// Runs VNRecognizeTextRequest on a CGImage and returns all recognised lines joined by newlines.
    ///
    /// `VNImageRequestHandler.perform()` is a synchronous, blocking call that drives the
    /// Neural Engine for 2–5 seconds on large images. Running it directly from an `async`
    /// context would occupy one of the limited cooperative threads in Swift's concurrency
    /// pool, starving other tasks during batch processing. Dispatching to a dedicated
    /// `DispatchQueue` keeps the cooperative pool free.
    private nonisolated func ocrText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                do {
                    try handler.perform([request])
                    let lines = (request.results ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Batch (JIT — first N cards only)

    /// Processes up to `limit` pending cards from a deck in sequence.
    /// Creates one `LanguageModelSession` for the entire batch to amortise
    /// session-initialisation overhead — Apple recommends session reuse within
    /// a single logical operation (see LanguageModelSession docs).
    func processJIT(deck: Deck, limit: Int = 3, modelContext: ModelContext, store: StoreManager? = nil) async {
        let pending = Array(deck.pendingFlashcards.prefix(limit))
        guard !pending.isEmpty else { return }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            for card in pending { card.state = .failed }
            do { try modelContext.save() } catch { AppLog.ai.warning("JIT model-unavailable save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }
        let session = LanguageModelSession(instructions: systemPrompt)
        for card in pending {
            await process(card: card, languageModelSession: session, in: modelContext, store: store)
        }
    }

    /// Variant of `process()` that accepts a caller-provided `LanguageModelSession`,
    /// allowing multiple cards to share one session within a JIT batch.
    private func process(card: Flashcard, languageModelSession session: LanguageModelSession, in modelContext: ModelContext, store: StoreManager? = nil) async {
        // Free-tier gate
        if let store, !store.canCreateCard {
            card.state = .failed
            card.explanation = "You've used all 20 free flashcards. Upgrade to Pro for unlimited scans."
            do { try modelContext.save() } catch { AppLog.ai.warning("JIT free-tier gate save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        guard
            let imageData = card.rawPhotoData,
            let uiImage = UIImage(data: imageData),
            let cgImage = uiImage.cgImage
        else {
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("JIT image-guard save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        let extractedText: String
        do {
            extractedText = try await ocrText(from: cgImage)
        } catch {
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("JIT OCR-error save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        guard !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            card.state = .failed
            do { try modelContext.save() } catch { AppLog.ai.warning("JIT empty-text save failed: \(error.localizedDescription, privacy: .public)") }
            return
        }

        do {
            let response = try await session.respond(
                to: "Extract a flashcard from the following text:\n\n\(extractedText)",
                generating: ExtractedFlashcard.self
            )
            let result = response.content
            card.question = result.question
            card.answer = result.answer
            card.difficulty = min(max(result.difficulty, 1), 5)
            card.explanation = result.explanation.isEmpty ? nil : result.explanation
            card.state = .active
            card.thumbnailData = uiImage.scaledDown(toWidth: 200).jpegData(compressionQuality: 0.72)
            card.rawPhotoData = nil
            // Free card consumption handled by callers at insertion time.
        } catch {
            card.state = .failed
        }

        do { try modelContext.save() } catch { AppLog.ai.warning("JIT final save failed: \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Full background batch

    /// Processes ALL pending cards in a deck with a throttle between calls.
    /// Call this from a BGProcessingTask, not from the UI.
    func processAll(deck: Deck, modelContext: ModelContext) async {
        for card in deck.pendingFlashcards {
            await process(card: card, in: modelContext)
            // 1-second breath between calls — prevents thermal throttling
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
