import SwiftUI

/// Top-level gate: shows OnboardingContainerView on first launch,
/// then MainTabView (Scan home + Decks + Profile).
/// Also owns the app-wide colour scheme preference so `.preferredColorScheme`
/// is applied at the highest possible level — covering both onboarding and main app.
struct RootView: View {
    @AppStorage(UserDefaultsKeys.onboardingComplete) private var onboardingComplete = false
    @AppStorage(UserDefaultsKeys.appearanceMode) private var appearanceModeRaw: Int = 0

    private var preferredColorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme
    }

    var body: some View {
        ZStack {
            if !onboardingComplete {
                OnboardingContainerView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboardingComplete)
        .preferredColorScheme(preferredColorScheme)
    }
}
