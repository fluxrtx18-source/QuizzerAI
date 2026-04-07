import SwiftUI
import SwiftData
import os

/// Tinder-style verification queue.
/// On appear: warms the first 3 pending cards via JIT AI processing.
/// Each swipe either accepts the extracted Q&A (keeps .active) or
/// triggers a rescan (replaces the card photo and re-runs AI inline).
struct SwipeQueueView: View {
    let deck: Deck
    let startingCard: Flashcard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreManager

    @State private var cards: [Flashcard] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isWarming = true
    @State private var rescanTarget: Flashcard?
    /// PersistentIdentifier of the card sent to RescanView.
    /// Using an ID (value type) instead of a Flashcard? reference avoids retaining a
    /// model object that SwiftData might fault out while the sheet is animating away.
    @State private var cardToReprocessID: PersistentIdentifier?

    /// Tracks the background JIT processing task so it can be cancelled when the
    /// view is dismissed. Without this, a detached `Task` would continue running
    /// with a potentially invalidated `modelContext`.
    @State private var jitTask: Task<Void, Never>?

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            Color("BG").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                cardStack
                Spacer()
                actionBar
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        // onDismiss fires after the item is cleared — use cardToReprocess to
        // identify which card needs AI re-processing after a successful rescan.
        .sheet(item: $rescanTarget, onDismiss: {
            Task { await reprocessAfterRescan() }
        }) { card in
            RescanView(card: card, deck: deck)
        }
        .onDisappear {
            // Cancel any in-flight JIT processing — the modelContext may be
            // invalidated after the view is dismissed.
            jitTask?.cancel()
            jitTask = nil
        }
        .task {
            await warmCards()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Review Queue")
                .font(.headline)
            Spacer()
            Text("\(cards.count) left")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var cardStack: some View {
        if isWarming {
            warmingPlaceholder
        } else if cards.isEmpty {
            emptyState
        } else {
            ZStack {
                // Background cards (depth illusion)
                ForEach(Array(cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                    if index > 0 {
                        SwipeCardView(card: card, isTop: false, dragOffset: .zero)
                            .scaleEffect(1.0 - CGFloat(index) * 0.04)
                            .offset(y: CGFloat(index) * 10)
                    }
                }

                // Top (interactive) card
                if let topCard = cards.first {
                    SwipeCardView(card: topCard, isTop: true, dragOffset: dragOffset)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 10))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    handleSwipe(card: topCard, offset: value.translation)
                                }
                        )
                        .accessibilityLabel(cardAccessibilityLabel(topCard))
                        .accessibilityHint("Swipe right to accept, swipe left to rescan")
                        .accessibilityAction(named: "Accept") { acceptCard(topCard) }
                        .accessibilityAction(named: "Rescan") { triggerRescan(topCard) }
                        .accessibilityAction(named: "Skip") {
                            withAnimation(.spring()) { advanceQueue() }
                            topCard.state = .pending
                            do { try modelContext.save() } catch { AppLog.ui.warning("VoiceOver skip save failed: \(error.localizedDescription, privacy: .public)") }
                        }
                }
            }
        }
    }

    private var warmingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Reading your scan…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 20))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color("AccentPurple"))
            Text("All caught up!")
                .font(.title3.weight(.semibold))
            Text("Every card in this deck has been reviewed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var actionBar: some View {
        HStack(spacing: 32) {
            CircleActionButton(icon: "camera.fill", label: "Rescan", color: Color("AccentAmber")) {
                if let top = cards.first { triggerRescan(top) }
            }
            .accessibilityLabel("Rescan card")
            .accessibilityHint("Opens the scanner to replace this card's photo")

            CircleActionButton(icon: "arrow.counterclockwise", label: "Skip", color: .secondary) {
                if let top = cards.first {
                    withAnimation(.spring()) { advanceQueue() }
                    top.state = .pending
                    do { try modelContext.save() } catch { AppLog.ui.warning("Skip save failed: \(error.localizedDescription, privacy: .public)") }
                }
            }
            .accessibilityLabel("Skip card")
            .accessibilityHint("Moves this card to the back of the queue")

            CircleActionButton(icon: "checkmark", label: "Accept", color: .green) {
                if let top = cards.first { acceptCard(top) }
            }
            .accessibilityLabel("Accept card")
            .accessibilityHint("Marks the extracted flashcard as ready for study")
        }
        .padding(.top, 24)
    }

    // MARK: - Accessibility helpers

    private func cardAccessibilityLabel(_ card: Flashcard) -> String {
        switch card.state {
        case .active:
            let q = card.question ?? "No question"
            let a = card.answer ?? "No answer"
            return "Flashcard. Question: \(q). Answer: \(a)"
        case .failed:
            return "Flashcard scan failed. AI could not read this image."
        case .pending:
            return "Flashcard is still processing."
        }
    }

    // MARK: - Logic

    private func warmCards() async {
        isWarming = true
        var pending = deck.pendingFlashcards
        if let idx = pending.firstIndex(where: { $0.id == startingCard.id }) {
            pending.move(fromOffsets: IndexSet(integer: idx), toOffset: 0)
        }
        cards = pending

        await AIEngine.shared.processJIT(deck: deck, limit: 3, modelContext: modelContext, store: store)

        cards = deck.flashcards.filter { $0.state == .active || $0.state == .failed }
            + deck.pendingFlashcards

        isWarming = false
    }

    private func handleSwipe(card: Flashcard, offset: CGSize) {
        let direction = offset.width
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if direction > swipeThreshold {
                acceptCard(card)
            } else if direction < -swipeThreshold {
                triggerRescan(card)
            } else {
                dragOffset = .zero
            }
        }
    }

    private func acceptCard(_ card: Flashcard) {
        card.state = .active
        do { try modelContext.save() } catch { AppLog.ui.warning("Accept save failed: \(error.localizedDescription, privacy: .public)") }
        advanceQueue()

        if deck.pendingFlashcards.first != nil {
            // Store the task so it can be cancelled on view dismiss (onDisappear).
            // Prevents orphaned AI processing with an invalidated modelContext.
            jitTask = Task { await AIEngine.shared.processJIT(deck: deck, limit: 1, modelContext: modelContext, store: store) }
        }
    }

    private func advanceQueue() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if !cards.isEmpty { cards.removeFirst() }
            dragOffset = .zero
        }
    }

    /// Sets both `rescanTarget` (presents the sheet) and `cardToReprocessID`
    /// (remembered for post-dismiss AI re-processing).
    private func triggerRescan(_ card: Flashcard) {
        cardToReprocessID = card.persistentModelID
        rescanTarget = card
    }

    /// Called when `RescanView` sheet dismisses.
    /// Re-materialises the card from the model context via its stable PersistentIdentifier,
    /// then runs AI processing if the rescan saved new photo data (state == .pending).
    private func reprocessAfterRescan() async {
        defer { cardToReprocessID = nil }
        guard
            let id = cardToReprocessID,
            let card = modelContext.model(for: id) as? Flashcard,
            card.state == .pending
        else { return }

        await AIEngine.shared.process(card: card, in: modelContext, store: store)
        // Refresh the queue to reflect the newly processed card
        cards = deck.flashcards.filter { $0.state == .active || $0.state == .failed }
            + deck.pendingFlashcards
    }
}

