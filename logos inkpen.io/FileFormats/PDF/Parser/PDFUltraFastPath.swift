import Foundation
import CoreGraphics
import simd
import Accelerate

struct PDFUltraFastPath {

    static func simplifyPath(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        return douglasPeuckerSIMD(points: points, epsilon: Float(tolerance))
    }

    private static func douglasPeuckerSIMD(points: [CGPoint], epsilon: Float) -> [CGPoint] {
        guard points.count > 2 else { return points }
        guard let firstPoint = points.first, let lastPoint = points.last else { return points }
        let distances = calculatePerpendicularDistancesSIMD(
            points: points,
            lineStart: firstPoint,
            lineEnd: lastPoint
        )
        var maxDistance: Float = 0
        var maxIndex = 0
        vDSP_maxvi(distances, 1, &maxDistance, &maxIndex, vDSP_Length(distances.count))
        if maxDistance > epsilon {
            let leftPart = douglasPeuckerSIMD(
                points: Array(points[0...maxIndex]),
                epsilon: epsilon
            )
            let rightPart = douglasPeuckerSIMD(
                points: Array(points[maxIndex..<points.count]),
                epsilon: epsilon
            )
            return leftPart + rightPart.dropFirst()
        } else {
            return [firstPoint, lastPoint]
        }
    }

