import SwiftUI

/// Undo step for one Knife stroke that may have cut several shapes.
final class KnifeCutCommand: BaseCommand {
    private let steps: [SplitPathCommand]

    init(steps: [SplitPathCommand]) {
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

    internal func handleKnifeDragUpdate(at location: CGPoint) {
        let minimumSpacing = 1.5 / zoomLevel
        if let last = knifePoints.last, hypot(last.x - location.x, last.y - location.y) < minimumSpacing {
            return
        }
        knifePoints.append(location)
        guard knifePoints.count >= 2 else { return }
        var elements: [PathElement] = [.move(to: VectorPoint(knifePoints[0]))]
        for point in knifePoints.dropFirst() { elements.append(.line(to: VectorPoint(point))) }
        knifePreviewPath = VectorPath(elements: elements)
    }

    /// Illustrator Knife: drag a freehand line across filled shapes to slice them into separate closed pieces.
    /// With a selection only the selected shapes are cut; with nothing selected every shape the knife crosses is cut.
    internal func handleKnifeDragEnd() {
        let knife = knifePoints
        knifePoints = []
        knifePreviewPath = nil
        guard knife.count >= 2 else { return }

        let selected = document.viewState.selectedObjectIDs
        var steps: [SplitPathCommand] = []
        var resultIDs: [UUID] = []
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
            let localKnife: [CGPoint]
            if shape.transform.isIdentity {
                localKnife = knife
            } else {
                guard abs(shape.transform.a * shape.transform.d - shape.transform.b * shape.transform.c) > 1e-9 else { continue }
                let inverse = shape.transform.inverted()
                localKnife = knife.map { $0.applying(inverse) }
            }
            let rule = shape.path.fillRule.cgPathFillRule
            guard let pieces = knifeCutPieces(shapePath: shape.path.cgPath, fillRule: rule, knife: localKnife) else { continue }

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
        guard !steps.isEmpty else {
            NSSound.beep()
            return
        }
        document.commandManager.execute(KnifeCutCommand(steps: steps))
        document.viewState.selectedObjectIDs = Set(resultIDs)
        document.viewState.orderedSelectedObjectIDs = resultIDs
    }
}
