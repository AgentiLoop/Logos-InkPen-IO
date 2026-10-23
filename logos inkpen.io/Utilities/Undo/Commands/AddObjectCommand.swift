import Foundation

class AddObjectCommand: BaseCommand {
    /// Back to front: objects are stacked in this order.
    private let objectsToAdd: [VectorObject]

    init(objects: [VectorObject]) {
        self.objectsToAdd = objects
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for obj in objectsToAdd {
            let uuid = obj.id
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.objects[uuid] = obj
                if !document.snapshot.layers[layerIndex].objectIDs.contains(uuid) {
                    document.snapshot.layers[layerIndex].objectIDs.append(uuid)
                }
                affectedLayers.insert(layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for obj in objectsToAdd {
            let uuid = obj.id
            document.snapshot.objects.removeValue(forKey: uuid)
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == uuid }
                affectedLayers.insert(layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
