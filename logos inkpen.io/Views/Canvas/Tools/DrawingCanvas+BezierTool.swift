import SwiftUI

extension DrawingCanvas {

    internal func cancelBezierDrawing() {
        if let activeBezierShape = activeBezierShape {
            ensureIncompletePathHasProperColors(shape: activeBezierShape)
        }
        isBezierDrawing = false
        bezierPath = nil
        bezierPoints.removeAll()
        bezierHandles.removeAll()
        liveBezierHandles.removeAll()
        originalBezierHandles.removeAll()
        activeBezierPointIndex = nil
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        showClosePathHint = false
        showContinuePathHint = false
        activeBezierShape = nil
        currentShapeId = nil
    }

    internal func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        return p1.distance(to: p2)
    }

    private func findNearestSnapPoint(to point: CGPoint) -> CGPoint? {
        let snapTolerance: CGFloat = 10.0 / zoomLevel

        var nearestPoint: CGPoint?
        var nearestDistance = snapTolerance
        for newVectorObject in document.snapshot.objects.values {
            if case .shape(let shape) = newVectorObject.objectType {
                if let currentId = currentShapeId, shape.id == currentId {
                    continue
                }
                for element in shape.path.elements {
                    switch element {
                    case .move(to: let p), .line(to: let p):
                        let dist = distance(point, CGPoint(x: p.x, y: p.y))
                        if dist < nearestDistance {
                            nearestDistance = dist
                            nearestPoint = CGPoint(x: p.x, y: p.y)
                        }
                    case .curve(to: let p, control1: _, control2: _):
                        let dist = distance(point, CGPoint(x: p.x, y: p.y))
                        if dist < nearestDistance {
                            nearestDistance = dist
                            nearestPoint = CGPoint(x: p.x, y: p.y)
                        }
                    case .close:
                        break
                    case .quadCurve(to: let p, control: _):
                        let dist = distance(point, CGPoint(x: p.x, y: p.y))
                        if dist < nearestDistance {
                            nearestDistance = dist
                            nearestPoint = CGPoint(x: p.x, y: p.y)
                        }

                    @unknown default:
                        break
                    }
                }
            }
        }
        return nearestPoint
    }
}
