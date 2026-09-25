import SwiftUI

struct EquilateralTriangleIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let center = CGPoint(x: 10, y: 10)
            let height: CGFloat = 8
            let width: CGFloat = height * 2 / sqrt(3)
            let topPoint = CGPoint(x: center.x, y: center.y - height * 0.6 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: center.x - width * 0.5 - IconStrokeExpand, y: center.y + height * 0.4 + IconStrokeExpand)
            let bottomRight = CGPoint(x: center.x + width * 0.5 + IconStrokeExpand, y: center.y + height * 0.4 + IconStrokeExpand)
            path.move(to: topPoint)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
