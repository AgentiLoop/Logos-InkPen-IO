import SwiftUI
import simd

struct RealTimeSmoothing {

    static func applyRealTimeSmoothing(
        newPoint: CGPoint,
        recentPoints: inout [CGPoint],
        windowSize: Int = 5,
        strength: Double = 0.3
    ) -> CGPoint {
        recentPoints.append(newPoint)
        if recentPoints.count > windowSize {
            recentPoints = Array(recentPoints.suffix(windowSize))
        }
        guard recentPoints.count >= 3 else {
            return newPoint
        }
        let smoothed = weightedAverageSmoothing(points: recentPoints, strength: strength)
        return smoothed.last ?? newPoint
    }

    private static func weightedAverageSmoothing(points: [CGPoint], strength: Double) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        var smoothedPoints = points
        for i in 1..<points.count - 1 {
            let prevVec = SIMD2<Double>(Double(points[i - 1].x), Double(points[i - 1].y))
            let currVec = SIMD2<Double>(Double(points[i].x), Double(points[i].y))
            let nextVec = SIMD2<Double>(Double(points[i + 1].x), Double(points[i + 1].y))
            let smoothVec = prevVec * 0.25 + currVec * 0.5 + nextVec * 0.25
            let resultVec = currVec * (1.0 - strength) + smoothVec * strength
            smoothedPoints[i] = CGPoint(x: resultVec.x, y: resultVec.y)
        }
        return smoothedPoints
    }
}
