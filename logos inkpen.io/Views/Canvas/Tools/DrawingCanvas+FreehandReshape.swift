import SwiftUI

/// One path segment as a cubic (lines keep `isLine` so they are written back as lines).
struct ReshapeSegment {
    var p0: CGPoint
    var c1: CGPoint
    var c2: CGPoint
    var p3: CGPoint
    var isLine: Bool

    static func line(_ a: CGPoint, _ b: CGPoint) -> ReshapeSegment {
        ReshapeSegment(p0: a, c1: a, c2: b, p3: b, isLine: true)
    }

    func point(at t: Double) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x
        let y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y
        return CGPoint(x: x, y: y)
    }

    func split(at t: Double) -> (ReshapeSegment, ReshapeSegment) {
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
        let p01 = mix(p0, c1), p12 = mix(c1, c2), p23 = mix(c2, p3)
        let p012 = mix(p01, p12), p123 = mix(p12, p23)
        let mid = mix(p012, p123)
        if isLine {
            return (.line(p0, mid), .line(mid, p3))
        }
        return (ReshapeSegment(p0: p0, c1: p01, c2: p012, p3: mid, isLine: false),
                ReshapeSegment(p0: mid, c1: p123, c2: p23, p3: p3, isLine: false))
    }

    var reversed: ReshapeSegment {
        ReshapeSegment(p0: p3, c1: c2, c2: c1, p3: p0, isLine: isLine)
    }

    var isDegenerate: Bool {
        isLine && abs(p0.x - p3.x) < 1e-6 && abs(p0.y - p3.y) < 1e-6
    }
}

private struct ReshapeLocation {
    var index: Int
    var t: Double
    var distance: Double
    var point: CGPoint
}

extension DrawingCanvas {

    /// Illustrator Pencil "Edit selected paths": drawing a stroke that starts and ends on the selected path
    /// reshapes that path along the new stroke instead of creating a new object. Returns true if it reshaped.
    internal func reshapeSelectedPathWithFreehand(_ newPath: VectorPath) -> Bool {
        guard !ApplicationSettings.shared.freehandExpandStroke else { return false }
        let selected = document.viewState.selectedObjectIDs
        guard selected.count == 1, let id = selected.first,
              let shape = document.findShape(by: id),
              !shape.isGroup, !shape.isGroupContainer, !shape.isCompoundPath, shape.isVisible, !shape.isLocked,
              shape.textContent == nil, shape.embeddedImageData == nil,
              shape.transform == .identity,
              shape.path.pendingStartHandle == nil, shape.path.pendingEndHandle == nil,
              shape.path.bezierHandles?.isEmpty ?? true,
              let original = reshapeSegments(from: shape.path.elements),
              let drawn = reshapeSegments(from: newPath.elements), !drawn.closed,
              !original.segments.isEmpty, !drawn.segments.isEmpty else { return false }

        let tolerance = max(2.0, 10.0 / zoomLevel)
        guard let startHit = reshapeNearest(drawn.segments[0].p0, in: original.segments),
              let endHit = reshapeNearest(drawn.segments[drawn.segments.count - 1].p3, in: original.segments),
              startHit.distance <= tolerance, endHit.distance <= tolerance else { return false }
        guard hypot(startHit.point.x - endHit.point.x, startHit.point.y - endHit.point.y) > 1.0 else { return false }

        var stroke = drawn.segments
        var lo = startHit, hi = endHit
        if (lo.index, lo.t) > (hi.index, hi.t) {
            swap(&lo, &hi)
            stroke = stroke.reversed().map { $0.reversed }
        }
        stroke[0].p0 = lo.point
        stroke[stroke.count - 1].p3 = hi.point

        var work = original.segments
        var loT = lo.t
        let (hiLeft, hiRight) = work[hi.index].split(at: hi.t)
        work.replaceSubrange(hi.index...hi.index, with: [hiLeft, hiRight])
        if lo.index == hi.index { loT = hi.t > 0 ? lo.t / hi.t : 0 }
        let (loLeft, loRight) = work[lo.index].split(at: loT)
        work.replaceSubrange(lo.index...lo.index, with: [loLeft, loRight])
        let loStart = lo.index + 1
        let hiStart = hi.index + 2

        var result: [ReshapeSegment]
        if original.closed {
            let arcA = Array(work[loStart..<hiStart])
            let arcB = Array(work[hiStart...]) + Array(work[..<loStart])
            let strokeToA = reshapeMeanDistance(from: stroke, to: arcA)
            let strokeToB = reshapeMeanDistance(from: stroke, to: arcB)
            if strokeToA <= strokeToB {
                result = stroke + arcB
            } else {
                result = arcA + stroke.reversed().map { $0.reversed }
            }
        } else {
            result = Array(work[..<loStart]) + stroke + Array(work[hiStart...])
        }
        result.removeAll { $0.isDegenerate }
        guard !result.isEmpty else { return false }

        var merged = shape.path
        merged.elements = reshapeElements(from: result, closed: original.closed)
        let command = ModifyPathCommand(objectID: id, oldPath: shape.path, newPath: merged)
        document.commandManager.execute(command)
        document.viewState.selectedObjectIDs = [id]
        document.viewState.orderedSelectedObjectIDs = [id]
        return true
    }

