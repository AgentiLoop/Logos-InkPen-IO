import Foundation

class AddObjectCommand: BaseCommand {
    private let objectsToAdd: [UUID: VectorObject]

    init(objects: [VectorObject]) {
        var dict: [UUID: VectorObject] = [:]
        for obj in objects {
            dict[obj.id] = obj
        }
        self.objectsToAdd = dict
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for (uuid, obj) in objectsToAdd {
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
        for (uuid, obj) in objectsToAdd {
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
