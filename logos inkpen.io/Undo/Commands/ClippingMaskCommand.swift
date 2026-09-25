import Foundation

class ClippingMaskCommand: BaseCommand {

    enum Operation {
        case makeClippingMask(maskID: UUID, clippedShapeIDs: [UUID], oldShapes: [UUID: VectorShape], newShapes: [UUID: VectorShape])
        case releaseClippingMask(affectedShapeIDs: [UUID], oldShapes: [UUID: VectorShape], newShapes: [UUID: VectorShape])
        case moveClippingMask(maskID: UUID, clippedShapeIDs: [UUID], offset: CGPoint, oldShapes: [UUID: VectorShape], newShapes: [UUID: VectorShape])
    }
    private let operation: Operation

    init(operation: Operation) {
        self.operation = operation
    }

    override func execute(on document: VectorDocument) {
        switch operation {
        case .makeClippingMask(_, _, _, let newShapes),
             .releaseClippingMask(_, _, let newShapes),
             .moveClippingMask(_, _, _, _, let newShapes):
            applyShapes(newShapes, to: document)
        }
    }

    override func undo(on document: VectorDocument) {
        switch operation {
        case .makeClippingMask(_, _, let oldShapes, _),
             .releaseClippingMask(_, let oldShapes, _),
             .moveClippingMask(_, _, _, let oldShapes, _):
            applyShapes(oldShapes, to: document)
        }
    }

    private func applyShapes(_ shapes: [UUID: VectorShape], to document: VectorDocument) {
        for (id, shape) in shapes {
            if let obj = document.snapshot.objects[id] {
                document.snapshot.objects[id] = VectorObject(
                    shape: shape,
                    layerIndex: obj.layerIndex,
                )
            }
        }
    }
}
