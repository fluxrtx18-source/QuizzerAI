import Testing
@testable import QuizzerAI

@Suite("Deck")
struct DeckTests {

    // MARK: - Initialisation

    @Test("Title is stored correctly")
    func titleStored() {
        let deck = Deck(title: "Biology")
        #expect(deck.title == "Biology")
    }

    @Test("lastStudiedAt is nil by default")
    func lastStudiedAtNilByDefault() {
        let deck = Deck(title: "Test")
        #expect(deck.lastStudiedAt == nil)
    }

    @Test("flashcards is empty by default")
    func flashcardsEmptyByDefault() {
        let deck = Deck(title: "Test")
        #expect(deck.flashcards.isEmpty)
    }

    // MARK: - pendingFlashcards

    @Test("pendingFlashcards returns only pending cards")
    func pendingFlashcardsFilter() {
        let deck = Deck(title: "Test")
        let pending = Flashcard(); pending.state = .pending
        let active  = Flashcard(); active.state  = .active
        let failed  = Flashcard(); failed.state  = .failed
        deck.flashcards = [pending, active, failed]

        #expect(deck.pendingFlashcards.count == 1)
        #expect(deck.pendingFlashcards.first?.state == .pending)
    }

    @Test("pendingFlashcards is empty when all cards are active")
    func pendingFlashcardsEmptyWhenAllActive() {
        let deck = Deck(title: "Test")
        let a = Flashcard(); a.state = .active
        let b = Flashcard(); b.state = .active
        deck.flashcards = [a, b]
        #expect(deck.pendingFlashcards.isEmpty)
    }

    // MARK: - activeFlashcards

    @Test("activeFlashcards returns only active cards")
    func activeFlashcardsFilter() {
        let deck = Deck(title: "Test")
        let pending = Flashcard(); pending.state = .pending
        let active  = Flashcard(); active.state  = .active
        deck.flashcards = [pending, active]

        #expect(deck.activeFlashcards.count == 1)
        #expect(deck.activeFlashcards.first?.state == .active)
    }

    // MARK: - progressFraction

    @Test("progressFraction is 0 when no flashcards")
    func progressFractionEmptyDeck() {
        let deck = Deck(title: "Test")
        #expect(deck.progressFraction == 0.0)
    }

    @Test("progressFraction is 1.0 when all cards active")
    func progressFractionAllActive() {
        let deck = Deck(title: "Test")
        let a = Flashcard(); a.state = .active
        let b = Flashcard(); b.state = .active
        deck.flashcards = [a, b]
        #expect(deck.progressFraction == 1.0)
    }

    @Test("progressFraction is 0.5 for half active")
    func progressFractionHalf() {
        let deck = Deck(title: "Test")
        let active  = Flashcard(); active.state  = .active
        let pending = Flashcard(); pending.state = .pending
        deck.flashcards = [active, pending]
        #expect(deck.progressFraction == 0.5)
    }

    @Test("progressFraction is 0 when all cards pending")
    func progressFractionAllPending() {
        let deck = Deck(title: "Test")
        let a = Flashcard(); a.state = .pending
        let b = Flashcard(); b.state = .pending
        deck.flashcards = [a, b]
        #expect(deck.progressFraction == 0.0)
    }
}

// MARK: - StoreError tests (appended here as they are small)

@Suite("StoreError")
struct StoreErrorTests {

    @Test("productNotFound provides a localizedDescription")
    func productNotFoundHasDescription() {
        let error: StoreError = .productNotFound
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test("verificationFailed wraps underlying error description")
    func verificationFailedWrapsDescription() {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "underlying issue" }
        }
        let error: StoreError = .verificationFailed(SampleError())
        let desc = error.errorDescription ?? ""
        #expect(!desc.isEmpty)
    }
}
