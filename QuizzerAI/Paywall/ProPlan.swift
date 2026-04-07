import Foundation

// MARK: - Pro Plan Model

enum ProPlan: String, CaseIterable, Identifiable {
    case yearly
    case weekly

    var id: String { rawValue }

    // MARK: Display

    var title: String {
        switch self {
        case .yearly: "Unlimited Yearly"
        case .weekly: "Unlimited Weekly"
        }
    }

    var fallbackSubtitle: String {
        switch self {
        case .yearly: "$49.99/year"
        case .weekly: "Billed each week"
        }
    }

    var pricePerWeek: String {
        switch self {
        case .yearly: "$0.96/week"
        case .weekly: "$4.99/week"
        }
    }

    /// App Store Connect product identifier — must match exactly.
    var productID: String {
        switch self {
        case .yearly:  "com.quizzerai.pro.yearly"
        case .weekly:  "com.quizzerai.pro.weekly"
        }
    }

    /// Hardcoded savings badge shown before StoreKit products finish loading.
    /// Once products load, `StoreManager.savingsBadge(for:)` takes over with
    /// a value computed from live `Product.price` — accurate for all regions.
    var fallbackSavingsBadge: String? {
        switch self {
        case .yearly: "SAVE 81%"
        case .weekly: nil
        }
    }

    // MARK: StoreKit fallbacks

    /// Hardcoded full price shown before StoreKit products finish loading.
    /// Once products load, `StoreManager.displayPrice(for:)` takes over.
    var fallbackPrice: String {
        switch self {
        case .yearly: "$49.99/year"
        case .weekly: "$4.99/week"
        }
    }

    /// Hardcoded per-week equivalent shown before StoreKit products finish loading.
    var fallbackPricePerWeek: String {
        switch self {
        case .yearly: "$0.96/week"
        case .weekly: "$4.99/week"
        }
    }

    // MARK: Raw values (used by tests + savings calculation)

    /// Actual cost charged per billing cycle.
    var billingCost: Double {
        switch self {
        case .yearly: 49.99
        case .weekly: 4.99
        }
    }

    /// Equivalent weekly cost for comparison.
    var weeklyEquivalent: Double {
        switch self {
        case .yearly: billingCost / 52.0
        case .weekly: billingCost
        }
    }

    /// Savings vs. weekly plan, expressed as 0…1.
    static func savingsFraction(vs baseline: ProPlan = .weekly) -> Double {
        let weeklyAnnual = baseline.weeklyEquivalent * 52
        let yearlyAnnual = ProPlan.yearly.billingCost
        guard weeklyAnnual > 0 else { return 0 }
        return (weeklyAnnual - yearlyAnnual) / weeklyAnnual
    }
}
