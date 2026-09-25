import SwiftUI

struct RightTriangleIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let topLeft = CGPoint(x: 5 - IconStrokeExpand, y: 5 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: 5 - IconStrokeExpand, y: 15 + IconStrokeExpand)
            let bottomRight = CGPoint(x: 15 + IconStrokeExpand, y: 15 + IconStrokeExpand)
            path.move(to: topLeft)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
