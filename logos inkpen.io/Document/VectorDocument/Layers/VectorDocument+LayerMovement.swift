import SwiftUI

extension VectorDocument {

    func moveShapeToLayer(shapeId: UUID, fromLayerIndex: Int, toLayerIndex: Int) {
        guard fromLayerIndex >= 0 && fromLayerIndex < snapshot.layers.count,
              toLayerIndex >= 0 && toLayerIndex < snapshot.layers.count,
              fromLayerIndex != toLayerIndex else {
            Log.error("❌ Invalid layer indices for shape move: from=\(fromLayerIndex), to=\(toLayerIndex)", category: .error)
            return
        }
        if snapshot.layers[toLayerIndex].isLocked {
            return
        }
        if snapshot.layers[fromLayerIndex].isLocked {
            return
        }
        moveObjectToLayer(objectId: shapeId, targetLayerIndex: toLayerIndex)
        viewState.selectedObjectIDs = [shapeId]
        selectedLayerIndex = toLayerIndex
    }

    func moveTextToLayer(textId: UUID, toLayerIndex: Int) {
        guard toLayerIndex >= 0 && toLayerIndex < snapshot.layers.count else {
            Log.error("❌ Invalid layer index for text move: \(toLayerIndex)", category: .error)
            return
        }
        if snapshot.layers[toLayerIndex].isLocked {
            return
        }
        guard findText(by: textId) != nil else {
            Log.error("❌ Text object not found", category: .error)
            return
        }
        moveObjectToLayer(objectId: textId, targetLayerIndex: toLayerIndex)
        viewState.selectedObjectIDs = [textId]
        selectedLayerIndex = toLayerIndex
    }

    func handleObjectDrop(_ draggableObject: DraggableVectorObject, ontoLayerIndex: Int) {
        switch draggableObject.objectType {
        case .shape:
            moveShapeToLayer(
                shapeId: draggableObject.objectId,
                fromLayerIndex: draggableObject.sourceLayerIndex,
                toLayerIndex: ontoLayerIndex
            )
        case .text:
            moveTextToLayer(
                textId: draggableObject.objectId,
                toLayerIndex: ontoLayerIndex
            )
        }
    }
}
