import Foundation

extension VectorDocument {

    func addObjectToNewStructure(_ object: VectorObject, layerID: UUID) {
        guard let layerIndex = snapshot.layers.firstIndex(where: { $0.id == layerID }) else { return }
        let updatedObject = VectorObject(shape: object.shape, layerIndex: layerIndex)
        snapshot.objects[updatedObject.id] = updatedObject
        if !snapshot.layers[layerIndex].objectIDs.contains(updatedObject.id) {
            snapshot.layers[layerIndex].objectIDs.append(updatedObject.id)
        }
    }

    func removeObjectFromNewStructure(objectID: UUID) {
        snapshot.objects.removeValue(forKey: objectID)
        for index in snapshot.layers.indices {
            snapshot.layers[index].objectIDs.removeAll { $0 == objectID }
        }
    }

    func moveObjectInNewStructure(objectID: UUID, fromLayerID: UUID, toLayerID: UUID) {
        guard let fromIndex = snapshot.layers.firstIndex(where: { $0.id == fromLayerID }) else { return }
        guard let toIndex = snapshot.layers.firstIndex(where: { $0.id == toLayerID }) else { return }
        guard let object = snapshot.objects[objectID] else { return }
        let updatedObject = VectorObject(shape: object.shape, layerIndex: toIndex)
        snapshot.objects[objectID] = updatedObject
        snapshot.layers[fromIndex].objectIDs.removeAll { $0 == objectID }
        if !snapshot.layers[toIndex].objectIDs.contains(objectID) {
            snapshot.layers[toIndex].objectIDs.append(objectID)
        }
    }

    func reorderObjectInNewStructure(objectID: UUID, layerID: UUID, toIndex: Int) {
        guard let layerIndex = snapshot.layers.firstIndex(where: { $0.id == layerID }) else { return }
        guard let fromIndex = snapshot.layers[layerIndex].objectIDs.firstIndex(of: objectID) else { return }
        snapshot.layers[layerIndex].objectIDs.remove(at: fromIndex)
        let safeIndex = min(toIndex, snapshot.layers[layerIndex].objectIDs.count)
        snapshot.layers[layerIndex].objectIDs.insert(objectID, at: safeIndex)
    }

    func updateObjectInNewStructure(_ object: VectorObject) {
        snapshot.objects[object.id] = object
    }

    func findLayerContaining(objectID: UUID) -> UUID? {
        return snapshot.layers.first { $0.objectIDs.contains(objectID) }?.id
    }
}
