import SwiftUI

extension VectorDocument {

    func lockSelectedObjects() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        let allIDs = viewState.selectedObjectIDs

        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]
        for id in allIDs {
            if let obj = snapshot.objects[id] {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    oldValues[id] = shape.isLocked
                    newValues[id] = true
                }
            }
        }
        let command = VisibilityCommand(
            objectIDs: Array(allIDs),
            property: .locked,
            oldValues: oldValues,
            newValues: newValues
        )
        executeCommand(command)
        viewState.selectedObjectIDs.removeAll()
    }

    func unlockAllObjects() {
        guard let layerIndex = selectedLayerIndex,
              layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        var affectedIDs: [UUID] = []
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        let layer = snapshot.layers[layerIndex]
        for objectID in layer.objectIDs {
            guard let obj = snapshot.objects[objectID] else { continue }
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if shape.isLocked {
                    affectedIDs.append(obj.id)
                    oldValues[obj.id] = true
                    newValues[obj.id] = false
                }
            }
        }
        if !affectedIDs.isEmpty {
            let command = VisibilityCommand(
                objectIDs: affectedIDs,
                property: .locked,
                oldValues: oldValues,
                newValues: newValues
            )
            executeCommand(command)
        }
    }

    func hideSelectedObjects() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        let allIDs = viewState.selectedObjectIDs

        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]
        for id in allIDs {
            if let obj = snapshot.objects[id] {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    oldValues[id] = shape.isVisible
                    newValues[id] = false
                }
            }
        }
        let command = VisibilityCommand(
            objectIDs: Array(allIDs),
            property: .visibility,
            oldValues: oldValues,
            newValues: newValues
        )
        executeCommand(command)
        viewState.selectedObjectIDs.removeAll()
    }

    func showAllObjects() {
        guard let layerIndex = selectedLayerIndex,
              layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        var affectedIDs: [UUID] = []
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        let layer = snapshot.layers[layerIndex]
        for objectID in layer.objectIDs {
            guard let obj = snapshot.objects[objectID] else { continue }
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if !shape.isVisible {
                    affectedIDs.append(shape.id)
                    oldValues[shape.id] = false
                    newValues[shape.id] = true
                    if case .text = obj.objectType {
                        showTextInUnified(id: shape.id)
                    } else {
                        let shapes = getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {
                            var updatedShape = shape
                            updatedShape.isVisible = true
                            setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                        }
                    }
                }
            }
        }
        if !affectedIDs.isEmpty {
            let command = VisibilityCommand(
                objectIDs: affectedIDs,
                property: .visibility,
                oldValues: oldValues,
                newValues: newValues
            )
            executeCommand(command)
        }
    }
}
