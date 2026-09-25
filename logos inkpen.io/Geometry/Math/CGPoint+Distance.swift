import CoreGraphics
import simd

extension CGPoint {

    var simd: SIMD2<Double> {
        SIMD2(Double(x), Double(y))
    }

    init(_ simd: SIMD2<Double>) {
        self.init(x: CGFloat(simd.x), y: CGFloat(simd.y))
    }

    func adding(_ other: CGPoint) -> CGPoint {
        CGPoint(simd + other.simd)
    }

    func subtracting(_ other: CGPoint) -> CGPoint {
        CGPoint(simd - other.simd)
    }

    func scaled(by factor: CGFloat) -> CGPoint {
        CGPoint(simd * Double(factor))
    }

    func negated() -> CGPoint {
        CGPoint(-simd)
    }

    func distance(to other: CGPoint) -> CGFloat {
        CGFloat(simd_length(simd - other.simd))
    }

    func distanceSquared(to other: CGPoint) -> CGFloat {
        CGFloat(simd_length_squared(simd - other.simd))
    }
}
