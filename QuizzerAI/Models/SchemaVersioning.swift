import SwiftData
import Foundation

// MARK: - Schema V1 (initial release)
//
// Captures the exact model shape shipped in v1.0 so SwiftData can diff schemas
// when a future V2 is added.
//
// ⚠️ IMPORTANT: These nested @Model classes are FROZEN SNAPSHOTS of the v1.0
// models. They must NEVER be modified once a V2 schema exists — SwiftData uses
// them as the "before" image in its diff. If you need to change a model, create
// SchemaV2 with the updated shape and add a MigrationStage to the plan.
//
// The live model types (StudyClass, Deck, Flashcard) are used by the rest of
// the app and evolve freely — only the versioned snapshots are frozen.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [V1StudyClass.self, V1Deck.self, V1Flashcard.self]
    }

    // ── Frozen model: StudyClass ──────────────────────────────────────
    @Model
    final class V1StudyClass {
        @Attribute(.unique) var id: UUID
        var name: String
        var subject: String
        var colorHex: String
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \V1Deck.studyClass)
        var decks: [V1Deck] = []

        init(name: String, subject: String = "", colorHex: String = "#8552F2") {
            self.id = UUID()
            self.name = name
            self.subject = subject
            self.colorHex = colorHex
            self.createdAt = Date()
        }
    }

    // ── Frozen model: Deck ────────────────────────────────────────────
    @Model
    final class V1Deck {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var lastStudiedAt: Date?

        var studyClass: V1StudyClass?

        @Relationship(deleteRule: .cascade, inverse: \V1Flashcard.deck)
        var flashcards: [V1Flashcard] = []

        init(title: String) {
            self.id = UUID()
            self.title = title
            self.createdAt = Date()
        }
    }

    // ── Frozen model: Flashcard ───────────────────────────────────────
    @Model
    final class V1Flashcard {
        @Attribute(.unique) var id: UUID
        var capturedAt: Date
        var stateRawValue: String

        @Attribute(.externalStorage) var rawPhotoData: Data?
        var thumbnailData: Data?

        var question: String?
        var answer: String?
        var explanation: String?
        var difficulty: Int?

        var reviewCount: Int
        var correctCount: Int
        var lastReviewedAt: Date?

        var deck: V1Deck?

        init(rawPhotoData: Data? = nil) {
            self.id = UUID()
            self.capturedAt = Date()
            self.stateRawValue = "pending"
            self.rawPhotoData = rawPhotoData
            self.reviewCount = 0
            self.correctCount = 0
        }
    }
}

// MARK: - Schema V2 (tags on Flashcard)
//
// Adds `tags: [String]` to Flashcard. All other models are unchanged but must
// still be present so SwiftData can build a complete schema graph for the diff.
//
// ⚠️ FROZEN: Once a V3 exists, never modify these V2 snapshots.

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [V2StudyClass.self, V2Deck.self, V2Flashcard.self]
    }

    // ── Frozen model: StudyClass (unchanged from V1) ─────────────────
    @Model
    final class V2StudyClass {
        @Attribute(.unique) var id: UUID
        var name: String
        var subject: String
        var colorHex: String
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \V2Deck.studyClass)
        var decks: [V2Deck] = []

        init(name: String, subject: String = "", colorHex: String = "#8552F2") {
            self.id = UUID()
            self.name = name
            self.subject = subject
            self.colorHex = colorHex
            self.createdAt = Date()
        }
    }

    // ── Frozen model: Deck (unchanged from V1) ───────────────────────
    @Model
    final class V2Deck {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var lastStudiedAt: Date?

        var studyClass: V2StudyClass?

        @Relationship(deleteRule: .cascade, inverse: \V2Flashcard.deck)
        var flashcards: [V2Flashcard] = []

        init(title: String) {
            self.id = UUID()
            self.title = title
            self.createdAt = Date()
        }
    }

    // ── Frozen model: Flashcard (V2 — added `tags`) ──────────────────
    @Model
    final class V2Flashcard {
        @Attribute(.unique) var id: UUID
        var capturedAt: Date
        var stateRawValue: String

        @Attribute(.externalStorage) var rawPhotoData: Data?
        var thumbnailData: Data?

        var question: String?
        var answer: String?
        var explanation: String?
        var difficulty: Int?

        var reviewCount: Int
        var correctCount: Int
        var lastReviewedAt: Date?

        // ✨ NEW in V2: user-assigned tags for filtering and organisation.
        // Stored as a Transformable array — SwiftData serialises [String]
        // automatically via NSSecureCoding.
        var tags: [String] = []

        var deck: V2Deck?

        init(rawPhotoData: Data? = nil) {
            self.id = UUID()
            self.capturedAt = Date()
            self.stateRawValue = "pending"
            self.rawPhotoData = rawPhotoData
            self.reviewCount = 0
            self.correctCount = 0
        }
    }
}

// MARK: - Migration Plan

enum QuizzerAIMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // V1 → V2: Adds `tags: [String] = []` to Flashcard.
    // This is a pure additive change (new column with a default) so
    // lightweight migration handles it automatically — no custom code needed.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
