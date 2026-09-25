import SwiftUI
import Combine
import simd

extension DrawingCanvas {

    func handlePenPlusMinusTap(at location: CGPoint) {
        let tolerance: Double = 8.0 / zoomLevel
        if let pointToDelete = findAnchorPointAt(location: location, tolerance: tolerance) {
            deletePointWithCurvePreservation(pointID: pointToDelete)
            return
        }
        if let segmentHit = findSegmentAt(location: location, tolerance: tolerance) {
            insertPointOnSegment(
                shapeID: segmentHit.shapeID,
                elementIndex: segmentHit.elementIndex,
                at: location
            )
            return
        }
    }

    private func insertPointOnSegment(shapeID: UUID, elementIndex: Int, at location: CGPoint) {
        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType,
              elementIndex < shape.path.elements.count else { return }
        let element = shape.path.elements[elementIndex]
        let oldPath = shape.path

        var startPoint: VectorPoint
        if elementIndex > 0 {
            let prevElement = shape.path.elements[elementIndex - 1]
            switch prevElement {
            case .move(let point), .line(let point), .curve(let point, _, _), .quadCurve(let point, _):
                startPoint = point
            default:
                return
            }
        } else {
            return
        }
        var elements = shape.path.elements
        switch element {
        case .curve(let to, let control1, let control2):
            let t = findParametricValueOnCurve(
                start: CGPoint(x: startPoint.x, y: startPoint.y),
                control1: control1.cgPoint,
                control2: control2.cgPoint,
                end: to.cgPoint,
                targetPoint: location
            )
            let splitResult = splitCubicBezierAt(
                p0: CGPoint(x: startPoint.x, y: startPoint.y),
                p1: control1.cgPoint,
                p2: control2.cgPoint,
                p3: to.cgPoint,
                t: t
            )
            let firstCurve = PathElement.curve(
                to: VectorPoint(splitResult.splitPoint),
                control1: VectorPoint(splitResult.leftControl1),
                control2: VectorPoint(splitResult.leftControl2)
            )
            let secondCurve = PathElement.curve(
                to: to,
                control1: VectorPoint(splitResult.rightControl1),
                control2: VectorPoint(splitResult.rightControl2)
            )
            elements[elementIndex] = firstCurve
            elements.insert(secondCurve, at: elementIndex + 1)
        case .line(let to):
            let start = CGPoint(x: startPoint.x, y: startPoint.y)
            let end = to.cgPoint
            let t = closestPointOnLineSegment(point: location, start: start, end: end)
            let splitPoint = CGPoint(
                x: start.x + t * (end.x - start.x),
                y: start.y + t * (end.y - start.y)
            )
            let firstLine = PathElement.line(to: VectorPoint(splitPoint))
            let secondLine = PathElement.line(to: to)
            elements[elementIndex] = firstLine
            elements.insert(secondLine, at: elementIndex + 1)
        case .close:
            guard let firstElement = elements.first else { return }
            let endPoint: VectorPoint
            switch firstElement {
            case .move(let to):
                endPoint = to
            default:
                return
            }
            let start = CGPoint(x: startPoint.x, y: startPoint.y)
            let end = CGPoint(x: endPoint.x, y: endPoint.y)
            let t = closestPointOnLineSegment(point: location, start: start, end: end)
            let splitPoint = CGPoint(
                x: start.x + t * (end.x - start.x),
                y: start.y + t * (end.y - start.y)
            )
            let firstLine = PathElement.line(to: VectorPoint(splitPoint))
            let secondLine = PathElement.line(to: endPoint)
            let closeElement = PathElement.close
            elements[elementIndex] = firstLine
            elements.insert(secondLine, at: elementIndex + 1)
            elements.insert(closeElement, at: elementIndex + 2)
        default:
            return
        }
        var modifiedShape = shape
        modifiedShape.path.elements = elements
        modifiedShape.updateBounds()
        let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
        document.updateShapeByID(shapeID) { shape in
            shape.path = newPath
            shape.updateBounds()
        }
        let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
        document.commandManager.execute(command)
    }

    private func closestPointOnLineSegment(point: CGPoint, start: CGPoint, end: CGPoint) -> Double {
        let A = point.x - start.x
        let B = point.y - start.y
        let C = end.x - start.x
        let D = end.y - start.y
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        if lenSq == 0 {
            return 0.0
        }
        var param = dot / lenSq
        param = max(0.0, min(1.0, param))
        return param
    }

