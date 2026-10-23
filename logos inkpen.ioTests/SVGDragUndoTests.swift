import XCTest
@testable import logos_inkpen_io

/// Mouse-drag moves with the selection tool go through VectorDocument.commitSelectionDrag (the same
/// call DrawingCanvas.finishSelectionDrag makes on mouse-up). Open SVG → drag → undo must restore
/// exactly, a drag must only touch the dragged objects, and hit testing must follow the move.
final class SVGDragUndoTests: XCTestCase {

    private let artwork = """
    <svg xmlns="http://www.w3.org/2000/svg" width="500" height="400">
      <g id="plain">
        <rect x="10" y="10" width="20" height="20" fill="red"/>
        <circle cx="60" cy="20" r="10" fill="green"/>
      </g>
      <g id="moved" transform="translate(30,40)">
        <rect x="200" y="10" width="20" height="20" fill="blue"/>
        <g id="inner">
          <rect x="240" y="10" width="20" height="20" fill="black"/>
        </g>
      </g>
      <line x1="10" y1="300" x2="200" y2="300" stroke="black"/>
      <rect x="300" y="300" width="30" height="30" transform="translate(50,10)" fill="purple"/>
      <rect x="400" y="200" width="30" height="30" fill="orange"/>
    </svg>
    """

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(artwork.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func topLevel(_ doc: VectorDocument) -> [VectorShape] {
        doc.snapshot.layers.flatMap(\.objectIDs).compactMap { doc.snapshot.objects[$0]?.shape }
    }

    private func descendants(of id: UUID, in doc: VectorDocument) -> Set<UUID> {
        guard let shape = doc.snapshot.objects[id]?.shape else { return [] }
        var ids: Set<UUID> = [id]
        for member in shape.memberIDs { ids.formUnion(descendants(of: member, in: doc)) }
        return ids
    }

    /// Where a leaf shape is drawn: its own bounds through its own transform and every parent group's.
    private func drawnBounds(_ id: UUID, in doc: VectorDocument) -> CGRect? {
        guard let shape = doc.snapshot.objects[id]?.shape else { return nil }
        var rect = shape.bounds.applying(shape.transform)
        var childID = id
        while let parent = doc.snapshot.objects.values.map(\.shape).first(where: { $0.memberIDs.contains(childID) }) {
            rect = rect.applying(parent.transform)
            childID = parent.id
        }
        return rect
    }

    private func drag(_ ids: Set<UUID>, by delta: CGPoint, in doc: VectorDocument) {
        doc.viewState.selectedObjectIDs = ids
        doc.commitSelectionDrag(delta: delta)
    }

    private func assertOnlyMoved(_ touched: Set<UUID>, by delta: CGPoint, doc: VectorDocument,
                                 before: [UUID: VectorShape], beforeDrawn: [UUID: CGRect],
                                 file: StaticString = #filePath, line: UInt = #line) {
        for (id, shape) in shapes(doc) where !touched.contains(id) {
            XCTAssertEqual(shape, before[id], "\(shape.name) was not dragged but changed", file: file, line: line)
        }
        for id in touched where doc.snapshot.objects[id]?.shape.isGroupContainer == false {
            guard let was = beforeDrawn[id], let now = drawnBounds(id, in: doc) else {
                XCTFail("missing \(id)", file: file, line: line); continue
            }
            XCTAssertEqual(now.minX, was.minX + delta.x, accuracy: 0.001, "x of \(id)", file: file, line: line)
            XCTAssertEqual(now.minY, was.minY + delta.y, accuracy: 0.001, "y of \(id)", file: file, line: line)
            XCTAssertEqual(now.width, was.width, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(now.height, was.height, accuracy: 0.001, file: file, line: line)
        }
    }

    private func allDrawn(_ doc: VectorDocument) -> [UUID: CGRect] {
        var out: [UUID: CGRect] = [:]
        for id in doc.snapshot.objects.keys { out[id] = drawnBounds(id, in: doc) }
        return out
    }

    func testDragEveryTopLevelObjectThenUndoRestoresExactly() throws {
        let doc = try open()
        let delta = CGPoint(x: 13, y: -7)
        for object in topLevel(doc) {
            let before = shapes(doc)
            let beforeDrawn = allDrawn(doc)
            drag([object.id], by: delta, in: doc)
            XCTAssertTrue(doc.commandManager.canUndo, "\(object.name): drag left no undo step")
            assertOnlyMoved(descendants(of: object.id, in: doc), by: delta, doc: doc, before: before, beforeDrawn: beforeDrawn)
            doc.undo()
            XCTAssertEqual(shapes(doc), before, "\(object.name): undo did not restore the drag exactly")
        }
    }

    func testDragTwiceThenUndoTwiceAndRedo() throws {
        let doc = try open()
        let before = shapes(doc)
        let ids = Set(topLevel(doc).prefix(2).map(\.id))
        drag(ids, by: CGPoint(x: 5, y: 0), in: doc)
        drag(ids, by: CGPoint(x: 0, y: 5), in: doc)
        let after = shapes(doc)
        doc.undo(); doc.undo()
        XCTAssertEqual(shapes(doc), before)
        XCTAssertFalse(doc.commandManager.canUndo)
        doc.redo(); doc.redo()
        XCTAssertEqual(shapes(doc), after)
    }

    func testHitTestingFollowsDraggedObject() throws {
        let doc = try open()
        guard let orange = topLevel(doc).last(where: { !$0.isGroupContainer && $0.transform.isIdentity && $0.bounds.width > 1 && $0.bounds.height > 1 }) else {
            return XCTFail("no plain shape")
        }
        let oldCenter = CGPoint(x: orange.bounds.midX, y: orange.bounds.midY)
        let delta = CGPoint(x: 0, y: 100)
        drag([orange.id], by: delta, in: doc)

        let index = try XCTUnwrap(MetalSpatialIndex())
        index.rebuildLayers(Set(doc.snapshot.layers.map(\.id)), from: doc.snapshot)
        XCTAssertTrue(index.candidateObjectIDs(at: CGPoint(x: oldCenter.x, y: oldCenter.y + delta.y)).contains(orange.id))
        XCTAssertFalse(index.candidateObjectIDs(at: oldCenter).contains(orange.id))
    }
}
