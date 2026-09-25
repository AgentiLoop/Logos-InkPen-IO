import SwiftUI
import simd

extension DrawingCanvas {

    internal func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard document.gridSettings.snapToGrid else { return point }
        let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

        let spacingMultiplier: CGFloat = {
            switch document.settings.unit {
            case .pixels, .points:
                return 25.0
            case .millimeters:
                return 10.0
            case .picas:
                return 4.0
            default:
                return 1.0
            }
        }()
        let gridSpacing = baseSpacing * spacingMultiplier
        guard gridSpacing > 0 else { return point }
        let snappedX = round(point.x / gridSpacing) * gridSpacing
        let snappedY = round(point.y / gridSpacing) * gridSpacing
        return CGPoint(x: snappedX, y: snappedY)
    }

    internal func ensureIncompletePathHasProperColors(shape: VectorShape) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        let shapes = document.getShapesForLayer(layerIndex)
        for shapeIndex in shapes.indices {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
               currentShape.id == shape.id {
                document.createStrokeStyleInUnified(
                    id: shape.id,
                    color: document.defaultStrokeColor,
                    width: document.defaultStrokeWidth,
                    placement: document.strokeDefaults.placement,
                    lineCap: document.strokeDefaults.lineCap,
                    lineJoin: document.strokeDefaults.lineJoin,
                    miterLimit: document.strokeDefaults.miterLimit,
                    opacity: document.defaultStrokeOpacity
                )
                document.createFillStyleInUnified(
                    id: shape.id,
                    color: document.defaultFillColor,
                    opacity: document.defaultFillOpacity
                )
                var updatedShape = currentShape
                updatedShape.updateBounds()
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                break
            }
        }
    }

    internal func handleBezierPenTap(at location: CGPoint) {
        var constrainedLocation = location
        if isShiftPressed && isBezierDrawing && !bezierPoints.isEmpty {
            guard let lastPoint = bezierPoints.last else { return }
            let referencePoint = CGPoint(x: lastPoint.x, y: lastPoint.y)
            constrainedLocation = constrainToAngle(from: referencePoint, to: location)
        }
        constrainedLocation = applySnapping(to: constrainedLocation)
        if isBezierDrawing && bezierPoints.count >= 3 && showClosePathHint {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            let baseCloseTolerance: Double = 5.0
            let zoomLevel = zoomLevel
            let closeTolerance = max(2.0, baseCloseTolerance / zoomLevel)
            if distance(constrainedLocation, firstPointLocation) <= closeTolerance {
                closeBezierPath()
                return
            }
        }
        if !isBezierDrawing {
            if let selectedPointID = selectedPoints.first {
                if getShapeForPoint(selectedPointID) != nil,

                   let pointPosition = getPointPosition(selectedPointID) {
                    continueExistingPath(from: pointPosition)
                    return
                }
            }
            if activeBezierShape == nil {
                createNewBezierPath(at: constrainedLocation)
            }
            return
        } else {
            addCornerPoint(at: constrainedLocation)
        }
    }

    internal func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        var startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        var currentLocation = screenToCanvas(value.location, geometry: geometry)
        startLocation = applySnapping(to: startLocation)
        if isShiftPressed && isBezierDrawing && !bezierPoints.isEmpty {
            currentLocation = applyAngleConstraintForDrag(currentLocation: currentLocation, startLocation: startLocation)
        }
        currentLocation = applySnapping(to: currentLocation)
        let dragDistance = value.location.distance(to: value.startLocation)
        let baseThreshold: Double = 8.0
        let zoomLevel = zoomLevel
        let zoomAwareThreshold = max(2.0, baseThreshold / zoomLevel)
        if !isBezierDrawing && activeBezierShape == nil {
            handleFirstPointCreationFromDrag(startLocation: startLocation)
        }
        guard isBezierDrawing else { return }
        if dragDistance < zoomAwareThreshold {
            return
        }
        let basePointTolerance: Double = 8.0
        let tolerance = max(2.0, basePointTolerance / zoomLevel)

        var draggedPointIndex: Int? = nil
        for (index, point) in bezierPoints.enumerated() {
            let pointLocation = CGPoint(x: point.x, y: point.y)
            if distance(startLocation, pointLocation) <= tolerance {
                draggedPointIndex = index
                break
            }
        }
        if let pointIndex = draggedPointIndex {
            editExistingPointHandles(pointIndex: pointIndex, currentLocation: currentLocation)
        } else {
            createNewPointWithHandles(startLocation: startLocation, currentLocation: currentLocation)
        }
    }

    internal func updateActiveBezierShapeInDocument(isLiveDrag: Bool = false) {
        guard let activeBezierShape = activeBezierShape,
              let updatedPath = bezierPath,
              let layerIndex = document.selectedLayerIndex else { return }
        let shapes = document.getShapesForLayer(layerIndex)
        for shapeIndex in shapes.indices {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
               currentShape.id == activeBezierShape.id {
                var updatedShape = currentShape
                updatedShape.path = updatedPath
                if !isLiveDrag {
                    document.createStrokeStyleInUnified(
                        id: activeBezierShape.id,
                        color: document.defaultStrokeColor,
                        width: document.defaultStrokeWidth,
                        placement: document.strokeDefaults.placement,
                        lineCap: document.strokeDefaults.lineCap,
                        lineJoin: document.strokeDefaults.lineJoin,
                        miterLimit: document.strokeDefaults.miterLimit,
                        opacity: document.defaultStrokeOpacity
                    )
                    updatedShape.updateBounds()
                }
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                break
            }
        }
    }

    internal func finishBezierPath() {
        guard var activeBezierShape = activeBezierShape else {
            cancelBezierDrawing()
            return
        }
        if bezierPoints.count < 2 {
            ensureIncompletePathHasProperColors(shape: activeBezierShape)
            cancelBezierDrawing()
            currentShapeId = nil
            return
        }
        updatePathWithHandles()
        if var currentPath = bezierPath {
            if let firstPointHandles = bezierHandles[0], let control2 = firstPointHandles.control2 {
                currentPath.pendingStartHandle = control2
            }
            let lastIndex = bezierPoints.count - 1
            if let lastPointHandles = bezierHandles[lastIndex], let control2 = lastPointHandles.control2 {
                currentPath.pendingEndHandle = control2
            }
            if !currentPath.isClosed {
                var stringKeyedHandles: [String: BezierHandleInfo] = [:]
                for (key, value) in bezierHandles {
                    stringKeyedHandles[String(key)] = value
                }
                currentPath.bezierHandles = stringKeyedHandles
            } else {
                currentPath.bezierHandles = nil
                currentPath.pendingStartHandle = nil
                currentPath.pendingEndHandle = nil
            }
            activeBezierShape.path = currentPath
            activeBezierShape.updateBounds()
        }
        if let obj = document.snapshot.objects[activeBezierShape.id] {
            var documentShape = obj.shape
            documentShape.path = activeBezierShape.path
            documentShape.updateBounds()
            let objectType = VectorObject.determineType(for: documentShape)
            let updatedObj = VectorObject(id: obj.id, layerIndex: obj.layerIndex, objectType: objectType)
            document.snapshot.objects[activeBezierShape.id] = updatedObj
            document.triggerLayerUpdate(for: obj.layerIndex)
            if isContinuingExistingPath, let originalShape = originalBezierShapeForUndo {
                let command = ShapeModificationCommand(
                    objectIDs: [activeBezierShape.id],
                    oldShapes: [activeBezierShape.id: originalShape],
                    newShapes: [activeBezierShape.id: documentShape]
                )
                document.commandManager.recordCompletedCommand(command)
            } else {
                let command = AddObjectCommand(object: updatedObj)
                document.commandManager.recordCompletedCommand(command)
            }
        }
        isContinuingExistingPath = false
        originalBezierShapeForUndo = nil
        cancelBezierDrawing()
    }

    internal func finishBezierPenDrag() {
        for (index, liveHandle) in liveBezierHandles {
            bezierHandles[index] = liveHandle
        }
        liveBezierHandles.removeAll()
        originalBezierHandles.removeAll()
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        updatePathWithHandles()
        updateActiveBezierShapeInDocument()
    }

    internal func shouldShowContinuePathHint() -> (Bool, CGPoint?) {
        guard document.viewState.currentTool == .bezierPen && !isBezierDrawing else {
            return (false, nil)
        }
        if let selectedPointID = selectedPoints.first,

           let pointPosition = getPointPosition(selectedPointID) {
            return (true, CGPoint(x: pointPosition.x, y: pointPosition.y))
        }
        return (false, nil)
    }

    internal var constraintAngles: [Double] {
        return [0, 45, 90, 135, 180, 225, 270, 315]
    }

    internal func findBestIntersectionPoint(from currentPoint: CGPoint, toward target: CGPoint) -> CGPoint? {
        guard isBezierDrawing && bezierPoints.count >= 1 else { return nil }
        let dx = target.x - currentPoint.x
        let dy = target.y - currentPoint.y
        let currentAngle = atan2(dy, dx)

        var currentAngleDegrees = currentAngle * 180.0 / .pi
        if currentAngleDegrees < 0 {
            currentAngleDegrees += 360
        }
        var closestAngleFromCurrent = constraintAngles[0]
        var minDiff = 360.0
        for angle in constraintAngles {
            let diff = abs(currentAngleDegrees - angle)
            let wrappedDiff = min(diff, 360 - diff)
            if wrappedDiff < minDiff {
                minDiff = wrappedDiff
                closestAngleFromCurrent = angle
            }
        }
        let angleFromCurrentRad = closestAngleFromCurrent * .pi / 180.0

        var bestIntersection: CGPoint?
        var bestScore = Double.infinity

        let dir1 = SIMD2<Double>(cos(angleFromCurrentRad), sin(angleFromCurrentRad))
        let currentVec = SIMD2<Double>(Double(currentPoint.x), Double(currentPoint.y))
        let targetVec = SIMD2<Double>(Double(target.x), Double(target.y))
        for existingPoint in bezierPoints {
            let existingVec = SIMD2<Double>(Double(existingPoint.x), Double(existingPoint.y))
            for constraintAngleFromPoint in constraintAngles {
                let angleFromPointRad = constraintAngleFromPoint * .pi / 180.0
                let dir2 = SIMD2<Double>(cos(angleFromPointRad), sin(angleFromPointRad))
                let denominator = dir1.x * dir2.y - dir1.y * dir2.x
                if abs(denominator) > 0.001 {
                    let delta = existingVec - currentVec
                    let t1 = (delta.x * dir2.y - delta.y * dir2.x) / denominator
                    let t2 = (delta.x * dir1.y - delta.y * dir1.x) / denominator
                    if t1 > 0 && t2 > 0 {
                        let intersectionVec = currentVec + dir1 * t1
                        let distToTarget = simd_length(targetVec - intersectionVec)
                        if distToTarget < bestScore {
                            bestScore = distToTarget
                            bestIntersection = CGPoint(x: intersectionVec.x, y: intersectionVec.y)
                        }
                    }
                }
            }
        }
        return bestIntersection
    }

    private func constrainToAngle(from reference: CGPoint, to target: CGPoint) -> CGPoint {
        let refVec = SIMD2<Double>(Double(reference.x), Double(reference.y))
        let targetVec = SIMD2<Double>(Double(target.x), Double(target.y))
        let delta = targetVec - refVec
        let distance = simd_length(delta)
        guard distance > 0.001 else { return target }
        if isBezierDrawing && bezierPoints.count >= 1 {
            if let intersectionPoint = findBestIntersectionPoint(from: reference, toward: target) {
                return intersectionPoint
            }
        }
        let angle = atan2(delta.y, delta.x)

        var angleDegrees = angle * 180.0 / .pi
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        var closestAngle = constraintAngles[0]
        var minDifference = 360.0
        for constraintAngle in constraintAngles {
            let diff = abs(angleDegrees - constraintAngle)
            let wrappedDiff = min(diff, 360 - diff)
            if wrappedDiff < minDifference {
                minDifference = wrappedDiff
                closestAngle = constraintAngle
            }
        }
        let constrainedAngleRad = closestAngle * .pi / 180.0
        let offset = SIMD2<Double>(cos(constrainedAngleRad), sin(constrainedAngleRad)) * distance
        let result = refVec + offset
        return CGPoint(x: result.x, y: result.y)
    }

    internal func getShapeForPoint(_ pointID: PointID) -> VectorShape? {
        for object in document.snapshot.objects.values {
            if case .shape(let shape) = object.objectType {
                if shape.id == pointID.shapeID {
                    return shape
                }
                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }

    private func createNewBezierPath(at location: CGPoint) {
        let newPath = VectorPath(elements: [.move(to: VectorPoint(location))])
        bezierPath = newPath
        bezierPoints = [VectorPoint(location)]
        isBezierDrawing = true
        activeBezierPointIndex = 0
        bezierHandles.removeAll()
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            placement: document.strokeDefaults.placement,
            dashPattern: [],
            lineCap: document.strokeDefaults.lineCap,
            lineJoin: document.strokeDefaults.lineJoin,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle: FillStyle? = nil
        activeBezierShape = VectorShape(
            name: "Bezier Path",
            path: newPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        if let shape = activeBezierShape {
            currentShapeId = shape.id
            document.addShape(shape)
        }
    }

    internal func continueExistingPath(from pointPosition: VectorPoint) {
        guard let selectedPointID = selectedPoints.first,

              let shape = getShapeForPoint(selectedPointID) else {
            createNewPathFromPoint(pointPosition)
            return
        }
        let isClosed = shape.path.elements.contains { element in
            if case .close = element { return true }
            return false
        }
        if isClosed {
            createNewPathFromPoint(pointPosition)
            return
        }
        var points: [VectorPoint] = []
        var handles: [Int: BezierHandleInfo] = [:]
        var currentIndex = 0
        var previousPoint: VectorPoint?

        let pendingStartHandle = shape.path.pendingStartHandle
        for element in shape.path.elements {
            switch element {
            case .move(to: let point):
                points.append(point)
                previousPoint = point
                currentIndex = 0
            case .line(to: let point):
                points.append(point)
                previousPoint = point
                currentIndex += 1
            case .curve(to: let point, control1: let cp1, control2: let cp2):
                points.append(point)
                if previousPoint != nil {
                    var prevHandleInfo = handles[currentIndex] ?? BezierHandleInfo()
                    prevHandleInfo.control2 = cp1
                    prevHandleInfo.hasHandles = true
                    handles[currentIndex] = prevHandleInfo
                }
                var currentHandleInfo = handles[currentIndex + 1] ?? BezierHandleInfo()
                currentHandleInfo.control1 = cp2
                currentHandleInfo.hasHandles = true
                handles[currentIndex + 1] = currentHandleInfo
                previousPoint = point
                currentIndex += 1
            case .quadCurve(to: let point, control: _):
                points.append(point)
                previousPoint = point
                currentIndex += 1
            case .close:
                break
            }
        }
        let lastPointIndex = points.count - 1
        if let pendingStart = shape.path.pendingStartHandle {
            var handleInfo = handles[0] ?? BezierHandleInfo()
            handleInfo.control2 = pendingStart
            handleInfo.hasHandles = true
            handles[0] = handleInfo
        } else if shape.path.elements.count > 1 {
            switch shape.path.elements[1] {
            case .curve(_, control1: let cp1, _):
                var handleInfo = handles[0] ?? BezierHandleInfo()
                handleInfo.control2 = cp1
                handleInfo.hasHandles = true
                handles[0] = handleInfo
            case .line:
                break
            default:
                break
            }
        }
        var handleInfo = handles[lastPointIndex] ?? BezierHandleInfo()
        if let pendingEnd = shape.path.pendingEndHandle {
            handleInfo.control2 = pendingEnd
            handleInfo.hasHandles = true
            handles[lastPointIndex] = handleInfo
        } else if let lastElement = shape.path.elements.last {
            switch lastElement {
            case .curve(_, _, control2: let cp2):
                let lastPoint = points[lastPointIndex]
                let mirroredControl2 = VectorPoint(
                    2 * lastPoint.x - cp2.x,
                    2 * lastPoint.y - cp2.y
                )
                if handleInfo.control1 == nil {
                    handleInfo.control1 = cp2
                }
                handleInfo.control2 = mirroredControl2
                handleInfo.hasHandles = true
                handles[lastPointIndex] = handleInfo
            case .line:
                break
            default:
                break
            }
        }
        let isStartPoint = selectedPointID.elementIndex == 0
        let isEndPoint = selectedPointID.elementIndex == points.count - 1
        if !isStartPoint && !isEndPoint {
            createNewPathFromPoint(pointPosition)
            return
        }
        if isStartPoint {
            points.reverse()
            var reversedHandles: [Int: BezierHandleInfo] = [:]
            for (index, handleInfo) in handles {
                let newIndex = points.count - 1 - index

                var newHandleInfo = BezierHandleInfo()
                newHandleInfo.control1 = handleInfo.control2
                newHandleInfo.control2 = handleInfo.control1
                newHandleInfo.hasHandles = (handleInfo.control1 != nil || handleInfo.control2 != nil)
                reversedHandles[newIndex] = newHandleInfo
            }
            handles = reversedHandles
            let newLastIndex = points.count - 1
            if let pendingStart = pendingStartHandle {
                let lastPoint = points[newLastIndex]
                let mirroredHandle = VectorPoint(
                    2 * lastPoint.x - pendingStart.x,
                    2 * lastPoint.y - pendingStart.y
                )
                var handleInfo = handles[newLastIndex] ?? BezierHandleInfo()
                handleInfo.control2 = mirroredHandle
                handleInfo.hasHandles = true
                handles[newLastIndex] = handleInfo
            }
        }
        bezierPoints = points
        bezierHandles = handles
        liveBezierHandles.removeAll()
        originalBezierHandles.removeAll()
        isBezierDrawing = true
        activeBezierPointIndex = points.count - 1
        activeBezierShape = shape
        currentShapeId = shape.id
        isContinuingExistingPath = true
        originalBezierShapeForUndo = shape
        rebuildBezierPath()
        selectedPoints.removeAll()
    }

    private func rebuildBezierPath() {
        guard !bezierPoints.isEmpty else {
            bezierPath = nil
            return
        }
        var elements: [PathElement] = []
        elements.append(.move(to: bezierPoints[0]))
        for i in 1..<bezierPoints.count {
            let currentPoint = bezierPoints[i]
            let previousHandles = bezierHandles[i - 1]
            let currentHandles = bezierHandles[i]
            let hasOutgoingHandle = previousHandles?.control2 != nil
            let hasIncomingHandle = currentHandles?.control1 != nil
            if hasOutgoingHandle || hasIncomingHandle {
                let control1 = previousHandles?.control2 ?? VectorPoint(bezierPoints[i - 1].x, bezierPoints[i - 1].y)
                let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                elements.append(.curve(to: currentPoint, control1: control1, control2: control2))
            } else {
                elements.append(.line(to: currentPoint))
            }
        }
        bezierPath = VectorPath(elements: elements)
    }

    private func createNewPathFromPoint(_ pointPosition: VectorPoint) {
        let newPath = VectorPath(elements: [.move(to: pointPosition)])
        bezierPath = newPath
        bezierPoints = [pointPosition]
        isBezierDrawing = true
        activeBezierPointIndex = 0
        bezierHandles.removeAll()
        isContinuingExistingPath = false
        originalBezierShapeForUndo = nil
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            placement: document.strokeDefaults.placement,
            dashPattern: [],
            lineCap: document.strokeDefaults.lineCap,
            lineJoin: document.strokeDefaults.lineJoin,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle: FillStyle? = nil
        activeBezierShape = VectorShape(
            name: "Bezier Path (Continued)",
            path: newPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        if let shape = activeBezierShape {
            currentShapeId = shape.id
            document.addShape(shape)
        }
        selectedPoints.removeAll()
    }

    private func addCornerPoint(at location: CGPoint) {
        let newPoint = VectorPoint(location)
        bezierPoints.append(newPoint)
        activeBezierPointIndex = bezierPoints.count - 1
        let previousPointIndex = bezierPoints.count - 2
        if previousPointIndex >= 0,
           let previousHandles = bezierHandles[previousPointIndex],

           let previousControl2 = previousHandles.control2 {
            bezierPath?.addElement(.curve(to: newPoint, control1: previousControl2, control2: newPoint))
        } else {
            bezierPath?.addElement(.line(to: newPoint))
        }
        updateActiveBezierShapeInDocument(isLiveDrag: true)
    }

    private func applyAngleConstraintForDrag(currentLocation: CGPoint, startLocation: CGPoint) -> CGPoint {
        let referencePoint: CGPoint
        if isDraggingBezierHandle {
            if let activeIndex = activeBezierPointIndex, activeIndex < bezierPoints.count {
                let point = bezierPoints[activeIndex]
                referencePoint = CGPoint(x: point.x, y: point.y)
            } else if !bezierPoints.isEmpty {
                if let lastPoint = bezierPoints.last {
                    referencePoint = CGPoint(x: lastPoint.x, y: lastPoint.y)
                } else {
                    referencePoint = currentLocation
                }
            } else {
                referencePoint = startLocation
            }
        } else {
            if let lastPoint = bezierPoints.last {
                referencePoint = CGPoint(x: lastPoint.x, y: lastPoint.y)
            } else {
                referencePoint = currentLocation
            }
        }
        return constrainToAngle(from: referencePoint, to: currentLocation)
    }

    private func handleFirstPointCreationFromDrag(startLocation: CGPoint) {
        if let selectedPointID = selectedPoints.first {
            if getShapeForPoint(selectedPointID) != nil,

               let pointPosition = getPointPosition(selectedPointID) {
                continueExistingPath(from: pointPosition)
            } else {
                createNewPathFromDrag(at: startLocation)
            }
        } else {
            createNewPathFromDrag(at: startLocation)
        }
    }

    private func createNewPathFromDrag(at location: CGPoint) {
        let firstPoint = VectorPoint(location)
        let newPath = VectorPath(elements: [.move(to: firstPoint)])
        bezierPath = newPath
        bezierPoints = [firstPoint]
        isBezierDrawing = true
        activeBezierPointIndex = 0
        bezierHandles.removeAll()
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle: FillStyle? = nil
        let newShape = VectorShape(
            name: "Bezier Path",
            path: newPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        activeBezierShape = newShape
        document.addShape(newShape)
    }

    private func editExistingPointHandles(pointIndex: Int, currentLocation: CGPoint) {
        if !isDraggingBezierHandle {
            isDraggingBezierHandle = true
            isDraggingBezierPoint = true
            originalBezierHandles = bezierHandles
        }
        let point = bezierPoints[pointIndex]
        let pointLocation = CGPoint(x: point.x, y: point.y)
        let dragVector = CGPoint(
            x: currentLocation.x - pointLocation.x,
            y: currentLocation.y - pointLocation.y
        )
        let control1 = VectorPoint(
            pointLocation.x - dragVector.x,
            pointLocation.y - dragVector.y
        )
        let control2 = VectorPoint(
            pointLocation.x + dragVector.x,
            pointLocation.y + dragVector.y
        )
        liveBezierHandles[pointIndex] = BezierHandleInfo(
            control1: control1,
            control2: control2,
            hasHandles: true
        )
    }

    private func createNewPointWithHandles(startLocation: CGPoint, currentLocation: CGPoint) {
        if !isDraggingBezierHandle {
            isDraggingBezierHandle = true
            originalBezierHandles = bezierHandles
            let lastPoint = bezierPoints.last
            let distanceToLastPoint = lastPoint.map { distance(startLocation, CGPoint(x: $0.x, y: $0.y)) } ?? Double.infinity
            let baseDuplicateTolerance: Double = 5.0
            let zoomLevel = zoomLevel
            let duplicateTolerance = max(1.0, baseDuplicateTolerance / zoomLevel)
            if distanceToLastPoint > duplicateTolerance {
                let newPoint = VectorPoint(startLocation)
                bezierPoints.append(newPoint)
                activeBezierPointIndex = bezierPoints.count - 1
                bezierPath?.addElement(.line(to: newPoint))
            } else {
                activeBezierPointIndex = bezierPoints.count - 1
            }
        }
        let activeIndex = bezierPoints.count - 1
        let activePoint = bezierPoints[activeIndex]
        let activeLocation = CGPoint(x: activePoint.x, y: activePoint.y)
        let dragVector = CGPoint(
            x: currentLocation.x - activeLocation.x,
            y: currentLocation.y - activeLocation.y
        )
        let control1 = VectorPoint(
            activeLocation.x - dragVector.x * 0.5,
            activeLocation.y - dragVector.y * 0.5
        )
        let control2 = VectorPoint(
            activeLocation.x + dragVector.x * 0.5,
            activeLocation.y + dragVector.y * 0.5
        )
        liveBezierHandles[activeIndex] = BezierHandleInfo(
            control1: control1,
            control2: control2,
            hasHandles: true
        )
    }

    private func applyFinalColorsToPath(shape: VectorShape) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        let shapes = document.getShapesForLayer(layerIndex)
        for shapeIndex in shapes.indices {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
               currentShape.id == shape.id {
                document.createStrokeStyleInUnified(
                    id: shape.id,
                    color: document.defaultStrokeColor,
                    width: document.defaultStrokeWidth,
                    placement: document.strokeDefaults.placement,
                    lineCap: document.strokeDefaults.lineCap,
                    lineJoin: document.strokeDefaults.lineJoin,
                    miterLimit: document.strokeDefaults.miterLimit,
                    opacity: document.defaultStrokeOpacity
                )
                document.createFillStyleInUnified(
                    id: shape.id,
                    color: document.defaultFillColor,
                    opacity: document.defaultFillOpacity
                )
                var updatedShape = currentShape
                updatedShape.updateBounds()
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                break
            }
        }
    }
}
