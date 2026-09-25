import Foundation
import Combine

class VisibilityCommand: BaseCommand {

    enum Property {
        case visibility
        case locked
    }
    private let objectIDs: [UUID]
    private let property: Property
    private let oldValues: [UUID: Bool]
    private let newValues: [UUID: Bool]

    init(objectIDs: [UUID], property: Property, oldValues: [UUID: Bool], newValues: [UUID: Bool]) {
        self.objectIDs = objectIDs
        self.property = property
        self.oldValues = oldValues
        self.newValues = newValues
    }

    override func execute(on document: VectorDocument) {
        applyValues(newValues, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyValues(oldValues, to: document)
    }

    private func applyValues(_ values: [UUID: Bool], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard var obj = document.snapshot.objects[id],
                  let value = values[id] else { continue }
            var updatedShape: VectorShape?
            var updatedObjectType: VectorObject.ObjectType?
            switch obj.objectType {
            case .shape(var shape),
                 .text(var shape),
                 .image(var shape),
                 .warp(var shape),
                 .group(var shape),
                 .clipGroup(var shape),
                 .clipMask(var shape),
                 .guide(var shape):
                switch property {
                case .visibility:
                    shape.isVisible = value
                case .locked:
                    shape.isLocked = value
                }
                updatedShape = shape
                updatedObjectType = VectorObject.determineType(for: shape)
            }
            if let _ = updatedShape, let objectType = updatedObjectType {
                obj = VectorObject(id: id, layerIndex: obj.layerIndex, objectType: objectType)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
