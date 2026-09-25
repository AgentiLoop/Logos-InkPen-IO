import SwiftUI
import Combine

extension VectorDocument {

    func renameLayer(at index: Int, to newName: String) {
        guard index >= 0 && index < snapshot.layers.count else {
            Log.error("❌ Invalid layer index for rename: \(index)", category: .error)
            return
        }
        if index == 0 && snapshot.layers[index].name == "Canvas" {
            return
        }
        snapshot.layers[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.selectedLayerId == snapshot.layers[index].id {
            settings.selectedLayerName = snapshot.layers[index].name
            onSettingsChanged()
        }
        changeNotifier.notifyLayersChanged()
    }

    func duplicateLayer(at index: Int) {
        guard index >= 0 && index < snapshot.layers.count else {
            Log.error("❌ Invalid layer index for duplicate: \(index)", category: .error)
            return
        }
        if index == 0 && snapshot.layers[index].name == "Canvas" {
            return
        }
        let originalLayer = snapshot.layers[index]
        let duplicatedLayer = Layer(
            id: UUID(),
            name: "\(originalLayer.name) Copy",
            objectIDs: [],
            isVisible: originalLayer.isVisible,
            isLocked: originalLayer.isLocked,
            opacity: originalLayer.opacity,
            blendMode: originalLayer.blendMode,
            color: originalLayer.color
        )
        snapshot.layers.insert(duplicatedLayer, at: index + 1)
        let originalShapes = getShapesForLayer(index)
        for shape in originalShapes {
            var duplicatedShape = shape
            duplicatedShape.id = UUID()
            if ImageContentRegistry.containsImage(shape, in: self),

               let image = ImageContentRegistry.image(for: shape.id, in: self) {
                ImageContentRegistry.register(image: image, for: duplicatedShape.id, in: self)
            }
            addShape(duplicatedShape, to: index + 1)
        }
        selectedLayerIndex = index + 1
        settings.selectedLayerId = duplicatedLayer.id
        settings.selectedLayerName = duplicatedLayer.name
        onSettingsChanged()
        changeNotifier.notifyLayersChanged()
    }

    func moveLayer(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < snapshot.layers.count,
              targetIndex >= 0 && targetIndex <= snapshot.layers.count,
              sourceIndex != targetIndex else { return }
        let movingLayer = snapshot.layers.remove(at: sourceIndex)
        let adjustedTargetIndex = (sourceIndex < targetIndex) ? targetIndex - 1 : targetIndex
        snapshot.layers.insert(movingLayer, at: adjustedTargetIndex)
        let affectedRange: ClosedRange<Int>
        if sourceIndex < adjustedTargetIndex {
            affectedRange = sourceIndex...adjustedTargetIndex
        } else {
            affectedRange = adjustedTargetIndex...sourceIndex
        }
        for layerIdx in affectedRange {
            guard layerIdx < snapshot.layers.count else { continue }
            for objectID in snapshot.layers[layerIdx].objectIDs {
                guard let object = snapshot.objects[objectID] else { continue }
                let currentLayerIndex = object.layerIndex

                var newLayerIndex = currentLayerIndex
                if currentLayerIndex == sourceIndex {
                    newLayerIndex = adjustedTargetIndex
                } else if sourceIndex < adjustedTargetIndex {
                    if currentLayerIndex > sourceIndex && currentLayerIndex <= adjustedTargetIndex {
                        newLayerIndex = currentLayerIndex - 1
                    }
                } else if sourceIndex > adjustedTargetIndex {
                    if currentLayerIndex >= adjustedTargetIndex && currentLayerIndex < sourceIndex {
                        newLayerIndex = currentLayerIndex + 1
                    }
                }
                if newLayerIndex != currentLayerIndex {
                    let updatedObject = VectorObject(id: object.id, layerIndex: newLayerIndex, objectType: object.objectType)
                    snapshot.objects[objectID] = updatedObject
                }
            }
        }
        if selectedLayerIndex == sourceIndex {
            selectedLayerIndex = adjustedTargetIndex
        } else if let selectedIndex = selectedLayerIndex {
            if sourceIndex < selectedIndex && adjustedTargetIndex >= selectedIndex {
                selectedLayerIndex = selectedIndex - 1
            } else if sourceIndex > selectedIndex && adjustedTargetIndex <= selectedIndex {
                selectedLayerIndex = selectedIndex + 1
            }
        }
        changeNotifier.notifyLayersChanged()
    }

    private func extractShape(from object: VectorObject) -> VectorShape {
        if case .shape(let shape) = object.objectType {
            return shape
        }
        fatalError("VectorObject does not contain a shape")
    }

    func addLayer(name: String = "New Layer") {
        let colors: [LayerColor] = [.gray, .blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        let color = colors[snapshot.layers.count % colors.count]

        var layerName = name
        if name == "New Layer" {
            var existingNumbers = Set<Int>()
            for layer in snapshot.layers {
                if layer.name.hasPrefix("Layer "),
                   let numberPart = layer.name.split(separator: " ").last,

                   let num = Int(numberPart) {
                    existingNumbers.insert(num)
                }
            }
            var layerNumber = 1
            while existingNumbers.contains(layerNumber) {
                layerNumber += 1
            }
            layerName = "Layer \(layerNumber)"
        }
        let newLayerID = UUID()
        if let currentIndex = selectedLayerIndex, currentIndex < snapshot.layers.count {
            let newLayerStruct = Layer(
                id: newLayerID,
                name: layerName,
                objectIDs: [],
                isVisible: true,
                isLocked: false,
                opacity: 1.0,
                blendMode: .normal,
                color: color
            )
            snapshot.layers.insert(newLayerStruct, at: currentIndex + 1)
            selectedLayerIndex = currentIndex + 1
            for layerIdx in (currentIndex + 2)..<snapshot.layers.count {
                for objectID in snapshot.layers[layerIdx].objectIDs {
                    if let object = snapshot.objects[objectID] {
                        let updatedObject = VectorObject(id: object.id, layerIndex: layerIdx, objectType: object.objectType)
                        snapshot.objects[objectID] = updatedObject
                    }
                }
            }
        } else {
            let newLayerStruct = Layer(
                id: newLayerID,
                name: layerName,
                objectIDs: [],
                isVisible: true,
                isLocked: false,
                opacity: 1.0,
                blendMode: .normal,
                color: color
            )
            snapshot.layers.append(newLayerStruct)
            selectedLayerIndex = snapshot.layers.count - 1
        }
        settings.selectedLayerId = newLayerID
        settings.selectedLayerName = layerName
        onSettingsChanged()
        changeNotifier.notifyLayersChanged()
    }

    func removeLayer(at index: Int) {
        guard index >= 0 && index < snapshot.layers.count && snapshot.layers.count > 1 else {
            return
        }
        let removingSelectedLayer = settings.selectedLayerId == snapshot.layers[index].id
        for objectID in snapshot.layers[index].objectIDs {
            snapshot.objects.removeValue(forKey: objectID)
            ImageContentRegistry.remove(for: objectID, in: self)
            viewState.selectedObjectIDs.remove(objectID)
        }
        snapshot.layers.remove(at: index)
        for layerIdx in index..<snapshot.layers.count {
            for objectID in snapshot.layers[layerIdx].objectIDs {
                if let object = snapshot.objects[objectID] {
                    let updatedObject = VectorObject(id: object.id, layerIndex: layerIdx, objectType: object.objectType)
                    snapshot.objects[objectID] = updatedObject
                }
            }
        }
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, snapshot.layers.count - 1)
        } else if let selected = selectedLayerIndex, selected > index {
            selectedLayerIndex = selected - 1
        }
        if removingSelectedLayer || settings.selectedLayerId == nil {
            validateSelectedLayer()
        }
        changeNotifier.notifyLayersChanged()
    }

