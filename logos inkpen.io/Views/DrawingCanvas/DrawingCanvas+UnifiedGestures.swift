import SwiftUI
import AppKit

extension DrawingCanvas {

    internal func handleDoubleClick(at location: CGPoint, geometry: GeometryProxy) {
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        if let textID = findTextAt(location: canvasLocation) {
            document.viewState.currentTool = .font
            startEditingText(textID: textID, at: canvasLocation)
            isTextEditingMode = true
            #if os(macOS)
            NSCursor.iBeam.set()
            #endif
        }
    }

    internal func handleUnifiedTap(at location: CGPoint, geometry: GeometryProxy) {
        let modifierFlags = NSEvent.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isOptionPressed = modifierFlags.contains(.option)
        isCommandPressed = modifierFlags.contains(.command)
        isControlPressed = modifierFlags.contains(.control)
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        let currentTime = Date()
        let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
        let distanceFromLastClick = distance(location, lastClickLocation)
        let isDoubleClick = timeSinceLastClick < doubleClickTimeout && distanceFromLastClick < 10.0
        lastClickTime = currentTime
        lastClickLocation = location
        if isDoubleClick {
            handleDoubleClick(at: location, geometry: geometry)
            return
        }
        if document.viewState.currentTool != .bezierPen && isBezierDrawing {
            cancelBezierDrawing()
        }
        switch document.viewState.currentTool {
        case .selection, .scale, .rotate, .reflect, .shear, .warp:
            handleSelectionTap(at: canvasLocation)
        case .directSelection:
            handleDirectSelectionTap(at: canvasLocation)
        case .convertAnchorPoint:
            handleConvertAnchorPointTap(at: canvasLocation)
        case .penPlusMinus:
            handlePenPlusMinusTap(at: canvasLocation)
        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)
        case .font:
            if !isShiftPressed && !isCommandPressed {
                if let existingTextID = findTextAt(location: canvasLocation) {
                    startEditingText(textID: existingTextID, at: canvasLocation)
                } else {
                    document.viewState.selectedObjectIDs = []
                    handleAggressiveBackgroundTap(at: canvasLocation)
                }
            } else {
            }
        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            if !isShiftPressed && !isCommandPressed {
                document.viewState.selectedObjectIDs = []
            }
        case .zoom:
            #if os(macOS)
            MagnifyingGlassCursor.set()
            #endif
            let focalPoint = location
            let currentZoom = CGFloat(zoomLevel)
            let targetZoom: CGFloat
            if isOptionPressed {
                targetZoom = nextAllowedStepDown(from: currentZoom)
            } else {
                targetZoom = nextAllowedStepUp(from: currentZoom)
            }
            handleZoomAtPoint(newZoomLevel: targetZoom, focalPoint: focalPoint, geometry: geometry)
            #if os(macOS)
            if isCanvasHovering && document.viewState.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            DispatchQueue.main.async {
                if isCanvasHovering && document.viewState.currentTool == .zoom {
                    MagnifyingGlassCursor.set()
                }
            }
            #endif
        case .eyedropper:
            startEyedropperColorPick()
        case .selectSameColor:
            selectSameColorAt(canvasLocation)
        default:
            break
        }
    }

    internal func handleUnifiedDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        switch document.viewState.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)
        case .zoom:
            if zoomToolDragStartPoint == .zero {
                zoomToolDragStartPoint = value.startLocation
                zoomToolInitialZoomLevel = zoomLevel
                isActivelyZooming = true
            }
            let dragDelta = value.location.y - zoomToolDragStartPoint.y
            let zoomSensitivity: CGFloat = 0.01
            let zoomFactor = 1.0 - (dragDelta * zoomSensitivity)
            let targetZoom = zoomToolInitialZoomLevel * zoomFactor
            let clampedZoom = ZoomMath.clamp(targetZoom)
            let focalPoint = zoomToolDragStartPoint
            handleZoomAtPoint(newZoomLevel: clampedZoom, focalPoint: focalPoint, geometry: geometry)
        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            handleShapeDrawing(value: value, geometry: geometry)
        case .font:
            handleTextBoxDrawing(value: value, geometry: geometry)
        case .selection:
            handleUnifiedSelectionDrag(value: value, geometry: geometry)
        case .directSelection:
            handleDirectSelectionDrag(value: value, geometry: geometry)
        case .bezierPen:
            handleBezierPenDrag(value: value, geometry: geometry)
        case .freehand:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isFreehandDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleFreehandDragStart(at: startLocation)
            }
            handleFreehandDragUpdate(at: currentLocation)
        case .brush:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isBrushDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleBrushDragStart(at: startLocation)
            }
            handleBrushDragUpdate(at: currentLocation)
        case .marker:
            break
        case .scale, .rotate, .reflect, .shear, .warp:
            break
        default:
            break
        }
    }

    internal func handleUnifiedDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        switch document.viewState.currentTool {
        case .hand:
            finishPanGesture()
        case .zoom:
            zoomToolDragStartPoint = .zero
            isActivelyZooming = false
            #if os(macOS)
            if isCanvasHovering && document.viewState.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            #endif
        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            finishShapeDrawing(value: value, geometry: geometry)
            resetShapeDrawingState()
        case .font:
            finishTextBoxDrawing(value: value, geometry: geometry)
            resetTextBoxDrawingState()
        case .selection:
            finishSelectionDrag()
            isDrawing = false
            if document.isHandleScalingActive {
                document.isHandleScalingActive = false
            }
        case .directSelection:
            finishDirectSelectionDrag()
        case .bezierPen:
            finishBezierPenDrag()
        case .freehand:
            handleFreehandDragEnd()
        case .brush:
            handleBrushDragEnd()
        case .marker:
            break
        default:
            break
        }
    }

    private func handleUnifiedSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDrawing && !document.isHandleScalingActive {
            for objectID in document.viewState.selectedObjectIDs {
                if let vectorObject = document.findObject(by: objectID),
                   case .shape(let shape) = vectorObject.objectType {
                    if shape.name != "Canvas Background" && shape.name != "Pasteboard Background" {
                    }
                }
            }
        }
        if document.isHandleScalingActive {
            return
        }
        if isCornerRadiusEditMode {
            return
        }
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        if !isDrawing {
            let shouldPreserveSelection = isShiftPressed || isCommandPressed
            if document.viewState.selectedObjectIDs.isEmpty || !isDraggingSelectedObject(at: startLocation) {
                if !shouldPreserveSelection || document.viewState.selectedObjectIDs.isEmpty {
                    selectObjectAt(startLocation)
                }
            }
            if !document.viewState.selectedObjectIDs.isEmpty {
                selectionDragStart = value.startLocation
                startSelectionDrag()
                isDrawing = true
            }
        }
        if isDrawing {
            handleSelectionDrag(value: value, geometry: geometry)
        }
    }

    private func finishPanGesture() {
        handlePanGestureEnd()
        #if os(macOS)
        if isCanvasHovering && document.viewState.currentTool == .hand {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
        #endif
    }

    private func resetShapeDrawingState() {
        isDrawing = false
        currentPath = nil
        tempBoundingBoxPath = nil
        currentDrawingPoints.removeAll()
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
    }

    private func startEyedropperColorPick() {
        #if canImport(AppKit)
        let sampler = NSColorSampler()
        sampler.show { pickedColor in
            guard let displayP3Color = pickedColor?.usingColorSpace(.displayP3) else { return }
            let rgba = displayP3Color.cgColor.rgbaComponents
            let rgb = RGBColor(red: Double(rgba.r), green: Double(rgba.g), blue: Double(rgba.b), alpha: Double(rgba.a))
            let vectorColor = VectorColor.rgb(rgb)
            document.setActiveColor(vectorColor)
        }
        #endif
    }

    private func selectSameColorAt(_ location: CGPoint) {
        var tappedObject: VectorObject?
        var tappedShape: VectorShape?
        for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
            let layer = document.snapshot.layers[layerIndex]
            if layerIndex < document.snapshot.layers.count {
                let legacyLayer = document.snapshot.layers[layerIndex]
                if !legacyLayer.isVisible || legacyLayer.isLocked {
                    continue
                }
            }
            for objectID in layer.objectIDs.reversed() {
                guard let object = document.snapshot.objects[objectID] else { continue }
                if case .shape(let shape) = object.objectType {
                    if !shape.isVisible { continue }
                    if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                        continue
                    }
                    let transformedBounds = shape.bounds.applying(shape.transform)
                    if transformedBounds.contains(location) {
                        tappedObject = object
                        tappedShape = shape
                        break
                    }
                }
            }
            if tappedObject != nil {
                break
            }
        }
        guard let tappedShape else {
            return
        }
        let targetColor: VectorColor?
        if let fillColor = tappedShape.fillStyle?.color {
            targetColor = fillColor
        } else if let strokeColor = tappedShape.strokeStyle?.color {
            targetColor = strokeColor
        } else {
            return
        }
        guard let colorToMatch = targetColor else { return }
        var matchingObjectIDs = Set<UUID>()
        for layerIndex in 0..<document.snapshot.layers.count {
            let layer = document.snapshot.layers[layerIndex]
            if layerIndex < document.snapshot.layers.count {
                let legacyLayer = document.snapshot.layers[layerIndex]
                if !legacyLayer.isVisible || legacyLayer.isLocked {
                    continue
                }
            }
            for objectID in layer.objectIDs {
                guard let object = document.snapshot.objects[objectID] else { continue }
                if case .shape(let shape) = object.objectType {
                    if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                        continue
                    }
                    let hasFillMatch = shape.fillStyle?.color == colorToMatch
                    let hasStrokeMatch = shape.strokeStyle?.color == colorToMatch
                    if hasFillMatch || hasStrokeMatch {
                        matchingObjectIDs.insert(object.id)
                    }
                }
            }
        }
        if !matchingObjectIDs.isEmpty {
            document.viewState.selectedObjectIDs = matchingObjectIDs
        }
    }

    private func validateCanvasLocation(_ location: CGPoint) -> CGPoint {
        if location.x.isNaN || location.y.isNaN || location.x.isInfinite || location.y.isInfinite {
            Log.error("❌ INVALID CANVAS COORDINATES: \(location) - using zero point", category: .error)
            return .zero
        }
        let maxReasonableValue: CGFloat = 1000000.0
        if abs(location.x) > maxReasonableValue || abs(location.y) > maxReasonableValue {
            Log.error("❌ EXTREME CANVAS COORDINATES: \(location) - using zero point", category: .error)
            return .zero
        }
        return location
    }
}
