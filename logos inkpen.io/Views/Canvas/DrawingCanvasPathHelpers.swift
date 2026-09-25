import SwiftUI
import simd
import Accelerate

typealias Vec2D = SIMD2<Double>

typealias Vec8D = SIMD8<Double>

enum DrawingCanvasPathHelpers {

    static func douglasPeuckerSimplify(points: [CGPoint], tolerance: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }
        return douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
    }

    static func douglasPeuckerRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int) -> [CGPoint] {
        guard endIndex - startIndex > 1 else {
            return [points[startIndex], points[endIndex]]
        }
        let startPoint = points[startIndex]
        let endPoint = points[endIndex]

        var maxDistance: Double = 0
        var maxIndex = startIndex

        let count = endIndex - startIndex - 1
        if count >= 8 {
            let distances = perpendicularDistancesBatch(
                points: points[(startIndex + 1)..<endIndex],
                lineStart: startPoint,
                lineEnd: endPoint
            )
            for (offset, distance) in distances.enumerated() {
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = startIndex + 1 + offset
                }
            }
        } else {
            for i in (startIndex + 1)..<endIndex {
                let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = i
                }
            }
        }
        if maxDistance > tolerance {
            let leftSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex)
            let rightSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex)
            return leftSegment + Array(rightSegment.dropFirst())
        } else {
            return [startPoint, endPoint]
        }
    }

    static func perpendicularDistancesBatch(
        points: ArraySlice<CGPoint>,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> [Double] {
        let count = points.count
        guard count > 0 else { return [] }
        let A = lineEnd.y - lineStart.y
        let B = lineStart.x - lineEnd.x
        let C = lineEnd.x * lineStart.y - lineStart.x * lineEnd.y
        let denominator = simd_length(Vec2D(A, B))

        var distances = [Double](repeating: 0, count: count)

        let stride = 8
        let fullBatches = count / stride
        for batch in 0..<fullBatches {
            let baseIndex = batch * stride

            var xs = Vec8D()
            var ys = Vec8D()
            for i in 0..<stride {
                let pt = points[points.startIndex + baseIndex + i]
                xs[i] = pt.x
                ys[i] = pt.y
            }
            let values = xs * Vec8D(repeating: A) + ys * Vec8D(repeating: B) + Vec8D(repeating: C)

            var numerators = Vec8D()
            for i in 0..<8 {
                numerators[i] = abs(values[i])
            }
            let results = numerators / Vec8D(repeating: denominator)
            for i in 0..<stride {
                distances[baseIndex + i] = results[i]
            }
        }
        let remaining = count - (fullBatches * stride)
        if remaining > 0 {
            let baseIndex = fullBatches * stride
            for i in 0..<remaining {
                let pt = points[points.startIndex + baseIndex + i]
                let numerator = abs(A * pt.x + B * pt.y + C)
                distances[baseIndex + i] = numerator / denominator
            }
        }
        return distances
    }

    static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let A = lineEnd.y - lineStart.y
        let B = lineStart.x - lineEnd.x
        let C = lineEnd.x * lineStart.y - lineStart.x * lineEnd.y
        let numerator = abs(A * point.x + B * point.y + C)
        let denominator = simd_length(Vec2D(A, B))
        return numerator / denominator
    }

    static func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        guard points.count >= 2 else {
            return VectorPath(elements: [])
        }
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))
        if points.count == 2 {
            elements.append(.line(to: VectorPoint(points[1])))
        } else {
            let curveSegments = fitBezierCurves(through: points)
            elements.append(contentsOf: curveSegments)
        }
        return VectorPath(elements: elements)
    }

    static func fitBezierCurves(through points: [CGPoint]) -> [PathElement] {
        var elements: [PathElement] = []
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let isFirstSegment = (i == 1)
            let isLastSegment = (i == points.count - 1)
            if isFirstSegment || isLastSegment {
                elements.append(.line(to: VectorPoint(p1)))
            } else {
                let tension: Double = 0.25
                let distance = p1.distance(to: p0)
                let prevTangent = i > 1 ? calculateTangent(p0: points[i - 2], p1: p0, p2: p1) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let nextTangent = i < points.count - 1 ? calculateTangent(p0: p0, p1: p1, p2: points[i + 1]) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let controlLength = distance * tension
                let control1 = CGPoint(
                    x: p0.x + prevTangent.x * controlLength,
                    y: p0.y + prevTangent.y * controlLength
                )
                let control2 = CGPoint(
                    x: p1.x - nextTangent.x * controlLength,
                    y: p1.y - nextTangent.y * controlLength
                )
                elements.append(.curve(
                    to: VectorPoint(p1),
                    control1: VectorPoint(control1),
                    control2: VectorPoint(control2)
                ))
            }
        }
        return elements
    }

    static func calculateTangent(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let v1 = Vec2D(p1.x - p0.x, p1.y - p0.y)
        let v2 = Vec2D(p2.x - p1.x, p2.y - p1.y)
        let avg = (v1 + v2) * 0.5
        let length = simd_length(avg)
        if length > 0 {
            let normalized = simd_normalize(avg)
            return CGPoint(x: normalized.x, y: normalized.y)
        } else {
            return CGPoint(x: 1, y: 0)
        }
    }

    static func removeCoincidentPoints(_ points: [CGPoint], passes: Int, tolerance: Double = 0.1) -> [CGPoint] {
        guard passes > 0 && points.count > 1 else { return points }
        var filtered = points
        for _ in 0..<min(passes, 3) {
            var result: [CGPoint] = []
            result.append(filtered[0])
            for i in 1..<filtered.count {
                let current = filtered[i]
                guard let previous = result.last else { continue }
                let distance = hypot(current.x - previous.x, current.y - previous.y)
                if distance >= tolerance {
                    result.append(current)
                }
            }
            filtered = result
            if filtered.count <= 2 { break }
        }
        return filtered
    }
}
