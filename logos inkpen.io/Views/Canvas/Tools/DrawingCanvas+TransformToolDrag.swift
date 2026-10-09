import SwiftUI
import AppKit
import simd

/// Live state of one Rotate / Scale / Reflect / Shear drag (Illustrator-style: drag anywhere about a reference point).
final class TransformToolSession {
    let ids: [UUID]
    let oldShapes: [UUID: VectorShape]
    let origin: CGPoint
    var shearHorizontal: Bool?
    var lastTransform: CGAffineTransform = .identity

    init(ids: [UUID], oldShapes: [UUID: VectorShape], origin: CGPoint) {
        self.ids = ids
        self.oldShapes = oldShapes
        self.origin = origin
    }
}

extension VectorDocument {

    /// Reference point of Rotate / Scale / Reflect / Shear: the point the user clicked, else the centre of the selection.
    func transformToolOriginPoint() -> CGPoint? {
        if let custom = viewState.transformToolOrigin { return custom }
        var union = CGRect.null
        for id in viewState.selectedObjectIDs {
            guard let object = snapshot.objects[id] else { continue }
            let shape = object.shape
            let rect: CGRect
            if shape.typography != nil, let position = shape.textPosition, let size = shape.areaSize {
                rect = CGRect(origin: position, size: size)
            } else {
                let base = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                rect = base.applying(shape.transform)
            }
            if rect.isNull || rect.isInfinite { continue }
            union = union.union(rect)
        }
        guard !union.isNull else { return nil }
        return CGPoint(x: union.midX, y: union.midY)
    }
}

extension DrawingCanvas {

    internal static func isTransformDragTool(_ tool: DrawingTool) -> Bool {
        return tool == .rotate || tool == .scale || tool == .reflect || tool == .shear
    }

    private func makeTransformSession() -> TransformToolSession? {
        guard let origin = document.transformToolOriginPoint() else { return nil }
        var ids: [UUID] = []
        var oldShapes: [UUID: VectorShape] = [:]

        func collect(_ id: UUID) {
            guard !ids.contains(id), let shape = document.findShape(by: id) else { return }
            ids.append(id)
            oldShapes[id] = shape
            if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty {
                for memberID in shape.memberIDs { collect(memberID) }
            }
            if shape.isClippingPath, let clipped = document.snapshot.clippedObjectsCache[shape.id] {
                for clippedID in clipped { collect(clippedID) }
            }
        }
        for id in document.viewState.selectedObjectIDs {
            if let shape = document.findShape(by: id),
               shape.name == "Canvas Background" || shape.name == "Pasteboard Background" || shape.isLocked {
                continue
            }
            collect(id)
        }
        guard !ids.isEmpty else { return nil }
        return TransformToolSession(ids: ids, oldShapes: oldShapes, origin: origin)
    }

