import XCTest
@testable import logos_inkpen_io

/// Shape opacity, group opacity and the even-odd fill rule are read on SVG import and written
/// on plain SVG export, so they survive open → save → open (an importer/exporter round trip,
/// the property VectorCraft tests its own SVG writer against).
final class SVGShapeAttributeRoundTripTests: XCTestCase {

    private func open(_ body: String) throws -> VectorDocument {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
        \(body)
        </svg>
        """
        return try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    private func save(_ doc: VectorDocument) throws -> String {
        try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
    }

    /// Non-group, non-image shapes left to right (top level or inside a group).
    private func paths(_ doc: VectorDocument) -> [VectorShape] {
        doc.snapshot.objects.values.map(\.shape)
            .filter { !$0.isGroup && $0.embeddedImageData == nil }
            .sorted { $0.bounds.minX < $1.bounds.minX }
    }

    private func groups(_ doc: VectorDocument) -> [VectorShape] {
        doc.snapshot.objects.values.map(\.shape).filter { $0.isGroup && !$0.isClippingGroup }
    }

    private let twoRects = """
    <path d="M10,10 L50,10 L50,50 L10,50 Z" fill="#ff0000" opacity="0.4"/>
    <path d="M100,10 L140,10 L140,50 L100,50 Z" fill="#00ff00"/>
    """

    func testShapeOpacityAttributeIsImported() throws {
        let doc = try open(twoRects)
        XCTAssertEqual(paths(doc).map(\.opacity), [0.4, 1])
    }

    func testShapeOpacityInStyleIsImportedAndClamped() throws {
        let doc = try open("""
        <path d="M10,10 L50,10 L50,50 L10,50 Z" style="fill:#ff0000;opacity:0.3"/>
        <rect x="100" y="10" width="40" height="40" fill="#00ff00" opacity="1.7"/>
        <circle cx="220" cy="30" r="20" fill="#0000ff" opacity="-1"/>
        """)
        XCTAssertEqual(paths(doc).map(\.opacity), [0.3, 1, 0])
    }

    func testPlainSVGExportKeepsShapeOpacity() throws {
        let svg = try save(try open(twoRects))
        let pathTags = svg.components(separatedBy: "\n").filter { $0.hasPrefix("<path ") }
        XCTAssertEqual(pathTags.count, 2)
        XCTAssertEqual(pathTags.filter { $0.contains(" opacity=\"0.4\"") }.count, 1)
        XCTAssertEqual(pathTags.filter { $0.contains(" opacity=") }.count, 1,
                       "A fully opaque shape adds no opacity attribute")
        XCTAssertEqual(paths(try FileOperations.importFromSVGData(Data(svg.utf8))).map(\.opacity), [0.4, 1])
    }

    func testOpacitySetInAppSurvivesPlainSVGExport() throws {
        let doc = try open(twoRects)
        let id = try XCTUnwrap(paths(doc).last?.id)
        doc.updateShapeOpacityInUnified(id: id, opacity: 0.25)
        let reopened = try FileOperations.importFromSVGData(Data(try save(doc).utf8))
        XCTAssertEqual(paths(reopened).map(\.opacity), [0.4, 0.25])
    }

    func testGroupOpacitySurvivesPlainSVGExport() throws {
        let doc = try open("<g opacity=\"0.5\">\(twoRects)</g>")
        XCTAssertEqual(groups(doc).map(\.opacity), [0.5])
        let svg = try save(doc)
        XCTAssertTrue(svg.contains("<g id=\"group_") && svg.contains("\" opacity=\"0.5\">"),
                      "The group must be written with its opacity")
        let reopened = try FileOperations.importFromSVGData(Data(svg.utf8))
        XCTAssertEqual(groups(reopened).map(\.opacity), [0.5])
        XCTAssertEqual(paths(reopened).map(\.opacity), [0.4, 1], "Member opacity is kept separately from the group's")
    }

    func testEvenOddFillRuleSurvivesPlainSVGExport() throws {
        let doc = try open("""
        <path d="M10,10 L90,10 L90,90 L10,90 Z M30,30 L70,30 L70,70 L30,70 Z" fill="#000000" fill-rule="evenodd"/>
        <path d="M110,10 L190,10 L190,90 L110,90 Z M130,30 L170,30 L170,70 L130,70 Z" fill="#000000"/>
        """)
        XCTAssertEqual(paths(doc).map(\.path.fillRule), [.evenOdd, .winding])
        let svg = try save(doc)
        XCTAssertEqual(svg.components(separatedBy: "fill-rule=\"evenodd\"").count - 1, 1,
                       "Only the even-odd path is written with fill-rule")
        let reopened = try FileOperations.importFromSVGData(Data(svg.utf8))
        XCTAssertEqual(paths(reopened).map(\.path.fillRule), [.evenOdd, .winding])
    }
}
