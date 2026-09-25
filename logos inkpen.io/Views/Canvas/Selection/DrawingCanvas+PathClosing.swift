import SwiftUI
import Combine

extension DrawingCanvas {

    internal func closeSelectedPaths() {
        let selectedShapeIDs = Set(selectedPoints.map { $0.shapeID })
        for shapeID in selectedShapeIDs {
            for layerIndex in document.snapshot.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }) {
                    guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                    let hasCloseElement = shape.path.elements.contains { element in
                        if case .close = element { return true }
                        return false
                    }
                    if !hasCloseElement && shape.path.elements.count > 2 {
                        var newElements = shape.path.elements
                        newElements.append(.close)
                        let newPath = VectorPath(elements: newElements, isClosed: true)
                        shape.path = newPath
                        shape.updateBounds()
                        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                    }
                }
            }
        }
    }
}
