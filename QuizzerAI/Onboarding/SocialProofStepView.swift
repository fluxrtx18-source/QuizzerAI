import SwiftUI

/// Screen 6 — social proof.
/// Headline stat + 3 scrollable testimonial cards to reduce risk perception.
struct SocialProofStepView: View {
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
                        Text(SocialProofData.headline)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        Text(SocialProofData.subheadline)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColor.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

                    Spacer().frame(height: 32)

                    // ── Testimonials ───────────────────────────────────
                    VStack(spacing: 16) {
                        ForEach(Array(SocialProofData.testimonials.enumerated()), id: \.element.id) { idx, t in
                            TestimonialCard(testimonial: t)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(
                                    .easeOut(duration: 0.4).delay(0.15 + Double(idx) * 0.1),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 120) // clear the fixed button
                }
            }

            // ── Fixed CTA ──────────────────────────────────────────
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                Button(action: onContinue) {
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
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.45), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Testimonial Card

private struct TestimonialCard: View {
    let testimonial: Testimonial

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stars
            HStack(spacing: 3) {
                ForEach(0 ..< testimonial.stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#FFB800"))
                }
            }

            // Review text
            Text("\"\(testimonial.review)\"")
                .font(.system(size: 15))
                .foregroundStyle(AppColor.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Reviewer
            HStack(spacing: 10) {
                // Avatar circle with initials
                ZStack {
                    Circle()
                        .fill(AppColor.brand.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(testimonial.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColor.brand)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(testimonial.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(testimonial.persona)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.textMuted)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppColor.separator, lineWidth: 1)
        )
    }
}

#Preview {
    SocialProofStepView(onContinue: {})
}
