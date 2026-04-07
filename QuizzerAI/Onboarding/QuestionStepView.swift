import SwiftUI

/// Reusable questionnaire screen used for screens 3, 4, 5.
/// Shows mascot avatar + speech bubble, scrollable option list,
/// top progress bar, back arrow, and fixed "Continue" button.
struct QuestionStepView: View {
    var question: OnboardingQuestion
    var progress: Double       // 0…1 — how far along the progress bar should be
    var onBack: () -> Void
    var onContinue: (String) -> Void  // passes selected option

    @State private var selected: String? = nil
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar: back + progress ───────────────────────
                topBar
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                // ── Mascot header ──────────────────────────────────
                mascotHeader
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)
                    .animation(.easeOut(duration: 0.3).delay(0.05), value: appeared)

                Spacer().frame(height: 24)

                // ── Option list ────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(Array(question.options.enumerated()), id: \.element) { idx, option in
                            OptionCard(
                                text: option,
                                isSelected: selected == option
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    selected = option
                                }
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(
                                .easeOut(duration: 0.3).delay(0.1 + Double(idx) * 0.04),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 110) // clear the fixed button
                }
            }

            // ── Fixed bottom CTA ───────────────────────────────────
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                Button {
                    if let sel = selected { onContinue(sel) }
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            selected != nil
                                ? AppColor.brand
                                : AppColor.brand.opacity(0.5),
                            in: Capsule()
                        )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .padding(.bottom, 20)
                .background(Color(UIColor.systemBackground))
                .animation(.easeInOut(duration: 0.2), value: selected != nil)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .frame(width: 32)
            .accessibilityLabel("Go back")

            // Progress pill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.separator)
                    Capsule()
                        .fill(AppColor.brand)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
        .frame(height: 32)
    }

    // MARK: - Mascot header

    private var mascotHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            MascotView(size: 52, isAvatar: true)

            Text(question.speechBubble)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
                )
                .overlay(alignment: .leading) {
                    BubbleTailLeft()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 12, height: 10)
                        .offset(x: -10, y: 4)
                }
        }
    }
}

// MARK: - Option card

private struct OptionCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.brand)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(isSelected ? AppColor.brand.opacity(0.07) : Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        isSelected ? AppColor.brand : AppColor.separator,
                        lineWidth: isSelected ? 1.8 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

