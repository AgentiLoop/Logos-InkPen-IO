import SwiftUI

extension VectorDocument {

    /// Open, untransformed, single-subpath plain shapes among the selection (candidates for Object > Join).
    private func joinableSelectedPaths() -> [(id: UUID, shape: VectorShape)] {
        var result: [(id: UUID, shape: VectorShape)] = []
        let ordered = viewState.orderedSelectedObjectIDs.filter { viewState.selectedObjectIDs.contains($0) }
        let ids = ordered.count == viewState.selectedObjectIDs.count ? ordered : Array(viewState.selectedObjectIDs)
        for id in ids {
            guard let object = snapshot.objects[id], case .shape(let shape) = object.objectType,
                  !shape.isGroup, !shape.isGroupContainer, !shape.isLocked,
                  shape.transform == .identity,
                  !shape.path.isClosed,
                  shape.path.elements.count >= 2,
                  case .move = shape.path.elements[0],
                  shape.path.elements.dropFirst().allSatisfy({
                      switch $0 { case .move, .close: return false; default: return true }
                  })
            else { continue }
            result.append((id, shape))
        }
        return result
    }

    var canJoinSelectedPaths: Bool {
        !joinableSelectedPaths().isEmpty
    }

    /// Illustrator Object > Path > Join (Cmd+J): one open path is closed; several open paths are chained by their closest end points.
    func joinSelectedPaths() {
        let candidates = joinableSelectedPaths()
        guard !candidates.isEmpty else { return }

        if candidates.count == 1 {
            let (id, shape) = candidates[0]
            var closed = shape.path
            closed.elements.append(.close)
            closed.isClosed = true
            closed.bezierHandles = nil
            commandManager.execute(ModifyPathCommand(objectID: id, oldPath: shape.path, newPath: closed))
            return
        }

        var work = candidates.map { (id: $0.id, elements: $0.shape.path.elements) }
        var removed: [UUID] = []
        let survivorIndexInitial = 0
        while work.count > 1 {
            var best: (a: Int, b: Int, aEnd: Bool, bStart: Bool, dist: CGFloat)?
            for i in 0..<work.count {
                for j in (i + 1)..<work.count {
                    let ai = [(false, work[i].elements.first?.endpointCGPoint), (true, work[i].elements.last?.endpointCGPoint)]
                    let bj = [(true, work[j].elements.first?.endpointCGPoint), (false, work[j].elements.last?.endpointCGPoint)]
                    for (aEnd, ap) in ai {
                        for (bStart, bp) in bj {
                            guard let ap = ap, let bp = bp else { continue }
                            let d = hypot(ap.x - bp.x, ap.y - bp.y)
                            if best == nil || d < best!.dist { best = (i, j, aEnd, bStart, d) }
                        }
                    }
                }
            }
            guard let pair = best else { break }
            let first = pair.aEnd ? work[pair.a].elements : reversedJoinElements(work[pair.a].elements)
            let second = pair.bStart ? work[pair.b].elements : reversedJoinElements(work[pair.b].elements)
            var merged = first
            if pair.dist > 0.01, let start = second.first {
                if case .move(let p) = start { merged.append(.line(to: p)) }
            }
            merged.append(contentsOf: second.dropFirst())
            removed.append(work[pair.b].id)
            work[pair.a].elements = merged
            work.remove(at: pair.b)
        }

        let survivor = work[survivorIndexInitial]
        guard let original = candidates.first(where: { $0.id == survivor.id }) else { return }
        var newPath = original.shape.path
        newPath.elements = survivor.elements
        newPath.bezierHandles = nil
        newPath.pendingStartHandle = nil
        newPath.pendingEndHandle = nil
        commandManager.execute(JoinPathsCommand(survivorID: survivor.id, oldPath: original.shape.path, mergedPath: newPath,
                                                removedIDs: removed, document: self))
        viewState.selectedObjectIDs = [survivor.id]
        viewState.orderedSelectedObjectIDs = [survivor.id]
    }

    private func reversedJoinElements(_ elements: [PathElement]) -> [PathElement] {
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
