import SwiftUI

/// Screen 10 — value delivery / viral moment.
/// Short processing animation reveals the user's "first deck" output.
/// The deck is gated behind the paywall on the next screen — sunk cost drives conversion.
struct ValueDeliveryStepView: View {
    var onContinue: () -> Void

    @State private var phase: Phase = .processing
    @State private var appeared = false

    private let cards = DemoFlashcards.cards

    enum Phase { case processing, revealed }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            switch phase {
            case .processing:
                processingView
                    .transition(.opacity)
            case .revealed:
                revealedView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
        .onAppear {
            appeared = true
            // Auto-advance to revealed after a brief processing pause
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation { phase = .revealed }
            }
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated sparkle icon
            ZStack {
                Circle()
                    .fill(AppColor.brand.opacity(0.08))
                    .frame(width: 120, height: 120)
                ProgressView()
                    .scaleEffect(1.6)
                    .tint(AppColor.brand)
            }

            VStack(spacing: 8) {
                Text("Building your first deck…")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Organising your cards")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textMuted)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Revealed

    private var revealedView: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 52)

                    // ── Header ─────────────────────────────────────
                    VStack(spacing: 10) {
                        Text("Your first deck is ready! ✨")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        Text("You studied \(cards.count) cards — here's what QuizzerAI made for you.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColor.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }

                    Spacer().frame(height: 32)

                    // ── Deck preview ───────────────────────────────
                    VStack(spacing: 12) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                            DeckPreviewRow(card: card, index: idx + 1)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 24)

                    // ── Stats strip ────────────────────────────────
                    statsStrip

                    Spacer().frame(height: 120)
                }
            }

            // ── CTA ────────────────────────────────────────────────
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("Keep my deck")
                            .font(.system(size: 17, weight: .semibold))
                        Text("→")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.brand, in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .padding(.bottom, 20)
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(cards.count)", label: "Cards")
            Divider().frame(height: 32)
            StatPill(value: "1", label: "Deck")
            Divider().frame(height: 32)
            StatPill(value: "0s", label: "Wait time")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColor.brand.opacity(0.06))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Deck Preview Row

private struct DeckPreviewRow: View {
    let card: DemoFlashcard
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color(hex: card.accentHex).opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: card.accentHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(card.subject)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: card.accentHex))
                    .tracking(0.8)
                    .textCase(.uppercase)
                Text(card.question)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(AppColor.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AppColor.separator, lineWidth: 1)
        )
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppColor.brand)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ValueDeliveryStepView(onContinue: {})
}
