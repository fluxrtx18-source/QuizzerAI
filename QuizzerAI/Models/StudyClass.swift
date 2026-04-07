import Foundation
import SwiftData

@Model
final class StudyClass {
    @Attribute(.unique) var id: UUID
    var name: String
    var subject: String
    var colorHex: String     // stored as "#RRGGBB" for theming
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Deck.studyClass)
    var decks: [Deck] = []

    init(name: String, subject: String = "", colorHex: String = "#8552F2") {
        self.id = UUID()
        self.name = name
        self.subject = subject
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    /// Sum of pending counts across all decks — avoids materialising a flat array.
    var pendingCount: Int {
        decks.reduce(0) { $0 + $1.pendingCount }
    }

    var totalCount: Int {
        decks.reduce(0) { $0 + $1.flashcards.count }
    }
}
