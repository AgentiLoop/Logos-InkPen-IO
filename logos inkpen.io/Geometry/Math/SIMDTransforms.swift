import Foundation
import CoreGraphics
import simd

extension VectorPoint {

    func applying(_ transform: CGAffineTransform) -> VectorPoint {
        let matrix = simd_double3x3(
            SIMD3(Double(transform.a), Double(transform.b), 0),
            SIMD3(Double(transform.c), Double(transform.d), 0),
            SIMD3(Double(transform.tx), Double(transform.ty), 1)
        )
        let homogeneous = SIMD3(simdPoint.x, simdPoint.y, 1.0)
        let result = matrix * homogeneous
        return VectorPoint(simd: SIMD2(result.x, result.y))
    }

    static func applyingTransform(_ points: [VectorPoint], transform: CGAffineTransform) -> [VectorPoint] {
        let matrix = simd_double3x3(
            SIMD3(Double(transform.a), Double(transform.b), 0),
            SIMD3(Double(transform.c), Double(transform.d), 0),
            SIMD3(Double(transform.tx), Double(transform.ty), 1)
        )
        return points.map { point in
            let homogeneous = SIMD3(point.simdPoint.x, point.simdPoint.y, 1.0)
            let result = matrix * homogeneous
            return VectorPoint(simd: SIMD2(result.x, result.y))
        }
    }
}

extension PathElement {

    func applying(_ transform: CGAffineTransform) -> PathElement {
        switch self {
        case .move(let to):
            return .move(to: to.applying(transform))
        case .line(let to):
            return .line(to: to.applying(transform))
        case .curve(let to, let control1, let control2):
            return .curve(
                to: to.applying(transform),
                control1: control1.applying(transform),
                control2: control2.applying(transform)
            )
        case .quadCurve(let to, let control):
            return .quadCurve(
                to: to.applying(transform),
                control: control.applying(transform)
            )
        case .close:
            return .close
        }
    }
}

extension VectorPath {

    func applying(_ transform: CGAffineTransform) -> VectorPath {
        if transform.isIdentity {
            return self
        }
        let transformedElements = elements.map { $0.applying(transform) }
        return VectorPath(elements: transformedElements, isClosed: isClosed, fillRule: fillRule.cgPathFillRule)
    }
}

extension VectorShape {

    func applyingSIMDTransform(_ transform: CGAffineTransform) -> VectorShape {
        var newShape = self
        newShape.path = path.applying(transform)
        newShape.transform = .identity
        newShape.updateBounds()
        return newShape
    }
}

extension Array where Element == VectorPoint {

    func simdBounds() -> CGRect? {
        guard let first = first else { return nil }
        var minPoint = first.simdPoint
        var maxPoint = first.simdPoint
        for point in self.dropFirst() {
            minPoint = simd_min(minPoint, point.simdPoint)
            maxPoint = simd_max(maxPoint, point.simdPoint)
        }
        return CGRect(
            x: minPoint.x,
            y: minPoint.y,
            width: maxPoint.x - minPoint.x,
            height: maxPoint.y - minPoint.y
        )
    }
}

extension VectorPath {

    func simdBounds() -> CGRect {
        var points: [VectorPoint] = []
        for element in elements {
            switch element {
            case .move(let to), .line(let to):
                points.append(to)
            case .curve(let to, let control1, let control2):
                points.append(contentsOf: [to, control1, control2])
            case .quadCurve(let to, let control):
                points.append(contentsOf: [to, control])
            case .close:
                break
            }
        }
        return points.simdBounds() ?? .zero
    }
}
