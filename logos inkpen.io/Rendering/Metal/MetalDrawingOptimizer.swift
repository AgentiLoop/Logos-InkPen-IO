import simd
import CoreGraphics

class MetalDrawingOptimizer {
    static let shared = MetalDrawingOptimizer()

    private init() {}

    func optimizePathSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        return cpuOptimizedSimplification(points, tolerance: tolerance)
    }

    func optimizeRealTimeDrawing(enabled: Bool) {
    }

    private func cpuOptimizedSimplification(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        return douglasPeuckerOptimized(points: points, tolerance: tolerance)
    }

    private func douglasPeuckerOptimized(points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        guard let startPoint = points.first,
              let endPoint = points.last else { return points }
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        if maxDistance > tolerance {
            let leftPoints = Array(points[0...maxIndex])
            let rightPoints = Array(points[maxIndex..<points.count])
            let leftSimplified = douglasPeuckerOptimized(points: leftPoints, tolerance: tolerance)
            let rightSimplified = douglasPeuckerOptimized(points: rightPoints, tolerance: tolerance)
            return leftSimplified + Array(rightSimplified.dropFirst())
        } else {
            return [startPoint, endPoint]
        }
    }

    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let pointVec = SIMD2<Double>(Double(point.x), Double(point.y))
        let startVec = SIMD2<Double>(Double(lineStart.x), Double(lineStart.y))
        let endVec = SIMD2<Double>(Double(lineEnd.x), Double(lineEnd.y))
        let toPoint = pointVec - startVec
        let lineVec = endVec - startVec
        let dot = simd_dot(toPoint, lineVec)
        let lenSq = simd_length_squared(lineVec)
        guard lenSq != 0 else { return CGFloat(simd_length(toPoint)) }
        let param = dot / lenSq
        let closestVec: SIMD2<Double>
        if param < 0 {
            closestVec = startVec
        } else if param > 1 {
            closestVec = endVec
        } else {
            closestVec = startVec + lineVec * param
        }
        let distance = simd_length(pointVec - closestVec)
        return CGFloat(distance)
    }

    func trackDrawingStart() {
    }

    func optimizePointCollection(_ points: inout [CGPoint], maxPoints: Int = 500) {
        if points.count > maxPoints {
            let step = max(2, points.count / (maxPoints / 2))
            let simplified = Swift.stride(from: 0, to: points.count, by: step).map { points[$0] }
            if let lastPoint = points.last {
                points = simplified + [lastPoint]
            } else {
                points = simplified
            }
        }
    }
}

extension MetalDrawingOptimizer {

    func optimizeFreehandDrawing(points: [CGPoint], tolerance: CGFloat = 2.0) -> [CGPoint] {
        trackDrawingStart()
        if points.count > 20 {
            let metalEngine = MetalComputeEngine.shared
            let result = metalEngine.douglasPeuckerGPU(points, tolerance: Float(tolerance))
            switch result {
            case .success(let simplifiedPoints):
                return simplifiedPoints
            case .failure(_):
                return GPUMathAcceleratorSimple.shared.optimizeDrawingPath(points, tolerance: tolerance)
            }
        }
        return points
    }

    func adaptiveOptimization(cpuUsage: Double) {
        if cpuUsage > 70 {
            optimizeRealTimeDrawing(enabled: true)
        } else if cpuUsage < 30 {
            optimizeRealTimeDrawing(enabled: false)
        }
    }
}
