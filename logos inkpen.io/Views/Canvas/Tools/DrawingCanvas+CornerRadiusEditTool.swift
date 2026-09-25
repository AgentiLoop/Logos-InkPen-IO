import SwiftUI
import Combine
import simd

extension DrawingCanvas {

    @ViewBuilder
    func cornerRadiusEditTool(geometry: GeometryProxy) -> some View {
        if let selectedShape = getSelectedRectangleShape() {
            let boundsToUse = getProperShapeBounds(for: selectedShape)
            let corners = getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)
            ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                cornerRadiusHandle(
                    cornerIndex: index,
                    position: (isDraggingCorner && draggedCornerIndex == index)
                        ? currentMousePosition
                        : getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)[index],
                    radius: selectedShape.cornerRadii[safe: index] ?? 0.0,
                    shape: selectedShape,
                    geometry: geometry
                )
            }
        }
    }

    @ViewBuilder
    private func cornerRadiusHandle(
        cornerIndex: Int,
        position: CGPoint,
        radius: Double,
        shape: VectorShape,
        geometry: GeometryProxy
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.8))
                .stroke(Color.white, lineWidth: 2.0)
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .position(position)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    handleCornerRadiusDrag(
                        cornerIndex: cornerIndex,
                        value: value,
                        shape: shape,
                        geometry: geometry
                    )
                }
                .onEnded { _ in
                    finishCornerRadiusDrag()
                }
        )
    }

    internal func getSelectedRectangleShape() -> VectorShape? {
        guard document.viewState.selectedObjectIDs.count == 1 else { return nil }
        for newVectorObject in document.snapshot.objects.values {
            if case .shape(let shape) = newVectorObject.objectType {
                if document.viewState.selectedObjectIDs.contains(shape.id) && isRectangleBasedShape(shape) {
                    return shape
                }
            }
        }
        return nil
    }

    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }

    internal func getProperShapeBounds(for shape: VectorShape) -> CGRect {
        var pathBounds = shape.path.cgPath.boundingBox
        if !shape.transform.isIdentity {
            pathBounds = pathBounds.applying(shape.transform)
        }
        let isSquareByName = shape.name.lowercased() == "square"
        let isSquareBySizeRatio = abs(pathBounds.width - pathBounds.height) < 1.0
        if isSquareByName || (isSquareBySizeRatio && shape.name.lowercased() == "rectangle") {
            let size = max(pathBounds.width, pathBounds.height)
            let squareBounds = CGRect(
                x: pathBounds.origin.x,
                y: pathBounds.origin.y,
                width: size,
                height: size
            )
            return squareBounds
        }
        return pathBounds
    }

    internal func applyTransformToCornerRadii(shape: inout VectorShape) {
        guard !shape.transform.isIdentity else { return }
        let colX = SIMD2<Double>(Double(shape.transform.a), Double(shape.transform.c))
        let colY = SIMD2<Double>(Double(shape.transform.b), Double(shape.transform.d))
        let scaleX = simd_length(colX)
        let scaleY = simd_length(colY)
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0
        if scaleRatio > maxReasonableRatio {
            if let transformedPath = shape.path.cgPath.copy(using: &shape.transform) {
                shape.path = VectorPath(cgPath: transformedPath)
            }
            shape.transform = .identity
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
        if let transformedPath = shape.path.cgPath.copy(using: &shape.transform) {
            shape.path = VectorPath(cgPath: transformedPath)
        }
        shape.transform = .identity
        shape.originalBounds = getProperShapeBounds(for: shape)
    }

    func getCornerScreenPositions(bounds: CGRect, shape: VectorShape, geometry: GeometryProxy) -> [CGPoint] {
        let transformedBounds = bounds

        var curvePositions: [CGPoint] = []

        let cornerPositions = [
            CGPoint(x: transformedBounds.minX, y: transformedBounds.minY),
            CGPoint(x: transformedBounds.maxX, y: transformedBounds.minY),
            CGPoint(x: transformedBounds.maxX, y: transformedBounds.maxY),
            CGPoint(x: transformedBounds.minX, y: transformedBounds.maxY)
        ]
        for (index, corner) in cornerPositions.enumerated() {
            let radius = shape.cornerRadii[safe: index] ?? 0.0
            let curvePosition: CGPoint
            if radius <= 0.0 {
                curvePosition = corner
            } else {
                let curveDistance = radius / sqrt(2.0)
                let direction: CGPoint
                switch index {
                case 0:
                    direction = CGPoint(x: 1, y: 1)
                case 1:
                    direction = CGPoint(x: -1, y: 1)
                case 2:
                    direction = CGPoint(x: -1, y: -1)
                case 3:
                    direction = CGPoint(x: 1, y: -1)
                default:
                    direction = CGPoint(x: 0, y: 0)
                }
                curvePosition = CGPoint(
                    x: corner.x + direction.x * curveDistance,
                    y: corner.y + direction.y * curveDistance
                )
            }
            curvePositions.append(curvePosition)
        }
        return curvePositions.map { canvasToScreen($0, geometry: geometry) }
    }

    private func handleCornerRadiusDrag(
        cornerIndex: Int,
        value: DragGesture.Value,
        shape: VectorShape,
        geometry: GeometryProxy
    ) {
        if !isDraggingCorner {
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
            sharedOriginalShape = shape
        }
        currentMousePosition = value.location
        let canvasLocation = screenToCanvas(value.location, geometry: geometry)
        let canvasStartLocation = screenToCanvas(cornerDragStart, geometry: geometry)
        let direction: CGPoint
        switch cornerIndex {
        case 0:
            direction = CGPoint(x: 1, y: 1)
        case 1:
            direction = CGPoint(x: -1, y: 1)
        case 2:
            direction = CGPoint(x: -1, y: -1)
        case 3:
            direction = CGPoint(x: 1, y: -1)
        default:
            direction = CGPoint(x: 1, y: 1)
        }
        let canvasDelta = CGPoint(
            x: canvasLocation.x - canvasStartLocation.x,
            y: canvasLocation.y - canvasStartLocation.y
        )
        let sqrt2: CGFloat = 1.41421356237
        let projectedDistance = (canvasDelta.x * direction.x + canvasDelta.y * direction.y) / sqrt2
        let radiusChange = projectedDistance
        let tentativeRadius = initialCornerRadius + radiusChange
        if let originalBounds = shape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                let originalRadius = allRadii[cornerIndex]
                if originalRadius > 0 {
                    let ratio = newRadius / originalRadius
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        let proportionalRadius = originalCornerRadius * ratio
                        let constrainedRadius = max(0.0, min(maxRadius, proportionalRadius))
                        allRadii[i] = constrainedRadius
                    }
                } else {
                    for i in 0..<4 {
                        let constrainedRadius = max(0.0, min(maxRadius, newRadius))
                        allRadii[i] = constrainedRadius
                    }
                }
                updateAllCornerRadiiToValues(
                    shapeID: shape.id,
                    cornerRadii: allRadii
                )
            } else {
                updateCornerRadiusToValue(
                    shapeID: shape.id,
                    cornerIndex: cornerIndex,
                    newRadius: newRadius
                )
            }
        } else {
            let newRadius = max(0.0, tentativeRadius)
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                let originalRadius = allRadii[cornerIndex]
                if originalRadius > 0 {
                    let ratio = newRadius / originalRadius
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        allRadii[i] = max(0.0, originalCornerRadius * ratio)
                    }
                } else {
                    for i in 0..<4 {
                        allRadii[i] = max(0.0, newRadius)
                    }
                }
                updateAllCornerRadiiToValues(
                    shapeID: shape.id,
                    cornerRadii: allRadii
                )
            } else {
                updateCornerRadiusToValue(
                    shapeID: shape.id,
                    cornerIndex: cornerIndex,
                    newRadius: newRadius
                )
            }
        }
    }

    private func finishCornerRadiusDrag() {
        if isDraggingCorner {
            if let selectedShape = getSelectedRectangleShape() {
                let currentRadius = selectedShape.cornerRadii[safe: draggedCornerIndex ?? -1] ?? 0.0
                let roundedRadius = round(currentRadius)
                if abs(currentRadius - roundedRadius) > 0.01 {
                    let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
                    if isShiftCurrentlyPressed {
                        var allRadii = selectedShape.cornerRadii
                        while allRadii.count < 4 {
                            allRadii.append(0.0)
                        }
                        let originalRadius = allRadii[draggedCornerIndex ?? 0]
                        if originalRadius > 0 {
                            let ratio = roundedRadius / originalRadius
                            for i in 0..<4 {
                                let originalCornerRadius = allRadii[i]
                                allRadii[i] = round(originalCornerRadius * ratio)
                            }
                        } else {
                            for i in 0..<4 {
                                allRadii[i] = round(max(0.0, roundedRadius))
                            }
                        }
                        updateAllCornerRadiiToValues(
                            shapeID: selectedShape.id,
                            cornerRadii: allRadii
                        )
                    } else {
                        updateCornerRadiusToValue(
                            shapeID: selectedShape.id,
                            cornerIndex: draggedCornerIndex ?? 0,
                            newRadius: roundedRadius
                        )
                    }
                }
            }
            if let originalShape = sharedOriginalShape,

               let finalShape = getSelectedRectangleShape() {
                document.modifyShapesWithUndo(shapeIDs: [originalShape.id]) { shape in
                    shape = finalShape
                }
            }
            sharedOriginalShape = nil
            isDraggingCorner = false
            draggedCornerIndex = nil
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero
        }
    }

    private func updateShapeWithOptimizedSync(_ shape: VectorShape, layerIndex: Int, shapeIndex: Int, isLiveDrag: Bool) {
        guard var obj = document.snapshot.objects[shape.id] else { return }
        let objectType = VectorObject.determineType(for: shape)
        obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        document.snapshot.objects[shape.id] = obj
        document.triggerLayerUpdate(for: layerIndex)
    }

    private func updateCornerRadius(shapeID: UUID, cornerIndex: Int, radiusChange: Double) {
        for layerIndex in document.snapshot.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }) {
                guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                if !shape.isRoundedRectangle && isRectangleBasedShape(shape) {
                    shape.originalBounds = getProperShapeBounds(for: shape)
                    shape.isRoundedRectangle = true
                    if shape.cornerRadii.isEmpty {
                        shape.cornerRadii = [0.0, 0.0, 0.0, 0.0]
                    }
                }
                let currentRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
                let newRadius = max(0.0, currentRadius + radiusChange)

                var updatedRadii = shape.cornerRadii
                if cornerIndex < updatedRadii.count {
                    updatedRadii[cornerIndex] = newRadius
                } else {
                    while updatedRadii.count <= cornerIndex {
                        updatedRadii.append(0.0)
                    }
                    updatedRadii[cornerIndex] = newRadius
                }
                shape.cornerRadii = updatedRadii
                let currentBounds = shape.path.cgPath.boundingBox
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                shape.path = newPath
                shape.updateBounds()
                shape.originalBounds = currentBounds
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
                updateShapeWithOptimizedSync(shape, layerIndex: layerIndex, shapeIndex: shapeIndex, isLiveDrag: true)
                break
            }
        }
    }

    func updateCornerRadiusToValue(shapeID: UUID, cornerIndex: Int, newRadius: Double) {
        for layerIndex in document.snapshot.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }) {
                guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                var updatedRadii = shape.cornerRadii
                if cornerIndex < updatedRadii.count {
                    updatedRadii[cornerIndex] = newRadius
                } else {
                    while updatedRadii.count <= cornerIndex {
                        updatedRadii.append(0.0)
                    }
                    updatedRadii[cornerIndex] = newRadius
                }
                shape.cornerRadii = updatedRadii
                let currentBounds = shape.path.cgPath.boundingBox
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                shape.path = newPath
                shape.updateBounds()
                shape.originalBounds = currentBounds
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
                updateShapeWithOptimizedSync(shape, layerIndex: layerIndex, shapeIndex: shapeIndex, isLiveDrag: true)
                break
            }
        }
    }

    func updateAllCornerRadiiToValues(shapeID: UUID, cornerRadii: [Double]) {
        for layerIndex in document.snapshot.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }) {
                guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                var updatedRadii = cornerRadii
                while updatedRadii.count < 4 {
                    updatedRadii.append(0.0)
                }
                if updatedRadii.count > 4 {
                    updatedRadii = Array(updatedRadii.prefix(4))
                }
                shape.cornerRadii = updatedRadii
                let currentBounds = shape.path.cgPath.boundingBox
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                shape.path = newPath
                shape.updateBounds()
                shape.originalBounds = currentBounds
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
                updateShapeWithOptimizedSync(shape, layerIndex: layerIndex, shapeIndex: shapeIndex, isLiveDrag: true)
                break
            }
        }
    }
}

extension Array {

    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
