import Foundation

class MoveObjectToLayerCommand: BaseCommand {
    private let moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]

    init(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int) {
        self.moves = [(objectID: objectID, oldLayerIndex: oldLayerIndex, newLayerIndex: newLayerIndex)]
    }

    init(moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]) {
        self.moves = moves
    }

    /// Object order of every affected layer before the move, so undo puts each object back at
    /// its old stacking position instead of on top of its old layer.
    private var layerOrderBefore: [Int: [UUID]] = [:]

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for move in moves {
            affectedLayers.insert(move.oldLayerIndex)
            affectedLayers.insert(move.newLayerIndex)
        }
        layerOrderBefore = [:]
        for layerIndex in affectedLayers where layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
            layerOrderBefore[layerIndex] = document.snapshot.layers[layerIndex].objectIDs
        }
        for move in moves {
            applyMove(objectID: move.objectID, toLayerIndex: move.newLayerIndex, document: document)
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for move in moves.reversed() {
            applyMove(objectID: move.objectID, toLayerIndex: move.oldLayerIndex, document: document)
            affectedLayers.insert(move.oldLayerIndex)
            affectedLayers.insert(move.newLayerIndex)
        }
        for (layerIndex, objectIDs) in layerOrderBefore where layerIndex < document.snapshot.layers.count {
            document.snapshot.layers[layerIndex].objectIDs = objectIDs
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func applyMove(objectID: UUID, toLayerIndex: Int, document: VectorDocument) {
        guard let object = document.snapshot.objects[objectID] else {
            return
        }
        let oldLayerIndex = object.layerIndex
        if oldLayerIndex >= 0 && oldLayerIndex < document.snapshot.layers.count {
            if let index = document.snapshot.layers[oldLayerIndex].objectIDs.firstIndex(of: objectID) {
                document.snapshot.layers[oldLayerIndex].objectIDs.remove(at: index)
            }
        }
        if toLayerIndex >= 0 && toLayerIndex < document.snapshot.layers.count {
            document.snapshot.layers[toLayerIndex].objectIDs.append(objectID)
        }
        switch object.objectType {
        case .text(let shape),
             .shape(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape),
             .guide(let shape):
            document.snapshot.objects[objectID] = VectorObject(
                shape: shape,
                layerIndex: toLayerIndex
            )
        }
        document.changeNotifier.notifyLayersChanged()
    }
}
