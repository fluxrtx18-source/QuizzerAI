import SwiftUI

/// Screen 9 — interactive app demo.
/// The user studies 3 sample flashcards (tap to flip) to experience the core mechanic
/// before hitting the paywall. This is the "aha moment" — they DO something, not just watch.
struct AppDemoStepView: View {
    var onContinue: () -> Void

    private let cards = DemoFlashcards.cards

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var appeared = false
    @State private var completed = false

    // Track which cards the user has flipped (seen the answer)
    @State private var seenAnswers: Set<Int> = []

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 52)

                // ── Header ─────────────────────────────────────────
                VStack(spacing: 8) {
                    Text(completed ? "Nice work! 🎉" : "Try a quick study session")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: completed)

                    Text(completed
                         ? "You just studied \(cards.count) cards in seconds."
                         : "Tap the card to see the answer")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.textMuted)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: completed)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.05), value: appeared)

                Spacer().frame(height: 28)

                // ── Progress dots ──────────────────────────────────
                HStack(spacing: 8) {
                    ForEach(cards.indices, id: \.self) { i in
                        Circle()
                            .fill(cardDotColor(for: i))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentIndex)
                            .animation(.spring(response: 0.3), value: seenAnswers)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: appeared)

                Spacer().frame(height: 24)

                // ── Flip card ──────────────────────────────────────
                if !completed {
                    flipCard
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    completionView
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                Spacer()
            }

            // ── Bottom controls ────────────────────────────────────
            if !completed {
                bottomControls
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.3), value: appeared)
            } else {
                continueCTA
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.38), value: completed)
        .onAppear { appeared = true }
    }

    // MARK: - Flip Card

    private var flipCard: some View {
        let card = cards[currentIndex]
        return ZStack {
            // Front — question
            CardFace(
                subject: card.subject,
                text: card.question,
                isAnswer: false,
                accentHex: card.accentHex
            )
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 0 : 1)

            // Back — answer
            CardFace(
                subject: card.subject,
                text: card.answer,
                isAnswer: true,
                accentHex: card.accentHex
            )
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 1 : 0)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
            if !isFlipped {
                // Just flipped to front — mark as seen when they first flip to answer
            } else {
                seenAnswers.insert(currentIndex)
            }
        }
        .id(currentIndex) // force view recreation on card change so flip resets
        .accessibilityLabel(isFlipped
            ? "Answer: \(card.answer)"
            : "Question: \(card.question). Tap to reveal the answer.")
        .accessibilityHint(isFlipped ? "Tap to flip back" : "Double tap to reveal the answer")
    }

    // MARK: - Bottom controls (shown while studying)

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // "Got it / Next" row — only active after flipping to see answer
            if isFlipped {
                HStack(spacing: 14) {
                    // "Again" — restart this card
                    Button {
                        advanceCard()
                    } label: {
                        Label("Again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "#FF6B6B"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "#FF6B6B").opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // "Got it" — advance to next
                    Button {
                        advanceCard()
                    } label: {
                        Label("Got it", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#10B981"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "#10B981").opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Text(isFlipped ? "Tap card to flip back" : "Tap the card to reveal the answer")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textMuted)
        }
        .animation(.easeInOut(duration: 0.25), value: isFlipped)
    }

    // MARK: - Continue CTA (shown after all cards studied)

    private var continueCTA: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            Button(action: onContinue) {
                Text("See your first deck →")
                    .font(.system(size: 17, weight: .semibold))
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

    // MARK: - Completion view

    private var completionView: some View {
        VStack(spacing: 24) {
            // Mini card stack
            ZStack {
                ForEach(cards.indices.reversed(), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: cards[i].accentHex).opacity(0.12))
                        .frame(height: 160)
                        .offset(y: CGFloat(i - 1) * 10)
                        .scaleEffect(1.0 - CGFloat(cards.count - 1 - i) * 0.04)
                }
            }
            .frame(height: 200)

            VStack(spacing: 8) {
                Text("\(cards.count) cards studied")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Now imagine scanning a full chapter in 30 seconds.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Helpers

    private func cardDotColor(for index: Int) -> Color {
        if index < currentIndex || (completed) {
            return AppColor.brand
        } else if index == currentIndex {
            return seenAnswers.contains(index) ? AppColor.brand.opacity(0.5) : AppColor.separator
        } else {
            return AppColor.separator
        }
    }

    private func advanceCard() {
        let next = currentIndex + 1
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeInOut(duration: 0.38)) {
                if next < cards.count {
                    currentIndex = next
                } else {
                    completed = true
                }
            }
        }
    }
}

// MARK: - Card Face

private struct CardFace: View {
    let subject: String
    let text: String
    let isAnswer: Bool
    let accentHex: String

    var body: some View {
        VStack(spacing: 0) {
            // Subject tag
            HStack {
                Text(subject.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: accentHex))
                Spacer()
                Image(systemName: isAnswer ? "lightbulb.fill" : "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: accentHex).opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Card text
            Text(text)
                .font(.system(size: isAnswer ? 16 : 18, weight: isAnswer ? .regular : .semibold))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            Spacer()

            // Tap hint (front only)
            if !isAnswer {
                Text("Tap to reveal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: accentHex).opacity(0.5))
                    .padding(.bottom, 16)
            } else {
                Spacer().frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isAnswer
                      ? Color(hex: accentHex).opacity(0.06)
                      : Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color(hex: accentHex).opacity(isAnswer ? 0.3 : 0.15), lineWidth: 1.5)
        )
    }
}

#Preview {
    AppDemoStepView(onContinue: {})
}
