import SwiftUI

/// Keeps a fill gradient attached to its object while the Rotate / Scale / Reflect / Shear tools transform it (Illustrator transforms gradients with the object).
/// Gradients are stored relative to the path's bounding box, so the old gradient is turned into canvas geometry, transformed, and expressed again against the new bounding box.
extension DrawingCanvas {

    /// - Parameters:
    ///   - old: shape before the transform (path in its own local space, `old.transform` not yet baked in).
    ///   - new: shape after the transform, with the transformed path already baked in.
    ///   - combined: the matrix that maps `old`'s local path coordinates to `new`'s path coordinates.
    internal func shapeWithTransformedFillGradient(old: VectorShape, new: VectorShape, combined: CGAffineTransform) -> VectorShape {
        guard let fill = old.fillStyle, case .gradient(let gradient) = fill.color else { return new }
        let oldBounds = old.path.cgPath.boundingBoxOfPath
        let newBounds = new.path.cgPath.boundingBoxOfPath
        guard oldBounds.width > 0, oldBounds.height > 0, newBounds.width > 0, newBounds.height > 0 else { return new }
        var result = new
        guard var newFill = new.fillStyle else { return new }
        switch gradient {
        case .linear(let linear):
            newFill.color = .gradient(.linear(transformedLinear(linear, oldBounds: oldBounds, newBounds: newBounds, combined: combined)))
        case .radial(let radial):
            newFill.color = .gradient(.radial(transformedRadial(radial, oldBounds: oldBounds, newBounds: newBounds, combined: combined)))
        }
        result.fillStyle = newFill
        return result
    }

    private func transformedLinear(_ linear: LinearGradient, oldBounds: CGRect, newBounds: CGRect, combined: CGAffineTransform) -> LinearGradient {
        var out = linear
        if linear.units == .userSpaceOnUse {
            out.startPoint = linear.startPoint.applying(combined)
            out.endPoint = linear.endPoint.applying(combined)
            out.storedAngle = atan2(out.endPoint.y - out.startPoint.y, out.endPoint.x - out.startPoint.x) * 180.0 / .pi
            return out
        }
        let oldScale = CGFloat(linear.scaleX)
        let oldMax = max(oldBounds.width, oldBounds.height)
        let center = CGPoint(x: oldBounds.minX + oldBounds.width * linear.originPoint.x * oldScale,
                             y: oldBounds.minY + oldBounds.height * linear.originPoint.y * oldScale)
        let angle = CGFloat(linear.storedAngle * .pi / 180.0)
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let deltaLength = hypot(linear.endPoint.x - linear.startPoint.x, linear.endPoint.y - linear.startPoint.y)
        let length = deltaLength * oldScale * oldMax

        let newCenter = center.applying(combined)
        let mapped = CGPoint(x: combined.a * direction.x + combined.c * direction.y,
                             y: combined.b * direction.x + combined.d * direction.y)
        let mappedLength = hypot(mapped.x, mapped.y)
        guard mappedLength > 0.000001, oldScale > 0 else { return out }
        let newAngle = atan2(mapped.y, mapped.x)
        let newLength = length * mappedLength
        let newMax = max(newBounds.width, newBounds.height)
        out.originPoint = CGPoint(x: (newCenter.x - newBounds.minX) / newBounds.width / oldScale,
                                  y: (newCenter.y - newBounds.minY) / newBounds.height / oldScale)
        out.storedAngle = Double(newAngle) * 180.0 / .pi
        let half = Double(newLength / (oldScale * newMax)) / 2
        out.startPoint = CGPoint(x: out.originPoint.x - cos(newAngle) * half, y: out.originPoint.y - sin(newAngle) * half)
        out.endPoint = CGPoint(x: out.originPoint.x + cos(newAngle) * half, y: out.originPoint.y + sin(newAngle) * half)
        return out
    }

    private func transformedRadial(_ radial: RadialGradient, oldBounds: CGRect, newBounds: CGRect, combined: CGAffineTransform) -> RadialGradient {
        var out = radial
        if radial.units == .userSpaceOnUse {
            let areaScale = sqrt(abs(Double(combined.a * combined.d - combined.b * combined.c)))
            out.centerPoint = radial.centerPoint.applying(combined)
            out.focalPoint = radial.focalPoint?.applying(combined)
            out.radius = radial.radius * areaScale
            return out
        }
        let oldMax = max(oldBounds.width, oldBounds.height)
        let center = CGPoint(x: oldBounds.minX + oldBounds.width * radial.originPoint.x,
                             y: oldBounds.minY + oldBounds.height * radial.originPoint.y)
        let newCenter = center.applying(combined)

        // Linear map of the gradient's unit circle: rotate, scale by (scaleX, scaleY) * radius, then apply the object transform.
        let phi = radial.angle * .pi / 180.0
        let rx = radial.radius * Double(oldMax) * radial.scaleX
        let ry = radial.radius * Double(oldMax) * radial.scaleY
        let m11 = Double(combined.a) * cos(phi) * rx + Double(combined.c) * sin(phi) * rx
        let m21 = Double(combined.b) * cos(phi) * rx + Double(combined.d) * sin(phi) * rx
        let m12 = -Double(combined.a) * sin(phi) * ry + Double(combined.c) * cos(phi) * ry
        let m22 = -Double(combined.b) * sin(phi) * ry + Double(combined.d) * cos(phi) * ry
        // 2x2 singular value decomposition: M = Rot(outAngle) * diag(s1, s2) * Rot(inAngle).
        let e = (m11 + m22) / 2
        let f = (m11 - m22) / 2
        let g = (m21 + m12) / 2
        let h = (m21 - m12) / 2
        let q = hypot(e, h)
        let r = hypot(f, g)
        let major = q + r
        let minor = abs(q - r)
        guard major > 0.000001 else { return out }
        let a1 = atan2(g, f)
        let a2 = atan2(h, e)
        let outAngle = (a2 + a1) / 2

        let newMax = Double(max(newBounds.width, newBounds.height))
        out.originPoint = CGPoint(x: (newCenter.x - newBounds.minX) / newBounds.width,
                                  y: (newCenter.y - newBounds.minY) / newBounds.height)
        out.centerPoint = out.originPoint
        out.angle = outAngle * 180.0 / .pi
        out.radius = major / newMax
        out.scaleX = 1.0
        out.scaleY = max(minor / major, 0.0001)
        out.scale = 1.0
        return out
    }
}
