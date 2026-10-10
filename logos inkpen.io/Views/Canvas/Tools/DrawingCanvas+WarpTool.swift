import SwiftUI
import AppKit

struct WarpToolSession {
    var originals: [UUID: VectorShape] = [:]
    var lastPoint: CGPoint
    var startPoint: CGPoint
    var resizingBrush: Bool
}

extension DrawingCanvas {

    /// Illustrator Warp tool: dragging pushes the outline of the selected objects (or of any object under the
    /// brush when nothing is selected) along with the brush. Option-drag resizes the brush.
    internal func handleWarpToolDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let start = screenToCanvas(value.startLocation, geometry: geometry)
        let current = screenToCanvas(value.location, geometry: geometry)
        if warpToolSession == nil {
            warpToolSession = WarpToolSession(lastPoint: start, startPoint: start,
                                              resizingBrush: NSEvent.modifierFlags.contains(.option))
        }
        guard var session = warpToolSession else { return }
        if session.resizingBrush {
            warpBrushCenterScreen = value.startLocation
            warpBrushRadius = min(max(hypot(current.x - start.x, current.y - start.y), 4), 600)
            return
        }
        warpBrushCenterScreen = value.location
        let radius = warpBrushRadius
        let delta = CGPoint(x: current.x - session.lastPoint.x, y: current.y - session.lastPoint.y)
        let length = hypot(delta.x, delta.y)
        guard length > 0.01 else { return }
        let steps = max(1, Int((length / (radius / 4)).rounded(.up)))
        let stepDelta = CGPoint(x: delta.x / CGFloat(steps), y: delta.y / CGFloat(steps))
        var affectedLayers = Set<Int>()
        for step in 1...steps {
            let center = CGPoint(x: session.lastPoint.x + delta.x * CGFloat(step) / CGFloat(steps),
                                 y: session.lastPoint.y + delta.y * CGFloat(step) / CGFloat(steps))
            for id in warpCandidateIDs(center: center, radius: radius) {
                guard let object = document.snapshot.objects[id], case .shape(let shape) = object.objectType,
                      let warped = warpedElements(shape.path.elements, center: center, radius: radius, delta: stepDelta) else { continue }
                if session.originals[id] == nil { session.originals[id] = shape }
                document.updateShapeByID(id, silent: true) { target in
                    target.path.elements = warped
                    target.anchorTypes = [:]
                    target.isRoundedRectangle = false
                    target.updateBounds()
                }
                affectedLayers.insert(object.layerIndex)
            }
        }
        session.lastPoint = current
        warpToolSession = session
        document.triggerLayerUpdates(for: affectedLayers)
    }

    internal func finishWarpToolDrag() {
        defer {
            warpToolSession = nil
            warpBrushCenterScreen = nil
        }
        guard let session = warpToolSession, !session.resizingBrush, !session.originals.isEmpty else { return }
        var newShapes: [UUID: VectorShape] = [:]
        for id in session.originals.keys {
            if let shape = document.findShape(by: id) { newShapes[id] = shape }
        }
        document.executeCommand(ShapeModificationCommand(objectIDs: Array(newShapes.keys),
                                                         oldShapes: session.originals,
                                                         newShapes: newShapes))
    }

    @ViewBuilder
    internal func warpBrushOverlay() -> some View {
        if document.viewState.currentTool == .warp, let center = warpBrushCenterScreen ?? currentMouseLocation {
            let diameter = warpBrushRadius * 2 * CGFloat(zoomLevel)
            Circle()
                .stroke(Color.black, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .background(Circle().fill(Color.blue.opacity(0.06)))
                .frame(width: diameter, height: diameter)
                .position(x: center.x, y: center.y)
                .allowsHitTesting(false)
        }
    }

    private func warpCandidateIDs(center: CGPoint, radius: CGFloat) -> [UUID] {
        let selected = document.viewState.selectedObjectIDs
        let ids: [UUID] = selected.isEmpty ? Array(document.snapshot.objects.keys) : Array(selected)
        let brush = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        return ids.filter { id in
            guard let object = document.snapshot.objects[id], case .shape(let shape) = object.objectType,
                  !shape.isGroup, !shape.isGroupContainer, shape.isVisible, !shape.isLocked,
                  shape.textContent == nil, shape.embeddedImageData == nil,
                  shape.transform == .identity,
                  shape.name != "Canvas Background", shape.name != "Pasteboard Background",
                  shape.path.pendingStartHandle == nil, shape.path.pendingEndHandle == nil,
                  shape.path.bezierHandles?.isEmpty ?? true,
                  object.layerIndex >= 0, object.layerIndex < document.snapshot.layers.count,
                  document.snapshot.layers[object.layerIndex].isVisible,
                  !document.snapshot.layers[object.layerIndex].isLocked else { return false }
            return shape.cachedCGPath.boundingBoxOfPath.insetBy(dx: -1, dy: -1).intersects(brush)
        }
    }

    /// Pushes every anchor and handle within `radius` of `center` by `delta` (smooth falloff), adding points
    /// where the brush crosses long segments. nil when nothing moved.
    private func warpedElements(_ elements: [PathElement], center: CGPoint, radius: CGFloat, delta: CGPoint) -> [PathElement]? {
        var chunks: [[PathElement]] = []
        for element in elements {
            if case .move = element { chunks.append([element]) } else if !chunks.isEmpty { chunks[chunks.count - 1].append(element) }
        }
        var result: [PathElement] = []
        var changed = false
        for chunk in chunks {
            guard let (segments, closed) = reshapeSegments(from: chunk), !segments.isEmpty else {
                result.append(contentsOf: chunk)
                continue
            }
            var moved = false
            var out: [ReshapeSegment] = []
            for segment in segments {
                for piece in warpDensify(segment, center: center, radius: radius, depth: 0) {
                    var seg = piece
                    let pts = [seg.p0, seg.c1, seg.c2, seg.p3]
                    guard pts.contains(where: { hypot($0.x - center.x, $0.y - center.y) < radius }) else {
                        out.append(seg)
                        continue
                    }
                    if seg.isLine {
                        seg.c1 = CGPoint(x: seg.p0.x + (seg.p3.x - seg.p0.x) / 3, y: seg.p0.y + (seg.p3.y - seg.p0.y) / 3)
                        seg.c2 = CGPoint(x: seg.p0.x + (seg.p3.x - seg.p0.x) * 2 / 3, y: seg.p0.y + (seg.p3.y - seg.p0.y) * 2 / 3)
                        seg.isLine = false
                    }
                    seg.p0 = warpPush(seg.p0, center: center, radius: radius, delta: delta)
                    seg.c1 = warpPush(seg.c1, center: center, radius: radius, delta: delta)
                    seg.c2 = warpPush(seg.c2, center: center, radius: radius, delta: delta)
                    seg.p3 = warpPush(seg.p3, center: center, radius: radius, delta: delta)
                    moved = true
                    out.append(seg)
                }
            }
            if moved {
                changed = true
                result.append(contentsOf: reshapeElements(from: out, closed: closed))
            } else {
                result.append(contentsOf: chunk)
            }
        }
        return changed ? result : nil
    }

    private func warpPush(_ point: CGPoint, center: CGPoint, radius: CGFloat, delta: CGPoint) -> CGPoint {
        let d = hypot(point.x - center.x, point.y - center.y)
        guard d < radius else { return point }
        let t = d / radius
        let falloff = (1 - t * t) * (1 - t * t)
        return CGPoint(x: point.x + delta.x * falloff, y: point.y + delta.y * falloff)
    }

    /// Splits segments near the brush into pieces of about radius/6 so the push can bend them smoothly.
    private func warpDensify(_ seg: ReshapeSegment, center: CGPoint, radius: CGFloat, depth: Int) -> [ReshapeSegment] {
        let xs = [seg.p0.x, seg.c1.x, seg.c2.x, seg.p3.x]
        let ys = [seg.p0.y, seg.c1.y, seg.c2.y, seg.p3.y]
        let dx = max(xs.min()! - center.x, 0, center.x - xs.max()!)
        let dy = max(ys.min()! - center.y, 0, center.y - ys.max()!)
        guard hypot(dx, dy) < radius, depth < 8 else { return [seg] }
        let polyLength = hypot(seg.c1.x - seg.p0.x, seg.c1.y - seg.p0.y)
            + hypot(seg.c2.x - seg.c1.x, seg.c2.y - seg.c1.y)
            + hypot(seg.p3.x - seg.c2.x, seg.p3.y - seg.c2.y)
        guard polyLength > radius / 6 else { return [seg] }
        let (a, b) = seg.split(at: 0.5)
        return warpDensify(a, center: center, radius: radius, depth: depth + 1)
            + warpDensify(b, center: center, radius: radius, depth: depth + 1)
    }
}