    func ensureGuidesLayerExists() {
        if snapshot.layers.count > 2 && snapshot.layers[2].name == "Guides" {
            return
        }
        guard snapshot.layers.count >= 2 else { return }
        let guidesLayer = Layer(
            id: UUID(),
            name: "Guides",
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .cyan
        )
        snapshot.layers.insert(guidesLayer, at: 2)
        for layerIdx in 3..<snapshot.layers.count {
            for objectID in snapshot.layers[layerIdx].objectIDs {
                if let object = snapshot.objects[objectID] {
                    let updatedObject = VectorObject(id: object.id, layerIndex: layerIdx, objectType: object.objectType)
                    snapshot.objects[objectID] = updatedObject
                }
            }
        }
    }

    func validateSelectedLayer() {
        if let savedId = settings.selectedLayerId,
           snapshot.layers.first(where: { $0.id == savedId }) != nil {
            if let index = snapshot.layers.firstIndex(where: { $0.id == savedId }) {
                selectedLayerIndex = index
                layerIndex = index
            }
            return
        }
        if let layer1Index = snapshot.layers.firstIndex(where: { $0.name == "Layer 1" }) {
            let layer1 = snapshot.layers[layer1Index]
            settings.selectedLayerId = layer1.id
            settings.selectedLayerName = layer1.name
            selectedLayerIndex = layer1Index
            layerIndex = layer1Index
            onSettingsChanged()
            return
        }
        for (index, layer) in snapshot.layers.enumerated() {
            if layer.name != "Canvas" && layer.name != "Pasteboard" && layer.name != "Guides" && !layer.isLocked {
                settings.selectedLayerId = layer.id
                settings.selectedLayerName = layer.name
                selectedLayerIndex = index
                layerIndex = index
                onSettingsChanged()
                return
            }
        }
        if snapshot.layers.count <= 3 {
            addLayer(name: "Layer 1")
        }
    }

