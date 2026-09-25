import SwiftUI
import Combine

extension ScaleHandles {

    func handleCornerScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            document.isHandleScalingActive = true
            initialBounds = bounds
            initialTransform = shape.transform
            startLocation = dragValue.startLocation
            scalingAnchorPoint = getAnchorPoint(for: document.viewState.scalingAnchor, in: bounds, cornerIndex: index)
        }
        let currentLocation = dragValue.location
        let anchorScreenX = scalingAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = scalingAnchorPoint.y * zoomLevel + canvasOffset.y
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        let baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let adaptiveMinDistanceX = min(20.0, max(2.0, abs(baseBounds.width) * 0.05))
        let adaptiveMinDistanceY = min(20.0, max(2.0, abs(baseBounds.height) * 0.05))
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1

        var scaleX = abs(startDistance.x) > adaptiveMinDistanceX ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        var scaleY = abs(startDistance.y) > adaptiveMinDistanceY ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)
        let isShiftCurrentlyPressed = NSEvent.modifierFlags.contains(.shift)
        if isShiftCurrentlyPressed {
            let uniformScale = max(scaleX, scaleY)
            scaleX = uniformScale
            scaleY = uniformScale
        }
        calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: scalingAnchorPoint)
    }

    func finishScaling() {
        scalingStarted = false
        isScaling = false
        document.isHandleScalingActive = false
        liveScaleDimensions = .zero
        liveScaleTransform = .identity
        var allShapeIDs: [UUID] = []
        var oldShapes: [UUID: VectorShape] = [:]
        collectShapesForUndo(shapeID: shape.id, into: &allShapeIDs, oldShapes: &oldShapes)
        if let vectorObject = document.findObject(by: shape.id),

        let layerIndex = vectorObject.layerIndex < document.snapshot.layers.count ? vectorObject.layerIndex : nil {
        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }),

           var updatedShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
            updatedShape.transform = initialTransform
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            previewTransform = .identity
            finalMarqueeBounds = .zero
            var newShapes: [UUID: VectorShape] = [:]
            for shapeID in allShapeIDs {
                if let transformedShape = document.findShape(by: shapeID) {
                    newShapes[shapeID] = transformedShape
                }
            }
            if !oldShapes.isEmpty && !newShapes.isEmpty {
                let command = ShapeModificationCommand(
                    objectIDs: allShapeIDs,
                    oldShapes: oldShapes,
                    newShapes: newShapes
                )
                document.executeCommand(command)
            }
            document.triggerLayerUpdate(for: layerIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.document.updateTransformPanelValues()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterScaling()
            }
        }
        } else {
            Log.error("❌ SCALING FAILED: Could not find shape in unified objects system", category: .error)
        }
    }

    private func collectShapesForUndo(shapeID: UUID, into ids: inout [UUID], oldShapes: inout [UUID: VectorShape]) {
        guard let object = document.findObject(by: shapeID) else { return }
        ids.append(shapeID)
        switch object.objectType {
        case .shape(let s), .image(let s), .warp(let s), .clipMask(let s), .guide(let s):
            oldShapes[shapeID] = s
        case .group(let s), .clipGroup(let s):
            oldShapes[shapeID] = s
            for memberID in s.memberIDs {
                collectShapesForUndo(shapeID: memberID, into: &ids, oldShapes: &oldShapes)
            }
        case .text:
            break
        }
    }

    func handleScalingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            startScalingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }
        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
        }
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        let anchorScreenX = scalingAnchorPoint.x * preciseZoom + canvasOffset.x
        let anchorScreenY = scalingAnchorPoint.y * preciseZoom + canvasOffset.y
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        let minDistance: CGFloat = 10.0
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1

        var scaleX = abs(startDistance.x) > minDistance ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        var scaleY = abs(startDistance.y) > minDistance ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)
        let isShiftCurrentlyPressed = NSEvent.modifierFlags.contains(.shift)
        if isShiftCurrentlyPressed {
            let uniformScale = max(scaleX, scaleY)
            scaleX = uniformScale
            scaleY = uniformScale
        }
        calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: scalingAnchorPoint)
    }

    func startScalingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        scalingStarted = true
        isScaling = true
        document.isHandleScalingActive = true
        initialBounds = bounds
        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
            setLockedPinPoint(nil)
        }
    }

    func calculatePreviewTransform(scaleX: CGFloat, scaleY: CGFloat, anchor: CGPoint) {
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        previewTransform = initialTransform.concatenating(scaleTransform)
        liveScaleTransform = previewTransform
        let newWidth = initialBounds.width * abs(scaleX)
        let newHeight = initialBounds.height * abs(scaleY)
        liveScaleDimensions = CGSize(width: newWidth, height: newHeight)
        let currentBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        finalMarqueeBounds = currentBounds.applying(scaleTransform)
        isScaling = true
    }
}
