import Foundation
import CoreGraphics
import simd

struct GeometryUtils {

    static func constrainToAngle(from reference: CGPoint, to target: CGPoint, constraintAngles: [Double]) -> CGPoint {
        let delta = SIMD2<Double>(Double(target.x - reference.x), Double(target.y - reference.y))
        let distance = simd_length(delta)
        guard distance > 0.001 else { return target }
        let dx = delta.x
        let dy = delta.y
        let angle = atan2(dy, dx)

        var angleDegrees = angle * 180.0 / .pi
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        var closestAngle = constraintAngles[0]
        var minDifference = 360.0
        for constraintAngle in constraintAngles {
            let diff = abs(angleDegrees - constraintAngle)
            let wrappedDiff = min(diff, 360 - diff)
            if wrappedDiff < minDifference {
                minDifference = wrappedDiff
                closestAngle = constraintAngle
            }
        }
        let constrainedAngleRad = closestAngle * .pi / 180.0
        let constrainedX = reference.x + distance * cos(constrainedAngleRad)
        let constrainedY = reference.y + distance * sin(constrainedAngleRad)
        return CGPoint(x: constrainedX, y: constrainedY)
    }
}

extension CGRect {

    @inline(__always)
    var simd: SIMD4<Double> {
        SIMD4(Double(origin.x), Double(origin.y), Double(size.width), Double(size.height))
    }

    @inline(__always)
    init(simd: SIMD4<Double>) {
        self.init(x: CGFloat(simd.x), y: CGFloat(simd.y), width: CGFloat(simd.z), height: CGFloat(simd.w))
    }

    @inline(__always)
    func intersectsSIMD(_ other: CGRect) -> Bool {
        let a = self.simd
        let b = other.simd
        let aMin = SIMD2(a.x, a.y)
        let aMax = SIMD2(a.x + a.z, a.y + a.w)
        let bMin = SIMD2(b.x, b.y)
        let bMax = SIMD2(b.x + b.z, b.y + b.w)
        let overlap = (aMin .< bMax) .& (aMax .> bMin)
        return all(overlap)
    }
}

extension CGSize {

    @inline(__always)
    var simd: SIMD2<Double> {
        SIMD2(Double(width), Double(height))
    }

    @inline(__always)
    init(simd: SIMD2<Double>) {
        self.init(width: CGFloat(simd.x), height: CGFloat(simd.y))
    }

    @inline(__always)
    var areaSIMD: CGFloat {
        let s = self.simd
        return CGFloat(s.x * s.y)
    }

    @inline(__always)
    var aspectRatioSIMD: CGFloat {
        let s = self.simd
        return s.y > 0 ? CGFloat(s.x / s.y) : 0
    }
}

struct SIMDRectOps {

    @inline(__always)
    static func unionBounds(_ rects: [CGRect]) -> CGRect {
        guard !rects.isEmpty else { return .zero }
        guard rects.count > 1 else { return rects[0] }
        let first = rects[0].simd

        var minVec = SIMD2<Double>(first.x, first.y)
        var maxVec = SIMD2<Double>(first.x + first.z, first.y + first.w)
        for rect in rects.dropFirst() {
            let simd = rect.simd
            let rectMin = SIMD2<Double>(simd.x, simd.y)
            let rectMax = SIMD2<Double>(simd.x + simd.z, simd.y + simd.w)
            minVec = simd_min(minVec, rectMin)
            maxVec = simd_max(maxVec, rectMax)
        }
        return CGRect(
            x: CGFloat(minVec.x),
            y: CGFloat(minVec.y),
            width: CGFloat(maxVec.x - minVec.x),
            height: CGFloat(maxVec.y - minVec.y)
        )
    }

    @inline(__always)
    static func filterIntersecting(_ rects: [CGRect], viewport: CGRect) -> [CGRect] {
        rects.filter { $0.intersectsSIMD(viewport) }
    }
}
