import SwiftUI

extension VectorDocument {

    func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        if viewState.currentTool == .directSelection && !viewState.selectedPoints.isEmpty {
            nudgeSelectedPoints(by: nudgeAmount)
            return
        }
        if !viewState.selectedPoints.isEmpty {
            nudgeSelectedPoints(by: nudgeAmount)
            return
        }
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        let translationTransform = CGAffineTransform(translationX: nudgeAmount.dx, y: nudgeAmount.dy)
        viewState.lastTransformAgain = (translationTransform, false)
        modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in viewState.selectedObjectIDs {
                    if let vectorObject = findObject(by: objectID) {
                        switch vectorObject.objectType {
                        case .shape(var shape),
                             .image(var shape),
                             .warp(var shape),
                             .group(var shape),
                             .clipGroup(var shape),
                             .clipMask(var shape),
                             .guide(var shape):
                            if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                                applyTransformToGroup(groupID: shape.id, transform: translationTransform)
                            } else if shape.isGroupContainer {
                                var nudgedGroupedShapes: [VectorShape] = []
                                for var groupedShape in shape.groupedShapes {
                                    groupedShape.path = nudgePath(groupedShape.path, by: nudgeAmount)
                                    groupedShape.updateBounds()
                                    nudgedGroupedShapes.append(groupedShape)
                                }
                                shape.groupedShapes = nudgedGroupedShapes
                                shape.updateBounds()
                                updateEntireShapeInUnified(id: shape.id) { updatedShape in
                                    updatedShape = shape
                                }
                            } else {
                                shape.path = nudgePath(shape.path, by: nudgeAmount)
                                shape.updateBounds()
                                updateEntireShapeInUnified(id: shape.id) { updatedShape in
                                    updatedShape = shape
                                }
                            }
                        case .text:
                            break
                        }
                    }
                }
                viewState.objectPositionUpdateTrigger.toggle()
            }
        )
    }

    private func nudgePath(_ path: VectorPath, by nudgeAmount: CGVector) -> VectorPath {
        var nudgedElements: [PathElement] = []
        for element in path.elements {
            switch element {
            case .move(let to):
                nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
            case .line(let to):
                nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
            case .curve(let to, let c1, let c2):
                nudgedElements.append(.curve(
                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                    control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                    control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                ))
            case .quadCurve(let to, let c):
                nudgedElements.append(.quadCurve(
                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                    control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
                ))
            case .close:
                nudgedElements.append(.close)
            }
        }
        return VectorPath(elements: nudgedElements, isClosed: path.isClosed)
    }

    private func nudgeSelectedPoints(by nudgeAmount: CGVector) {
        guard !viewState.selectedPoints.isEmpty else { return }
        var pointsByShape: [UUID: [PointID]] = [:]
        for pointID in viewState.selectedPoints {
            pointsByShape[pointID.shapeID, default: []].append(pointID)
        }
        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        for shapeID in pointsByShape.keys {
            if let shape = findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                objectIDs.append(shapeID)
            }
        }
        for (shapeID, pointIDs) in pointsByShape {
            guard var shape = findShape(by: shapeID) else { continue }
            var elements = shape.path.elements
            let selectedIndices = Set(pointIDs.map { $0.elementIndex })
            func moved(_ p: VectorPoint) -> VectorPoint {
                VectorPoint(p.x + nudgeAmount.dx, p.y + nudgeAmount.dy)
            }
            // An anchor carries its incoming handle (control2 of its own element) and its
            // outgoing handle (control1 of the next element), like Illustrator.
            for index in 0..<elements.count {
                let anchorSelected = selectedIndices.contains(index)
                let previousSelected = selectedIndices.contains(index - 1)
                switch elements[index] {
                case .move(let to):
                    if anchorSelected { elements[index] = .move(to: moved(to)) }
                case .line(let to):
                    if anchorSelected { elements[index] = .line(to: moved(to)) }
                case .curve(let to, let c1, let c2):
                    elements[index] = .curve(
                        to: anchorSelected ? moved(to) : to,
                        control1: previousSelected ? moved(c1) : c1,
                        control2: anchorSelected ? moved(c2) : c2
                    )
                case .quadCurve(let to, let c):
                    if anchorSelected || previousSelected {
                        elements[index] = .quadCurve(to: anchorSelected ? moved(to) : to, control: moved(c))
                    }
                case .close:
                    break
                }
            }
            shape.path = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            shape.updateBounds()
            updateShapeByID(shapeID, silent: false) { s in
                s = shape
            }
        }
        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }
        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            executeCommand(command)
        }
        viewState.objectPositionUpdateTrigger.toggle()
    }
}
