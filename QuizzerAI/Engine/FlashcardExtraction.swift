import Foundation
import FoundationModels

/// The structured output schema the on-device model fills in.
/// Uses Foundation Models structured-output API (iOS 26+).
@Generable
struct ExtractedFlashcard {
    /// A concise, self-contained question derived from the source material.
    @Guide(description: "A clear, testable question based on the image content. No more than 25 words.")
    var question: String

    /// The correct answer to the question.
    @Guide(description: "The direct answer. Factual, concise, 1-3 sentences maximum.")
    var answer: String

    /// Difficulty on a 1–5 scale. 1 = recall of a single fact; 5 = synthesis across concepts.
    @Guide(description: "Integer difficulty score: 1 (trivial recall) to 5 (deep synthesis). Must be 1, 2, 3, 4, or 5.")
    var difficulty: Int

    /// Extra context to show after the student reveals the answer.
    @Guide(description: "Optional 1-sentence elaboration or memory hook. Leave empty string if nothing useful to add.")
    var explanation: String
}
