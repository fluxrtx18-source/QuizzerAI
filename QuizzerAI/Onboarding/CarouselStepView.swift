import SwiftUI

/// Screen 2 — small avatar mascot + speech bubble header, auto-advancing feature carousel.
struct CarouselStepView: View {
    var namespace: Namespace.ID
    var onContinue: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false
    @State private var userSwiped = false

    private let cards = FeatureCard.all
    private let autoAdvanceInterval: Duration = .seconds(3.5)

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header: avatar + speech bubble ──────────────────
                mascotHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -12)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                Spacer().frame(height: 32)

                // ── Feature carousel ──────────────────────────────
                TabView(selection: $currentPage) {
                    ForEach(cards.indices, id: \.self) { i in
                        FeatureCardView(card: cards[i])
                            .tag(i)
                            .padding(.horizontal, 28)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
                .onChange(of: currentPage) { _, _ in
                    // Pause auto-advance once the user manually swipes
                    userSwiped = true
                }

                // Page dots
                HStack(spacing: 8) {
                    ForEach(cards.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? AppColor.brand : AppColor.separator)
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 16)

                Spacer()

                // CTA
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColor.brand, in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.3), value: appeared)
            }
        }
        .task {
            // Set appeared immediately to trigger entrance animations.
            appeared = true
            // Auto-advance loop — .task cancels automatically when the view disappears,
            // eliminating the Timer leak that the old onAppear/onDisappear pattern had.
            while !Task.isCancelled {
                try? await Task.sleep(for: autoAdvanceInterval)
                guard !Task.isCancelled, !userSwiped else { break }
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentPage = (currentPage + 1) % cards.count
                }
            }
        }
    }

    // MARK: - Mascot header

    private var mascotHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            // Small mascot avatar (matched geometry from welcome)
            MascotView(size: 52, isAvatar: true)
                .matchedGeometryEffect(id: "mascot", in: namespace)

            // Speech bubble
            Text("Take a picture of any page and I'll turn it into flashcards!")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                )
                .overlay(alignment: .leading) {
                    // Bubble tail pointing left
                    BubbleTailLeft()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 12, height: 10)
                        .offset(x: -10, y: 4)
                }
        }
    }

}

// MARK: - Feature card

private struct FeatureCardView: View {
    let card: FeatureCard

    var body: some View {
        VStack(spacing: 20) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color(hex: card.accentHex).opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: card.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(hex: card.accentHex))
            }

            VStack(spacing: 8) {
                Text(card.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: card.accentHex))
                    .tracking(1.2)
                    .textCase(.uppercase)

                Text(card.headline)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(card.body)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.top, 28)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }
}

// BubbleTailLeft is now in BubbleTailShape.swift