    internal func handleTransformToolDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if document.isHandleScalingActive { return }
        if transformToolSession == nil {
            if document.viewState.selectedObjectIDs.isEmpty {
                selectObjectAt(screenToCanvas(value.startLocation, geometry: geometry))
            }
            guard let session = makeTransformSession() else { return }
            transformToolSession = session
        }
        guard let session = transformToolSession else { return }
        let start = screenToCanvas(value.startLocation, geometry: geometry)
        let current = screenToCanvas(value.location, geometry: geometry)
        let transform = transformForDrag(session: session, start: start, current: current)
        session.lastTransform = transform
        applyTransform(transform, to: session)
    }

    internal func finishTransformToolDrag() {
        guard let session = transformToolSession else { return }
        transformToolSession = nil
        let transform = session.lastTransform
        guard !transform.isIdentity else { return }
        if NSEvent.modifierFlags.contains(.option) {
            applyTransform(.identity, to: session)
            ClipboardManager.shared.duplicateSelectionInPlace(in: document)
            guard let copySession = makeTransformSession() else { return }
            applyTransform(transform, to: copySession)
            commitTransform(copySession)
        } else {
            commitTransform(session)
        }
    }

    private func transformForDrag(session: TransformToolSession, start: CGPoint, current: CGPoint) -> CGAffineTransform {
        let o = session.origin
        let shift = NSEvent.modifierFlags.contains(.shift)
        let zoom = max(CGFloat(zoomLevel), 0.0001)
        let minDistance = 8.0 / zoom
        var matrix = CGAffineTransform.identity
        switch document.viewState.currentTool {
        case .rotate:
            let startAngle = atan2(start.y - o.y, start.x - o.x)
            var delta = atan2(current.y - o.y, current.x - o.x) - startAngle
            if shift {
                let step = CGFloat.pi / 4
                delta = (delta / step).rounded() * step
            }
            matrix = CGAffineTransform(rotationAngle: delta)
        case .scale:
            let v0 = CGPoint(x: start.x - o.x, y: start.y - o.y)
            let v1 = CGPoint(x: current.x - o.x, y: current.y - o.y)
            var sx: CGFloat = abs(v0.x) > minDistance ? v1.x / v0.x : 1
            var sy: CGFloat = abs(v0.y) > minDistance ? v1.y / v0.y : 1
            if shift {
                let d0 = hypot(v0.x, v0.y)
                let s: CGFloat = d0 > minDistance ? hypot(v1.x, v1.y) / d0 : 1
                sx = s
                sy = s
            }
            if abs(sx) < 0.001 { sx = sx < 0 ? -0.001 : 0.001 }
            if abs(sy) < 0.001 { sy = sy < 0 ? -0.001 : 0.001 }
            matrix = CGAffineTransform(scaleX: sx, y: sy)
        case .reflect:
            var axis = atan2(current.y - o.y, current.x - o.x)
            if shift {
                let step = CGFloat.pi / 4
                axis = (axis / step).rounded() * step
            }
            matrix = CGAffineTransform(rotationAngle: -axis)
                .concatenating(CGAffineTransform(scaleX: 1, y: -1))
                .concatenating(CGAffineTransform(rotationAngle: axis))
        case .shear:
            let dx = current.x - start.x
            let dy = current.y - start.y
            if session.shearHorizontal == nil, hypot(dx, dy) > 6.0 / zoom {
                session.shearHorizontal = abs(dx) >= abs(dy)
            }
            guard let horizontal = session.shearHorizontal else { return .identity }
            if horizontal {
                var h = start.y - o.y
                if abs(h) < 40.0 / zoom { h = h < 0 ? -40.0 / zoom : 40.0 / zoom }
                matrix = CGAffineTransform(a: 1, b: 0, c: dx / h, d: 1, tx: 0, ty: 0)
            } else {
                var w = start.x - o.x
                if abs(w) < 40.0 / zoom { w = w < 0 ? -40.0 / zoom : 40.0 / zoom }
                matrix = CGAffineTransform(a: 1, b: dy / w, c: 0, d: 1, tx: 0, ty: 0)
            }
        default:
            return .identity
        }
        return CGAffineTransform(translationX: -o.x, y: -o.y)
            .concatenating(matrix)
            .concatenating(CGAffineTransform(translationX: o.x, y: o.y))
    }

    private func applyTransform(_ transform: CGAffineTransform, to session: TransformToolSession) {
        var affectedLayers = Set<Int>()
        for id in session.ids {
            guard let old = session.oldShapes[id] else { continue }
            let newShape = transformedShape(old, by: transform)
            document.updateShapeByID(id, silent: true) { $0 = newShape }
            if let object = document.snapshot.objects[id] { affectedLayers.insert(object.layerIndex) }
        }
        for id in session.ids.reversed() {
            if let shape = session.oldShapes[id], shape.isGroup || shape.isClippingGroup, !shape.memberIDs.isEmpty {
                document.recalculateGroupBounds(groupID: id)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func commitTransform(_ session: TransformToolSession) {
        var newShapes: [UUID: VectorShape] = [:]
        for id in session.ids {
            if let shape = document.findShape(by: id) { newShapes[id] = shape }
        }
        document.executeCommand(ShapeModificationCommand(objectIDs: session.ids, oldShapes: session.oldShapes, newShapes: newShapes))
        document.updateTransformPanelValues()
    }

    private func transformedShape(_ old: VectorShape, by transform: CGAffineTransform) -> VectorShape {
        guard !transform.isIdentity else { return old }
        var shape = old
        if (old.isGroup || old.isClippingGroup) && !old.memberIDs.isEmpty {
            return old
        }
        if old.typography != nil {
            if let position = old.textPosition {
                let size = old.areaSize ?? .zero
                let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2).applying(transform)
                let newPosition = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
                shape.textPosition = newPosition
                shape.transform = CGAffineTransform(translationX: newPosition.x, y: newPosition.y)
            }
            return shape
        }
        if ImageContentRegistry.containsImage(old, in: document) {
            shape.transform = old.transform.concatenating(transform)
            return shape
        }
        let combined = old.transform.concatenating(transform)
        var elements: [PathElement] = []
        for element in old.path.elements {
            switch element {
            case .move(let to):
                elements.append(.move(to: VectorPoint(to.cgPoint.applying(combined))))
            case .line(let to):
                elements.append(.line(to: VectorPoint(to.cgPoint.applying(combined))))
            case .curve(let to, let c1, let c2):
                elements.append(.curve(to: VectorPoint(to.cgPoint.applying(combined)),
                                       control1: VectorPoint(c1.cgPoint.applying(combined)),
                                       control2: VectorPoint(c2.cgPoint.applying(combined))))
            case .quadCurve(let to, let c):
                elements.append(.quadCurve(to: VectorPoint(to.cgPoint.applying(combined)),
                                           control: VectorPoint(c.cgPoint.applying(combined))))
            case .close:
                elements.append(.close)
            }
        }
        shape.path = VectorPath(elements: elements, isClosed: old.path.isClosed)
        shape.transform = .identity
        if !shape.cornerRadii.isEmpty && shape.isRoundedRectangle {
            let scaleX = simd_length(SIMD2(Double(transform.a), Double(transform.c)))
            let scaleY = simd_length(SIMD2(Double(transform.b), Double(transform.d)))
            if max(scaleX, scaleY) / min(scaleX, scaleY) > 3.0 {
                shape.isRoundedRectangle = false
                shape.cornerRadii = []
                shape.originalBounds = nil
            } else {
                let averageScale = (scaleX + scaleY) / 2.0
                for i in shape.cornerRadii.indices {
                    shape.cornerRadii[i] = max(0.0, old.cornerRadii[i] * Double(averageScale))
                }
            }
        }
        shape.updateBounds()
        return shape
    }
}
