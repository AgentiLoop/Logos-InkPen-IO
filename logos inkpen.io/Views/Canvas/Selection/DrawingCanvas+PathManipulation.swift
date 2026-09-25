import SwiftUI

extension DrawingCanvas {

    internal func updatePathWithHandles() {
        guard let path = bezierPath, bezierPoints.count >= 1 else { return }
        var newElements: [PathElement] = []
        newElements.append(.move(to: bezierPoints[0]))
        for i in 1..<bezierPoints.count {
            let currentPoint = bezierPoints[i]
            let previousPoint = bezierPoints[i - 1]
            let previousHandles = liveBezierHandles[i - 1] ?? bezierHandles[i - 1]
            let currentHandles = liveBezierHandles[i] ?? bezierHandles[i]
            let hasOutgoingHandle = previousHandles?.control2 != nil
            let hasIncomingHandle = currentHandles?.control1 != nil
            if hasOutgoingHandle || hasIncomingHandle {
                let control1 = previousHandles?.control2 ?? VectorPoint(previousPoint.x, previousPoint.y)
                let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                newElements.append(.curve(to: currentPoint, control1: control1, control2: control2))
            } else {
                newElements.append(.line(to: currentPoint))
            }
        }
        bezierPath = VectorPath(elements: newElements, isClosed: path.isClosed)
    }
}
