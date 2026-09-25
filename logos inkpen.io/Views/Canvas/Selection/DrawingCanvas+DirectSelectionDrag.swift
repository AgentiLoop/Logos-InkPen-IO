import SwiftUI
import Combine
import simd

extension DrawingCanvas {

    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle && !isDraggingCurveSegment {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 10.0
            let tolerance: Double = screenTolerance / zoomLevel
            if !selectedObjectIDs.isEmpty {
                if let curveSegment = findCurveSegmentInSelectedShapes(at: canvasLocation, tolerance: tolerance) {
                    isDraggingCurveSegment = true
                    draggedCurveSegment = curveSegment
                    dragStartLocation = canvasLocation
                    if let shape = document.snapshot.objects[curveSegment.shapeID]?.shape {
                        curveSegmentDragT = calculateTOnCurveSegment(shape: shape, elementIndex: curveSegment.elementIndex, point: canvasLocation)
                    }
                    captureOriginalHandlesForCurveSegment(shapeID: curveSegment.shapeID, elementIndex: curveSegment.elementIndex)
                    return
                }
            }
        }
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !selectedObjectIDs.isEmpty && !isDraggingCurveSegment {
            handleDirectSelectionShapeDrag(value: value, geometry: geometry)
            return
        }
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle && !isDraggingCurveSegment {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 15.0
            let tolerance: Double = screenTolerance / zoomLevel

            var foundPointOrHandle = false
            if !selectedObjectIDs.isEmpty {
                foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)
            }
            if !foundPointOrHandle {
                if directSelectWholeShape(at: canvasLocation) {
                    foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)
                    if !foundPointOrHandle && !selectedObjectIDs.isEmpty {
                        handleDirectSelectionShapeDrag(value: value, geometry: geometry)
                        return
                    }
                }
            }
            if !foundPointOrHandle {
                return
            }
        }
        if isDraggingCurveSegment {
            handleCurveSegmentDrag(value: value, geometry: geometry)
            return
        }
        guard !selectedPoints.isEmpty || !selectedHandles.isEmpty else { return }
        for pointID in selectedPoints {
            if lockedObjectIDs.contains(pointID.shapeID) {
                return
            }
        }
        for handleID in selectedHandles {
            if lockedObjectIDs.contains(handleID.shapeID) {
                return
            }
        }
        if !isDraggingPoint && !isDraggingHandle {
            isDraggingPoint = !selectedPoints.isEmpty
            isDraggingHandle = !selectedHandles.isEmpty
            document.viewState.isLivePointDrag = true
            var affectedShapeIDs = Set<UUID>()
            for pointID in selectedPoints {
                affectedShapeIDs.insert(pointID.shapeID)
            }
            for handleID in selectedHandles {
                affectedShapeIDs.insert(handleID.shapeID)
            }
            originalDragShapes.removeAll()
            for shapeID in affectedShapeIDs {
                if let shape = document.findShape(by: shapeID) {
                    originalDragShapes[shapeID] = shape
                }
            }
            captureOriginalPositions()
        }
        let preciseZoom = Double(zoomLevel)
        let preciseTranslationX = Double(value.translation.width)
        let preciseTranslationY = Double(value.translation.height)
        let delta = CGPoint(
            x: preciseTranslationX / preciseZoom,
            y: preciseTranslationY / preciseZoom
        )
        var snappedDelta = delta
        if (document.gridSettings.snapToPoint || document.gridSettings.snapToGrid) && !selectedPoints.isEmpty {
            if let firstPointID = selectedPoints.first,

               let originalPosition = originalPointPositions[firstPointID] {
                let unsnappedPosition = CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                )
                let snappedPosition = applySnapping(to: unsnappedPosition)
                snappedDelta = CGPoint(
                    x: snappedPosition.x - originalPosition.x,
                    y: snappedPosition.y - originalPosition.y
                )
            }
        }
        let shouldDragPoints = selectedHandles.isEmpty && !selectedPoints.isEmpty
        let shouldDragHandles = !selectedHandles.isEmpty
        if shouldDragPoints {
            for pointID in selectedPoints {
                if let originalPosition = originalPointPositions[pointID] {
                    let newPointPosition = CGPoint(
                        x: originalPosition.x + snappedDelta.x,
                        y: originalPosition.y + snappedDelta.y
                    )
                    livePointPositions[pointID] = newPointPosition
                    updateLiveHandlesForMovedPoint(pointID: pointID, delta: snappedDelta)
                }
            }
        }
        if shouldDragHandles {
            for handleID in selectedHandles {
            if let originalPosition = originalHandlePositions[handleID] {
                let newPosition = CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                )
                liveHandlePositions[handleID] = newPosition
                if !isOptionPressed && isPointSmooth(handleID: handleID) {
                    updateLiveLinkedHandle(handleID: handleID, newPosition: newPosition)
                }
            }
            }
        }
    }

    private func isCoincidentPointSmooth(elements: [PathElement], handleID: HandleID) -> Bool {
        guard elements.count >= 2 else { return false }
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType else { return false }
        if let explicitType = shape.anchorTypes[0] {
            switch explicitType {
            case .smooth: return true
            case .corner, .cusp: return false
            case .auto: break
            }
        }
        let firstPoint: CGPoint?
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            return false
        }
        var lastElementIndex = elements.count - 1
        if case .close = elements[lastElementIndex] {
            lastElementIndex -= 1
        }
        let lastPoint: CGPoint?
        if lastElementIndex >= 0 {
            switch elements[lastElementIndex] {
            case .curve(let lastTo, _, _), .line(let lastTo), .quadCurve(let lastTo, _):
                lastPoint = CGPoint(x: lastTo.x, y: lastTo.y)
            default:
                return false
            }
        } else {
            return false
        }
        guard let first = firstPoint, let last = lastPoint,
              abs(first.x - last.x) < 0.1 && abs(first.y - last.y) < 0.1 else {
            return false
        }
        let isFirstOutgoing = (handleID.handleType == .control1 && handleID.elementIndex == 1)
        let isLastIncoming = (handleID.handleType == .control2 && handleID.elementIndex == lastElementIndex)
        if !isFirstOutgoing && !isLastIncoming {
            return false
        }
        var handle1: CGPoint?
        var handle2: CGPoint?
        if case .curve(_, let firstControl1, _) = elements[1] {
            handle1 = CGPoint(x: firstControl1.x, y: firstControl1.y)
        }
        if case .curve(_, _, let lastControl2) = elements[lastElementIndex] {
            handle2 = CGPoint(x: lastControl2.x, y: lastControl2.y)
        }
        guard let h1 = handle1, let h2 = handle2 else { return false }
        if (abs(h1.x - first.x) < 0.1 && abs(h1.y - first.y) < 0.1) ||
           (abs(h2.x - first.x) < 0.1 && abs(h2.y - first.y) < 0.1) {
            return false
        }
        let firstVec = SIMD2<Double>(Double(first.x), Double(first.y))
        let h1Vec = SIMD2<Double>(Double(h1.x), Double(h1.y))
        let h2Vec = SIMD2<Double>(Double(h2.x), Double(h2.y))
        let vec1 = h1Vec - firstVec
        let vec2 = h2Vec - firstVec
        let len1 = simd_length(vec1)
        let len2 = simd_length(vec2)
        if len1 < 0.1 || len2 < 0.1 { return false }
        let norm1 = simd_normalize(vec1)
        let norm2 = simd_normalize(vec2)
        let dot = simd_dot(norm1, norm2)
        return dot < -0.9962
    }

    private func isPointSmooth(handleID: HandleID) -> Bool {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType,
              handleID.elementIndex < shape.path.elements.count else { return false }
        let elements = shape.path.elements
        let element = elements[handleID.elementIndex]
        let anchorElementIndex = handleID.handleType == .control2 ? handleID.elementIndex : handleID.elementIndex - 1
        if let explicitType = shape.anchorTypes[anchorElementIndex] {
            switch explicitType {
            case .smooth: return true
            case .corner, .cusp: return false
            case .auto: break
            }
        }
        if isCoincidentPointSmooth(elements: elements, handleID: handleID) {
            return true
        }
        var anchorPoint: CGPoint?
        var handle1: CGPoint?
        var handle2: CGPoint?
        if handleID.handleType == .control2 {
            guard case .curve(let to, _, let control2) = element else { return false }
            anchorPoint = to.cgPoint
            handle1 = control2.cgPoint
            let nextIndex = handleID.elementIndex + 1
            if nextIndex < elements.count,
               case .curve(_, let nextControl1, _) = elements[nextIndex] {
                handle2 = nextControl1.cgPoint
            }
        } else if handleID.handleType == .control1 {
            guard case .curve(_, let control1, _) = element else { return false }
            handle2 = control1.cgPoint
            let prevIndex = handleID.elementIndex - 1
            if prevIndex >= 0,
               case .curve(let prevTo, _, let prevControl2) = elements[prevIndex] {
                anchorPoint = CGPoint(x: prevTo.x, y: prevTo.y)
                handle1 = CGPoint(x: prevControl2.x, y: prevControl2.y)
            }
        }
        guard let anchor = anchorPoint,
              let h1 = handle1,
              let h2 = handle2 else { return false }
        let anchorVec = SIMD2<Double>(Double(anchor.x), Double(anchor.y))
        let h1Vec = SIMD2<Double>(Double(h1.x), Double(h1.y))
        let h2Vec = SIMD2<Double>(Double(h2.x), Double(h2.y))
        let vec1 = h1Vec - anchorVec
        let vec2 = h2Vec - anchorVec
        let len1 = simd_length(vec1)
        let len2 = simd_length(vec2)
        if len1 < 0.1 || len2 < 0.1 { return false }
        let norm1 = simd_normalize(vec1)
        let norm2 = simd_normalize(vec2)
        let dot = simd_dot(norm1, norm2)
        return dot < -0.9962
    }

    private func updateLiveHandlesForMovedPoint(pointID: PointID, delta: CGPoint) {
        guard let object = document.snapshot.objects[pointID.shapeID],
              case .shape(let shape) = object.objectType,
              pointID.elementIndex < shape.path.elements.count else { return }
        let element = shape.path.elements[pointID.elementIndex]
        if case .curve(_, _, let control2) = element {
            let handleID = HandleID(shapeID: pointID.shapeID, pathIndex: 0, elementIndex: pointID.elementIndex, handleType: .control2)
            if let originalHandlePos = originalHandlePositions[handleID] {
                liveHandlePositions[handleID] = CGPoint(
                    x: originalHandlePos.x + delta.x,
                    y: originalHandlePos.y + delta.y
                )
            } else {
                liveHandlePositions[handleID] = CGPoint(
                    x: control2.x + delta.x,
                    y: control2.y + delta.y
                )
            }
        }
        let nextIndex = pointID.elementIndex + 1
        if nextIndex < shape.path.elements.count {
            let nextElement = shape.path.elements[nextIndex]
            if case .curve(_, let control1, _) = nextElement {
                let handleID = HandleID(shapeID: pointID.shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                if let originalHandlePos = originalHandlePositions[handleID] {
                    liveHandlePositions[handleID] = CGPoint(
                        x: originalHandlePos.x + delta.x,
                        y: originalHandlePos.y + delta.y
                    )
                } else {
                    liveHandlePositions[handleID] = CGPoint(
                        x: control1.x + delta.x,
                        y: control1.y + delta.y
                    )
                }
            }
        }
    }

    private func updateLiveLinkedHandle(handleID: HandleID, newPosition: CGPoint) {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType,
              handleID.elementIndex < shape.path.elements.count else { return }
        let elements = shape.path.elements
        if checkFirstLastCoincidentForLive(elements: elements, handleID: handleID, newPosition: newPosition) {
            return
        }
        let element = elements[handleID.elementIndex]

        var anchorPoint: CGPoint?
        var anchorPointID: PointID?
        var oppositeHandleID: HandleID?
        var oppositeOriginalPosition: CGPoint?
        if handleID.handleType == .control2 {
            guard case .curve(let to, _, _) = element else { return }
            anchorPoint = to.cgPoint
            anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: handleID.elementIndex)
            let nextIndex = handleID.elementIndex + 1
            if nextIndex < elements.count,
               case .curve(_, let nextControl1, _) = elements[nextIndex] {
                oppositeHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                oppositeOriginalPosition = nextControl1.cgPoint
            }
        } else if handleID.handleType == .control1 {
            let prevIndex = handleID.elementIndex - 1
            if prevIndex >= 0,
               case .curve(let prevTo, _, let prevControl2) = elements[prevIndex] {
                anchorPoint = CGPoint(x: prevTo.x, y: prevTo.y)
                anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex)
                oppositeHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                oppositeOriginalPosition = CGPoint(x: prevControl2.x, y: prevControl2.y)
            }
        }
        guard var anchor = anchorPoint,
              let oppositeID = oppositeHandleID,
              let oppositeOriginal = oppositeOriginalPosition else { return }
        if let liveAnchor = anchorPointID, let livePos = livePointPositions[liveAnchor] {
            anchor = livePos
        }
        let linkedPosition = calculateLinkedHandle(
            anchorPoint: anchor,
            draggedHandle: newPosition,
            originalOppositeHandle: oppositeOriginal
        )
        liveHandlePositions[oppositeID] = linkedPosition
    }

    private func handleCoincidentForLiveHandle(handleID: HandleID, newPosition: CGPoint, shape: VectorShape) {
        let elements = shape.path.elements
        guard elements.count >= 2 else { return }
        let firstPoint: CGPoint?
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            firstPoint = nil
        }
        var lastElementIndex = elements.count - 1
        if case .close = elements[lastElementIndex] {
            lastElementIndex -= 1
        }
        let lastPoint: CGPoint?
        if lastElementIndex >= 0 {
            switch elements[lastElementIndex] {
            case .curve(let lastTo, _, _), .line(let lastTo), .quadCurve(let lastTo, _):
                lastPoint = CGPoint(x: lastTo.x, y: lastTo.y)
            default:
                lastPoint = nil
            }
        } else {
            lastPoint = nil
        }
        guard let first = firstPoint, let last = lastPoint,
              abs(first.x - last.x) < 0.001 && abs(first.y - last.y) < 0.001 else {
            return
        }
        let anchorPoint = first
        if handleID.handleType == .control2 && handleID.elementIndex == 0 {
            if case .curve(_, _, _) = elements[lastElementIndex],

               let originalLastControl2 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }
        if handleID.handleType == .control2 && handleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(_, _, _) = elements[1],

               let originalFirstControl1 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalFirstControl1.x, y: originalFirstControl1.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }
        if handleID.handleType == .control1 && handleID.elementIndex == 1 {
            if case .curve(_, _, _) = elements[lastElementIndex],

               let originalLastControl2 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }
        if handleID.handleType == .control1 && handleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(_, _, _) = elements[1],

               let originalFirstControl1 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalFirstControl1.x, y: originalFirstControl1.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }
    }

    private func checkFirstLastCoincidentForLive(elements: [PathElement], handleID: HandleID, newPosition: CGPoint) -> Bool {
        guard elements.count >= 2 else { return false }
        let firstPoint: CGPoint?
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            firstPoint = nil
        }
        var lastElementIndex = elements.count - 1
        if case .close = elements[lastElementIndex] {
            lastElementIndex -= 1
        }
        let lastPoint: CGPoint?
        if lastElementIndex >= 0 {
            switch elements[lastElementIndex] {
            case .curve(let lastTo, _, _), .line(let lastTo), .quadCurve(let lastTo, _):
                lastPoint = CGPoint(x: lastTo.x, y: lastTo.y)
            default:
                lastPoint = nil
            }
        } else {
            lastPoint = nil
        }
        guard let first = firstPoint, let last = lastPoint,
              abs(first.x - last.x) < 0.001 && abs(first.y - last.y) < 0.001 else {
            return false
        }
        if !isCoincidentPointSmooth(elements: elements, handleID: handleID) {
            return false
        }
        let anchorPoint = first
        if handleID.handleType == .control1 && handleID.elementIndex == 1 {
            if case .curve(_, _, let lastControl2) = elements[lastElementIndex] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: lastControl2.x, y: lastControl2.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)
                liveHandlePositions[oppositeHandleID] = oppositeHandle
                return true
            }
        }
        if handleID.handleType == .control2 && handleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(_, let secondControl1, _) = elements[1] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: secondControl1.x, y: secondControl1.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                liveHandlePositions[oppositeHandleID] = oppositeHandle
                return true
            }
        }
        return false
    }

    private func applyPointUpdatesToShape(shapeID: UUID, pointUpdates: [(PointID, CGPoint)]) {
        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType else { return }
        var elements = shape.path.elements
        for (pointID, newPosition) in pointUpdates {
            guard pointID.elementIndex < elements.count else { continue }
            let newPoint = VectorPoint(newPosition.x, newPosition.y)
            let originalPosition: CGPoint
            switch elements[pointID.elementIndex] {
            case .move(let to), .line(let to):
                originalPosition = to.cgPoint
            case .curve(let to, _, _):
                originalPosition = to.cgPoint
            case .quadCurve(let to, _):
                originalPosition = to.cgPoint
            case .close:
                continue
            }
            let deltaX = newPosition.x - originalPosition.x
            let deltaY = newPosition.y - originalPosition.y
            switch elements[pointID.elementIndex] {
            case .move(_):
                elements[pointID.elementIndex] = .move(to: newPoint)
            case .line(_):
                elements[pointID.elementIndex] = .line(to: newPoint)
            case .curve(let oldTo, let control1, let control2):
                let control2Collapsed = (abs(control2.x - oldTo.x) < 0.1 && abs(control2.y - oldTo.y) < 0.1)
                let newControl1 = control1
                let newControl2 = control2Collapsed ? newPoint : VectorPoint(control2.x + deltaX, control2.y + deltaY)
                elements[pointID.elementIndex] = .curve(to: newPoint, control1: newControl1, control2: newControl2)
            case .quadCurve(_, let control):
                elements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
            case .close:
                break
            }
            if pointID.elementIndex + 1 < elements.count {
                if case .curve(let nextTo, let nextControl1, let nextControl2) = elements[pointID.elementIndex + 1] {
                    let outgoingCollapsed = (abs(nextControl1.x - originalPosition.x) < 0.1 && abs(nextControl1.y - originalPosition.y) < 0.1)
                    let newNextControl1 = outgoingCollapsed ? newPoint : VectorPoint(nextControl1.x + deltaX, nextControl1.y + deltaY)
                    elements[pointID.elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
        }
        document.updateShapeByID(shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
    }

    private func applyHandleUpdatesToShape(shapeID: UUID, handleUpdates: [(HandleID, CGPoint)]) {
        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType else { return }
        var elements = shape.path.elements
        for (handleID, newPosition) in handleUpdates {
            guard handleID.elementIndex < elements.count else { continue }
            let newHandle = VectorPoint(newPosition.x, newPosition.y)
            switch elements[handleID.elementIndex] {
            case .curve(let to, let control1, let control2):
                if handleID.handleType == .control1 {
                    elements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
                } else {
                    elements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
                }
            case .quadCurve(let to, _):
                if handleID.handleType == .control1 {
                    elements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
                }
            default:
                break
            }
            handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: handleID, newDraggedPosition: newPosition)
        }
        document.updateShapeByID(shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
    }

    private func moveHandleToAbsolutePositionWithoutLinked(_ handleID: HandleID, to newPosition: CGPoint) {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType else { return }
        guard handleID.elementIndex < shape.path.elements.count else { return }
        let newHandle = VectorPoint(newPosition.x, newPosition.y)

        var elements = shape.path.elements
        switch elements[handleID.elementIndex] {
        case .curve(let to, let control1, let control2):
            if handleID.handleType == .control1 {
                elements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
            } else {
                elements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
            }
        case .quadCurve(let to, _):
            if handleID.handleType == .control1 {
                elements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
            }
        default:
            break
        }
        handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: handleID, newDraggedPosition: newPosition)
        document.updateShapeByID(handleID.shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
    }

    private func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
        let anchorVec = SIMD2<Double>(Double(anchorPoint.x), Double(anchorPoint.y))
        let draggedVec = SIMD2<Double>(Double(draggedHandle.x), Double(draggedHandle.y))
        let originalVec = SIMD2<Double>(Double(originalOppositeHandle.x), Double(originalOppositeHandle.y))
        let draggedVector = draggedVec - anchorVec
        let originalVector = originalVec - anchorVec
        let originalLength = simd_length(originalVector)
        let draggedLength = simd_length(draggedVector)
        guard draggedLength > 0.1 else { return originalOppositeHandle }
        let normalizedDragged = simd_normalize(draggedVector)
        let linkedVec = anchorVec - normalizedDragged * originalLength
        return CGPoint(x: linkedVec.x, y: linkedVec.y)
    }

    private func handleDirectSelectionShapeDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDraggingDirectSelectedShapes {
            isDraggingDirectSelectedShapes = true
            document.viewState.selectedObjectIDs = selectedObjectIDs
            startSelectionDrag()
            selectionDragStart = value.startLocation
        }
        handleSelectionDrag(value: value, geometry: geometry)
    }

    internal func finishDirectSelectionDrag() {
        if isDraggingCurveSegment {
            finishCurveSegmentDrag()
            isDraggingCurveSegment = false
            draggedCurveSegment = nil
            return
        }
        if isDraggingDirectSelectedShapes {
            finishSelectionDrag()
            isDraggingDirectSelectedShapes = false
            return
        }
        let originalSelectedHandles = selectedHandles

        var pointsByShape: [UUID: [(PointID, CGPoint)]] = [:]
        for (pointID, livePosition) in livePointPositions {
            pointsByShape[pointID.shapeID, default: []].append((pointID, livePosition))
        }
        for (shapeID, points) in pointsByShape {
            applyPointUpdatesToShape(shapeID: shapeID, pointUpdates: points)
        }
        var handlesByShape: [UUID: [(HandleID, CGPoint)]] = [:]
        for (handleID, livePosition) in liveHandlePositions {
            handlesByShape[handleID.shapeID, default: []].append((handleID, livePosition))
        }
        for (shapeID, handles) in handlesByShape {
            applyHandleUpdatesToShape(shapeID: shapeID, handleUpdates: handles)
        }
        selectedHandles = originalSelectedHandles
        livePointPositions.removeAll()
        liveHandlePositions.removeAll()
        document.viewState.isLivePointDrag = false
        isDraggingPoint = false
        isDraggingHandle = false
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
        var affectedShapeIDs = Set<UUID>()
        for pointID in selectedPoints {
            affectedShapeIDs.insert(pointID.shapeID)
        }
        for handleID in selectedHandles {
            affectedShapeIDs.insert(handleID.shapeID)
        }
        var affectedLayers = Set<Int>()
        for shapeID in affectedShapeIDs {
            if let object = document.snapshot.objects[shapeID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
        if !originalDragShapes.isEmpty {
            var newShapes: [UUID: VectorShape] = [:]
            var objectIDs: [UUID] = []
            for (shapeID, _) in originalDragShapes {
                objectIDs.append(shapeID)
                if let updatedShape = document.findShape(by: shapeID) {
                    newShapes[shapeID] = updatedShape
                }
            }
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: originalDragShapes, newShapes: newShapes)
            document.commandManager.execute(command)
            originalDragShapes.removeAll()
        }
    }

    private func findCurveSegmentInSelectedShapes(at location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        for objectID in selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID],
                  case .shape(let shape) = object.objectType,
                  shape.isVisible && !shape.isLocked else { continue }
            var previousPoint: VectorPoint?
            var firstPoint: VectorPoint?
            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .move(let to):
                    previousPoint = to
                    firstPoint = to
                case .line(let to):
                    if let prev = previousPoint {
                        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                        let end = to.cgPoint.applying(shape.transform)
                        if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                            return (shape.id, elementIndex)
                        }
                    }
                    previousPoint = to
                case .curve(let to, let control1, let control2):
                    if let prev = previousPoint {
                        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                        let c1 = control1.cgPoint.applying(shape.transform)
                        let c2 = control2.cgPoint.applying(shape.transform)
                        let end = to.cgPoint.applying(shape.transform)
                        if isPointNearBezierCurve(point: location, p0: start, p1: c1, p2: c2, p3: end, tolerance: tolerance) {
                            return (shape.id, elementIndex)
                        }
                    }
                    previousPoint = to
                case .quadCurve(let to, _):
                    previousPoint = to
                case .close:
                    if let prev = previousPoint, let first = firstPoint {
                        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                        let end = CGPoint(x: first.x, y: first.y).applying(shape.transform)
                        if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                            return (shape.id, elementIndex)
                        }
                    }
                }
            }
        }
        return nil
    }

    private func calculateTOnCurveSegment(shape: VectorShape, elementIndex: Int, point: CGPoint) -> Double {
        guard elementIndex < shape.path.elements.count,
              case .curve(let to, let control1, let control2) = shape.path.elements[elementIndex] else {
            return 0.5
        }
        var previousPoint: VectorPoint?
        for (idx, element) in shape.path.elements.enumerated() {
            if idx == elementIndex {
                break
            }
            switch element {
            case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                previousPoint = to
            default:
                break
            }
        }
        guard let prev = previousPoint else { return 0.5 }
        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
        let c1 = control1.cgPoint.applying(shape.transform)
        let c2 = control2.cgPoint.applying(shape.transform)
        let end = to.cgPoint.applying(shape.transform)

        var bestT: Double = 0.5
        var bestDistance: Double = Double.infinity
        for i in 0...100 {
            let t = Double(i) / 100.0
            let curvePoint = evaluateCubicBezier(p0: start, p1: c1, p2: c2, p3: end, t: t)
            let dist = distance(point, curvePoint)
            if dist < bestDistance {
                bestDistance = dist
                bestT = t
            }
        }
        return bestT
    }

    private func captureOriginalHandlesForCurveSegment(shapeID: UUID, elementIndex: Int, maintainTangency: Bool = true) {
        originalHandlePositions.removeAll()
        liveHandlePositions.removeAll()
        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType,
              elementIndex < shape.path.elements.count else { return }
        let element = shape.path.elements[elementIndex]
        if case .line = element {
            return
        }
        guard case .curve(_, let control1, let control2) = element else { return }
        let control1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)
        let control2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)
        originalHandlePositions[control1HandleID] = control1
        originalHandlePositions[control2HandleID] = control2
        if maintainTangency {
            let isClosed = shape.path.elements.last.map { element in
                if case .close = element { return true }
                return false
            } ?? false
            var lastCurveIndex = shape.path.elements.count - 1
            if isClosed && lastCurveIndex >= 0, case .close = shape.path.elements[lastCurveIndex] {
                lastCurveIndex -= 1
            }
            let prevIndex = elementIndex - 1
            if prevIndex >= 0, case .curve(_, _, let prevControl2) = shape.path.elements[prevIndex] {
                let prevControl2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                originalHandlePositions[prevControl2HandleID] = prevControl2
            } else if isClosed && elementIndex == 1 {
                if lastCurveIndex >= 0, case .curve(_, _, let lastControl2) = shape.path.elements[lastCurveIndex] {
                    let lastControl2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
                    originalHandlePositions[lastControl2HandleID] = lastControl2
                }
            }
            let nextIndex = elementIndex + 1
            if nextIndex < shape.path.elements.count, case .curve(_, let nextControl1, _) = shape.path.elements[nextIndex] {
                let nextControl1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                originalHandlePositions[nextControl1HandleID] = nextControl1
            } else if isClosed && elementIndex == lastCurveIndex {
                if shape.path.elements.count > 1, case .curve(_, let firstControl1, _) = shape.path.elements[1] {
                    let firstControl1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                    originalHandlePositions[firstControl1HandleID] = firstControl1
                }
            }
        }
    }

    private func convertCloseSegmentToCurveAndDrag(shape: VectorShape, elementIndex: Int, offset: CGPoint, curveSegment: (shapeID: UUID, elementIndex: Int)) {
        var firstPoint: VectorPoint?
        if case .move(let to) = shape.path.elements[0] {
            firstPoint = to
        }
        var lastPoint: VectorPoint?

        let prevIndex = elementIndex - 1
        if prevIndex >= 0 {
            switch shape.path.elements[prevIndex] {
            case .move(let prev), .line(let prev):
                lastPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                lastPoint = prev
            default:
                break
            }
        }
        guard let start = lastPoint, let end = firstPoint else { return }
        let control1 = VectorPoint(
            start.x + (end.x - start.x) / 3.0,
            start.y + (end.y - start.y) / 3.0
        )
        let control2 = VectorPoint(
            start.x + 2.0 * (end.x - start.x) / 3.0,
            start.y + 2.0 * (end.y - start.y) / 3.0
        )
        document.updateShapeByID(curveSegment.shapeID) { updatedShape in
            updatedShape.path.elements[elementIndex] = .curve(to: end, control1: control1, control2: control2)
            updatedShape.updateBounds()
        }
        captureOriginalHandlesForCurveSegment(shapeID: curveSegment.shapeID, elementIndex: elementIndex, maintainTangency: false)
        guard let updatedObject = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let updatedShape) = updatedObject.objectType,
              case .curve = updatedShape.path.elements[elementIndex] else { return }
        dragCurveSegmentWithHandles(shape: updatedShape, curveSegment: curveSegment, offset: offset)
    }

    private func convertLineToCurveAndDrag(shape: VectorShape, elementIndex: Int, to: VectorPoint, offset: CGPoint, curveSegment: (shapeID: UUID, elementIndex: Int)) {
        var prevPoint: VectorPoint?
        if elementIndex > 0 {
            switch shape.path.elements[elementIndex - 1] {
            case .move(let prev), .line(let prev):
                prevPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                prevPoint = prev
            default:
                break
            }
        }
        guard let start = prevPoint else { return }
        let control1 = VectorPoint(
            start.x + (to.x - start.x) / 3.0,
            start.y + (to.y - start.y) / 3.0
        )
        let control2 = VectorPoint(
            start.x + 2.0 * (to.x - start.x) / 3.0,
            start.y + 2.0 * (to.y - start.y) / 3.0
        )
        document.updateShapeByID(curveSegment.shapeID) { updatedShape in
            updatedShape.path.elements[elementIndex] = .curve(to: to, control1: control1, control2: control2)
            updatedShape.updateBounds()
        }
        captureOriginalHandlesForCurveSegment(shapeID: curveSegment.shapeID, elementIndex: elementIndex, maintainTangency: false)
        guard let updatedObject = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let updatedShape) = updatedObject.objectType,
              case .curve = updatedShape.path.elements[elementIndex] else { return }
        dragCurveSegmentWithHandles(shape: updatedShape, curveSegment: curveSegment, offset: offset)
    }

    private func handleCloseSegmentDrag(shape: VectorShape, elementIndex: Int, offset: CGPoint) {
        var firstPoint: VectorPoint?
        if case .move(let to) = shape.path.elements[0] {
            firstPoint = to
        }
        var lastPoint: VectorPoint?

        let prevIndex = elementIndex - 1
        if prevIndex >= 0 {
            switch shape.path.elements[prevIndex] {
            case .move(let prev), .line(let prev):
                lastPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                lastPoint = prev
            default:
                break
            }
        }
        guard let first = firstPoint, let last = lastPoint else { return }
        let dx = first.x - last.x
        let dy = first.y - last.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0.001 else { return }
        let dirX = dx / length
        let dirY = dy / length
        let perpX = -dirY
        let perpY = dirX
        let perpDist = offset.x * perpX + offset.y * perpY
        let moveOffset = CGPoint(x: perpDist * perpX, y: perpDist * perpY)
        let firstPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: 0)
        let lastPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex)
        livePointPositions[firstPointID] = CGPoint(x: first.x + moveOffset.x, y: first.y + moveOffset.y)
        livePointPositions[lastPointID] = CGPoint(x: last.x + moveOffset.x, y: last.y + moveOffset.y)
    }

    private func handleLineSegmentDrag(shape: VectorShape, elementIndex: Int, to: VectorPoint, offset: CGPoint) {
        var prevPoint: VectorPoint?
        if elementIndex > 0 {
            switch shape.path.elements[elementIndex - 1] {
            case .move(let prev), .line(let prev):
                prevPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                prevPoint = prev
            default:
                break
            }
        }
        guard let start = prevPoint else { return }
        let dx = to.x - start.x
        let dy = to.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0.001 else { return }
        let dirX = dx / length
        let dirY = dy / length
        let perpX = -dirY
        let perpY = dirX
        let perpDist = offset.x * perpX + offset.y * perpY
        let moveOffset = CGPoint(x: perpDist * perpX, y: perpDist * perpY)
        let startPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex - 1)
        let endPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
        livePointPositions[startPointID] = CGPoint(x: start.x + moveOffset.x, y: start.y + moveOffset.y)
        livePointPositions[endPointID] = CGPoint(x: to.x + moveOffset.x, y: to.y + moveOffset.y)
    }

    private func handleCurveSegmentDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let curveSegment = draggedCurveSegment else { return }
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        let offset = CGPoint(
            x: currentLocation.x - dragStartLocation.x,
            y: currentLocation.y - dragStartLocation.y
        )
        guard let object = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let shape) = object.objectType,
              curveSegment.elementIndex < shape.path.elements.count else { return }
        let element = shape.path.elements[curveSegment.elementIndex]
        if case .line(let to) = element {
            let optionKeyPressed = NSEvent.modifierFlags.contains(.option)
            if optionKeyPressed {
                convertLineToCurveAndDrag(shape: shape, elementIndex: curveSegment.elementIndex, to: to, offset: offset, curveSegment: curveSegment)
                return
            } else {
                handleLineSegmentDrag(shape: shape, elementIndex: curveSegment.elementIndex, to: to, offset: offset)
                return
            }
        }
        if case .close = element {
            let optionKeyPressed = NSEvent.modifierFlags.contains(.option)
            if optionKeyPressed {
                convertCloseSegmentToCurveAndDrag(shape: shape, elementIndex: curveSegment.elementIndex, offset: offset, curveSegment: curveSegment)
                return
            } else {
                handleCloseSegmentDrag(shape: shape, elementIndex: curveSegment.elementIndex, offset: offset)
                return
            }
        }
        dragCurveSegmentWithHandles(shape: shape, curveSegment: curveSegment, offset: offset)
    }

    private func dragCurveSegmentWithHandles(shape: VectorShape, curveSegment: (shapeID: UUID, elementIndex: Int), offset: CGPoint) {
        let t = curveSegmentDragT
        let control1Weight = 1.0 - t
        let control2Weight = t
        let control1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: curveSegment.elementIndex, handleType: .control1)
        let control2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: curveSegment.elementIndex, handleType: .control2)
        let isClosed = shape.path.elements.last.map { element in
            if case .close = element { return true }
            return false
        } ?? false
        var lastCurveIndex = shape.path.elements.count - 1
        if isClosed && lastCurveIndex >= 0, case .close = shape.path.elements[lastCurveIndex] {
            lastCurveIndex -= 1
        }
        if let originalControl1 = originalHandlePositions[control1HandleID] {
            let newControl1Pos = CGPoint(
                x: originalControl1.x + offset.x * control1Weight,
                y: originalControl1.y + offset.y * control1Weight
            )
            liveHandlePositions[control1HandleID] = newControl1Pos
            let prevIndex = curveSegment.elementIndex - 1

            var anchorA: CGPoint?
            if prevIndex >= 0 {
                if case .curve(let toA, _, _) = shape.path.elements[prevIndex] {
                    anchorA = CGPoint(x: toA.x, y: toA.y)
                } else if case .move(let toA) = shape.path.elements[prevIndex] {
                    anchorA = CGPoint(x: toA.x, y: toA.y)
                }
            }
            if prevIndex >= 0, let anchor = anchorA {
                if case .curve = shape.path.elements[prevIndex] {
                    let prevControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                    if let originalPrevControl2 = originalHandlePositions[prevControl2HandleID] {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalPrevControl2.x, y: originalPrevControl2.y)
                        )
                        liveHandlePositions[prevControl2HandleID] = linkedPos
                        visibleHandles.insert(prevControl2HandleID)
                    }
                }
                else if case .move = shape.path.elements[prevIndex], isClosed {
                    let lastControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
                    if let originalLastControl2 = originalHandlePositions[lastControl2HandleID] {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                        )
                        liveHandlePositions[lastControl2HandleID] = linkedPos
                        visibleHandles.insert(lastControl2HandleID)
                    }
                }
            } else if isClosed && curveSegment.elementIndex == 1 {
                let lastControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
                if let originalLastControl2 = originalHandlePositions[lastControl2HandleID] {
                    var anchorA: CGPoint?
                    if case .curve(let toA, _, _) = shape.path.elements[lastCurveIndex] {
                        anchorA = CGPoint(x: toA.x, y: toA.y)
                    }
                    if let anchor = anchorA {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                        )
                        liveHandlePositions[lastControl2HandleID] = linkedPos
                        visibleHandles.insert(lastControl2HandleID)
                    }
                }
            }
        }
        if let originalControl2 = originalHandlePositions[control2HandleID] {
            let newControl2Pos = CGPoint(
                x: originalControl2.x + offset.x * control2Weight,
                y: originalControl2.y + offset.y * control2Weight
            )
            liveHandlePositions[control2HandleID] = newControl2Pos
            let nextIndex = curveSegment.elementIndex + 1
            if nextIndex < shape.path.elements.count, case .curve = shape.path.elements[nextIndex] {
                let nextControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                if let originalNextControl1 = originalHandlePositions[nextControl1HandleID] {
                    var anchorB: CGPoint?
                    if case .curve(let toB, _, _) = shape.path.elements[curveSegment.elementIndex] {
                        anchorB = CGPoint(x: toB.x, y: toB.y)
                    }
                    if let anchor = anchorB {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl2Pos,
                            originalOppositeHandle: CGPoint(x: originalNextControl1.x, y: originalNextControl1.y)
                        )
                        liveHandlePositions[nextControl1HandleID] = linkedPos
                        visibleHandles.insert(nextControl1HandleID)
                        handleCoincidentForLiveHandle(handleID: nextControl1HandleID, newPosition: linkedPos, shape: shape)
                    }
                }
            } else if isClosed && curveSegment.elementIndex == lastCurveIndex {
                let firstControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                if let originalFirstControl1 = originalHandlePositions[firstControl1HandleID] {
                    var anchorB: CGPoint?
                    if case .curve(let toB, _, _) = shape.path.elements[curveSegment.elementIndex] {
                        anchorB = CGPoint(x: toB.x, y: toB.y)
                    }
                    if let anchor = anchorB {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl2Pos,
                            originalOppositeHandle: CGPoint(x: originalFirstControl1.x, y: originalFirstControl1.y)
                        )
                        liveHandlePositions[firstControl1HandleID] = linkedPos
                        visibleHandles.insert(firstControl1HandleID)
                    }
                }
            }
        }
        visibleHandles.insert(control1HandleID)
        visibleHandles.insert(control2HandleID)
        let prevIndex = curveSegment.elementIndex - 1
        if prevIndex >= 0 {
            let prevControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
            visibleHandles.insert(prevControl2HandleID)
        } else if isClosed && curveSegment.elementIndex == 1 {
            let lastControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
            visibleHandles.insert(lastControl2HandleID)
        }
        let nextIndex = curveSegment.elementIndex + 1
        if nextIndex < shape.path.elements.count, case .curve = shape.path.elements[nextIndex] {
            let nextControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
            visibleHandles.insert(nextControl1HandleID)
        } else if isClosed && curveSegment.elementIndex == lastCurveIndex {
            let firstControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
            visibleHandles.insert(firstControl1HandleID)
        }
    }

    private func finishCurveSegmentDrag() {
        guard let curveSegment = draggedCurveSegment else { return }
        guard let object = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let originalShape) = object.objectType else {
            liveHandlePositions.removeAll()
            originalHandlePositions.removeAll()
            return
        }
        var handlesByShape: [UUID: [(HandleID, CGPoint)]] = [:]
        for (handleID, livePosition) in liveHandlePositions {
            handlesByShape[handleID.shapeID, default: []].append((handleID, livePosition))
        }
        for (shapeID, handles) in handlesByShape {
            applyHandleUpdatesToShape(shapeID: shapeID, handleUpdates: handles)
        }
        var pointsByShape: [UUID: [(PointID, CGPoint)]] = [:]
        for (pointID, livePosition) in livePointPositions {
            pointsByShape[pointID.shapeID, default: []].append((pointID, livePosition))
        }
        for (shapeID, points) in pointsByShape {
            applyPointUpdatesToShape(shapeID: shapeID, pointUpdates: points)
        }
        liveHandlePositions.removeAll()
        livePointPositions.removeAll()
        originalHandlePositions.removeAll()
        if let updatedShape = document.findShape(by: curveSegment.shapeID) {
            let command = ShapeModificationCommand(
                objectIDs: [curveSegment.shapeID],
                oldShapes: [curveSegment.shapeID: originalShape],
                newShapes: [curveSegment.shapeID: updatedShape]
            )
            document.commandManager.execute(command)
        }
    }

    private func isPointNearLineSegment(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: Double) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            let dist = point.distance(to: start)
            return dist <= tolerance
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let closestX = start.x + t * dx
        let closestY = start.y + t * dy
        let distance = sqrt(pow(point.x - closestX, 2) + pow(point.y - closestY, 2))
        return distance <= tolerance
    }

    private func isPointNearBezierCurve(point: CGPoint, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tolerance: Double) -> Bool {
        for i in 0...20 {
            let t = Double(i) / 20.0
            let curvePoint = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
            if distance(point, curvePoint) <= tolerance {
                return true
            }
        }
        return false
    }

    private func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let mt = 1.0 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t
        return CGPoint(
            x: mt3 * p0.x + 3.0 * mt2 * t * p1.x + 3.0 * mt * t2 * p2.x + t3 * p3.x,
            y: mt3 * p0.y + 3.0 * mt2 * t * p1.y + 3.0 * mt * t2 * p2.y + t3 * p3.y
        )
    }
}
