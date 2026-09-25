import SwiftUI
import Combine

extension DrawingCanvas {

    internal func startSelectionDrag() {
        guard document.selectedLayerIndex != nil,
              !document.viewState.selectedObjectIDs.isEmpty else { return }
        shiftConstraintAxis = .none
        if isBezierDrawing, let bezierShape = activeBezierShape {
            if !document.viewState.selectedObjectIDs.contains(bezierShape.id) {
                document.viewState.orderedSelectedObjectIDs.append(bezierShape.id)
                document.viewState.selectedObjectIDs.insert(bezierShape.id)
            }
        }
        if ApplicationSettings.shared.hideTransformBoxDuringDrag {
            transformBoxOpacity = 0.000001
        }
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            if object.layerIndex < document.snapshot.layers.count {
                let layer = document.snapshot.layers[object.layerIndex]
                if layer.isLocked {
                    return
                }
            }
            switch object.objectType {
            case .text:
                break
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if shape.isLocked {
                    return
                }
            }
        }
        var combinedBounds: CGRect?
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text:
                break
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                let bounds: CGRect
                if shape.isGroupContainer {
                    bounds = document.calculateGroupBounds(shape)
                } else {
                    bounds = shape.bounds
                }
                let transformedBounds = bounds.applying(shape.transform)
                if let existing = combinedBounds {
                    combinedBounds = existing.union(transformedBounds)
                } else {
                    combinedBounds = transformedBounds
                }
            }
        }
        cachedSelectionBoundsForDrag = combinedBounds
        initialObjectPositions.removeAll()
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                if let textObject = document.findText(by: shape.id) {
                    let centerX = textObject.position.x + textObject.bounds.width/2
                    let centerY = textObject.position.y + textObject.bounds.height/2
                    let calculatedCenter = CGPoint(x: centerX, y: centerY)
                    initialObjectPositions[object.id] = calculatedCenter
                } else {
                    let bounds = shape.bounds
                    let centerX = shape.transform.tx + bounds.width/2
                    let centerY = shape.transform.ty + bounds.height/2
                    let fallbackCenter = CGPoint(x: centerX, y: centerY)
                    initialObjectPositions[object.id] = fallbackCenter
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                let bounds: CGRect
                if shape.isGroupContainer {
                    bounds = document.calculateGroupBounds(shape)
                } else {
                    bounds = shape.bounds
                }
                let localCenter = CGPoint(x: bounds.midX, y: bounds.midY)
                let documentCenter = localCenter.applying(shape.transform)
                initialObjectPositions[object.id] = documentCenter
                initialObjectTransforms[object.id] = shape.transform
            }
        }
    }

    internal func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard document.selectedLayerIndex != nil,
              !document.viewState.selectedObjectIDs.isEmpty else { return }
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            if object.layerIndex < document.snapshot.layers.count {
                let layer = document.snapshot.layers[object.layerIndex]
                if layer.isLocked {
                    return
                }
            }
            switch object.objectType {
            case .text:
                break
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if shape.isLocked {
                    return
                }
            }
        }
        var cursorDelta = CGPoint(
            x: value.location.x - selectionDragStart.x,
            y: value.location.y - selectionDragStart.y
        )
        let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
        if isShiftCurrentlyPressed {
            if shiftConstraintAxis == .none {
                if abs(cursorDelta.x) > abs(cursorDelta.y) {
                    shiftConstraintAxis = .horizontal
                } else if abs(cursorDelta.y) > abs(cursorDelta.x) {
                    shiftConstraintAxis = .vertical
                }
            }
            switch shiftConstraintAxis {
            case .horizontal:
                cursorDelta.y = 0
            case .vertical:
                cursorDelta.x = 0
            case .none:
                break
            }
        } else {
            shiftConstraintAxis = .none
        }
        let preciseZoom = Double(zoomLevel)

        var canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        if document.gridSettings.snapToGrid || document.gridSettings.snapToPoint {
            if let firstObjectID = document.viewState.selectedObjectIDs.first,
               let initialCenter = initialObjectPositions[firstObjectID],

               let firstObject = document.snapshot.objects[firstObjectID] {
                if case .shape(let shape) = firstObject.objectType {
                    let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    let transformedBounds = bounds.applying(shape.transform)
                    let topLeftX = initialCenter.x - transformedBounds.width/2 + canvasDelta.x
                    let topLeftY = initialCenter.y - transformedBounds.height/2 + canvasDelta.y
                    let targetTopLeft = CGPoint(x: topLeftX, y: topLeftY)
                    let snappedTopLeft = applySnapping(to: targetTopLeft)
                    let snappedCenter = CGPoint(
                        x: snappedTopLeft.x + transformedBounds.width/2,
                        y: snappedTopLeft.y + transformedBounds.height/2
                    )
                    canvasDelta = CGPoint(x: snappedCenter.x - initialCenter.x, y: snappedCenter.y - initialCenter.y)
                    switch shiftConstraintAxis {
                    case .horizontal:
                        canvasDelta.y = 0
                    case .vertical:
                        canvasDelta.x = 0
                    case .none:
                        break
                    }
                }
            }
        }
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            if case .shape(let shape) = object.objectType {
                if shape.isClippingPath {
                }
            }
        }
        currentDragDelta = canvasDelta
        liveDragOffset = canvasDelta
        if document.activeLayerIndexDuringDrag == nil, let firstSelected = document.viewState.selectedObjectIDs.first {
            if let obj = document.findObject(by: firstSelected) {
                document.activeLayerIndexDuringDrag = obj.layerIndex
                for layer in document.snapshot.layers {
                    if layer.opacity == 1.0 {
                        layerPreviewOpacities[layer.id] = 0.9999999999
                    }
                }
            }
        }
    }

    internal func finishSelectionDrag() {
        if document.isHandleScalingActive {
            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            liveDragOffset = .zero
            cachedSelectionBoundsForDrag = nil
            shiftConstraintAxis = .none
            document.activeLayerIndexDuringDrag = nil
            layerPreviewOpacities.removeAll()
            return
        }
        if !initialObjectPositions.isEmpty && currentDragDelta != .zero {
            guard document.selectedLayerIndex != nil else { return }
            transformBoxOpacity = 1.0
            let finalDelta = currentDragDelta
            liveDragOffset = .zero
            cachedSelectionBoundsForDrag = nil
            document.currentDragOffset = .zero
            document.dragPreviewCoordinates = .zero
            document.cachedSelectionBounds = nil
            document.activeLayerIndexDuringDrag = nil
            layerPreviewOpacities.removeAll()
            var oldShapes: [UUID: VectorShape] = [:]
            var affectedObjectIDs: Set<UUID> = []

            func collectGroupMembers(_ shape: VectorShape) {
                guard !shape.memberIDs.isEmpty else { return }
                for memberID in shape.memberIDs {
                    guard let memberObj = document.snapshot.objects[memberID] else { continue }
                    oldShapes[memberID] = memberObj.shape
                    affectedObjectIDs.insert(memberID)
                    switch memberObj.objectType {
                    case .group(let nestedShape), .clipGroup(let nestedShape):
                        collectGroupMembers(nestedShape)
                    default:
                        break
                    }
                }
            }
            for objectID in document.viewState.selectedObjectIDs {
                guard let object = document.snapshot.objects[objectID] else { continue }
                switch object.objectType {
                case .text(let shape):
                    oldShapes[object.id] = shape
                    affectedObjectIDs.insert(object.id)
                case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape), .guide(let shape):
                    oldShapes[object.id] = shape
                    affectedObjectIDs.insert(object.id)
                    if shape.isClippingPath, let clippedIDs = document.snapshot.clippedObjectsCache[shape.id] {
                        for clippedID in clippedIDs {
                            if let clippedObj = document.snapshot.objects[clippedID] {
                                let clippedShape = clippedObj.shape
                                oldShapes[clippedID] = clippedShape
                                affectedObjectIDs.insert(clippedID)
                            }
                        }
                    }
                case .group(let shape), .clipGroup(let shape):
                    oldShapes[object.id] = shape
                    affectedObjectIDs.insert(object.id)
                    collectGroupMembers(shape)
                }
            }
            for objectID in document.viewState.selectedObjectIDs {
                guard let object = document.snapshot.objects[objectID] else { continue }
                switch object.objectType {
                case .text(let shape):
                    document.translateTextInUnified(id: shape.id, delta: finalDelta)
                case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                    applyDragDeltaToUnifiedObject(objectID: shape.id, delta: finalDelta)
                }
            }
            var newShapes: [UUID: VectorShape] = [:]
            for objectID in affectedObjectIDs {
                if let object = document.snapshot.objects[objectID] {
                    switch object.objectType {
                    case .text(let shape):
                        if let updatedObject = document.snapshot.objects[shape.id],
                           case .text(let updatedShape) = updatedObject.objectType {
                            newShapes[objectID] = updatedShape
                        } else {
                            newShapes[objectID] = shape
                        }
                    case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                        if let updatedShape = document.findShape(by: shape.id) {
                            newShapes[objectID] = updatedShape
                        } else {
                            newShapes[objectID] = shape
                        }
                    }
                }
            }
            if !oldShapes.isEmpty && !newShapes.isEmpty {
                let command = ShapeModificationCommand(
                    objectIDs: Array(affectedObjectIDs),
                    oldShapes: oldShapes,
                    newShapes: newShapes
                )
                document.executeCommand(command)
            }
            document.updateTransformPanelValues()
            if isBezierDrawing, let bezierShape = activeBezierShape,
               affectedObjectIDs.contains(bezierShape.id) {
                bezierPoints = bezierPoints.map { point in
                    VectorPoint(point.x + finalDelta.x, point.y + finalDelta.y)
                }
                var updatedHandles: [Int: BezierHandleInfo] = [:]
                for (index, handleInfo) in bezierHandles {
                    var newHandleInfo = handleInfo
                    if let c1 = handleInfo.control1 {
                        newHandleInfo.control1 = VectorPoint(c1.x + finalDelta.x, c1.y + finalDelta.y)
                    }
                    if let c2 = handleInfo.control2 {
                        newHandleInfo.control2 = VectorPoint(c2.x + finalDelta.x, c2.y + finalDelta.y)
                    }
                    updatedHandles[index] = newHandleInfo
                }
                bezierHandles = updatedHandles
                updatePathWithHandles()
                if let updatedShape = document.findShape(by: bezierShape.id) {
                    activeBezierShape = updatedShape
                }
            }
            currentDragDelta = .zero
            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            shiftConstraintAxis = .none
        } else {
            liveDragOffset = .zero
            cachedSelectionBoundsForDrag = nil
            document.cachedSelectionBounds = nil
        }
    }

    private func applyDragDeltaToUnifiedObject(objectID: UUID, delta: CGPoint) {
        guard let object = document.snapshot.objects[objectID] else {
            return
        }
        switch object.objectType {
        case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
            applyDragDeltaToShape(shape: shape, delta: delta)
        case .text:
            return
        }
    }

    private func applyDragDeltaToShapeCoordinates(layerIndex: Int, shapeIndex: Int, delta: CGPoint) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        applyDragDeltaToShape(shape: shape, delta: delta)
    }

    private func applyDragDeltaToShape(shape: VectorShape, delta: CGPoint) {
        let hasNonIdentityTransform = !shape.transform.isIdentity
        if ImageContentRegistry.containsImage(shape, in: document) || hasNonIdentityTransform {
            var updatedShape = shape
            if updatedShape.transform.isIdentity {
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
            } else {
                let currentTransform = updatedShape.transform
                let translationTransform = CGAffineTransform(translationX: delta.x, y: delta.y)
                updatedShape.transform = currentTransform.concatenating(translationTransform)
            }
            document.updateShapeTransformAndPathInUnified(id: updatedShape.id, transform: updatedShape.transform)
            return
        }
        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
            for memberID in shape.memberIDs {
                if let memberObj = document.snapshot.objects[memberID] {
                    switch memberObj.objectType {
                    case .shape(let memberShape), .image(let memberShape), .warp(let memberShape), .group(let memberShape), .clipGroup(let memberShape), .clipMask(let memberShape), .guide(let memberShape):
                        applyDragDeltaToShape(shape: memberShape, delta: delta)
                    case .text(let memberShape):
                        if let textPosition = memberShape.textPosition {
                            var updatedShape = memberShape
                            updatedShape.textPosition = CGPoint(x: textPosition.x + delta.x, y: textPosition.y + delta.y)
                            let updatedObject = VectorObject(
                                id: memberID,
                                layerIndex: memberObj.layerIndex,
                                objectType: .text(updatedShape)
                            )
                            document.snapshot.objects[memberID] = updatedObject
                        }
                    }
                }
            }
            var updatedGroupShape = shape
            updatedGroupShape.bounds = document.calculateGroupBounds(shape)
            if let groupObj = document.snapshot.objects[shape.id] {
                let updatedObject = VectorObject(
                    id: shape.id,
                    layerIndex: groupObj.layerIndex,
                    objectType: shape.isClippingGroup ? .clipGroup(updatedGroupShape) : .group(updatedGroupShape)
                )
                document.snapshot.objects[shape.id] = updatedObject
            }
            return
        }
        var updatedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                updatedElements.append(.move(to: VectorPoint(newPoint)))
            case .line(let to):
                let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                updatedElements.append(.line(to: VectorPoint(newPoint)))
            case .curve(let to, let control1, let control2):
                let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                let newControl1 = CGPoint(x: control1.x + delta.x, y: control1.y + delta.y)
                let newControl2 = CGPoint(x: control2.x + delta.x, y: control2.y + delta.y)
                updatedElements.append(.curve(
                    to: VectorPoint(newTo),
                    control1: VectorPoint(newControl1),
                    control2: VectorPoint(newControl2),
                ))
            case .quadCurve(let to, let control):
                let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                let newControl = CGPoint(x: control.x + delta.x, y: control.y + delta.y)
                updatedElements.append(.quadCurve(
                    to: VectorPoint(newTo),
                    control: VectorPoint(newControl),
                ))
            case .close:
                updatedElements.append(.close)
            }
        }
        let updatedPath = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)

        var movedShape = shape
        movedShape.path = updatedPath
        if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
            var updatedWarpEnvelope: [CGPoint] = []
            for corner in shape.warpEnvelope {
                let movedCorner = CGPoint(x: corner.x + delta.x, y: corner.y + delta.y)
                updatedWarpEnvelope.append(movedCorner)
            }
            movedShape.warpEnvelope = updatedWarpEnvelope
        }
        if shape.isClippingPath {
            for object in document.snapshot.objects.values {
                switch object.objectType {
                case .shape(let checkShape), .image(let checkShape), .warp(let checkShape), .group(let checkShape), .clipGroup(let checkShape), .clipMask(let checkShape), .guide(let checkShape):
                    if checkShape.clippedByShapeID == shape.id {
                        applyDragDeltaToUnifiedObject(objectID: checkShape.id, delta: delta)
                    }
                case .text:
                    break
                }
            }
        }
        movedShape.updateBounds()
        document.updateShapeByID(movedShape.id) { $0 = movedShape }
        if document.findParentGroup(for: movedShape.id) != nil {
            if let updatedObject = document.snapshot.objects[movedShape.id] {
                document.updateChildInParentGroup(childID: movedShape.id, updatedShape: updatedObject.shape)
            }
        } else {
        }
    }

    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let transform = shape.transform
        if transform.isIdentity {
            return
        }
        if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
            var transformedGroupedShapes: [VectorShape] = []
            for var groupedShape in shape.groupedShapes {
                var transformedElements: [PathElement] = []
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        let transformedPoint = to.cgPoint.applying(transform)
                        transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                    case .line(let to):
                        let transformedPoint = to.cgPoint.applying(transform)
                        transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                    case .curve(let to, let control1, let control2):
                        let transformedTo = to.cgPoint.applying(transform)
                        let transformedControl1 = control1.cgPoint.applying(transform)
                        let transformedControl2 = control2.cgPoint.applying(transform)
                        transformedElements.append(.curve(
                            to: VectorPoint(transformedTo),
                            control1: VectorPoint(transformedControl1),
                            control2: VectorPoint(transformedControl2),
                        ))
                    case .quadCurve(let to, let control):
                        let transformedTo = to.cgPoint.applying(transform)
                        let transformedControl = control.cgPoint.applying(transform)
                        transformedElements.append(.quadCurve(
                            to: VectorPoint(transformedTo),
                            control: VectorPoint(transformedControl),
                        ))
                    case .close:
                        transformedElements.append(.close)
                    }
                }
                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.transform = .identity
                groupedShape.updateBounds()
                transformedGroupedShapes.append(groupedShape)
            }
            shape.groupedShapes = transformedGroupedShapes
            shape.transform = .identity
            shape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
            return
        }
        var transformedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = to.cgPoint.applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
            case .line(let to):
                let transformedPoint = to.cgPoint.applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
            case .curve(let to, let control1, let control2):
                let transformedTo = to.cgPoint.applying(transform)
                let transformedControl1 = control1.cgPoint.applying(transform)
                let transformedControl2 = control2.cgPoint.applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2),
                ))
            case .quadCurve(let to, let control):
                let transformedTo = to.cgPoint.applying(transform)
                let transformedControl = control.cgPoint.applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl),
                ))
            case .close:
                transformedElements.append(.close)
            }
        }
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        shape.path = transformedPath
        shape.transform = .identity
        shape.updateBounds()
        var updatedShape = shape
        if !updatedShape.cornerRadii.isEmpty && updatedShape.isRoundedRectangle {
            updatedShape.transform = transform
            applyTransformToCornerRadii(shape: &updatedShape)
            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        }
    }
}
