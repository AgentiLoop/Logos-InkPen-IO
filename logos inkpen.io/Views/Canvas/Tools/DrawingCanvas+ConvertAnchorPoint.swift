import SwiftUI
import Combine

extension DrawingCanvas {

    func handleConvertAnchorPointTap(at location: CGPoint) {
        let baseTolerance: Double = 8.0
        let zoomLevel = zoomLevel
        let tolerance = max(2.0, baseTolerance / zoomLevel)
        if let restoreResult = restoreCollapsedHandlesIfClicked(at: location, tolerance: tolerance) {
            enableDirectSelectionForConvertedPoint(shapeID: restoreResult.shapeID, elementIndex: restoreResult.elementIndex)
            return
        }
        if let collapseResult = collapseHandleIfClicked(at: location, tolerance: tolerance) {
            enableDirectSelectionForConvertedPoint(shapeID: collapseResult.shapeID, elementIndex: collapseResult.elementIndex)
            return
        }
        tryToSelectShapeForConvertTool(at: location)
    }

    func restoreCollapsedHandlesIfClicked(at location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        for layerIndex in document.snapshot.layers.indices.reversed() {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible { continue }
            if layer.isLocked {
                continue
            }
            let shapes = document.getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                var clickedAnchorPoint: VectorPoint?
                var clickedElementIndex: Int?
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .curve(let to, _, _), .move(let to), .line(let to), .quadCurve(let to, _):
                        let anchorPointLocation = to.cgPoint
                        if distance(location, anchorPointLocation) <= tolerance {
                            clickedAnchorPoint = to
                            clickedElementIndex = elementIndex
                            break
                        }
                    default:
                        break
                    }
                }
                if let anchorPoint = clickedAnchorPoint, let elementIndex = clickedElementIndex {
                    var hasCollapsedHandles = false
                    for (_, checkElement) in shape.path.elements.enumerated() {
                        switch checkElement {
                        case .curve(_, let control1, let control2):
                            let control1Collapsed = (abs(control1.x - anchorPoint.x) < 0.1 && abs(control1.y - anchorPoint.y) < 0.1)
                            let control2Collapsed = (abs(control2.x - anchorPoint.x) < 0.1 && abs(control2.y - anchorPoint.y) < 0.1)
                            if control1Collapsed || control2Collapsed {
                                hasCollapsedHandles = true
                            }
                        default:
                            break
                        }
                    }
                    if hasCollapsedHandles {
                        restoreAllHandlesForAnchorPoint(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex, anchorPoint: anchorPoint)
                        return (shape.id, elementIndex)
                    }
                    if !hasCollapsedHandles {
                        let clickedElement = shape.path.elements[elementIndex]
                        if case .curve(_, let control1, let control2) = clickedElement {
                            let control1Extended = !(abs(control1.x - anchorPoint.x) < 0.1 && abs(control1.y - anchorPoint.y) < 0.1)
                            let control2Extended = !(abs(control2.x - anchorPoint.x) < 0.1 && abs(control2.y - anchorPoint.y) < 0.1)
                            if control1Extended && control2Extended {
                                collapseBothHandlesForAnchorPoint(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex, anchorPoint: anchorPoint)
                                return (shape.id, elementIndex)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    func collapseHandleIfClicked(at location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        for layerIndex in document.snapshot.layers.indices.reversed() {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible { continue }
            if layer.isLocked {
                continue
            }
            let shapes = document.getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .curve(let to, let control1, let control2):
                        let control1HandleLocation = control1.cgPoint
                        if distance(location, control1HandleLocation) <= tolerance {
                            let currentAnchorPoint: VectorPoint
                            if elementIndex > 0 {
                                let previousElement = shape.path.elements[elementIndex - 1]
                                switch previousElement {
                                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                                    currentAnchorPoint = to
                                case .close:
                                    currentAnchorPoint = VectorPoint(0, 0)
                                }
                            } else {
                                currentAnchorPoint = VectorPoint(0, 0)
                            }
                            let handleCollapsed = (abs(control1.x - currentAnchorPoint.x) < 0.1 && abs(control1.y - currentAnchorPoint.y) < 0.1)
                            if !handleCollapsed {
                                collapseControl1Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return (shape.id, elementIndex)
                            }
                        }
                        let control2HandleLocation = control2.cgPoint
                        if distance(location, control2HandleLocation) <= tolerance {
                            let handleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                            if !handleCollapsed {
                                collapseControl2Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                return (shape.id, elementIndex)
                            }
                        }
                    case .move(_), .line(_):
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(let nextTo, let nextControl1, _) = nextElement {
                                let control1HandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                if distance(location, control1HandleLocation) <= tolerance {
                                    let sourceAnchorPoint: VectorPoint
                                    switch element {
                                    case .move(let to), .line(let to):
                                        sourceAnchorPoint = to
                                    case .curve(let to, _, _), .quadCurve(let to, _):
                                        sourceAnchorPoint = to
                                    default:
                                        sourceAnchorPoint = nextTo
                                    }
                                    let handleCollapsed = (abs(nextControl1.x - sourceAnchorPoint.x) < 0.1 && abs(nextControl1.y - sourceAnchorPoint.y) < 0.1)
                                    if !handleCollapsed {
                                        collapseNextElementControl1Handle(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                        return (shape.id, elementIndex)
                                    }
                                }
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
        return nil
    }

    func collapseControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        let oldPath = shape.path
        let element = shape.path.elements[elementIndex]

        var elements = shape.path.elements
        switch element {
        case .curve(let to, let originalControl1, let control2):
            let handleKey = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control1"
            document.originalHandlePositions[handleKey] = originalControl1
            let currentAnchorPoint: VectorPoint
            if elementIndex > 0 {
                let previousElement = elements[elementIndex - 1]
                switch previousElement {
                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                    currentAnchorPoint = to
                case .close:
                    currentAnchorPoint = VectorPoint(0, 0)
                }
            } else {
                currentAnchorPoint = VectorPoint(0, 0)
            }
            let collapsedControl1 = VectorPoint(currentAnchorPoint.x, currentAnchorPoint.y)
            elements[elementIndex] = .curve(to: to, control1: collapsedControl1, control2: control2)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        case .quadCurve(let to, _):
            elements[elementIndex] = .line(to: to)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        default:
            break
        }
    }

    func collapseControl2Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        let oldPath = shape.path
        let element = shape.path.elements[elementIndex]

        var elements = shape.path.elements
        switch element {
        case .curve(let to, let control1, let originalControl2):
            let handleKey = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control2"
            document.originalHandlePositions[handleKey] = originalControl2
            let collapsedControl2 = VectorPoint(to.x, to.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: collapsedControl2)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        case .quadCurve(let to, _):
            elements[elementIndex] = .line(to: to)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        default:
            break
        }
    }

    func collapseNextElementControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex + 1 < shape.path.elements.count else { return }
        let oldPath = shape.path
        let nextElement = shape.path.elements[elementIndex + 1]

        var elements = shape.path.elements
        switch nextElement {
        case .curve(let to, let originalControl1, let control2):
            let handleKey = "\(layerIndex)_\(shapeIndex)_\(elementIndex + 1)_control1"
            document.originalHandlePositions[handleKey] = originalControl1
            let currentElement = elements[elementIndex]
            let sourceAnchorPoint: VectorPoint
            switch currentElement {
            case .move(let to), .line(let to):
                sourceAnchorPoint = to
            case .curve(let to, _, _), .quadCurve(let to, _):
                sourceAnchorPoint = to
            default:
                sourceAnchorPoint = to
            }
            elements[elementIndex + 1] = .curve(to: to, control1: sourceAnchorPoint, control2: control2)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        default:
            break
        }
    }

    func restoreHandlesForCurveElement(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        let oldPath = shape.path
        let element = shape.path.elements[elementIndex]

        var elements = shape.path.elements
        switch element {
        case .curve(let to, let control1, let control2):
            let control1Key = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control1"
            let control2Key = "\(layerIndex)_\(shapeIndex)_\(elementIndex)_control2"
            let control1X = UserDefaults.standard.double(forKey: "\(control1Key)_x")
            let control1Y = UserDefaults.standard.double(forKey: "\(control1Key)_y")
            let control2X = UserDefaults.standard.double(forKey: "\(control2Key)_x")
            let control2Y = UserDefaults.standard.double(forKey: "\(control2Key)_y")
            let hasControl1Original = (control1X != 0.0 || control1Y != 0.0)
            let hasControl2Original = (control2X != 0.0 || control2Y != 0.0)
            let control1Collapsed = (abs(control1.x - to.x) < 0.1 && abs(control1.y - to.y) < 0.1)
            let control2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)

            var restoredControl1 = control1
            var restoredControl2 = control2
            if control1Collapsed && hasControl1Original {
                restoredControl1 = VectorPoint(control1X, control1Y)
            }
            if control2Collapsed && hasControl2Original {
                restoredControl2 = VectorPoint(control2X, control2Y)
            }
            elements[elementIndex] = .curve(to: to, control1: restoredControl1, control2: restoredControl2)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        default:
            break
        }
    }

    func restoreNextElementControl1Handle(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex + 1 < shape.path.elements.count else { return }
        let oldPath = shape.path
        let nextElement = shape.path.elements[elementIndex + 1]

        var elements = shape.path.elements
        switch nextElement {
        case .curve(let to, _, let control2):
            let control1Key = "\(layerIndex)_\(shapeIndex)_\(elementIndex + 1)_control1"
            let control1X = UserDefaults.standard.double(forKey: "\(control1Key)_x")
            let control1Y = UserDefaults.standard.double(forKey: "\(control1Key)_y")
            let hasControl1Original = (control1X != 0.0 || control1Y != 0.0)

            var restoredControl1: VectorPoint
            if hasControl1Original {
                restoredControl1 = VectorPoint(control1X, control1Y)
            } else {
                let currentElement = elements[elementIndex]
                let sourceAnchorPoint: VectorPoint
                switch currentElement {
                case .move(let to), .line(let to):
                    sourceAnchorPoint = to
                case .curve(let to, _, _), .quadCurve(let to, _):
                    sourceAnchorPoint = to
                default:
                    sourceAnchorPoint = to
                }
                restoredControl1 = VectorPoint(
                    sourceAnchorPoint.x + (to.x - sourceAnchorPoint.x) * 0.33,
                    sourceAnchorPoint.y + (to.y - sourceAnchorPoint.y) * 0.33
                )
            }
            elements[elementIndex + 1] = .curve(to: to, control1: restoredControl1, control2: control2)
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        default:
            break
        }
    }

    func restoreAllHandlesForAnchorPoint(layerIndex: Int, shapeIndex: Int, elementIndex: Int, anchorPoint: VectorPoint) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        let oldPath = shape.path

        var elements = shape.path.elements
        var needsUpdate = false
        for (checkIndex, checkElement) in elements.enumerated() {
            if case .curve(let to, let control1, let control2) = checkElement {
                let control1Collapsed = (abs(control1.x - anchorPoint.x) < 0.1 && abs(control1.y - anchorPoint.y) < 0.1)
                let control2Collapsed = (abs(control2.x - anchorPoint.x) < 0.1 && abs(control2.y - anchorPoint.y) < 0.1)

                var restoredControl1 = control1
                var restoredControl2 = control2
                var elementNeedsUpdate = false
                if control1Collapsed {
                    let control1Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control1"
                    if let originalPosition = document.originalHandlePositions[control1Key] {
                        restoredControl1 = originalPosition
                        elementNeedsUpdate = true
                    }
                }
                if control2Collapsed {
                    let control2Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control2"
                    if let originalPosition = document.originalHandlePositions[control2Key] {
                        restoredControl2 = originalPosition
                        elementNeedsUpdate = true
                    }
                }
                if elementNeedsUpdate {
                    elements[checkIndex] = .curve(to: to, control1: restoredControl1, control2: restoredControl2)
                    needsUpdate = true
                }
            }
        }
        if needsUpdate {
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        }
    }

    func collapseBothHandlesForAnchorPoint(layerIndex: Int, shapeIndex: Int, elementIndex: Int, anchorPoint: VectorPoint) {
        guard layerIndex < document.snapshot.layers.count,
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }
        let oldPath = shape.path

        var elements = shape.path.elements
        var needsUpdate = false
        for (checkIndex, checkElement) in elements.enumerated() {
            if case .curve(let to, let control1, let control2) = checkElement {
                if abs(to.x - anchorPoint.x) < 0.1 && abs(to.y - anchorPoint.y) < 0.1 {
                    let control2Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control2"
                    document.originalHandlePositions[control2Key] = control2
                    let collapsedControl2 = VectorPoint(anchorPoint.x, anchorPoint.y)
                    elements[checkIndex] = .curve(to: to, control1: control1, control2: collapsedControl2)
                    needsUpdate = true
                }
                if checkIndex > 0 {
                    let previousElement = elements[checkIndex - 1]
                    let previousAnchorPoint: VectorPoint
                    switch previousElement {
                    case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                        previousAnchorPoint = to
                    default:
                        previousAnchorPoint = VectorPoint(0, 0)
                    }
                    if abs(previousAnchorPoint.x - anchorPoint.x) < 0.1 && abs(previousAnchorPoint.y - anchorPoint.y) < 0.1 {
                        let control1Key = "\(layerIndex)_\(shapeIndex)_\(checkIndex)_control1"
                        document.originalHandlePositions[control1Key] = control1
                        let collapsedControl1 = VectorPoint(anchorPoint.x, anchorPoint.y)
                        elements[checkIndex] = .curve(to: to, control1: collapsedControl1, control2: control2)
                        needsUpdate = true
                    }
                }
            }
        }
        if needsUpdate {
            var updatedShape = shape
            updatedShape.path.elements = elements
            updatedShape.updateBounds()
            let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
        }
    }

    internal func tryToSelectShapeForConvertTool(at location: CGPoint) {
        for layerIndex in document.snapshot.layers.indices.reversed() {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible { continue }
            if layer.isLocked {
                continue
            }
            let shapes = document.getShapesForLayer(layerIndex)
            for shape in shapes.reversed() {
                if !shape.isVisible { continue }
                var isHit = false

                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    continue
                } else {
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    if isStrokeOnly && shape.strokeStyle != nil {
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    } else {
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        if expandedBounds.contains(location) {
                            isHit = true
                        } else {
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                        }
                    }
                }
                if isHit {
                    if layer.isLocked || shape.isLocked {
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        selectedObjectIDs.removeAll()
                        syncDirectSelectionWithDocument()
                        return
                    }
                    document.viewState.selectedObjectIDs.removeAll()
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    selectedObjectIDs.removeAll()
                    selectedObjectIDs.insert(shape.id)
                    syncDirectSelectionWithDocument()
                    return
                }
            }
        }
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        selectedObjectIDs.removeAll()
        syncDirectSelectionWithDocument()
    }

    func enableDirectSelectionForConvertedPoint(shapeID: UUID, elementIndex: Int) {
        document.viewState.selectedObjectIDs.removeAll()
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        selectedObjectIDs.removeAll()
        selectedObjectIDs.insert(shapeID)
        syncDirectSelectionWithDocument()
        let pointID = PointID(
            shapeID: shapeID,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        selectedPoints.insert(pointID)
    }
}