    func moveObjectToLayer(objectId: UUID, targetLayerIndex: Int) {
        guard let object = snapshot.objects[objectId] else {
            Log.error("❌ Object not found for layer move: \(objectId)", category: .error)
            return
        }
        guard targetLayerIndex >= 0 && targetLayerIndex < snapshot.layers.count else {
            Log.error("❌ Invalid target layer index: \(targetLayerIndex)", category: .error)
            return
        }
        let finalTargetIndex = targetLayerIndex <= 2 ? 3 : targetLayerIndex
        let sourceLayerIndex = object.layerIndex
        if sourceLayerIndex == finalTargetIndex {
            return
        }
        let command = MoveObjectToLayerCommand(
            objectID: objectId,
            oldLayerIndex: sourceLayerIndex,
            newLayerIndex: finalTargetIndex
        )
        commandManager.execute(command)
    }

    func moveObjectsToLayer(objectIds: [UUID], targetLayerIndex: Int) {
        guard targetLayerIndex >= 0 && targetLayerIndex < snapshot.layers.count else {
            Log.error("❌ Invalid target layer index: \(targetLayerIndex)", category: .error)
            return
        }
        let finalTargetIndex = targetLayerIndex <= 2 ? 3 : targetLayerIndex

        var moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)] = []
        for objectId in objectIds {
            guard let object = snapshot.objects[objectId] else {
                continue
            }
            let sourceLayerIndex = object.layerIndex
            if sourceLayerIndex != finalTargetIndex {
                moves.append((objectID: objectId, oldLayerIndex: sourceLayerIndex, newLayerIndex: finalTargetIndex))
            }
        }
        if !moves.isEmpty {
            let command = MoveObjectToLayerCommand(moves: moves)
            commandManager.execute(command)
        }
    }

    func selectNextObjectUp() {
        let visibleObjects = snapshot.objects.values
            .filter { obj in
                if obj.layerIndex >= 0 && obj.layerIndex < snapshot.layers.count {
                    return snapshot.layers[obj.layerIndex].isVisible
                }
                return false
            }
            .sorted { obj1, obj2 in
                if obj1.layerIndex != obj2.layerIndex {
                    return obj1.layerIndex > obj2.layerIndex
                }
                return false
            }
        guard !visibleObjects.isEmpty else { return }
        if viewState.selectedObjectIDs.isEmpty,

           let firstObject = visibleObjects.first {
            viewState.selectedObjectIDs = [firstObject.id]
            return
        }
        guard let currentID = viewState.selectedObjectIDs.first,

              let currentIndex = visibleObjects.firstIndex(where: { $0.id == currentID }) else {
            if let firstObject = visibleObjects.first {
                viewState.selectedObjectIDs = [firstObject.id]
            }
            return
        }
        let nextIndex = (currentIndex > 0) ? currentIndex - 1 : currentIndex
        viewState.selectedObjectIDs = [visibleObjects[nextIndex].id]
    }

    func selectNextObjectDown() {
        let visibleObjects = snapshot.objects.values
            .filter { obj in
                if obj.layerIndex >= 0 && obj.layerIndex < snapshot.layers.count {
                    return snapshot.layers[obj.layerIndex].isVisible
                }
                return false
            }
            .sorted { obj1, obj2 in
                if obj1.layerIndex != obj2.layerIndex {
                    return obj1.layerIndex > obj2.layerIndex
                }
                return false
            }
        guard !visibleObjects.isEmpty else { return }
        guard let lastObject = visibleObjects.last else { return }
        if viewState.selectedObjectIDs.isEmpty {
            viewState.selectedObjectIDs = [lastObject.id]
            return
        }
        guard let currentID = viewState.selectedObjectIDs.first,

              let currentIndex = visibleObjects.firstIndex(where: { $0.id == currentID }) else {
            viewState.selectedObjectIDs = [lastObject.id]
            return
        }
        let nextIndex = (currentIndex < visibleObjects.count - 1) ? currentIndex + 1 : currentIndex
        viewState.selectedObjectIDs = [visibleObjects[nextIndex].id]
    }

    func reorderObject(objectId: UUID, targetObjectId: UUID) {
        guard let sourceObject = snapshot.objects[objectId],

              let targetObject = snapshot.objects[targetObjectId] else {
            Log.error("❌ Objects not found for reordering", category: .error)
            return
        }
        guard sourceObject.layerIndex == targetObject.layerIndex else {
            return
        }
        let layerIndex = sourceObject.layerIndex
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        guard let sourceObjIndex = snapshot.layers[layerIndex].objectIDs.firstIndex(of: objectId),

              let targetObjIndex = snapshot.layers[layerIndex].objectIDs.firstIndex(of: targetObjectId) else {
            return
        }
        let draggingUp = sourceObjIndex > targetObjIndex

        var newObjectIDs = snapshot.layers[layerIndex].objectIDs
        newObjectIDs.remove(at: sourceObjIndex)
        if let newTargetIndex = newObjectIDs.firstIndex(of: targetObjectId) {
            let insertIndex = draggingUp ? newTargetIndex : newTargetIndex + 1
            newObjectIDs.insert(objectId, at: insertIndex)
        }
        updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: newObjectIDs)
        changeNotifier.notifyLayersChanged()
    }

    func reorderLayer(sourceLayerId: UUID, targetLayerId: UUID) {
        guard let sourceIndex = snapshot.layers.firstIndex(where: { $0.id == sourceLayerId }),

              let targetIndex = snapshot.layers.firstIndex(where: { $0.id == targetLayerId }) else {
            Log.error("❌ Layers not found for reordering", category: .error)
            return
        }
        guard sourceIndex != targetIndex else { return }
        var affectedObjectUpdates: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)] = []

        let newSourceIndex = targetIndex
        for (objectID, object) in snapshot.objects {
            let currentLayerIndex = object.layerIndex

            var newLayerIndex = currentLayerIndex
            if currentLayerIndex == sourceIndex {
                newLayerIndex = newSourceIndex
            } else if sourceIndex < targetIndex {
                if currentLayerIndex > sourceIndex && currentLayerIndex <= targetIndex {
                    newLayerIndex = currentLayerIndex - 1
                }
            } else {
                if currentLayerIndex >= targetIndex && currentLayerIndex < sourceIndex {
                    newLayerIndex = currentLayerIndex + 1
                }
            }
            if newLayerIndex != currentLayerIndex {
                affectedObjectUpdates.append((objectID: objectID, oldLayerIndex: currentLayerIndex, newLayerIndex: newLayerIndex))
            }
        }
        let command = LayerReorderCommand(
            sourceLayerId: sourceLayerId,
            targetLayerId: targetLayerId,
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            affectedObjectUpdates: affectedObjectUpdates
        )
        commandManager.execute(command)
    }
}
