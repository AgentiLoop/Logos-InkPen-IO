import SwiftUI
import simd

struct ProfessionalBezierMathematics {

    struct BezierPoint: Codable, Hashable {
        var point: VectorPoint
        var incomingHandle: VectorPoint?
        var outgoingHandle: VectorPoint?
        var pointType: AnchorPointType
        var handleConstraint: HandleConstraint

        init(point: VectorPoint,
             incomingHandle: VectorPoint? = nil,
             outgoingHandle: VectorPoint? = nil,
             pointType: AnchorPointType = .corner,
             handleConstraint: HandleConstraint = .independent) {
            self.point = point
            self.incomingHandle = incomingHandle
            self.outgoingHandle = outgoingHandle
            self.pointType = pointType
            self.handleConstraint = handleConstraint
        }

        static func smoothPoint(at location: VectorPoint, handleLength: Double, angle: Double) -> BezierPoint {
            let handleVector = SIMD2<Double>(cos(angle), sin(angle)) * handleLength
            return BezierPoint(
                point: location,
                incomingHandle: VectorPoint(simd: location.simdPoint - handleVector),
                outgoingHandle: VectorPoint(simd: location.simdPoint + handleVector),
                pointType: .smoothCurve,
                handleConstraint: .symmetric
            )
        }

        static func cornerPoint(at location: VectorPoint) -> BezierPoint {
            return BezierPoint(
                point: location,
                incomingHandle: nil,
                outgoingHandle: nil,
                pointType: .corner,
                handleConstraint: .independent
            )
        }
    }

    enum AnchorPointType: String, CaseIterable, Codable {
        case corner = "Corner"
        case smoothCurve = "Smooth Curve"
        case smoothCorner = "Smooth Corner"
        case cusp = "Cusp"
        case connector = "Connector"

        var description: String {
            switch self {
            case .corner:
                return "Corner point with sharp edges"
            case .smoothCurve:
                return "Smooth curve point with symmetric handles"
            case .smoothCorner:
                return "Smooth corner with different handle lengths"
            case .cusp:
                return "Cusp point with independent handle directions"
            case .connector:
                return "Intelligent connector point (FreeHand style)"
            }
        }

        var hasHandles: Bool {
            switch self {
            case .corner: return false
            case .smoothCurve, .smoothCorner, .cusp, .connector: return true
            }
        }
    }

    enum HandleConstraint: String, CaseIterable, Codable {
                case symmetric = "Symmetric"
case aligned = "Aligned"
case independent = "Independent"
        case automatic = "Automatic"

        var description: String {
            switch self {
            case .symmetric:
                return "Symmetric handles (equal length and opposite direction)"
            case .aligned:
                return "Aligned handles (opposite direction, different lengths)"
            case .independent:
                return "Independent handles (move separately)"
            case .automatic:
                return "Automatic handles (system optimized)"
            }
        }
    }

    static func deCasteljauEvaluation(points: [VectorPoint], t: Double) -> VectorPoint {
        guard !points.isEmpty else { return VectorPoint(0, 0) }
        guard points.count > 1 else { return points[0] }
        var currentPoints = points
        while currentPoints.count > 1 {
            var nextLevel: [VectorPoint] = []
            for i in 0..<(currentPoints.count - 1) {
                let p0 = currentPoints[i].simdPoint
                let p1 = currentPoints[i + 1].simdPoint
                let interpolated = simd_mix(p0, p1, SIMD2<Double>(repeating: t))
                nextLevel.append(VectorPoint(simd: interpolated))
            }
            currentPoints = nextLevel
        }
        return currentPoints[0]
    }

    static func bernsteinBasis(i: Int, n: Int, t: Double) -> Double {
        let binomialCoeff = binomialCoefficient(n: n, k: i)
        let tPower = pow(t, Double(i))
        let oneMinusTPower = pow(1.0 - t, Double(n - i))
        return Double(binomialCoeff) * tPower * oneMinusTPower
    }
    private static var binomialLookup: [[Int]] = []

