import SwiftUI
import Foundation

enum PaintSelectionOperations {

    static func handleFillOpacityEditingComplete(_ opacity: Double, document: VectorDocument) {
        document.modifySelectedShapesWithUndo(
            preCapture: {
                document.defaultFillOpacity = opacity
                updateFillOpacityLive(opacity, document: document, isEditing: false)
                for objectID in document.viewState.selectedObjectIDs {
                    document.clearTextPreviewTypography(id: objectID)
                }
            }
        )
    }

    static func handleStrokeWidthEditingComplete(_ width: Double, document: VectorDocument) {
        document.modifySelectedShapesWithUndo(
            preCapture: {
                document.defaultStrokeWidth = width
                updateStrokeWidthLive(width, document: document, isEditing: false)
            }
        )
    }

    static func handleStrokeOpacityEditingComplete(_ opacity: Double, document: VectorDocument) {
        document.modifySelectedShapesWithUndo(
            preCapture: {
                document.defaultStrokeOpacity = opacity
                updateStrokeOpacityLive(opacity, document: document, isEditing: false)
            }
        )
    }

    static func handleMiterLimitEditingComplete(_ miterLimit: Double, document: VectorDocument) {
        document.modifySelectedShapesWithUndo(
            preCapture: {
                document.strokeDefaults.miterLimit = miterLimit
                updateStrokeMiterLimit(miterLimit, document: document)
            }
        )
    }

