import SwiftUI

/// Undo step for one Eraser stroke that may have trimmed, split or removed several shapes.
final class EraserCommand: BaseCommand {
    private let steps: [BaseCommand]

    init(steps: [BaseCommand]) {
        self.steps = steps
    }

    override func execute(on document: VectorDocument) {
        steps.forEach { $0.execute(on: document) }
    }

    override func undo(on document: VectorDocument) {
        steps.reversed().forEach { $0.undo(on: document) }
    }
}

extension DrawingCanvas {

    internal func handleEraserDragUpdate(at location: CGPoint) {
        let minimumSpacing = 1.0 / zoomLevel
        if let last = eraserPoints.last, hypot(last.x - location.x, last.y - location.y) < minimumSpacing {
            return
        }
        eraserPoints.append(location)
        var elements: [PathElement] = [.move(to: VectorPoint(eraserPoints[0]))]
        if eraserPoints.count == 1 {
            elements.append(.line(to: VectorPoint(eraserPoints[0])))
        } else {
            for point in eraserPoints.dropFirst() { elements.append(.line(to: VectorPoint(point))) }
        }
        eraserPreviewPath = VectorPath(elements: elements)
    }

    /// Illustrator Eraser: drag over filled shapes to rub out the parts under the brush.
    /// With a selection only the selected shapes are erased; with nothing selected every shape the stroke touches is.
    /// Pieces cut apart by the eraser become separate shapes; a shape that is erased completely is deleted.
    internal func handleEraserDragEnd() {
        let points = eraserPoints
        eraserPoints = []
        eraserPreviewPath = nil
        guard !points.isEmpty else { return }

        let size = max(1.0, ApplicationSettings.shared.eraserSize)
        let strokeLine = CGMutablePath()
        strokeLine.move(to: points[0])
        if points.count == 1 {
            strokeLine.addLine(to: points[0])
        } else {
            for point in points.dropFirst() { strokeLine.addLine(to: point) }
        }
        let eraserRegion = strokeLine.copy(strokingWithWidth: size, lineCap: .round, lineJoin: .round, miterLimit: 10)
        let eraserBounds = eraserRegion.boundingBoxOfPath

        let selected = document.viewState.selectedObjectIDs
        var steps: [BaseCommand] = []
        var resultIDs: [UUID] = []
        var deletedIDs: [UUID] = []
        for object in document.snapshot.objects.values {
            guard case .shape(let shape) = object.objectType,
                  selected.isEmpty || selected.contains(shape.id),
                  shape.isVisible, !shape.isLocked,
                  shape.fillStyle != nil,
                  !shape.isGroup, !shape.isGroupContainer, !shape.isCompoundPath,
                  !shape.isClippingPath, !shape.isWarpObject, shape.textContent == nil,
                  shape.name != "Canvas Background", shape.name != "Pasteboard Background",
                  object.layerIndex >= 0, object.layerIndex < document.snapshot.layers.count,
                  document.snapshot.layers[object.layerIndex].isVisible,
                  !document.snapshot.layers[object.layerIndex].isLocked else { continue }
            var localRegion = eraserRegion
            var localBounds = eraserBounds
            if !shape.transform.isIdentity {
                guard abs(shape.transform.a * shape.transform.d - shape.transform.b * shape.transform.c) > 1e-9 else { continue }
                var inverse = shape.transform.inverted()
                guard let transformed = eraserRegion.copy(using: &inverse) else { continue }
                localRegion = transformed
                localBounds = transformed.boundingBoxOfPath
            }
            let cgPath = shape.path.cgPath
            guard cgPath.boundingBoxOfPath.intersects(localBounds) else { continue }
            let rule = shape.path.fillRule.cgPathFillRule
            guard !cgPath.intersection(localRegion, using: rule).isEmpty else { continue }
            let remaining = cgPath.subtracting(localRegion, using: rule)
            let pieces = remaining.isEmpty ? [] : remaining.componentsSeparated(using: rule)
            if pieces.isEmpty {
                steps.append(DeleteObjectCommand(objectIDs: [shape.id], document: document))
                deletedIDs.append(shape.id)
                continue
            }
            var firstPath = VectorPath(cgPath: pieces[0], fillRule: rule)
            firstPath.id = shape.path.id
            var added: [VectorObject] = []
            for piece in pieces.dropFirst() {
                var copy = shape
                copy.id = UUID()
                copy.path = VectorPath(cgPath: piece, fillRule: rule)
                copy.updateBounds()
                added.append(VectorObject(shape: copy, layerIndex: object.layerIndex))
            }
            steps.append(SplitPathCommand(objectID: shape.id, oldPath: shape.path, newPath: firstPath, addedObjects: added))
            resultIDs.append(shape.id)
            resultIDs.append(contentsOf: added.map { $0.id })
        }
        guard !steps.isEmpty else { return }
        document.commandManager.execute(EraserCommand(steps: steps))
        if !selected.isEmpty {
            let kept = document.viewState.orderedSelectedObjectIDs.filter { !deletedIDs.contains($0) }
            let ordered = kept + resultIDs.filter { !kept.contains($0) }
            document.viewState.selectedObjectIDs = Set(ordered)
            document.viewState.orderedSelectedObjectIDs = ordered
        }
    }
}
