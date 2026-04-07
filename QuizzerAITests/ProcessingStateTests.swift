import Testing
@testable import QuizzerAI

@Suite("ProcessingState")
struct ProcessingStateTests {

    // MARK: Raw values

    @Test("Raw value equals case name", arguments: ProcessingState.allCases)
    func rawValueMatchesCaseName(state: ProcessingState) {
        switch state {
        case .pending: #expect(state.rawValue == "pending")
        case .active:  #expect(state.rawValue == "active")
        case .failed:  #expect(state.rawValue == "failed")
        }
    }

    // MARK: Codability

    @Test("Round-trips through JSON encoding/decoding", arguments: ProcessingState.allCases)
    func roundTripsJSON(state: ProcessingState) throws {
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ProcessingState.self, from: data)
        #expect(decoded == state)
    }

    // MARK: CaseIterable

    @Test("Has exactly three cases")
    func exactlyThreeCases() {
        #expect(ProcessingState.allCases.count == 3)
    }

    @Test("All raw values are unique")
    func rawValuesUnique() {
        let rawValues = ProcessingState.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    // MARK: Unknown raw value fallback

    @Test("Unknown raw value produces nil")
    func unknownRawValueIsNil() {
        #expect(ProcessingState(rawValue: "unknown") == nil)
        #expect(ProcessingState(rawValue: "") == nil)
    }
}
