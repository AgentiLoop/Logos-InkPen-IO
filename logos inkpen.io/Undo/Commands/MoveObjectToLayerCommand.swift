import Foundation

class MoveObjectToLayerCommand: BaseCommand {
    private let moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]

    init(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int) {
        self.moves = [(objectID: objectID, oldLayerIndex: oldLayerIndex, newLayerIndex: newLayerIndex)]
    }

    init(moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]) {
        self.moves = moves
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for move in moves {
            applyMove(objectID: move.objectID, toLayerIndex: move.newLayerIndex, document: document)
            affectedLayers.insert(move.oldLayerIndex)
            affectedLayers.insert(move.newLayerIndex)
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
