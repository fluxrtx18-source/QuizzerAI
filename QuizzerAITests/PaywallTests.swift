import Testing
@testable import QuizzerAI

// MARK: - ProPlan Tests

@Suite("ProPlan")
struct ProPlanTests {

    // MARK: Display content

    @Test("All plans have non-empty display strings", arguments: ProPlan.allCases)
    func displayStringsNonEmpty(plan: ProPlan) {
        #expect(!plan.title.isEmpty)
        #expect(!plan.fallbackSubtitle.isEmpty)
        #expect(!plan.pricePerWeek.isEmpty)
    }

    @Test("Yearly plan has a fallback savings badge; weekly plan does not")
    func savingsBadgePresence() {
        #expect(ProPlan.yearly.fallbackSavingsBadge != nil)
        #expect(ProPlan.weekly.fallbackSavingsBadge == nil)
    }

    @Test("Fallback savings badge content contains '%'")
    func savingsBadgeFormat() throws {
        let badge = try #require(ProPlan.yearly.fallbackSavingsBadge)
        #expect(badge.contains("%"))
    }

    // MARK: Pricing logic

    @Test("All billing costs are positive", arguments: ProPlan.allCases)
    func billingCostPositive(plan: ProPlan) {
        #expect(plan.billingCost > 0)
    }

    @Test("Yearly weekly-equivalent is cheaper than weekly plan")
    func yearlyIsCheeperPerWeek() {
        #expect(ProPlan.yearly.weeklyEquivalent < ProPlan.weekly.weeklyEquivalent)
    }

    @Test("Savings fraction exceeds 50 percent vs weekly baseline")
    func savingsFractionAboveHalf() {
        let fraction = ProPlan.savingsFraction(vs: .weekly)
        #expect(fraction > 0.5)
    }

    @Test("Savings fraction is below 100 percent (sanity check)")
    func savingsFractionBelow100() {
        let fraction = ProPlan.savingsFraction(vs: .weekly)
        #expect(fraction < 1.0)
    }

    // MARK: Identifiable / CaseIterable

    @Test("Each plan ID matches its raw value", arguments: ProPlan.allCases)
    func idMatchesRawValue(plan: ProPlan) {
        #expect(plan.id == plan.rawValue)
    }

    @Test("ProPlan has exactly two cases")
    func exactlyCases() {
        #expect(ProPlan.allCases.count == 2)
    }
}
