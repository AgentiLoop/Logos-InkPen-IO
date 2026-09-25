import SwiftUI

extension VectorDocument {

    func removeShapeFromUnifiedSystem(id: UUID) {
        guard let object = snapshot.objects[id] else { return }
        let layerIndex = object.layerIndex
        snapshot.objects.removeValue(forKey: id)
        if layerIndex >= 0 && layerIndex < snapshot.layers.count {
            snapshot.layers[layerIndex].objectIDs.removeAll { $0 == id }
        }
        ImageContentRegistry.remove(for: id, in: self)
        viewState.selectedObjectIDs.remove(id)
        if layerIndex >= 0 && layerIndex < snapshot.layers.count {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func removeTextFromUnifiedSystem(id: UUID) {
        guard let object = snapshot.objects[id] else { return }
        let layerIndex = object.layerIndex
        snapshot.objects.removeValue(forKey: id)
        if layerIndex >= 0 && layerIndex < snapshot.layers.count {
            snapshot.layers[layerIndex].objectIDs.removeAll { $0 == id }
        }
        viewState.selectedObjectIDs.remove(id)
        if layerIndex >= 0 && layerIndex < snapshot.layers.count {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func updateEntireTextInUnified(id: UUID, updater: (inout VectorText) -> Void) {
        guard let object = snapshot.objects[id] else { return }
        guard case .text(let shape) = object.objectType,
              var vectorText = VectorText.from(shape) else { return }
        updater(&vectorText)
        let updatedShape = VectorShape.from(vectorText)
        let layerIndex = object.layerIndex
        let updatedObject = VectorObject(
            shape: updatedShape,
            layerIndex: layerIndex
        )
        snapshot.objects[id] = updatedObject
        triggerLayerUpdate(for: layerIndex)
    }

    func getTextCount() -> Int {
        return snapshot.objects.values.filter { obj in
            if case .text = obj.objectType {
                return true
            }
            return false
        }.count
    }

    func hasTextObjects() -> Bool {
        return snapshot.objects.values.contains { obj in
            if case .text = obj.objectType {
                return true
            }
            return false
        }
    }

    func getTextByID(_ id: UUID) -> VectorText? {
        guard let object = snapshot.objects[id] else { return nil }
        guard case .text(let shape) = object.objectType,
              var vectorText = VectorText.from(shape) else { return nil }
        vectorText.layerIndex = object.layerIndex
        return vectorText
    }

    func getFirstText(where predicate: (VectorText) -> Bool) -> VectorText? {
        for object in snapshot.objects.values {
            if case .text(let shape) = object.objectType,

               var vectorText = VectorText.from(shape) {
                vectorText.layerIndex = object.layerIndex
                if predicate(vectorText) {
                    return vectorText
                }
            }
        }
        return nil
    }

    func removeAllText() {
        var affectedLayers = Set<Int>()
        for (id, object) in snapshot.objects {
            if case .text = object.objectType {
                affectedLayers.insert(object.layerIndex)
                snapshot.objects.removeValue(forKey: id)
                let layerIndex = object.layerIndex
                if layerIndex >= 0 && layerIndex < snapshot.layers.count {
                    snapshot.layers[layerIndex].objectIDs.removeAll { $0 == id }
                }
            }
        }
        triggerLayerUpdates(for: affectedLayers)
    }
}
