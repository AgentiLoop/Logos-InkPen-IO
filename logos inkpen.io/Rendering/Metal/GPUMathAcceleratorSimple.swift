import simd
import CoreGraphics

class GPUMathAcceleratorSimple {
    static let shared = GPUMathAcceleratorSimple()

    private init() {}

    func douglasPeuckerSimplifyGPUReady(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        return douglasPeuckerOptimized(points: points, tolerance: Float(tolerance))
    }

    private func douglasPeuckerOptimized(points: [CGPoint], tolerance: Float) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var result: [CGPoint] = []
        var stack: [(startIndex: Int, endIndex: Int)] = [(0, points.count - 1)]
        var keepPoints = Set<Int>()
        keepPoints.insert(0)
        keepPoints.insert(points.count - 1)
        while !stack.isEmpty {
            let segment = stack.removeLast()
            let startIndex = segment.startIndex
            let endIndex = segment.endIndex
            if endIndex - startIndex <= 1 {
                continue
            }
            let lineStart = points[startIndex]
            let lineEnd = points[endIndex]

            var maxDistance: Float = 0
            var maxIndex = startIndex
            for i in (startIndex + 1)..<endIndex {
                let distance = perpendicularDistanceOptimized(
                    point: points[i],
                    lineStart: lineStart,
                    lineEnd: lineEnd
                )
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = i
                }
            }
            if maxDistance > tolerance {
                keepPoints.insert(maxIndex)
                stack.append((startIndex: startIndex, endIndex: maxIndex))
                stack.append((startIndex: maxIndex, endIndex: endIndex))
            }
        }
        result = keepPoints.sorted().map { points[$0] }
        return result
    }

    private func perpendicularDistanceOptimized(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Float {
        let lineVec = SIMD2<Float>(Float(lineEnd.x - lineStart.x), Float(lineEnd.y - lineStart.y))
        let normal = SIMD2<Float>(lineVec.y, -lineVec.x)
        let pointVec = SIMD2<Float>(Float(point.x - lineStart.x), Float(point.y - lineStart.y))
        let numerator = abs(simd_dot(normal, pointVec))
        let denominator = simd_length(normal)
        return numerator / denominator
    }

    func optimizeDrawingPath(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        if points.count > 20 {
            return douglasPeuckerSimplifyGPUReady(points, tolerance: tolerance)
        } else {
            return points
        }
    }

    var isGPUReady: Bool {
        return true
    }

    func getPerformanceInfo() -> String {
        return "SIMD CPU Accelerated"
    }
}
