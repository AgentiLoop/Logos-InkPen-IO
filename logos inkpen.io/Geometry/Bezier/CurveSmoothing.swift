import SwiftUI
import simd

struct CurveSmoothing {

    static func chaikinSmooth(points: [CGPoint], iterations: Int = 1, ratio: Double = 0.25) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        var smoothedPoints = points
        for _ in 0..<iterations {
            if smoothedPoints.count >= 50 {
                let metalEngine = MetalComputeEngine.shared
                let smoothingResult = metalEngine.chaikinSmoothingGPU(points: smoothedPoints, ratio: Float(ratio))
                switch smoothingResult {
                case .success(let smoothed):
                    smoothedPoints = smoothed
                case .failure(_):
                    smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
                }
            } else {
                smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
            }
            if smoothedPoints.count < 3 {
                break
            }
        }
        return smoothedPoints
    }

    private static func applySingleChaikinIteration(points: [CGPoint], ratio: Double) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        var newPoints: [CGPoint] = []
        newPoints.append(points[0])
        for i in 0..<points.count-1 {
            let p0 = points[i].simd
            let p1 = points[i + 1].simd
            let q = p0 + (p1 - p0) * ratio
            let r = p0 + (p1 - p0) * (1.0 - ratio)
            newPoints.append(CGPoint(q))
            newPoints.append(CGPoint(r))
        }
        if let lastPoint = points.last {
            newPoints.append(lastPoint)
        }
        return newPoints
    }

    static func improvedDouglassPeucker(points: [CGPoint], tolerance: Double, preserveSharpCorners: Bool = true) -> [CGPoint] {
        guard points.count > 2 else { return points }
        return improvedDPRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1, preserveSharpCorners: preserveSharpCorners)
    }

    private static func improvedDPRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int, preserveSharpCorners: Bool) -> [CGPoint] {
        var maxDistance: Double = 0
        var maxIndex = 0
        var maxCurvature: Double = 0
        for i in startIndex + 1..<endIndex {
            let distance = perpendicularDistance(point: points[i], lineStart: points[startIndex], lineEnd: points[endIndex])
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
            if preserveSharpCorners && i > startIndex && i < endIndex - 1 {
                let curvature = calculateCurvature(p0: points[i-1], p1: points[i], p2: points[i+1])
                maxCurvature = max(maxCurvature, curvature)
            }
        }
        let isSharpCorner = preserveSharpCorners && maxCurvature > 0.7
        if maxDistance > tolerance || isSharpCorner {
            let leftPoints = improvedDPRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex, preserveSharpCorners: preserveSharpCorners)
            let rightPoints = improvedDPRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex, preserveSharpCorners: preserveSharpCorners)
            return leftPoints + Array(rightPoints.dropFirst())
        } else {
            return [points[startIndex], points[endIndex]]
        }
    }

    static func adaptiveCurveFitting(points: [CGPoint], adaptiveTension: Bool = true, baseTension: Double = 0.3) -> [PathElement] {
        guard points.count >= 2 else { return [] }
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))
        if points.count == 2 {
            elements.append(.line(to: VectorPoint(points[1])))
            return elements
        }
        for i in 1..<points.count {
            let p0 = points[max(0, i - 2)]
            let p1 = points[i - 1]
            let p2 = points[i]
            let p3 = points[min(points.count - 1, i + 1)]

            var tension = baseTension
            if adaptiveTension {
                let curvature = calculateCurvature(p0: p0, p1: p1, p2: p2)
                let distance = p2.distance(to: p1)
                tension = baseTension * (1.0 - curvature * 0.5) * min(2.0, distance / 50.0)
                tension = max(0.1, min(0.8, tension))
            }
            let (control1, control2) = calculateCentripetalControls(p0: p0, p1: p1, p2: p2, p3: p3, tension: tension)
            elements.append(.curve(
                to: VectorPoint(p2),
                control1: VectorPoint(control1),
                control2: VectorPoint(control2)
            ))
        }
        return elements
    }

    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let pointVec = point.simd - lineStart.simd
        let lineVec = lineEnd.simd - lineStart.simd
        let lenSq = simd_length_squared(lineVec)
        if lenSq == 0 {
            return simd_length(pointVec)
        }
        let param = simd_dot(pointVec, lineVec) / lenSq
        let closest: SIMD2<Double>
        if param < 0 {
            closest = lineStart.simd
        } else if param > 1 {
            closest = lineEnd.simd
        } else {
            closest = lineStart.simd + param * lineVec
        }
        return simd_length(point.simd - closest)
    }

    private static func calculateCurvature(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let v1 = p1.simd - p0.simd
        let v2 = p2.simd - p1.simd
        let len1 = simd_length(v1)
        let len2 = simd_length(v2)
        if len1 == 0 || len2 == 0 {
            return 0
        }
        let n1 = simd_normalize(v1)
        let n2 = simd_normalize(v2)
        let dotProduct = simd_dot(n1, n2)
        return 1.0 - abs(dotProduct)
    }

    static func calculateCurvatureBatch(points: [CGPoint]) -> [Double] {
        guard points.count >= 3 else { return [] }
        if points.count >= 100 {
            let metalEngine = MetalComputeEngine.shared
            let results = metalEngine.calculateCurvatureGPU(points: points)
            switch results {
            case .success(let curvatures):
                return curvatures.map { Double($0) }
            case .failure(_):
                break
            }
        }
        var curvatures: [Double] = []
        curvatures.append(0.0)
        for i in 1..<(points.count - 1) {
            let curvature = calculateCurvature(p0: points[i-1], p1: points[i], p2: points[i+1])
            curvatures.append(curvature)
        }
        curvatures.append(0.0)
        return curvatures
    }

    private static func calculateCentripetalControls(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tension: Double) -> (CGPoint, CGPoint) {
        let d1 = p1.distance(to: p0)
        let d2 = p2.distance(to: p1)
        let d3 = p3.distance(to: p2)
        let d1Safe = max(d1, 0.001)
        let d2Safe = max(d2, 0.001)
        let d3Safe = max(d3, 0.001)
        let t1 = CGPoint(
            x: (p2.x - p0.x) / (d1Safe + d2Safe),
            y: (p2.y - p0.y) / (d1Safe + d2Safe)
        )
        let t2 = CGPoint(
            x: (p3.x - p1.x) / (d2Safe + d3Safe),
            y: (p3.y - p1.y) / (d2Safe + d3Safe)
        )
        let control1 = CGPoint(
            x: p1.x + t1.x * d2Safe * tension,
            y: p1.y + t1.y * d2Safe * tension
        )
        let control2 = CGPoint(
            x: p2.x - t2.x * d2Safe * tension,
            y: p2.y - t2.y * d2Safe * tension
        )
        return (control1, control2)
    }
}
