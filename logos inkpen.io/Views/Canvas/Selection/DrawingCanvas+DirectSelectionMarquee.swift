import SwiftUI

extension DrawingCanvas {

    /// Illustrator Direct Selection tool: dragging on empty canvas draws a marquee and selects every
    /// anchor point inside it. Shift adds to the existing selection.
    /// Returns true when the drag is (or just became) a marquee drag.
    internal func handleDirectSelectionMarqueeDrag(value: DragGesture.Value, geometry: GeometryProxy) -> Bool {
        if selectionMarqueeRect == nil {
            guard !directSelectionDragEvaluated else { return false }
            directSelectionDragEvaluated = true
            guard !isDraggingPoint, !isDraggingHandle, !isDraggingCurveSegment, !isDraggingDirectSelectedShapes else { return false }
            let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
            if directSelectionDragStartsOnContent(at: startLocation) { return false }
            if !NSEvent.modifierFlags.contains(.shift) {
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                visibleHandles.removeAll()
                selectedObjectIDs.removeAll()
                syncDirectSelectionWithDocument()
            }
        }
        selectionMarqueeRect = CGRect(
            x: min(value.startLocation.x, value.location.x),
            y: min(value.startLocation.y, value.location.y),
            width: abs(value.location.x - value.startLocation.x),
            height: abs(value.location.y - value.startLocation.y)
        )
        return true
    }

    internal func finishDirectSelectionMarquee(geometry: GeometryProxy) {
        defer { selectionMarqueeRect = nil }
        guard let screenRect = selectionMarqueeRect,
              screenRect.width > 2 || screenRect.height > 2 else { return }
        let a = screenToCanvas(CGPoint(x: screenRect.minX, y: screenRect.minY), geometry: geometry)
        let b = screenToCanvas(CGPoint(x: screenRect.maxX, y: screenRect.maxY), geometry: geometry)
        let canvasRect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        var newPoints = Set<PointID>()
        for layer in document.snapshot.layers where layer.isVisible && !layer.isLocked {
            for objectID in layer.objectIDs {
                guard let object = document.snapshot.objects[objectID] else { continue }
                if case .guide = object.objectType { continue }
                collectMarqueePoints(of: object.shape, in: canvasRect, into: &newPoints)
            }
        }
        for pointID in newPoints {
            selectedPoints.insert(pointID)
            selectedObjectIDs.insert(pointID.shapeID)
        }
        if !newPoints.isEmpty {
            showHandlesForSelectedPoints()
        }
        syncDirectSelectionWithDocument()
    }

    private func collectMarqueePoints(of shape: VectorShape, in rect: CGRect, into result: inout Set<PointID>) {
        if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" { return }
        if !shape.isVisible || shape.isLocked { return }
        if shape.isGroupContainer {
            for memberID in shape.memberIDs {
                if let member = document.snapshot.objects[memberID] {
                    collectMarqueePoints(of: member.shape, in: rect, into: &result)
                }
            }
            return
        }
        for (elementIndex, element) in shape.path.elements.enumerated() {
            guard let point = element.endpointCGPoint else { continue }
            if rect.contains(point.applying(shape.transform)) {
                result.insert(PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex))
            }
        }
    }

    /// True when a Direct Selection drag starting at `location` grabs something: a point or handle of a
    /// selected shape, a selected shape's segment, or any shape. Otherwise the drag is a marquee.
    private func directSelectionDragStartsOnContent(at location: CGPoint) -> Bool {
        let tolerance = 12.0 / zoomLevel
        for objectID in selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID],
                  case .shape(let shape) = object.objectType else { continue }
            for element in shape.path.elements {
                var points: [CGPoint] = []
                switch element {
                case .move(let to), .line(let to):
                    points = [to.cgPoint]
                case .curve(let to, let c1, let c2):
                    points = [to.cgPoint, c1.cgPoint, c2.cgPoint]
                case .quadCurve(let to, let c):
                    points = [to.cgPoint, c.cgPoint]
                case .close:
                    break
                }
                for point in points where point.applying(shape.transform).distance(to: location) <= tolerance {
                    return true
                }
            }
        }
        if !selectedObjectIDs.isEmpty, findCurveSegmentInSelectedShapes(at: location, tolerance: tolerance) != nil {
            return true
        }
        return findShapeAtLocationForDirectSelect(at: location) != nil
    }
}
