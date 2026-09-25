import SwiftUI
import Combine

extension VectorDocument {

    func makeClippingMaskFromSelection() {
        let selectedShapes = getSelectedShapesInStackingOrder()
        guard selectedShapes.count >= 2 else { return }
        guard let targetLayerIndex = selectedLayerIndex else { return }
        var shapesInOrder = selectedShapes

        let maskShape = shapesInOrder.removeLast()
        let contentShapes = shapesInOrder
        let groupShapes = [maskShape] + contentShapes
        let clippingGroup = VectorShape.group(from: groupShapes, name: "Clipping Group", isClippingGroup: true)

        var originalLayerIndices: [UUID: Int] = [:]
        var removedShapes: [UUID: VectorShape] = [:]
        var allRemovedObjectIDs: [UUID] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID] {
                originalLayerIndices[objectID] = obj.layerIndex
                removedShapes[obj.id] = obj.shape
                allRemovedObjectIDs.append(objectID)
            }
        }
        let newSelectedIDs: Set<UUID> = [clippingGroup.id]
        let command = GroupCommand(
            operation: .group,
            layerIndex: targetLayerIndex,
            removedObjectIDs: allRemovedObjectIDs,
            removedShapes: removedShapes,
            addedObjectIDs: [clippingGroup.id],
            addedShapes: [clippingGroup.id: clippingGroup],
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs,
            originalLayerIndices: originalLayerIndices
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [clippingGroup.id]
        viewState.selectedObjectIDs = [clippingGroup.id]
    }

    func releaseClippingMaskForSelection() {
        ungroupSelectedObjects()
    }

    func moveClippingMask(_ maskID: UUID, by offset: CGPoint) {
        guard let layerIndex = selectedLayerIndex else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let maskIndex = shapes.firstIndex(where: { $0.id == maskID }),
              var maskShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex) else { return }
        var oldShapes: [UUID: VectorShape] = [:]
        var clippedShapeIDs: [UUID] = []
        oldShapes[maskID] = maskShape
        for shape in shapes {
            if shape.clippedByShapeID == maskID {
                oldShapes[shape.id] = shape
                clippedShapeIDs.append(shape.id)
            }
        }
        maskShape.transform = maskShape.transform.translatedBy(x: offset.x, y: offset.y)
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: maskIndex, shape: maskShape)
        moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: maskIndex, by: offset)
        let allShapes = getShapesForLayer(layerIndex)
        for (idx, shape) in allShapes.enumerated() {
            if shape.clippedByShapeID == maskID {
                moveShapeByPathCoordinates(layerIndex: layerIndex, shapeIndex: idx, by: offset)
            }
        }
        var newShapes: [UUID: VectorShape] = [:]
        if let shape = findShape(by: maskID) {
            newShapes[maskID] = shape
        }
        for shapeID in clippedShapeIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }
        let command = ClippingMaskCommand(operation: .moveClippingMask(
            maskID: maskID,
            clippedShapeIDs: clippedShapeIDs,
            offset: offset,
            oldShapes: oldShapes,
            newShapes: newShapes
        ))
        commandManager.execute(command)
    }

    private func moveShapeByPathCoordinates(layerIndex: Int, shapeIndex: Int, by offset: CGPoint) {
        guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        if ImageContentRegistry.containsImage(shape, in: self) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
            shape.transform = shape.transform.translatedBy(x: offset.x, y: offset.y)
            var updatedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.move(to: VectorPoint(newPoint)))
                case .line(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.line(to: VectorPoint(newPoint)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl1 = CGPoint(x: control1.x + offset.x, y: control1.y + offset.y)
                    let newControl2 = CGPoint(x: control2.x + offset.x, y: control2.y + offset.y)
                    updatedElements.append(.curve(
                        to: VectorPoint(newTo),
                        control1: VectorPoint(newControl1),
                        control2: VectorPoint(newControl2)
                    ))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl = CGPoint(x: control.x + offset.x, y: control.y + offset.y)
                    updatedElements.append(.quadCurve(
                        to: VectorPoint(newTo),
                        control: VectorPoint(newControl)
                    ))
                case .close:
                    updatedElements.append(.close)
                }
            }
            shape.path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        } else {
            var updatedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.move(to: VectorPoint(newPoint)))
                case .line(let to):
                    let newPoint = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    updatedElements.append(.line(to: VectorPoint(newPoint)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl1 = CGPoint(x: control1.x + offset.x, y: control1.y + offset.y)
                    let newControl2 = CGPoint(x: control2.x + offset.x, y: control2.y + offset.y)
                    updatedElements.append(.curve(
                        to: VectorPoint(newTo),
                        control1: VectorPoint(newControl1),
                        control2: VectorPoint(newControl2)
                    ))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + offset.x, y: to.y + offset.y)
                    let newControl = CGPoint(x: control.x + offset.x, y: control.y + offset.y)
                    updatedElements.append(.quadCurve(
                        to: VectorPoint(newTo),
                        control: VectorPoint(newControl)
                    ))
                case .close:
                    updatedElements.append(.close)
                }
            }
            shape.path = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
        }
        shape.updateBounds()
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
    }

    func isShapeInClippingMask(_ shapeID: UUID) -> Bool {
        if let shape = findShape(by: shapeID) {
            return shape.isClippingPath || shape.clippedByShapeID != nil
        }
        return false
    }

    func getClippingMaskGroup(for maskID: UUID) -> [VectorShape] {
        guard let layerIndex = selectedLayerIndex else { return [] }
        var group: [VectorShape] = []
        if let maskShape = findShape(by: maskID), maskShape.isClippingPath {
            group.append(maskShape)
        }
        let shapes = getShapesForLayer(layerIndex)
        for shape in shapes {
            if shape.clippedByShapeID == maskID {
                group.append(shape)
            }
        }
        return group
    }
}
