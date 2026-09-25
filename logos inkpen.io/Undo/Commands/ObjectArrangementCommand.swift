import Foundation
import Combine

class ObjectArrangementCommand: BaseCommand {
    private let affectedObjectIDs: [UUID]
    private let oldIndices: [UUID: Int]
    private let newIndices: [UUID: Int]

    init(affectedObjectIDs: [UUID],
         oldIndices: [UUID: Int],
         newIndices: [UUID: Int]) {
        self.affectedObjectIDs = affectedObjectIDs
        self.oldIndices = oldIndices
        self.newIndices = newIndices
    }

    override func execute(on document: VectorDocument) {
        applyIndices(newIndices, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyIndices(oldIndices, to: document)
    }

    private func applyIndices(_ targetIndices: [UUID: Int], to document: VectorDocument) {
        var objectsByLayer: [Int: [(UUID, Int)]] = [:]
        for id in affectedObjectIDs {
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
