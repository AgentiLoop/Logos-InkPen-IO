import SwiftUI

extension VectorDocument {

    func groupSelectedObjects() {
        guard viewState.selectedObjectIDs.count > 1 else {
            return
        }
        let selectedShapes = getSelectedShapesInStackingOrder()
        guard let firstObjectID = viewState.orderedSelectedObjectIDs.first ?? viewState.selectedObjectIDs.first,

              let firstObject = snapshot.objects[firstObjectID] else {
            return
        }
        let layerIndex = firstObject.layerIndex
        let groupShape = VectorShape.group(from: selectedShapes, name: "Group")
        let newSelectedIDs: Set<UUID> = [groupShape.id]
        let memberObjectIDs = selectedShapes.map { $0.id }
        let command = GroupCommand(
            operation: .group,
            layerIndex: layerIndex,
            removedObjectIDs: memberObjectIDs,
            removedShapes: [:],
            addedObjectIDs: [groupShape.id],
            addedShapes: [groupShape.id: groupShape],
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [groupShape.id]
        viewState.selectedObjectIDs = [groupShape.id]
    }

    func flattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              viewState.selectedObjectIDs.count > 1 else { return }
        var removedShapes: [UUID: VectorShape] = [:]
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID] {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    removedShapes[obj.id] = shape
                }
            }
        }
        let selectedShapes = getSelectedShapesInStackingOrder()

        var combinedBounds = CGRect.zero
        for shape in selectedShapes {
            let shapeBounds = shape.bounds
            if combinedBounds == .zero {
                combinedBounds = shapeBounds
            } else {
                combinedBounds = combinedBounds.union(shapeBounds)
            }
        }
        let flattenedShape = VectorShape(
            name: "Flattened Group",
            path: VectorPath(cgPath: CGPath(rect: combinedBounds, transform: nil)),
            strokeStyle: nil,
            fillStyle: nil,
            transform: .identity,
            isGroup: true,
            groupedShapes: selectedShapes,
            isCompoundPath: false
        )
        let newSelectedIDs: Set<UUID> = [flattenedShape.id]
        let command = GroupCommand(
            operation: .flatten,
            layerIndex: layerIndex,
            removedObjectIDs: Array(viewState.selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [flattenedShape.id],
            addedShapes: [flattenedShape.id: flattenedShape],
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [flattenedShape.id]
        viewState.selectedObjectIDs = [flattenedShape.id]
    }

    func ungroupSelectedObjects() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        var newSelectedShapeIDs: Set<UUID> = []
        var groupsToRemove: [UUID] = []
        var memberIDsToRestore: [UUID] = []
        var removedShapes: [UUID: VectorShape] = [:]
        var addedShapes: [UUID: VectorShape] = [:]
        for objectID in viewState.selectedObjectIDs {
            if let vectorObject = findObject(by: objectID) {
                switch vectorObject.objectType {
                case .group(let shape), .clipGroup(let shape):
                    if shape.isGroupContainer {
                        removedShapes[objectID] = shape
                        groupsToRemove.append(objectID)
                        if !shape.memberIDs.isEmpty {
                            var idsInStackingOrder = Array(shape.memberIDs)
                            if shape.isClippingGroup && idsInStackingOrder.count > 1 {
                                let maskID = idsInStackingOrder.removeFirst()
                                idsInStackingOrder.append(maskID)
                            }
                            for memberID in idsInStackingOrder {
                                memberIDsToRestore.append(memberID)
                                newSelectedShapeIDs.insert(memberID)
                            }
                        } else {
                            for groupedShape in shape.groupedShapes {
                                memberIDsToRestore.append(groupedShape.id)
                                newSelectedShapeIDs.insert(groupedShape.id)
                                addedShapes[groupedShape.id] = groupedShape
                            }
                        }
                    } else {
                        newSelectedShapeIDs.insert(objectID)
                    }
                case .shape, .image, .warp, .clipMask, .text, .guide:
                    newSelectedShapeIDs.insert(objectID)
                }
            }
        }
        let layerIndex = groupsToRemove.first.flatMap { snapshot.objects[$0]?.layerIndex } ?? selectedLayerIndex ?? 0
        let command = GroupCommand(
            operation: .ungroup,
            layerIndex: layerIndex,
            removedObjectIDs: groupsToRemove,
            removedShapes: removedShapes,
            addedObjectIDs: memberIDsToRestore,
            addedShapes: addedShapes,
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedShapeIDs
        )
        commandManager.execute(command)
        viewState.selectedObjectIDs = newSelectedShapeIDs
    }

    func unflattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              viewState.selectedObjectIDs.count == 1,
              let selectedShapeID = viewState.selectedObjectIDs.first else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }) else { return }
        guard let flattenedGroup = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        guard flattenedGroup.isGroup && !flattenedGroup.groupedShapes.isEmpty else { return }
        var removedShapes: [UUID: VectorShape] = [:]
        if snapshot.objects[selectedShapeID] != nil {
            removedShapes[selectedShapeID] = flattenedGroup
        }
        let restoredShapes = flattenedGroup.groupedShapes

        var newSelectedIDs: Set<UUID> = []
        var shapesToAdd: [VectorShape] = []
        for originalShape in restoredShapes {
            var restoredShape = originalShape
            restoredShape.id = UUID()
            shapesToAdd.append(restoredShape)
            newSelectedIDs.insert(restoredShape.id)
        }
        var addedShapes: [UUID: VectorShape] = [:]
        for shape in shapesToAdd {
            addedShapes[shape.id] = shape
        }
        let command = GroupCommand(
            operation: .unflatten,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.selectedObjectIDs = newSelectedIDs
    }

    func makeCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              viewState.selectedObjectIDs.count > 1 else { return }
        var removedShapes: [UUID: VectorShape] = [:]
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID] {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    removedShapes[obj.id] = shape
                }
            }
        }
        let selectedShapes = getSelectedShapesInStackingOrder()
        let compoundPath = CGMutablePath()
        for shape in selectedShapes {
            compoundPath.addPath(shape.path.cgPath)
        }
        let compoundShape = VectorShape(
            name: "Compound Path",
            path: VectorPath(cgPath: compoundPath, fillRule: .evenOdd),
            strokeStyle: selectedShapes.last?.strokeStyle,
            fillStyle: selectedShapes.last?.fillStyle,
            transform: .identity,
            isCompoundPath: true
        )
        let newSelectedIDs: Set<UUID> = [compoundShape.id]
        let command = GroupCommand(
            operation: .makeCompound,
            layerIndex: layerIndex,
            removedObjectIDs: Array(viewState.selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [compoundShape.id],
            addedShapes: [compoundShape.id: compoundShape],
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [compoundShape.id]
        viewState.selectedObjectIDs = [compoundShape.id]
    }

    func makeLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              viewState.selectedObjectIDs.count > 1 else { return }
        var removedShapes: [UUID: VectorShape] = [:]
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID] {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    removedShapes[obj.id] = shape
                }
            }
        }
        let selectedShapes = getSelectedShapesInStackingOrder()
        let loopingPath = CGMutablePath()
        for shape in selectedShapes {
            loopingPath.addPath(shape.path.cgPath)
        }
        let loopingShape = VectorShape(
            name: "Looping Path",
            path: VectorPath(cgPath: loopingPath, fillRule: .winding),
            strokeStyle: selectedShapes.last?.strokeStyle,
            fillStyle: selectedShapes.last?.fillStyle,
            transform: .identity,
            isCompoundPath: true
        )
        let newSelectedIDs: Set<UUID> = [loopingShape.id]
        let command = GroupCommand(
            operation: .makeLooping,
            layerIndex: layerIndex,
            removedObjectIDs: Array(viewState.selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [loopingShape.id],
            addedShapes: [loopingShape.id: loopingShape],
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [loopingShape.id]
        viewState.selectedObjectIDs = [loopingShape.id]
    }

    func releaseCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              viewState.selectedObjectIDs.count == 1,
              let selectedShapeID = viewState.selectedObjectIDs.first else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let compoundShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              compoundShape.isTrueCompoundPath else { return }
        var removedShapes: [UUID: VectorShape] = [:]
        if snapshot.objects[selectedShapeID] != nil {
            removedShapes[selectedShapeID] = compoundShape
        }
        let subpaths = extractSubpaths(from: compoundShape.path.cgPath)

        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []
        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: compoundShape.strokeStyle,
                fillStyle: compoundShape.fillStyle,
                transform: compoundShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }
        var addedShapes: [UUID: VectorShape] = [:]
        for shape in newShapes {
            addedShapes[shape.id] = shape
        }
        let command = GroupCommand(
            operation: .releaseCompound,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.selectedObjectIDs = newSelectedIDs
    }

    func releaseLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              viewState.selectedObjectIDs.count == 1,
              let selectedShapeID = viewState.selectedObjectIDs.first else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let loopingShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              loopingShape.isTrueLoopingPath else { return }
        var removedShapes: [UUID: VectorShape] = [:]
        if snapshot.objects[selectedShapeID] != nil {
            removedShapes[selectedShapeID] = loopingShape
        }
        let subpaths = extractSubpaths(from: loopingShape.path.cgPath)

        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []
        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: loopingShape.strokeStyle,
                fillStyle: loopingShape.fillStyle,
                transform: loopingShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }
        var addedShapes: [UUID: VectorShape] = [:]
        for shape in newShapes {
            addedShapes[shape.id] = shape
        }
        let command = GroupCommand(
            operation: .releaseLooping,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: viewState.selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )
        commandManager.execute(command)
        viewState.selectedObjectIDs = newSelectedIDs
    }

    private func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = CGMutablePath()
                }
                currentPath.move(to: element.points[0])
            case .addLineToPoint:
                currentPath.addLine(to: element.points[0])
            case .addQuadCurveToPoint:
                currentPath.addQuadCurve(to: element.points[1], control: element.points[0])
            case .addCurveToPoint:
                currentPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
            case .closeSubpath:
                if !currentPath.isEmpty {
                    currentPath.closeSubpath()
                }

            @unknown default:
                break
            }
        }
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        return subpaths
    }
}
