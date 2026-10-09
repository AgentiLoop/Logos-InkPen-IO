import SwiftUI
import AppKit

/// Live state of one Convert Anchor Point drag (Illustrator: drag from an anchor pulls out symmetrical smooth handles).
final class ConvertAnchorDragSession {
    let shapeID: UUID
    let elementIndex: Int
    let oldPath: VectorPath
    let anchor: CGPoint
    var moved = false

    init(shapeID: UUID, elementIndex: Int, oldPath: VectorPath, anchor: CGPoint) {
        self.shapeID = shapeID
        self.elementIndex = elementIndex
        self.oldPath = oldPath
        self.anchor = anchor
    }
}

extension DrawingCanvas {

    /// True when a drag starting at `canvasLocation` lands on an anchor point of a visible, unlocked shape.
    func anchorExists(at canvasLocation: CGPoint) -> Bool {
        return findAnchorForConvertDrag(at: canvasLocation) != nil
    }

    private func findAnchorForConvertDrag(at location: CGPoint) -> (shape: VectorShape, elementIndex: Int)? {
        let tolerance = max(2.0, 8.0 / zoomLevel)
        for layerIndex in document.snapshot.layers.indices.reversed() {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible || layer.isLocked { continue }
            for shape in document.getShapesForLayer(layerIndex).reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                for (index, element) in shape.path.elements.enumerated() {
                    guard let end = element.endpointCGPoint else { continue }
                    if distance(location, end) <= tolerance {
                        return (shape, index)
                    }
                }
            }
        }
        return nil
    }

    /// Returns true if the drag was consumed (it started on an anchor point).
    @discardableResult
    func handleConvertAnchorDrag(value: DragGesture.Value, geometry: GeometryProxy) -> Bool {
        if convertAnchorDragSession == nil {
            if convertAnchorDragEvaluated { return false }
            convertAnchorDragEvaluated = true
            let start = screenToCanvas(value.startLocation, geometry: geometry)
            guard let hit = findAnchorForConvertDrag(at: start),
                  let anchor = hit.shape.path.elements[hit.elementIndex].endpointCGPoint else { return false }
            convertAnchorDragSession = ConvertAnchorDragSession(
                shapeID: hit.shape.id,
                elementIndex: hit.elementIndex,
                oldPath: hit.shape.path,
                anchor: anchor
            )
        }
        guard let session = convertAnchorDragSession else { return false }
        let current = screenToCanvas(value.location, geometry: geometry)
        var handle = CGPoint(x: current.x - session.anchor.x, y: current.y - session.anchor.y)
        if NSEvent.modifierFlags.contains(.shift) {
            let angle = atan2(handle.y, handle.x)
            let snapped = (angle / (CGFloat.pi / 4)).rounded() * (CGFloat.pi / 4)
            let length = hypot(handle.x, handle.y)
            handle = CGPoint(x: cos(snapped) * length, y: sin(snapped) * length)
        }
        if hypot(handle.x, handle.y) < 2.0 / max(CGFloat(zoomLevel), 0.0001) && !session.moved { return true }
        session.moved = true
        let elements = pullOutHandles(in: session.oldPath.elements,
                                      isClosed: session.oldPath.isClosed,
                                      at: session.elementIndex,
                                      anchor: session.anchor,
                                      handle: handle)
        document.updateShapeByID(session.shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
        if let object = document.snapshot.objects[session.shapeID] {
            document.triggerLayerUpdates(for: [object.layerIndex])
        }
        return true
    }

    func finishConvertAnchorDrag() {
        convertAnchorDragEvaluated = false
        guard let session = convertAnchorDragSession else { return }
        convertAnchorDragSession = nil
        guard session.moved, let shape = document.findShape(by: session.shapeID) else { return }
        let command = ModifyPathCommand(objectID: session.shapeID, oldPath: session.oldPath, newPath: shape.path)
        document.commandManager.execute(command)
        if document.viewState.currentTool == .convertAnchorPoint {
            enableDirectSelectionForConvertedPoint(shapeID: session.shapeID, elementIndex: session.elementIndex)
        }
    }

    /// Outgoing handle = anchor + handle, incoming handle = anchor - handle (smooth, symmetrical).
    private func pullOutHandles(in original: [PathElement], isClosed: Bool, at index: Int,
                                anchor: CGPoint, handle: CGPoint) -> [PathElement] {
        var elements = original
        let outPoint = VectorPoint(anchor.x + handle.x, anchor.y + handle.y)
        let inPoint = VectorPoint(anchor.x - handle.x, anchor.y - handle.y)

        // Incoming handle: the segment that ends at this anchor.
        var incomingIndex: Int? = nil
        if case .move = elements[index] {
            if isClosed, let last = elements.lastIndex(where: { $0.endpoint != nil }), last != index,
               let end = elements[last].endpointCGPoint, hypot(end.x - anchor.x, end.y - anchor.y) < 0.01 {
                incomingIndex = last
            }
        } else {
            incomingIndex = index
        }
        if let i = incomingIndex {
            switch elements[i] {
            case .curve(let to, let c1, _):
                elements[i] = .curve(to: to, control1: c1, control2: inPoint)
            case .line(let to), .quadCurve(let to, _):
                var previous = VectorPoint(to.x, to.y)
                if i > 0, let p = elements[i - 1].endpoint { previous = p }
                elements[i] = .curve(to: to, control1: previous, control2: inPoint)
            default:
                break
            }
        }

        // Outgoing handle: the segment that starts at this anchor.
        let next = index + 1
        if next < elements.count {
            switch elements[next] {
            case .curve(let to, _, let c2):
                elements[next] = .curve(to: to, control1: outPoint, control2: c2)
            case .line(let to), .quadCurve(let to, _):
                elements[next] = .curve(to: to, control1: outPoint, control2: to)
            default:
                break
            }
        }
        return elements
    }
}
