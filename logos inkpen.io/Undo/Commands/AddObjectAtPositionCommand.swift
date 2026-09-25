import Foundation
import Combine

class AddObjectAtPositionCommand: BaseCommand {
    private let objectsToAdd: [UUID: VectorObject]
    private let insertPosition: InsertPosition

    enum InsertPosition {
        case front
        case back
        case afterSelection(Set<UUID>)
        case beforeSelection(Set<UUID>)
    }

    init(objects: [VectorObject], position: InsertPosition = .back) {
        var dict: [UUID: VectorObject] = [:]
        for obj in objects {
            dict[obj.id] = obj
        }
        self.objectsToAdd = dict
        self.insertPosition = position
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        var objectsByLayer: [Int: [(UUID, VectorObject)]] = [:]
        for (uuid, obj) in objectsToAdd {
            objectsByLayer[obj.layerIndex, default: []].append((uuid, obj))
        }
        for (layerIndex, layerObjects) in objectsByLayer {
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { continue }
            for (uuid, obj) in layerObjects {
                document.snapshot.objects[uuid] = obj
            }
            let insertIndex: Int
            switch insertPosition {
            case .front:
                insertIndex = document.snapshot.layers[layerIndex].objectIDs.count
            case .back:
                insertIndex = 0
            case .afterSelection(let selectedIDs):
                let objectIDs = document.snapshot.layers[layerIndex].objectIDs
                var maxIndex = -1
                for (index, objID) in objectIDs.enumerated() {
                    if selectedIDs.contains(objID) {
                        maxIndex = max(maxIndex, index)
                    }
                }
                insertIndex = maxIndex >= 0 ? maxIndex + 1 : document.snapshot.layers[layerIndex].objectIDs.count
            case .beforeSelection(let selectedIDs):
                let objectIDs = document.snapshot.layers[layerIndex].objectIDs
                var minIndex = Int.max
                for (index, objID) in objectIDs.enumerated() {
                    if selectedIDs.contains(objID) {
                        minIndex = min(minIndex, index)
                    }
                }
                insertIndex = minIndex == Int.max ? 0 : minIndex
            }
            for (uuid, _) in layerObjects.reversed() {
                if !document.snapshot.layers[layerIndex].objectIDs.contains(uuid) {
                    let safeIndex = min(insertIndex, document.snapshot.layers[layerIndex].objectIDs.count)
                    document.snapshot.layers[layerIndex].objectIDs.insert(uuid, at: safeIndex)
                }
            }
            affectedLayers.insert(layerIndex)
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
