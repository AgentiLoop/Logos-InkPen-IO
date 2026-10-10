import SwiftUI

extension DrawingCanvas {

    internal func handleLassoDragUpdate(at location: CGPoint) {
        if lassoPoints.isEmpty {
            lassoBase = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.option)
                ? document.viewState.selectedObjectIDs : []
        }
        let minimumSpacing = 1.5 / zoomLevel
        if let last = lassoPoints.last, hypot(last.x - location.x, last.y - location.y) < minimumSpacing {
            return
        }
        lassoPoints.append(location)
        guard lassoPoints.count >= 2 else { return }
        var elements: [PathElement] = [.move(to: VectorPoint(lassoPoints[0]))]
        for point in lassoPoints.dropFirst() { elements.append(.line(to: VectorPoint(point))) }
        lassoPreviewPath = VectorPath(elements: elements)
    }

    /// Illustrator Lasso: drag a freehand loop; every object the loop touches is selected.
    /// Shift adds to the selection, Option removes from it; a plain lasso replaces the selection.
    internal func handleLassoDragEnd() {
        let points = lassoPoints
        let base = lassoBase
        lassoPoints = []
        lassoPreviewPath = nil
        lassoBase = []
        let flags = NSEvent.modifierFlags
        let adding = flags.contains(.shift) && !flags.contains(.option)
        let subtracting = flags.contains(.option)

        var touched = Set<UUID>()
        if points.count >= 3 {
            let loop = CGMutablePath()
            loop.move(to: points[0])
            for point in points.dropFirst() { loop.addLine(to: point) }
            loop.closeSubpath()
            let loopBounds = loop.boundingBoxOfPath
            touched = objectIDsSelectable { object, shape in
                lassoTouches(object: object, shape: shape, loop: loop, loopBounds: loopBounds)
            }
        }

        var selection: Set<UUID>
        if subtracting {
            selection = base.subtracting(touched)
        } else if adding {
            selection = base.union(touched)
        } else {
            selection = touched
        }
        let previousSelection = document.viewState.selectedObjectIDs
        guard selection != previousSelection else { return }
        if !adding && !subtracting {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            isCornerRadiusEditMode = false
        }
        let ordered = document.viewState.orderedSelectedObjectIDs.filter { selection.contains($0) }
            + selection.subtracting(document.viewState.orderedSelectedObjectIDs)
        document.setSelectionWithUndo(selection, ordered: ordered)
        var affectedLayers = Set<Int>()
        for objectID in previousSelection.union(selection) {
            if let object = document.snapshot.objects[objectID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
        if let first = selection.first, let object = document.snapshot.objects[first] {
            document.selectedLayerIndex = object.layerIndex
        }
    }

    /// Compound paths hit-test through their real outline and fill rule (holes stay unselectable), like any plain path.
    private func lassoTouches(object: VectorObject, shape: VectorShape, loop: CGPath, loopBounds: CGRect) -> Bool {
        guard marqueeTouches(object: object, shape: shape, rect: loopBounds) else { return false }
        let isPlainPath = !shape.isGroupContainer && !shape.isWarpObject && !shape.isClippingGroup &&
            shape.embeddedImageData == nil && shape.linkedImagePath == nil &&
            shape.textContent == nil && !shape.path.elements.isEmpty
        if !isPlainPath {
            if case .text = object.objectType { return true }
            let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds.applying(shape.transform)
            return !loop.intersection(CGPath(rect: bounds, transform: nil), using: .winding).isEmpty
        }
        var transform = shape.transform
        guard let cgPath = shape.path.cgPath.copy(using: &transform) else { return true }
        if let fill = shape.fillStyle, fill.opacity > 0 {
            var visible = true
            if case .clear = fill.color { visible = false }
            if visible, !loop.intersection(cgPath, using: shape.path.fillRule.cgPathFillRule).isEmpty { return true }
        }
        let outlineWidth = max(1.0 / zoomLevel, shape.strokeStyle?.width ?? 0)
        let outline = cgPath.copy(strokingWithWidth: outlineWidth, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
        return !loop.intersection(outline, using: .winding).isEmpty
    }
}
