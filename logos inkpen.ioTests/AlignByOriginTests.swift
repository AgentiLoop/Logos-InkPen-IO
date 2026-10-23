import XCTest
@testable import logos_inkpen_io

/// Align X / Y / X+Y by Anchor Points: every selected object's transform origin (center by default)
/// moves onto the key object's origin. The key object never moves, the anchor mode picks the key
/// (a locked object always wins), groups move with their members, and ⌘Z gives back the old shapes.
final class AlignByOriginTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect id="a" x="10" y="10" width="20" height="20" fill="red"/>
      <rect id="b" x="100" y="50" width="40" height="40" fill="green"/>
      <rect id="c" x="200" y="100" width="10" height="10" fill="blue"/>
      <g id="g">
        <rect x="300" y="10" width="20" height="20" fill="black"/>
        <circle cx="360" cy="20" r="10" fill="orange"/>
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

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
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

    /// a, b, c (plain rectangles) and g (group), in that order.
    private func fixture(_ doc: VectorDocument) throws -> (a: UUID, b: UUID, c: UUID, g: UUID) {
        let ids = topLevelIDs(doc)
        let plain = ids.filter { doc.snapshot.objects[$0]?.shape.isGroup == false }
        let group = try XCTUnwrap(ids.first { doc.snapshot.objects[$0]?.shape.isGroup == true })
        XCTAssertEqual(plain.count, 3)
        return (plain[0], plain[1], plain[2], group)
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    /// Bounds on the canvas; a group's bounds are the union of its members.
    private func box(_ doc: VectorDocument, _ id: UUID) -> CGRect {
        guard let s = doc.snapshot.objects[id]?.shape else { return .null }
        if s.isGroup && !s.memberIDs.isEmpty {
            return s.memberIDs.map { box(doc, $0) }.reduce(CGRect.null) { $0.union($1) }
        }
        return s.bounds.applying(s.transform)
    }

    private func center(_ doc: VectorDocument, _ id: UUID) -> CGPoint {
        let r = box(doc, id)
        return CGPoint(x: r.midX, y: r.midY)
    }

    private func assertPoint(_ p: CGPoint, _ q: CGPoint, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.x, q.x, accuracy: 0.001, "\(message) x", file: file, line: line)
        XCTAssertEqual(p.y, q.y, accuracy: 0.001, "\(message) y", file: file, line: line)
    }

    private func assertRestored(_ doc: VectorDocument, _ before: [UUID: VectorShape], _ message: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(shapes(doc).keys), Set(before.keys), "\(message): object set differs", file: file, line: line)
        for (id, shape) in before {
            XCTAssertEqual(shapes(doc)[id], shape, "\(message): \(shape.name) differs", file: file, line: line)
        }
    }

    func testFixtureShape() throws {
        let doc = try open()
        let f = try fixture(doc)
        assertPoint(center(doc, f.a), CGPoint(x: 20, y: 20), "a")
        assertPoint(center(doc, f.b), CGPoint(x: 120, y: 70), "b")
        assertPoint(center(doc, f.c), CGPoint(x: 205, y: 105), "c")
        assertPoint(center(doc, f.g), CGPoint(x: 335, y: 20), "g")
        XCTAssertEqual(doc.snapshot.objects[f.g]?.shape.memberIDs.count, 2)
    }

    // MARK: Axes

    func testAlignBothMovesCentersOntoFirstSelected() throws {
        let doc = try open()
        let f = try fixture(doc)
        let keyBefore = try XCTUnwrap(shapes(doc)[f.b])
        let sizeA = box(doc, f.a).size, sizeC = box(doc, f.c).size

        select([f.b, f.a, f.c], in: doc)
        doc.alignSelectedObjectsByOrigin()

        XCTAssertEqual(shapes(doc)[f.b], keyBefore, "The key object must not move")
        assertPoint(center(doc, f.a), CGPoint(x: 120, y: 70), "a")
        assertPoint(center(doc, f.c), CGPoint(x: 120, y: 70), "c")
        XCTAssertEqual(box(doc, f.a).size, sizeA, "Align must move, not resize")
        XCTAssertEqual(box(doc, f.c).size, sizeC, "Align must move, not resize")
    }

    func testAlignXOnlyKeepsVerticalPosition() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.b, f.a, f.c], in: doc)
        doc.alignSelectedObjectsByOriginX()
        assertPoint(center(doc, f.a), CGPoint(x: 120, y: 20), "a")
        assertPoint(center(doc, f.c), CGPoint(x: 120, y: 105), "c")
        assertPoint(center(doc, f.b), CGPoint(x: 120, y: 70), "key b")
    }

    func testAlignYOnlyKeepsHorizontalPosition() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.b, f.a, f.c], in: doc)
        doc.alignSelectedObjectsByOriginY()
        assertPoint(center(doc, f.a), CGPoint(x: 20, y: 70), "a")
        assertPoint(center(doc, f.c), CGPoint(x: 205, y: 70), "c")
        assertPoint(center(doc, f.b), CGPoint(x: 120, y: 70), "key b")
    }

    func testAlignLeavesUnselectedObjectsAlone() throws {
        let doc = try open()
        let f = try fixture(doc)
        let before = shapes(doc)
        select([f.a, f.b], in: doc)
        doc.alignSelectedObjectsByOrigin()
        XCTAssertEqual(shapes(doc)[f.c], before[f.c])
        XCTAssertEqual(shapes(doc)[f.g], before[f.g])
        for m in before[f.g]?.memberIDs ?? [] { XCTAssertEqual(shapes(doc)[m], before[m]) }
    }

    func testAlignUsesTheKeyObjectsTransformOrigin() throws {
        let doc = try open()
        let f = try fixture(doc)
        doc.updateShapeByID(f.b) { $0.transformOrigin = .topLeft }
        select([f.b, f.a], in: doc)
        doc.alignSelectedObjectsByOrigin()
        // b's top-left (100, 50) is the target; a aligns its own (center) origin there.
        assertPoint(center(doc, f.a), CGPoint(x: 100, y: 50), "a")
    }

    // MARK: Anchor (key object) choice

    func testAnchorModes() throws {
        let cases: [(AlignmentAnchorMode, String, CGPoint)] = [
            (.firstSelected, "a", CGPoint(x: 20, y: 20)),
            (.lastSelected, "c", CGPoint(x: 205, y: 105)),
            (.largestArea, "b", CGPoint(x: 120, y: 70)),
            (.smallestArea, "c", CGPoint(x: 205, y: 105)),
        ]
        for (mode, keyName, target) in cases {
            ApplicationSettings.shared.alignmentAnchorMode = mode
            let doc = try open()
            let f = try fixture(doc)
            let key = ["a": f.a, "b": f.b, "c": f.c][keyName]!
            let keyBefore = shapes(doc)[key]

            select([f.a, f.b, f.c], in: doc)
            doc.alignSelectedObjectsByOrigin()

            XCTAssertEqual(shapes(doc)[key], keyBefore, "\(mode): key object \(keyName) moved")
            for id in [f.a, f.b, f.c] { assertPoint(center(doc, id), target, "\(mode)") }
        }
    }

    func testLockedObjectIsAlwaysTheKey() throws {
        ApplicationSettings.shared.alignmentAnchorMode = .largestArea
        let doc = try open()
        let f = try fixture(doc)
        select([f.c], in: doc)
        doc.lockSelectedObjects()
        let lockedBefore = shapes(doc)[f.c]

        select([f.a, f.b, f.c], in: doc)
        doc.alignSelectedObjectsByOrigin()

        XCTAssertEqual(shapes(doc)[f.c], lockedBefore, "A locked object must never move")
        assertPoint(center(doc, f.a), CGPoint(x: 205, y: 105), "a")
        assertPoint(center(doc, f.b), CGPoint(x: 205, y: 105), "b")
    }

    // MARK: Groups

    func testGroupMovesWithItsMembers() throws {
        let doc = try open()
        let f = try fixture(doc)
        let members = try XCTUnwrap(doc.snapshot.objects[f.g]?.shape.memberIDs)
        let memberSizes = members.map { box(doc, $0).size }
        let gap = center(doc, members[1]).x - center(doc, members[0]).x

        select([f.a, f.g], in: doc)
        doc.alignSelectedObjectsByOrigin()

        assertPoint(center(doc, f.g), CGPoint(x: 20, y: 20), "group")
        XCTAssertEqual(members.map { box(doc, $0).size }, memberSizes, "Members must not resize")
        XCTAssertEqual(center(doc, members[1]).x - center(doc, members[0]).x, gap, accuracy: 0.001,
                       "Members must keep their spacing")
        let groupBounds = try XCTUnwrap(doc.snapshot.objects[f.g]?.shape.groupBounds)
        assertPoint(CGPoint(x: groupBounds.midX, y: groupBounds.midY), CGPoint(x: 20, y: 20),
                    "Stored group bounds must follow the members")
    }

    func testGroupAsKeyStaysInPlace() throws {
        let doc = try open()
        let f = try fixture(doc)
        let before = shapes(doc)
        select([f.g, f.a], in: doc)
        doc.alignSelectedObjectsByOrigin()
        for id in [f.g] + (before[f.g]?.memberIDs ?? []) {
            XCTAssertEqual(shapes(doc)[id], before[id], "The key group or a member moved")
        }
        assertPoint(center(doc, f.a), CGPoint(x: 335, y: 20), "a")
    }

    // MARK: Undo

    func testUndoRedoAlign() throws {
        let doc = try open()
        let f = try fixture(doc)
        let before = shapes(doc)

        select([f.b, f.a, f.c, f.g], in: doc)
        doc.alignSelectedObjectsByOrigin()
        let aligned = shapes(doc)
        XCTAssertNotEqual(aligned, before)

        doc.undo()
        assertRestored(doc, before, "Undo align")
        doc.redo()
        assertRestored(doc, aligned, "Redo align")
        doc.undo()
        assertRestored(doc, before, "Undo after redo")
    }

    func testAligningAlreadyAlignedObjectsAddsNoUndoStep() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.b, f.a], in: doc)
        doc.alignSelectedObjectsByOrigin()
        let aligned = shapes(doc)

        doc.alignSelectedObjectsByOrigin()
        doc.alignSelectedObjectsByOriginX()
        doc.alignSelectedObjectsByOriginY()
        assertRestored(doc, aligned, "Repeated align")

        // One ⌘Z must undo the one align that moved something.
        doc.undo()
        assertPoint(center(doc, f.a), CGPoint(x: 20, y: 20), "a after one undo")
    }

    func testAlignNeedsTwoObjects() throws {
        let doc = try open()
        let f = try fixture(doc)
        let before = shapes(doc)
        let couldUndo = doc.commandManager.canUndo
        select([f.a], in: doc)
        doc.alignSelectedObjectsByOrigin()
        doc.alignSelectedObjectsByOriginX()
        doc.alignSelectedObjectsByOriginY()
        assertRestored(doc, before, "Align with one object")
        XCTAssertEqual(doc.commandManager.canUndo, couldUndo)
    }
}
