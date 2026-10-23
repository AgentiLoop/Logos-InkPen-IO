import XCTest
@testable import logos_inkpen_io

/// Object > Compound Path > Make / Release must keep the drawing's stacking order, and ⌘Z must
/// give back exactly the objects that were there before (same shapes, same front-to-back order).
final class CompoundPathTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect id="a" x="10" y="10" width="20" height="20" fill="red"/>
      <rect id="b" x="50" y="10" width="20" height="20" fill="green"/>
      <rect id="c" x="90" y="10" width="20" height="20" fill="blue"/>
      <rect id="d" x="130" y="10" width="20" height="20" fill="black"/>
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

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func minX(_ doc: VectorDocument, _ id: UUID) -> CGFloat? {
        doc.snapshot.objects[id]?.shape.bounds.minX
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
        XCTAssertEqual(topLevelIDs(doc).count, 4)
        XCTAssertEqual(topLevelIDs(doc).compactMap { minX(doc, $0) }, [10, 50, 90, 130])
    }

    // MARK: Make

    func testMakeCompoundReplacesSelectionInPlace() throws {
        let doc = try open()
        let ids = topLevelIDs(doc)
        let top = ids[3]
        let topShape = try XCTUnwrap(shapes(doc)[top])

        select(Array(ids.prefix(3)), in: doc)
        doc.makeCompoundPath()

        let after = topLevelIDs(doc)
        XCTAssertEqual(after.count, 2)
        XCTAssertEqual(after.last, top, "Compound path must stay below the unselected shape that was on top")
        let compoundID = after[0]
        let compound = try XCTUnwrap(doc.snapshot.objects[compoundID]?.shape)
        XCTAssertTrue(compound.isTrueCompoundPath)
        XCTAssertEqual(compound.path.cgPath.boundingBoxOfPath, CGRect(x: 10, y: 10, width: 100, height: 20))
        XCTAssertEqual(doc.viewState.selectedObjectIDs, [compoundID])
        XCTAssertEqual(doc.viewState.orderedSelectedObjectIDs, [compoundID])
        XCTAssertEqual(shapes(doc)[top], topShape, "Make Compound changed an unselected shape")
        for id in ids.prefix(3) { XCTAssertNil(doc.snapshot.objects[id]) }
    }

    func testUndoMakeCompoundRestoresStackingOrder() throws {
        // The selection is a Set; repeat with fresh UUIDs so an order that only
        // happens to be right for one hash seed can't pass.
        for run in 0..<8 {
            let doc = try open()
            let before = shapes(doc), order = layerOrder(doc)
            let ids = topLevelIDs(doc)

            select(Array(ids.prefix(3)), in: doc)
            doc.makeCompoundPath()
            XCTAssertEqual(topLevelIDs(doc).count, 2)

            doc.undo()
            assertRestored(doc, before, order, "Undo make compound (run \(run))")

            doc.redo()
            XCTAssertEqual(topLevelIDs(doc).count, 2, "Redo make compound (run \(run))")
            doc.undo()
            assertRestored(doc, before, order, "Undo after redo (run \(run))")
        }
    }

    func testMakeCompoundNeedsTwoObjects() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let couldUndo = doc.commandManager.canUndo
        select([topLevelIDs(doc)[0]], in: doc)
        doc.makeCompoundPath()
        assertRestored(doc, before, order, "Make compound with one object")
        XCTAssertEqual(doc.commandManager.canUndo, couldUndo)
    }

    // MARK: Release

    func testReleaseCompoundKeepsSubpathOrder() throws {
        for run in 0..<8 {
            let doc = try open()
            let ids = topLevelIDs(doc)
            let top = ids[3]
            select(Array(ids.prefix(3)), in: doc)
            doc.makeCompoundPath()
            let compoundID = try XCTUnwrap(doc.viewState.selectedObjectIDs.first)
            let compound = try XCTUnwrap(doc.snapshot.objects[compoundID]?.shape)
            let beforeRelease = shapes(doc), orderBeforeRelease = layerOrder(doc)

            doc.releaseCompoundPath()

            let after = topLevelIDs(doc)
            XCTAssertEqual(after.count, 4, "run \(run)")
            XCTAssertNil(doc.snapshot.objects[compoundID])
            XCTAssertEqual(after.last, top, "Released paths must stay below the shape that was on top (run \(run))")
            let released = Array(after.prefix(3))
            XCTAssertEqual(released.compactMap { minX(doc, $0) }, [10, 50, 90],
                           "Released paths must keep the compound's subpath order (run \(run))")
            for id in released {
                let s = try XCTUnwrap(doc.snapshot.objects[id]?.shape)
                XCTAssertFalse(s.isTrueCompoundPath)
                XCTAssertEqual(s.fillStyle, compound.fillStyle)
                XCTAssertEqual(s.bounds.size, CGSize(width: 20, height: 20))
            }
            XCTAssertEqual(doc.viewState.selectedObjectIDs, Set(released))

            doc.undo()
            assertRestored(doc, beforeRelease, orderBeforeRelease, "Undo release (run \(run))")
            doc.redo()
            XCTAssertEqual(topLevelIDs(doc).prefix(3).compactMap { minX(doc, $0) }, [10, 50, 90],
                           "Redo release must keep subpath order (run \(run))")
        }
    }

    func testReleaseIgnoresPlainShape() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let couldUndo = doc.commandManager.canUndo
        select([topLevelIDs(doc)[1]], in: doc)
        doc.releaseCompoundPath()
        assertRestored(doc, before, order, "Release on a plain rectangle")
        XCTAssertEqual(doc.commandManager.canUndo, couldUndo)
    }
}
