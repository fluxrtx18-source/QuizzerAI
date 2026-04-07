import SwiftUI

/// Reusable speech-bubble tail pointing left.
/// Used by CarouselStepView, QuestionStepView, and PainPointsStepView.
struct BubbleTailLeft: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