    private func deletePointWithCurvePreservation(pointID: PointID) {
        guard let object = document.snapshot.objects[pointID.shapeID],
              case .shape(let shape) = object.objectType else { return }
        let elements = shape.path.elements
        guard pointID.elementIndex < elements.count else { return }
        let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
        if !closedPathEndpoints.isEmpty {
            NSSound.beep()
            return
        }
        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        if !coincidentPoints.isEmpty {
            NSSound.beep()
            return
        }
        let oldPath = shape.path
        let pathPointCount = elements.filter { element in
            switch element {
            case .move, .line, .curve, .quadCurve: return true
            case .close: return false
            }
        }.count
        if pathPointCount <= 2 {
            document.removeShapeFromUnifiedSystem(id: shape.id)
        } else {
            let updatedElements = deletePointWithCurveMerging(
                elements: elements,
                pointIndex: pointID.elementIndex
            )
            let newPath = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
            document.updateShapeByID(pointID.shapeID) { shape in
                shape.path = newPath
                shape.updateBounds()
            }
            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
            return
        }
    }

    private func findAnchorPointAt(location: CGPoint, tolerance: Double) -> PointID? {
        for newVectorObject in document.snapshot.objects.values.reversed() {
            if case .shape(let shape) = newVectorObject.objectType {
                if !shape.isVisible || shape.isLocked { continue }
            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                    let rawPointLocation = to.cgPoint
                    let pointLocation = rawPointLocation.applying(shape.transform)
                    if distance(location, pointLocation) <= tolerance {
                        return PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                    }
                default:
                    break
                }
            }
            }
        }
        return nil
    }

    private func findSegmentAt(location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        for object in document.snapshot.objects.values.reversed() {
            if case .shape(let shape) = object.objectType {
                if !shape.isVisible || shape.isLocked { continue }
                var previousPoint: VectorPoint?
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .move(let to):
                        previousPoint = to
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
                        if let prev = previousPoint,
                           let firstPoint = shape.path.elements.first,
                           case .move(let firstTo) = firstPoint {
                            let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                            let end = CGPoint(x: firstTo.x, y: firstTo.y).applying(shape.transform)
                            if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                                return (shape.id, elementIndex)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func findParametricValueOnCurve(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, targetPoint: CGPoint) -> Double {
        var bestT: Double = 0.5
        var bestDistance: Double = Double.infinity
        for i in 0...100 {
            let t = Double(i) / 100.0
            let curvePoint = evaluateCubicBezier(p0: start, p1: control1, p2: control2, p3: end, t: t)
            let dist = distance(targetPoint, curvePoint)
            if dist < bestDistance {
                bestDistance = dist
                bestT = t
            }
        }
        return bestT
    }

    private func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let oneMinusT = 1.0 - t
        let oneMinusT2 = oneMinusT * oneMinusT
        let oneMinusT3 = oneMinusT2 * oneMinusT
        let t2 = t * t
        let t3 = t2 * t
        return CGPoint(
            x: oneMinusT3 * p0.x + 3 * oneMinusT2 * t * p1.x + 3 * oneMinusT * t2 * p2.x + t3 * p3.x,
            y: oneMinusT3 * p0.y + 3 * oneMinusT2 * t * p1.y + 3 * oneMinusT * t2 * p2.y + t3 * p3.y
        )
    }

    private func splitCubicBezierAt(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> (
        leftControl1: CGPoint, leftControl2: CGPoint,
        splitPoint: CGPoint,
        rightControl1: CGPoint, rightControl2: CGPoint
    ) {
        let p01 = lerp(p0, p1, t)
        let p12 = lerp(p1, p2, t)
        let p23 = lerp(p2, p3, t)
        let p012 = lerp(p01, p12, t)
        let p123 = lerp(p12, p23, t)
        let splitPoint = lerp(p012, p123, t)
        return (
            leftControl1: p01,
            leftControl2: p012,
            splitPoint: splitPoint,
            rightControl1: p123,
            rightControl2: p23
        )
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        return CGPoint(
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t
        )
    }

    private func isPointNearLineSegment(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: Double) -> Bool {
        let pointVec = SIMD2<Double>(Double(point.x), Double(point.y))
        let startVec = SIMD2<Double>(Double(start.x), Double(start.y))
        let endVec = SIMD2<Double>(Double(end.x), Double(end.y))
        let toPoint = pointVec - startVec
        let lineVec = endVec - startVec
        let dot = simd_dot(toPoint, lineVec)
        let lenSq = simd_length_squared(lineVec)
        if lenSq == 0 {
            return simd_length(toPoint) <= tolerance
        }
        let param = dot / lenSq
        let closestVec: SIMD2<Double>
        if param < 0 {
            closestVec = startVec
        } else if param > 1 {
            closestVec = endVec
        } else {
            closestVec = startVec + lineVec * param
        }
        let distance = simd_length(pointVec - closestVec)
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

    private func deletePointWithCurveMerging(elements: [PathElement], pointIndex: Int) -> [PathElement] {
        var newElements = elements
        newElements.remove(at: pointIndex)
        if pointIndex > 0 && pointIndex < elements.count {
        }
        return newElements
    }
}
