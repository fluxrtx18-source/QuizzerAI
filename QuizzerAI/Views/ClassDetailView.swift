import SwiftUI
import SwiftData

/// Shows all Decks belonging to a StudyClass.
struct ClassDetailView: View {
    let studyClass: StudyClass
    @Environment(\.modelContext) private var modelContext

    @State private var showAddDeck = false
    @State private var newDeckTitle = ""
    @State private var createError: String?
    @State private var sortedDecks: [Deck] = []
    @State private var deckToDelete: Deck?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color("BG").ignoresSafeArea()

            Group {
                if studyClass.decks.isEmpty {
                    emptyState
                } else {
                    deckList
                }
            }

            addButton
        }
        .navigationTitle(studyClass.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddDeck) {
            addDeckSheet
        }
        .alert("Couldn't Save Deck", isPresented: Binding(
            get: { createError != nil },
            set: { if !$0 { createError = nil } }
        )) {
            Button("OK", role: .cancel) { createError = nil }
        } message: {
            Text(createError ?? "")
        }
        .confirmationDialog(
            "Delete Deck",
            isPresented: Binding(
                get: { deckToDelete != nil },
                set: { if !$0 { deckToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let d = deckToDelete {
                    modelContext.delete(d)
                    do { try modelContext.save() } catch { createError = error.localizedDescription }
                    deckToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { deckToDelete = nil }
        } message: {
            if let d = deckToDelete {
                Text("This will permanently delete \"\(d.title)\" and all its flashcards.")
            }
        }
        .onChange(of: studyClass.decks.count, initial: true) { _, _ in
            sortedDecks = studyClass.decks.sorted { $0.createdAt < $1.createdAt }
        }
    }

    private var deckList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(sortedDecks) { deck in
                    NavigationLink {
                        DeckGridView(deck: deck)
                    } label: {
                        DeckRowCard(deck: deck)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deckToDelete = deck
                        } label: {
                            Label("Delete Deck", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color("AccentPurple").opacity(0.4))
            Text("No decks yet")
                .font(.title3.weight(.semibold))
            Text("Add a deck, then scan your notes to build flashcards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var addButton: some View {
        Button {
            showAddDeck = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("New Deck")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 28)
            .frame(height: 52)
            .background(Color("AccentPurple"), in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: Color("AccentPurple").opacity(0.4), radius: 12, y: 4)
        }
        .padding(.bottom, 32)
    }

    private var addDeckSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck title (e.g. Chapter 4)", text: $newDeckTitle)
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddDeck = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createDeck()
                    }
                    .disabled(newDeckTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createDeck() {
        let deck = Deck(title: newDeckTitle.trimmingCharacters(in: .whitespaces))
        deck.studyClass = studyClass
        studyClass.decks.append(deck)
        modelContext.insert(deck)
        do {
            try modelContext.save()
            newDeckTitle = ""
            showAddDeck = false
        } catch {
            createError = error.localizedDescription
        }
    }
}

// MARK: - Deck Row Card

private struct DeckRowCard: View {
    let deck: Deck

    var body: some View {
        // Cache counts once — avoids 4 separate O(n) filter passes per render.
        let pending = deck.pendingCount
        let active = deck.activeCount
        let total = deck.flashcards.count
        let progress = total > 0 ? Double(active) / Double(total) : 0

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(deck.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if pending > 0 {
                    Text("\(pending) pending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("AccentAmber"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color("AccentAmber").opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(Color("AccentPurple"))
                Text("\(active)/\(total)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 16))
    }
}
