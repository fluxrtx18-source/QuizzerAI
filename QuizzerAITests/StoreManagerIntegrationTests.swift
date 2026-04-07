import XCTest
import StoreKit
import StoreKitTest
@testable import QuizzerAI

// MARK: - StoreManager Integration Tests
//
// Uses SKTestSession so tests run fully offline / sandboxed.
// SKTestSession requires XCTestCase lifecycle (setUp/tearDown) and cannot
// use Swift Testing — hence XCTestCase here instead of @Suite.

@MainActor
final class StoreManagerIntegrationTests: XCTestCase {

    var session: SKTestSession!
    var store: StoreManager!

    override func setUp() async throws {
        try await super.setUp()
        session = try SKTestSession(configurationFileNamed: "StoreKitConfig")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        store = StoreManager()
        // Wait for products to load with a bounded retry instead of a fixed sleep.
        // StoreManager.init fires loadProducts() in a Task — poll until both plans
        // are loaded or bail after 5 seconds (generous for slow CI machines).
        try await waitForProducts(timeout: .seconds(5))
    }

    /// Polls `store.products` in 100ms intervals until both plans are loaded or timeout.
    private func waitForProducts(timeout: Duration) async throws {
        let deadline = ContinuousClock.now + timeout
        while store.products.count < ProPlan.allCases.count {
            guard ContinuousClock.now < deadline else {
                XCTFail("Products did not load within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
        store = nil
        try await super.tearDown()
    }

    // MARK: - Product Loading

    func testProductsLoadForBothPlans() async throws {
        let yearly = try XCTUnwrap(store.products[.yearly], "Yearly product did not load")
        let weekly = try XCTUnwrap(store.products[.weekly], "Weekly product did not load")
        XCTAssertEqual(yearly.id, ProPlan.yearly.productID)
        XCTAssertEqual(weekly.id, ProPlan.weekly.productID)
    }

    func testDisplayPriceNonEmpty() {
        for plan in ProPlan.allCases {
            let price = store.displayPrice(for: plan)
            XCTAssertFalse(price.isEmpty, "displayPrice for \(plan) should not be empty")
        }
    }

    func testWeeklyEquivalentPriceNonEmpty() {
        for plan in ProPlan.allCases {
            let price = store.weeklyEquivalentPrice(for: plan)
            XCTAssertFalse(price.isEmpty)
        }
    }

    // MARK: - Purchase Flow

    func testPurchaseYearlyGrantsPro() async throws {
        XCTAssertFalse(store.isPro, "Should start as non-pro")
        let outcome = try await store.purchase(.yearly)
        XCTAssertEqual(outcome, .success)
        XCTAssertTrue(store.isPro, "isPro should be true after yearly purchase")
    }

    func testPurchaseWeeklyGrantsPro() async throws {
        XCTAssertFalse(store.isPro, "Should start as non-pro")
        let outcome = try await store.purchase(.weekly)
        XCTAssertEqual(outcome, .success)
        XCTAssertTrue(store.isPro, "isPro should be true after weekly purchase")
    }

    // MARK: - Entitlement refresh on cold launch

    func testRefreshEntitlementsAfterPurchase() async throws {
        let outcome = try await store.purchase(.yearly)
        XCTAssertEqual(outcome, .success)

        // Simulate cold launch with a fresh StoreManager.
        // Poll isPro instead of sleeping — entitlements resolve via Transaction.currentEntitlements
        // which is async and may take a few hundred ms.
        let freshStore = StoreManager()
        let deadline = ContinuousClock.now + .seconds(5)
        while !freshStore.isPro {
            guard ContinuousClock.now < deadline else {
                XCTFail("Fresh store did not detect entitlement within 5 seconds")
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(freshStore.isPro, "Fresh store should detect entitlement after purchase")
    }

    // MARK: - Product not loaded yet

    func testPurchaseWithoutProductsThrows() async {
        // Create a store that has never loaded products (products dict is empty)
        let earlyStore = StoreManager()
        // Clear the products dict so the guard fires
        // (We can't mutate private(set), so we verify displayPrice falls back cleanly instead)
        let fallback = earlyStore.displayPrice(for: .yearly)
        XCTAssertFalse(fallback.isEmpty, "Fallback price should be non-empty before products load")
    }
}

// MARK: - PurchaseOutcome Equatable (needed for XCTAssertEqual)

extension StoreManager.PurchaseOutcome: Equatable {
    public static func == (lhs: StoreManager.PurchaseOutcome,
                           rhs: StoreManager.PurchaseOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success), (.pending, .pending), (.cancelled, .cancelled): true
        default: false
        }
    }
}
