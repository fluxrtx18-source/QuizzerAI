import SwiftUI

/// Screen 1 — large centered mascot, headline, body copy, "Get Started" CTA.
/// The namespace + isActive flag let the container animate the mascot
/// shrinking into the header position on the next screen.
struct WelcomeStepView: View {
    var namespace: Namespace.ID
    var onGetStarted: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Mascot with matchedGeometryEffect so it can animate to avatar
                MascotView(size: 200)
                    .matchedGeometryEffect(id: "mascot", in: namespace)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                Spacer().frame(height: 32)

                // Headline
                Text("Stop re-reading.\nStart remembering.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.45).delay(0.25), value: appeared)

                Spacer().frame(height: 14)

                // Body
                Text("Point your camera at any notes or textbook. QuizzerAI creates flashcards in seconds — 100% on your device.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)

                Spacer()

                // CTA
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColor.brand, in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }
}
