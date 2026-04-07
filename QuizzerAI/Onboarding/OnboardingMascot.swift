import SwiftUI

/// Pure-SwiftUI robot mascot with a wizard hat.
/// size controls the overall bounding box.
struct MascotView: View {
    var size: CGFloat = 120
    /// When true, renders a smaller avatar version (used in speech-bubble rows)
    var isAvatar: Bool = false

    private var headW: CGFloat  { size * 0.72 }
    private var headH: CGFloat  { size * 0.60 }
    private var eyeD:  CGFloat  { size * 0.165 }
    private var hatH:  CGFloat  { size * 0.52 }

    var body: some View {
        ZStack(alignment: .center) {
            // ── Sparkles (welcome screen only) ────────────────────────
            if !isAvatar {
                SparkleField(size: size)
            }

            VStack(spacing: 0) {
                // ── Wizard hat ────────────────────────────────────────
                WizardHat(width: headW * 0.9, height: hatH)

                // ── Head ─────────────────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.13)
                        .fill(Color(hex: "#1A1A2E"))
                        .frame(width: headW, height: headH)

                    // ear bolts
                    HStack(spacing: headW * 0.92) {
                        Circle()
                            .fill(Color(hex: "#2E2E4E"))
                            .frame(width: size * 0.09, height: size * 0.09)
                    }

                    VStack(spacing: size * 0.07) {
                        // eyes row
                        HStack(spacing: eyeD * 0.95) {
                            EyeView(diameter: eyeD)
                            EyeView(diameter: eyeD)
                        }

                        // mouth bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#00E5FF").opacity(0.5))
                            .frame(width: headW * 0.35, height: size * 0.04)
                    }
                }
            }
            .offset(y: hatH * 0.18) // tuck hat into frame
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)  // decorative illustration — VoiceOver skips it
    }
}

// MARK: - Eye

private struct EyeView: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            // glow halo
            Circle()
                .fill(Color(hex: "#00E5FF").opacity(0.25))
                .frame(width: diameter * 1.5, height: diameter * 1.5)
            // iris
            Circle()
                .fill(Color(hex: "#00E5FF"))
                .frame(width: diameter, height: diameter)
            // pupil
            Circle()
                .fill(Color(hex: "#003366"))
                .frame(width: diameter * 0.45, height: diameter * 0.45)
            // specular dot
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: diameter * 0.18, height: diameter * 0.18)
                .offset(x: diameter * 0.12, y: -diameter * 0.12)
        }
    }
}

// MARK: - Wizard Hat

private struct WizardHat: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            // Cone (triangle via custom Shape)
            HatCone()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#8B5CF6"), Color(hex: "#6D28D9")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.55, height: height * 0.78)
                .overlay(alignment: .top) {
                    // star on tip
                    Text("★")
                        .font(.system(size: width * 0.13))
                        .foregroundStyle(Color(hex: "#FFD54F"))
                        .offset(y: -width * 0.04)
                }

            // Brim
            Capsule()
                .fill(Color(hex: "#4C1D95"))
                .frame(width: width, height: height * 0.16)
        }
        .frame(width: width, height: height)
        // floating stars on the cone
        .overlay(alignment: .leading) {
            Text("✦")
                .font(.system(size: width * 0.11))
                .foregroundStyle(Color(hex: "#FFD54F").opacity(0.85))
                .offset(x: width * 0.16, y: -height * 0.22)
        }
        .overlay(alignment: .trailing) {
            Text("✦")
                .font(.system(size: width * 0.08))
                .foregroundStyle(Color(hex: "#FFD54F").opacity(0.7))
                .offset(x: -width * 0.1, y: -height * 0.38)
        }
    }
}

private struct HatCone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Sparkles (welcome only)

private struct SparkleField: View {
    let size: CGFloat

    private let positions: [(CGFloat, CGFloat, CGFloat)] = [
        (-0.52,  0.05, 0.16),
        ( 0.50, -0.10, 0.13),
        (-0.30, -0.42, 0.11),
        ( 0.28,  0.38, 0.12),
        (-0.10,  0.50, 0.09)
    ]

    var body: some View {
        ZStack {
            ForEach(positions.indices, id: \.self) { i in
                let (dx, dy, scale) = positions[i]
                Image(systemName: "sparkle")
                    .font(.system(size: size * scale))
                    .foregroundStyle(Color(hex: "#FFD54F").opacity(0.85))
                    .offset(x: size * dx, y: size * dy)
            }
        }
    }
}

#Preview {
    HStack(spacing: 32) {
        MascotView(size: 200)
        MascotView(size: 52, isAvatar: true)
    }
    .padding()
}
