import SwiftUI

extension VectorDocument {

    func lockTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isLocked = true
            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func unlockTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isLocked = false
            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func hideTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isVisible = false
            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func showTextInUnified(id: UUID) {
        if let obj = snapshot.objects[id],
           case .text(var shape) = obj.objectType {
            shape.isVisible = true
            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: obj.layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }

    func updateTextFillOpacityInUnified(id: UUID, opacity: Double) {
        updateShapeByID(id) { shape in
            shape.typography?.fillOpacity = opacity
        }
    }

    func updateTextStrokeWidthInUnified(id: UUID, width: Double) {
        updateShapeByID(id) { shape in
            shape.typography?.strokeWidth = width
            shape.typography?.hasStroke = width > 0
        }
    }

    func updateTextStrokeLineJoin(id: UUID, lineJoin: CGLineJoin) {
        updateShapeByID(id) { shape in
            shape.typography?.strokeLineJoin = LineJoin(lineJoin)
        }
    }

    func translateTextInUnified(id: UUID, delta: CGPoint) {
        updateShapeByID(id) { shape in
            shape.transform.tx += delta.x
            shape.transform.ty += delta.y
            if let textPos = shape.textPosition {
                shape.textPosition = textPos.adding(delta)
            }
        }
    }

    func translateAllTextInUnified(delta: CGPoint) {
        let textIDs = snapshot.objects.values.compactMap { obj -> UUID? in
            if case .text(let shape) = obj.objectType {
                return shape.id
            }
            return nil
        }
        for textID in textIDs {
            translateTextInUnified(id: textID, delta: delta)
        }
    }

    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        updateShapeByID(id) { shape in
            shape.isEditing = isEditing
        }
    }

    func updateTextLayerInUnified(id: UUID, layerIndex: Int) {
        if let obj = snapshot.objects[id],
           case .text(let shape) = obj.objectType {
            let updatedObject = VectorObject(
                id: shape.id,
                layerIndex: layerIndex,
                objectType: .text(shape)
            )
            snapshot.objects[id] = updatedObject
        }
    }
}
