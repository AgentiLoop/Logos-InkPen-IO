import SwiftUI

extension DrawingCanvas {

    /// Illustrator-style polygon/star drawing: the press point is the centre, the drag distance is the
    /// radius, and the shape rotates to follow the cursor. Shift locks the shape upright.
    /// Returns nil for tools that are not radial shapes.
    internal func radialShapePath(tool: DrawingTool, center: CGPoint, cursor: CGPoint) -> VectorPath? {
        let sides: Int
        switch tool {
        case .polygon, .hexagon: sides = 6
        case .pentagon: sides = 5
        case .heptagon: sides = 7
        case .octagon: sides = 8
        case .nonagon: sides = 9
        case .star: sides = 0
        default: return nil
        }
        let dx = cursor.x - center.x
        let dy = cursor.y - center.y
        let radius = hypot(dx, dy)
        let isShift = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
        let upright = -Double.pi / 2
        let firstAngle = isShift ? upright : atan2(dy, dx)

        var elements: [PathElement] = []
        if sides == 0 {
            let points: Int
            let innerRatio: Double
            switch ToolGroupManager.shared.selectedVariant {
            case .threePoint: points = 3; innerRatio = 0.22
            case .fourPoint: points = 4; innerRatio = 0.28
            case .fivePoint: points = 5; innerRatio = 0.40
            case .sixPoint: points = 6; innerRatio = 0.40
            case .sevenPoint: points = 7; innerRatio = 0.40
            }
            let step = Double.pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = firstAngle + Double(i) * step
                let r = i % 2 == 0 ? radius : radius * innerRatio
                let point = VectorPoint(center.x + cos(angle) * r, center.y + sin(angle) * r)
                elements.append(i == 0 ? .move(to: point) : .line(to: point))
            }
        } else {
            let step = 2 * Double.pi / Double(sides)
            for i in 0..<sides {
                let angle = firstAngle + Double(i) * step
                let point = VectorPoint(center.x + cos(angle) * radius, center.y + sin(angle) * radius)
                elements.append(i == 0 ? .move(to: point) : .line(to: point))
            }
        }
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }
}
