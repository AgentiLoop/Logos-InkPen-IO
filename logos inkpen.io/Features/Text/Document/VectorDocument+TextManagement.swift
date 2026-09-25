import SwiftUI
import CoreText
import AppKit
import Combine

extension VectorDocument {

    func addText(_ text: VectorText) {
        guard let layerIndex = selectedLayerIndex else { return }
        let oldSelection = viewState.selectedObjectIDs
        let shape = VectorShape.from(text)
        let command = TextManagementCommand(
            operation: .addText(textID: text.id, shape: shape, layerIndex: layerIndex),
            oldSelection: oldSelection,
            newSelection: [text.id]
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [text.id]
        viewState.selectedObjectIDs = [text.id]
    }

    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < snapshot.layers.count else {
            addText(text)
            return
        }
        let oldSelection = viewState.selectedObjectIDs

        var modifiedText = text
        modifiedText.layerIndex = layerIndex
        let shape = VectorShape.from(modifiedText)
        let command = TextManagementCommand(
            operation: .addText(textID: text.id, shape: shape, layerIndex: layerIndex),
            oldSelection: oldSelection,
            newSelection: [text.id]
        )
        commandManager.execute(command)
        viewState.orderedSelectedObjectIDs = [text.id]
        viewState.selectedObjectIDs = [text.id]
        selectedLayerIndex = layerIndex
    }

    func removeSelectedText() {
        let oldSelection = viewState.selectedObjectIDs

        var removedObjects: [UUID: VectorObject] = [:]
        var removedPositions: [UUID: Int] = [:]
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID],
               case .text = obj.objectType {
                removedObjects[objectID] = obj
                let layerIdx = obj.layerIndex
                if layerIdx >= 0 && layerIdx < snapshot.layers.count,

                   let pos = snapshot.layers[layerIdx].objectIDs.firstIndex(of: objectID) {
                    removedPositions[objectID] = pos
                }
            }
        }
        let command = TextManagementCommand(
            operation: .removeText(textIDs: Array(viewState.selectedObjectIDs), removedObjects: removedObjects, removedPositions: removedPositions),
            oldSelection: oldSelection,
            newSelection: []
        )
        commandManager.execute(command)
        viewState.selectedObjectIDs.removeAll()
    }

    func duplicateSelectedText() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        let oldSelection = viewState.selectedObjectIDs

        var newTextIDs: Set<UUID> = []
        var duplicatedObjects: [UUID: VectorObject] = [:]
        for textID in viewState.selectedObjectIDs {
            if let originalText = findText(by: textID),

               let obj = snapshot.objects[textID] {
                var duplicateText = originalText
                duplicateText.id = UUID()
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10,
                    y: originalText.position.y + 10
                )
                let shape = VectorShape.from(duplicateText)
                let layerIndex = obj.layerIndex
                let newObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .text(shape))
                duplicatedObjects[shape.id] = newObject
                newTextIDs.insert(duplicateText.id)
            }
        }
        let command = TextManagementCommand(
            operation: .duplicateText(originalIDs: Array(viewState.selectedObjectIDs), duplicatedObjects: duplicatedObjects),
            oldSelection: oldSelection,
            newSelection: newTextIDs
        )
        commandManager.execute(command)
        viewState.selectedObjectIDs = newTextIDs
    }

    func updateTextInUnified(_ updatedText: VectorText) {
        if let obj = snapshot.objects[updatedText.id],
           case .text = obj.objectType {
            let updatedShape = VectorShape.from(updatedText)
            let updatedObject = VectorObject(
                id: updatedShape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(updatedShape)
            )
            snapshot.objects[updatedText.id] = updatedObject
        }
    }

    func convertSelectedTextToOutlines() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        let selectedTexts = viewState.selectedObjectIDs.compactMap { textID -> VectorText? in
            guard let obj = snapshot.objects[textID],
                  case .text(let shape) = obj.objectType else { return nil }
            return VectorText.from(shape)
        }
        let oldSelection = viewState.selectedObjectIDs
        let removedTextIDs = Array(viewState.selectedObjectIDs)

        var removedTextObjects: [UUID: VectorObject] = [:]
        var removedPositions: [UUID: Int] = [:]
        for uuid in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[uuid] {
                removedTextObjects[uuid] = obj
                if let position = snapshot.layers[obj.layerIndex].objectIDs.firstIndex(of: uuid) {
                    removedPositions[uuid] = position
                }
            }
        }
        var newShapeIDs: Set<UUID> = []

        let shapesBefore = Set(snapshot.objects.keys.filter {
            if let obj = snapshot.objects[$0], case .shape = obj.objectType { return true }
            return false
        })
        for textObj in selectedTexts {
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: self)
            viewModel.convertToPath()
        }

        let shapesAfter = Set(snapshot.objects.keys.filter {
            if let obj = snapshot.objects[$0], case .shape = obj.objectType { return true }
            return false
        })
        newShapeIDs = shapesAfter.subtracting(shapesBefore)
        if !newShapeIDs.isEmpty {
            var addedShapeObjects: [UUID: VectorObject] = [:]
            for uuid in newShapeIDs {
                if let obj = snapshot.objects[uuid] {
                    addedShapeObjects[uuid] = obj
                }
            }
            let command = TextManagementCommand(
                operation: .convertToOutlines(
                    removedTextIDs: removedTextIDs,
                    removedObjects: removedTextObjects,
                    removedPositions: removedPositions,
                    addedShapeIDs: Array(newShapeIDs),
                    addedObjects: addedShapeObjects
                ),
                oldSelection: oldSelection,
                newSelection: newShapeIDs
            )
            commandManager.recordCompletedCommand(command)
            viewState.selectedObjectIDs = newShapeIDs
        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }
    }

    func updateTextContent(_ textID: UUID, content: String) {
        updateTextContentInUnified(id: textID, content: content)
    }
}
