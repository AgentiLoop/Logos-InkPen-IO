import XCTest
@testable import logos_inkpen_io

/// Text content and text paint (fill opacity, stroke, letter spacing) survive open → save → open
/// through the plain SVG writer and importer — VectorCraft lists text alongside paths and gradients
/// as round-tripping "through the engine's own SVG writer, property-tested against the importer."
final class SVGTextRoundTripTests: XCTestCase {

    private func open(_ body: String) throws -> VectorDocument {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
        \(body)
        </svg>
        """
        return try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    private func saveAndReopen(_ doc: VectorDocument) throws -> VectorDocument {
        let svg = try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
        return try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    private func texts(_ doc: VectorDocument) -> [VectorShape] {
        doc.snapshot.objects.values.map(\.shape)
            .filter { $0.typography != nil }
            .sorted { $0.bounds.minY < $1.bounds.minY }
    }

    private let paintedText = """
    <text x="20" y="60" font-family="Helvetica" font-size="24" fill="#0000ff" fill-opacity="0.5" \
    stroke="#ff0000" stroke-width="2" stroke-opacity="0.25" letter-spacing="3">Hi</text>
    """

    private func assertPaint(_ doc: VectorDocument, file: StaticString = #filePath, line: UInt = #line) {
        let found = texts(doc)
        XCTAssertEqual(found.count, 1, file: file, line: line)
        XCTAssertEqual(found.first?.textContent, "Hi", "letter-spaced text stays on one line", file: file, line: line)
        guard let t = found.first?.typography else { return }
        XCTAssertEqual(t.fillOpacity, 0.5, accuracy: 1e-9, file: file, line: line)
        XCTAssertTrue(t.hasStroke, "stroke is imported", file: file, line: line)
        XCTAssertNotEqual(t.strokeColor, t.fillColor, "stroke color is the stroke attribute, not the fill", file: file, line: line)
        XCTAssertEqual(t.strokeWidth, 2, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(t.strokeOpacity, 0.25, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(t.letterSpacing, 3, accuracy: 1e-9, file: file, line: line)
    }

    func testTextPaintIsImported() throws {
        assertPaint(try open(paintedText))
    }

    func testTextPaintSurvivesPlainSVGRoundTrip() throws {
        assertPaint(try saveAndReopen(try open(paintedText)))
    }

    func testTextPaintInStyleIsImportedAndClamped() throws {
        let doc = try open("""
        <text x="20" y="60" font-size="24" style="fill:#000000;fill-opacity:1.6;stroke:none;stroke-width:4">Hi</text>
        """)
        guard let t = texts(doc).first?.typography else { return XCTFail("no text imported") }
        XCTAssertEqual(t.fillOpacity, 1, accuracy: 1e-9)
        XCTAssertFalse(t.hasStroke, "stroke=\"none\" adds no stroke")
    }

    func testUnpaintedTextKeepsDefaults() throws {
        let doc = try saveAndReopen(try open("<text x=\"20\" y=\"60\" font-size=\"24\" fill=\"#000000\">Hi</text>"))
        guard let t = texts(doc).first?.typography else { return XCTFail("no text imported") }
        XCTAssertEqual(t.fillOpacity, 1)
        XCTAssertFalse(t.hasStroke)
        XCTAssertEqual(t.letterSpacing, 0)
    }

    func testTextContentWithXMLCharactersSurvivesRoundTrip() throws {
        let doc = try saveAndReopen(try open("<text x=\"20\" y=\"60\" font-size=\"24\">A &amp; B &lt;C&gt; \"q\"</text>"))
        XCTAssertEqual(texts(doc).map(\.textContent), ["A & B <C> \"q\""])
    }
}
