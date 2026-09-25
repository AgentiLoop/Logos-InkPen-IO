import SwiftUI
import Combine

struct GradientCenterPointCanvasView: View {
    let document: VectorDocument
    let geometry: GeometryProxy
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let activeGradientDelta: VectorGradient?
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    var body: some View {
        Canvas { context, size in
            guard let selectedGradient = getSelectedShapeGradient(document: document),
                  let selectedShape = getSelectedShapeWithGradient(document: document) else { return }
            let zoom = zoomLevel
            let offset = canvasOffset
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: offset.x, y: offset.y)
                .scaledBy(x: zoom, y: zoom)
            context.transform = baseTransform
            let gradientToDisplay = activeGradientDelta ?? selectedGradient
            let originX = getGradientOriginX(gradientToDisplay)
            let originY = getGradientOriginY(gradientToDisplay)
            let shapeBounds = selectedShape.bounds
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            let centerPoint = CGPoint(x: centerX, y: centerY)
            let outerSize: CGFloat = 16.0 / zoom
            let innerSize: CGFloat = 6.0 / zoom
            let strokeWidth: CGFloat = 2.0 / zoom
            let outerRect = CGRect(
                x: centerPoint.x - outerSize/2,
                y: centerPoint.y - outerSize/2,
                width: outerSize,
                height: outerSize
            )
            let outerCircle = Path(ellipseIn: outerRect)
            context.fill(outerCircle, with: .color(.blue.opacity(0.8)))
            context.stroke(outerCircle, with: .color(.white), lineWidth: strokeWidth)
            switch selectedGradient {
            case .radial:
                let innerRect = CGRect(
                    x: centerPoint.x - innerSize/2,
                    y: centerPoint.y - innerSize/2,
                    width: innerSize,
                    height: innerSize
                )
                let innerCircle = Path(ellipseIn: innerRect)
                context.fill(innerCircle, with: .color(.white))
            case .linear:
                let lineWidth: CGFloat = 8.0 / zoom
                let lineHeight: CGFloat = 2.0 / zoom
                let lineRect = CGRect(
                    x: centerPoint.x - lineWidth/2,
                    y: centerPoint.y - lineHeight/2,
                    width: lineWidth,
                    height: lineHeight
                )
                var linePath = Path(lineRect)

                let rotation = CGAffineTransform(rotationAngle: .pi / 4)
                let translated = CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
                linePath = linePath.applying(CGAffineTransform(translationX: -centerPoint.x, y: -centerPoint.y))
                linePath = linePath.applying(rotation)
                linePath = linePath.applying(translated)
                context.fill(linePath, with: .color(.white))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(onDragChanged)
                .onEnded(onDragEnded)
        )
    }

    private func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        guard let firstSelectedID = document.viewState.selectedObjectIDs.first else { return nil }
        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }

    private func getSelectedShapeWithGradient(document: VectorDocument) -> VectorShape? {
        guard let firstSelectedID = document.viewState.selectedObjectIDs.first else { return nil }
        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle,
              case .gradient = fillStyle.color else {
            return nil
        }
        return shape
    }

    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            return radial.originPoint.x
        }
    }

    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            return radial.originPoint.y
        }
    }
}

extension DrawingCanvas {

    @ViewBuilder
    func gradientEditTool(geometry: GeometryProxy) -> some View {
        if getSelectedShapeGradient(document: document) != nil,
           getSelectedShapeWithGradient() != nil {
            GradientCenterPointCanvasView(
                document: document,
                geometry: geometry,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                activeGradientDelta: activeGradientDelta,
                onDragChanged: { value in
                    if let selectedShape = getSelectedShapeWithGradient(),

                       let selectedGradient = getSelectedShapeGradient(document: document) {
                        handleGradientCenterDrag(value: value, geometry: geometry, shape: selectedShape, gradient: selectedGradient)
                    }
                },
                onDragEnded: { value in
                    if let selectedShape = getSelectedShapeWithGradient() {
                        handleGradientCenterDragEnd(value: value, geometry: geometry, shape: selectedShape)
                    }
                }
            )
        }
    }

