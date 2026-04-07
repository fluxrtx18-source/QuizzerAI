import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .scan

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: Decks ──────────────────────────────────────
            DecksView()
                .tabItem {
                    Label("Decks", systemImage: "rectangle.stack.fill")
                }
                .tag(AppTab.decks)

            // ── Tab 2: Scan (default, matches screenshot "Home") ──
            ScanHomeView()
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(AppTab.scan)
                // Tab bar tint is set per-tab via .toolbarColorScheme
                // We need the scan tab to show a black background beneath the tab bar
                .toolbarBackground(Color.black, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)

            // ── Tab 3: Profile ────────────────────────────────────
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(AppColor.brand)  // active tab icon color
    }
}

// MARK: - Tab Enum

enum AppTab: Hashable {
    case decks, scan, profile
}

