import SwiftUI

/// Screen 5 — multi-select pain points.
/// Mascot speech bubble asks what gets in the way; user can pick multiple options.
/// "Continue" is always enabled (user can skip without selecting anything).
struct PainPointsStepView: View {
    var progress: Double
    var onBack: () -> Void
    var onContinue: ([String]) -> Void

    @State private var selected: Set<String> = []
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ────────────────────────────────────────
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

                Spacer().frame(height: 8)

                // ── "Pick all that apply" hint ─────────────────────
                Text("Pick all that apply")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.1), value: appeared)

                Spacer().frame(height: 16)

                // ── Option list ────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(Array(OnboardingPainPoints.options.enumerated()), id: \.element) { idx, option in
                            PainPointCard(
                                text: option,
                                isSelected: selected.contains(option)
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    if selected.contains(option) {
                                        selected.remove(option)
                                    } else {
                                        selected.insert(option)
                                    }
                                }
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(
                                .easeOut(duration: 0.3).delay(0.12 + Double(idx) * 0.04),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 110)
                }
            }

            // ── Fixed CTA (always enabled — skip is fine) ──────────
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                Button {
                    onContinue(Array(selected))
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColor.brand, in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .padding(.bottom, 20)
                .background(Color(UIColor.systemBackground))
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .frame(width: 32)
            .accessibilityLabel("Go back")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.separator)
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

            Text(OnboardingPainPoints.speechBubble)
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

// MARK: - Pain Point Card (checkbox-style, multi-select)

private struct PainPointCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? AppColor.brand : Color.clear)
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? AppColor.brand : AppColor.separator,
                            lineWidth: isSelected ? 0 : 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)

                Text(text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColor.brand : AppColor.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

#Preview {
    PainPointsStepView(progress: 1.0, onBack: {}, onContinue: { _ in })
}
