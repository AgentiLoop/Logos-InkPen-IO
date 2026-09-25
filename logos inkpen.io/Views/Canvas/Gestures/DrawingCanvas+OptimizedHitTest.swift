import SwiftUI

extension DrawingCanvas {

    internal func findObjectWithPathHitTest(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)
        return metalHitTest(at: validatedLocation) { object, point in
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true {
                return false
            }
            switch object.objectType {
            case .text(let textShape):
                let textBounds: CGRect
                if let position = textShape.textPosition, let size = textShape.areaSize {
                    textBounds = CGRect(origin: position, size: size)
                } else {
                    textBounds = CGRect(
                        x: textShape.transform.tx,
                        y: textShape.transform.ty,
                        width: textShape.bounds.width,
                        height: textShape.bounds.height
                    )
                }
                return textBounds.contains(point)
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performPathOnlyHitTest(shape: shape, at: point)
                }
            }
        }
    }

    internal func findObjectAtLocationOptimized(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)

        var groupedChildIDs = Set<UUID>()
        for obj in document.snapshot.objects.values {
            switch obj.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for memberID in groupShape.memberIDs {
                    groupedChildIDs.insert(memberID)
                }
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }
        let guidesLayerID = document.snapshot.layers.count > 2 ? document.snapshot.layers[2].id : nil
        let isGuidesLayerSelected = guidesLayerID != nil && document.settings.selectedLayerId == guidesLayerID
        return metalHitTest(at: validatedLocation) { object, point in
            if groupedChildIDs.contains(object.id) {
                return false
            }
            if isGuidesLayerSelected {
                if case .guide = object.objectType {
                } else {
                    return false
                }
            }
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true {
                return false
            }
            switch object.objectType {
            case .text(let textShape):
                let textBounds: CGRect
                if let position = textShape.textPosition, let size = textShape.areaSize {
                    textBounds = CGRect(origin: position, size: size)
                } else {
                    textBounds = CGRect(
                        x: textShape.transform.tx,
                        y: textShape.transform.ty,
                        width: textShape.bounds.width,
                        height: textShape.bounds.height
                    )
                }
                return textBounds.contains(point)
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performShapeHitTest(shape: shape, at: point)
                }
            }
        }
    }

    private func metalHitTest(at point: CGPoint, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        let candidates = spatialIndex.candidateObjectIDs(at: point)
        for layer in document.snapshot.layers.reversed() {
            guard layer.isVisible else { continue }
            for objectID in layer.objectIDs.reversed() {
                guard candidates.contains(objectID) else { continue }
                guard let object = document.snapshot.objects[objectID] else {
                    continue
                }
                if testFunction(object, point) {
                    return object
                }
            }
        }
        return nil
    }
}
