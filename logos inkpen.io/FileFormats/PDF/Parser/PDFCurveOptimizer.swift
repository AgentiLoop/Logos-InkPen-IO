import SwiftUI
import simd

struct PDFCurveOptimizer {

    static func convertToQuadCurve(
        from start: CGPoint,
        cp1: CGPoint,
        cp2: CGPoint,
        to end: CGPoint
    ) -> PathCommand? {
        let startVec = simd_float2(Float(start.x), Float(start.y))
        let cp1Vec = simd_float2(Float(cp1.x), Float(cp1.y))
        let cp2Vec = simd_float2(Float(cp2.x), Float(cp2.y))
        let endVec = simd_float2(Float(end.x), Float(end.y))
        let potentialQCP1Vec = startVec + 1.5 * (cp1Vec - startVec)
        let potentialQCP2Vec = endVec + 1.5 * (cp2Vec - endVec)
        let diff = potentialQCP1Vec - potentialQCP2Vec
        let absDiff = simd_abs(diff)
        let tolerance: Float = 0.1
        if absDiff.x < tolerance && absDiff.y < tolerance {
            let quadCPVec = (potentialQCP1Vec + potentialQCP2Vec) * 0.5
            let quadCP = CGPoint(
                x: CGFloat(quadCPVec.x),
                y: CGFloat(quadCPVec.y)
            )
            return .quadCurveTo(cp: quadCP, to: end)
        }
        return nil
    }

    static func batchConvertToQuadCurves(curves: [(start: CGPoint, cp1: CGPoint, cp2: CGPoint, end: CGPoint)]) -> [PathCommand?] {
        guard !curves.isEmpty else { return [] }
        var results = [PathCommand?]()
        results.reserveCapacity(curves.count)
        for curve in curves {
            results.append(convertToQuadCurve(
                from: curve.start,
                cp1: curve.cp1,
                cp2: curve.cp2,
                to: curve.end
            ))
        }
        return results
    }

    static func arePointsCollinear(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, tolerance: CGFloat = 0.1) -> Bool {
        let v1 = simd_float2(Float(p2.x - p1.x), Float(p2.y - p1.y))
        let v2 = simd_float2(Float(p3.x - p1.x), Float(p3.y - p1.y))
        let cross = v1.x * v2.y - v1.y * v2.x
        return abs(cross) < Float(tolerance)
    }

    static func batchCheckCollinearity(triplets: [(CGPoint, CGPoint, CGPoint)], tolerance: CGFloat = 0.1) -> [Bool] {
        guard !triplets.isEmpty else { return [] }
        return PDFMetalAccelerator.shared.batchCheckCollinearity(triplets: triplets, tolerance: Float(tolerance))
    }

    static func calculateCurveFlatness(
        start: CGPoint,
        cp1: CGPoint,
        cp2: CGPoint,
        end: CGPoint
    ) -> CGFloat {
        let startVec = simd_float2(Float(start.x), Float(start.y))
        let cp1Vec = simd_float2(Float(cp1.x), Float(cp1.y))
        let cp2Vec = simd_float2(Float(cp2.x), Float(cp2.y))
        let endVec = simd_float2(Float(end.x), Float(end.y))
        let lineVec = endVec - startVec
        let lineLength = simd_length(lineVec)
        guard lineLength > 0 else { return 0 }
        let toCP1 = cp1Vec - startVec
        let projLength1 = simd_dot(toCP1, lineVec) / lineLength
        let proj1 = startVec + (lineVec / lineLength) * projLength1
        let dist1 = simd_distance(cp1Vec, proj1)
        let toCP2 = cp2Vec - startVec
        let projLength2 = simd_dot(toCP2, lineVec) / lineLength
        let proj2 = startVec + (lineVec / lineLength) * projLength2
        let dist2 = simd_distance(cp2Vec, proj2)
        return CGFloat(max(dist1, dist2))
    }

    static func batchCalculateFlatness(curves: [(start: CGPoint, cp1: CGPoint, cp2: CGPoint, end: CGPoint)]) -> [CGFloat] {
        guard !curves.isEmpty else { return [] }
        var results = [CGFloat]()
        results.reserveCapacity(curves.count)
        for curve in curves {
            results.append(calculateCurveFlatness(
                start: curve.start,
                cp1: curve.cp1,
                cp2: curve.cp2,
                end: curve.end
            ))
        }
        return results
    }
}
