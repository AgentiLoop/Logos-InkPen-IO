import SwiftUI

extension DrawingCanvas {

    internal func handleSmoothDragUpdate(at location: CGPoint) {
        let minimumSpacing = 1.0 / zoomLevel
        if let last = smoothPoints.last, hypot(last.x - location.x, last.y - location.y) < minimumSpacing {
            return
        }
        smoothPoints.append(location)
        var elements: [PathElement] = [.move(to: VectorPoint(smoothPoints[0]))]
        if smoothPoints.count == 1 {
            elements.append(.line(to: VectorPoint(smoothPoints[0])))
        } else {
            for point in smoothPoints.dropFirst() { elements.append(.line(to: VectorPoint(point))) }
        }
        smoothPreviewPath = VectorPath(elements: elements)
    }

    /// Illustrator Smooth tool: dragging along a selected path re-fits the part of it the stroke passed over
    /// with fewer anchors and gentler curves. Only the selected, untransformed paths are smoothed.
    internal func handleSmoothDragEnd() {
        let trail = smoothPoints
        smoothPoints = []
        smoothPreviewPath = nil
        guard !trail.isEmpty else { return }

        let radius = 12.0 / zoomLevel
        var steps: [BaseCommand] = []
        for id in document.viewState.orderedSelectedObjectIDs {
            guard let shape = document.findShape(by: id),
                  !shape.isGroup, !shape.isGroupContainer, shape.isVisible, !shape.isLocked,
                  shape.textContent == nil, shape.embeddedImageData == nil,
                  shape.transform == .identity,
                  shape.path.pendingStartHandle == nil, shape.path.pendingEndHandle == nil,
                  shape.path.bezierHandles?.isEmpty ?? true,
                  let newElements = smoothedSubpathElements(shape.path.elements, trail: trail, radius: radius) else { continue }
            var smoothed = shape.path
            smoothed.elements = newElements
            steps.append(ModifyPathCommand(objectID: id, oldPath: shape.path, newPath: smoothed))
        }
        guard !steps.isEmpty else { return }
        document.commandManager.execute(EraserCommand(steps: steps))
    }

    /// Smooths every subpath the trail passed over (compound paths keep their other subpaths untouched).
    private func smoothedSubpathElements(_ elements: [PathElement], trail: [CGPoint], radius: Double) -> [PathElement]? {
        var starts: [Int] = []
        for (index, element) in elements.enumerated() {
            if case .move = element { starts.append(index) }
        }
        guard !starts.isEmpty, starts[0] == 0 else { return nil }
        var result: [PathElement] = []
        var changed = false
        for (position, lower) in starts.enumerated() {
            let upper = position + 1 < starts.count ? starts[position + 1] : elements.count
            let part = Array(elements[lower..<upper])
            if let original = reshapeSegments(from: part), !original.segments.isEmpty,
               let smoothed = smoothedElements(for: original.segments, closed: original.closed, trail: trail, radius: radius) {
                result += smoothed
                changed = true
            } else {
                result += part
            }
        }
        return changed ? result : nil
    }

    private func smoothedElements(for segments: [ReshapeSegment], closed: Bool, trail: [CGPoint], radius: Double) -> [PathElement]? {
        func distanceToTrail(_ p: CGPoint) -> Double {
            guard trail.count > 1 else { return hypot(p.x - trail[0].x, p.y - trail[0].y) }
            var best = Double.infinity
            for i in 1..<trail.count {
                let a = trail[i - 1], b = trail[i]
                let dx = b.x - a.x, dy = b.y - a.y
                let lengthSquared = dx * dx + dy * dy
                let t = lengthSquared > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared)) : 0
                best = min(best, hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy)))
            }
            return best
        }
        let samplesPerSegment = 16
        var touched: [Int] = []
        for (index, segment) in segments.enumerated() {
            for step in 0...samplesPerSegment where distanceToTrail(segment.point(at: Double(step) / Double(samplesPerSegment))) <= radius {
                touched.append(index)
                break
            }
        }
        guard let lo = touched.first, let hi = touched.last, hi > lo else { return nil }

        var points: [CGPoint] = []
        for index in lo...hi {
            for step in 0..<samplesPerSegment { points.append(segments[index].point(at: Double(step) / Double(samplesPerSegment))) }
        }
        points.append(segments[hi].p3)
        points = CurveSmoothing.chaikinSmooth(points: points, iterations: 2, ratio: 0.25)
        points = CurveSmoothing.improvedDouglassPeucker(points: points, tolerance: max(0.5, 2.0 / zoomLevel), preserveSharpCorners: false)
        guard points.count >= 2 else { return nil }

        var run: [ReshapeSegment] = []
        var current = points[0]
        for element in CurveSmoothing.adaptiveCurveFitting(points: points).dropFirst() {
            switch element {
            case .line(let to):
                run.append(.line(current, to.cgPoint))
                current = to.cgPoint
            case .curve(let to, let c1, let c2):
                run.append(ReshapeSegment(p0: current, c1: c1.cgPoint, c2: c2.cgPoint, p3: to.cgPoint, isLine: false))
                current = to.cgPoint
            default:
                break
            }
        }
        guard !run.isEmpty else { return nil }

        let result = Array(segments[..<lo]) + run + Array(segments[(hi + 1)...])
        return reshapeElements(from: result, closed: closed)
    }
}
