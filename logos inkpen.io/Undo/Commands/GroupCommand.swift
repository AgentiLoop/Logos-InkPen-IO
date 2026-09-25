import Foundation

class GroupCommand: BaseCommand {

    enum GroupOperation {
        case group
        case ungroup
        case flatten
        case unflatten
        case makeCompound
        case releaseCompound
        case makeLooping
        case releaseLooping
        case pathOperation
    }
    private let operation: GroupOperation
    private let layerIndex: Int
    private let removedObjectIDs: [UUID]
    private let removedShapes: [UUID: VectorShape]
    private let addedObjectIDs: [UUID]
    private let addedShapes: [UUID: VectorShape]
    private let oldSelectedObjectIDs: Set<UUID>
    private let newSelectedObjectIDs: Set<UUID>
    private let originalLayerIndices: [UUID: Int]
    private let behindObjectIDs: Set<UUID>

    init(operation: GroupOperation,
         layerIndex: Int,
         removedObjectIDs: [UUID],
         removedShapes: [UUID: VectorShape],
         addedObjectIDs: [UUID],
         addedShapes: [UUID: VectorShape],
         oldSelectedObjectIDs: Set<UUID>,
         newSelectedObjectIDs: Set<UUID>,
         originalLayerIndices: [UUID: Int] = [:],
         behindObjectIDs: Set<UUID> = []) {
        self.operation = operation
        self.layerIndex = layerIndex
        self.removedObjectIDs = removedObjectIDs
        self.removedShapes = removedShapes
        self.addedObjectIDs = addedObjectIDs
        self.addedShapes = addedShapes
        self.oldSelectedObjectIDs = oldSelectedObjectIDs
        self.newSelectedObjectIDs = newSelectedObjectIDs
        self.originalLayerIndices = originalLayerIndices
        self.behindObjectIDs = behindObjectIDs
    }

    override func execute(on document: VectorDocument) {
        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }
        if !originalLayerIndices.isEmpty {
            var layerUpdates: [Int: [UUID]] = [:]
            for (objectID, origLayer) in originalLayerIndices {
                if origLayer != layerIndex && origLayer >= 0 && origLayer < document.snapshot.layers.count {
                    layerUpdates[origLayer, default: []].append(objectID)
                }
            }
            for (origLayerIdx, objectIDs) in layerUpdates {
                var layerObjectIDs = document.snapshot.layers[origLayerIdx].objectIDs
                layerObjectIDs.removeAll { objectIDs.contains($0) }
                document.updateLayerObjectIDs(layerIndex: origLayerIdx, newObjectIDs: layerObjectIDs)
            }
        }
        let insertionIndex: Int
        if !behindObjectIDs.isEmpty {
            insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { behindObjectIDs.contains($0) } ?? document.snapshot.layers[layerIndex].objectIDs.count
        } else {
            insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { removedObjectIDs.contains($0) }
                ?? document.snapshot.layers[layerIndex].objectIDs.count
        }
        var updatedObjectIDs = document.snapshot.layers[layerIndex].objectIDs
        updatedObjectIDs.removeAll { removedObjectIDs.contains($0) }
        switch operation {
        case .group:
            for (offset, objectID) in addedObjectIDs.enumerated() {
                guard let shape = addedShapes[objectID] else { continue }
                let newObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = newObject
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
                if shape.isGroup || shape.isClippingGroup {
                    let childIDs = shape.memberIDs.isEmpty ? shape.groupedShapes.map { $0.id } : shape.memberIDs
                    document.updateParentCacheForGroup(objectID, childIDs: childIDs)
                }
            }
        case .ungroup:
            for objectID in removedObjectIDs {
                document.snapshot.objects.removeValue(forKey: objectID)
                document.removeParentCacheForGroup(objectID)
            }
            for (offset, objectID) in addedObjectIDs.enumerated() {
                if let shape = addedShapes[objectID] {
                    let newObject = VectorObject(
                        shape: shape,
                        layerIndex: layerIndex
                    )
                    document.snapshot.objects[objectID] = newObject
                }
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }
        default:
            for objectID in removedObjectIDs {
                document.snapshot.objects.removeValue(forKey: objectID)
            }
            for (offset, objectID) in addedObjectIDs.enumerated() {
                guard let shape = addedShapes[objectID] else { continue }
                let newObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = newObject
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }
        }
        document.updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: updatedObjectIDs)
        document.viewState.selectedObjectIDs = newSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }

    override func undo(on document: VectorDocument) {
        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { addedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count
        var updatedObjectIDs = document.snapshot.layers[layerIndex].objectIDs
        updatedObjectIDs.removeAll { addedObjectIDs.contains($0) }
        switch operation {
        case .group:
            for id in addedObjectIDs {
                document.snapshot.objects.removeValue(forKey: id)
                document.removeParentCacheForGroup(id)
            }
            if !originalLayerIndices.isEmpty {
                var layerRestores: [Int: [UUID]] = [:]
                for objectID in removedObjectIDs {
                    let origLayer = originalLayerIndices[objectID] ?? layerIndex
                    layerRestores[origLayer, default: []].append(objectID)
                }
                for (origLayerIdx, objectIDs) in layerRestores {
                    guard origLayerIdx >= 0 && origLayerIdx < document.snapshot.layers.count else { continue }
                    if origLayerIdx == layerIndex {
                        for (offset, objectID) in objectIDs.enumerated() {
                            updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
                        }
                    } else {
                        var layerObjectIDs = document.snapshot.layers[origLayerIdx].objectIDs
                        layerObjectIDs.append(contentsOf: objectIDs)
                        document.updateLayerObjectIDs(layerIndex: origLayerIdx, newObjectIDs: layerObjectIDs)
                        document.triggerLayerUpdate(for: origLayerIdx)
                    }
                }
            } else {
                for (offset, objectID) in removedObjectIDs.enumerated() {
                    updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
                }
            }
        case .ungroup:
            for objectID in addedObjectIDs {
                if addedShapes[objectID] != nil {
                    document.snapshot.objects.removeValue(forKey: objectID)
                }
            }
            for (objectID, shape) in removedShapes {
                let restoredObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = restoredObject
                if shape.isGroup || shape.isClippingGroup {
                    let childIDs = shape.memberIDs.isEmpty ? shape.groupedShapes.map { $0.id } : shape.memberIDs
                    document.updateParentCacheForGroup(objectID, childIDs: childIDs)
                }
            }
            for (offset, objectID) in removedObjectIDs.enumerated() {
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }
        default:
            for id in addedObjectIDs {
                document.snapshot.objects.removeValue(forKey: id)
            }
            for (objectID, shape) in removedShapes {
                let restoredObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = restoredObject
            }
            for (offset, objectID) in removedObjectIDs.enumerated() {
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }
        }
        document.updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: updatedObjectIDs)
        document.viewState.selectedObjectIDs = oldSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }
}
