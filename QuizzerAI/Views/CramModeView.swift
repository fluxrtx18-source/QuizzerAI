import SwiftUI
import SwiftData
import os

struct CramModeView: View {
    let deck: Deck
    @Environment(\.modelContext) private var modelContext

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var showExplanation = false
    @State private var correctCount = 0
    @State private var sessionDone = false

    /// Snapshot of active cards taken once on appear — avoids re-filtering/sorting
    /// `deck.activeFlashcards` on every body evaluation during the cram session.
    @State private var cards: [Flashcard] = []

    private var currentCard: Flashcard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        ZStack {
            Color("BG").ignoresSafeArea()

            if sessionDone || cards.isEmpty {
                sessionSummary
            } else {
                VStack(spacing: 0) {
                    progressBar
                    cardArea
                    answerControls
                }
            }
        }
        .navigationBarBackButtonHidden(sessionDone)
        .navigationTitle("Cram Mode")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if cards.isEmpty { cards = deck.activeFlashcards }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color("CardBG")
                Color("AccentPurple")
                    .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(cards.count, 1)))
                    .animation(.spring(), value: currentIndex)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Card Area

    private var cardArea: some View {
        ZStack {
            // FRONT — question
            frontFace
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)

            // BACK — answer + explanation
            backFace
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
        .onTapGesture { flipCard() }
        .accessibilityLabel(
            isFlipped
                ? "Answer: \(currentCard?.answer ?? "No answer")"
                : "Question: \(currentCard?.question ?? "No question")"
        )
        .accessibilityHint("Tap to flip the card")
    }

    private var frontFace: some View {
        VStack(spacing: 20) {
            Spacer()

            if let card = currentCard {
                difficultyBar(card: card)

                Text(card.question ?? "No question extracted")
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.caption)
                Text("Tap to reveal")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.tertiary)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }

    private var backFace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let card = currentCard {
                    // Question recap (dimmed)
                    Text(card.question ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Answer
                    Text(card.answer ?? "")
                        .font(.system(size: 18, weight: .regular))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Explanation toggle
                    if let exp = card.explanation, !exp.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showExplanation.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showExplanation ? "Hide explanation" : "Show explanation")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color("AccentPurple"))
                                Image(systemName: showExplanation ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(Color("AccentPurple"))
                            }
                        }

                        if showExplanation {
                            Text(exp)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color("AccentPurple").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        }
                    }
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }

    // MARK: - Answer Controls

    @ViewBuilder
    private var answerControls: some View {
        if isFlipped {
            HStack(spacing: 16) {
                Button {
                    recordAnswer(correct: false)
                } label: {
                    Label("Wrong", systemImage: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color("AccentAmber").opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color("AccentAmber"))
                }

                Button {
                    recordAnswer(correct: true)
                } label: {
                    Label("Got it", systemImage: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Color.clear.frame(height: 84)
        }
    }

    // MARK: - Session Summary

    private var sessionSummary: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color("AccentPurple").opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color("AccentPurple"))
            }

            VStack(spacing: 8) {
                Text("Session Complete")
                    .font(.title.weight(.bold))

                Text("\(correctCount) / \(cards.count) correct")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Accuracy ring
            ZStack {
                Circle()
                    .stroke(Color("AccentPurple").opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: accuracyFraction)
                    .stroke(Color("AccentPurple"), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.2), value: accuracyFraction)
                Text("\(Int(accuracyFraction * 100))%")
                    .font(.title2.weight(.bold))
            }
            .frame(width: 120, height: 120)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func flipCard() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isFlipped.toggle()
            if !isFlipped { showExplanation = false }
        }
    }

    private func recordAnswer(correct: Bool) {
        guard let card = currentCard else { return }
        card.reviewCount += 1
        if correct {
            card.correctCount += 1
            correctCount += 1
        }
        card.lastReviewedAt = Date()
        deck.lastStudiedAt = Date()
        do { try modelContext.save() } catch { AppLog.ui.warning("CramMode save failed: \(error.localizedDescription, privacy: .public)") }

        withAnimation {
            isFlipped = false
            showExplanation = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            // Guard against the view being dismissed during the sleep delay.
            // Without this, the state mutation fires on a dead view.
            guard !Task.isCancelled else { return }
            withAnimation {
                if currentIndex + 1 >= cards.count {
                    sessionDone = true
                } else {
                    currentIndex += 1
                }
            }
        }
    }

    private var accuracyFraction: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(correctCount) / Double(cards.count)
    }

    @ViewBuilder
    private func difficultyBar(card: Flashcard) -> some View {
        if let d = card.difficulty, d > 0 {
            let clamped = min(max(d, 1), 5)  // L-31: guard against out-of-range values
            HStack(spacing: 3) {
                ForEach(1 ... 5, id: \.self) { i in
                    Capsule()
                        .fill(i <= clamped ? Color("AccentPurple") : Color("AccentPurple").opacity(0.15))
                        .frame(width: 20, height: 5)
                }
            }
        }
    }
}
