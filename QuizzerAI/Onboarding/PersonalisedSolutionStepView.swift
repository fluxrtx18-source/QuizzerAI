import SwiftUI

/// Screen 7 — personalised solution.
/// Mirrors the user's stated goal back and shows how QuizzerAI addresses each pain point.
/// This is the "bridge" moment — "you told us your problems, here's exactly how we fix them."
struct PersonalisedSolutionStepView: View {
    var goal: String             // selected goal from Screen 3
    var onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 52)

                    // ── Headline ───────────────────────────────────────
                    VStack(spacing: 10) {
                        Text(PersonalisedSolutionData.headline(for: goal))
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        if !goal.isEmpty {
                            goalPill
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

                    Spacer().frame(height: 32)

                    // ── Solution items ─────────────────────────────────
                    VStack(spacing: 14) {
                        ForEach(Array(PersonalisedSolutionData.items.enumerated()), id: \.element.id) { idx, item in
                            SolutionRow(item: item)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 18)
                                .animation(
                                    .easeOut(duration: 0.38).delay(0.18 + Double(idx) * 0.08),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 120)
                }
            }

            // ── Fixed CTA ──────────────────────────────────────────
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                Button(action: onContinue) {
                    Text("Show me how")
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
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Goal pill

    private var goalPill: some View {
        Text(goal)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColor.brand)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(AppColor.brand.opacity(0.1), in: Capsule())
    }
}

// MARK: - Solution Row

private struct SolutionRow: View {
    let item: SolutionItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColor.brand.opacity(0.10))
                    .frame(width: 48, height: 48)
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.brand)
            }

            VStack(alignment: .leading, spacing: 4) {
                // "Before" — what they said was a pain
                Text(item.painPoint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColor.textMuted)
                    .strikethrough(true, color: AppColor.textMuted.opacity(0.6))

                // "After" — how QuizzerAI fixes it
                Text(item.solution)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppColor.separator, lineWidth: 1)
        )
    }
}

#Preview {
    PersonalisedSolutionStepView(goal: "🎯 Ace an upcoming exam", onContinue: {})
}