    static func updateFillOpacityLive(_ opacity: Double, document: VectorDocument, isEditing: Bool) {
        if isEditing {
            return
        }
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            affectedLayers.insert(object.layerIndex)
            switch object.objectType {
            case .text(let shape):
                document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    static func updateFillOpacity(_ opacity: Double, document: VectorDocument) {
        document.defaultFillOpacity = opacity
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]
        for objectID in document.viewState.selectedObjectIDs {
            if let obj = document.snapshot.objects[objectID] {
                switch obj.objectType {
                case .text(let shape):
                    oldOpacities[objectID] = shape.typography?.fillOpacity ?? 1.0
                    document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
                    newOpacities[objectID] = opacity
                case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                    oldOpacities[objectID] = shape.fillStyle?.opacity ?? 1.0
                    if let layerIndex = obj.layerIndex < document.snapshot.layers.count ? obj.layerIndex : nil,
                       document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                        document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
                    }
                    newOpacities[objectID] = opacity
                }
            }
        }
        if !oldOpacities.isEmpty {
            let command = OpacityCommand(
                objectIDs: Array(document.viewState.selectedObjectIDs),
                target: .fill,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            document.executeCommand(command)
        }
    }

    static func updateFillColor(_ color: VectorColor, opacity: Double? = nil, document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            affectedLayers.insert(object.layerIndex)
            switch object.objectType {
            case .text(let shape):
                document.updateTextFillColorInUnified(id: shape.id, color: color)
                if let opacity = opacity {
                    document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
                }
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                document.updateShapeFillColorInUnified(id: shape.id, color: color)
                if let opacity = opacity {
                    document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
                }
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    static func updateStrokeWidthLive(_ width: Double, document: VectorDocument, isEditing: Bool) {
        if isEditing {
            return
        }
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            affectedLayers.insert(object.layerIndex)
            switch object.objectType {
            case .text(let shape):
                if shape.typography?.hasStroke == true {
                    document.updateTextStrokeWidthInUnified(id: shape.id, width: width)
                }
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                document.updateShapeStrokeWidthInUnified(id: shape.id, width: width)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    static func updateStrokeOpacityLive(_ opacity: Double, document: VectorDocument, isEditing: Bool) {
        if isEditing {
            return
        }
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            affectedLayers.insert(object.layerIndex)
            switch object.objectType {
            case .text:
                break
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                document.updateShapeStrokeOpacityInUnified(id: shape.id, opacity: opacity)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    /// The selected objects with groups replaced by their (nested) members, so a style edit on a
    /// group reaches the shapes that are drawn.
    private static func selectedLeafIDs(document: VectorDocument) -> [UUID] {
        var result: [UUID] = []
        func visit(_ id: UUID) {
            guard let shape = document.snapshot.objects[id]?.shape else { return }
            if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                shape.memberIDs.forEach(visit)
            } else if !result.contains(id) {
                result.append(id)
            }
        }
        document.getActiveShapeIDs().forEach(visit)
        return result
    }

    static func updateStrokePlacement(_ placement: StrokePlacement, document: VectorDocument) {
        document.strokeDefaults.placement = placement
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        document.modifySelectedShapesWithUndo(preCapture: {
            for shapeID in activeShapeIDs {
                document.updateShapeStrokePlacementInUnified(id: shapeID, placement: placement)
            }
        })
    }

    static func updateStrokeLineJoin(_ lineJoin: CGLineJoin, document: VectorDocument) {
        document.strokeDefaults.lineJoin = lineJoin
        document.modifySelectedShapesWithUndo(preCapture: {
            for shapeID in selectedLeafIDs(document: document) {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .text:
                        document.updateTextStrokeLineJoin(id: shapeID, lineJoin: lineJoin)
                    default:
                        document.updateShapeStrokeLineJoinInUnified(id: shapeID, lineJoin: lineJoin)
                    }
                }
            }
        })
    }

    static func updateStrokeLineCap(_ lineCap: CGLineCap, document: VectorDocument) {
        document.strokeDefaults.lineCap = lineCap
        document.modifySelectedShapesWithUndo(preCapture: {
            for shapeID in selectedLeafIDs(document: document) {
                document.updateShapeStrokeLineCapInUnified(id: shapeID, lineCap: lineCap)
            }
        })
    }


    static func updateStrokeMiterLimitDirectNoUndo(_ miterLimit: Double, document: VectorDocument) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                document.updateShapeStrokeMiterLimitInUnified(id: shape.id, miterLimit: miterLimit)
            case .text:
                continue
            }
        }
    }

    static func updateStrokeMiterLimit(_ miterLimit: Double, document: VectorDocument) {
        document.strokeDefaults.miterLimit = miterLimit
        document.modifySelectedShapesWithUndo(preCapture: {
            for shapeID in selectedLeafIDs(document: document) {
                document.updateShapeStrokeMiterLimitInUnified(id: shapeID, miterLimit: miterLimit)
            }
        })
    }

    static func updateStrokeScaleWithTransform(_ scaleWithTransform: Bool, document: VectorDocument) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                document.updateShapeStrokeScaleWithTransformInUnified(id: shape.id, scaleWithTransform: scaleWithTransform)
            case .text:
                continue
            }
        }
    }

    /// Opacity of each selected image (the Image Properties slider's targets). Other selected
    /// objects are left out so the image slider never changes them.
    static func selectedImageOpacities(document: VectorDocument) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for objectID in document.viewState.selectedObjectIDs {
            guard let obj = document.snapshot.objects[objectID] else { continue }
            if case .text = obj.objectType { continue }
            let shape = obj.shape
            if ImageContentRegistry.containsImage(shape, in: document) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                result[objectID] = shape.opacity
            }
        }
        return result
    }

    /// Shows a slider value on the selected images while dragging, without an undo step.
    static func updateImageOpacityLive(_ opacity: Double, document: VectorDocument) {
        for id in selectedImageOpacities(document: document).keys {
            document.updateShapeOpacityInUnified(id: id, opacity: opacity)
        }
    }

    /// Ends a slider drag: one undo step from the opacities captured when it began (`start`)
    /// to `opacity`, or none if nothing changed.
    static func commitImageOpacity(_ opacity: Double, from start: [UUID: Double], document: VectorDocument) {
        let ids = Array(start.keys)
        for id in ids {
            document.updateShapeOpacityInUnified(id: id, opacity: start[id] ?? opacity)
        }
        guard ids.contains(where: { start[$0] != opacity }) else { return }
        document.modifyShapesWithUndo(shapeIDs: ids) { $0.opacity = opacity }
    }

    static func updateImageOpacity(_ opacity: Double, document: VectorDocument) {
        commitImageOpacity(opacity, from: selectedImageOpacities(document: document), document: document)
    }

    static func applyFillToSelectedShapes(fillColor: VectorColor, fillOpacity: Double, document: VectorDocument) {
        document.modifySelectedShapesWithUndo(preCapture: {
            for shapeID in selectedLeafIDs(document: document) {
                document.createFillStyleInUnified(id: shapeID, color: fillColor, opacity: fillOpacity)
            }
        })
    }

    static func duplicateSelectedShapes(document: VectorDocument) {
        var duplicatedIDs: [UUID] = []
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            affectedLayers.insert(object.layerIndex)
            let newID = UUID()

            var duplicatedShape = object.shape
            duplicatedShape.id = newID
            duplicatedShape.transform = duplicatedShape.transform.translatedBy(x: 20, y: 20)
            let duplicatedObject = VectorObject(shape: duplicatedShape, layerIndex: object.layerIndex)
            document.snapshot.objects[newID] = duplicatedObject
            if object.layerIndex < document.snapshot.layers.count {
                document.appendToLayer(layerIndex: object.layerIndex, objectID: newID)
            }
            duplicatedIDs.append(newID)
        }
        document.viewState.selectedObjectIDs = Set(duplicatedIDs)
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
