import SwiftUI

extension VectorDocument {

    /// Moves the selected objects by `delta` (the end of a mouse drag with the selection tool) and
    /// records one undo step. Returns the IDs of every object that changed.
    @discardableResult
    func commitSelectionDrag(delta: CGPoint) -> Set<UUID> {
        var oldShapes: [UUID: VectorShape] = [:]
        var affectedObjectIDs: Set<UUID> = []

        func collectGroupMembers(_ shape: VectorShape) {
            guard !shape.memberIDs.isEmpty else { return }
            for memberID in shape.memberIDs {
                guard let memberObj = snapshot.objects[memberID] else { continue }
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
        for objectID in viewState.selectedObjectIDs {
            guard let object = snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                oldShapes[object.id] = shape
                affectedObjectIDs.insert(object.id)
            case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape), .guide(let shape):
                oldShapes[object.id] = shape
                affectedObjectIDs.insert(object.id)
                if shape.isClippingPath, let clippedIDs = snapshot.clippedObjectsCache[shape.id] {
                    for clippedID in clippedIDs {
                        if let clippedObj = snapshot.objects[clippedID] {
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
        for objectID in viewState.selectedObjectIDs {
            guard let object = snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                translateTextInUnified(id: shape.id, delta: delta)
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                applyDragDeltaToUnifiedObject(objectID: shape.id, delta: delta)
            }
        }
        var newShapes: [UUID: VectorShape] = [:]
        for objectID in affectedObjectIDs {
            if let object = snapshot.objects[objectID] {
                switch object.objectType {
                case .text(let shape):
                    if let updatedObject = snapshot.objects[shape.id],
                       case .text(let updatedShape) = updatedObject.objectType {
                        newShapes[objectID] = updatedShape
                    } else {
                        newShapes[objectID] = shape
                    }
                case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                    if let updatedShape = findShape(by: shape.id) {
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
            executeCommand(command)
        }
        return affectedObjectIDs
    }

    private func applyDragDeltaToUnifiedObject(objectID: UUID, delta: CGPoint) {
        guard let object = snapshot.objects[objectID] else {
            return
        }
        switch object.objectType {
        case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
            applyDragDeltaToShape(shape: shape, delta: delta)
        case .text:
            return
        }
    }

    func applyDragDeltaToShape(shape: VectorShape, delta: CGPoint) {
        let hasNonIdentityTransform = !shape.transform.isIdentity
        if ImageContentRegistry.containsImage(shape, in: self) || hasNonIdentityTransform {
            var updatedShape = shape
            if updatedShape.transform.isIdentity {
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
            } else {
                let currentTransform = updatedShape.transform
                let translationTransform = CGAffineTransform(translationX: delta.x, y: delta.y)
                updatedShape.transform = currentTransform.concatenating(translationTransform)
            }
            updateShapeTransformAndPathInUnified(id: updatedShape.id, transform: updatedShape.transform)
            return
        }
        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
            for memberID in shape.memberIDs {
                if let memberObj = snapshot.objects[memberID] {
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
                            snapshot.objects[memberID] = updatedObject
                        }
                    }
                }
            }
            var updatedGroupShape = shape
            updatedGroupShape.bounds = calculateGroupBounds(shape)
            if let groupObj = snapshot.objects[shape.id] {
                let updatedObject = VectorObject(
                    id: shape.id,
                    layerIndex: groupObj.layerIndex,
                    objectType: shape.isClippingGroup ? .clipGroup(updatedGroupShape) : .group(updatedGroupShape)
                )
                snapshot.objects[shape.id] = updatedObject
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
            for object in snapshot.objects.values {
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
        updateShapeByID(movedShape.id) { $0 = movedShape }
        if findParentGroup(for: movedShape.id) != nil {
            if let updatedObject = snapshot.objects[movedShape.id] {
                updateChildInParentGroup(childID: movedShape.id, updatedShape: updatedObject.shape)
            }
        }
    }
}