    /// Single-subpath element list -> cubic/line segments. nil for multi-subpath paths.
    internal func reshapeSegments(from elements: [PathElement]) -> (segments: [ReshapeSegment], closed: Bool)? {
        guard case .move(let first)? = elements.first else { return nil }
        let start = first.cgPoint
        var current = start
        var segments: [ReshapeSegment] = []
        var closed = false
        for element in elements.dropFirst() {
            if closed { return nil }
            switch element {
            case .move:
                return nil
            case .line(let to):
                let p = to.cgPoint
                segments.append(.line(current, p))
                current = p
            case .curve(let to, let c1, let c2):
                let p = to.cgPoint
                segments.append(ReshapeSegment(p0: current, c1: c1.cgPoint, c2: c2.cgPoint, p3: p, isLine: false))
                current = p
            case .quadCurve(let to, let c):
                let p = to.cgPoint
                let q = c.cgPoint
                let c1 = CGPoint(x: current.x + 2.0 / 3.0 * (q.x - current.x), y: current.y + 2.0 / 3.0 * (q.y - current.y))
                let c2 = CGPoint(x: p.x + 2.0 / 3.0 * (q.x - p.x), y: p.y + 2.0 / 3.0 * (q.y - p.y))
                segments.append(ReshapeSegment(p0: current, c1: c1, c2: c2, p3: p, isLine: false))
                current = p
            case .close:
                if hypot(current.x - start.x, current.y - start.y) > 1e-6 {
                    segments.append(.line(current, start))
                }
                current = start
                closed = true
            }
        }
        segments.removeAll { $0.isDegenerate }
        return (segments, closed)
    }

    internal func reshapeElements(from segments: [ReshapeSegment], closed: Bool) -> [PathElement] {
        var segments = segments
        // The implicit closing line is written by .close, so a trailing straight segment is dropped.
        if closed, let last = segments.last, last.isLine { segments.removeLast() }
        var elements: [PathElement] = [.move(to: VectorPoint(segments[0].p0))]
        for seg in segments {
            if seg.isLine {
                elements.append(.line(to: VectorPoint(seg.p3)))
            } else {
                elements.append(.curve(to: VectorPoint(seg.p3), control1: VectorPoint(seg.c1), control2: VectorPoint(seg.c2)))
            }
        }
        if closed { elements.append(.close) }
        return elements
    }

    private func reshapeNearest(_ point: CGPoint, in segments: [ReshapeSegment]) -> ReshapeLocation? {
        let steps = 32
        var best: ReshapeLocation?
        func dist(_ a: CGPoint) -> Double { hypot(a.x - point.x, a.y - point.y) }
        for (index, seg) in segments.enumerated() {
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let d = dist(seg.point(at: t))
                if best == nil || d < best!.distance {
                    best = ReshapeLocation(index: index, t: t, distance: d, point: seg.point(at: t))
                }
            }
        }
        guard var found = best else { return nil }
        let seg = segments[found.index]
        var lowT = max(0, found.t - 1.0 / Double(steps))
        var highT = min(1, found.t + 1.0 / Double(steps))
        for _ in 0..<24 {
            let m1 = lowT + (highT - lowT) / 3
            let m2 = highT - (highT - lowT) / 3
            if dist(seg.point(at: m1)) < dist(seg.point(at: m2)) { highT = m2 } else { lowT = m1 }
        }
        let t = (lowT + highT) / 2
        let refined = seg.point(at: t)
        if dist(refined) <= found.distance {
            found = ReshapeLocation(index: found.index, t: t, distance: dist(refined), point: refined)
        }
        return found
    }

    /// Mean distance from points sampled along `stroke` to the nearest sample on `arc` (lower = arc is what the stroke redraws).
    private func reshapeMeanDistance(from stroke: [ReshapeSegment], to arc: [ReshapeSegment]) -> Double {
        guard !arc.isEmpty else { return .infinity }
        var arcPoints: [CGPoint] = []
        for seg in arc { for step in 0..<8 { arcPoints.append(seg.point(at: Double(step) / 8.0)) } }
        if let last = arc.last { arcPoints.append(last.p3) }
        var total = 0.0
        var count = 0
        for seg in stroke {
            for step in 0..<8 {
                let p = seg.point(at: Double(step) / 8.0)
                total += arcPoints.map { hypot($0.x - p.x, $0.y - p.y) }.min() ?? 0
                count += 1
            }
        }
        return count > 0 ? total / Double(count) : .infinity
    }
}
