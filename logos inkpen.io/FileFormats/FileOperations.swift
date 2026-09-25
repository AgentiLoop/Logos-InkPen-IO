import SwiftUI

class FileOperations {

    static func convertVectorPathToCGPath(_ vectorPath: VectorPath) -> CGPath {
        let cgPath = CGMutablePath()
        for element in vectorPath.elements {
            switch element {
            case .move(let point):
                cgPath.move(to: CGPoint(x: point.x, y: point.y))
            case .line(let point):
                cgPath.addLine(to: CGPoint(x: point.x, y: point.y))
            case .curve(let point, let control1, let control2):
                cgPath.addCurve(
                    to: CGPoint(x: point.x, y: point.y),
                    control1: CGPoint(x: control1.x, y: control1.y),
                    control2: CGPoint(x: control2.x, y: control2.y)
                )
            case .quadCurve(let point, let control):
                cgPath.addQuadCurve(
                    to: CGPoint(x: point.x, y: point.y),
                    control: CGPoint(x: control.x, y: control.y)
                )
            case .close:
                if !cgPath.isEmpty {
                    cgPath.closeSubpath()
                }
            }
        }
        return cgPath
    }
}
