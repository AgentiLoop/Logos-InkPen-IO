import SwiftUI
import Combine

extension DrawingCanvas {

    internal func handleSelectionTap(at location: CGPoint) {
        let validatedLocation = validateAndCorrectLocation(location)
        if isOptionPressed && document.viewState.currentTool == .selection {
            document.viewState.currentTool = .directSelection
            handleDirectSelectionTap(at: validatedLocation)
            return
        }
        if isControlPressed && document.viewState.currentTool == .selection {
            var clickedShape: VectorShape?
            for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
                let layer = document.snapshot.layers[layerIndex]
                if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                    continue
                }
                for objectID in layer.objectIDs.reversed() {
                    guard let object = document.snapshot.objects[objectID] else { continue }
                    switch object.objectType {
                    case .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape),
                         .guide(let shape):
                        if !shape.isVisible { continue }
                        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                        if isBackgroundShape { continue }
                        let isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                        if isHit {
                            clickedShape = shape
                            break
                        }
                    case .text:
                        continue
                    }
                }
                if clickedShape != nil {
                    break
                }
            }
            if let shape = clickedShape, isRectangleBasedShape(shape) {
                if !shape.isRoundedRectangle {
                }
                let previousSelection = document.viewState.selectedObjectIDs
                document.setSelectionWithUndo([shape.id], ordered: [shape.id])
                isCornerRadiusEditMode = true
                var affectedLayers = Set<Int>()
                for objectID in previousSelection {
                    if let object = document.snapshot.objects[objectID] {
                        affectedLayers.insert(object.layerIndex)
                    }
                }
                if let object = document.snapshot.objects[shape.id] {
                    affectedLayers.insert(object.layerIndex)
                }
                document.triggerLayerUpdates(for: affectedLayers)
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                selectedObjectIDs.removeAll()
                return
            } else if clickedShape != nil {
            }
        }
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        selectedObjectIDs.removeAll()
        isCornerRadiusEditMode = false
        guard document.viewState.currentTool == .selection ||
              document.viewState.currentTool == .scale ||
              document.viewState.currentTool == .rotate ||
              document.viewState.currentTool == .reflect ||
              document.viewState.currentTool == .shear ||
              document.viewState.currentTool == .warp else {
            if !isShiftPressed && !isCommandPressed {
                document.clearSelectionWithUndo()
            }
            return
        }
        if isCommandPressed {
            let objectsAtLocation = findAllObjectsAtLocation(validatedLocation)
            if !objectsAtLocation.isEmpty {
                let tolerance: CGFloat = 5.0
                let isSameLocation = abs(validatedLocation.x - selectBehindLocation.x) < tolerance &&
                                     abs(validatedLocation.y - selectBehindLocation.y) < tolerance
                if isSameLocation {
                    selectBehindIndex = (selectBehindIndex + 1) % objectsAtLocation.count
                } else {
                    selectBehindLocation = validatedLocation
                    let topObject = objectsAtLocation[0]
                    if document.viewState.selectedObjectIDs.contains(topObject.id) && objectsAtLocation.count > 1 {
                        selectBehindIndex = 1
                    } else {
                        selectBehindIndex = 0
                    }
                }
                let objectToSelect = objectsAtLocation[selectBehindIndex]
                let previousSelection = document.viewState.selectedObjectIDs
                document.setSelectionWithUndo([objectToSelect.id], ordered: [objectToSelect.id])
                var affectedLayers = Set<Int>()
                for objectID in previousSelection {
                    if let object = document.snapshot.objects[objectID] {
                        affectedLayers.insert(object.layerIndex)
                    }
                }
                affectedLayers.insert(objectToSelect.layerIndex)
                document.triggerLayerUpdates(for: affectedLayers)
                document.selectedLayerIndex = objectToSelect.layerIndex
                return
            }
        }
        let hitObject = findObjectAtLocationOptimized(validatedLocation)
        if !isCommandPressed {
            selectBehindIndex = 0
            selectBehindLocation = .zero
        }
        if let hitObject = hitObject {
            let objectToSelect = hitObject
            let previousSelection = document.viewState.selectedObjectIDs
            if isShiftPressed {
                document.addToSelectionWithUndo(objectToSelect.id)
            } else {
                document.setSelectionWithUndo([objectToSelect.id], ordered: [objectToSelect.id])
            }
            var affectedLayers = Set<Int>()
            for objectID in previousSelection {
                if let object = document.snapshot.objects[objectID] {
                    affectedLayers.insert(object.layerIndex)
                }
            }
            for objectID in document.viewState.selectedObjectIDs {
                if let object = document.snapshot.objects[objectID] {
                    affectedLayers.insert(object.layerIndex)
                }
            }
            document.triggerLayerUpdates(for: affectedLayers)
            if case .text = objectToSelect.objectType {
                document.viewState.transformOrigin = .topLeft
            }
            document.selectedLayerIndex = objectToSelect.layerIndex
            if let selectedColor = document.getSelectedObjectColor() {
                if document.viewState.activeColorTarget == .stroke {
                    document.defaultStrokeColor = selectedColor
                } else {
                    document.defaultFillColor = selectedColor
                }
            }
        } else {
            if !isShiftPressed && !isCommandPressed {
                let previousSelection = document.viewState.selectedObjectIDs
                document.clearSelectionWithUndo()
                var affectedLayers = Set<Int>()
                for objectID in previousSelection {
                    if let object = document.snapshot.objects[objectID] {
                        affectedLayers.insert(object.layerIndex)
                    }
                }
                document.triggerLayerUpdates(for: affectedLayers)
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                selectedObjectIDs.removeAll()
                syncDirectSelectionWithDocument()
                isCornerRadiusEditMode = false
            }
        }
    }

    internal func performPathOnlyHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        return performShapeHitTest(shape: shape, at: location)
    }

    internal func performShapeHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        if shape.typography != nil {
            let textBounds: CGRect
            if let position = shape.textPosition, let size = shape.areaSize {
                textBounds = CGRect(origin: position, size: size)
            } else {
                textBounds = CGRect(
                    x: shape.transform.tx,
                    y: shape.transform.ty,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
            }
            return textBounds.contains(location)
        }
        if shape.isGroupContainer {
            return shape.groupBounds.contains(location)
        }
        if shape.isGuide, let orientation = shape.guideOrientation {
            let guideTolerance: CGFloat = 5.0
            guard let firstElement = shape.path.elements.first,
                  case .move(let point) = firstElement else {
                return false
            }
            switch orientation {
            case .horizontal:
                let guideY = CGFloat(point.y)
                return abs(location.y - guideY) <= guideTolerance
            case .vertical:
                let guideX = CGFloat(point.x)
                return abs(location.x - guideX) <= guideTolerance
            }
        }
        let hitBounds = shape.bounds.applying(shape.transform)
        // Images, warps, clip groups, and compound containers keep box selection.
        let usesBoxHitTest = shape.embeddedImageData != nil || shape.linkedImagePath != nil ||
            shape.isWarpObject || shape.isClippingGroup || shape.isCompoundPath || shape.path.elements.isEmpty
        if usesBoxHitTest {
            return hitBounds.contains(location)
        }
        // Vector paths: hit the filled interior or near the stroke (Illustrator/Figma behavior)
        // instead of anywhere in the bounding box, which let thin diagonal lines and open
        // curves steal clicks meant for objects behind them.
        var transform = shape.transform
        guard let cgPath = shape.path.cgPath.copy(using: &transform) else {
            return hitBounds.contains(location)
        }
        let isFilled: Bool = {
            guard let fill = shape.fillStyle, fill.opacity > 0 else { return false }
            if case .clear = fill.color { return false }
            return true
        }()
        let strokeWidth = shape.strokeStyle.map { CGFloat($0.width) } ?? 0
        return HitTestMath.hits(
            path: cgPath,
            point: location,
            filled: isFilled,
            fillRule: shape.path.fillRule.cgPathFillRule,
            strokeWidth: strokeWidth,
            tolerance: HitTestMath.canvasTolerance(zoom: CGFloat(zoomLevel))
        )
    }

     internal func validateAndCorrectLocation(_ location: CGPoint) -> CGPoint {
         if location.x.isNaN || location.y.isNaN || location.x.isInfinite || location.y.isInfinite {
             Log.error("❌ INVALID COORDINATES: \(location) - using zero point", category: .error)
             return .zero
         }
         let maxReasonableValue: CGFloat = 1000000.0
         if abs(location.x) > maxReasonableValue || abs(location.y) > maxReasonableValue {
             Log.error("❌ EXTREME COORDINATES: \(location) - using zero point", category: .error)
             return .zero
         }
         return location
     }

    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }

    private func isLocationWithinSelectionBox(_ location: CGPoint) -> Bool {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                let textContentArea = CGRect(
                    x: CGPoint(x: shape.transform.tx, y: shape.transform.ty).x,
                    y: CGPoint(x: shape.transform.tx, y: shape.transform.ty).y,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
                let contains = textContentArea.contains(location)
                if contains {
                    return true
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                let transformedBounds = shape.bounds.applying(shape.transform)
                let selectionBoxBounds = transformedBounds.insetBy(dx: 0, dy: 0)
                let contains = selectionBoxBounds.contains(location)
                if contains {
                    return true
                }
            }
        }
        return false
    }

    private func findShapeByID(_ shapeID: UUID) -> VectorShape? {
        guard let object = document.snapshot.objects[shapeID] else { return nil }
        switch object.objectType {
        case .shape(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape),
             .guide(let shape):
            return shape
        case .text:
            return nil
        }
    }

    internal func findAllObjectsAtLocation(_ location: CGPoint) -> [VectorObject] {
        var results: [VectorObject] = []
        for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
            let layer = document.snapshot.layers[layerIndex]
            if layer.isLocked { continue }
            for objectID in layer.objectIDs.reversed() {
                guard let object = document.snapshot.objects[objectID] else { continue }
                let shape = object.shape
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    continue
                }
                if !shape.isVisible { continue }
                if performShapeHitTest(shape: shape, at: location) {
                    results.append(object)
                }
            }
        }
        return results
    }
}
