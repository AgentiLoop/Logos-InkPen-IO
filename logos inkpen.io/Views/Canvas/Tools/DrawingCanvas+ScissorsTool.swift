import SwiftUI

/// Undo step for a Scissors cut: the clicked shape gets its first piece, further pieces are added as new shapes.
final class SplitPathCommand: BaseCommand {
    private let modify: ModifyPathCommand
    private let add: AddObjectCommand?

    init(objectID: UUID, oldPath: VectorPath, newPath: VectorPath, addedObjects: [VectorObject]) {
        modify = ModifyPathCommand(objectID: objectID, oldPath: oldPath, newPath: newPath)
        add = addedObjects.isEmpty ? nil : AddObjectCommand(objects: addedObjects)
    }

    override func execute(on document: VectorDocument) {
        modify.execute(on: document)
        add?.execute(on: document)
    }

    override func undo(on document: VectorDocument) {
        add?.undo(on: document)
        modify.undo(on: document)
    }
}

extension DrawingCanvas {

    /// Illustrator Scissors: click an anchor or segment of a path to cut it there.
    func handleScissorsTap(at location: CGPoint) {
        let tolerance: Double = 8.0 / zoomLevel
        let selected = document.viewState.selectedObjectIDs
        var scopes: [Set<UUID>?] = []
        if !selected.isEmpty { scopes.append(selected) }
        scopes.append(nil)
        for scope in scopes {
            if let anchor = findAnchorPointAt(location: location, tolerance: tolerance, restrictedTo: scope),
               cutShape(id: anchor.shapeID, location: location, anchorElementIndex: anchor.elementIndex, segmentElementIndex: nil) {
                return
            }
            if let hit = findSegmentAt(location: location, tolerance: tolerance, restrictedTo: scope),
               cutShape(id: hit.shapeID, location: location, anchorElementIndex: nil, segmentElementIndex: hit.elementIndex) {
                return
            }
        }
        NSSound.beep()
    }

    private func cutShape(id: UUID, location: CGPoint, anchorElementIndex: Int?, segmentElementIndex: Int?) -> Bool {
        guard let object = document.snapshot.objects[id],
              case .shape(let shape) = object.objectType,
              !shape.isGroup, !shape.isGroupContainer else { return false }
        let local = shape.transform.isIdentity ? location : location.applying(shape.transform.inverted())
        let cutLocation: PathCutLocation
        if let anchorElementIndex {
            cutLocation = .anchor(elementIndex: anchorElementIndex)
        } else if let segmentElementIndex {
            cutLocation = .segment(elementIndex: segmentElementIndex, near: local)
        } else {
            return false
        }
        if shape.isCompoundPath {
            return cutCompoundShape(id: id, shape: shape, at: cutLocation)
        }
        guard let pieces = cuttingPath(shape.path.elements, at: cutLocation), !pieces.isEmpty else { return false }

        let oldPath = shape.path
        var firstPath = VectorPath(elements: pieces[0], isClosed: false, fillRule: shape.path.fillRule.cgPathFillRule)
        firstPath.id = oldPath.id
        var added: [VectorObject] = []
        var newIDs: [UUID] = []
        for elements in pieces.dropFirst() {
            var copy = shape
            copy.id = UUID()
            copy.path = VectorPath(elements: elements, isClosed: false, fillRule: shape.path.fillRule.cgPathFillRule)
            copy.updateBounds()
            added.append(VectorObject(shape: copy, layerIndex: object.layerIndex))
            newIDs.append(copy.id)
        }
        let command = SplitPathCommand(objectID: id, oldPath: oldPath, newPath: firstPath, addedObjects: added)
        document.commandManager.execute(command)
        document.viewState.selectedObjectIDs = Set([id] + newIDs)
        document.viewState.orderedSelectedObjectIDs = [id] + newIDs
        return true
    }

    /// Scissors on a compound path cuts only the subpath that was clicked; the result stays one compound path
    /// (a closed subpath becomes an open one, an open subpath becomes two).
    private func cutCompoundShape(id: UUID, shape: VectorShape, at cutLocation: PathCutLocation) -> Bool {
        let elements = shape.path.elements
        let target: Int
        switch cutLocation {
        case .anchor(let elementIndex), .segment(let elementIndex, _): target = elementIndex
        }
        guard target >= 0, target < elements.count else { return false }
        var starts: [Int] = []
        for (index, element) in elements.enumerated() {
            if case .move = element { starts.append(index) }
        }
        guard let startPosition = starts.lastIndex(where: { $0 <= target }) else { return false }
        let lower = starts[startPosition]
        let upper = startPosition + 1 < starts.count ? starts[startPosition + 1] : elements.count
        let relativeLocation: PathCutLocation
        switch cutLocation {
        case .anchor(let elementIndex): relativeLocation = .anchor(elementIndex: elementIndex - lower)
        case .segment(let elementIndex, let near): relativeLocation = .segment(elementIndex: elementIndex - lower, near: near)
        }
        guard let pieces = cuttingPath(Array(elements[lower..<upper]), at: relativeLocation), !pieces.isEmpty else { return false }
        let newElements = Array(elements[..<lower]) + pieces.flatMap { $0 } + Array(elements[upper...])
        let oldPath = shape.path
        var newPath = VectorPath(elements: newElements, isClosed: false, fillRule: oldPath.fillRule.cgPathFillRule)
        newPath.id = oldPath.id
        document.commandManager.execute(SplitPathCommand(objectID: id, oldPath: oldPath, newPath: newPath, addedObjects: []))
        document.viewState.selectedObjectIDs = [id]
        document.viewState.orderedSelectedObjectIDs = [id]
        return true
    }
}
