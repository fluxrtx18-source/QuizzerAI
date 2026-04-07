import Testing
@testable import QuizzerAI

// MARK: - Free-Tier Boundary Tests
//
// Tests the free-card gating logic in StoreManager:
// - canCreateCard boundary at 0, 19, 20
// - consumeFreeCard increments and caps at limit
// - Pro users bypass the gate
// - freeCardsRemaining is computed correctly
//
// NOTE: These tests create a StoreManager which starts StoreKit listeners.
// The listeners fail silently in a test environment (no StoreKit config) —
// that's fine; we're only testing the free-tier counter, not StoreKit.

@Suite("Free Tier", .serialized)
@MainActor
struct FreeTierTests {

    // MARK: - Fresh state

    @Test("Fresh StoreManager starts with canCreateCard == true")
    func freshStoreCanCreate() {
        // Clean Keychain state for this test
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(0, forKey: testKey)
        UserDefaults.standard.set(0, forKey: testKey)

        let store = StoreManager()
        #expect(store.canCreateCard == true)
        #expect(store.freeCardsRemaining == StoreManager.freeCardLimit)
        #expect(store.freeCardsUsed == 0)
    }

    // MARK: - Consumption

    @Test("consumeFreeCard increments freeCardsUsed by 1")
    func consumeIncrements() {
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(0, forKey: testKey)
        UserDefaults.standard.set(0, forKey: testKey)

        let store = StoreManager()
        let before = store.freeCardsUsed
        store.consumeFreeCard()
        #expect(store.freeCardsUsed == before + 1)
    }

    @Test("consumeFreeCard caps at freeCardLimit (no overflow)")
    func consumeCapsAtLimit() {
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(StoreManager.freeCardLimit, forKey: testKey)
        UserDefaults.standard.set(StoreManager.freeCardLimit, forKey: testKey)

        let store = StoreManager()
        store.consumeFreeCard()
        #expect(store.freeCardsUsed == StoreManager.freeCardLimit)
    }

    // MARK: - Boundary: last free card (19 used)

    @Test("canCreateCard is true with 19 cards used (1 remaining)")
    func lastFreeCard() {
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(19, forKey: testKey)
        UserDefaults.standard.set(19, forKey: testKey)

        let store = StoreManager()
        #expect(store.canCreateCard == true)
        #expect(store.freeCardsRemaining == 1)
    }

    // MARK: - Boundary: exhausted (20 used)

    @Test("canCreateCard is false with 20 cards used (0 remaining)")
    func exhaustedFreeCards() {
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(20, forKey: testKey)
        UserDefaults.standard.set(20, forKey: testKey)

        let store = StoreManager()
        #expect(store.canCreateCard == false)
        #expect(store.freeCardsRemaining == 0)
    }

    // MARK: - freeCardsRemaining computed property

    @Test("freeCardsRemaining matches limit minus used", arguments: [0, 5, 10, 15, 19, 20])
    func remainingMatchesFormula(used: Int) {
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(used, forKey: testKey)
        UserDefaults.standard.set(used, forKey: testKey)

        let store = StoreManager()
        let expected = max(0, StoreManager.freeCardLimit - used)
        #expect(store.freeCardsRemaining == expected)
    }

    // MARK: - Keychain persistence round-trip

    @Test("consumeFreeCard persists to Keychain")
    func persistsToKeychain() {
        let testKey = UserDefaultsKeys.freeCardsUsed
        KeychainHelper.setInt(0, forKey: testKey)
        UserDefaults.standard.set(0, forKey: testKey)

        let store = StoreManager()
        store.consumeFreeCard()
        store.consumeFreeCard()
        store.consumeFreeCard()

        // Read directly from Keychain to verify persistence
        let persisted = KeychainHelper.getInt(forKey: testKey)
        #expect(persisted == 3)
    }

    // MARK: - Keychain → UserDefaults migration

    @Test("Init migrates legacy UserDefaults value to Keychain")
    func migratesFromUserDefaults() {
        let testKey = UserDefaultsKeys.freeCardsUsed
        // Simulate legacy state: value in UserDefaults, nothing in Keychain
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: testKey
        ]
        SecItemDelete(legacyQuery as CFDictionary)
        UserDefaults.standard.set(7, forKey: testKey)

        let store = StoreManager()
        #expect(store.freeCardsUsed == 7)

        // Verify it was migrated to Keychain
        let keychainValue = KeychainHelper.getInt(forKey: testKey)
        #expect(keychainValue == 7)
    }
}

import Security
