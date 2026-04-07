import SwiftUI
import SwiftData
import os

// MARK: - History Sheet

struct HistorySheet: View {
    @Query(sort: \Flashcard.capturedAt, order: .reverse) private var cards: [Flashcard]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Cached day-grouped cards — rebuilt only when the `@Query` result set changes.
    @State private var cachedGroups: [(String, [Flashcard])] = []

    /// Card pending deletion confirmation. Non-nil triggers the confirmation dialog.
    @State private var cardToDelete: Flashcard?

    /// Tracks whether a save error occurred during deletion.
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BG").ignoresSafeArea()

                Group {
                    if cards.isEmpty {
                        emptyState
                    } else {
                        cardList
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.brand)
                }
            }
            .onChange(of: cardsCacheKey, initial: true) { _, _ in
                cachedGroups = buildGroups(from: cards)
            }
            // Delete confirmation
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
                        deleteCard(card)
                    }
                }
                Button("Cancel", role: .cancel) {
                    cardToDelete = nil
                }
            } message: {
                if let card = cardToDelete {
                    Text("This will permanently delete \"\(card.question ?? "this flashcard")\". This action cannot be undone.")
                }
            }
            // Error alert (follows existing app pattern)
            .alert("Couldn't Delete Card", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    // MARK: - Card List

    private var cardList: some View {
        List {
            ForEach(cachedGroups, id: \.0) { day, dayCards in
                Section {
                    ForEach(dayCards) { card in
                        HistoryRow(card: card)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    cardToDelete = card
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color("CardBG"))
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .textCase(nil)
                }
            }
            .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 52))
                .foregroundStyle(AppColor.brand.opacity(0.45))
            Text("No scans yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Your scan history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Deletion

    private func deleteCard(_ card: Flashcard) {
        // Best-effort guard: mark as failed so any in-flight AIEngine task
        // observes a terminal state when it resumes after an await.
        card.state = .failed
        modelContext.delete(card)
        do {
            try modelContext.save()
            cardToDelete = nil   // only clear on success
        } catch {
            AppLog.ui.warning("HistorySheet delete failed: \(error.localizedDescription, privacy: .public)")
            deleteError = error.localizedDescription
            // cardToDelete stays set so the user sees which card failed
        }
    }

    // MARK: - Cache Key

    /// Lightweight, deterministic change signal. Encodes card count and the
    /// count of cards in each processing state into a single Int. Changes
    /// whenever cards are added/removed OR any card's state transitions.
    ///
    /// Uses arithmetic combining instead of `hashValue` — Swift randomises
    /// hash seeds per process, so `hashValue` is not stable across launches.
    /// While this key is only used at runtime (never persisted), a
    /// deterministic signal is easier to reason about and debug.
    private var cardsCacheKey: Int {
        let pending = cards.filter { $0.stateRawValue == "pending" }.count
        let active  = cards.filter { $0.stateRawValue == "active"  }.count
        let failed  = cards.filter { $0.stateRawValue == "failed"  }.count
        // Bit-pack: count in high bits, state counts in lower segments.
        // Overflow-safe thanks to &+ and &* wrapping operators.
        return cards.count &* 1_000_000 &+ pending &* 10_000 &+ active &* 100 &+ failed
    }

    // MARK: - Day grouping

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func buildGroups(from source: [Flashcard]) -> [(String, [Flashcard])] {
        let formatter = Self.dayFormatter
        var groups: [(String, [Flashcard])] = []
        var seen: [String: Int] = [:]

        for card in source {
            let key = relativeDay(for: card.capturedAt, formatter: formatter)
            if let idx = seen[key] {
                groups[idx].1.append(card)
            } else {
                seen[key] = groups.count
                groups.append((key, [card]))
            }
        }
        return groups.filter { !$0.1.isEmpty }
    }

    private func relativeDay(for date: Date, formatter: DateFormatter) -> String {
        if Calendar.current.isDateInToday(date)     { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return formatter.string(from: date)
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let card: Flashcard

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail or placeholder — use thumbnailImage (200pt) for active cards
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(stateColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                if let img = card.thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: stateIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(stateColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(card.question ?? "Processing…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Text(card.deck?.title ?? "No deck")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                stateBadge
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityLabel({
            switch card.state {
            case .active:  return "Flashcard: \(card.question ?? "Ready")"
            case .pending: return "Flashcard: Processing"
            case .failed:  return "Failed flashcard scan"
            }
        }())
        .accessibilityHint("Swipe left to delete")
    }

    private var stateBadge: some View {
        Text(stateLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(stateColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(stateColor.opacity(0.12), in: Capsule())
    }

    private var stateLabel: String {
        switch card.state {
        case .pending: "Pending"
        case .active:  "Ready"
        case .failed:  "Failed"
        }
    }

    private var stateColor: Color {
        switch card.state {
        case .pending: Color(hex: "#FF9500")
        case .active:  Color(hex: "#34C759")
        case .failed:  Color(hex: "#FF3B30")
        }
    }

    private var stateIcon: String {
        switch card.state {
        case .pending: "hourglass"
        case .active:  "checkmark"
        case .failed:  "xmark"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: card.capturedAt)
    }
}
