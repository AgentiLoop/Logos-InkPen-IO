import XCTest
@testable import logos_inkpen_io

/// Open an SVG → save it the way the app saves (.svg with embedded inkpen data) → open it again
/// must give back the same document. A save that changes or loses objects corrupts the user's file.
final class SVGRoundTripTests: XCTestCase {

    private let artwork = """
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="300">
      <defs>
        <symbol id="dot"><g><circle cx="5" cy="5" r="5" fill="red"/><rect x="0" y="12" width="4" height="4"/></g></symbol>
      </defs>
      <g id="left">
        <rect x="10" y="10" width="20" height="20" fill="red"/>
        <circle cx="60" cy="20" r="10" fill="green"/>
      </g>
      <line x1="0" y1="100" x2="300" y2="100" stroke="black"/>
      <path d="M 10 150 L 60 150 L 35 190 Z" fill="blue"/>
      <rect x="100" y="200" width="30" height="30" transform="translate(50,10)" fill="purple"/>
      <use xlink:href="#dot" x="200" y="20"/>
      <use xlink:href="#dot" x="250" y="20"/>
    </svg>
    """

    /// Same call InkpenDocument.fileWrapper makes for .svg.
    private func save(_ doc: VectorDocument) throws -> Data {
        let svg = try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: true)
        return Data(svg.utf8)
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func assertIntegrity(_ doc: VectorDocument, file: StaticString = #filePath, line: UInt = #line) {
        let ids = doc.snapshot.objects
        for layer in doc.snapshot.layers {
            for id in layer.objectIDs {
                XCTAssertNotNil(ids[id], "Layer \(layer.name) points at a missing object", file: file, line: line)
            }
        }
        for (_, obj) in ids {
            for member in obj.shape.memberIDs {
                XCTAssertNotNil(ids[member], "\(obj.shape.name) points at a missing member", file: file, line: line)
            }
        }
    }

    func testSaveThenReopenGivesBackTheSameDocument() throws {
        let opened = try FileOperations.importFromSVGData(Data(artwork.utf8))
        XCTAssertGreaterThan(opened.snapshot.objects.count, 5)
        assertIntegrity(opened)

        let reopened = try FileOperations.importFromSVGData(try save(opened))
        assertIntegrity(reopened)
        XCTAssertEqual(shapes(reopened), shapes(opened), "Reopening a saved file must restore every object exactly")
        XCTAssertEqual(reopened.snapshot.layers.map(\.objectIDs), opened.snapshot.layers.map(\.objectIDs))
    }

    func testRepeatedSavesAreStable() throws {
        var doc = try FileOperations.importFromSVGData(Data(artwork.utf8))
        let first = shapes(doc)
        for _ in 0..<3 {
            doc = try FileOperations.importFromSVGData(try save(doc))
        }
        XCTAssertEqual(shapes(doc), first, "Each save/reopen must not drift or drop objects")
    }

    func testEditSaveReopenKeepsOnlyTheEdit() throws {
        let doc = try FileOperations.importFromSVGData(Data(artwork.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        let before = shapes(doc)
        guard let target = doc.snapshot.layers.flatMap(\.objectIDs)
            .compactMap({ doc.snapshot.objects[$0]?.shape }).first(where: { !$0.isGroup }) else { return XCTFail("no shape") }

        doc.viewState.selectedObjectIDs = [target.id]
        doc.nudgeSelectedObjects(by: CGVector(dx: 6, dy: 0))
        let edited = try XCTUnwrap(doc.snapshot.objects[target.id]?.shape)
        XCTAssertEqual(edited.bounds.minX, target.bounds.minX + 6, accuracy: 0.001, "\(target.name) did not move")

        let reopened = try FileOperations.importFromSVGData(try save(doc))
        assertIntegrity(reopened)
        let after = shapes(reopened)
        XCTAssertEqual(Set(after.keys), Set(before.keys))
        for (id, shape) in after where id != target.id {
            XCTAssertEqual(shape, before[id], "\(shape.name) changed although only \(target.name) was edited")
        }
        let moved = try XCTUnwrap(after[target.id])
        XCTAssertEqual(moved.bounds.minX, target.bounds.minX + 6, accuracy: 0.001)
    }

    func testPlainSVGExportKeepsGeometry() throws {
        // Without the embedded inkpen data other apps (and a reopen that ignores it) see only the SVG
        // geometry. Every visible top-level object must survive with the same bounds.
        let opened = try FileOperations.importFromSVGData(Data(artwork.utf8))
        let svg = try SVGExporter.shared.exportToSVG(opened, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
        let reopened = try FileOperations.importFromSVGData(Data(svg.utf8))

        func leafBounds(_ doc: VectorDocument) -> [CGRect] {
            doc.snapshot.objects.values.map(\.shape).filter { !$0.isGroup }.map(\.bounds)
                .sorted { ($0.minX, $0.minY, $0.width) < ($1.minX, $1.minY, $1.width) }
        }
        let a = leafBounds(opened), b = leafBounds(reopened)
        XCTAssertEqual(a.count, b.count, "Plain SVG export dropped or duplicated shapes")
        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.minX, y.minX, accuracy: 0.01)
            XCTAssertEqual(x.minY, y.minY, accuracy: 0.01)
            XCTAssertEqual(x.width, y.width, accuracy: 0.01)
            XCTAssertEqual(x.height, y.height, accuracy: 0.01)
        }
    }
}
