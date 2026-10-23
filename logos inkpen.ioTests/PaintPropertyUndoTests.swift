import XCTest
@testable import logos_inkpen_io

/// Stroke & Fill panel edits (stroke width / opacity, fill opacity, stroke placement, join, cap,
/// miter limit, apply fill): each edit is one undo step, reaches the members of a selected group,
/// leaves unselected objects alone, and ⌘Z gives back exactly the old shapes. Setting a value the
/// selection already has adds no undo step.
final class PaintPropertyUndoTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect id="a" x="10" y="10" width="40" height="40" fill="red" stroke="black" stroke-width="2"/>
      <rect id="b" x="100" y="10" width="40" height="40" fill="green"/>
      <g id="g">
        <rect x="200" y="10" width="20" height="20" fill="blue" stroke="black" stroke-width="1"/>
        <rect x="250" y="10" width="20" height="20" fill="orange" stroke="black" stroke-width="3"/>
      </g>
    </svg>
    """

    private struct Op {
        let name: String
        let run: (VectorDocument) -> Void
        /// The edited property of a leaf shape, as text so every type compares the same way.
        let read: (VectorShape) -> String?
        let expected: String
    }

    private let ops: [Op] = [
        Op(name: "stroke width",
           run: { PaintSelectionOperations.handleStrokeWidthEditingComplete(7, document: $0) },
           read: { $0.strokeStyle.map { "\($0.width)" } }, expected: "7.0"),
        Op(name: "fill opacity",
           run: { PaintSelectionOperations.handleFillOpacityEditingComplete(0.4, document: $0) },
           read: { $0.fillStyle.map { "\($0.opacity)" } }, expected: "0.4"),
        Op(name: "stroke opacity",
           run: { PaintSelectionOperations.handleStrokeOpacityEditingComplete(0.3, document: $0) },
           read: { $0.strokeStyle.map { "\($0.opacity)" } }, expected: "0.3"),
        Op(name: "stroke placement",
           run: { PaintSelectionOperations.updateStrokePlacement(.inside, document: $0) },
           read: { $0.strokeStyle.map { $0.placement.rawValue } }, expected: StrokePlacement.inside.rawValue),
        Op(name: "line join",
           run: { PaintSelectionOperations.updateStrokeLineJoin(.bevel, document: $0) },
           read: { $0.strokeStyle.map { "\($0.lineJoin.cgLineJoin.rawValue)" } }, expected: "\(CGLineJoin.bevel.rawValue)"),
        Op(name: "line cap",
           run: { PaintSelectionOperations.updateStrokeLineCap(.round, document: $0) },
           read: { $0.strokeStyle.map { "\($0.lineCap.cgLineCap.rawValue)" } }, expected: "\(CGLineCap.round.rawValue)"),
        Op(name: "miter limit",
           run: { PaintSelectionOperations.updateStrokeMiterLimit(3, document: $0) },
           read: { $0.strokeStyle.map { "\($0.miterLimit)" } }, expected: "3.0"),
        Op(name: "apply fill",
           run: { PaintSelectionOperations.applyFillToSelectedShapes(fillColor: .black, fillOpacity: 0.5, document: $0) },
           read: { $0.fillStyle.map { "\($0.color == .black)/\($0.opacity)" } }, expected: "true/0.5"),
    ]

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    /// a (stroked rect), b (rect without stroke), g (group) and g's members.
    private func fixture(_ doc: VectorDocument) throws -> (a: UUID, b: UUID, g: UUID, members: [UUID]) {
        let ids = doc.snapshot.layers.enumerated()
            .filter { $0.offset > 2 }
            .flatMap(\.element.objectIDs)
            .filter { id in
                guard let s = doc.snapshot.objects[id]?.shape else { return false }
                return s.name != "Canvas Background" && s.name != "Pasteboard Background"
            }
        let plain = ids.filter { doc.snapshot.objects[$0]?.shape.isGroup == false }
        let group = try XCTUnwrap(ids.first { doc.snapshot.objects[$0]?.shape.isGroup == true })
        XCTAssertEqual(plain.count, 2)
        let members = try XCTUnwrap(doc.snapshot.objects[group]?.shape.memberIDs)
        XCTAssertEqual(members.count, 2)
        XCTAssertNotNil(doc.snapshot.objects[plain[0]]?.shape.strokeStyle)
        return (plain[0], plain[1], group, members)
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func changedIDs(_ a: [UUID: VectorShape], _ b: [UUID: VectorShape]) -> Set<UUID> {
        Set(a.keys).union(b.keys).filter { a[$0] != b[$0] }
    }

    /// Runs `op` on the selection and checks: one undo step, `edited` leaves read the new value,
    /// only `allowed` objects changed, undo restores exactly, redo restores the edited state.
    private func check(_ op: Op, select ids: [UUID], edited: [UUID], allowed: Set<UUID>,
                       in doc: VectorDocument, file: StaticString = #filePath, line: UInt = #line) {
        select(ids, in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        op.run(doc)
        let after = shapes(doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps + 1, "\(op.name): undo steps", file: file, line: line)
        for id in edited {
            XCTAssertEqual(after[id].flatMap(op.read), op.expected, "\(op.name): new value", file: file, line: line)
        }
        let changed = changedIDs(before, after)
        XCTAssertTrue(changed.isSubset(of: allowed), "\(op.name): changed unselected objects", file: file, line: line)
        doc.commandManager.undo()
        XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(op.name): undo did not restore", file: file, line: line)
        doc.commandManager.redo()
        XCTAssertEqual(changedIDs(after, shapes(doc)), [], "\(op.name): redo did not restore", file: file, line: line)
    }

    func testEditOnShapeIsOneUndoStepAndUndoesExactly() throws {
        for op in ops {
            let doc = try open()
            let f = try fixture(doc)
            check(op, select: [f.a], edited: [f.a], allowed: [f.a], in: doc)
        }
    }

    func testEditOnGroupReachesMembersAndUndoesExactly() throws {
        for op in ops {
            let doc = try open()
            let f = try fixture(doc)
            check(op, select: [f.g], edited: f.members, allowed: Set(f.members + [f.g]), in: doc)
        }
    }

    func testEditOnShapeWithoutStrokeUndoesExactly() throws {
        for op in ops {
            let doc = try open()
            let f = try fixture(doc)
            XCTAssertNil(doc.snapshot.objects[f.b]?.shape.strokeStyle)
            select([f.b], in: doc)
            let before = shapes(doc)
            op.run(doc)
            XCTAssertTrue(changedIDs(before, shapes(doc)).isSubset(of: [f.b]), "\(op.name): changed other objects")
            doc.commandManager.undo()
            XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(op.name): undo did not restore")
        }
    }

    func testRepeatingTheSameValueAddsNoUndoStep() throws {
        for op in ops {
            let doc = try open()
            let f = try fixture(doc)
            select([f.a, f.g], in: doc)
            let before = shapes(doc)
            op.run(doc)
            let steps = doc.commandManager.undoCount
            op.run(doc)
            XCTAssertEqual(doc.commandManager.undoCount, steps, "\(op.name): repeat added an undo step")
            doc.commandManager.undo()
            XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(op.name): one undo did not restore")
        }
    }

    func testEditWithNothingSelectedAddsNoUndoStep() throws {
        for op in ops {
            let doc = try open()
            select([], in: doc)
            let before = shapes(doc)
            let steps = doc.commandManager.undoCount
            op.run(doc)
            XCTAssertEqual(doc.commandManager.undoCount, steps, "\(op.name): undo step with empty selection")
            XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(op.name): changed objects with empty selection")
        }
    }
}
