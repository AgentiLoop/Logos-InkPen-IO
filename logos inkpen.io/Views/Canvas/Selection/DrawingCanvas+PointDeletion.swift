import SwiftUI
import Combine

extension DrawingCanvas {

    internal func deleteSelectedPoints() {
        let pointsByShape = Dictionary(grouping: selectedPoints) { $0.shapeID }
        for (shapeID, points) in pointsByShape {
            for layerIndex in document.snapshot.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),

                   let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    let pathPointCount = shape.path.elements.filter { element in
                        switch element {
                        case .move, .line, .curve, .quadCurve: return true
                        case .close: return false
                        }
                    }.count
                    if points.count >= pathPointCount || pathPointCount <= 2 {
                        document.removeShapeFromUnifiedSystem(id: shape.id)
                    } else {
                        let updatedPath = deletePointsFromPath(shape.path, selectedPoints: points)
                        document.updateShapePathUnified(id: shape.id, path: updatedPath)
                    }
                    break
                }
            }
        }
        selectedPoints.removeAll()
        selectedHandles.removeAll()
    }

    internal func closeBezierPath() {
        guard bezierPath != nil,
                let activeShape = activeBezierShape,
              bezierPoints.count >= 3 else {
            cancelBezierDrawing()
            return
        }
        updatePathWithHandles()
        guard let updatedPath = bezierPath else {
            cancelBezierDrawing()
            return
        }
        let firstPoint = bezierPoints[0]
        let lastIndex = bezierPoints.count - 1
        let lastPointHandles = bezierHandles[lastIndex]
        let firstPointHandles = bezierHandles[0]

        var finalElements = updatedPath.elements
        if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstControl1))
        } else if let lastControl2 = lastPointHandles?.control2 {
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstPoint))
        } else if let firstControl1 = firstPointHandles?.control1 {
            finalElements.append(.curve(to: firstPoint, control1: VectorPoint(bezierPoints[lastIndex].x, bezierPoints[lastIndex].y), control2: firstControl1))
        } else {
            finalElements.append(.line(to: firstPoint))
        }
        finalElements.append(.close)
        let closedPath = VectorPath(elements: finalElements, isClosed: true)

        var targetLayerIndex = document.selectedLayerIndex
        if targetLayerIndex == nil {
            for (index, layer) in document.snapshot.layers.enumerated() {
                if layer.name != "Pasteboard" && layer.name != "Canvas" && layer.name != "Guides" {
                    targetLayerIndex = index
                    break
                }
            }
        }
        if let layerIndex = targetLayerIndex {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == activeShape.id }) {
                guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
                shape.path = closedPath
                shape.fillStyle = FillStyle(
                    color: document.defaultFillColor,
                    opacity: document.defaultFillOpacity
                )
                shape.updateBounds()
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
            }
        }
        cancelBezierDrawing()
        currentShapeId = nil
        showClosePathHint = false
        showContinuePathHint = false
    }
}
