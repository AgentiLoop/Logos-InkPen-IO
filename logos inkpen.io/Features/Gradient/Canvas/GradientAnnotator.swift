import SwiftUI

/// What a Gradient tool press landed on in the on-canvas annotator (Illustrator's gradient bar).
enum GradientAnnotatorMode: Equatable {
    case start
    case end
    case bar
    case stop(Int)
}

/// Canvas-space bar of a gradient: linear gradients run from start to end, radial gradients from the centre out to the radius.
/// Only gradients in object-bounding-box units have a bar; others return nil.
struct GradientAnnotatorGeometry {
    let p0: CGPoint
    let p1: CGPoint

    init?(gradient: VectorGradient, bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let size = max(bounds.width, bounds.height)
        switch gradient {
        case .linear(let linear):
            guard linear.units == .objectBoundingBox else { return nil }
            let scale = CGFloat(linear.scaleX)
            let center = CGPoint(x: bounds.minX + bounds.width * linear.originPoint.x * scale,
                                 y: bounds.minY + bounds.height * linear.originPoint.y * scale)
            let angle = CGFloat(linear.storedAngle * .pi / 180.0)
            let length = hypot(linear.endPoint.x - linear.startPoint.x, linear.endPoint.y - linear.startPoint.y) * scale * size
            let half = CGPoint(x: cos(angle) * length / 2, y: sin(angle) * length / 2)
            p0 = CGPoint(x: center.x - half.x, y: center.y - half.y)
            p1 = CGPoint(x: center.x + half.x, y: center.y + half.y)
        case .radial(let radial):
            guard radial.units == .objectBoundingBox else { return nil }
            let center = CGPoint(x: bounds.minX + bounds.width * radial.originPoint.x,
                                 y: bounds.minY + bounds.height * radial.originPoint.y)
            let angle = CGFloat(radial.angle * .pi / 180.0)
            let length = CGFloat(radial.radius * radial.scaleX) * size
            p0 = center
            p1 = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
        }
    }

    func point(at t: Double) -> CGPoint {
        CGPoint(x: p0.x + (p1.x - p0.x) * CGFloat(t), y: p0.y + (p1.y - p0.y) * CGFloat(t))
    }

    /// Position of `p` along the bar (0 at p0, 1 at p1; not clamped).
    func parameter(of p: CGPoint) -> Double {
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0.000001 else { return 0 }
        return Double(((p.x - p0.x) * dx + (p.y - p0.y) * dy) / lengthSquared)
    }

    func distanceToBar(_ p: CGPoint) -> CGFloat {
        let t = min(max(parameter(of: p), 0), 1)
        let closest = point(at: t)
        return hypot(p.x - closest.x, p.y - closest.y)
    }

    /// Which part of the annotator is under `p`. Stops win over the end points, which win over the bar itself.
    func hitTest(_ p: CGPoint, stops: [GradientStop], zoom: CGFloat) -> GradientAnnotatorMode? {
        let zoom = max(zoom, 0.0001)
        let tolerance = 8.0 / zoom
        for (index, stop) in stops.enumerated() where stop.position > 0.001 && stop.position < 0.999 {
            let c = point(at: stop.position)
            if hypot(p.x - c.x, p.y - c.y) <= tolerance { return .stop(index) }
        }
        if hypot(p.x - p0.x, p.y - p0.y) <= tolerance { return .start }
        if hypot(p.x - p1.x, p.y - p1.y) <= tolerance { return .end }
        if distanceToBar(p) <= 5.0 / zoom { return .bar }
        return nil
    }

