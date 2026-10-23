import XCTest
@testable import logos_inkpen_io

/// Object menu commands (Delete, Group/Ungroup, Arrange, Duplicate, Lock/Hide) must change only
/// what is selected, and ⌘Z must give back exactly the document that was there before.
final class ObjectCommandUndoTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect id="a" x="10" y="10" width="20" height="20" fill="red"/>
      <rect id="b" x="50" y="10" width="20" height="20" fill="green"/>
      <rect id="c" x="90" y="10" width="20" height="20" fill="blue"/>
      <g id="g">
        <rect x="200" y="10" width="20" height="20" fill="black"/>
        <circle cx="260" cy="20" r="10" fill="orange"/>
      </g>
    </svg>
    """

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        let layer = try XCTUnwrap(topLevelIDs(doc).first.flatMap { doc.snapshot.objects[$0]?.layerIndex })
        doc.selectedLayerIndex = layer
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func layerOrder(_ doc: VectorDocument) -> [[UUID]] {
        doc.snapshot.layers.map(\.objectIDs)
    }

    /// Top-level objects of the drawing layer(s), back to front.
    private func topLevelIDs(_ doc: VectorDocument) -> [UUID] {
        doc.snapshot.layers.enumerated()
            .filter { $0.offset > 2 }
            .flatMap(\.element.objectIDs)
            .filter { id in
                guard let s = doc.snapshot.objects[id]?.shape else { return false }
                return s.name != "Canvas Background" && s.name != "Pasteboard Background"
            }
    }

    private func plainShapes(_ doc: VectorDocument) -> [UUID] {
        topLevelIDs(doc).filter { doc.snapshot.objects[$0]?.shape.isGroup == false }
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func assertRestored(_ doc: VectorDocument, _ before: [UUID: VectorShape], _ order: [[UUID]],
                                _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(shapes(doc).keys), Set(before.keys), "\(message): object set differs", file: file, line: line)
        for (id, shape) in before {
            XCTAssertEqual(shapes(doc)[id], shape, "\(message): \(shape.name) differs", file: file, line: line)
        }
        XCTAssertEqual(layerOrder(doc), order, "\(message): stacking order differs", file: file, line: line)
    }

    func testFixtureShape() throws {
        let doc = try open()
        XCTAssertEqual(plainShapes(doc).count, 3)
        XCTAssertEqual(topLevelIDs(doc).count, 4)
    }

    // MARK: Delete

    func testDeleteRemovesOnlySelectionAndUndoRestoresIt() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let target = try XCTUnwrap(plainShapes(doc).dropFirst().first)

        select([target], in: doc)
        doc.removeSelectedObjects()

        XCTAssertNil(doc.snapshot.objects[target])
        XCTAssertFalse(layerOrder(doc).flatMap { $0 }.contains(target))
        XCTAssertTrue(doc.viewState.selectedObjectIDs.isEmpty)
        for (id, shape) in before where id != target {
            XCTAssertEqual(shapes(doc)[id], shape, "\(shape.name) changed by deleting another object")
        }

        doc.undo()
        assertRestored(doc, before, order, "Undo delete")
        doc.redo()
        XCTAssertNil(doc.snapshot.objects[target], "Redo must delete again")
    }

    func testDeleteGroupThenUndoBringsBackItsMembers() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let group = try XCTUnwrap(topLevelIDs(doc).first { doc.snapshot.objects[$0]?.shape.isGroup == true })

        select([group], in: doc)
        doc.removeSelectedObjects()
        XCTAssertFalse(topLevelIDs(doc).contains(group))

        doc.undo()
        assertRestored(doc, before, order, "Undo group delete")
        let members = try XCTUnwrap(doc.snapshot.objects[group]?.shape.memberIDs)
        XCTAssertEqual(members.count, 2)
        for m in members { XCTAssertNotNil(doc.snapshot.objects[m], "Group member missing after undo") }
    }

    // MARK: Group / Ungroup

    func testGroupThenUndoRestoresTopLevelObjects() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let ids = Array(plainShapes(doc).prefix(2))

        select(ids, in: doc)
        doc.groupSelectedObjects()

        let groupID = try XCTUnwrap(doc.viewState.selectedObjectIDs.first)
        XCTAssertEqual(doc.viewState.selectedObjectIDs.count, 1)
        let group = try XCTUnwrap(doc.snapshot.objects[groupID]?.shape)
        XCTAssertTrue(group.isGroup)
        XCTAssertEqual(Set(group.memberIDs), Set(ids))
        for id in ids {
            XCTAssertFalse(topLevelIDs(doc).contains(id), "Grouped object still at top level")
            XCTAssertEqual(doc.snapshot.objects[id]?.shape.bounds, before[id]?.bounds, "Grouping moved a member")
        }

        doc.undo()
        assertRestored(doc, before, order, "Undo group")
    }

    func testUngroupKeepsMembersInPlaceAndUndoRegroups() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let groupID = try XCTUnwrap(topLevelIDs(doc).first { doc.snapshot.objects[$0]?.shape.isGroup == true })
        let members = try XCTUnwrap(before[groupID]?.memberIDs)

        select([groupID], in: doc)
        doc.ungroupSelectedObjects()

        XCTAssertNil(doc.snapshot.objects[groupID], "Group container must be gone")
        XCTAssertEqual(doc.viewState.selectedObjectIDs, Set(members))
        for m in members {
            XCTAssertTrue(topLevelIDs(doc).contains(m), "Member not promoted to top level")
            XCTAssertEqual(doc.snapshot.objects[m]?.shape.bounds, before[m]?.bounds, "Ungroup moved a member")
        }

        doc.undo()
        assertRestored(doc, before, order, "Undo ungroup")
    }

    func testGroupUngroupRoundTripThroughUndoAndRedo() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        select(plainShapes(doc), in: doc)
        doc.groupSelectedObjects()
        doc.ungroupSelectedObjects()
        let after = layerOrder(doc)

        doc.undo(); doc.undo()
        assertRestored(doc, before, order, "Undo group+ungroup")
        doc.redo(); doc.redo()
        XCTAssertEqual(layerOrder(doc), after)
        doc.undo(); doc.undo()
        assertRestored(doc, before, order, "Second undo group+ungroup")
    }

    func testNudgeGroupedObjectsMovesAllMembers() throws {
        let doc = try open()
        let ids = Array(plainShapes(doc).prefix(2))
        let start = ids.compactMap { doc.snapshot.objects[$0]?.shape.bounds }
        select(ids, in: doc)
        doc.groupSelectedObjects()

        doc.nudgeSelectedObjects(by: CGVector(dx: 6, dy: 2))
        for (id, was) in zip(ids, start) {
            let now = try XCTUnwrap(doc.snapshot.objects[id]?.shape.bounds)
            XCTAssertEqual(now.minX, was.minX + 6, accuracy: 0.001)
            XCTAssertEqual(now.minY, was.minY + 2, accuracy: 0.001)
        }
    }

    // MARK: Arrange

    func testBringToFrontAndSendToBackThenUndo() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let first = try XCTUnwrap(topLevelIDs(doc).first)

        select([first], in: doc)
        doc.bringSelectedToFront()
        XCTAssertEqual(topLevelIDs(doc).last, first)
        XCTAssertEqual(shapes(doc), before, "Arrange must not change any shape")

        doc.sendSelectedToBack()
        XCTAssertEqual(topLevelIDs(doc).first, first)

        doc.undo()
        XCTAssertEqual(topLevelIDs(doc).last, first)
        doc.undo()
        assertRestored(doc, before, order, "Undo arrange")
    }

    func testBringForwardAndSendBackwardMoveOneStep() throws {
        let doc = try open()
        let ids = topLevelIDs(doc)
        XCTAssertGreaterThanOrEqual(ids.count, 3)

        select([ids[0]], in: doc)
        doc.bringSelectedForward()
        XCTAssertEqual(Array(topLevelIDs(doc).prefix(2)), [ids[1], ids[0]])

        doc.sendSelectedBackward()
        XCTAssertEqual(topLevelIDs(doc), ids)

        let countBefore = doc.commandManager.canUndo
        select([ids[0]], in: doc)
        doc.sendSelectedBackward() // already at back: no-op
        XCTAssertEqual(topLevelIDs(doc), ids)
        XCTAssertEqual(doc.commandManager.canUndo, countBefore)
    }

    // MARK: Duplicate

    func testDuplicateShapeIsOffsetCopyAndUndoRemovesIt() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let target = try XCTUnwrap(plainShapes(doc).first)
        let original = try XCTUnwrap(before[target])

        select([target], in: doc)
        doc.duplicateSelectedShapes()

        XCTAssertEqual(doc.viewState.selectedObjectIDs.count, 1)
        let copyID = try XCTUnwrap(doc.viewState.selectedObjectIDs.first)
        XCTAssertNotEqual(copyID, target)
        let copy = try XCTUnwrap(doc.snapshot.objects[copyID]?.shape)
        XCTAssertEqual(copy.bounds.minX, original.bounds.minX + 10, accuracy: 0.001)
        XCTAssertEqual(copy.bounds.minY, original.bounds.minY + 10, accuracy: 0.001)
        XCTAssertEqual(copy.bounds.size, original.bounds.size)
        XCTAssertEqual(shapes(doc)[target], original, "Duplicate changed the original")

        doc.undo()
        assertRestored(doc, before, order, "Undo duplicate")
    }

    func testDuplicatedGroupDoesNotShareMembersWithOriginal() throws {
        let doc = try open()
        let groupID = try XCTUnwrap(topLevelIDs(doc).first { doc.snapshot.objects[$0]?.shape.isGroup == true })
        let originalMembers = try XCTUnwrap(doc.snapshot.objects[groupID]?.shape.memberIDs)
        let memberBounds = originalMembers.compactMap { doc.snapshot.objects[$0]?.shape.bounds }

        select([groupID], in: doc)
        doc.duplicateSelectedShapes()
        let copyID = try XCTUnwrap(doc.viewState.selectedObjectIDs.first)
        XCTAssertNotEqual(copyID, groupID)

        let copy = try XCTUnwrap(doc.snapshot.objects[copyID]?.shape)
        XCTAssertTrue(copy.isGroup)
        XCTAssertEqual(copy.memberIDs.count, originalMembers.count)
        XCTAssertTrue(Set(copy.memberIDs).isDisjoint(with: originalMembers), "Copy shares member objects with the original group")
        for (copyMember, was) in zip(copy.memberIDs, memberBounds) {
            let now = try XCTUnwrap(doc.snapshot.objects[copyMember]?.shape.bounds, "Copied member missing")
            XCTAssertEqual(now.minX, was.minX + 10, accuracy: 0.001)
            XCTAssertEqual(now.minY, was.minY + 10, accuracy: 0.001)
        }

        // Moving the copy must leave the original group's members where they were.
        doc.nudgeSelectedObjects(by: CGVector(dx: 5, dy: 0))
        let after = originalMembers.compactMap { doc.snapshot.objects[$0]?.shape.bounds }
        XCTAssertEqual(after, memberBounds, "Moving the duplicate moved the original group")
    }

    // MARK: Lock / Hide

    func testLockAndHideAreUndoable() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let ids = plainShapes(doc)

        select([ids[0]], in: doc)
        doc.lockSelectedObjects()
        XCTAssertEqual(doc.snapshot.objects[ids[0]]?.shape.isLocked, true)
        XCTAssertTrue(doc.viewState.selectedObjectIDs.isEmpty)

        select([ids[1]], in: doc)
        doc.hideSelectedObjects()
        XCTAssertEqual(doc.snapshot.objects[ids[1]]?.shape.isVisible, false)
        XCTAssertEqual(doc.snapshot.objects[ids[2]]?.shape.isVisible, true)

        doc.undo()
        XCTAssertEqual(doc.snapshot.objects[ids[1]]?.shape.isVisible, true)
        doc.undo()
        assertRestored(doc, before, order, "Undo lock+hide")
    }

    func testLockedObjectIsLeftOutOfSelectAll() throws {
        let doc = try open()
        let ids = plainShapes(doc)
        select([ids[0]], in: doc)
        doc.lockSelectedObjects()

        doc.selectAll()
        XCTAssertFalse(doc.viewState.selectedObjectIDs.contains(ids[0]))
        XCTAssertTrue(doc.viewState.selectedObjectIDs.contains(ids[1]))

        doc.unlockAllObjects()
        XCTAssertEqual(doc.snapshot.objects[ids[0]]?.shape.isLocked, false)
    }
}
