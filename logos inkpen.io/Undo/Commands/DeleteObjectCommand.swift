import Foundation
import Combine

class DeleteObjectCommand: BaseCommand {
    private let objectsToRestore: [UUID: VectorObject]

    private var originalPositions: [UUID: (layerIndex: Int, position: Int)] = [:]

    init(objectIDs: [UUID], document: VectorDocument) {
        var dict: [UUID: VectorObject] = [:]
        var positions: [UUID: (layerIndex: Int, position: Int)] = [:]
        for uuid in objectIDs {
            if let obj = document.snapshot.objects[uuid] {
                dict[uuid] = obj
                let layerIdx = obj.layerIndex
                if layerIdx >= 0 && layerIdx < document.snapshot.layers.count,

                   let pos = document.snapshot.layers[layerIdx].objectIDs.firstIndex(of: uuid) {
                    positions[uuid] = (layerIndex: layerIdx, position: pos)
                }
            }
        }
        self.objectsToRestore = dict
        self.originalPositions = positions
    }

    private init(objectsDict: [UUID: VectorObject]) {
        self.objectsToRestore = objectsDict
    }

    convenience init(objects: [VectorObject]) {
        var dict: [UUID: VectorObject] = [:]
        for obj in objects {
            dict[obj.id] = obj
        }
        self.init(objectsDict: dict)
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        let idsToRemove = Set(objectsToRestore.keys)

        var affectedLayers = Set<Int>()
        for (_, obj) in objectsToRestore {
            affectedLayers.insert(obj.layerIndex)
        }
        if originalPositions.isEmpty {
            for (uuid, obj) in objectsToRestore {
                let layerIdx = obj.layerIndex
                if layerIdx >= 0 && layerIdx < document.snapshot.layers.count,

                   let pos = document.snapshot.layers[layerIdx].objectIDs.firstIndex(of: uuid) {
                    originalPositions[uuid] = (layerIndex: layerIdx, position: pos)
                }
            }
        }
        for id in idsToRemove {
            document.snapshot.objects.removeValue(forKey: id)
        }
        for (uuid, obj) in objectsToRestore {
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == uuid }
            }
        }
        document.viewState.selectedObjectIDs = document.viewState.selectedObjectIDs.subtracting(idsToRemove)
        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        var affectedLayers = Set<Int>()

        let sortedRestores = objectsToRestore.sorted { a, b in
            let posA = originalPositions[a.key]?.position ?? Int.max
            let posB = originalPositions[b.key]?.position ?? Int.max
            return posA < posB
        }
        for (uuid, obj) in sortedRestores {
            document.snapshot.objects[uuid] = obj
            affectedLayers.insert(obj.layerIndex)
            if obj.layerIndex < document.snapshot.layers.count {
                if !document.snapshot.layers[obj.layerIndex].objectIDs.contains(uuid) {
                    if let pos = originalPositions[uuid]?.position {
                        let clampedPos = min(pos, document.snapshot.layers[obj.layerIndex].objectIDs.count)
                        document.snapshot.layers[obj.layerIndex].objectIDs.insert(uuid, at: clampedPos)
                    } else {
                        document.snapshot.layers[obj.layerIndex].objectIDs.append(uuid)
                    }
                }
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
