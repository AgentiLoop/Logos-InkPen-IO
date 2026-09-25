import Foundation
import Combine

class TextManagementCommand: BaseCommand {

    enum Operation {
        case addText(textID: UUID, shape: VectorShape, layerIndex: Int)
        case removeText(textIDs: [UUID], removedObjects: [UUID: VectorObject], removedPositions: [UUID: Int])
        case duplicateText(originalIDs: [UUID], duplicatedObjects: [UUID: VectorObject])
        case convertToOutlines(removedTextIDs: [UUID], removedObjects: [UUID: VectorObject], removedPositions: [UUID: Int], addedShapeIDs: [UUID], addedObjects: [UUID: VectorObject])
    }
    private let operation: Operation
    private let oldSelection: Set<UUID>
    private let newSelection: Set<UUID>

    init(operation: Operation, oldSelection: Set<UUID>, newSelection: Set<UUID>) {
        self.operation = operation
        self.oldSelection = oldSelection
        self.newSelection = newSelection
    }

    override func execute(on document: VectorDocument) {
        switch operation {
        case .addText(let textID, let shape, let layerIndex):
            let newObject = VectorObject(shape: shape, layerIndex: layerIndex)
            document.snapshot.objects[textID] = newObject
            if layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.append(textID)
            }
            document.viewState.selectedObjectIDs = [textID]
        case .removeText(let textIDs, _, _):
            for textID in textIDs {
                if let obj = document.snapshot.objects[textID] {
                    document.snapshot.objects.removeValue(forKey: textID)
                    if obj.layerIndex < document.snapshot.layers.count {
                        document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == textID }
                    }
                }
            }
            document.viewState.selectedObjectIDs = newSelection
        case .duplicateText(_, let duplicatedObjects):
            for (uuid, obj) in duplicatedObjects {
                document.snapshot.objects[uuid] = obj
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(uuid)
                }
            }
            document.viewState.selectedObjectIDs = newSelection
        case .convertToOutlines(let removedTextIDs, _, _, _, let addedObjects):
            for textID in removedTextIDs {
                if let obj = document.snapshot.objects[textID] {
                    document.snapshot.objects.removeValue(forKey: textID)
                    document.removeFromLayer(layerIndex: obj.layerIndex, objectID: textID)
                }
            }
            for (uuid, obj) in addedObjects {
                document.snapshot.objects[uuid] = obj
                document.appendToLayer(layerIndex: obj.layerIndex, objectID: uuid)
            }
            document.viewState.selectedObjectIDs = newSelection
        }
    }

    override func undo(on document: VectorDocument) {
        switch operation {
        case .addText(let textID, _, _):
            if let obj = document.snapshot.objects[textID] {
                document.snapshot.objects.removeValue(forKey: textID)
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == textID }
                }
            }
            document.viewState.selectedObjectIDs = oldSelection
        case .removeText(_, let removedObjects, let removedPositions):
            let sorted = removedObjects.sorted { a, b in
                (removedPositions[a.key] ?? Int.max) < (removedPositions[b.key] ?? Int.max)
            }
            for (uuid, obj) in sorted {
                document.snapshot.objects[uuid] = obj
                if obj.layerIndex < document.snapshot.layers.count {
                    if let originalPosition = removedPositions[uuid] {
                        let clampedPos = min(originalPosition, document.snapshot.layers[obj.layerIndex].objectIDs.count)
                        document.snapshot.layers[obj.layerIndex].objectIDs.insert(uuid, at: clampedPos)
                    } else {
                        document.snapshot.layers[obj.layerIndex].objectIDs.append(uuid)
                    }
                }
            }
            document.viewState.selectedObjectIDs = oldSelection
        case .duplicateText(_, let duplicatedObjects):
            for (uuid, obj) in duplicatedObjects {
                document.snapshot.objects.removeValue(forKey: uuid)
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == uuid }
                }
            }
            document.viewState.selectedObjectIDs = oldSelection
        case .convertToOutlines(_, let removedObjects, let removedPositions, let addedShapeIDs, _):
            for shapeID in addedShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    document.snapshot.objects.removeValue(forKey: shapeID)
                    document.removeFromLayer(layerIndex: obj.layerIndex, objectID: shapeID)
                }
            }
            for (uuid, obj) in removedObjects {
                document.snapshot.objects[uuid] = obj
                if let originalPosition = removedPositions[uuid],
                   obj.layerIndex < document.snapshot.layers.count {
                    document.insertIntoLayer(layerIndex: obj.layerIndex, objectID: uuid, at: originalPosition)
                } else {
                    document.appendToLayer(layerIndex: obj.layerIndex, objectID: uuid)
                }
            }
            document.viewState.selectedObjectIDs = oldSelection
        }
    }
}
