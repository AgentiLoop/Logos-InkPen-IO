import XCTest
@testable import logos_inkpen_io

/// Open an SVG → edit → undo must give back exactly what was opened, and an edit must only touch
/// the selected objects. These go through the same document calls the arrow keys use.
final class SVGEditUndoTests: XCTestCase {

    private let twoGroups = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <g id="left">
        <rect x="10" y="10" width="20" height="20" fill="red"/>
        <circle cx="60" cy="20" r="10" fill="green"/>
      </g>
      <g id="right">
        <rect x="200" y="10" width="20" height="20" fill="blue"/>
        <rect x="240" y="10" width="20" height="20" fill="black"/>
      </g>
      <rect x="10" y="200" width="30" height="30" fill="orange"/>
      <rect x="100" y="200" width="30" height="30" transform="translate(50,10)" fill="purple"/>
    </svg>
    """

    private func open(_ svg: String) throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func layerOrder(_ doc: VectorDocument) -> [[UUID]] {
        doc.snapshot.layers.map(\.objectIDs)
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

    func testOpenedSVGHasNothingToUndo() throws {
        let doc = try open(twoGroups)
        let before = shapes(doc)
        XCTAssertFalse(doc.commandManager.canUndo, "Opening a file must not leave undo steps that could erase it")
        doc.undo()
        XCTAssertEqual(shapes(doc), before)
        XCTAssertEqual(doc.snapshot.objects.count, before.count)
    }

    func testNudgeShapeThenUndoRestoresDocumentExactly() throws {
        let doc = try open(twoGroups)
        let before = shapes(doc)
        let order = layerOrder(doc)
        guard let target = topLevel(doc).first(where: { !$0.isGroup }) else { return XCTFail("no shape") }

        doc.viewState.selectedObjectIDs = [target.id]
        doc.nudgeSelectedObjects(by: CGVector(dx: 7, dy: -3))

        XCTAssertTrue(doc.commandManager.canUndo)
        let moved = try XCTUnwrap(doc.snapshot.objects[target.id]?.shape)
        XCTAssertEqual(moved.bounds.minX, target.bounds.minX + 7, accuracy: 0.001)
        XCTAssertEqual(moved.bounds.minY, target.bounds.minY - 3, accuracy: 0.001)

        doc.undo()
        XCTAssertEqual(shapes(doc), before, "Undo must restore every object exactly")
        XCTAssertEqual(layerOrder(doc), order)
    }

    func testNudgeOneGroupLeavesEverythingElseAlone() throws {
        let doc = try open(twoGroups)
        let before = shapes(doc)
        let groups = topLevel(doc).filter(\.isGroup)
        XCTAssertEqual(groups.count, 2)
        guard let group = groups.first else { return }
        let touched = descendants(of: group.id, in: doc)
        XCTAssertGreaterThan(touched.count, 1)

        doc.viewState.selectedObjectIDs = [group.id]
        doc.nudgeSelectedObjects(by: CGVector(dx: 5, dy: 5))

        for (id, shape) in shapes(doc) where !touched.contains(id) {
            XCTAssertEqual(shape, before[id], "Object \(shape.name) outside the selected group changed")
        }
        for id in touched {
            let now = try XCTUnwrap(doc.snapshot.objects[id]?.shape)
            let was = try XCTUnwrap(before[id])
            XCTAssertEqual(now.bounds.minX, was.bounds.minX + 5, accuracy: 0.001, "\(now.name) did not move with its group")
        }

        doc.undo()
        XCTAssertEqual(shapes(doc), before)
    }

    func testShapeWithTransformAttributeMovesByExactlyTheNudge() throws {
        let doc = try open(twoGroups)
        guard let target = topLevel(doc).last(where: { !$0.isGroup }) else { return XCTFail("no shape") }
        let start = target.bounds

        doc.viewState.selectedObjectIDs = [target.id]
        doc.nudgeSelectedObjects(by: CGVector(dx: 4, dy: 0))
        let moved = try XCTUnwrap(doc.snapshot.objects[target.id]?.shape)
        XCTAssertEqual(moved.bounds.minX, start.minX + 4, accuracy: 0.001)
        XCTAssertEqual(moved.bounds.width, start.width, accuracy: 0.001)

        doc.nudgeSelectedObjects(by: CGVector(dx: 4, dy: 0))
        let movedTwice = try XCTUnwrap(doc.snapshot.objects[target.id]?.shape)
        XCTAssertEqual(movedTwice.bounds.minX, start.minX + 8, accuracy: 0.001, "Second nudge must not re-apply the imported transform")
    }

    func testUndoRedoUndoRoundTrip() throws {
        let doc = try open(twoGroups)
        let before = shapes(doc)
        let groups = topLevel(doc).filter(\.isGroup)
        guard let group = groups.last else { return XCTFail("no group") }

        doc.viewState.selectedObjectIDs = [group.id]
        doc.nudgeSelectedObjects(by: CGVector(dx: 10, dy: 0))
        doc.nudgeSelectedObjects(by: CGVector(dx: 0, dy: 10))
        let after = shapes(doc)

        doc.undo(); doc.undo()
        XCTAssertEqual(shapes(doc), before)
        doc.redo(); doc.redo()
        XCTAssertEqual(shapes(doc), after)
        doc.undo(); doc.undo()
        XCTAssertEqual(shapes(doc), before)
        XCTAssertFalse(doc.commandManager.canUndo)
    }
}
