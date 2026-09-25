import Foundation

class LayerReorderCommand: BaseCommand {
    private let sourceLayerId: UUID
    private let targetLayerId: UUID
    private let sourceIndex: Int
    private let targetIndex: Int
    private let affectedObjectUpdates: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]

    init(sourceLayerId: UUID, targetLayerId: UUID, sourceIndex: Int, targetIndex: Int, affectedObjectUpdates: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]) {
        self.sourceLayerId = sourceLayerId
        self.targetLayerId = targetLayerId
        self.sourceIndex = sourceIndex
        self.targetIndex = targetIndex
        self.affectedObjectUpdates = affectedObjectUpdates
    }

    override func execute(on document: VectorDocument) {
        applyReorder(forward: true, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyReorder(forward: false, to: document)
    }

    private func applyReorder(forward: Bool, to document: VectorDocument) {
        let fromIndex = forward ? sourceIndex : targetIndex
        let toIndex = forward ? targetIndex : sourceIndex
        guard fromIndex < document.snapshot.layers.count,
              toIndex <= document.snapshot.layers.count else {
            return
        }
        let snapshotLayer = document.snapshot.layers.remove(at: fromIndex)
        document.snapshot.layers.insert(snapshotLayer, at: toIndex)
        for update in affectedObjectUpdates {
            if var obj = document.snapshot.objects[update.objectID] {
                let newLayerIndex = forward ? update.newLayerIndex : update.oldLayerIndex
                switch obj.objectType {
                case .shape(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .text(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .image(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .group(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .clipGroup(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .warp(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .clipMask(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                case .guide(let shape):
                    obj = VectorObject(shape: shape, layerIndex: newLayerIndex)
                }
                document.snapshot.objects[update.objectID] = obj
            }
        }
        if document.selectedLayerIndex == fromIndex {
            document.selectedLayerIndex = toIndex
        } else if let selectedIndex = document.selectedLayerIndex {
            if fromIndex < toIndex {
                if selectedIndex > fromIndex && selectedIndex <= toIndex {
                    document.selectedLayerIndex = selectedIndex - 1
                }
            } else {
                if selectedIndex >= toIndex && selectedIndex < fromIndex {
                    document.selectedLayerIndex = selectedIndex + 1
                }
            }
        }
    }
}
