import Foundation

class LayerObjectOrderCommand: BaseCommand {
    private let layerIndex: Int
    private let oldObjectIDs: [UUID]
    private let newObjectIDs: [UUID]

    init(layerIndex: Int, oldObjectIDs: [UUID], newObjectIDs: [UUID]) {
        self.layerIndex = layerIndex
        self.oldObjectIDs = oldObjectIDs
        self.newObjectIDs = newObjectIDs
    }

    override func execute(on document: VectorDocument) {
        applyOrder(newObjectIDs, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyOrder(oldObjectIDs, to: document)
    }

    private func applyOrder(_ objectIDs: [UUID], to document: VectorDocument) {
        document.updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: objectIDs)
    }
}
