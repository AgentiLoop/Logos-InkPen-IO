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

    static func updateStrokePlacement(_ placement: StrokePlacement, document: VectorDocument) {
        document.strokeDefaults.placement = placement
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        var oldPlacements: [UUID: StrokePlacement] = [:]
        var newPlacements: [UUID: StrokePlacement] = [:]
        for shapeID in activeShapeIDs {
            if let obj = document.snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                    oldPlacements[shapeID] = shape.strokeStyle?.placement ?? .center
                    newPlacements[shapeID] = placement
                case .text:
                    continue
                }
            }
        }
        if !oldPlacements.isEmpty {
            let command = StrokePropertiesCommand(
                objectIDs: Array(activeShapeIDs),
                placement: oldPlacements,
                new: newPlacements
            )
            document.executeCommand(command)
        }
        for shapeID in activeShapeIDs {
            document.updateShapeStrokePlacementInUnified(id: shapeID, placement: placement)
        }
    }

    static func updateStrokeLineJoin(_ lineJoin: CGLineJoin, document: VectorDocument) {
        document.strokeDefaults.lineJoin = lineJoin
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            var oldLineJoins: [UUID: CGLineJoin] = [:]
            var newLineJoins: [UUID: CGLineJoin] = [:]
            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                        oldLineJoins[shapeID] = shape.strokeStyle?.lineJoin.cgLineJoin ?? .miter
                        newLineJoins[shapeID] = lineJoin
                    case .text(let shape):
                        oldLineJoins[shapeID] = shape.typography?.strokeLineJoin.cgLineJoin ?? .round
                        newLineJoins[shapeID] = lineJoin
                    }
                }
            }
            if !oldLineJoins.isEmpty {
                let command = StrokePropertiesCommand(
                    objectIDs: Array(activeShapeIDs),
                    lineJoin: oldLineJoins,
                    new: newLineJoins
                )
                document.executeCommand(command)
            }
            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .text:
                        document.updateTextStrokeLineJoin(id: shapeID, lineJoin: lineJoin)
                    default:
                        document.updateShapeStrokeLineJoinInUnified(id: shapeID, lineJoin: lineJoin)
                    }
                }
            }
        }
    }

    static func updateStrokeLineCap(_ lineCap: CGLineCap, document: VectorDocument) {
        document.strokeDefaults.lineCap = lineCap
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            var oldLineCaps: [UUID: CGLineCap] = [:]
            var newLineCaps: [UUID: CGLineCap] = [:]
            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                        oldLineCaps[shapeID] = shape.strokeStyle?.lineCap.cgLineCap ?? .butt
                        newLineCaps[shapeID] = lineCap
                    case .text:
                        continue
                    }
                }
            }
            if !oldLineCaps.isEmpty {
                let command = StrokePropertiesCommand(
                    objectIDs: Array(activeShapeIDs),
                    lineCap: oldLineCaps,
                    new: newLineCaps
                )
                document.executeCommand(command)
            }
            for shapeID in activeShapeIDs {
                document.updateShapeStrokeLineCapInUnified(id: shapeID, lineCap: lineCap)
            }
        }
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
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            var oldMiterLimits: [UUID: Double] = [:]
            var newMiterLimits: [UUID: Double] = [:]
            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                        oldMiterLimits[shapeID] = shape.strokeStyle?.miterLimit ?? 10.0
                        newMiterLimits[shapeID] = miterLimit
                    case .text:
                        continue
                    }
                }
            }
            if !oldMiterLimits.isEmpty {
                let command = StrokePropertiesCommand(
                    objectIDs: Array(activeShapeIDs),
                    miterLimit: oldMiterLimits,
                    new: newMiterLimits
                )
                document.executeCommand(command)
            }
            for shapeID in activeShapeIDs {
                document.updateShapeStrokeMiterLimitInUnified(id: shapeID, miterLimit: miterLimit)
            }
        }
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

    static func updateImageOpacity(_ opacity: Double, document: VectorDocument) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]
        for shapeID in document.viewState.selectedObjectIDs {
            if let obj = document.snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                    oldOpacities[shapeID] = shape.opacity
                    newOpacities[shapeID] = opacity
                case .text:
                    continue
                }
            }
        }
        if !oldOpacities.isEmpty {
            let command = StrokePropertiesCommand(
                objectIDs: Array(document.viewState.selectedObjectIDs),
                imageOpacity: oldOpacities,
                new: newOpacities
            )
            document.executeCommand(command)
        }
        for shapeID in document.viewState.selectedObjectIDs {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),

               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                if ImageContentRegistry.containsImage(shape, in: document) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                    document.updateShapeOpacityInUnified(id: shape.id, opacity: opacity)
                }
            }
        }
    }

    static func applyFillToSelectedShapes(fillColor: VectorColor, fillOpacity: Double, document: VectorDocument) {
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        var oldColors: [UUID: VectorColor] = [:]
        var newColors: [UUID: VectorColor] = [:]
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]
        for shapeID in activeShapeIDs {
            if let obj = document.snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                    oldColors[shapeID] = shape.fillStyle?.color ?? .black
                    newColors[shapeID] = fillColor
                    oldOpacities[shapeID] = shape.fillStyle?.opacity ?? 1.0
                    newOpacities[shapeID] = fillOpacity
                case .text:
                    continue
                }
            }
        }
        if !oldColors.isEmpty {
            let command = ChangeColorCommand(
                objectIDs: Array(activeShapeIDs),
                target: .fill,
                oldColors: oldColors,
                newColors: newColors,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            document.executeCommand(command)
        }
        for shapeID in activeShapeIDs {
            document.createFillStyleInUnified(id: shapeID, color: fillColor, opacity: fillOpacity)
        }
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
