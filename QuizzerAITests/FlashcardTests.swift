import Testing
@testable import QuizzerAI

@Suite("Flashcard")
struct FlashcardTests {

    // MARK: - Default initialisation

    @Test("Default state is pending")
    func defaultStateIsPending() {
        let card = Flashcard()
        #expect(card.state == .pending)
    }

    @Test("Default rawPhotoData is nil")
    func defaultRawPhotoDataIsNil() {
        let card = Flashcard()
        #expect(card.rawPhotoData == nil)
    }

    @Test("Default stats are zero")
    func defaultStatsZero() {
        let card = Flashcard()
        #expect(card.reviewCount == 0)
        #expect(card.correctCount == 0)
    }

    @Test("Each init produces a distinct UUID")
    func uuidsAreUnique() {
        let a = Flashcard()
        let b = Flashcard()
        #expect(a.id != b.id)
    }

    // MARK: - State round-trip via stateRawValue

    @Test("State setter updates stateRawValue", arguments: ProcessingState.allCases)
    func stateSetterUpdatesRawValue(state: ProcessingState) {
        let card = Flashcard()
        card.state = state
        #expect(card.stateRawValue == state.rawValue)
    }

    @Test("State getter reads from stateRawValue")
    func stateGetterReadsRawValue() {
        let card = Flashcard()
        card.stateRawValue = ProcessingState.active.rawValue
        #expect(card.state == .active)
    }

    @Test("Corrupted stateRawValue falls back to pending")
    func corruptedRawValueFallsBackToPending() {
        let card = Flashcard()
        card.stateRawValue = "corrupted_value"
        #expect(card.state == .pending)
    }

    // MARK: - accuracyRate

    @Test("accuracyRate is 0 when reviewCount is 0")
    func accuracyRateZeroWithNoReviews() {
        let card = Flashcard()
        #expect(card.accuracyRate == 0.0)
    }

    @Test("accuracyRate is 1.0 when all answers correct")
    func accuracyRatePerfect() {
        let card = Flashcard()
        card.reviewCount = 5
        card.correctCount = 5
        #expect(card.accuracyRate == 1.0)
    }

    @Test("accuracyRate computes correctly for partial correctness")
    func accuracyRatePartial() {
        let card = Flashcard()
        card.reviewCount = 4
        card.correctCount = 3
        #expect(card.accuracyRate == 0.75)
    }

    // MARK: - rawPhotoData init

    @Test("rawPhotoData is stored from init parameter")
    func rawPhotoDataStoredFromInit() {
        let data = Data([0x01, 0x02, 0x03])
        let card = Flashcard(rawPhotoData: data)
        #expect(card.rawPhotoData == data)
    }
}
