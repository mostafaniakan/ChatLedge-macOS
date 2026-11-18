import SwiftUI

struct ChatBadge: View {
    var size: CGFloat = 35

    var body: some View {
        ChatMark()
            .stroke(style: StrokeStyle(lineWidth: size * 2.8 / 32, lineCap: .round, lineJoin: .round))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct ChatMark: Shape {
    func path(in rect: CGRect) -> Path {
        let mark = Path { path in
            path.move(to: CGPoint(x: 18, y: 11))
            path.addLine(to: CGPoint(x: 13.5, y: 11))
            path.addLine(to: CGPoint(x: 8, y: 6.5))
            path.addLine(to: CGPoint(x: 8, y: 11))
            path.addCurve(to: CGPoint(x: 3, y: 16), control1: CGPoint(x: 5, y: 11),
                          control2: CGPoint(x: 3, y: 13))
            path.addLine(to: CGPoint(x: 3, y: 22))
            path.addCurve(to: CGPoint(x: 8, y: 27), control1: CGPoint(x: 3, y: 25),
                          control2: CGPoint(x: 5, y: 27))
            path.addLine(to: CGPoint(x: 19, y: 27))
            path.addCurve(to: CGPoint(x: 24, y: 23), control1: CGPoint(x: 21.5, y: 27),
                          control2: CGPoint(x: 23.5, y: 25.3))

            path.move(to: CGPoint(x: 10, y: 19))
            path.addLine(to: CGPoint(x: 24, y: 19))
            path.addCurve(to: CGPoint(x: 29, y: 14), control1: CGPoint(x: 27, y: 19),
                          control2: CGPoint(x: 29, y: 17))
            path.addLine(to: CGPoint(x: 29, y: 11))
            path.addCurve(to: CGPoint(x: 24, y: 6), control1: CGPoint(x: 29, y: 8),
                          control2: CGPoint(x: 27, y: 6))
            path.addLine(to: CGPoint(x: 24, y: 3))
            path.addLine(to: CGPoint(x: 19.7, y: 6))
            path.addLine(to: CGPoint(x: 14.3, y: 6))
        }
        // The icon artwork uses upward Y coordinates. SwiftUI draws downward.
        let scale = min(rect.width, rect.height) / 32
        return mark.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
                                               tx: rect.midX - 16 * scale, ty: rect.midY + 16 * scale))
    }
}
