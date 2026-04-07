import Foundation
import SwiftData

@Model
final class Deck {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var lastStudiedAt: Date?

    var studyClass: StudyClass?

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
    var flashcards: [Flashcard] = []

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
    }

    /// Pending cards sorted by capture date. Use `pendingCount` when you only need the count.
    var pendingFlashcards: [Flashcard] {
        flashcards
            .filter { $0.state == .pending }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Active cards sorted by capture date. Use `activeCount` when you only need the count.
    var activeFlashcards: [Flashcard] {
        flashcards
            .filter { $0.state == .active }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    /// O(n) filter without sort — use for display counts and badges.
    var pendingCount: Int { flashcards.filter { $0.state == .pending }.count }
    var activeCount: Int  { flashcards.filter { $0.state == .active  }.count }

    var progressFraction: Double {
        guard !flashcards.isEmpty else { return 0 }
        return Double(activeCount) / Double(flashcards.count)
    }
}