    static func binomialCoefficient(n: Int, k: Int) -> Int {
        guard n >= 0 && k >= 0 && k <= n else { return 0 }
        while binomialLookup.count <= n {
            let currentN = binomialLookup.count

            var newRow: [Int] = []
            for i in 0...currentN {
                if i == 0 || i == currentN {
                    newRow.append(1)
                } else {
                    let value = binomialLookup[currentN - 1][i - 1] + binomialLookup[currentN - 1][i]
                    newRow.append(value)
                }
            }
            binomialLookup.append(newRow)
        }
        return binomialLookup[n][k]
    }

    static func evaluateCubicBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let u2 = u * u
        let u3 = u2 * u
        let t2 = t * t
        let t3 = t2 * t
        let result = u3 * p0.simdPoint +
                     3 * u2 * t * p1.simdPoint +
                     3 * u * t2 * p2.simdPoint +
                     t3 * p3.simdPoint
        return VectorPoint(simd: result)
    }

    static func evaluateQuadraticBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let u2 = u * u
        let t2 = t * t
        let result = u2 * p0.simdPoint +
                     2 * u * t * p1.simdPoint +
                     t2 * p2.simdPoint
        return VectorPoint(simd: result)
    }

    static func cubicBezierFirstDerivative(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let term1 = u * u * (p1.simdPoint - p0.simdPoint)
        let term2 = 2.0 * u * t * (p2.simdPoint - p1.simdPoint)
        let term3 = t * t * (p3.simdPoint - p2.simdPoint)
        let result = 3.0 * (term1 + term2 + term3)
        return VectorPoint(simd: result)
    }

    static func cubicBezierSecondDerivative(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let term1 = u * (p2.simdPoint - 2.0 * p1.simdPoint + p0.simdPoint)
        let term2 = t * (p3.simdPoint - 2.0 * p2.simdPoint + p1.simdPoint)
        let result = 6.0 * (term1 + term2)
        return VectorPoint(simd: result)
    }

    static func calculateCurvature(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> Double {
        let firstDeriv = cubicBezierFirstDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        let secondDeriv = cubicBezierSecondDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        let crossProduct = firstDeriv.x * secondDeriv.y - firstDeriv.y * secondDeriv.x
        let speedSquared = simd_length_squared(firstDeriv.simdPoint)
        let speed = sqrt(speedSquared)
        guard speed > 1e-10 else { return 0.0 }
        return abs(crossProduct) / (speedSquared * speed)
    }

    static func splitCubicBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> ([VectorPoint], [VectorPoint]) {
        let q1 = VectorPoint.lerp(p0, p1, t)
        let q2 = VectorPoint.lerp(p1, p2, t)
        let r1 = VectorPoint.lerp(q1, q2, t)
        let r2 = VectorPoint.lerp(p2, p3, t)
        let s1 = VectorPoint.lerp(r1, r2, t)
        let pointOnCurve = VectorPoint.lerp(s1, s1, t)
        let leftCurve = [p0, q1, r1, pointOnCurve]
        let rightCurve = [pointOnCurve, s1, r2, p3]
        return (leftCurve, rightCurve)
    }

    static func generateSmoothHandles(previousPoint: VectorPoint?, currentPoint: VectorPoint, nextPoint: VectorPoint?, tension: Double = 0.33) -> (VectorPoint?, VectorPoint?) {
        var incomingHandle: VectorPoint?
        var outgoingHandle: VectorPoint?
        if let prev = previousPoint, let next = nextPoint {
            let direction = next.simdPoint - prev.simdPoint
            let directionLength = simd_length(direction)
            guard directionLength > 1e-10 else { return (nil, nil) }
            let normalizedDirection = simd_normalize(direction)
            let prevDistance = simd_length(currentPoint.simdPoint - prev.simdPoint)
            let nextDistance = simd_length(next.simdPoint - currentPoint.simdPoint)
            let avgDistance = (prevDistance + nextDistance) / 2.0
            let baseTension = tension
            let distanceMultiplier = min(avgDistance / 50.0, 2.0)
            let dynamicTension = baseTension * (1.0 + distanceMultiplier * 0.5)
            let incomingLength = prevDistance * dynamicTension
            let outgoingLength = nextDistance * dynamicTension
            incomingHandle = VectorPoint(simd: currentPoint.simdPoint - normalizedDirection * incomingLength)
            outgoingHandle = VectorPoint(simd: currentPoint.simdPoint + normalizedDirection * outgoingLength)
        } else if let prev = previousPoint {
            let direction = currentPoint.simdPoint - prev.simdPoint
            let directionLength = simd_length(direction)
            if directionLength > 1e-10 {
                let distanceMultiplier = min(directionLength / 50.0, 2.0)
                let dynamicTension = tension * (1.0 + distanceMultiplier * 0.5)
                let handleLength = directionLength * dynamicTension
                let normalizedDirection = simd_normalize(direction)
                outgoingHandle = VectorPoint(simd: currentPoint.simdPoint + normalizedDirection * handleLength)
            }
        } else if let next = nextPoint {
            let direction = next.simdPoint - currentPoint.simdPoint
            let directionLength = simd_length(direction)
            if directionLength > 1e-10 {
                let distanceMultiplier = min(directionLength / 50.0, 2.0)
                let dynamicTension = tension * (1.0 + distanceMultiplier * 0.5)
                let handleLength = directionLength * dynamicTension
                let normalizedDirection = simd_normalize(direction)
                incomingHandle = VectorPoint(simd: currentPoint.simdPoint - normalizedDirection * handleLength)
            }
        }
        return (incomingHandle, outgoingHandle)
    }

    enum ContinuityType: String, CaseIterable, Codable {
        case c0 = "C0"
        case g1 = "G1"
        case c1 = "C1"
        case g2 = "G2"
        case c2 = "C2"
        case none = "None"
    }

    static func analyzeContinuity(curve1: [VectorPoint], curve2: [VectorPoint], tolerance: Double = 1e-10) -> ContinuityType {
        guard curve1.count == 4 && curve2.count == 4 else { return .none }
        let p2 = curve1[2], p3 = curve1[3]
        let q0 = curve2[0], q1 = curve2[1]
        let positionDiff = simd_length(p3.simdPoint - q0.simdPoint)
        guard positionDiff < tolerance else { return .none }
        let curve1EndTangent = p3.simdPoint - p2.simdPoint
        let curve2StartTangent = q1.simdPoint - q0.simdPoint
        let tangent1Length = simd_length(curve1EndTangent)
        let tangent2Length = simd_length(curve2StartTangent)
        guard tangent1Length > tolerance && tangent2Length > tolerance else { return .c0 }
        let normalizedTangent1 = simd_normalize(curve1EndTangent)
        let normalizedTangent2 = simd_normalize(curve2StartTangent)
        let tangentDiff = simd_length(normalizedTangent1 - normalizedTangent2)
        guard tangentDiff < tolerance else { return .c0 }
        let derivativeDiff = abs(tangent1Length - tangent2Length)
        if derivativeDiff < tolerance {
            return .c1
        } else {
            return .g1
        }
    }

    static func fitCubicBezierToPoints(points: [VectorPoint]) -> [VectorPoint]? {
        guard points.count >= 4 else { return nil }
        guard let p0 = points.first, let p3 = points.last else { return nil }
        let midIndex1 = points.count / 3
        let midIndex2 = (points.count * 2) / 3
        let p1 = points[min(midIndex1, points.count - 1)]
        let p2 = points[min(midIndex2, points.count - 1)]
        return [p0, p1, p2, p3]
    }

    static func calculateArcLength(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, subdivisions: Int = 10) -> Double {
        var totalLength: Double = 0.0

        let dt = 1.0 / Double(subdivisions)
        for i in 0..<subdivisions {
            let t1 = Double(i) * dt
            let t2 = Double(i + 1) * dt
            let point1 = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t1)
            let point2 = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t2)
            let segmentLength = simd_length(point2.simdPoint - point1.simdPoint)
            totalLength += segmentLength
        }
        return totalLength
    }
}

