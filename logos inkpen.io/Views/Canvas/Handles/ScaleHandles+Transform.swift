import SwiftUI
import simd

extension ScaleHandles {

    func getAnchorPoint(for anchor: ScalingAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform
        if currentTransform.isIdentity {
            return
        }
        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
            document.applyTransformToGroup(groupID: shape.id, transform: currentTransform)
            return
        }
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            var mutableShape = shape
            var transformedGroupedShapes: [VectorShape] = []
            for var groupedShape in mutableShape.groupedShapes {
                var transformedElements: [PathElement] = []
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        let transformedPoint = to.cgPoint.applying(currentTransform)
                        transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                    case .line(let to):
                        let transformedPoint = to.cgPoint.applying(currentTransform)
                        transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                    case .curve(let to, let control1, let control2):
                        let transformedTo = to.cgPoint.applying(currentTransform)
                        let transformedControl1 = control1.cgPoint.applying(currentTransform)
                        let transformedControl2 = control2.cgPoint.applying(currentTransform)
                        transformedElements.append(.curve(
                            to: VectorPoint(transformedTo),
                            control1: VectorPoint(transformedControl1),
                            control2: VectorPoint(transformedControl2)
                        ))
                    case .quadCurve(let to, let control):
                        let transformedTo = to.cgPoint.applying(currentTransform)
                        let transformedControl = control.cgPoint.applying(currentTransform)
                        transformedElements.append(.quadCurve(
                            to: VectorPoint(transformedTo),
                            control: VectorPoint(transformedControl)
                        ))
                    case .close:
                        transformedElements.append(.close)
                    }
                }
                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.transform = .identity
                groupedShape.updateBounds()
                transformedGroupedShapes.append(groupedShape)
            }
            mutableShape.groupedShapes = transformedGroupedShapes
            mutableShape.transform = .identity
            mutableShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: mutableShape)
            return
        }
        var transformedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = to.cgPoint.applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
            case .line(let to):
                let transformedPoint = to.cgPoint.applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
            case .curve(let to, let control1, let control2):
                let transformedTo = to.cgPoint.applying(currentTransform)
                let transformedControl1 = control1.cgPoint.applying(currentTransform)
                let transformedControl2 = control2.cgPoint.applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
            case .quadCurve(let to, let control):
                let transformedTo = to.cgPoint.applying(currentTransform)
                let transformedControl = control.cgPoint.applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
            case .close:
                transformedElements.append(.close)
            }
        }
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        guard let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        if !currentShape.cornerRadii.isEmpty && currentShape.isRoundedRectangle {
            var updatedShape = currentShape
            updatedShape.path = transformedPath
            updatedShape.transform = .identity
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)
            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        } else {
            document.updateShapeTransformAndPathInUnified(id: currentShape.id, path: transformedPath, transform: .identity)
        }
    }

    func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }

    func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.viewState.scalingAnchor {
        case .center:
            return false
        case .topLeft:
            return cornerIndex == 0
        case .topRight:
            return cornerIndex == 1
        case .bottomRight:
            return cornerIndex == 2
        case .bottomLeft:
            return cornerIndex == 3
        }
    }

    func getAnchorForCorner(index: Int) -> ScalingAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }

    func setupKeyEventMonitoring() {
    }

    func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        let scaleX = simd_length(SIMD2(Double(transform.a), Double(transform.c)))
        let scaleY = simd_length(SIMD2(Double(transform.b), Double(transform.d)))
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0
        if scaleRatio > maxReasonableRatio {
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            return
        }
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius)
            }
        }
    }
}
