import SwiftUI
import SwiftUI

extension DrawingCanvas {

    func findCoincidentPoints(to targetPointID: PointID, tolerance: Double = 1.0) -> Set<PointID> {
        guard let targetPosition = getPointPosition(targetPointID) else { return [] }
        var coincidentPoints: Set<PointID> = []

        let targetPoint = CGPoint(x: targetPosition.x, y: targetPosition.y)

		let allowedShapeIDs: Set<UUID> = {
			let active = document.getActiveShapeIDs()
			return active.isEmpty ? [targetPointID.shapeID] : active
		}()
        for layerIndex in document.snapshot.layers.indices {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible { continue }
			let shapes = document.getShapesForLayer(layerIndex)
			for shape in shapes {
				if !allowedShapeIDs.contains(shape.id) { continue }
                if !shape.isVisible { continue }
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let pointID = PointID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex
                    )
                    if pointID == targetPointID { continue }
                    let elementPoint: CGPoint?
                    switch element {
                    case .move(let to), .line(let to):
                        elementPoint = to.cgPoint
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        elementPoint = to.cgPoint
                    case .close:
                        elementPoint = nil
                    }
                    if let checkPoint = elementPoint {
                        let distance = targetPoint.distance(to: checkPoint)
                        if distance <= tolerance {
                            coincidentPoints.insert(pointID)
                        }
                    }
                }
            }
        }
        return coincidentPoints
    }

    func selectPointWithCoincidents(_ pointID: PointID, addToSelection: Bool = false) {
        if !addToSelection {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
        }
        selectedPoints.insert(pointID)
        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        for coincidentPoint in coincidentPoints {
            selectedPoints.insert(coincidentPoint)
        }
        let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
        for endpointID in closedPathEndpoints {
            selectedPoints.insert(endpointID)
        }
        showHandlesForSelectedPoints()
    }

    internal func showHandlesForSelectedPoints() {
        for pointID in selectedPoints {
            guard let object = document.snapshot.objects[pointID.shapeID],
                  case .shape(let shape) = object.objectType,
                  pointID.elementIndex < shape.path.elements.count else { continue }
            let element = shape.path.elements[pointID.elementIndex]
            if case .curve = element {
                let incomingHandle = HandleID(shapeID: pointID.shapeID, pathIndex: 0, elementIndex: pointID.elementIndex, handleType: .control2)
                visibleHandles.insert(incomingHandle)
            }
            if pointID.elementIndex + 1 < shape.path.elements.count {
                if case .curve = shape.path.elements[pointID.elementIndex + 1] {
                    let outgoingHandle = HandleID(shapeID: pointID.shapeID, pathIndex: 0, elementIndex: pointID.elementIndex + 1, handleType: .control1)
                    visibleHandles.insert(outgoingHandle)
                }
            }
        }
    }

    func findClosedPathEndpoints(for pointID: PointID) -> Set<PointID> {
        var endpointPairs: Set<PointID> = []
        if let vectorObject = document.findObject(by: pointID.shapeID),
           case .shape(let shape) = vectorObject.objectType {
                let hasCloseElement = shape.path.elements.contains { element in
                    if case .close = element { return true }
                    return false
                }
                if hasCloseElement {
                    var moveToIndex: Int?
                    var lastPointIndex: Int?
                    var moveToPoint: VectorPoint?
                    var lastPoint: VectorPoint?
                    for (index, element) in shape.path.elements.enumerated() {
                        switch element {
                        case .move(let to):
                            if moveToIndex == nil {
                                moveToIndex = index
                                moveToPoint = to
                            }
                        case .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                            lastPointIndex = index
                            lastPoint = to
                        case .close:
                            break
                        }
                    }
                    if let moveIndex = moveToIndex, let lastIndex = lastPointIndex,

                       let firstPoint = moveToPoint, let endPoint = lastPoint {
                        let distance = firstPoint.distance(to: endPoint)
                        let tolerance = 0.1
                        if distance <= tolerance {
                            if pointID.elementIndex == moveIndex {
                                endpointPairs.insert(PointID(shapeID: pointID.shapeID, pathIndex: pointID.pathIndex, elementIndex: lastIndex))
                            } else if pointID.elementIndex == lastIndex {
                                endpointPairs.insert(PointID(shapeID: pointID.shapeID, pathIndex: pointID.pathIndex, elementIndex: moveIndex))
                            }
                        }
                    }
                }
        }
        return endpointPairs
    }

    func analyzeCoincidentPoints() {
        var totalCoincidentGroups = 0
        var processedPoints: Set<PointID> = []
        for layerIndex in document.snapshot.layers.indices {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible { continue }
            let shapes = document.getShapesForLayer(layerIndex)
            for shape in shapes {
                if !shape.isVisible { continue }
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let pointID = PointID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex
                    )
                    if processedPoints.contains(pointID) { continue }
                    switch element {
                    case .move(_), .line(_), .curve(_, _, _), .quadCurve(_, _):
                        break
                    case .close:
                        continue
                    }
                    let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                    if !coincidentPoints.isEmpty {
                        totalCoincidentGroups += 1
                        if getPointPosition(pointID) != nil {
                            processedPoints.insert(pointID)
                            for coincidentPoint in coincidentPoints {
                                processedPoints.insert(coincidentPoint)
                            }
                        }
                    }
                }
            }
        }
    }

    func moveCoincidentPointsWithSmoothLogic(pointID: PointID, to newPosition: CGPoint, delta: CGPoint) {
        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        for coincidentPointID in coincidentPoints {
            if coincidentPointID == pointID { continue }
            for layerIndex in document.snapshot.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == coincidentPointID.shapeID }) {
                    guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                    guard coincidentPointID.elementIndex < shape.path.elements.count else { continue }
                    var updatedShape = shape
                    var elements = shape.path.elements

                    let newPoint = VectorPoint(newPosition.x, newPosition.y)
                    switch elements[coincidentPointID.elementIndex] {
                    case .move(_):
                        elements[coincidentPointID.elementIndex] = .move(to: newPoint)
                    case .line(_):
                        elements[coincidentPointID.elementIndex] = .line(to: newPoint)
                    case .curve(_, let control1, let control2):
                        elements[coincidentPointID.elementIndex] = .curve(to: newPoint, control1: control1, control2: control2)
                    case .quadCurve(_, let control):
                        elements[coincidentPointID.elementIndex] = .quadCurve(to: newPoint, control: control)
                    case .close:
                        continue
                    }
                    if isSmoothCurvePoint(elements: elements, elementIndex: coincidentPointID.elementIndex) {
                        moveSmoothCurveHandles(elements: &elements, elementIndex: coincidentPointID.elementIndex, delta: delta)
                    }
                    updatedShape.path.elements = elements
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    break
                }
            }
        }
    }

    private func isSmoothCurvePoint(elements: [PathElement], elementIndex: Int) -> Bool {
        guard elementIndex < elements.count else { return false }
        switch elements[elementIndex] {
        case .curve(let to, _, let control2):
            let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)

            var outgoingHandleCollapsed = true
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(_, let nextControl1, _) = nextElement {
                    outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                }
            }
            return !incomingHandleCollapsed && !outgoingHandleCollapsed
        default:
            return false
        }
    }

    private func moveSmoothCurveHandles(elements: inout [PathElement], elementIndex: Int, delta: CGPoint) {
        guard elementIndex < elements.count else { return }
        switch elements[elementIndex] {
        case .curve(let to, let control1, let control2):
            let anchorPoint = to.cgPoint
            let newControl2 = VectorPoint(control2.x + delta.x, control2.y + delta.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: newControl2)
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    let oppositeHandle = calculateLinkedHandle(
                        anchorPoint: anchorPoint,
                        draggedHandle: CGPoint(x: newControl2.x, y: newControl2.y),
                        originalOppositeHandle: CGPoint(x: nextControl1.x, y: nextControl1.y)
                    )
                    let newNextControl1 = VectorPoint(oppositeHandle.x, oppositeHandle.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
        default:
            break
        }
    }

    @discardableResult
    func handleCoincidentSmoothPoints(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) -> Bool {
        if handleFirstLastCoincidentPoints(elements: &elements, draggedHandleID: draggedHandleID, newDraggedPosition: newDraggedPosition) {
            return true
        }
        if let object = document.snapshot.objects[draggedHandleID.shapeID],
           case .shape(let shape) = object.objectType {
            let anchorElementIndex: Int
            if draggedHandleID.handleType == .control2 {
                anchorElementIndex = draggedHandleID.elementIndex
            } else {
                anchorElementIndex = draggedHandleID.elementIndex - 1
            }
            if let explicitType = shape.anchorTypes[anchorElementIndex] {
                switch explicitType {
                case .cusp, .corner:
                    return false
                case .smooth, .auto:
                    break
                }
            } else {
            }
        }
        let anchorPoint: CGPoint?
        let draggedPointID: PointID
        if draggedHandleID.handleType == .control1 {
            let prevIndex = draggedHandleID.elementIndex - 1
            if prevIndex >= 0 {
                switch elements[prevIndex] {
                case .curve(let to, _, _), .line(let to), .quadCurve(let to, _), .move(let to):
                    anchorPoint = to.cgPoint
                    draggedPointID = PointID(shapeID: draggedHandleID.shapeID, pathIndex: 0, elementIndex: prevIndex)
                default:
                    return false
                }
            } else {
                return false
            }
        } else if draggedHandleID.handleType == .control2 {
            switch elements[draggedHandleID.elementIndex] {
            case .curve(let to, _, _):
                anchorPoint = to.cgPoint
                draggedPointID = PointID(shapeID: draggedHandleID.shapeID, pathIndex: 0, elementIndex: draggedHandleID.elementIndex)
            default:
                return false
            }
        } else {
            return false
        }
        guard let anchor = anchorPoint else { return false }
        let coincidentPoints = findCoincidentPointsInSameShape(
            shapeID: draggedHandleID.shapeID,
            anchorPosition: anchor,
            elements: elements,
            excludeIndex: draggedPointID.elementIndex
        )
        if coincidentPoints.isEmpty {
            return false
        }
        for coincidentIndex in coincidentPoints {
            if draggedHandleID.handleType == .control1 {
                if case .curve(let to, let control1, let control2) = elements[coincidentIndex] {
                    let oppositeHandle = calculateLinkedHandle(
                        anchorPoint: anchor,
                        draggedHandle: newDraggedPosition,
                        originalOppositeHandle: control2.cgPoint
                    )
                    elements[coincidentIndex] = .curve(
                        to: to,
                        control1: control1,
                        control2: VectorPoint(oppositeHandle.x, oppositeHandle.y)
                    )
                    let oppositeHandleID = HandleID(
                        shapeID: draggedHandleID.shapeID,
                        pathIndex: 0,
                        elementIndex: coincidentIndex,
                        handleType: .control2
                    )
                    visibleHandles.insert(oppositeHandleID)
                }
            } else if draggedHandleID.handleType == .control2 {
                let nextIndex = coincidentIndex + 1
                if nextIndex < elements.count {
                    if case .curve(let to, let control1, let control2) = elements[nextIndex] {
                        let oppositeHandle = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newDraggedPosition,
                            originalOppositeHandle: control1.cgPoint
                        )
                        elements[nextIndex] = .curve(
                            to: to,
                            control1: VectorPoint(oppositeHandle.x, oppositeHandle.y),
                            control2: control2
                        )
                        let oppositeHandleID = HandleID(
                            shapeID: draggedHandleID.shapeID,
                            pathIndex: 0,
                            elementIndex: nextIndex,
                            handleType: .control1
                        )
                        visibleHandles.insert(oppositeHandleID)
                    }
                }
            }
        }
        if draggedHandleID.handleType == .control1 {
            elements[draggedHandleID.elementIndex] = updateElementControl1(
                elements[draggedHandleID.elementIndex],
                newControl1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y)
            )
        } else if draggedHandleID.handleType == .control2 {
            elements[draggedHandleID.elementIndex] = updateElementControl2(
                elements[draggedHandleID.elementIndex],
                newControl2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y)
            )
        }
        return !coincidentPoints.isEmpty
    }

    private func findCoincidentPointsInSameShape(
        shapeID: UUID,
        anchorPosition: CGPoint,
        elements: [PathElement],
        excludeIndex: Int
    ) -> [Int] {
        var coincidentIndices: [Int] = []

        let tolerance = 0.1
        for (index, element) in elements.enumerated() {
            if index == excludeIndex { continue }
            let elementPoint: CGPoint?
            switch element {
            case .move(let to), .line(let to):
                elementPoint = to.cgPoint
            case .curve(let to, _, _), .quadCurve(let to, _):
                elementPoint = to.cgPoint
            case .close:
                elementPoint = nil
            }
            if let point = elementPoint {
                let distance = anchorPosition.distance(to: point)
                if distance <= tolerance {
                    coincidentIndices.append(index)
                }
            }
        }
        return coincidentIndices
    }

    private func handleFirstLastCoincidentPoints(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) -> Bool {
        guard elements.count >= 2 else { return false }
        if let object = document.snapshot.objects[draggedHandleID.shapeID],
           case .shape(let shape) = object.objectType,

           let explicitType = shape.anchorTypes[0] {
            switch explicitType {
            case .cusp, .corner:
                return false
            case .smooth:
                break
            case .auto:
                break
            }
        } else {
        }
        let firstPoint: CGPoint?
        let lastPoint: CGPoint?
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            firstPoint = nil
        }
        var lastElementIndex = elements.count - 1
        if lastElementIndex >= 0 {
            if case .close = elements[lastElementIndex] {
                lastElementIndex -= 1
            }
        }
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
        let anchorPoint = first
        if draggedHandleID.handleType == .control1 && draggedHandleID.elementIndex == 1 {
            if case .curve(let lastTo, let lastControl1, let lastControl2) = elements[lastElementIndex] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: lastControl2.x, y: lastControl2.y)
                )
                elements[draggedHandleID.elementIndex] = updateElementControl1(elements[draggedHandleID.elementIndex], newControl1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[lastElementIndex] = .curve(to: lastTo, control1: lastControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y))
                let oppositeHandleID = HandleID(
                    shapeID: draggedHandleID.shapeID,
                    pathIndex: 0,
                    elementIndex: lastElementIndex,
                    handleType: .control2
                )
                selectedHandles.insert(oppositeHandleID)
                return true
            }
        } else if draggedHandleID.handleType == .control2 && draggedHandleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(let secondTo, let secondControl1, let secondControl2) = elements[1] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: secondControl1.x, y: secondControl1.y)
                )
                elements[draggedHandleID.elementIndex] = updateElementControl2(elements[draggedHandleID.elementIndex], newControl2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[1] = .curve(to: secondTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: secondControl2)
                let oppositeHandleID = HandleID(
                    shapeID: draggedHandleID.shapeID,
                    pathIndex: 0,
                    elementIndex: 1,
                    handleType: .control1
                )
                selectedHandles.insert(oppositeHandleID)
                return true
            }
        }
        return false
    }

    func updateElementControl1(_ element: PathElement, newControl1: VectorPoint) -> PathElement {
        switch element {
        case .curve(let to, _, let control2):
            return .curve(to: to, control1: newControl1, control2: control2)
        case .quadCurve(let to, _):
            return .quadCurve(to: to, control: newControl1)
        default:
            return element
        }
    }

    func updateElementControl2(_ element: PathElement, newControl2: VectorPoint) -> PathElement {
        switch element {
        case .curve(let to, let control1, _):
            return .curve(to: to, control1: control1, control2: newControl2)
        default:
            return element
        }
    }
}