    private static func calculatePerpendicularDistancesSIMD(
        points: [CGPoint],
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> [Float] {
        let count = points.count

        var distances = [Float](repeating: 0, count: count)

        let dx = Float(lineEnd.x - lineStart.x)
        let dy = Float(lineEnd.y - lineStart.y)
        let lineLengthSquared = dx * dx + dy * dy
        guard lineLengthSquared > 0 else {
            return distances
        }
        var xCoords = points.map { Float($0.x) }
        var yCoords = points.map { Float($0.y) }

        let startX = Float(lineStart.x)
        let startY = Float(lineStart.y)

        var negStartX = -startX
        var negStartY = -startY
        vDSP_vsadd(xCoords, 1, &negStartX, &xCoords, 1, vDSP_Length(count))
        vDSP_vsadd(yCoords, 1, &negStartY, &yCoords, 1, vDSP_Length(count))
        for i in 0..<count {
            let cross = abs(xCoords[i] * dy - yCoords[i] * dx)
            distances[i] = cross / sqrt(lineLengthSquared)
        }
        return distances
    }

    static func calculateTightBounds(path: CGPath) -> CGRect {
        var points = [CGPoint]()
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break

            @unknown default:
                break
            }
        }
        return PDFAdvancedSIMD.calculatePathBounds(points: points)
    }

    static func parallelTessellatePath(path: CGPath, flatness: CGFloat) -> [CGPoint] {
        var segments: [(start: CGPoint, cp1: CGPoint?, cp2: CGPoint?, end: CGPoint)] = []
        var currentPoint = CGPoint.zero
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                currentPoint = element.pointee.points[0]
            case .addLineToPoint:
                let end = element.pointee.points[0]
                segments.append((start: currentPoint, cp1: nil, cp2: nil, end: end))
                currentPoint = end
            case .addQuadCurveToPoint:
                let cp = element.pointee.points[0]
                let end = element.pointee.points[1]
                segments.append((start: currentPoint, cp1: cp, cp2: nil, end: end))
                currentPoint = end
            case .addCurveToPoint:
                let cp1 = element.pointee.points[0]
                let cp2 = element.pointee.points[1]
                let end = element.pointee.points[2]
                segments.append((start: currentPoint, cp1: cp1, cp2: cp2, end: end))
                currentPoint = end
            case .closeSubpath:
                break

            @unknown default:
                break
            }
        }
        guard !segments.isEmpty else { return [] }
        let segmentResults = segments.map { segment -> [CGPoint] in
            if let cp1 = segment.cp1, let cp2 = segment.cp2 {
                return tessellateCubicSIMD(
                    start: segment.start,
                    cp1: cp1,
                    cp2: cp2,
                    end: segment.end,
                    flatness: Float(flatness)
                )
            } else if let cp = segment.cp1 {
                return tessellateQuadraticSIMD(
                    start: segment.start,
                    cp: cp,
                    end: segment.end,
                    flatness: Float(flatness)
                )
            } else {
                return [segment.start, segment.end]
            }
        }
        return segmentResults.flatMap { $0 }
    }

    private static func tessellateCubicSIMD(
        start: CGPoint,
        cp1: CGPoint,
        cp2: CGPoint,
        end: CGPoint,
        flatness: Float
    ) -> [CGPoint] {
        let curveFlatness = PDFCurveOptimizer.calculateCurveFlatness(
            start: start,
            cp1: cp1,
            cp2: cp2,
            end: end
        )
        if curveFlatness <= CGFloat(flatness) {
            return [start, end]
        }
        let p0 = simd_float2(Float(start.x), Float(start.y))
        let p1 = simd_float2(Float(cp1.x), Float(cp1.y))
        let p2 = simd_float2(Float(cp2.x), Float(cp2.y))
        let p3 = simd_float2(Float(end.x), Float(end.y))
        let p01 = (p0 + p1) * 0.5
        let p12 = (p1 + p2) * 0.5
        let p23 = (p2 + p3) * 0.5
        let p012 = (p01 + p12) * 0.5
        let p123 = (p12 + p23) * 0.5
        let p0123 = (p012 + p123) * 0.5
        let mid = CGPoint(x: CGFloat(p0123.x), y: CGFloat(p0123.y))
        let newCP1Left = CGPoint(x: CGFloat(p01.x), y: CGFloat(p01.y))
        let newCP2Left = CGPoint(x: CGFloat(p012.x), y: CGFloat(p012.y))
        let newCP1Right = CGPoint(x: CGFloat(p123.x), y: CGFloat(p123.y))
        let newCP2Right = CGPoint(x: CGFloat(p23.x), y: CGFloat(p23.y))
        let leftPoints = tessellateCubicSIMD(
            start: start,
            cp1: newCP1Left,
            cp2: newCP2Left,
            end: mid,
            flatness: flatness
        )
        let rightPoints = tessellateCubicSIMD(
            start: mid,
            cp1: newCP1Right,
            cp2: newCP2Right,
            end: end,
            flatness: flatness
        )
        return leftPoints + rightPoints.dropFirst()
    }

    private static func tessellateQuadraticSIMD(
        start: CGPoint,
        cp: CGPoint,
        end: CGPoint,
        flatness: Float
    ) -> [CGPoint] {
        if PDFCurveOptimizer.arePointsCollinear(start, cp, end, tolerance: CGFloat(flatness)) {
            return [start, end]
        }
        let p0 = simd_float2(Float(start.x), Float(start.y))
        let p1 = simd_float2(Float(cp.x), Float(cp.y))
        let p2 = simd_float2(Float(end.x), Float(end.y))
        let p01 = (p0 + p1) * 0.5
        let p12 = (p1 + p2) * 0.5
        let p012 = (p01 + p12) * 0.5
        let mid = CGPoint(x: CGFloat(p012.x), y: CGFloat(p012.y))
        let newCPLeft = CGPoint(x: CGFloat(p01.x), y: CGFloat(p01.y))
        let newCPRight = CGPoint(x: CGFloat(p12.x), y: CGFloat(p12.y))
        let leftPoints = tessellateQuadraticSIMD(
            start: start,
            cp: newCPLeft,
            end: mid,
            flatness: flatness
        )
        let rightPoints = tessellateQuadraticSIMD(
            start: mid,
            cp: newCPRight,
            end: end,
            flatness: flatness
        )
        return leftPoints + rightPoints.dropFirst()
    }

    static func transformPath(_ path: CGPath, by transform: CGAffineTransform) -> CGPath {
        var points = [CGPoint]()
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break

            @unknown default:
                break
            }
        }
        let transformedPoints = PDFAdvancedSIMD.batchApplyTransform(transform, to: points)
        let newPath = CGMutablePath()

        var pointIndex = 0
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                newPath.move(to: transformedPoints[pointIndex])
                pointIndex += 1
            case .addLineToPoint:
                newPath.addLine(to: transformedPoints[pointIndex])
                pointIndex += 1
            case .addQuadCurveToPoint:
                newPath.addQuadCurve(
                    to: transformedPoints[pointIndex + 1],
                    control: transformedPoints[pointIndex]
                )
                pointIndex += 2
            case .addCurveToPoint:
                newPath.addCurve(
                    to: transformedPoints[pointIndex + 2],
                    control1: transformedPoints[pointIndex],
                    control2: transformedPoints[pointIndex + 1]
                )
                pointIndex += 3
            case .closeSubpath:
                newPath.closeSubpath()

            @unknown default:
                break
            }
        }
        return newPath
    }
}