// MARK: - Swipe Card View

private struct SwipeCardView: View {
    let card: Flashcard
    let isTop: Bool
    let dragOffset: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image — use thumbnailImage (200pt) for active cards; sourceImage while pending
            if let img = card.thumbnailImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
            } else {
                Color("CardBG")
                    .frame(height: 220)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if let q = card.question {
                    Text("Q: \(q)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(3)
                } else if card.state == .failed {
                    Label(card.explanation ?? "AI couldn't read this scan", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentAmber"))
                } else {
                    Text("Processing…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                if let a = card.answer {
                    Text(a)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                difficultyDots
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 20))
        .overlay(swipeIndicator)
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }

    @ViewBuilder
    private var difficultyDots: some View {
        if let d = card.difficulty, d > 0 {
            let clamped = min(max(d, 1), 5)
            HStack(spacing: 4) {
                ForEach(1 ... 5, id: \.self) { i in
                    Circle()
                        .fill(i <= clamped ? Color("AccentPurple") : Color("AccentPurple").opacity(0.2))
                        .frame(width: 7, height: 7)
                }
                Text("Difficulty")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var swipeIndicator: some View {
        if isTop && abs(dragOffset.width) > 20 {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    dragOffset.width > 0 ? .green : Color("AccentAmber"),
                    lineWidth: 3
                )
                .overlay(
                    Text(dragOffset.width > 0 ? "ACCEPT" : "RESCAN")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(dragOffset.width > 0 ? .green : Color("AccentAmber"))
                        .rotationEffect(.degrees(dragOffset.width > 0 ? -15 : 15))
                        .opacity(min(abs(dragOffset.width) / 60, 1))
                        .padding()
                        , alignment: dragOffset.width > 0 ? .topLeading : .topTrailing
                )
        }
    }
}

// MARK: - Circle Action Button

private struct CircleActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 58, height: 58)
                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Rescan Sheet

/// Shows the document scanner to replace a failed/blurry card's photo.
/// Uses `DocumentScannerView`'s replacement mode: the first scanned page
/// overwrites `card.rawPhotoData` and resets extracted Q&A so AI
/// re-processes the card from scratch. No duplicate cards are created.
struct RescanView: View {
    let card: Flashcard
    let deck: Deck
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DocumentScannerView(deck: deck, replacementCard: card) { _ in
            dismiss()
        }
    }
}
