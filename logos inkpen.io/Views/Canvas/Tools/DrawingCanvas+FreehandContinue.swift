import SwiftUI

/// Illustrator Pencil: with an open path selected, starting a stroke on one of its end points continues that path.
struct FreehandContinueTarget {
    let shapeID: UUID
    let atStart: Bool
    let oldPath: VectorPath
}

extension DrawingCanvas {

    /// Finds the selected open path whose first/last anchor lies under `location`.
    internal func findFreehandContinueTarget(at location: CGPoint) -> FreehandContinueTarget? {
        guard !ApplicationSettings.shared.freehandExpandStroke else { return nil }
        let selected = document.viewState.selectedObjectIDs
        guard selected.count == 1, let id = selected.first,
              let shape = document.findShape(by: id),
              !shape.isGroup, !shape.isGroupContainer, shape.isVisible, !shape.isLocked,
              shape.strokeStyle != nil,
              shape.transform == .identity else { return nil }
        let path = shape.path
        guard !path.isClosed,
              !path.elements.contains(where: { if case .close = $0 { return true } else { return false } }),
              path.pendingStartHandle == nil, path.pendingEndHandle == nil,
              path.bezierHandles?.isEmpty ?? true,
              path.elements.count >= 2,
              case .move(let first) = path.elements[0],
              let last = path.elements.last?.endpointCGPoint else { return nil }
        let tolerance = max(2.0, 10.0 / zoomLevel)
        if distance(location, last) <= tolerance {
            return FreehandContinueTarget(shapeID: id, atStart: false, oldPath: path)
        }
        if distance(location, first.cgPoint) <= tolerance {
            return FreehandContinueTarget(shapeID: id, atStart: true, oldPath: path)
        }
        return nil
    }

    /// Appends the freshly drawn stroke to the continue target. Returns true if it was merged.
    internal func mergeFreehandStroke(_ newPath: VectorPath, into target: FreehandContinueTarget) -> Bool {
        guard newPath.elements.count >= 2, document.findShape(by: target.shapeID) != nil else { return false }
        let base = target.atStart ? reversedOpenElements(target.oldPath.elements) : target.oldPath.elements
        var merged = target.oldPath
        merged.elements = base + Array(newPath.elements.dropFirst())
        let command = ModifyPathCommand(objectID: target.shapeID, oldPath: target.oldPath, newPath: merged)
        document.commandManager.execute(command)
        document.viewState.selectedObjectIDs = [target.shapeID]
        document.viewState.orderedSelectedObjectIDs = [target.shapeID]
        return true
    }

    private func reversedOpenElements(_ elements: [PathElement]) -> [PathElement] {
        guard case .move = elements.first, let lastPoint = elements.last?.endpoint else { return elements }
        var anchors: [VectorPoint] = []
        for element in elements { if let p = element.endpoint { anchors.append(p) } }
        var result: [PathElement] = [.move(to: lastPoint)]
        var segmentIndex = elements.count - 1
        while segmentIndex >= 1 {
            let target = anchors[segmentIndex - 1]
            switch elements[segmentIndex] {
            case .curve(_, let c1, let c2):
                result.append(.curve(to: target, control1: c2, control2: c1))
            case .quadCurve(_, let c):
                result.append(.quadCurve(to: target, control: c))
            default:
                result.append(.line(to: target))
            }
            segmentIndex -= 1
        }
        return result
    }
}
