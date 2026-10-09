import SwiftUI
import AppKit

/// Live state of one Gradient tool drag (Illustrator-style: drag across the selected object to set where the gradient starts and ends).
final class GradientToolSession {
    let shapeID: UUID
    let oldShape: VectorShape
    let baseGradient: VectorGradient
    let bounds: CGRect
    /// True when the drag began on the centre marker of an existing gradient, which only moves the gradient centre.
    let movesCenterOnly: Bool

    init(shapeID: UUID, oldShape: VectorShape, baseGradient: VectorGradient, bounds: CGRect, movesCenterOnly: Bool) {
        self.shapeID = shapeID
        self.oldShape = oldShape
        self.baseGradient = baseGradient
        self.bounds = bounds
        self.movesCenterOnly = movesCenterOnly
    }
}

extension DrawingCanvas {

    /// Gradient for the drag to start from: the shape's existing fill gradient, or a new two-stop one made from its solid fill.
    private func baseGradient(for shape: VectorShape) -> VectorGradient {
        if let fillStyle = shape.fillStyle, case .gradient(let existing) = fillStyle.color {
            return existing
        }
        var startColor = shape.fillStyle?.color ?? document.defaultFillColor
        if startColor == .clear { startColor = .white }
        let endColor: VectorColor = startColor == .white ? .black : .white
        let stops = [GradientStop(position: 0, color: startColor), GradientStop(position: 1, color: endColor)]
        return .linear(LinearGradient(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5), stops: stops))
    }

    internal func handleGradientToolDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let start = screenToCanvas(value.startLocation, geometry: geometry)
        let current = screenToCanvas(value.location, geometry: geometry)
        if gradientToolSession == nil {
            if document.viewState.selectedObjectIDs.isEmpty {
                selectObjectAt(start)
            }
            guard let id = document.viewState.selectedObjectIDs.first,
                  let shape = document.findShape(by: id),
                  shape.typography == nil, !shape.isLocked,
                  shape.name != "Canvas Background", shape.name != "Pasteboard Background" else { return }
            let bounds = shape.cachedCGPath.boundingBoxOfPath
            guard bounds.width > 0, bounds.height > 0 else { return }
            document.viewState.activeColorTarget = .fill
            var base = baseGradient(for: shape)
            var movesCenter = false
            if shape.fillStyle?.isGradient == true {
                if let editable = GradientFillSection.getEditableSelectedGradient(snapshot: document.snapshot, selectedObjectIDs: [id], activeColorTarget: .fill) {
                    base = editable
                }
                let origin = gradientOrigin(of: base)
                let center = CGPoint(x: bounds.minX + bounds.width * origin.x, y: bounds.minY + bounds.height * origin.y)
                let hitRadius = 10.0 / max(CGFloat(zoomLevel), 0.0001)
                movesCenter = hypot(start.x - center.x, start.y - center.y) <= hitRadius
            }
            gradientToolSession = GradientToolSession(shapeID: id, oldShape: shape, baseGradient: base, bounds: bounds, movesCenterOnly: movesCenter)
        }
        guard let session = gradientToolSession else { return }
        let minDistance = 3.0 / max(CGFloat(zoomLevel), 0.0001)
        guard hypot(current.x - start.x, current.y - start.y) >= minDistance else { return }
        activeGradientDelta = gradient(for: session, start: start, current: current)
    }

    internal func finishGradientToolDrag() {
        guard let session = gradientToolSession else { return }
        gradientToolSession = nil
        guard let finalGradient = activeGradientDelta else { return }
        activeGradientDelta = nil
        var newShape = session.oldShape
        newShape.fillStyle = FillStyle(gradient: finalGradient, opacity: session.oldShape.fillStyle?.opacity ?? 1.0)
        document.executeCommand(ShapeModificationCommand(objectIDs: [session.shapeID], oldShapes: [session.shapeID: session.oldShape], newShapes: [session.shapeID: newShape]))
    }

    private func gradientOrigin(of gradient: VectorGradient) -> CGPoint {
        switch gradient {
        case .linear(let linear): return linear.originPoint
        case .radial(let radial): return radial.originPoint
        }
    }

    private func gradient(for session: GradientToolSession, start: CGPoint, current: CGPoint) -> VectorGradient {
        let bounds = session.bounds
        let size = max(bounds.width, bounds.height)
        if session.movesCenterOnly {
            let relative = CGPoint(x: (current.x - bounds.minX) / bounds.width, y: (current.y - bounds.minY) / bounds.height)
            switch session.baseGradient {
            case .linear(var linear):
                linear.originPoint = relative
                return .linear(linear)
            case .radial(var radial):
                radial.originPoint = relative
                radial.focalPoint = relative
                return .radial(radial)
            }
        }
        var end = current
        if NSEvent.modifierFlags.contains(.shift) {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let step = CGFloat.pi / 4
            let angle = (atan2(dy, dx) / step).rounded() * step
            let length = hypot(dx, dy)
            end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        switch session.baseGradient {
        case .linear(var linear):
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let normalizedHalf = Double(length / size) / 2
            let angle = atan2(dy, dx)
            linear.units = .objectBoundingBox
            linear.originPoint = CGPoint(x: (mid.x - bounds.minX) / bounds.width, y: (mid.y - bounds.minY) / bounds.height)
            linear.scale = 1.0
            linear.scaleX = 1.0
            linear.scaleY = 1.0
            linear.storedAngle = Double(angle) * 180.0 / .pi
            linear.startPoint = CGPoint(x: linear.originPoint.x - cos(angle) * normalizedHalf, y: linear.originPoint.y - sin(angle) * normalizedHalf)
            linear.endPoint = CGPoint(x: linear.originPoint.x + cos(angle) * normalizedHalf, y: linear.originPoint.y + sin(angle) * normalizedHalf)
            return .linear(linear)
        case .radial(var radial):
            radial.units = .objectBoundingBox
            radial.originPoint = CGPoint(x: (start.x - bounds.minX) / bounds.width, y: (start.y - bounds.minY) / bounds.height)
            radial.centerPoint = radial.originPoint
            radial.focalPoint = nil
            radial.radius = Double(length / size)
            radial.scale = 1.0
            radial.scaleX = 1.0
            radial.scaleY = 1.0
            radial.angle = 0
            return .radial(radial)
        }
    }
}
