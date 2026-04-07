import StoreKit
import Foundation
import os

/// Centralises all StoreKit 2 logic: product loading, entitlement checking,
/// the long-lived `Transaction.updates` listener, and purchase execution.
///
/// Usage:
///   - Create one instance in `QuizzerAIApp` with `@StateObject`
///   - Inject into SwiftUI environment via `.environmentObject(storeManager)`
///   - Read in child views via `@EnvironmentObject var store: StoreManager`
@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Published State

    /// `true` when the user has a verified, non-expired, non-revoked Pro subscription.
    @Published private(set) var isPro = false

    /// The currently active plan (yearly or weekly), or `nil` when not subscribed.
    @Published private(set) var activePlan: ProPlan?

    /// When the current subscription expires (or renews). `nil` when not subscribed.
    @Published private(set) var expirationDate: Date?

    /// Loaded StoreKit `Product` objects keyed by plan.
    /// Empty until the first `loadProducts()` completes.
    @Published private(set) var products: [ProPlan: Product] = [:]

    // MARK: - Free Trial

    /// Maximum number of flashcards a non-Pro user can generate for free.
    static let freeCardLimit = 20

    /// How many of the 20 free cards the user has consumed so far.
    @Published private(set) var freeCardsUsed: Int

    /// Cards remaining before the user hits the paywall.
    var freeCardsRemaining: Int { max(0, Self.freeCardLimit - freeCardsUsed) }

    /// `true` when the user may generate another flashcard (is Pro, or has free cards left).
    /// Call this before invoking the AI engine. If `false`, present `PaywallView`.
    var canCreateCard: Bool { isPro || freeCardsUsed < Self.freeCardLimit }

    /// Call once per flashcard successfully generated while the user is not Pro.
    /// Has no effect if the user is already subscribed.
    /// Called from `AIEngine.process(card:in:store:)` after successful extraction.
    func consumeFreeCard() {
        guard !isPro else { return }
        freeCardsUsed = min(freeCardsUsed + 1, Self.freeCardLimit)
        KeychainHelper.setInt(freeCardsUsed, forKey: UserDefaultsKeys.freeCardsUsed)
    }

    // MARK: - Private

    /// Retains the long-lived task draining `Transaction.updates`.
    /// Cancelled in `deinit` — must outlive every purchase session.
    private var updatesTask: Task<Void, Never>?

    // MARK: - Init / Deinit

    init() {
        // Read from Keychain (tamper-resistant). Falls back to UserDefaults for
        // users upgrading from a prior version that stored in UserDefaults, then
        // migrates the value to Keychain on first access.
        if let keychainValue = KeychainHelper.getInt(forKey: UserDefaultsKeys.freeCardsUsed) {
            self.freeCardsUsed = keychainValue
        } else {
            let legacyValue = UserDefaults.standard.integer(forKey: UserDefaultsKeys.freeCardsUsed)
            self.freeCardsUsed = legacyValue
            if legacyValue > 0 {
                KeychainHelper.setInt(legacyValue, forKey: UserDefaultsKeys.freeCardsUsed)
            }
        }
        // Start the update listener *before* anything else so no transaction
        // event is missed between app launch and product fetch.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                // Always finish a transaction — verified or not — to prevent
                // StoreKit from replaying it on future launches. Crucially, this
                // happens BEFORE the `self` check: if StoreManager is deallocated
                // mid-lifecycle, unfinished transactions would accumulate in
                // StoreKit's replay queue and re-deliver on every launch.
                switch result {
                case .verified(let tx):
                    await tx.finish()
                case .unverified(let tx, let error):
                    AppLog.store.warning("Unverified transaction in updates: \(error.localizedDescription, privacy: .public)")
                    await tx.finish()
                }
                // Only refresh entitlements if StoreManager is still alive.
                // If deallocated, break out — no point draining further events.
                guard let self else { break }
                await self.refreshEntitlements()
            }
        }

        Task { @MainActor in
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Product Loading

    /// Fetches all `ProPlan` products from App Store Connect.
    /// Products are cached in `self.products` and used for display and purchasing.
    func loadProducts() async {
        let ids = Set(ProPlan.allCases.map(\.productID))
        do {
            let fetched = try await Product.products(for: ids)
            for product in fetched {
                if let plan = ProPlan.allCases.first(where: { $0.productID == product.id }) {
                    products[plan] = product
                }
            }
        } catch {
            AppLog.store.warning("loadProducts failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Entitlement Check

    /// Re-evaluates all current entitlements and updates `isPro`.
    ///
    /// `Transaction.currentEntitlements` only yields verified, non-expired,
    /// non-revoked transactions — so any verified entry means the plan is active.
    /// Call on app launch and after any transaction event.
    ///
    /// ⚠️ Do NOT call `tx.finish()` here — `currentEntitlements` yields the same
    /// transactions repeatedly (they are not consumed by iteration). Finishing them
    /// here would remove active subscriptions from StoreKit's entitlement cache.
    /// Finish only in the `updates` listener and in `purchase()`.
    func refreshEntitlements() async {
        var hasActive = false
        var detectedPlan: ProPlan?
        var detectedExpiration: Date?

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let tx):
                hasActive = true
                // Identify which plan this transaction belongs to
                if detectedPlan == nil {
                    detectedPlan = ProPlan.allCases.first { $0.productID == tx.productID }
                    detectedExpiration = tx.expirationDate
                }
            case .unverified(_, let error):
                AppLog.store.warning("Unverified entitlement: \(error.localizedDescription, privacy: .public)")
            }
        }
        isPro = hasActive
        activePlan = hasActive ? detectedPlan : nil
        expirationDate = hasActive ? detectedExpiration : nil
    }

    // MARK: - Purchase

    enum PurchaseOutcome {
        case success    // entitlement granted
        case pending    // ask-to-buy / parental approval pending
        case cancelled  // user backed out
    }

    /// Executes a StoreKit 2 purchase for the given plan.
    ///
    /// - Throws: `StoreError.productNotFound` if products haven't loaded yet,
    ///   or `StoreError.verificationFailed` if Apple's JWS signature is invalid.
    func purchase(_ plan: ProPlan) async throws -> PurchaseOutcome {
        guard let product = products[plan] else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let tx):
                await tx.finish()
                await refreshEntitlements()
                return .success
            case .unverified(let tx, let error):
                // Finish even unverified transactions to prevent StoreKit from
                // re-delivering them. Then surface the error to the UI.
                await tx.finish()
                throw StoreError.verificationFailed(error)
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    // MARK: - Restore Purchases

    /// Syncs with Apple's servers to pull transactions from other devices,
    /// then refreshes local entitlements. Call this from the "Restore Purchases" button.
    ///
    /// `AppStore.sync()` is the StoreKit 2 equivalent of
    /// `SKPaymentQueue.restoreCompletedTransactions()` — it forces a server
    /// round-trip so purchases made on another device appear locally.
    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Display Price Helpers

    /// Localised full price for `plan` (e.g. "$49.99"), with a hardcoded
    /// fallback while StoreKit products are still loading.
    func displayPrice(for plan: ProPlan) -> String {
        products[plan]?.displayPrice ?? plan.fallbackPrice
    }

    /// Per-week equivalent price string (e.g. "$0.96/week").
    /// For yearly plans this divides `product.price` by 52 using the
    /// product's own currency format style — locale-safe.
    func weeklyEquivalentPrice(for plan: ProPlan) -> String {
        guard let product = products[plan] else { return plan.fallbackPricePerWeek }
        switch plan {
        case .yearly:
            let weekly = product.price / 52
            return "\(weekly.formatted(product.priceFormatStyle))/week"
        case .weekly:
            return "\(product.displayPrice)/week"
        }
    }

    /// Subtitle text shown below the plan title in the paywall card.
    func subtitle(for plan: ProPlan) -> String {
        switch plan {
        case .yearly:
            return (products[plan]?.displayPrice ?? "$49.99") + "/year"
        case .weekly:
            return "Billed each week"
        }
    }

    /// Savings badge computed from live StoreKit prices for regional accuracy.
    /// Falls back to the hardcoded `ProPlan.fallbackSavingsBadge` while products
    /// are still loading or if the weekly product isn't available.
    ///
    /// Example: If yearly = $49.99 and weekly = $4.99, the weekly-annualised cost
    /// is $259.48, giving savings of ≈81% → "SAVE 81%".
    func savingsBadge(for plan: ProPlan) -> String? {
        guard plan == .yearly else { return nil }
        guard
            let yearlyProduct = products[.yearly],
            let weeklyProduct = products[.weekly]
        else {
            return plan.fallbackSavingsBadge
        }
        let weeklyAnnualised = weeklyProduct.price * 52
        guard weeklyAnnualised > 0 else { return plan.fallbackSavingsBadge }
        let fraction = (weeklyAnnualised - yearlyProduct.price) / weeklyAnnualised
        // Convert Decimal → Double for percentage math. Decimal's * operator
        // only accepts (Decimal, Decimal) — no mixed (Decimal, Int) overload.
        let percent = Int((Double(truncating: fraction as NSDecimalNumber) * 100).rounded())
        guard percent > 0 else { return nil }
        return "SAVE \(percent)%"
    }
}

// MARK: - Store Error

enum StoreError: LocalizedError {
    case productNotFound
    case verificationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not available. Please try again later."
        case .verificationFailed(let error):
            return "Purchase could not be verified: \(error.localizedDescription)"
        }
    }
}
