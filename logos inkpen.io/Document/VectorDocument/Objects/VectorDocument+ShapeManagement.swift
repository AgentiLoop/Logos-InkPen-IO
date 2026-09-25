import SwiftUI

extension VectorDocument {

    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        let objectType = VectorObject.determineType(for: shape)
        let obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)
        viewState.orderedSelectedObjectIDs = [shape.id]
        viewState.selectedObjectIDs = [shape.id]
    }

    func addShapeToFront(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        let objectType = VectorObject.determineType(for: shape)
        let obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)
        viewState.orderedSelectedObjectIDs = [shape.id]
        viewState.selectedObjectIDs = [shape.id]
    }

    func addShape(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let objectType = VectorObject.determineType(for: shape)
        let obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)
    }

    func addImportedShape(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        if (shape.isGroup || shape.isClippingGroup) && !shape.groupedShapes.isEmpty {
            var container = shape
            var memberIDs = container.memberIDs
            for child in container.groupedShapes {
                installGroupMemberIntoSnapshot(child, layerIndex: layerIndex)
                memberIDs.append(child.id)
            }
            container.memberIDs = memberIDs
            container.groupedShapes = []
            addShapeToUnifiedSystem(container, layerIndex: layerIndex)
        } else {
            addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        }
    }

    private func installGroupMemberIntoSnapshot(_ shape: VectorShape, layerIndex: Int) {
        var toInstall = shape
        if (toInstall.isGroup || toInstall.isClippingGroup) && !toInstall.groupedShapes.isEmpty {
            var memberIDs = toInstall.memberIDs
            for child in toInstall.groupedShapes {
                installGroupMemberIntoSnapshot(child, layerIndex: layerIndex)
                memberIDs.append(child.id)
            }
            toInstall.memberIDs = memberIDs
            toInstall.groupedShapes = []
        }
        let objectType = VectorObject.determineType(for: toInstall)
        let vectorObject = VectorObject(id: toInstall.id, layerIndex: layerIndex, objectType: objectType)
        snapshot.objects[toInstall.id] = vectorObject
    }

    func addShapeWithoutUndo(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func removeSelectedShapes() {
        removeSelectedObjects()
    }

    func removeSelectedObjects() {
        let objectIDsToDelete = viewState.selectedObjectIDs.filter { uuid in
            guard let object = snapshot.objects[uuid] else { return false }
            if object.layerIndex < snapshot.layers.count && snapshot.layers[object.layerIndex].isLocked {
                return false
            }
            if object.layerIndex <= 1 {
                return false
            }
            switch object.objectType {
            case .shape(let shape),
                 .text(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    Log.error("🚫 PROTECTED: Attempted to delete protected background shape '\(shape.name)' - BLOCKED", category: .error)
                    return false
                }
            }
            return true
        }
        let candidateCount = viewState.selectedObjectIDs.count
        if candidateCount != objectIDsToDelete.count {
            let blockedCount = candidateCount - objectIDsToDelete.count
            Log.error("🚫 PROTECTION: Blocked deletion of \(blockedCount) protected object(s)", category: .error)
        }
        if !objectIDsToDelete.isEmpty {
            let command = DeleteObjectCommand(objectIDs: Array(objectIDsToDelete), document: self)
            executeCommand(command)
        }
        viewState.selectedObjectIDs.removeAll()
    }

    func getSelectedShapes() -> [VectorShape] {
        var selectedShapes: [VectorShape] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID] {
                switch obj.objectType {
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    selectedShapes.append(shape)
                case .text:
                    break
                }
            }
        }
        return selectedShapes
    }

    func getShapesByIds(_ shapeIDs: Set<UUID>) -> [VectorShape] {
        var shapes: [VectorShape] = []
        for shapeID in shapeIDs {
            if let obj = snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    shapes.append(shape)
                case .text:
                    break
                }
            }
        }
        return shapes
    }

    func getActiveShapeIDs() -> Set<UUID> {
        if viewState.currentTool == .directSelection || viewState.currentTool == .convertAnchorPoint || viewState.currentTool == .penPlusMinus,
           !viewState.selectedObjectIDs.isEmpty {
            return viewState.selectedObjectIDs
        }
        return viewState.selectedObjectIDs
    }

    func getActiveShapes() -> [VectorShape] {
        let activeShapeIDs = getActiveShapeIDs()
        return getShapesByIds(activeShapeIDs)
    }

    func getObjectsInStackingOrder() -> [VectorObject] {
        var result: [VectorObject] = []
        for layer in snapshot.layers {
            guard layer.isVisible else { continue }
            for objectID in layer.objectIDs {
                guard let object = snapshot.objects[objectID] else { continue }
                guard object.isVisible else { continue }
                result.append(object)
            }
        }
        return result
    }

    func getSelectedShapesInStackingOrder() -> [VectorShape] {
        var result: [VectorShape] = []
        for layer in snapshot.layers {
            for objectID in layer.objectIDs {
                guard viewState.selectedObjectIDs.contains(objectID) else { continue }
                guard let object = snapshot.objects[objectID] else { continue }
                switch object.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    result.append(shape)
                }
            }
        }
        return result
    }

    func setSelectionWithUndo(_ newSelectedIDs: Set<UUID>, ordered: [UUID]? = nil) {
        let oldSelectedIDs = viewState.selectedObjectIDs
        let oldOrderedIDs = viewState.orderedSelectedObjectIDs
        guard newSelectedIDs != oldSelectedIDs else { return }
        let newOrderedIDs = ordered ?? Array(newSelectedIDs)
        let command = SelectionCommand(
            oldSelectedIDs: oldSelectedIDs,
            newSelectedIDs: newSelectedIDs,
            oldOrderedIDs: oldOrderedIDs,
            newOrderedIDs: newOrderedIDs
        )
        executeCommand(command)
    }

    func addToSelectionWithUndo(_ shapeID: UUID) {
        guard findObject(by: shapeID) != nil else { return }
        var newSelectedIDs = viewState.selectedObjectIDs
        newSelectedIDs.insert(shapeID)
        var newOrderedIDs = viewState.orderedSelectedObjectIDs
        if !newOrderedIDs.contains(shapeID) {
            newOrderedIDs.append(shapeID)
        }
        setSelectionWithUndo(newSelectedIDs, ordered: newOrderedIDs)
    }

    func removeFromSelectionWithUndo(_ shapeID: UUID) {
        var newSelectedIDs = viewState.selectedObjectIDs
        newSelectedIDs.remove(shapeID)
        var newOrderedIDs = viewState.orderedSelectedObjectIDs
        newOrderedIDs.removeAll { $0 == shapeID }
        setSelectionWithUndo(newSelectedIDs, ordered: newOrderedIDs)
    }

    func toggleSelectionWithUndo(_ shapeID: UUID) {
        if viewState.selectedObjectIDs.contains(shapeID) {
            removeFromSelectionWithUndo(shapeID)
        } else {
            addToSelectionWithUndo(shapeID)
        }
    }

    func clearSelectionWithUndo() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        setSelectionWithUndo([], ordered: [])
    }

    func selectShape(_ shapeID: UUID) {
        if let vectorObject = findObject(by: shapeID) {
            setSelectionWithUndo([vectorObject.id], ordered: [vectorObject.id])
        }
    }

    func addToSelection(_ shapeID: UUID) {
        if let vectorObject = findObject(by: shapeID) {
            addToSelectionWithUndo(vectorObject.id)
        }
    }

    func selectAll() {
        var objectIDsInLayers = Set<UUID>()
        for layer in snapshot.layers {
            for objectID in layer.objectIDs {
                objectIDsInLayers.insert(objectID)
            }
        }
        let visibleObjects = snapshot.objects.values.filter { object in
            guard objectIDsInLayers.contains(object.id) else { return false }
            guard object.isVisible && !object.isLocked else { return false }
            guard object.layerIndex < snapshot.layers.count else { return false }
            let layer = snapshot.layers[object.layerIndex]
            guard layer.isVisible && !layer.isLocked else { return false }
            guard object.layerIndex > 2 else { return false }
            switch object.objectType {
            case .shape(let shape),
                 .text(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    return false
                }
            }
            return true
        }
        if !visibleObjects.isEmpty {
            let sortedByArea = visibleObjects.sorted { obj1, obj2 in
                let bounds1 = obj1.shape.isGroupContainer ? obj1.shape.groupBounds : obj1.shape.bounds
                let bounds2 = obj2.shape.isGroupContainer ? obj2.shape.groupBounds : obj2.shape.bounds
                let area1 = bounds1.width * bounds1.height
                let area2 = bounds2.width * bounds2.height
                return area1 > area2
            }
            let orderedIDs = sortedByArea.map { $0.id }
            let selectedIDs = Set(visibleObjects.map { $0.id })
            setSelectionWithUndo(selectedIDs, ordered: orderedIDs)
        }
    }

    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        var newShapeIDs: Set<UUID> = []
        for objectID in viewState.selectedObjectIDs {
            guard let obj = snapshot.objects[objectID],
                  obj.layerIndex == layerIndex else { continue }
            switch obj.objectType {
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                var newShape = shape
                newShape.id = UUID()
                if ImageContentRegistry.containsImage(shape, in: self),

                   let image = ImageContentRegistry.image(for: shape.id, in: self) {
                    ImageContentRegistry.register(image: image, for: newShape.id, in: self)
                }
                let offsetTransform = CGAffineTransform(translationX: 10, y: 10)
                newShape = applyTransformToShapeCoordinates(shape: newShape, transform: offsetTransform)
                newShape.updateBounds()
                addShape(newShape, to: layerIndex)
                newShapeIDs.insert(newShape.id)
            case .text:
                break
            }
        }
        viewState.selectedObjectIDs = newShapeIDs
    }

    internal func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        if transform.isIdentity {
            return shape
        }
        let transformedPath = shape.path.applying(transform)

        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity
        return newShape
    }

    func addGuideShape(position: CGFloat, orientation: Guide.Orientation) {
        let guidesLayerIndex = 2
        guard guidesLayerIndex < snapshot.layers.count else { return }
        let lineLength: CGFloat = 100000
        let path: VectorPath
        switch orientation {
        case .horizontal:
            path = VectorPath(elements: [
                .move(to: VectorPoint(-lineLength / 2, position)),
                .line(to: VectorPoint(lineLength / 2, position))
            ], isClosed: false)
        case .vertical:
            path = VectorPath(elements: [
                .move(to: VectorPoint(position, -lineLength / 2)),
                .line(to: VectorPoint(position, lineLength / 2))
            ], isClosed: false)
        }
        let nonPhotoBlue = VectorColor.rgb(RGBColor(red: 164/255, green: 221/255, blue: 237/255))

        var guideShape = VectorShape(
            name: "Guide",
            path: path,
            geometricType: nil,
            strokeStyle: StrokeStyle(
                color: nonPhotoBlue,
                width: 1.0,
                placement: .center,
                opacity: 1.0
            ),
            fillStyle: nil
        )
        guideShape.isGuide = true
        guideShape.guideOrientation = orientation
        addShape(guideShape, to: guidesLayerIndex)
        viewState.selectedObjectIDs.removeAll()
        viewState.orderedSelectedObjectIDs.removeAll()
    }

    func clearGuides() {
        let guidesLayerIndex = 2
        guard guidesLayerIndex < snapshot.layers.count else { return }
        let guideIDs = snapshot.layers[guidesLayerIndex].objectIDs
        for guideID in guideIDs {
            if let object = snapshot.objects[guideID] {
                removeShapeFromUnifiedSystem(id: object.shape.id)
            }
        }
    }

    func getGuideShapes() -> [VectorShape] {
        let guidesLayerIndex = 2
        guard guidesLayerIndex < snapshot.layers.count else { return [] }
        return getShapesForLayer(guidesLayerIndex).filter { $0.isGuide }
    }
}
