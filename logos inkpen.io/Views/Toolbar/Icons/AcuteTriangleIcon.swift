import SwiftUI

struct AcuteTriangleIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let baseWidth: CGFloat = 8
            let height: CGFloat = 12
            let center = CGPoint(x: 10, y: 10)
            let topPoint = CGPoint(x: center.x, y: center.y - height * 0.5 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: center.x - baseWidth * 0.5 - IconStrokeExpand, y: center.y + height * 0.5 + IconStrokeExpand)
            let bottomRight = CGPoint(x: center.x + baseWidth * 0.5 + IconStrokeExpand, y: center.y + height * 0.5 + IconStrokeExpand)
            path.move(to: topPoint)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
