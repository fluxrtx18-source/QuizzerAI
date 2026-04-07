import SwiftUI
import SwiftData

struct DeckGridView: View {
    let deck: Deck
    @Environment(\.modelContext) private var modelContext

    @State private var showScanner = false
    @State private var recentlySaved = 0
    @State private var showSaveToast = false

    // Tapping a pending card launches the JIT swipe queue from that card
    @State private var launchSwipeFrom: Flashcard?
    @State private var showCramMode = false
    @State private var sortedCards: [Flashcard] = []
    @State private var cardToDelete: Flashcard?
    @State private var deleteError: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color("BG").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    deckHeader
                    cardGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }

            bottomBar
        }
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(deck: deck) { count in
                recentlySaved = count
                withAnimation { showSaveToast = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { showSaveToast = false }
                }
            }
        }
        .sheet(item: $launchSwipeFrom) { card in
            SwipeQueueView(deck: deck, startingCard: card)
        }
        .navigationDestination(isPresented: $showCramMode) {
            CramModeView(deck: deck)
        }
        .overlay(alignment: .top) {
            if showSaveToast {
                saveToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .confirmationDialog(
            "Delete Flashcard",
            isPresented: Binding(
                get: { cardToDelete != nil },
                set: { if !$0 { cardToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let card = cardToDelete {
                    modelContext.delete(card)
                    do { try modelContext.save() } catch { deleteError = error.localizedDescription }
                    cardToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { cardToDelete = nil }
        } message: {
            Text("This will permanently delete this flashcard.")
        }
        .alert("Couldn't Delete Card", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .onChange(of: deck.flashcards.count, initial: true) { _, _ in
            sortedCards = deck.flashcards.sorted { $0.capturedAt < $1.capturedAt }
        }
    }

    // MARK: - Subviews

    private var deckHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(deck.flashcards.count) cards")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ProgressView(value: deck.progressFraction)
                        .tint(Color("AccentPurple"))
                        .frame(width: 120)
                }
                Spacer()
                pendingBadge
            }
        }
    }

    @ViewBuilder
    private var pendingBadge: some View {
        let count = deck.pendingCount
        if count > 0 {
            Label("\(count) pending", systemImage: "clock.badge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AccentAmber"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color("AccentAmber").opacity(0.15), in: Capsule())
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sortedCards) { card in
                FlashcardThumbnail(card: card)
                    .onTapGesture {
                        if card.state == .pending {
                            launchSwipeFrom = card
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            cardToDelete = card
                        } label: {
                            Label("Delete Card", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Button {
                showScanner = true
            } label: {
                Label("Scan", systemImage: "camera.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 14))
            }
            .foregroundStyle(Color("AccentPurple"))

            Button {
                showCramMode = true
            } label: {
                Label("Cram", systemImage: "bolt.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color("AccentPurple"), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(deck.activeCount == 0)
            .opacity(deck.activeCount == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .background(.ultraThinMaterial)
    }

    private var saveToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(recentlySaved) page\(recentlySaved == 1 ? "" : "s") saved")
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showScanner = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Thumbnail Cell

struct FlashcardThumbnail: View {
    let card: Flashcard

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnailImage
            stateOverlay
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let img = card.thumbnailImage {   // uses 200pt thumbnail or full scan for pending cards
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            Color("CardBG")
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                )
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch card.state {
        case .pending:
            // Shimmer-style loading badge
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text("Pending")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(8)

        case .active:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .padding(8)

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color("AccentAmber"))
                .font(.title3)
                .padding(8)
        }
    }

    private var borderColor: Color {
        switch card.state {
        case .pending: return .clear
        case .active:  return .green.opacity(0.4)
        case .failed:  return Color("AccentAmber").opacity(0.6)
        }
    }
}
