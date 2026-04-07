import SwiftUI
import SwiftData
import StoreKit

// MARK: - Profile View

struct ProfileView: View {
    @Query private var decks: [Deck]
    // M3: StudyClass rows represent what the app calls "Decks" at the top-level tab
    @Query private var classes: [StudyClass]
    @EnvironmentObject private var store: StoreManager
    @Environment(\.openURL) private var openURL
    @AppStorage(UserDefaultsKeys.appearanceMode) private var appearanceModeRaw: Int = 0
    @State private var showPaywall = false
    @State private var showHistory = false

    private var totalCards: Int { decks.reduce(0) { $0 + $1.flashcards.count } }
    private var activeCards: Int { decks.reduce(0) { $0 + $1.activeCount } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BG").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        avatarHeader
                        premiumCard
                        subscriptionSection
                        statsStrip
                        activitySection
                        appearanceSection
                        supportSection
                        legalSection
                        versionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet()
        }
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColor.brand, AppColor.brandEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Text("Q")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
            }
            Text("QuizzerAI User")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.top, 8)
    }

    // MARK: - Premium Card

    private var premiumCard: some View {
        Button { if !store.isPro { showPaywall = true } } label: {
            ZStack(alignment: .leading) {
                // Background gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [AppColor.brand, AppColor.brandEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AppColor.brand.opacity(0.35), radius: 16, y: 6)

                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 130, height: 130)
                    .offset(x: 220, y: -30)
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 90, height: 90)
                    .offset(x: 270, y: 30)

                HStack(spacing: 14) {
                    // Crown icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("QuizzerAI Premium")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                        Text("Unlimited scans · On-device AI · Private")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.78))
                    }

                    Spacer()

                    if store.isPro {
                        VStack(alignment: .trailing, spacing: 2) {
                            Label("Active", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColor.brand)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.white, in: Capsule())
                        }
                    } else {
                        Text("Upgrade")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColor.brand)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white, in: Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .frame(height: 84)
            .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.isPro ? "QuizzerAI Premium — Active" : "Upgrade to QuizzerAI Premium")
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(classes.count)", label: "Decks")
            statDivider
            statCell(value: "\(totalCards)", label: "Cards")
            statDivider
            statCell(value: "\(activeCards)", label: "Studied")
        }
        .padding(.vertical, 18)
        .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(AppColor.brand)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(AppColor.separator)
            .frame(width: 1, height: 36)
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        if store.isPro {
            sectionCard(title: "Subscription") {
                VStack(spacing: 0) {
                    if let plan = store.activePlan {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColor.brand)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColor.textPrimary)
                                if let exp = store.expirationDate {
                                    Text("Renews \(exp, style: .date)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        Divider().padding(.leading, 52)
                    }

                    profileRow(
                        icon: "gearshape.fill",
                        iconColor: .gray,
                        label: "Manage Subscription"
                    ) {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        sectionCard(title: "Activity") {
            profileRow(
                icon: "clock.arrow.circlepath",
                iconColor: AppColor.brand,
                label: "History"
            ) { showHistory = true }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        sectionCard(title: "Appearance") {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColor.brand)
                            .frame(width: 32, height: 32)
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("Theme")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer()

                    // 3-segment picker: Auto / Light / Dark
                    Picker("Theme", selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                            Image(systemName: mode.icon)
                                .tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .accessibilityLabel("Select theme: \(AppearanceMode(rawValue: appearanceModeRaw)?.label ?? "Auto")")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        sectionCard(title: "Support") {
            profileRow(
                icon: "questionmark.circle.fill",
                iconColor: .green,
                label: "FAQ"
            ) {
                if let url = URL(string: "https://quizzerai.app/faq") {
                    openURL(url)
                }
            }

            Divider().padding(.leading, 52)

            profileRow(
                icon: "star.fill",
                iconColor: .orange,
                label: "Rate QuizzerAI"
            ) {
                requestReview()
            }
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        sectionCard(title: "Legal") {
            profileRow(
                icon: "doc.text.fill",
                iconColor: .blue,
                label: "Terms of Use"
            ) {
                if let url = URL(string: "https://quizzerai.app/terms") {
                    openURL(url)
                }
            }

            Divider().padding(.leading, 52)

            profileRow(
                icon: "hand.raised.fill",
                iconColor: Color(red: 0.345, green: 0.337, blue: 0.839),
                label: "Privacy Policy"
            ) {
                if let url = URL(string: "https://quizzerai.app/privacy") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - Footer

    private var versionFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return Text("QuizzerAI v\(version) · Built with ♥ for students")
            .font(.system(size: 12))
            .foregroundStyle(AppColor.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard(title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColor.sectionTitle)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                rows()
            }
            .background(Color("CardBG"), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func profileRow(
        icon: String,
        iconColor: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.chevron)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rate

    @MainActor
    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            AppStore.requestReview(in: scene)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Deck.self, Flashcard.self], inMemory: true)
        .environmentObject(StoreManager())
}
