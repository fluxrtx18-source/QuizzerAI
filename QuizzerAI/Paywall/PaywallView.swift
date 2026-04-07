import SwiftUI
import StoreKit
import os

// MARK: - Timeline Item

struct TimelineItem {
    let icon: String
    let title: String
    let body: String
}

// MARK: - Paywall View

struct PaywallView: View {
    var onDismiss: () -> Void = {}
    /// When `true` (shown as last onboarding step), hides the back button and
    /// shows a "Start free — 20 cards included" escape hatch below the CTA.
    var isOnboarding: Bool = false

    @EnvironmentObject private var store: StoreManager

    @State private var selectedPlan: ProPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: IdentifiableError? = nil
    @State private var showPendingAlert = false

    private let timeline: [TimelineItem] = [
        TimelineItem(
            icon: "lock.open.fill",
            title: "Today",
            body: "Unlock unlimited AI flashcard creation from every page you scan"
        ),
        TimelineItem(
            icon: "sparkles",
            title: "Instantly",
            body: "On-device AI processes every scan privately — no cloud, no waiting"
        ),
        TimelineItem(
            icon: "crown.fill",
            title: "Always",
            body: "Cancel anytime from your App Store subscription settings"
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                // Free trial banner — only shown when entering from onboarding
                if isOnboarding {
                    freeTrialBanner
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                headline
                    .padding(.horizontal, 24)
                    .padding(.top, isOnboarding ? 16 : 28)
                    .padding(.bottom, 36)

                timelineSection
                    .padding(.bottom, 36)

                planCards
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)

                ctaButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                footnote
                    .padding(.bottom, isOnboarding ? 8 : 40)

                // Escape hatch — lets user skip to main app with 20 free cards
                if isOnboarding {
                    freeEscapeButton
                        .padding(.bottom, 40)
                }
            }
        }
        .background(Color("CardBG").ignoresSafeArea())
        .alert(
            "Purchase Error",
            isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            ),
            presenting: purchaseError
        ) { _ in
            Button("OK", role: .cancel) { purchaseError = nil }
        } message: { error in
            Text(error.message)
        }
        .alert("Purchase Pending", isPresented: $showPendingAlert) {
            Button("OK") { onDismiss() }
        } message: {
            Text("Your purchase is waiting for approval. You'll get access as soon as it's confirmed.")
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            // Back button hidden during onboarding — user has committed to this screen
            if !isOnboarding {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Go back")
            }
            Spacer()
            if !isOnboarding {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
            }
        }
    }

    // MARK: - Free Trial Banner (onboarding only)

    private var freeTrialBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.brand)
            Text("20 free flashcards included — no credit card needed")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColor.brand)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColor.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Free Escape Button (onboarding only)

    private var freeEscapeButton: some View {
        Button(action: onDismiss) {
            Text("Start free — 20 cards, no subscription")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.textMuted)
                .underline()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Headline

    private var headline: some View {
        // AttributedString avoids the Text-concatenation '+' that was deprecated in iOS 26.
        Text(headlineAttributed)
            .font(.system(size: 32, weight: .black))
            .foregroundStyle(AppColor.textPrimary)
            .lineSpacing(3)
    }

    private var headlineAttributed: AttributedString {
        var string = AttributedString("Study smarter\nwith QuizzerAI Pro")
        if let range = string.range(of: "QuizzerAI Pro") {
            string[range].foregroundColor = AppColor.brand
        }
        return string
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        HStack(alignment: .top, spacing: 18) {
            // Purple gradient bar with icon badges
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColor.brand,
                                AppColor.brand.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 54)

                // Three icons evenly distributed in the bar
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)
                    iconBadge(timeline[0].icon, opacity: 1.0)
                    Spacer()
                    iconBadge(timeline[1].icon, opacity: 0.80)
                    Spacer()
                    iconBadge(timeline[2].icon, opacity: 0.45)
                    Spacer().frame(height: 28)
                }
                .frame(width: 54)
            }
            .frame(width: 54, height: 260)

            // Text items aligned with icon positions
            VStack(alignment: .leading, spacing: 0) {
                timelineRow(item: timeline[0])
                Spacer()
                timelineRow(item: timeline[1])
                Spacer()
                timelineRow(item: timeline[2])
            }
            .frame(height: 260)
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 20)
    }

    private func iconBadge(_ symbol: String, opacity: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.22 * opacity))
                .frame(width: 40, height: 40)
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(opacity))
        }
    }

    private func timelineRow(item: TimelineItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
            Text(item.body)
                .font(.system(size: 14))
                .foregroundStyle(AppColor.textMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 14) {
            ForEach(ProPlan.allCases) { plan in
                PlanCardView(
                    plan: plan,
                    subtitle: store.subtitle(for: plan),
                    pricePerWeek: store.weeklyEquivalentPrice(for: plan),
                    savingsBadge: store.savingsBadge(for: plan),
                    isSelected: selectedPlan == plan
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        selectedPlan = plan
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(plan.title), \(store.subtitle(for: plan)), \(store.weeklyEquivalentPrice(for: plan))")
                .accessibilityAddTraits(selectedPlan == plan ? .isSelected : [])
            }
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            ZStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.1)
                } else {
                    HStack(spacing: 8) {
                        Text("Unlock QuizzerAI Pro")
                            .font(.system(size: 17, weight: .bold))
                        Text("✨")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                AppColor.brand,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .disabled(isPurchasing)
        .scaleEffect(isPurchasing ? 0.97 : 1)
        .animation(.easeInOut(duration: 0.15), value: isPurchasing)
        .accessibilityLabel("Unlock QuizzerAI Pro")
        .accessibilityHint("Starts the purchase for the selected plan")
    }

    // MARK: - Footnote

    private var footnote: some View {
        VStack(spacing: 8) {
            Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings › Apple ID › Subscriptions.")
                .font(.system(size: 11))
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                Task { await restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.brand)
            }

            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://fluxrtx18-source.github.io/QuizzerAI/terms")!)
                Text("·")
                Link("Privacy Policy", destination: URL(string: "https://fluxrtx18-source.github.io/QuizzerAI/privacy")!)
            }
            .font(.system(size: 11))
            .foregroundStyle(AppColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Purchase

    @MainActor
    private func purchase() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let outcome = try await store.purchase(selectedPlan)
            switch outcome {
            case .success:
                onDismiss()
            case .pending:
                // Ask-to-buy or parental approval — inform the user before dismissing
                showPendingAlert = true
            case .cancelled:
                break   // user backed out — spinner already reset by defer
            }
        } catch {
            purchaseError = IdentifiableError(message: error.localizedDescription)
            AppLog.store.warning("PaywallView purchase error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Restore Purchases

    @MainActor
    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        await store.restorePurchases()
        if store.isPro {
            onDismiss()
        }
    }
}

// MARK: - Plan Card View

private struct PlanCardView: View {
    let plan: ProPlan
    let subtitle: String       // live from StoreManager (falls back to ProPlan.fallbackPrice)
    let pricePerWeek: String   // live from StoreManager
    let savingsBadge: String?  // live from StoreManager (computed from Product.price)
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // ── Card shell ─────────────────────────────────────────
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("CardBG"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected ? AppColor.brand : AppColor.separator,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                )
                .shadow(
                    color: isSelected
                        ? AppColor.brand.opacity(0.18)
                        : Color.black.opacity(0.04),
                    radius: isSelected ? 14 : 4,
                    y: isSelected ? 6 : 2
                )

            // ── Card content ───────────────────────────────────────
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textMuted)
                }
                Spacer()
                Text(pricePerWeek)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.brand)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            // Extra top padding only on yearly to make room for the overlapping badges
            .padding(.top, (savingsBadge != nil && isSelected) ? 10 : 0)
        }
        // Push the whole card down so the -16 offset badge isn't clipped
        .padding(.top, (savingsBadge != nil && isSelected) ? 16 : 0)
        .overlay(alignment: .top) {
            if let badge = savingsBadge, isSelected {
                overlappingBadges(badge: badge)
                    .offset(y: -1) // sit right on the border line
            }
        }
    }

    private func overlappingBadges(badge: String) -> some View {
        HStack(spacing: 0) {
            Spacer()

            // "SAVE 81%" pill — centered
            Text(badge)
                .font(.system(size: 11, weight: .black))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(AppColor.brand, in: Capsule())

            Spacer()

            // Purple checkmark circle — top-right corner
            Circle()
                .fill(AppColor.brand)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                )
                .padding(.trailing, 16)
        }
    }
}

// MARK: - IdentifiableError (used for alert(item:) binding)

/// Wraps an error message as an Identifiable so SwiftUI's alert(item:) API can use it.
struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
