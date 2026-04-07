import SwiftUI

/// Root onboarding container.
/// Owns the 11-step state machine and slide transitions.
/// Writes `onboardingComplete = true` to AppStorage when the user finishes
/// (either by subscribing or by choosing the 20-card free escape on the paywall).
struct OnboardingContainerView: View {
    @AppStorage(UserDefaultsKeys.onboardingComplete) private var onboardingComplete = false

    @State private var step: OnboardingStep = .welcome
    @State private var selectedGoal: String = ""
    @State private var selectedLevel: String = ""
    @State private var selectedPainPoints: [String] = []
    @Namespace private var mascotNamespace

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeStepView(namespace: mascotNamespace) {
                    advance(to: .carousel)
                }
                .transition(welcomeTransition)

            case .carousel:
                CarouselStepView(namespace: mascotNamespace) {
                    advance(to: .goalQ)
                }
                .transition(slideTransition)

            case .goalQ:
                QuestionStepView(
                    question: OnboardingQuestions.goal,
                    progress: 1.0 / 3.0,
                    onBack: { retreat(to: .carousel) },
                    onContinue: { answer in
                        selectedGoal = answer
                        advance(to: .levelQ)
                    }
                )
                .transition(slideTransition)

            case .levelQ:
                QuestionStepView(
                    question: OnboardingQuestions.level,
                    progress: 2.0 / 3.0,
                    onBack: { retreat(to: .goalQ) },
                    onContinue: { answer in
                        selectedLevel = answer
                        advance(to: .painPoints)
                    }
                )
                .transition(slideTransition)

            case .painPoints:
                PainPointsStepView(
                    progress: 3.0 / 3.0,
                    onBack: { retreat(to: .levelQ) },
                    onContinue: { points in
                        selectedPainPoints = points
                        advance(to: .socialProof)
                    }
                )
                .transition(slideTransition)

            case .socialProof:
                SocialProofStepView {
                    advance(to: .solution)
                }
                .transition(slideTransition)

            case .solution:
                PersonalisedSolutionStepView(goal: selectedGoal) {
                    advance(to: .cameraPermission)
                }
                .transition(slideTransition)

            case .cameraPermission:
                CameraPermissionPrimingView {
                    advance(to: .appDemo)
                }
                .transition(slideTransition)

            case .appDemo:
                AppDemoStepView {
                    advance(to: .valueDelivery)
                }
                .transition(slideTransition)

            case .valueDelivery:
                ValueDeliveryStepView {
                    advance(to: .paywall)
                }
                .transition(slideTransition)

            case .paywall:
                PaywallView(onDismiss: completeOnboarding, isOnboarding: true)
                    .transition(slideTransition)
            }
        }
        // Animation is applied explicitly via withAnimation in advance()/retreat()
        // to give per-transition control over timing. An implicit .animation() here
        // would double-animate, causing visual rubber-banding.
    }

    // MARK: - Transitions

    private var welcomeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }

    // MARK: - Navigation

    private func advance(to next: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.38)) {
            step = next
        }
    }

    private func retreat(to prev: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.32)) {
            step = prev
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.3)) {
            onboardingComplete = true
        }
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(StoreManager())
}
