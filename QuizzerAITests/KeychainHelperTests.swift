import Testing
@testable import QuizzerAI

// MARK: - KeychainHelper Unit Tests
//
// These test against the real Keychain using a unique prefix to avoid
// collisions with production data or other tests running in parallel.
// Each test cleans up its key after execution.

@Suite("KeychainHelper")
struct KeychainHelperTests {

    /// Unique prefix prevents collision with production keys or parallel test runs.
    private static let prefix = "test_kh_\(ProcessInfo.processInfo.globallyUniqueString.prefix(8))_"

    private func key(_ name: String) -> String { Self.prefix + name }

    /// Remove a test key from Keychain after use.
    private func cleanup(_ key: String) {
        // Write nil-equivalent by deleting the item directly
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - getInt / setInt round-trip

    @Test("setInt then getInt returns same value")
    func roundTrip() {
        let k = key("roundTrip")
        defer { cleanup(k) }

        KeychainHelper.setInt(42, forKey: k)
        let result = KeychainHelper.getInt(forKey: k)
        #expect(result == 42)
    }

    @Test("getInt returns nil for non-existent key")
    func missingKeyReturnsNil() {
        let result = KeychainHelper.getInt(forKey: key("nonExistent_\(UUID())"))
        #expect(result == nil)
    }

    @Test("setInt overwrites previous value")
    func overwrite() {
        let k = key("overwrite")
        defer { cleanup(k) }

        KeychainHelper.setInt(10, forKey: k)
        KeychainHelper.setInt(99, forKey: k)
        #expect(KeychainHelper.getInt(forKey: k) == 99)
    }

    @Test("setInt stores zero correctly")
    func storesZero() {
        let k = key("zero")
        defer { cleanup(k) }

        KeychainHelper.setInt(0, forKey: k)
        #expect(KeychainHelper.getInt(forKey: k) == 0)
    }

    @Test("setInt stores negative values via Int32 clamping")
    func storesNegative() {
        let k = key("negative")
        defer { cleanup(k) }

        KeychainHelper.setInt(-5, forKey: k)
        #expect(KeychainHelper.getInt(forKey: k) == -5)
    }

    @Test("Large values are clamped to Int32 range")
    func largeValueClamped() {
        let k = key("clamp")
        defer { cleanup(k) }

        // Int.max exceeds Int32.max — should clamp to Int32.max (2_147_483_647)
        KeychainHelper.setInt(Int(Int32.max) + 100, forKey: k)
        #expect(KeychainHelper.getInt(forKey: k) == Int(Int32.max))
    }

    // MARK: - Boundary values for free-card counter

    @Test("Stores values 0 through 20 (free-card range)", arguments: [0, 1, 10, 19, 20])
    func freeCardRangeValues(value: Int) {
        let k = key("freeRange_\(value)")
        defer { cleanup(k) }

        KeychainHelper.setInt(value, forKey: k)
        #expect(KeychainHelper.getInt(forKey: k) == value)
    }
}

// MARK: - Import Security for cleanup

import Security
