import SwiftUI
import Combine

extension VectorDocument {

    func unwrapWarpObject() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        var selectedWarpObjects: [VectorObject] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID],
               case .warp(let shape) = obj.objectType,
               shape.isWarpObject {
                selectedWarpObjects.append(obj)
            }
        }
        guard !selectedWarpObjects.isEmpty else { return }
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var affectedIDs: [UUID] = []
        var layerIndices: [UUID: Int] = [:]
        for obj in selectedWarpObjects {
            if case .warp(let shape) = obj.objectType {
                oldShapes[shape.id] = shape
                affectedIDs.append(shape.id)
                layerIndices[shape.id] = obj.layerIndex
                if let unwrappedShape = shape.unwrapWarpObject() {
                    newShapes[shape.id] = unwrappedShape
                }
            }
        }
        let command = WarpObjectCommand(
            affectedObjectIDs: affectedIDs,
            oldShapes: oldShapes,
            newShapes: newShapes,
            layerIndices: layerIndices
        )
        commandManager.execute(command)
    }

    func expandWarpObject() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        var selectedWarpObjects: [VectorObject] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID],
               case .warp(let shape) = obj.objectType,
               shape.isWarpObject {
                selectedWarpObjects.append(obj)
            }
        }
        guard !selectedWarpObjects.isEmpty else { return }
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var affectedIDs: [UUID] = []
        var layerIndices: [UUID: Int] = [:]
        for obj in selectedWarpObjects {
            if case .warp(let shape) = obj.objectType {
                oldShapes[shape.id] = shape
                affectedIDs.append(shape.id)
                layerIndices[shape.id] = obj.layerIndex
                if let expandedShape = shape.expandWarpObject() {
                    newShapes[shape.id] = expandedShape
                }
            }
        }
        let command = WarpObjectCommand(
            affectedObjectIDs: affectedIDs,
            oldShapes: oldShapes,
            newShapes: newShapes,
            layerIndices: layerIndices
        )
        commandManager.execute(command)
    }
}
