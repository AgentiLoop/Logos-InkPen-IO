import SwiftUI

extension DrawingCanvas {

    internal func handleBlobBrushDragUpdate(at location: CGPoint) {
        let minimumSpacing = 1.0 / zoomLevel
        if let last = blobBrushPoints.last, hypot(last.x - location.x, last.y - location.y) < minimumSpacing {
            return
        }
        blobBrushPoints.append(location)
        var elements: [PathElement] = [.move(to: VectorPoint(blobBrushPoints[0]))]
        if blobBrushPoints.count == 1 {
            elements.append(.line(to: VectorPoint(blobBrushPoints[0])))
        } else {
            for point in blobBrushPoints.dropFirst() { elements.append(.line(to: VectorPoint(point))) }
        }
        blobBrushPreviewPath = VectorPath(elements: elements)
    }

    /// The paint the Blob Brush uses. Illustrator paints a filled shape with the Stroke colour; when the (first) selected
    /// object is a plain filled shape with no stroke its fill is used so painting onto it extends it.
    internal func blobBrushPaint() -> (color: VectorColor, opacity: Double) {
        if let selectedID = document.viewState.orderedSelectedObjectIDs.first ?? document.viewState.selectedObjectIDs.first,
           let shape = document.findShape(by: selectedID),
           shape.strokeStyle == nil, let fill = shape.fillStyle {
            return (fill.color, fill.opacity)
        }
        return (getCurrentStrokeColor(), getCurrentStrokeOpacity())
    }

    /// Illustrator Blob Brush: the drag becomes a filled, stroke-less shape; it merges with every touching shape on the
    /// layer that has the same fill and no stroke, so repeated strokes build up one shape.
    internal func handleBlobBrushDragEnd() {
        let points = blobBrushPoints
        blobBrushPoints = []
        blobBrushPreviewPath = nil
        guard !points.isEmpty,
              let layerIndex = document.selectedLayerIndex,
              layerIndex >= 0, layerIndex < document.snapshot.layers.count,
              document.snapshot.layers[layerIndex].isVisible,
              !document.snapshot.layers[layerIndex].isLocked else { return }

        let size = max(1.0, ApplicationSettings.shared.blobBrushSize)
        let simplified = DrawingCanvasPathHelpers.douglasPeuckerSimplify(
            points: points, tolerance: max(0.25 / zoomLevel, size * 0.03))
        let centreLine = CGMutablePath()
        centreLine.move(to: simplified[0])
        if simplified.count == 1 {
            centreLine.addLine(to: simplified[0])
        } else {
            for point in simplified.dropFirst() { centreLine.addLine(to: point) }
        }
        let stroked = centreLine.copy(strokingWithWidth: size, lineCap: .round, lineJoin: .round, miterLimit: 10)
        guard let blob = CoreGraphicsPathOperations.normalized(stroked, using: .winding) else { return }
        let blobBounds = blob.boundingBoxOfPath.insetBy(dx: -0.01, dy: -0.01)

        let paint = blobBrushPaint()
        var mergeShapes: [VectorShape] = []
        var mergePaths: [CGPath] = []
        for objectID in document.snapshot.layers[layerIndex].objectIDs {
            guard let object = document.snapshot.objects[objectID],
                  case .shape(let shape) = object.objectType,
                  shape.isVisible, !shape.isLocked,
                  shape.strokeStyle == nil,
                  let fill = shape.fillStyle, fill.color == paint.color, abs(fill.opacity - paint.opacity) < 0.001,
                  !shape.isGroup, !shape.isGroupContainer, !shape.isCompoundPath,
                  !shape.isClippingPath, !shape.isWarpObject, shape.textContent == nil else { continue }
            var cgPath = shape.path.cgPath
            if !shape.transform.isIdentity {
                var transform = shape.transform
                guard let moved = cgPath.copy(using: &transform) else { continue }
                cgPath = moved
            }
            guard cgPath.boundingBoxOfPath.intersects(blobBounds),
                  !cgPath.intersection(blob, using: .winding).isEmpty else { continue }
            mergeShapes.append(shape)
            mergePaths.append(cgPath)
        }

        let resultPath = CoreGraphicsPathOperations.unionMultiplePaths([blob] + mergePaths) ?? blob
        var result: VectorShape
        if var base = mergeShapes.last {
            base.id = UUID()
            result = base
            result.path = VectorPath(cgPath: resultPath, fillRule: .winding)
            result.transform = .identity
        } else {
            result = VectorShape(
                name: "Blob Brush",
                path: VectorPath(cgPath: resultPath, fillRule: .winding),
                strokeStyle: nil,
                fillStyle: FillStyle(color: paint.color, opacity: paint.opacity)
            )
        }
        result.updateBounds()

        var removed: [UUID: VectorShape] = [:]
        for shape in mergeShapes { removed[shape.id] = shape }
        let command = GroupCommand(
            operation: .pathOperation,
            layerIndex: layerIndex,
            removedObjectIDs: mergeShapes.map { $0.id },
            removedShapes: removed,
            addedObjectIDs: [result.id],
            addedShapes: [result.id: result],
            oldSelectedObjectIDs: document.viewState.selectedObjectIDs,
            newSelectedObjectIDs: [result.id]
        )
        document.commandManager.execute(command)
        document.viewState.orderedSelectedObjectIDs = [result.id]
    }
}
