import SwiftUI

extension VectorDocument {

    private func expandSelectionForClippingMasks(_ selectedIDs: Set<UUID>, in layerObjects: [VectorObject]) -> Set<UUID> {
        var expandedSelectedIDs = selectedIDs
        for selectedID in selectedIDs {
            if let selectedObject = findObject(by: selectedID),
               case .shape(let selectedShape) = selectedObject.objectType {
                if selectedShape.isClippingPath {
                    for obj in layerObjects {
                        if case .shape(let shape) = obj.objectType,
                           shape.clippedByShapeID == selectedShape.id {
                            expandedSelectedIDs.insert(obj.id)
                        }
                    }
                }
                else if let maskID = selectedShape.clippedByShapeID {
                    if let maskObject = findObject(by: maskID) {
                        expandedSelectedIDs.insert(maskObject.id)
                        for obj in layerObjects {
                            if case .shape(let shape) = obj.objectType,
                               shape.clippedByShapeID == maskID {
                                expandedSelectedIDs.insert(obj.id)
                            }
                        }
                    }
                }
            }
        }
        return expandedSelectedIDs
    }

    func bringSelectedToFront() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        guard let selectedLayerIndex = selectedLayerIndex, selectedLayerIndex < snapshot.layers.count else { return }
        let layer = snapshot.layers[selectedLayerIndex]
        let oldObjectIDs = layer.objectIDs
        let selectedIDs = viewState.selectedObjectIDs
        let unselectedIDs = oldObjectIDs.filter { !selectedIDs.contains($0) }
        let selectedObjectIDs = oldObjectIDs.filter { selectedIDs.contains($0) }
        guard !selectedObjectIDs.isEmpty else { return }
        let newObjectIDs = unselectedIDs + selectedObjectIDs
        let command = LayerObjectOrderCommand(
            layerIndex: selectedLayerIndex,
            oldObjectIDs: oldObjectIDs,
            newObjectIDs: newObjectIDs
        )
        commandManager.execute(command)
    }

    func bringSelectedForward() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        guard let selectedLayerIndex = selectedLayerIndex, selectedLayerIndex < snapshot.layers.count else { return }
        let layer = snapshot.layers[selectedLayerIndex]
        let oldObjectIDs = layer.objectIDs

        var newObjectIDs = oldObjectIDs

        let selectedIDs = viewState.selectedObjectIDs
        for i in stride(from: newObjectIDs.count - 2, through: 0, by: -1) {
            let objectID = newObjectIDs[i]
            if selectedIDs.contains(objectID) && i < newObjectIDs.count - 1 {
                let nextID = newObjectIDs[i + 1]
                if !selectedIDs.contains(nextID) {
                    newObjectIDs.swapAt(i, i + 1)
                }
            }
        }
        guard newObjectIDs != oldObjectIDs else { return }
        let command = LayerObjectOrderCommand(
            layerIndex: selectedLayerIndex,
            oldObjectIDs: oldObjectIDs,
            newObjectIDs: newObjectIDs
        )
        commandManager.execute(command)
    }

    func sendSelectedBackward() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        guard let selectedLayerIndex = selectedLayerIndex, selectedLayerIndex < snapshot.layers.count else { return }
        let layer = snapshot.layers[selectedLayerIndex]
        let oldObjectIDs = layer.objectIDs

        var newObjectIDs = oldObjectIDs

        let selectedIDs = viewState.selectedObjectIDs
        for i in 1..<newObjectIDs.count {
            let objectID = newObjectIDs[i]
            if selectedIDs.contains(objectID) && i > 0 {
                let prevID = newObjectIDs[i - 1]
                if !selectedIDs.contains(prevID) {
                    newObjectIDs.swapAt(i, i - 1)
                }
            }
        }
        guard newObjectIDs != oldObjectIDs else { return }
        let command = LayerObjectOrderCommand(
            layerIndex: selectedLayerIndex,
            oldObjectIDs: oldObjectIDs,
            newObjectIDs: newObjectIDs
        )
        commandManager.execute(command)
    }

    func sendSelectedToBack() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        guard let selectedLayerIndex = selectedLayerIndex, selectedLayerIndex < snapshot.layers.count else { return }
        let layer = snapshot.layers[selectedLayerIndex]
        let oldObjectIDs = layer.objectIDs
        let selectedIDs = viewState.selectedObjectIDs
        let unselectedIDs = oldObjectIDs.filter { !selectedIDs.contains($0) }
        let selectedObjectIDs = oldObjectIDs.filter { selectedIDs.contains($0) }
        guard !selectedObjectIDs.isEmpty else { return }
        let newObjectIDs = selectedObjectIDs + unselectedIDs
        let command = LayerObjectOrderCommand(
            layerIndex: selectedLayerIndex,
            oldObjectIDs: oldObjectIDs,
            newObjectIDs: newObjectIDs
        )
        commandManager.execute(command)
    }
}
