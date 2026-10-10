import SwiftUI

extension DrawingCanvas {

    /// Illustrator Selection tool: dragging on empty canvas draws a marquee and selects every
    /// object the marquee touches. Shift adds to the existing selection.
    /// Returns true when the drag is (or just became) a marquee drag.
    internal func handleSelectionMarqueeDrag(value: DragGesture.Value, geometry: GeometryProxy) -> Bool {
        if selectionMarqueeRect == nil {
            guard !isDrawing, !document.isHandleScalingActive else { return false }
            let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
            if isDraggingSelectedObject(at: startLocation) { return false }
            if findObjectAtLocationOptimized(startLocation) != nil { return false }
            let extend = NSEvent.modifierFlags.contains(.shift)
            selectionMarqueeBase = extend ? document.viewState.selectedObjectIDs : []
            if !extend {
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                selectedObjectIDs.removeAll()
                isCornerRadiusEditMode = false
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

    internal func finishSelectionMarquee(geometry: GeometryProxy) {
        defer {
            selectionMarqueeRect = nil
            selectionMarqueeBase = []
        }
        guard let screenRect = selectionMarqueeRect else { return }
        var selection = selectionMarqueeBase
        if screenRect.width > 2 || screenRect.height > 2 {
            let a = screenToCanvas(CGPoint(x: screenRect.minX, y: screenRect.minY), geometry: geometry)
            let b = screenToCanvas(CGPoint(x: screenRect.maxX, y: screenRect.maxY), geometry: geometry)
            let canvasRect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
            selection.formUnion(objectIDsTouching(canvasRect))
        }
        let previousSelection = document.viewState.selectedObjectIDs
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

    private func objectIDsTouching(_ rect: CGRect) -> Set<UUID> {
        objectIDsSelectable { object, shape in marqueeTouches(object: object, shape: shape, rect: rect) }
    }

    /// Every top-level (or isolated-group member) object that the selection tools may pick and `touches` accepts.
    internal func objectIDsSelectable(where touches: (VectorObject, VectorShape) -> Bool) -> Set<UUID> {
        if let isolatedID = document.viewState.isolatedGroupID {
            var isolated = Set<UUID>()
            for memberID in document.snapshot.objects[isolatedID]?.shape.memberIDs ?? [] {
                guard let object = document.snapshot.objects[memberID] else { continue }
                let shape = object.shape
                if !shape.isVisible || shape.isLocked { continue }
                if touches(object, shape) { isolated.insert(memberID) }
            }
            return isolated
        }
        var groupedChildIDs = Set<UUID>()
        for obj in document.snapshot.objects.values {
            switch obj.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                groupedChildIDs.formUnion(groupShape.memberIDs)
                for child in groupShape.groupedShapes { groupedChildIDs.insert(child.id) }
            default:
                break
            }
        }
        var result = Set<UUID>()
        for layer in document.snapshot.layers where layer.isVisible && !layer.isLocked {
            for objectID in layer.objectIDs {
                guard !groupedChildIDs.contains(objectID),
                      let object = document.snapshot.objects[objectID] else { continue }
                let shape = object.shape
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" { continue }
                if !shape.isVisible || shape.isLocked || shape.clippedByShapeID != nil { continue }
                if case .guide = object.objectType { continue }
                if touches(object, shape) {
                    result.insert(objectID)
                }
            }
        }
        return result
    }

    internal func marqueeTouches(object: VectorObject, shape: VectorShape, rect: CGRect) -> Bool {
        if case .text = object.objectType {
            let textBounds: CGRect
            if let position = shape.textPosition, let size = shape.areaSize {
                textBounds = CGRect(origin: position, size: size)
            } else {
                textBounds = CGRect(x: shape.transform.tx, y: shape.transform.ty,
                                    width: shape.bounds.width, height: shape.bounds.height)
            }
            return textBounds.intersects(rect)
        }
        if shape.isGroupContainer {
            return shape.groupBounds.intersects(rect)
        }
        let bounds = shape.bounds.applying(shape.transform)
        guard bounds.intersects(rect) else { return false }
        let usesBoxTest = shape.embeddedImageData != nil || shape.linkedImagePath != nil ||
            shape.isWarpObject || shape.isClippingGroup || shape.isCompoundPath || shape.path.elements.isEmpty
        if usesBoxTest || rect.contains(bounds) { return true }
        var transform = shape.transform
        guard let cgPath = shape.path.cgPath.copy(using: &transform) else { return true }
        let isFilled: Bool = {
            guard let fill = shape.fillStyle, fill.opacity > 0 else { return false }
            if case .clear = fill.color { return false }
            return true
        }()
        if isFilled {
            let rule = shape.path.fillRule.cgPathFillRule
            if cgPath.contains(CGPoint(x: rect.midX, y: rect.midY), using: rule) { return true }
            for corner in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                           CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)] {
                if cgPath.contains(corner, using: rule) { return true }
            }
        }
        return pathOutlineTouches(cgPath, rect: rect)
    }

    /// True if the flattened path outline passes through `rect`.
    private func pathOutlineTouches(_ path: CGPath, rect: CGRect) -> Bool {
        var touches = false
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        func segment(_ from: CGPoint, _ to: CGPoint) {
            if !touches && segmentIntersects(from, to, rect: rect) { touches = true }
        }
        path.applyWithBlock { elementPointer in
            if touches { return }
            let element = elementPointer.pointee
            let p = element.points
            switch element.type {
            case .moveToPoint:
                current = p[0]
                subpathStart = p[0]
            case .addLineToPoint:
                segment(current, p[0])
                current = p[0]
            case .addQuadCurveToPoint:
                let steps = 16
                var prev = current
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let mt = 1 - t
                    let pt = CGPoint(x: mt * mt * current.x + 2 * mt * t * p[0].x + t * t * p[1].x,
                                     y: mt * mt * current.y + 2 * mt * t * p[0].y + t * t * p[1].y)
                    segment(prev, pt)
                    prev = pt
                }
                current = p[1]
            case .addCurveToPoint:
                let steps = 24
                var prev = current
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let mt = 1 - t
                    let x = mt * mt * mt * current.x + 3 * mt * mt * t * p[0].x + 3 * mt * t * t * p[1].x + t * t * t * p[2].x
                    let y = mt * mt * mt * current.y + 3 * mt * mt * t * p[0].y + 3 * mt * t * t * p[1].y + t * t * t * p[2].y
                    let pt = CGPoint(x: x, y: y)
                    segment(prev, pt)
                    prev = pt
                }
                current = p[2]
            case .closeSubpath:
                segment(current, subpathStart)
                current = subpathStart
            @unknown default:
                break
            }
        }
        return touches
    }

    private func segmentIntersects(_ a: CGPoint, _ b: CGPoint, rect: CGRect) -> Bool {
        if rect.contains(a) || rect.contains(b) { return true }
        let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        if !box.insetBy(dx: -0.0001, dy: -0.0001).intersects(rect) { return false }
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        for i in 0..<4 {
            if segmentsCross(a, b, corners[i], corners[(i + 1) % 4]) { return true }
        }
        return false
    }

    private func segmentsCross(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        func orient(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        let d1 = orient(p3, p4, p1), d2 = orient(p3, p4, p2)
        let d3 = orient(p1, p2, p3), d4 = orient(p1, p2, p4)
        return (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0)
    }
}
