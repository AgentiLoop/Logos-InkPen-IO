import SwiftUI

/// Undo step for joining two open paths: path of `survivor` is replaced by the merged path and `removed` is deleted.
final class JoinPathsCommand: BaseCommand {
    private let modify: ModifyPathCommand
    private let delete: DeleteObjectCommand

    init(survivorID: UUID, oldPath: VectorPath, mergedPath: VectorPath, removedID: UUID, document: VectorDocument) {
        modify = ModifyPathCommand(objectID: survivorID, oldPath: oldPath, newPath: mergedPath)
        delete = DeleteObjectCommand(objectIDs: [removedID], document: document)
    }

    override func execute(on document: VectorDocument) {
        modify.execute(on: document)
        delete.execute(on: document)
    }

    override func undo(on document: VectorDocument) {
        delete.undo(on: document)
        modify.undo(on: document)
    }
}

/// An end point of another open path under the Pen cursor.
struct PenJoinTarget {
    let shapeID: UUID
    let atStart: Bool
    let point: CGPoint
}

extension DrawingCanvas {

    /// Illustrator Pen: while drawing, clicking an end point of another open path joins the two paths.
    internal func findPenJoinTarget(at location: CGPoint) -> PenJoinTarget? {
        let tolerance = max(2.0, 8.0 / zoomLevel)
        for (id, object) in document.snapshot.objects {
            guard id != activeBezierShape?.id,
                  case .shape(let shape) = object.objectType,
                  !shape.isGroup, !shape.isGroupContainer, shape.isVisible, !shape.isLocked,
                  shape.transform == .identity,
                  !shape.path.isClosed,
                  !shape.path.elements.contains(where: { if case .close = $0 { return true } else { return false } }),
                  shape.path.elements.count >= 2,
                  case .move(let first) = shape.path.elements[0],
                  let last = shape.path.elements.last?.endpointCGPoint else { continue }
            if distance(location, last) <= tolerance {
                return PenJoinTarget(shapeID: id, atStart: false, point: last)
            }
            if distance(location, first.cgPoint) <= tolerance {
                return PenJoinTarget(shapeID: id, atStart: true, point: first.cgPoint)
            }
        }
        return nil
    }

    /// Ends the in-progress pen path on the target's end point and merges the target into it.
    internal func joinPenPath(with target: PenJoinTarget) {
        guard let activeID = activeBezierShape?.id,
              let targetObject = document.snapshot.objects[target.shapeID],
              case .shape(let targetShape) = targetObject.objectType else { return }
        let appended = VectorPoint(target.point)
        bezierPoints.append(appended)
        bezierPath?.addElement(.line(to: appended))
        finishBezierPath()

        guard let activeShape = document.findShape(by: activeID) else { return }
        let oldPath = activeShape.path
        guard !oldPath.isClosed, oldPath.elements.count >= 1 else { return }
        let incoming = target.atStart ? targetShape.path.elements : reversedOpenElements(targetShape.path.elements)
        var merged = oldPath
        merged.elements = oldPath.elements + Array(incoming.dropFirst())
        merged.bezierHandles = nil
        merged.pendingStartHandle = nil
        merged.pendingEndHandle = nil
        let command = JoinPathsCommand(survivorID: activeID, oldPath: oldPath, mergedPath: merged,
                                       removedID: target.shapeID, document: document)
        document.commandManager.execute(command)
        document.viewState.selectedObjectIDs = [activeID]
        document.viewState.orderedSelectedObjectIDs = [activeID]
    }
}
