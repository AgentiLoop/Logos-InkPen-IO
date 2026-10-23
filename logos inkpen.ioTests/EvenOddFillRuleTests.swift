import XCTest
@testable import logos_inkpen_io

/// A compound path with the even-odd fill rule (a ring, a letter "O") must keep that rule — and its
/// closed flag — through every move or transform, or its hole fills in. Covers arrow-key nudge (objects
/// and points), mouse drag, Align, the Transform panel and the group transform the canvas handles use,
/// on a top-level ring and on a ring inside a group. Each edit is one undo step and ⌘Z restores exactly.
/// (VectorCraft #3272 / #1225 check the same: compound paths keep their fill rule through edits and undo.)
final class EvenOddFillRuleTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <path fill-rule="evenodd" fill="black" d="M10 10 L90 10 L90 90 L10 90 Z M30 30 L70 30 L70 70 L30 70 Z"/>
      <rect x="150" y="150" width="40" height="40" fill="red"/>
      <g>
        <path fill-rule="evenodd" fill="blue" d="M200 10 L280 10 L280 90 L200 90 Z M220 30 L260 30 L260 70 L220 70 Z"/>
        <rect x="300" y="10" width="20" height="20" fill="green"/>
      </g>
    </svg>
    """

    private var savedMode: AlignmentAnchorMode = .firstSelected

    override func setUp() {
        super.setUp()
        savedMode = ApplicationSettings.shared.alignmentAnchorMode
        ApplicationSettings.shared.alignmentAnchorMode = .firstSelected
    }

    override func tearDown() {
        ApplicationSettings.shared.alignmentAnchorMode = savedMode
        super.tearDown()
    }

    private struct Fixture {
        let ring: UUID, rect: UUID, group: UUID, groupRing: UUID
    }

    private func open() throws -> (VectorDocument, Fixture) {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        doc.viewState.transformOrigin = .center
        doc.settings.pageOrigin = .zero
        let ids = doc.snapshot.layers.enumerated()
            .filter { $0.offset > 2 }
            .flatMap(\.element.objectIDs)
            .filter { id in
                guard let s = doc.snapshot.objects[id]?.shape else { return false }
                return s.name != "Canvas Background" && s.name != "Pasteboard Background"
            }
        let shape = { (id: UUID) in doc.snapshot.objects[id]?.shape }
        let ring = try XCTUnwrap(ids.first { shape($0)?.isGroup == false && shape($0)?.path.fillRule == .evenOdd })
        let rect = try XCTUnwrap(ids.first { shape($0)?.isGroup == false && $0 != ring })
        let group = try XCTUnwrap(ids.first { shape($0)?.isGroup == true })
        let members = try XCTUnwrap(shape(group)?.memberIDs)
        XCTAssertEqual(members.count, 2, "fixture group members")
        let groupRing = try XCTUnwrap(members.first { shape($0)?.path.fillRule == .evenOdd }, "fixture group ring")
        return (doc, Fixture(ring: ring, rect: rect, group: group, groupRing: groupRing))
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    /// Opens a fresh document, runs `op`, and checks `target`'s path moved yet kept even-odd + closed flag,
    /// that it took one undo step (when `undoable`) and that ⌘Z restores every object exactly.
    private func check(_ name: String, undoable: Bool = true,
                       file: StaticString = #filePath, line: UInt = #line,
                       target: (Fixture) -> UUID, _ op: (VectorDocument, Fixture) -> Void) throws {
        let (doc, f) = try open()
        let id = target(f)
        let path = try XCTUnwrap(doc.snapshot.objects[id]?.shape.path)
        XCTAssertEqual(path.fillRule, .evenOdd, "\(name): fixture", file: file, line: line)
        let before = doc.snapshot.objects.mapValues(\.shape)
        let steps = doc.commandManager.undoCount

        op(doc, f)

        let after = try XCTUnwrap(doc.snapshot.objects[id]?.shape.path)
        XCTAssertNotEqual(after.elements, path.elements, "\(name): path did not move", file: file, line: line)
        XCTAssertEqual(after.fillRule, .evenOdd, "\(name): lost even-odd fill (hole fills in)", file: file, line: line)
        XCTAssertEqual(after.isClosed, path.isClosed, "\(name): closed flag changed", file: file, line: line)
        guard undoable else { return }
        XCTAssertEqual(doc.commandManager.undoCount, steps + 1, "\(name): undo steps", file: file, line: line)
        doc.commandManager.undo()
        for (oid, shape) in before {
            XCTAssertEqual(doc.snapshot.objects[oid]?.shape, shape, "\(name): undo left \(shape.name) changed",
                           file: file, line: line)
        }
    }

    // MARK: Nudge (arrow keys)

    func testNudgeKeepsEvenOdd() throws {
        try check("nudge ring", target: \.ring) { doc, f in
            select([f.ring], in: doc)
            doc.nudgeSelectedObjects(by: CGVector(dx: 5, dy: -3))
        }
        try check("nudge group", target: \.groupRing) { doc, f in
            select([f.group], in: doc)
            doc.nudgeSelectedObjects(by: CGVector(dx: 5, dy: -3))
        }
    }

    func testNudgeSelectedPointKeepsEvenOdd() throws {
        try check("nudge point", target: \.ring) { doc, f in
            doc.viewState.currentTool = .directSelection
            doc.viewState.selectedPoints = [PointID(shapeID: f.ring, pathIndex: 0, elementIndex: 0)]
            doc.nudgeSelectedObjects(by: CGVector(dx: 2, dy: 0))
        }
    }

    // MARK: Mouse drag

    func testDragKeepsEvenOdd() throws {
        try check("drag ring", target: \.ring) { doc, f in
            select([f.ring], in: doc)
            doc.commitSelectionDrag(delta: CGPoint(x: 12, y: 7))
        }
        try check("drag group", target: \.groupRing) { doc, f in
            select([f.group], in: doc)
            doc.commitSelectionDrag(delta: CGPoint(x: 12, y: 7))
        }
    }

    // MARK: Align

    func testAlignKeepsEvenOdd() throws {
        try check("align ring", target: \.ring) { doc, f in
            select([f.rect, f.ring], in: doc)
            doc.alignSelectedObjectsByOrigin()
        }
        try check("align group", target: \.groupRing) { doc, f in
            select([f.rect, f.group], in: doc)
            doc.alignSelectedObjectsByOrigin()
        }
    }

    // MARK: Transform panel on a group (the ungrouped case is in TransformFieldsUndoTests)

    func testTransformPanelOnGroupKeepsEvenOdd() throws {
        try check("fields group", target: \.groupRing) { doc, f in
            select([f.group], in: doc)
            doc.applyTransformFields(x: 50, y: 50, width: 150, height: 100)
        }
        try check("scale group", target: \.groupRing) { doc, f in
            select([f.group], in: doc)
            doc.scaleSelection(percentX: 150, percentY: 150)
        }
        try check("rotate group", target: \.groupRing) { doc, f in
            select([f.group], in: doc)
            doc.rotateSelection(degrees: 30)
        }
    }

    // MARK: Canvas handles (scale / rotate / reflect / shear call applyTransformToGroup on release)

    func testGroupHandleTransformKeepsEvenOdd() throws {
        try check("handle transform group", undoable: false, target: \.groupRing) { doc, f in
            doc.applyTransformToGroup(groupID: f.group, transform: CGAffineTransform(scaleX: -1, y: 1.5))
        }
    }
}
