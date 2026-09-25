import SwiftUI

struct EggIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let center = CGPoint(x: 10, y: 10)
            let radiusX: CGFloat = 4 + IconStrokeExpand
            let radiusY: CGFloat = 6 + IconStrokeExpand
            let eggOffset = radiusY * 0.3
            let controlPointOffsetX = radiusX * 0.552
            let controlPointOffsetY = radiusY * 0.552
            path.move(to: CGPoint(x: center.x + radiusX, y: center.y))
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y - radiusY - eggOffset),
                control1: CGPoint(x: center.x + radiusX, y: center.y - controlPointOffsetY),
                control2: CGPoint(x: center.x + controlPointOffsetX, y: center.y - radiusY - eggOffset)
            )
            path.addCurve(
                to: CGPoint(x: center.x - radiusX, y: center.y),
                control1: CGPoint(x: center.x - controlPointOffsetX, y: center.y - radiusY - eggOffset),
                control2: CGPoint(x: center.x - radiusX, y: center.y - controlPointOffsetY)
            )
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y + radiusY - eggOffset),
                control1: CGPoint(x: center.x - radiusX, y: center.y + controlPointOffsetY),
                control2: CGPoint(x: center.x - controlPointOffsetX, y: center.y + radiusY - eggOffset)
            )
            path.addCurve(
                to: CGPoint(x: center.x + radiusX, y: center.y),
                control1: CGPoint(x: center.x + controlPointOffsetX, y: center.y + radiusY - eggOffset),
                control2: CGPoint(x: center.x + radiusX, y: center.y + controlPointOffsetY)
            )
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
