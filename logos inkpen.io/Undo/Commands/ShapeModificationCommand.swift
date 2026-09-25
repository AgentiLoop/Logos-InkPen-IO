import Foundation
import Combine

class ShapeModificationCommand: BaseCommand {
    private let objectIDs: [UUID]
    private let oldShapes: [UUID: VectorShape]
    private let newShapes: [UUID: VectorShape]

    init(objectIDs: [UUID],
         oldShapes: [UUID: VectorShape],
         newShapes: [UUID: VectorShape]) {
        self.objectIDs = objectIDs
        self.oldShapes = oldShapes
        self.newShapes = newShapes
    }

    override func execute(on document: VectorDocument) {
        applyShapes(newShapes, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyShapes(oldShapes, to: document)
    }

    private func applyShapes(_ shapes: [UUID: VectorShape], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            if let shape = shapes[id] {
                document.updateShapeByID(id, silent: true) { existingShape in
                    existingShape = shape
                }
                if let obj = document.snapshot.objects[id] {
                    affectedLayers.insert(obj.layerIndex)
                }
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
