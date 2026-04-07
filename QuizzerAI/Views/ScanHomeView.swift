import SwiftUI
import SwiftData
import PhotosUI
import os

// MARK: - Scan Mode

enum ScanMode: String, CaseIterable {
    case single = "Single Page"
    case multi  = "Multi Page"
}

// MARK: - Main View

struct ScanHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreManager
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]

    @State private var scanMode: ScanMode   = .single
    @State private var isFlashOn: Bool      = false
    @State private var showScanner: Bool    = false
    @State private var showDeckPicker: Bool = false
    @State private var targetDeck: Deck?    = nil
    @State private var showHistory: Bool    = false
    @State private var showPaywall: Bool    = false
    @State private var galleryItem: PhotosPickerItem? = nil
    @State private var isCameraActive: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            // Live viewfinder — best back camera with continuous AF/AE.
            // isActive is toggled on tab appear/disappear to avoid draining
            // battery when the user is on the Decks or Profile tab.
            CameraPreviewView(torchOn: $isFlashOn, isActive: isCameraActive)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Trial / promo banner ───────────────────────────
                trialBanner

                // ── Top bar ───────────────────────────────────────
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Spacer()

                // ── Center CTA ────────────────────────────────────
                centerPrompt
                    .onTapGesture { triggerScan() }

                Spacer()

                // ── Mode selector ─────────────────────────────────
                modePicker
                    .padding(.bottom, 22)

                // ── Camera controls ───────────────────────────────
                cameraControls
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
        .onChange(of: galleryItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                // Free-tier gate: check before inserting to avoid orphaned failed cards
                guard store.canCreateCard else {
                    showPaywall = true
                    galleryItem = nil
                    return
                }
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    galleryItem = nil
                    return
                }
                let card = Flashcard(rawPhotoData: data)
                card.deck = targetDeck ?? decks.first
                modelContext.insert(card)
                do {
                    try modelContext.save()
                } catch {
                    AppLog.ui.warning("Gallery import save failed: \(error.localizedDescription, privacy: .public)")
                    card.state = .failed
                    galleryItem = nil
                    return
                }
                // Consume AFTER successful save so the counter stays in sync with
                // persisted cards. If save fails above, no free card is wasted.
                store.consumeFreeCard()
                await AIEngine.shared.process(card: card, in: modelContext, store: store)
                galleryItem = nil
            }
        }
        .onAppear { isCameraActive = true }
        .onDisappear { isCameraActive = false }
        .confirmationDialog("Choose a deck to scan into", isPresented: $showDeckPicker, titleVisibility: .visible) {
            ForEach(decks) { deck in
                Button(deck.title) {
                    targetDeck = deck
                    showScanner = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Upgrade Banner (hidden when user is already Pro)

    private var trialBanner: some View {
        Group {
            if !store.isPro {
                Button { showPaywall = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Upgrade to QuizzerAI Pro")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("See plans →")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF4B8B")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Upgrade to QuizzerAI Pro")
                .accessibilityHint("Opens subscription plans")
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // History button
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Scan history")
            .accessibilityHint("View all previously scanned cards")

            Spacer()

            // Pro badge — opens paywall for free users; inert for Pro users (M-19)
            Button { if !store.isPro { showPaywall = true } } label: {
                HStack(spacing: 6) {
                    Text("📒")
                        .font(.system(size: 16))
                    Text("Pro")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isPro ? "QuizzerAI Pro — active" : "Upgrade to Pro")
            .accessibilityHint(store.isPro ? "" : "Opens subscription plans")
        }
    }

    // MARK: - Center Prompt

    private var centerPrompt: some View {
        VStack(spacing: 22) {
            Text("Scan a page to create flashcards")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Large + icon — the primary tap target
            ZStack {
                // subtle glow ring behind + for depth
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)

                Image(systemName: "plus")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(ScanMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scanMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(
                            size: 14,
                            weight: scanMode == mode ? .bold : .regular
                        ))
                        .foregroundStyle(
                            scanMode == mode
                                ? .white
                                : Color.white.opacity(0.38)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: 300)
    }

    // MARK: - Camera Controls

    private var cameraControls: some View {
        HStack(alignment: .center) {
            // Flashlight
            Button {
                isFlashOn.toggle()
            } label: {
                Image(systemName: isFlashOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isFlashOn ? Color(hex: "#FFD54F") : .white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isFlashOn ? "Turn off flashlight" : "Turn on flashlight")

            Spacer()

            // Main shutter (scan trigger)
            Button { triggerScan() } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3.5)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(ShutterButtonStyle())
            .accessibilityLabel("Scan page")
            .accessibilityHint("Captures the current view and creates a flashcard")

            Spacer()

            // Chat / feedback (right side icons)
            HStack(spacing: 16) {
                // Support chat — opens mailto link
                Button {
                    if let url = URL(string: "mailto:support@quizzerai.app") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Contact support")
                .accessibilityHint("Opens email to support@quizzerai.app")

                // Gallery picker — import image from Photos library
                PhotosPicker(selection: $galleryItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Import from Photos")
                .accessibilityHint("Choose an image from your photo library to create a flashcard")
            }
        }
    }

    // MARK: - Scanner Sheet

    @ViewBuilder
    private var scannerSheet: some View {
        if let deck = targetDeck {
            DocumentScannerView(deck: deck)
        } else if let first = decks.first {
            DocumentScannerView(deck: first)
        } else {
            // No decks yet — show inline message
            VStack(spacing: 20) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColor.brand)
                Text("Create a deck first")
                    .font(.title3.weight(.semibold))
                Text("Go to the Decks tab and create a deck before scanning.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.medium])
        }
    }

    // MARK: - Action

    private func triggerScan() {
        if decks.isEmpty {
            showScanner = true          // shows "no deck" message
        } else if decks.count == 1 {
            targetDeck = decks.first
            showScanner = true
        } else {
            showDeckPicker = true       // let user pick which deck
        }
    }
}

// MARK: - Shutter Button Style

/// Spring press-down feedback for the shutter ring.
private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
