import Foundation

class ObjectReorderCommand: BaseCommand {

    enum ReorderType {
        case moveObjectToLayer(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int, oldIndex: Int, newIndex: Int)
        case moveUp(objectIDs: [UUID], oldIndices: [UUID: Int], newIndices: [UUID: Int])
        case moveDown(objectIDs: [UUID], oldIndices: [UUID: Int], newIndices: [UUID: Int])
        case reorderBetween(sourceID: UUID, targetID: UUID, oldIndex: Int, newIndex: Int)
        case bringToFront(objectID: UUID, oldIndex: Int, newIndex: Int, layerIndex: Int)
        case sendToBack(objectID: UUID, oldIndex: Int, newIndex: Int, layerIndex: Int)
    }
    private let reorderType: ReorderType

    init(reorderType: ReorderType) {
        self.reorderType = reorderType
    }

    override func execute(on document: VectorDocument) {
        let affectedLayers = applyReorder(forward: true, to: document)
        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        let affectedLayers = applyReorder(forward: false, to: document)
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func applyReorder(forward: Bool, to document: VectorDocument) -> Set<Int> {
        var affectedLayers = Set<Int>()
        switch reorderType {
        case .moveObjectToLayer(let objectID, let oldLayerIndex, let newLayerIndex, let oldIndex, let newIndex):
            let sourceLayer = forward ? oldLayerIndex : newLayerIndex
            let targetLayer = forward ? newLayerIndex : oldLayerIndex
            let targetIndex = forward ? newIndex : oldIndex
            guard sourceLayer >= 0 && sourceLayer < document.snapshot.layers.count,
                  targetLayer >= 0 && targetLayer < document.snapshot.layers.count,
                  let obj = document.snapshot.objects[objectID] else { return affectedLayers }
            document.removeFromLayer(layerIndex: sourceLayer, objectID: objectID)
            let updatedObj = VectorObject(id: obj.id, layerIndex: targetLayer, objectType: obj.objectType)
            document.snapshot.objects[objectID] = updatedObj
            let insertIndex = min(targetIndex, document.snapshot.layers[targetLayer].objectIDs.count)
            document.insertIntoLayer(layerIndex: targetLayer, objectID: objectID, at: insertIndex)
            affectedLayers.insert(oldLayerIndex)
            affectedLayers.insert(newLayerIndex)
        case .moveUp(let objectIDs, let oldIndices, let newIndices):
            let indexDict = forward ? newIndices : oldIndices
            moveObjectsToIndices(objectIDs: objectIDs, targetIndices: indexDict, document: document)
            for id in objectIDs {
                if let obj = document.snapshot.objects[id] {
                    affectedLayers.insert(obj.layerIndex)
                }
            }
        case .moveDown(let objectIDs, let oldIndices, let newIndices):
            let indexDict = forward ? newIndices : oldIndices
            moveObjectsToIndices(objectIDs: objectIDs, targetIndices: indexDict, document: document)
            for id in objectIDs {
                if let obj = document.snapshot.objects[id] {
                    affectedLayers.insert(obj.layerIndex)
                }
            }
        case .reorderBetween(let sourceID, _, let oldIndex, let newIndex):
            let targetIndex = forward ? newIndex : oldIndex
            guard let obj = document.snapshot.objects[sourceID],
                  obj.layerIndex >= 0 && obj.layerIndex < document.snapshot.layers.count else { return affectedLayers }
            document.removeFromLayer(layerIndex: obj.layerIndex, objectID: sourceID)
            let insertIndex = min(targetIndex, document.snapshot.layers[obj.layerIndex].objectIDs.count)
            document.insertIntoLayer(layerIndex: obj.layerIndex, objectID: sourceID, at: insertIndex)
            affectedLayers.insert(obj.layerIndex)
        case .bringToFront(let objectID, let oldIndex, let newIndex, let layerIndex):
            let targetIndex = forward ? newIndex : oldIndex
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count,
                  document.snapshot.objects[objectID] != nil else { return affectedLayers }
            document.removeFromLayer(layerIndex: layerIndex, objectID: objectID)
            let insertIndex = min(targetIndex, document.snapshot.layers[layerIndex].objectIDs.count)
            document.insertIntoLayer(layerIndex: layerIndex, objectID: objectID, at: insertIndex)
            affectedLayers.insert(layerIndex)
        case .sendToBack(let objectID, let oldIndex, let newIndex, let layerIndex):
            let targetIndex = forward ? newIndex : oldIndex
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count,
                  document.snapshot.objects[objectID] != nil else { return affectedLayers }
            document.removeFromLayer(layerIndex: layerIndex, objectID: objectID)
            let insertIndex = min(targetIndex, document.snapshot.layers[layerIndex].objectIDs.count)
            document.insertIntoLayer(layerIndex: layerIndex, objectID: objectID, at: insertIndex)
            affectedLayers.insert(layerIndex)
        }
        return affectedLayers
    }

    private func moveObjectsToIndices(objectIDs: [UUID], targetIndices: [UUID: Int], document: VectorDocument) {
        var objectsByLayer: [Int: [(UUID, Int)]] = [:]
        for id in objectIDs {
            guard let obj = document.snapshot.objects[id],
                  let targetIndex = targetIndices[id] else { continue }
            objectsByLayer[obj.layerIndex, default: []].append((id, targetIndex))
        }
        for (layerIndex, idsAndIndices) in objectsByLayer {
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { continue }
            var layerObjectIDs = document.snapshot.layers[layerIndex].objectIDs

            let affectedIDs = Set(idsAndIndices.map { $0.0 })
            layerObjectIDs.removeAll { affectedIDs.contains($0) }
            let sorted = idsAndIndices.sorted { $0.1 < $1.1 }
            for (id, targetIdx) in sorted {
                let insertIndex = min(targetIdx, layerObjectIDs.count)
                layerObjectIDs.insert(id, at: insertIndex)
            }
            document.updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: layerObjectIDs)
        }
    }
}
