import Foundation
import CoreGraphics

extension VectorShape {

    func calculateCentroid() -> CGPoint {
        var vertices: [CGPoint] = []
        for element in path.elements {
            if let point = element.endpointCGPoint {
                vertices.append(point)
            }
        }
        if vertices.count < 3 {
            let shapeBounds = isGroupContainer ? groupBounds : bounds
            return CGPoint(x: shapeBounds.midX, y: shapeBounds.midY)
        }
        var signedArea: CGFloat = 0.0
        var cx: CGFloat = 0.0
        var cy: CGFloat = 0.0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let xi = vertices[i].x
            let yi = vertices[i].y
            let xj = vertices[j].x
            let yj = vertices[j].y
            let a = xi * yj - xj * yi
            signedArea += a
            cx += (xi + xj) * a
            cy += (yi + yj) * a
        }
        signedArea *= 0.5
        if abs(signedArea) < 0.001 {
            let sumX = vertices.reduce(0.0) { $0 + $1.x }
            let sumY = vertices.reduce(0.0) { $0 + $1.y }
            return CGPoint(x: sumX / CGFloat(vertices.count), y: sumY / CGFloat(vertices.count))
        }
        let factor = 1.0 / (6.0 * signedArea)
        cx *= factor
        cy *= factor
        return CGPoint(x: cx, y: cy)
    }
}