    /// The gradient re-expressed so its bar runs from `newP0` to `newP1`.
    static func gradient(_ gradient: VectorGradient, bounds: CGRect, p0 newP0: CGPoint, p1 newP1: CGPoint) -> VectorGradient {
        let size = max(bounds.width, bounds.height)
        let dx = newP1.x - newP0.x
        let dy = newP1.y - newP0.y
        let length = hypot(dx, dy)
        guard bounds.width > 0, bounds.height > 0, length > 0.5 else { return gradient }
        let angle = atan2(dy, dx)
        switch gradient {
        case .linear(var linear):
            let mid = CGPoint(x: (newP0.x + newP1.x) / 2, y: (newP0.y + newP1.y) / 2)
            let half = Double(length / size) / 2
            linear.units = .objectBoundingBox
            linear.originPoint = CGPoint(x: (mid.x - bounds.minX) / bounds.width, y: (mid.y - bounds.minY) / bounds.height)
            linear.scale = 1.0
            linear.scaleX = 1.0
            linear.scaleY = 1.0
            linear.storedAngle = Double(angle) * 180.0 / .pi
            linear.startPoint = CGPoint(x: linear.originPoint.x - cos(angle) * half, y: linear.originPoint.y - sin(angle) * half)
            linear.endPoint = CGPoint(x: linear.originPoint.x + cos(angle) * half, y: linear.originPoint.y + sin(angle) * half)
            return .linear(linear)
        case .radial(var radial):
            guard radial.scaleX > 0.000001 else { return gradient }
            radial.units = .objectBoundingBox
            radial.originPoint = CGPoint(x: (newP0.x - bounds.minX) / bounds.width, y: (newP0.y - bounds.minY) / bounds.height)
            radial.centerPoint = radial.originPoint
            radial.radius = Double(length / size) / radial.scaleX
            radial.angle = Double(angle) * 180.0 / .pi
            return .radial(radial)
        }
    }

    static func gradient(_ gradient: VectorGradient, withStops stops: [GradientStop]) -> VectorGradient {
        let sorted = stops.enumerated().sorted { lhs, rhs in
            lhs.element.position == rhs.element.position ? lhs.offset < rhs.offset : lhs.element.position < rhs.element.position
        }.map { $0.element }
        switch gradient {
        case .linear(var linear):
            linear.stops = sorted
            return .linear(linear)
        case .radial(var radial):
            radial.stops = sorted
            return .radial(radial)
        }
    }

    /// Colour and opacity the gradient has at `t`, used for a stop added by clicking the bar.
    static func interpolatedStop(in stops: [GradientStop], at t: Double) -> GradientStop {
        let sorted = stops.sorted { $0.position < $1.position }
        guard let first = sorted.first, let last = sorted.last else { return GradientStop(position: t, color: .white) }
        if t <= first.position { return GradientStop(position: t, color: first.color, opacity: first.opacity) }
        if t >= last.position { return GradientStop(position: t, color: last.color, opacity: last.opacity) }
        for index in 1..<sorted.count where t <= sorted[index].position {
            let lower = sorted[index - 1]
            let upper = sorted[index]
            let span = upper.position - lower.position
            let fraction = span > 0.000001 ? (t - lower.position) / span : 0
            let opacity = lower.opacity + (upper.opacity - lower.opacity) * fraction
            guard let a = lower.color.cgColor.components, let b = upper.color.cgColor.components, a.count == 4, b.count == 4 else {
                return GradientStop(position: t, color: fraction < 0.5 ? lower.color : upper.color, opacity: opacity)
            }
            let f = CGFloat(fraction)
            let color = RGBColor(red: Double(a[0] + (b[0] - a[0]) * f),
                                 green: Double(a[1] + (b[1] - a[1]) * f),
                                 blue: Double(a[2] + (b[2] - a[2]) * f),
                                 alpha: Double(a[3] + (b[3] - a[3]) * f))
            return GradientStop(position: t, color: .rgb(color), opacity: opacity)
        }
        return GradientStop(position: t, color: last.color, opacity: last.opacity)
    }

    /// Draws the bar with a square marker per interior stop and a round marker at each end.
    func draw(in context: inout GraphicsContext, stops: [GradientStop], zoom: CGFloat) {
        let unit = 1.0 / max(zoom, 0.0001)
        var bar = Path()
        bar.move(to: p0)
        bar.addLine(to: p1)
        context.stroke(bar, with: .color(.white), lineWidth: 4 * unit)
        context.stroke(bar, with: .color(.black), lineWidth: 1.5 * unit)
        let sorted = stops.sorted { $0.position < $1.position }
        func marker(_ center: CGPoint, radius: CGFloat, round: Bool, stop: GradientStop?) {
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let path = round ? Path(ellipseIn: rect) : Path(rect)
            let fill: Color = stop.map { $0.color.color.opacity($0.opacity) } ?? .white
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(.white), lineWidth: 3 * unit)
            context.stroke(path, with: .color(.black), lineWidth: 1 * unit)
        }
        marker(p0, radius: 6 * unit, round: true, stop: sorted.first)
        marker(p1, radius: 6 * unit, round: true, stop: sorted.last)
        for stop in sorted where stop.position > 0.001 && stop.position < 0.999 {
            marker(point(at: stop.position), radius: 5 * unit, round: false, stop: stop)
        }
    }
}
