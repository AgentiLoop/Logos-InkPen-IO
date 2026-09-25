import SwiftUI
import Combine

extension VectorDocument {

    func appendShapeToLayerUnified(layerIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func removeShapeByIdUnified(shapeID: UUID) {
        removeShapeFromUnifiedSystem(id: shapeID)
    }

    func removeShapesUnified(layerIndex: Int, where condition: (VectorShape) -> Bool) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let shapesToRemove = snapshot.objects.values.compactMap { obj -> UUID? in
            if obj.layerIndex == layerIndex,
               case .shape(let shape) = obj.objectType,
               condition(shape) {
                return shape.id
            }
            return nil
        }
        for shapeID in shapesToRemove {
            removeShapeFromUnifiedSystem(id: shapeID)
        }
    }

    func insertShapeUnified(layerIndex: Int, shape: VectorShape, at index: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func appendShapesUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        for shape in shapes {
            addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        }
    }

    func removeShapeAtIndexUnified(layerIndex: Int, shapeIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let shapesInLayer = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapesInLayer.count else { return }
        let shapeToRemove = shapesInLayer[shapeIndex]
        removeShapeFromUnifiedSystem(id: shapeToRemove.id)
    }

    func setShapesForLayerUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let existingShapes = getShapesForLayer(layerIndex)
        for shape in existingShapes {
            removeShapeFromUnifiedSystem(id: shape.id)
        }
        for shape in shapes {
            addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        }
    }
}
