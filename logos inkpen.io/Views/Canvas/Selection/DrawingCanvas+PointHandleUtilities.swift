import SwiftUI
import Combine

extension DrawingCanvas {

    internal func captureOriginalPositions() {
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
        for pointID in selectedPoints {
            if let point = getPointPosition(pointID) {
                originalPointPositions[pointID] = point
            }
        }
        for handleID in selectedHandles {
            if let handle = getHandlePosition(handleID) {
                originalHandlePositions[handleID] = handle
            }
        }
    }

    internal func getPointPosition(_ pointID: PointID) -> VectorPoint? {
        if let object = document.snapshot.objects[pointID.shapeID],
           case .shape(let shape) = object.objectType {
            guard pointID.elementIndex < shape.path.elements.count else { return nil }
            let element = shape.path.elements[pointID.elementIndex]
            switch element {
            case .move(let to), .line(let to):
                return to
            case .curve(let to, _, _), .quadCurve(let to, _):
                return to
            case .close:
                return nil
            }
        }
        return nil
    }

    internal func getHandlePosition(_ handleID: HandleID) -> VectorPoint? {
        if let object = document.snapshot.objects[handleID.shapeID],
           case .shape(let shape) = object.objectType {
            guard handleID.elementIndex < shape.path.elements.count else { return nil }
            let element = shape.path.elements[handleID.elementIndex]
            switch element {
            case .curve(_, let control1, let control2):
                return handleID.handleType == .control1 ? control1 : control2
            case .quadCurve(_, let control):
                return handleID.handleType == .control1 ? control : nil
            default:
                return nil
            }
        }
        return nil
    }

    internal func movePointToAbsolutePosition(_ pointID: PointID, to newPosition: CGPoint) {
        movePointToAbsolutePositionOptimized(pointID, to: newPosition, isLiveDrag: isDraggingPoint, shouldUpdate: true)
    }

    internal func movePointToAbsolutePositionBatched(_ pointID: PointID, to newPosition: CGPoint) {
        movePointToAbsolutePositionOptimized(pointID, to: newPosition, isLiveDrag: true, shouldUpdate: false)
    }

    private func movePointToAbsolutePositionOptimized(_ pointID: PointID, to newPosition: CGPoint, isLiveDrag: Bool, shouldUpdate: Bool = true) {
        guard let object = document.snapshot.objects[pointID.shapeID],
              case .shape(let shape) = object.objectType else { return }
                guard pointID.elementIndex < shape.path.elements.count else { return }
                let newPoint = VectorPoint(newPosition.x, newPosition.y)

                var elements = shape.path.elements

                let originalPosition: CGPoint
                switch elements[pointID.elementIndex] {
                case .move(let to), .line(let to):
                    originalPosition = to.cgPoint
                case .curve(let to, _, _):
                    originalPosition = to.cgPoint
                case .quadCurve(let to, _):
                    originalPosition = to.cgPoint
                case .close:
                    return
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
                document.updateShapeByID(pointID.shapeID, silent: true) { shape in
                    shape.path.elements = elements
                    shape.updateBounds()
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

    private func moveHandlesWithAnchorPoint(elements: inout [PathElement], elementIndex: Int, delta: CGPoint) {
        guard elementIndex < elements.count else { return }
        switch elements[elementIndex] {
        case .curve(let to, let control1, let control2):
            let newControl2 = VectorPoint(control2.x + delta.x, control2.y + delta.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: newControl2)
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
        case .move(_), .line(_):
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
        default:
            break
        }
    }

    internal func moveHandleToAbsolutePosition(_ handleID: HandleID, to newPosition: CGPoint) {
        moveHandleToAbsolutePositionOptimized(handleID, to: newPosition, isLiveDrag: isDraggingHandle, shouldUpdate: true)
    }

    internal func moveHandleToAbsolutePositionBatched(_ handleID: HandleID, to newPosition: CGPoint) {
        moveHandleToAbsolutePositionOptimized(handleID, to: newPosition, isLiveDrag: true, shouldUpdate: false)
    }

    private func moveHandleToAbsolutePositionOptimized(_ handleID: HandleID, to newPosition: CGPoint, isLiveDrag: Bool, shouldUpdate: Bool = true) {
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
        if !optionPressed() {
            updateLinkedHandle(
                elements: &elements,
                draggedHandleID: handleID,
                newDraggedPosition: newPosition
            )
        }
        document.updateShapeByID(handleID.shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
    }
}
