import XCTest
@testable import logos_inkpen_io

/// Transform panel fields (X/Y/W/H, Scale %, Rotate °) as the toolbar runs them
/// (`VectorDocument.applyTransformFields`, `scaleSelection`, `rotateSelection`): the selection lands
/// where the fields say with the reference point fixed, groups move with all their members, nothing
/// else changes, it is one undo step, ⌘Z restores exactly, and typing the current values adds no step.
/// (VectorCraft's Transform panel tests check the same: fixed reference point, rotate 30° then undo.)
final class TransformFieldsUndoTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect x="10" y="10" width="40" height="40" fill="red"/>
      <rect x="100" y="10" width="40" height="40" fill="green"/>
      <g>
        <rect x="200" y="10" width="20" height="20" fill="blue"/>
        <rect x="250" y="40" width="20" height="20" fill="orange"/>
      </g>
    </svg>
    """

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        doc.viewState.transformOrigin = .topLeft
        doc.settings.pageOrigin = .zero
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func changedIDs(_ a: [UUID: VectorShape], _ b: [UUID: VectorShape]) -> Set<UUID> {
        Set(a.keys).union(b.keys).filter { a[$0] != b[$0] }
    }

    /// a, b (plain rects), g (group) and g's two members.
    private func fixture(_ doc: VectorDocument) throws -> (a: UUID, b: UUID, g: UUID, members: [UUID]) {
        let ids = doc.snapshot.layers.enumerated()
            .filter { $0.offset > 2 }
            .flatMap(\.element.objectIDs)
            .filter { id in
                guard let s = doc.snapshot.objects[id]?.shape else { return false }
                return s.name != "Canvas Background" && s.name != "Pasteboard Background"
            }
        let plain = ids.filter { doc.snapshot.objects[$0]?.shape.isGroup == false }
        XCTAssertEqual(plain.count, 2)
        let g = try XCTUnwrap(ids.first { doc.snapshot.objects[$0]?.shape.isGroup == true })
        let members = try XCTUnwrap(doc.snapshot.objects[g]?.shape.memberIDs)
        XCTAssertEqual(members.count, 2)
        return (plain[0], plain[1], g, members)
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func bounds(_ id: UUID, _ doc: VectorDocument) -> CGRect {
        doc.snapshot.objects[id]?.shape.bounds ?? .null
    }

    private func assertRect(_ r: CGRect, _ e: CGRect, _ msg: String, file: StaticString = #filePath, line: UInt = #line) {
        let ok = abs(r.minX - e.minX) < 0.01 && abs(r.minY - e.minY) < 0.01
            && abs(r.width - e.width) < 0.01 && abs(r.height - e.height) < 0.01
        XCTAssertTrue(ok, "\(msg): \(r) != \(e)", file: file, line: line)
    }

    /// Runs `op` on `ids` and checks: one undo step, only `allowed` change, undo restores exactly, redo too.
    private func check(_ name: String, select ids: [UUID], allowed: Set<UUID>, in doc: VectorDocument,
                       file: StaticString = #filePath, line: UInt = #line,
                       _ op: () -> Void, verify: () -> Void) {
        select(ids, in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        op()
        let after = shapes(doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps + 1, "\(name): undo steps", file: file, line: line)
        XCTAssertFalse(changedIDs(before, after).isEmpty, "\(name): nothing changed", file: file, line: line)
        XCTAssertTrue(changedIDs(before, after).isSubset(of: allowed),
                      "\(name): changed unselected objects", file: file, line: line)
        verify()
        doc.commandManager.undo()
        XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(name): undo did not restore", file: file, line: line)
        doc.commandManager.redo()
        XCTAssertEqual(changedIDs(after, shapes(doc)), [], "\(name): redo did not restore", file: file, line: line)
    }

    // MARK: X / Y / W / H

    func testPositionAndSizeFieldsOnShape() throws {
        let doc = try open()
        let f = try fixture(doc)
        assertRect(bounds(f.a, doc), CGRect(x: 10, y: 10, width: 40, height: 40), "fixture")
        check("move", select: [f.a], allowed: [f.a], in: doc, {
            doc.applyTransformFields(x: 60, y: 80, width: 40, height: 40)
        }, verify: {
            assertRect(bounds(f.a, doc), CGRect(x: 60, y: 80, width: 40, height: 40), "moved")
        })
        // Bottom-right reference point stays put while the size changes.
        doc.viewState.transformOrigin = .bottomRight
        check("resize", select: [f.a], allowed: [f.a], in: doc, {
            doc.applyTransformFields(x: 100, y: 120, width: 80, height: 20)
        }, verify: {
            assertRect(bounds(f.a, doc), CGRect(x: 20, y: 100, width: 80, height: 20), "resized")
        })
    }

    func testPositionAndSizeFieldsOnGroupMoveItsMembers() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.g], in: doc)
        assertRect(try XCTUnwrap(doc.transformFieldSelectionBounds()), CGRect(x: 200, y: 10, width: 70, height: 50), "fixture")
        check("move group", select: [f.g], allowed: Set([f.g] + f.members), in: doc, {
            doc.applyTransformFields(x: 0, y: 100, width: 70, height: 50)
        }, verify: {
            assertRect(bounds(f.members[0], doc), CGRect(x: 0, y: 100, width: 20, height: 20), "member 1")
            assertRect(bounds(f.members[1], doc), CGRect(x: 50, y: 130, width: 20, height: 20), "member 2")
            assertRect(doc.transformFieldSelectionBounds() ?? .null, CGRect(x: 0, y: 100, width: 70, height: 50), "group")
        })
        check("resize group", select: [f.g], allowed: Set([f.g] + f.members), in: doc, {
            doc.applyTransformFields(x: 200, y: 10, width: 140, height: 100)
        }, verify: {
            assertRect(bounds(f.members[0], doc), CGRect(x: 200, y: 10, width: 40, height: 40), "member 1")
            assertRect(bounds(f.members[1], doc), CGRect(x: 300, y: 70, width: 40, height: 40), "member 2")
        })
    }

    func testPositionFieldsOnSeveralObjectsMoveThemTogether() throws {
        let doc = try open()
        let f = try fixture(doc)
        check("move several", select: [f.a, f.g], allowed: Set([f.a, f.g] + f.members), in: doc, {
            doc.applyTransformFields(x: 20, y: 20, width: 260, height: 50)
        }, verify: {
            assertRect(bounds(f.a, doc), CGRect(x: 20, y: 20, width: 40, height: 40), "a")
            assertRect(bounds(f.members[0], doc), CGRect(x: 210, y: 20, width: 20, height: 20), "member 1")
        })
    }

    func testCurrentFieldValuesAddNoUndoStep() throws {
        let doc = try open()
        let f = try fixture(doc)
        for ids in [[f.a], [f.g], [f.a, f.b, f.g]] {
            select(ids, in: doc)
            let r = try XCTUnwrap(doc.transformFieldSelectionBounds())
            let before = shapes(doc)
            let steps = doc.commandManager.undoCount
            doc.applyTransformFields(x: r.minX, y: r.minY, width: r.width, height: r.height)
            XCTAssertEqual(doc.commandManager.undoCount, steps, "\(ids.count) selected: empty undo step")
            XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(ids.count) selected: shapes changed")
        }
    }

    func testFieldsScaleAndRotateKeepEvenOddFillAndClosedPath() throws {
        let ring = """
        <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
          <path fill-rule="evenodd" fill="black" d="M10 10 L90 10 L90 90 L10 90 Z M30 30 L70 30 L70 70 L30 70 Z"/>
        </svg>
        """
        for op in ["fields", "scale", "rotate"] {
            let doc = try FileOperations.importFromSVGData(Data(ring.utf8))
            doc.viewState.currentTool = .selection
            doc.viewState.transformOrigin = .center
            doc.settings.pageOrigin = .zero
            let id = try XCTUnwrap(doc.snapshot.layers.enumerated().filter { $0.offset > 2 }
                .flatMap(\.element.objectIDs).first { doc.snapshot.objects[$0]?.shape.path.elements.isEmpty == false })
            let path = try XCTUnwrap(doc.snapshot.objects[id]?.shape.path)
            XCTAssertEqual(path.fillRule, .evenOdd, "fixture")
            select([id], in: doc)
            switch op {
            case "fields": doc.applyTransformFields(x: 60, y: 60, width: 100, height: 100)
            case "scale": doc.scaleSelection(percentX: 150, percentY: 150)
            default: doc.rotateSelection(degrees: 45)
            }
            let after = try XCTUnwrap(doc.snapshot.objects[id]?.shape.path)
            XCTAssertNotEqual(after.elements, path.elements, "\(op): path unchanged")
            XCTAssertEqual(after.fillRule, path.fillRule, "\(op): lost even-odd fill (hole fills in)")
            XCTAssertEqual(after.isClosed, path.isClosed, "\(op): closed flag")
        }
    }

    // MARK: Scale

    func testScaleAroundReferencePoint() throws {
        let doc = try open()
        let f = try fixture(doc)
        doc.viewState.transformOrigin = .center
        check("scale shape", select: [f.a], allowed: [f.a], in: doc, {
            doc.scaleSelection(percentX: 200, percentY: 50)
        }, verify: {
            assertRect(bounds(f.a, doc), CGRect(x: -10, y: 20, width: 80, height: 20), "scaled")
        })
        doc.viewState.transformOrigin = .topLeft
        check("scale group", select: [f.g], allowed: Set([f.g] + f.members), in: doc, {
            doc.scaleSelection(percentX: 200, percentY: 200)
        }, verify: {
            assertRect(bounds(f.members[0], doc), CGRect(x: 200, y: 10, width: 40, height: 40), "member 1")
            assertRect(bounds(f.members[1], doc), CGRect(x: 300, y: 70, width: 40, height: 40), "member 2")
        })
    }

    func testScaleOf100PercentAddsNoUndoStep() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.a, f.g], in: doc)
        let steps = doc.commandManager.undoCount
        doc.scaleSelection(percentX: 100, percentY: 100)
        XCTAssertEqual(doc.commandManager.undoCount, steps)
    }

    // MARK: Rotate

    func testRotateAroundReferencePoint() throws {
        let doc = try open()
        let f = try fixture(doc)
        doc.viewState.transformOrigin = .center
        // 30° like VectorCraft's check: the square's center stays, its box grows to 40·(cos+sin).
        let side = 40 * (cos(CGFloat.pi / 6) + sin(CGFloat.pi / 6))
        check("rotate shape", select: [f.a], allowed: [f.a], in: doc, {
            doc.rotateSelection(degrees: 30)
        }, verify: {
            assertRect(bounds(f.a, doc), CGRect(x: 30 - side / 2, y: 30 - side / 2, width: side, height: side), "rotated")
        })
        check("rotate group", select: [f.g], allowed: Set([f.g] + f.members), in: doc, {
            doc.rotateSelection(degrees: 90)
        }, verify: {
            // Group box 200…270 × 10…60 turns a quarter around its center (235, 35).
            assertRect(doc.transformFieldSelectionBounds() ?? .null, CGRect(x: 210, y: 0, width: 50, height: 70), "group")
            assertRect(bounds(f.members[0], doc), CGRect(x: 240, y: 0, width: 20, height: 20), "member 1")
        })
    }

    func testRotateZeroAddsNoUndoStepAndNothingSelectedDoesNothing() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.a], in: doc)
        let steps = doc.commandManager.undoCount
        doc.rotateSelection(degrees: 0)
        XCTAssertEqual(doc.commandManager.undoCount, steps)
        select([], in: doc)
        let before = shapes(doc)
        doc.rotateSelection(degrees: 45)
        doc.scaleSelection(percentX: 150, percentY: 150)
        doc.applyTransformFields(x: 1, y: 1, width: 5, height: 5)
        XCTAssertEqual(doc.commandManager.undoCount, steps)
        XCTAssertEqual(changedIDs(before, shapes(doc)), [])
    }
}
