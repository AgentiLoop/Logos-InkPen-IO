import SwiftUI

extension DrawingCanvas {

    /// Illustrator-style Eyedropper: clicking an object copies its fill/stroke appearance onto the
    /// selected objects (or onto the document's default fill/stroke when nothing is selected).
    /// Returns false when no object is under the click so the caller can fall back to the screen colour sampler.
    internal func applyEyedropperObjectAppearance(at location: CGPoint) -> Bool {
        guard let source = topmostSampleableShape(at: location) else { return false }
        let appearance = EyedropperAppearance(source: source)
        let fill = appearance.fill
        let stroke = appearance.stroke
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
            appearance.apply(to: &shape)
        }
        document.viewState.objectPositionUpdateTrigger.toggle()
        return true
    }

    /// Illustrator: Option-click with the Eyedropper applies the appearance of the selected object
    /// to the object under the cursor (the selection stays unchanged). Returns false if not applicable.
    internal func applySelectedAppearanceToObject(at location: CGPoint) -> Bool {
        guard let sourceID = document.viewState.selectedObjectIDs.first,
              let source = document.findShape(by: sourceID),
              let target = topmostSampleableShape(at: location),
              !document.viewState.selectedObjectIDs.contains(target.id) else { return false }
        var newTarget = target
        EyedropperAppearance(source: source).apply(to: &newTarget)
        document.executeCommand(ShapeModificationCommand(objectIDs: [target.id], oldShapes: [target.id: target], newShapes: [target.id: newTarget]))
        document.viewState.objectPositionUpdateTrigger.toggle()
        return true
    }

    private func topmostSampleableShape(at location: CGPoint) -> VectorShape? {
        for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
            let layer = document.snapshot.layers[layerIndex]
            if !layer.isVisible || layer.isLocked { continue }
            for objectID in layer.objectIDs.reversed() {
                guard let object = document.snapshot.objects[objectID] else { continue }
                if case .text(let textShape) = object.objectType {
                    if !textShape.isVisible || textShape.isLocked { continue }
                    let textBounds = CGRect(x: textShape.transform.tx, y: textShape.transform.ty,
                                            width: textShape.bounds.width, height: textShape.bounds.height)
                    if textBounds.contains(location) { return textShape }
                    continue
                }
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

/// Appearance picked up by the Eyedropper. Text objects keep their colours in `typography`;
/// text → text copies the whole typography (Illustrator copies character attributes too),
/// text ↔ path converts between fill/stroke and the text colours.
struct EyedropperAppearance {
    var fill: FillStyle?
    var stroke: StrokeStyle?
    var typography: TypographyProperties?

    init(source: VectorShape) {
        if let t = source.typography {
            typography = t
            fill = FillStyle(color: t.fillColor, opacity: t.fillOpacity)
            stroke = t.hasStroke ? StrokeStyle(color: t.strokeColor, width: t.strokeWidth, opacity: t.strokeOpacity) : nil
        } else {
            fill = source.fillStyle
            stroke = source.strokeStyle
        }
    }

    func apply(to shape: inout VectorShape) {
        guard shape.typography != nil else {
            shape.fillStyle = fill
            shape.strokeStyle = stroke
            return
        }
        if let typography {
            shape.typography = typography
            return
        }
        if let fill, fill.color != .clear {
            shape.typography?.fillColor = fill.color
            shape.typography?.fillOpacity = fill.opacity
        }
        if let stroke {
            shape.typography?.hasStroke = true
            shape.typography?.strokeColor = stroke.color
            shape.typography?.strokeWidth = stroke.width
            shape.typography?.strokeOpacity = stroke.opacity
        } else {
            shape.typography?.hasStroke = false
        }
    }
}
