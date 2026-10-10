import CoreGraphics

/// Where the Scissors tool cuts a path: on an anchor, or on a segment near a point (both in the path's own coordinate space).
enum PathCutLocation {
    case anchor(elementIndex: Int)
    case segment(elementIndex: Int, near: CGPoint)
}

private struct CutSegment {
    var elementIndex: Int
    var from: CGPoint
    var c1: CGPoint?
    var c2: CGPoint?
    var to: CGPoint

    var isCurve: Bool { c1 != nil && c2 != nil }

    func point(at t: CGFloat) -> CGPoint {
        guard let c1, let c2 else {
            return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
        let u = 1 - t
        return CGPoint(
            x: u * u * u * from.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * to.x,
            y: u * u * u * from.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * to.y
        )
    }

    func split(at t: CGFloat) -> (CutSegment, CutSegment) {
        let mid = point(at: t)
        guard let c1, let c2 else {
            return (CutSegment(elementIndex: elementIndex, from: from, c1: nil, c2: nil, to: mid),
                    CutSegment(elementIndex: elementIndex, from: mid, c1: nil, c2: nil, to: to))
        }
        func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        let p01 = lerp(from, c1), p12 = lerp(c1, c2), p23 = lerp(c2, to)
        let p012 = lerp(p01, p12), p123 = lerp(p12, p23)
        return (CutSegment(elementIndex: elementIndex, from: from, c1: p01, c2: p012, to: mid),
                CutSegment(elementIndex: elementIndex, from: mid, c1: p123, c2: p23, to: to))
    }

    func nearestParameter(to target: CGPoint) -> CGFloat {
        guard isCurve else {
            let dx = to.x - from.x, dy = to.y - from.y
            let lenSq = dx * dx + dy * dy
            if lenSq == 0 { return 0 }
            return min(1, max(0, ((target.x - from.x) * dx + (target.y - from.y) * dy) / lenSq))
        }
        func dist2(_ t: CGFloat) -> CGFloat {
            let p = point(at: t)
            return (p.x - target.x) * (p.x - target.x) + (p.y - target.y) * (p.y - target.y)
        }
        var best: CGFloat = 0
        var bestD = CGFloat.infinity
        for i in 0...200 {
            let t = CGFloat(i) / 200
            let d = dist2(t)
            if d < bestD { bestD = d; best = t }
        }
        var lo = max(0, best - 1.0 / 200), hi = min(1, best + 1.0 / 200)
        for _ in 0..<20 {
            let a = lo + (hi - lo) / 3, b = hi - (hi - lo) / 3
            if dist2(a) < dist2(b) { hi = b } else { lo = a }
        }
        return (lo + hi) / 2
    }

    var element: PathElement {
        if let c1, let c2 {
            return .curve(to: VectorPoint(to), control1: VectorPoint(c1), control2: VectorPoint(c2))
        }
        return .line(to: VectorPoint(to))
    }
}

/// Illustrator Scissors: cuts a single-subpath path at an anchor or on a segment.
/// An open path yields two open paths; a closed path yields one open path that starts and ends at the cut.
/// Returns nil when the cut would not split anything (end anchor of an open path) or the path isn't a plain single subpath.
func cuttingPath(_ elements: [PathElement], at location: PathCutLocation) -> [[PathElement]]? {
    guard case .move(let startPoint)? = elements.first else { return nil }
    let start = startPoint.cgPoint
    var segments: [CutSegment] = []
    var current = start
    var isClosed = false
    for (index, element) in elements.enumerated().dropFirst() {
        switch element {
        case .move:
            return nil
        case .line(let to):
            segments.append(CutSegment(elementIndex: index, from: current, c1: nil, c2: nil, to: to.cgPoint))
            current = to.cgPoint
        case .curve(let to, let c1, let c2):
            segments.append(CutSegment(elementIndex: index, from: current, c1: c1.cgPoint, c2: c2.cgPoint, to: to.cgPoint))
            current = to.cgPoint
        case .quadCurve(let to, let control):
            let q = control.cgPoint
            let c1 = CGPoint(x: current.x + 2.0 / 3.0 * (q.x - current.x), y: current.y + 2.0 / 3.0 * (q.y - current.y))
            let c2 = CGPoint(x: to.x + 2.0 / 3.0 * (q.x - to.x), y: to.y + 2.0 / 3.0 * (q.y - to.y))
            segments.append(CutSegment(elementIndex: index, from: current, c1: c1, c2: c2, to: to.cgPoint))
            current = to.cgPoint
        case .close:
            isClosed = true
            if hypot(current.x - start.x, current.y - start.y) > 0.01 {
                segments.append(CutSegment(elementIndex: index, from: current, c1: nil, c2: nil, to: start))
                current = start
            }
        }
    }
    guard !segments.isEmpty else { return nil }

    // Resolve the cut to an anchor index (anchor k sits at the start of segment k; the end of the last segment is anchor n).
    let anchorIndex: Int
    switch location {
    case .anchor(let elementIndex):
        if elementIndex == 0 {
            anchorIndex = 0
        } else if let j = segments.firstIndex(where: { $0.elementIndex == elementIndex }) {
            anchorIndex = j + 1
        } else {
            return nil
        }
    case .segment(let elementIndex, let near):
        guard let j = segments.firstIndex(where: { $0.elementIndex == elementIndex }) else { return nil }
        let t = segments[j].nearestParameter(to: near)
        if t < 0.001 {
            anchorIndex = j
        } else if t > 0.999 {
            anchorIndex = j + 1
        } else {
            let (a, b) = segments[j].split(at: t)
            segments.replaceSubrange(j...j, with: [a, b])
            anchorIndex = j + 1
        }
    }

    func build(_ segs: [CutSegment]) -> [PathElement]? {
        guard let first = segs.first else { return nil }
        return [.move(to: VectorPoint(first.from))] + segs.map { $0.element }
    }

    let n = segments.count
    if isClosed {
        let k = anchorIndex % n
        let rotated = Array(segments[k...]) + Array(segments[..<k])
        guard let path = build(rotated) else { return nil }
        return [path]
    }
    guard anchorIndex > 0, anchorIndex < n,
          let head = build(Array(segments[..<anchorIndex])),
          let tail = build(Array(segments[anchorIndex...])) else { return nil }
    return [head, tail]
}

/// Illustrator Knife: splits a filled shape along a freehand knife path (all coordinates in the shape's own space).
/// The knife is extended past both ends and closed into a big region on its left; the shape is split into the part
/// inside that region and the part outside it, so the cut leaves no gap. Returns nil when the knife doesn't split the shape.
func knifeCutPieces(shapePath: CGPath, fillRule: CGPathFillRule, knife: [CGPoint]) -> [CGPath]? {
    var points: [CGPoint] = []
    for p in knife where points.last.map({ hypot($0.x - p.x, $0.y - p.y) > 0.001 }) ?? true {
        points.append(p)
    }
    guard points.count >= 2, !shapePath.isEmpty else { return nil }

    func direction(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let length = hypot(b.x - a.x, b.y - a.y)
        return CGPoint(x: (b.x - a.x) / length, y: (b.y - a.y) / length)
    }
    // Use points a little way in from the ends so tiny hand jitter doesn't swing the extension.
    let knifeBox = points.reduce(CGRect.null) { $0.union(CGRect(x: $1.x, y: $1.y, width: 0, height: 0)) }
    let box = shapePath.boundingBoxOfPath.union(knifeBox)
    let reach = hypot(box.width, box.height) * 2 + 10
    let sampleDistance = max(0.001, min(reach * 0.01, hypot(knifeBox.width, knifeBox.height) * 0.25))
    var startRef = points[1]
    for p in points.dropFirst() where hypot(p.x - points[0].x, p.y - points[0].y) >= sampleDistance {
        startRef = p
        break
    }
    var endRef = points[points.count - 2]
    for p in points.reversed().dropFirst() where hypot(p.x - points[points.count - 1].x, p.y - points[points.count - 1].y) >= sampleDistance {
        endRef = p
        break
    }
    let startDir = direction(from: startRef, to: points[0])   // pointing backwards out of the start
    let endDir = direction(from: endRef, to: points[points.count - 1])  // pointing forwards out of the end
    guard startDir.x.isFinite, endDir.x.isFinite else { return nil }

    let startExt = CGPoint(x: points[0].x + startDir.x * reach, y: points[0].y + startDir.y * reach)
    let endExt = CGPoint(x: points[points.count - 1].x + endDir.x * reach, y: points[points.count - 1].y + endDir.y * reach)
    // Left of the travel direction (y-down screen space): rotate (dx, dy) to (dy, -dx).
    let travelStart = CGPoint(x: -startDir.x, y: -startDir.y)
    let leftStart = CGPoint(x: travelStart.y, y: -travelStart.x)
    let leftEnd = CGPoint(x: endDir.y, y: -endDir.x)

    let region = CGMutablePath()
    region.move(to: startExt)
    for p in points { region.addLine(to: p) }
    region.addLine(to: endExt)
    region.addLine(to: CGPoint(x: endExt.x + leftEnd.x * reach * 2, y: endExt.y + leftEnd.y * reach * 2))
    region.addLine(to: CGPoint(x: startExt.x + leftStart.x * reach * 2, y: startExt.y + leftStart.y * reach * 2))
    region.closeSubpath()

    let inside = shapePath.intersection(region, using: fillRule)
    let outside = shapePath.subtracting(region, using: fillRule)
    guard !inside.isEmpty, !outside.isEmpty else { return nil }
    let pieces = inside.componentsSeparated(using: fillRule) + outside.componentsSeparated(using: fillRule)
    return pieces.count >= 2 ? pieces : nil
}
