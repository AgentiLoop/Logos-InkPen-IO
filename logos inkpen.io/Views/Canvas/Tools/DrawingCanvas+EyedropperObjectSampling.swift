import SwiftUI

extension DrawingCanvas {

    /// Illustrator-style Eyedropper: clicking an object copies its fill/stroke appearance onto the
    /// selected objects (or onto the document's default fill/stroke when nothing is selected).
    /// Returns false when no object is under the click so the caller can fall back to the screen colour sampler.
    internal func applyEyedropperObjectAppearance(at location: CGPoint) -> Bool {
        guard let source = topmostSampleableShape(at: location) else { return false }
        let fill = source.fillStyle
        let stroke = source.strokeStyle
        let selectedIDs = document.viewState.selectedObjectIDs
        if selectedIDs.isEmpty {
            if let fill, fill.color != .clear {
                document.defaultFillColor = fill.color
                document.defaultFillOpacity = fill.opacity
            }
            if let stroke {
                document.defaultStrokeColor = stroke.color
                document.defaultStrokeOpacity = stroke.opacity
                document.defaultStrokeWidth = stroke.width
            }
            return true
        }
        _ = document.modifySelectedShapesWithUndo { shape in
            shape.fillStyle = fill
            shape.strokeStyle = stroke
        }
        document.viewState.objectPositionUpdateTrigger.toggle()
        return true
    }

    private func topmostSampleableShape(at location: CGPoint) -> VectorShape? {
        for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible || layer.isLocked { continue }
            for objectID in layer.objectIDs.reversed() {
                guard let object = document.snapshot.objects[objectID] else { continue }
                guard case .shape(let shape) = object.objectType else { continue }
                if !shape.isVisible { continue }
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" { continue }
                if performShapeHitTest(shape: shape, at: location) {
                    return shape
                }
            }
        }
        return nil
    }
}
