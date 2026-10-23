import XCTest
@testable import logos_inkpen_io

/// Picking a color in the Color panel / swatches (`VectorDocument.setActiveColor`) for the fill or
/// the stroke: one undo step, reaches every member of a selected group (also nested groups), leaves
/// unselected objects alone, and ⌘Z gives back exactly the old shapes — also when the pick created
/// a stroke the shape didn't have. Picking the color the selection already has adds no undo step.
final class ColorSwatchUndoTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect x="10" y="10" width="40" height="40" fill="red" stroke="black" stroke-width="2"/>
      <rect x="100" y="10" width="40" height="40" fill="green"/>
      <g>
        <rect x="200" y="10" width="20" height="20" fill="blue" stroke="black" stroke-width="1"/>
        <g>
          <rect x="250" y="10" width="20" height="20" fill="orange"/>
          <rect x="300" y="10" width="20" height="20" fill="purple"/>
        </g>
      </g>
    </svg>
    """

    private let picked = VectorColor.rgb(RGBColor(red: 0.2, green: 0.4, blue: 0.6))

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        return doc
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func changedIDs(_ a: [UUID: VectorShape], _ b: [UUID: VectorShape]) -> Set<UUID> {
        Set(a.keys).union(b.keys).filter { a[$0] != b[$0] }
    }

    /// a (stroked rect), b (rect without stroke), g (outer group), the inner group and every leaf in g.
    private func fixture(_ doc: VectorDocument) throws -> (a: UUID, b: UUID, g: UUID, inner: UUID, leaves: [UUID]) {
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
        let inner = try XCTUnwrap(members.first { doc.snapshot.objects[$0]?.shape.isGroup == true })
        let innerMembers = try XCTUnwrap(doc.snapshot.objects[inner]?.shape.memberIDs)
        let leaves = members.filter { $0 != inner } + innerMembers
        XCTAssertEqual(leaves.count, 3)
        XCTAssertNotNil(doc.snapshot.objects[plain[0]]?.shape.strokeStyle)
        XCTAssertNil(doc.snapshot.objects[plain[1]]?.shape.strokeStyle)
        return (plain[0], plain[1], g, inner, leaves)
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func color(_ target: ColorTarget, of shape: VectorShape?) -> VectorColor? {
        target == .fill ? shape?.fillStyle?.color : shape?.strokeStyle?.color
    }

    /// Picks `picked` for `target` and checks: one undo step, `edited` get the color, only `allowed`
    /// change, undo restores exactly, redo restores the edited state.
    private func check(_ target: ColorTarget, select ids: [UUID], edited: [UUID], allowed: Set<UUID>,
                       in doc: VectorDocument, file: StaticString = #filePath, line: UInt = #line) {
        doc.viewState.activeColorTarget = target
        select(ids, in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        doc.setActiveColor(picked)
        let after = shapes(doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps + 1, "\(target): undo steps", file: file, line: line)
        for id in edited {
            XCTAssertEqual(color(target, of: after[id]), picked, "\(target): new color", file: file, line: line)
        }
        XCTAssertTrue(changedIDs(before, after).isSubset(of: allowed), "\(target): changed unselected objects", file: file, line: line)
        doc.commandManager.undo()
        XCTAssertEqual(changedIDs(before, shapes(doc)), [], "\(target): undo did not restore", file: file, line: line)
        doc.commandManager.redo()
        XCTAssertEqual(changedIDs(after, shapes(doc)), [], "\(target): redo did not restore", file: file, line: line)
    }

    func testPickOnShapeIsOneUndoStepAndUndoesExactly() throws {
        for target in [ColorTarget.fill, .stroke] {
            let doc = try open()
            let f = try fixture(doc)
            check(target, select: [f.a], edited: [f.a], allowed: [f.a], in: doc)
        }
    }

    func testPickOnShapeWithoutStrokeUndoesExactly() throws {
        for target in [ColorTarget.fill, .stroke] {
            let doc = try open()
            let f = try fixture(doc)
            check(target, select: [f.b], edited: [f.b], allowed: [f.b], in: doc)
        }
    }

    func testPickOnGroupReachesNestedMembersAndUndoesExactly() throws {
        for target in [ColorTarget.fill, .stroke] {
            let doc = try open()
            let f = try fixture(doc)
            check(target, select: [f.g], edited: f.leaves, allowed: Set(f.leaves + [f.g, f.inner]), in: doc)
        }
    }

    func testPickOnSeveralObjectsIsOneUndoStep() throws {
        for target in [ColorTarget.fill, .stroke] {
            let doc = try open()
            let f = try fixture(doc)
            check(target, select: [f.a, f.b, f.g], edited: [f.a, f.b] + f.leaves,
                  allowed: Set([f.a, f.b, f.g, f.inner] + f.leaves), in: doc)
        }
    }

    func testPickingSameColorAgainAddsNoUndoStep() throws {
        for target in [ColorTarget.fill, .stroke] {
            let doc = try open()
            let f = try fixture(doc)
            doc.viewState.activeColorTarget = target
            select([f.a, f.g], in: doc)
            doc.setActiveColor(picked)
            let steps = doc.commandManager.undoCount
            let before = shapes(doc)
            doc.setActiveColor(picked)
            XCTAssertEqual(doc.commandManager.undoCount, steps, "\(target): repeated pick added an undo step")
            XCTAssertEqual(changedIDs(before, shapes(doc)), [])
        }
    }

    func testPickWithNothingSelectedOnlySetsDefaultColor() throws {
        let doc = try open()
        select([], in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        doc.viewState.activeColorTarget = .fill
        doc.setActiveColor(picked)
        doc.viewState.activeColorTarget = .stroke
        doc.setActiveColor(.black)
        XCTAssertEqual(doc.commandManager.undoCount, steps)
        XCTAssertEqual(changedIDs(before, shapes(doc)), [])
        XCTAssertEqual(doc.defaultFillColor, picked)
        XCTAssertEqual(doc.defaultStrokeColor, .black)
    }
}
