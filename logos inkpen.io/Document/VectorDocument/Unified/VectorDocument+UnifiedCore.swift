import SwiftUI

extension VectorDocument {

    func cleanupOrphanedObjects() {
        var validObjectIDs = Set<UUID>()
        for layer in snapshot.layers {
            for objectID in layer.objectIDs {
                validObjectIDs.insert(objectID)
            }
        }
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                collectMemberIDsRecursively(shape.memberIDs, into: &validObjectIDs)
            default:
                break
            }
        }
        let allObjectIDs = Set(snapshot.objects.keys)
        let orphanedIDs = allObjectIDs.subtracting(validObjectIDs)
        if !orphanedIDs.isEmpty {
            Log.info("🧹 Cleaning up \(orphanedIDs.count) orphaned object(s)", category: .general)
            for orphanID in orphanedIDs {
                snapshot.objects.removeValue(forKey: orphanID)
            }
        }
    }

    private func collectMemberIDsRecursively(_ memberIDs: [UUID], into validIDs: inout Set<UUID>) {
        for memberID in memberIDs {
            validIDs.insert(memberID)
            if let memberObject = snapshot.objects[memberID] {
                switch memberObject.objectType {
                case .group(let shape), .clipGroup(let shape):
                    collectMemberIDsRecursively(shape.memberIDs, into: &validIDs)
                default:
                    break
                }
            }
        }
    }

    func getShapeAtIndex(layerIndex: Int, shapeIndex: Int) -> VectorShape? {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return nil }
        return shapes[shapeIndex]
    }

    func getShapeCount(layerIndex: Int) -> Int {
        return getShapesForLayer(layerIndex).count
    }

    func setShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return }
        let objectType = VectorObject.determineType(for: shape)
        let updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        snapshot.objects[shape.id] = updatedObject
        triggerLayerUpdate(for: layerIndex)
    }

    func updateShapeByID(_ shapeID: UUID, silent: Bool = false, update: (inout VectorShape) -> Void) {
        if let object = snapshot.objects[shapeID] {
            let layerIndex = object.layerIndex

            var updatedObject = object
            switch object.objectType {
            case .text(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .shape(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .image(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .warp(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .group(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .clipGroup(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .clipMask(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            case .guide(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            }
            snapshot.objects[shapeID] = updatedObject
            if !silent {
                triggerLayerUpdate(for: layerIndex)
            }
            return
        }
        if let parentGroupID = snapshot.parentGroupCache[shapeID],

           let groupObject = snapshot.objects[parentGroupID] {
            switch groupObject.objectType {
            case .group(var groupShape), .clipGroup(var groupShape):
                if groupShape.isGroupContainer {
                    if let childIndex = groupShape.groupedShapes.firstIndex(where: { $0.id == shapeID }) {
                        var childShape = groupShape.groupedShapes[childIndex]
                        update(&childShape)
                        groupShape.groupedShapes[childIndex] = childShape
                        let layerIndex = groupObject.layerIndex
                        let updatedType: VectorObject.ObjectType
                        switch groupObject.objectType {
                        case .clipGroup:
                            updatedType = .clipGroup(groupShape)
                        default:
                            updatedType = .group(groupShape)
                        }
                        let updatedObject = VectorObject(id: groupShape.id, layerIndex: layerIndex, objectType: updatedType)
                        snapshot.objects[parentGroupID] = updatedObject
                        if !silent {
                            triggerLayerUpdate(for: layerIndex)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    func getShapesForLayer(_ layerIndex: Int) -> [VectorShape] {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return [] }
        let layer = snapshot.layers[layerIndex]
        return layer.objectIDs.compactMap { objectID in
            guard let object = snapshot.objects[objectID] else { return nil }
            switch object.objectType {
            case .shape(let shape):
                return shape
            case .image(let shape):
                return shape
            case .text(let shape):
                return shape
            case .group(let shape):
                return shape
            case .warp(let shape):
                return shape
            case .clipGroup(let shape):
                return shape
            case .clipMask(let shape):
                return shape
            case .guide(let shape):
                return shape
            }
        }
    }

    func addShapeToUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else {
            return
        }
        let objectType = VectorObject.determineType(for: shape)
        let vectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        if let existingObject = snapshot.objects[shape.id] {
            removeFromLayer(layerIndex: existingObject.layerIndex, objectID: shape.id)
        }
        snapshot.objects[shape.id] = vectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            appendToLayer(layerIndex: layerIndex, objectID: shape.id)
        } else {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let objectType = VectorObject.determineType(for: shape)
        let newVectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        snapshot.objects[shape.id] = newVectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            appendToLayer(layerIndex: layerIndex, objectID: shape.id)
        } else {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func addShapeBehindInUnifiedSystem(_ shape: VectorShape, layerIndex: Int, behindShapeIDs: Set<UUID>) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let objectType = VectorObject.determineType(for: shape)
        let newVectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        snapshot.objects[shape.id] = newVectorObject
        var insertIndex: Int?
        for (index, objectID) in snapshot.layers[layerIndex].objectIDs.enumerated() {
            if behindShapeIDs.contains(objectID) {
                insertIndex = index
                break
            }
        }
        if let insertIndex = insertIndex {
            insertIntoLayer(layerIndex: layerIndex, objectID: shape.id, at: insertIndex)
        } else {
            if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
                appendToLayer(layerIndex: layerIndex, objectID: shape.id)
            } else {
                triggerLayerUpdate(for: layerIndex)
            }
        }
    }

    func addTextToUnifiedSystem(_ text: VectorText, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        var textWithLayer = text
        textWithLayer.layerIndex = layerIndex
        let textShape = VectorShape.from(textWithLayer)
        let newVectorObject = VectorObject(id: textShape.id, layerIndex: layerIndex, objectType: .text(textShape))
        snapshot.objects[textShape.id] = newVectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(textShape.id) {
            appendToLayer(layerIndex: layerIndex, objectID: textShape.id)
        } else {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func rebuildParentGroupCache() {
        snapshot.parentGroupCache.removeAll()
        snapshot.clippedObjectsCache.removeAll()
        for (groupID, object) in snapshot.objects {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                if groupShape.isGroupContainer {
                    for childShape in groupShape.groupedShapes {
                        snapshot.parentGroupCache[childShape.id] = groupID
                    }
                }
            case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape):
                if shape.isClippingPath {
                    snapshot.clippedObjectsCache[shape.id] = []
                }
            default:
                continue
            }
        }
        for (objectID, object) in snapshot.objects {
            switch object.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                if let clippingPathID = shape.clippedByShapeID {
                    snapshot.clippedObjectsCache[clippingPathID, default: []].append(objectID)
                }
            default:
                continue
            }
        }
    }

    func updateParentCacheForGroup(_ groupID: UUID, childIDs: [UUID]) {
        for (childID, parentID) in snapshot.parentGroupCache where parentID == groupID {
            snapshot.parentGroupCache.removeValue(forKey: childID)
        }
        for childID in childIDs {
            snapshot.parentGroupCache[childID] = groupID
        }
    }

    func removeParentCacheForGroup(_ groupID: UUID) {
        snapshot.parentGroupCache = snapshot.parentGroupCache.filter { $0.value != groupID }
    }

    func removeParentCacheForChild(_ childID: UUID) {
        snapshot.parentGroupCache.removeValue(forKey: childID)
    }
}
