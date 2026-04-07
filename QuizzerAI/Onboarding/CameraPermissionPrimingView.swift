import SwiftUI
import AVFoundation

/// Screen 8 — camera permission priming.
/// Explains WHY camera access is needed before the one-shot system dialog appears.
/// "Not now" skips without triggering the dialog — iOS will prompt in-context later.
struct CameraPermissionPrimingView: View {
    var onContinue: () -> Void

    @State private var appeared = false
    @State private var isRequesting = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Icon ──────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(AppColor.brand.opacity(0.10))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(AppColor.brand.opacity(0.18))
                        .frame(width: 88, height: 88)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(AppColor.brand)
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.05), value: appeared)

                Spacer().frame(height: 32)

                // ── Headline ──────────────────────────────────────────
                Text("Allow camera access")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                Spacer().frame(height: 12)

                Text("QuizzerAI uses your camera to scan pages into flashcards. Nothing is ever sent to the cloud.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.38).delay(0.22), value: appeared)

                Spacer().frame(height: 36)

                // ── Benefits list ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    BenefitRow(icon: "camera.viewfinder",  text: "Scan any page in seconds")
                    BenefitRow(icon: "lock.fill",          text: "Images stay on your device")
                    BenefitRow(icon: "sparkles",           text: "AI runs locally — no upload needed")
                }
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.38).delay(0.3), value: appeared)

                Spacer()
            }

            // ── Buttons ───────────────────────────────────────────────
            VStack(spacing: 10) {
                // Primary — triggers system dialog
                Button {
                    isRequesting = true
                    Task {
                        _ = await AVCaptureDevice.requestAccess(for: .video)
                        await MainActor.run {
                            isRequesting = false
                            onContinue()
                        }
                    }
                } label: {
                    ZStack {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable Camera")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.brand, in: Capsule())
                }
                .disabled(isRequesting)
                .padding(.horizontal, 24)

                // Secondary — skip without prompting
                Button("Not now", action: onContinue)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textMuted)
                    .padding(.bottom, 6)
            }
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.4), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.brand)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(AppColor.textPrimary)
        }
    }
}

#Preview {
    CameraPermissionPrimingView(onContinue: {})
}