extension VectorPoint {

    static func lerp(_ a: VectorPoint, _ b: VectorPoint, _ t: Double) -> VectorPoint {
        let result = simd_mix(a.simdPoint, b.simdPoint, SIMD2<Double>(repeating: t))
        return VectorPoint(simd: result)
    }

    static func lerpBatch(_ startPoints: [VectorPoint], _ endPoints: [VectorPoint], _ t: Double) -> [VectorPoint] {
        guard startPoints.count == endPoints.count else { return [] }
        let startCGPoints = startPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let endCGPoints = endPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.lerpVectorsGPU(from: startCGPoints, to: endCGPoints, t: Float(t))
        switch results {
        case .success(let interpolatedVectors):
            return interpolatedVectors.map { VectorPoint($0) }
        case .failure(_):
            return zip(startPoints, endPoints).map { start, end in
                VectorPoint.lerp(start, end, t)
            }
        }
    }

    func distance(to other: VectorPoint) -> Double {
        return simd_length(self.simdPoint - other.simdPoint)
    }

    static func distancesBatch(from sourcePoints: [VectorPoint], to targetPoints: [VectorPoint]) -> [Double] {
        guard sourcePoints.count == targetPoints.count else { return [] }
        let sourceCGPoints = sourcePoints.map { CGPoint(x: $0.x, y: $0.y) }
        let targetCGPoints = targetPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.calculateDistancesGPU(from: sourceCGPoints, to: targetCGPoints)
        switch results {
        case .success(let distances):
            return distances.map { Double($0) }
        case .failure(_):
            return zip(sourcePoints, targetPoints).map { source, target in
                source.distance(to: target)
            }
        }
    }

