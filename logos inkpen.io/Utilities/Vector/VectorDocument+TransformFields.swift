import SwiftUI

/// Transform panel (X/Y/W/H, scale, rotate) edits, moved out of TransformationControls so they are unit-testable.
extension VectorDocument {

    private func transformPoint(_ point: CGPoint, currentOrigin: CGPoint, newOrigin: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        let dx = point.x - currentOrigin.x
        let dy = point.y - currentOrigin.y
        let scaledX = dx * scaleX
        let scaledY = dy * scaleY
        return CGPoint(x: scaledX + newOrigin.x, y: scaledY + newOrigin.y)
    }

    /// Bounds the transform fields (X/Y/W/H, scale, rotate) work on: union of the selected objects.
    func transformFieldSelectionBounds() -> CGRect? {
        guard !viewState.selectedObjectIDs.isEmpty else { return nil }
        var combinedBounds: CGRect?
        for vectorObject in snapshot.objects.values {
            switch vectorObject.objectType {
            case .text(let shape):
                if viewState.selectedObjectIDs.contains(shape.id) {
                    let position = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let shapeBounds = CGRect(
                        x: position.x,
                        y: position.y,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if viewState.selectedObjectIDs.contains(shape.id) {
                    let shapeBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                }
            }
        }
        return combinedBounds
    }

    /// X/Y/W/H fields of the transform panel, in points (X/Y relative to the page origin, at the transform origin).
    func applyTransformFields(x newX: CGFloat, y newY: CGFloat, width newWidth: CGFloat, height newHeight: CGFloat) {
        guard let currentBounds = transformFieldSelectionBounds(),
              newWidth > 0,
              newHeight > 0 else { return }
        let originOffset = viewState.transformOrigin.point
        let pageOrigin = settings.pageOrigin ?? .zero
        // The fields already show the selection's place and size: nothing to do, no undo step.
        guard newX + pageOrigin.x != currentBounds.minX + currentBounds.width * originOffset.x
                || newY + pageOrigin.y != currentBounds.minY + currentBounds.height * originOffset.y
                || newWidth != currentBounds.width || newHeight != currentBounds.height else { return }
        modifySelectedShapesWithUndo(
            preCapture: {
                let currentOriginX = currentBounds.minX + currentBounds.width * originOffset.x
                let currentOriginY = currentBounds.minY + currentBounds.height * originOffset.y
                let newOriginX = newX + pageOrigin.x
                let newOriginY = newY + pageOrigin.y
                let scaleX = newWidth / currentBounds.width
                let scaleY = newHeight / currentBounds.height
                for objectID in viewState.selectedObjectIDs {
                    // Groups keep their shapes as members: move/resize every member (nested too).
                    if let groupShape = snapshot.objects[objectID]?.shape,
                       groupShape.isGroupContainer && !groupShape.memberIDs.isEmpty {
                        let fieldTransform = CGAffineTransform(translationX: newOriginX, y: newOriginY)
                            .scaledBy(x: scaleX, y: scaleY)
                            .translatedBy(x: -currentOriginX, y: -currentOriginY)
                        applyTransformToGroup(groupID: objectID, transform: fieldTransform)
                        continue
                    }
                    if let newVectorObject = snapshot.objects[objectID],
                       case .shape(var shape) = newVectorObject.objectType {
                        if shape.isGroupContainer {
                            var transformedGroupedShapes: [VectorShape] = []
                            for var groupedShape in shape.groupedShapes {
                                var transformedElements: [PathElement] = []
                                for element in groupedShape.path.elements {
                                    switch element {
                                    case .move(let to):
                                        let pt = to.cgPoint
                                        let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.move(to: VectorPoint(newPt)))
                                    case .line(let to):
                                        let pt = to.cgPoint
                                        let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.line(to: VectorPoint(newPt)))
                                    case .curve(let to, let control1, let control2):
                                        let toPt = to.cgPoint
                                        let c1Pt = control1.cgPoint
                                        let c2Pt = control2.cgPoint
                                        let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        let newC1 = transformPoint(c1Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        let newC2 = transformPoint(c2Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.curve(to: VectorPoint(newTo),
                                                                         control1: VectorPoint(newC1),
                                                                         control2: VectorPoint(newC2)))
                                    case .quadCurve(let to, let control):
                                        let toPt = to.cgPoint
                                        let cPt = control.cgPoint
                                        let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        let newC = transformPoint(cPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                                             control: VectorPoint(newC)))
                                    case .close:
                                        transformedElements.append(.close)
                                    }
                                }
                                groupedShape.path.elements = transformedElements
                                groupedShape.updateBounds()
                                transformedGroupedShapes.append(groupedShape)
                            }
                            shape.groupedShapes = transformedGroupedShapes
                            shape.updateBounds()
                        } else if shape.typography != nil {
                            let currentPosition = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                            let newPosition = transformPoint(currentPosition,
                                                            currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                            newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                            scaleX: scaleX, scaleY: scaleY)
                            shape.textPosition = newPosition
                            shape.transform = CGAffineTransform(translationX: newPosition.x, y: newPosition.y)
                            if scaleX != 1.0 || scaleY != 1.0 {
                                let newWidth = shape.bounds.width * scaleX
                                let newHeight = shape.bounds.height * scaleY
                                shape.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
                                if let areaSize = shape.areaSize {
                                    shape.areaSize = CGSize(width: areaSize.width * scaleX, height: areaSize.height * scaleY)
                                }
                            }
                        } else {
                            var transformedElements: [PathElement] = []
                            for element in shape.path.elements {
                                switch element {
                                case .move(let to):
                                    let pt = to.cgPoint
                                    let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.move(to: VectorPoint(newPt)))
                                case .line(let to):
                                    let pt = to.cgPoint
                                    let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.line(to: VectorPoint(newPt)))
                                case .curve(let to, let control1, let control2):
                                    let toPt = to.cgPoint
                                    let c1Pt = control1.cgPoint
                                    let c2Pt = control2.cgPoint
                                    let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    let newC1 = transformPoint(c1Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    let newC2 = transformPoint(c2Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.curve(to: VectorPoint(newTo),
                                                                     control1: VectorPoint(newC1),
                                                                     control2: VectorPoint(newC2)))
                                case .quadCurve(let to, let control):
                                    let toPt = to.cgPoint
                                    let cPt = control.cgPoint
                                    let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    let newC = transformPoint(cPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                            newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                            scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                                         control: VectorPoint(newC)))
                                case .close:
                                    transformedElements.append(.close)
                                }
                            }
                            shape.path.elements = transformedElements
                            shape.updateBounds()
                        }
                        for layerIndex in snapshot.layers.indices {
                            let shapes = getShapesForLayer(layerIndex)
                            if let shapeIndex = shapes.firstIndex(where: { $0.id == objectID }) {
                                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                                if shape.typography != nil {
                                    if let position = shape.textPosition {
                                        updateTextPositionInUnified(id: shape.id, position: position)
                                    }
                                    if let areaSize = shape.areaSize {
                                        updateTextAreaSizeInUnified(id: shape.id, areaSize: areaSize)
                                    }
                                    updateTextBoundsInUnified(id: shape.id, bounds: shape.bounds)
                                }
                                triggerLayerUpdate(for: layerIndex)
                                break
                            }
                        }
                    }
                }
            }
        )
    }

    /// Scale fields of the transform panel, in percent, around the transform origin.
    func scaleSelection(percentX scaleX: CGFloat, percentY scaleY: CGFloat) {
        guard scaleX > 0, scaleY > 0,
              let currentBounds = transformFieldSelectionBounds() else { return }
        let scaleFactorX = scaleX / 100.0
        let scaleFactorY = scaleY / 100.0
        guard abs(scaleFactorX - 1.0) > 0.001 || abs(scaleFactorY - 1.0) > 0.001 else { return }
        let originOffset = viewState.transformOrigin.point
        let originX = currentBounds.minX + currentBounds.width * originOffset.x
        let originY = currentBounds.minY + currentBounds.height * originOffset.y
        modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in viewState.selectedObjectIDs {
                    if let vectorObject = snapshot.objects[objectID] {
                        var shape = vectorObject.shape
                        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                            let scaleTransform = CGAffineTransform(translationX: originX, y: originY)
                                .scaledBy(x: scaleFactorX, y: scaleFactorY)
                                .translatedBy(x: -originX, y: -originY)
                            applyTransformToGroup(groupID: shape.id, transform: scaleTransform)
                        } else if shape.isGroupContainer {
                            for i in shape.groupedShapes.indices {
                                var groupedShape = shape.groupedShapes[i]
                                scaleShapePath(&groupedShape, scaleX: scaleFactorX, scaleY: scaleFactorY, originX: originX, originY: originY)
                                shape.groupedShapes[i] = groupedShape
                            }
                            shape.updateBounds()
                            updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else if shape.typography != nil {
                            if let pos = shape.textPosition {
                                let newX = originX + (pos.x - originX) * scaleFactorX
                                let newY = originY + (pos.y - originY) * scaleFactorY
                                shape.textPosition = CGPoint(x: newX, y: newY)
                                shape.transform = CGAffineTransform(translationX: newX, y: newY)
                                shape.bounds = CGRect(x: 0, y: 0,
                                                     width: shape.bounds.width * scaleFactorX,
                                                     height: shape.bounds.height * scaleFactorY)
                                if let areaSize = shape.areaSize {
                                    shape.areaSize = CGSize(width: areaSize.width * scaleFactorX,
                                                           height: areaSize.height * scaleFactorY)
                                }
                            }
                            updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else {
                            scaleShapePath(&shape, scaleX: scaleFactorX, scaleY: scaleFactorY, originX: originX, originY: originY)
                            updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        }
                    }
                }
            }
        )
    }

    private func scaleShapePath(_ shape: inout VectorShape, scaleX: CGFloat, scaleY: CGFloat, originX: CGFloat, originY: CGFloat) {
        var scaledElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let newX = originX + (to.x - originX) * scaleX
                let newY = originY + (to.y - originY) * scaleY
                scaledElements.append(.move(to: VectorPoint(CGPoint(x: newX, y: newY))))
            case .line(let to):
                let newX = originX + (to.x - originX) * scaleX
                let newY = originY + (to.y - originY) * scaleY
                scaledElements.append(.line(to: VectorPoint(CGPoint(x: newX, y: newY))))
            case .curve(let to, let control1, let control2):
                let newToX = originX + (to.x - originX) * scaleX
                let newToY = originY + (to.y - originY) * scaleY
                let newC1X = originX + (control1.x - originX) * scaleX
                let newC1Y = originY + (control1.y - originY) * scaleY
                let newC2X = originX + (control2.x - originX) * scaleX
                let newC2Y = originY + (control2.y - originY) * scaleY
                scaledElements.append(.curve(
                    to: VectorPoint(CGPoint(x: newToX, y: newToY)),
                    control1: VectorPoint(CGPoint(x: newC1X, y: newC1Y)),
                    control2: VectorPoint(CGPoint(x: newC2X, y: newC2Y))
                ))
            case .quadCurve(let to, let control):
                let newToX = originX + (to.x - originX) * scaleX
                let newToY = originY + (to.y - originY) * scaleY
                let newCX = originX + (control.x - originX) * scaleX
                let newCY = originY + (control.y - originY) * scaleY
                scaledElements.append(.quadCurve(
                    to: VectorPoint(CGPoint(x: newToX, y: newToY)),
                    control: VectorPoint(CGPoint(x: newCX, y: newCY))
                ))
            case .close:
                scaledElements.append(.close)
            }
        }
        shape.path.elements = scaledElements
        shape.updateBounds()
    }

    /// Rotate field of the transform panel, in degrees, around the transform origin.
    func rotateSelection(degrees angle: CGFloat) {
        guard let currentBounds = transformFieldSelectionBounds() else { return }
        guard abs(angle) > 0.001 else { return }
        let radians = angle * .pi / 180.0
        let originOffset = viewState.transformOrigin.point
        let originX = currentBounds.minX + currentBounds.width * originOffset.x
        let originY = currentBounds.minY + currentBounds.height * originOffset.y
        modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in viewState.selectedObjectIDs {
                    if let vectorObject = snapshot.objects[objectID] {
                        var shape = vectorObject.shape
                        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                            let rotationTransform = CGAffineTransform(translationX: originX, y: originY)
                                .rotated(by: radians)
                                .translatedBy(x: -originX, y: -originY)
                            applyTransformToGroup(groupID: shape.id, transform: rotationTransform)
                        } else if shape.isGroupContainer {
                            for i in shape.groupedShapes.indices {
                                var groupedShape = shape.groupedShapes[i]
                                rotateShapePath(&groupedShape, radians: radians, originX: originX, originY: originY)
                                shape.groupedShapes[i] = groupedShape
                            }
                            shape.updateBounds()
                            updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else if shape.typography != nil {
                            if let pos = shape.textPosition {
                                let dx = pos.x - originX
                                let dy = pos.y - originY
                                let newX = originX + dx * cos(radians) - dy * sin(radians)
                                let newY = originY + dx * sin(radians) + dy * cos(radians)
                                shape.textPosition = CGPoint(x: newX, y: newY)
                                shape.transform = CGAffineTransform(translationX: newX, y: newY)
                            }
                            updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else {
                            rotateShapePath(&shape, radians: radians, originX: originX, originY: originY)
                            updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        }
                    }
                }
            }
        )
    }

    private func rotateShapePath(_ shape: inout VectorShape, radians: CGFloat, originX: CGFloat, originY: CGFloat) {
        var rotatedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let rotated = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.move(to: VectorPoint(rotated)))
            case .line(let to):
                let rotated = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.line(to: VectorPoint(rotated)))
            case .curve(let to, let control1, let control2):
                let rotatedTo = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                let rotatedC1 = rotatePoint(x: control1.x, y: control1.y, originX: originX, originY: originY, radians: radians)
                let rotatedC2 = rotatePoint(x: control2.x, y: control2.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.curve(
                    to: VectorPoint(rotatedTo),
                    control1: VectorPoint(rotatedC1),
                    control2: VectorPoint(rotatedC2)
                ))
            case .quadCurve(let to, let control):
                let rotatedTo = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                let rotatedC = rotatePoint(x: control.x, y: control.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.quadCurve(
                    to: VectorPoint(rotatedTo),
                    control: VectorPoint(rotatedC)
                ))
            case .close:
                rotatedElements.append(.close)
            }
        }
        shape.path.elements = rotatedElements
        shape.updateBounds()
    }

    private func rotatePoint(x: CGFloat, y: CGFloat, originX: CGFloat, originY: CGFloat, radians: CGFloat) -> CGPoint {
        let dx = x - originX
        let dy = y - originY
        let newX = originX + dx * cos(radians) - dy * sin(radians)
        let newY = originY + dx * sin(radians) + dy * cos(radians)
        return CGPoint(x: newX, y: newY)
    }
}