    private func getSelectedShapeWithGradient() -> VectorShape? {
        guard let firstSelectedID = document.viewState.selectedObjectIDs.first else { return nil }
        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle,
              case .gradient = fillStyle.color else {
            return nil
        }
        return shape
    }

    private func getGradientCenterPoint(gradient: VectorGradient, shape: VectorShape) -> CGPoint {
        let shapeBounds = shape.bounds
        switch gradient {
        case .linear(let linear):
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            return CGPoint(x: centerX, y: centerY)
        case .radial(let radial):
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            return CGPoint(x: centerX, y: centerY)
        }
    }

    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX
        case .radial(let radial):
            return radial.scaleX
        }
    }

    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            return radial.originPoint.x
        }
    }

    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            return radial.originPoint.y
        }
    }

    private func handleGradientCenterDrag(value: DragGesture.Value, geometry: GeometryProxy, shape: VectorShape, gradient: VectorGradient) {
        if dragStartGradient == nil {
            dragStartGradient = gradient
        }
        let canvasPoint = screenToCanvas(value.location, geometry: geometry)
        let shapeBounds = shape.bounds
        let relativeX = (canvasPoint.x - shapeBounds.minX) / shapeBounds.width
        let relativeY = (canvasPoint.y - shapeBounds.minY) / shapeBounds.height
        let newGradient: VectorGradient
        switch gradient {
        case .linear(var linear):
            linear.originPoint.x = relativeX
            linear.originPoint.y = relativeY
            newGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.x = relativeX
            radial.originPoint.y = relativeY
            radial.focalPoint = CGPoint(x: relativeX, y: relativeY)
            newGradient = .radial(radial)
        }
        activeGradientDelta = newGradient
    }

    private func handleGradientCenterDragEnd(value: DragGesture.Value, geometry: GeometryProxy, shape: VectorShape) {
        guard let finalGradient = activeGradientDelta,
              let startGradient = dragStartGradient,

              let fillStyle = document.findShape(by: shape.id)?.fillStyle else {
            activeGradientDelta = nil
            dragStartGradient = nil
            return
        }
        let command = GradientCommand(
            objectIDs: [shape.id],
            target: .fill,
            oldGradients: [shape.id: startGradient],
            newGradients: [shape.id: finalGradient],
            oldOpacities: [shape.id: fillStyle.opacity],
            newOpacities: [shape.id: fillStyle.opacity]
        )
        document.commandManager.execute(command)
        activeGradientDelta = nil
        dragStartGradient = nil
    }

    private func updateGradientOriginX(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true) {
        updateGradientOriginXOptimized(newX, shape: shape, applyToShapes: applyToShapes, isLiveDrag: false)
    }

    private func updateGradientOriginY(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true) {
        updateGradientOriginYOptimized(newY, shape: shape, applyToShapes: applyToShapes, isLiveDrag: false)
    }

    private func updateGradientOriginXOptimized(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.x = newX
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }

    private func updateGradientOriginYOptimized(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.y = newY
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }

    private func updateGradientOriginXYOptimized(_ newX: Double, _ newY: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        let newGradient: VectorGradient
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            linear.originPoint.y = newY
            newGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.x = newX
            radial.originPoint.y = newY
            radial.focalPoint = CGPoint(x: newX, y: newY)
            newGradient = .radial(radial)
        }
        activeGradientDelta = newGradient
    }

    private func updateShapeGradient(shape: VectorShape, newGradient: VectorGradient) {
        updateShapeGradientOptimized(shape: shape, newGradient: newGradient, isLiveDrag: false)
    }

    private func updateShapeGradientOptimized(shape: VectorShape, newGradient: VectorGradient, isLiveDrag: Bool) {
        document.updateShapeGradientInUnified(id: shape.id, gradient: newGradient, target: document.viewState.activeColorTarget)
    }

    private func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        guard let firstSelectedID = document.viewState.selectedObjectIDs.first else { return nil }
        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }
}