    func angle(to other: VectorPoint) -> Double {
        return atan2(other.y - self.y, other.x - self.x)
    }

    var normalized: VectorPoint {
        let length = simd_length(simdPoint)
        guard length > 1e-10 else { return VectorPoint(0, 0) }
        return VectorPoint(simd: simd_normalize(simdPoint))
    }

    static func normalizeBatch(_ vectors: [VectorPoint]) -> [VectorPoint] {
        let cgVectors = vectors.map { CGPoint(x: $0.x, y: $0.y) }
        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.normalizeVectorsGPU(cgVectors)
        switch results {
        case .success(let normalizedVectors):
            return normalizedVectors.map { VectorPoint($0) }
        case .failure(_):
            return vectors.map { $0.normalized }
        }
    }
}

struct ProfessionalBezierFactory {

    static func createSmoothCurve(from startPoint: VectorPoint, to endPoint: VectorPoint, tension: Double = 0.33) -> [VectorPoint] {
        let direction = endPoint.simdPoint - startPoint.simdPoint
        let control1 = VectorPoint(simd: startPoint.simdPoint + direction * tension)
        let control2 = VectorPoint(simd: endPoint.simdPoint - direction * tension)
        return [startPoint, control1, control2, endPoint]
    }

    static func createCircularArc(center: VectorPoint, radius: Double, startAngle: Double, endAngle: Double) -> [VectorPoint] {
        let kappa = 0.5522847498307935
        let startVec = SIMD2<Double>(cos(startAngle), sin(startAngle)) * radius
        let startPoint = VectorPoint(simd: center.simdPoint + startVec)
        let endVec = SIMD2<Double>(cos(endAngle), sin(endAngle)) * radius
        let endPoint = VectorPoint(simd: center.simdPoint + endVec)
        let handleLength = radius * kappa
        let control1Vec = SIMD2<Double>(cos(startAngle + .pi / 2), sin(startAngle + .pi / 2)) * handleLength
        let control1 = VectorPoint(simd: startPoint.simdPoint + control1Vec)
        let control2Vec = SIMD2<Double>(cos(endAngle - .pi / 2), sin(endAngle - .pi / 2)) * handleLength
        let control2 = VectorPoint(simd: endPoint.simdPoint + control2Vec)
        return [startPoint, control1, control2, endPoint]
    }
}

extension ProfessionalBezierMathematics.ContinuityType {

    var priority: Int {
        switch self {
        case .none: return 0
        case .c0: return 1
        case .g1: return 2
        case .c1: return 3
        case .g2: return 4
        case .c2: return 5
        }
    }
}
