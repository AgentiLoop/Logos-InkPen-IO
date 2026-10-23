import XCTest
import AppKit
@testable import logos_inkpen_io

/// An SVG <image>'s opacity (attribute or style) is read on import and written on export,
/// so a semi-transparent image stays semi-transparent through open → save → open.
final class SVGImageOpacityTests: XCTestCase {

    private func pngBase64() throws -> String {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:])).base64EncodedString()
    }

    /// Opens an SVG with one <image> per entry of `imageAttributes` (extra attributes for that image).
    private func open(_ imageAttributes: [String]) throws -> VectorDocument {
        let png = try pngBase64()
        let images = imageAttributes.enumerated().map { i, extra in
            "<image x=\"\(10 + i * 60)\" y=\"10\" width=\"40\" height=\"40\" \(extra) xlink:href=\"data:image/png;base64,\(png)\"/>"
        }.joined(separator: "\n")
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="300">
        \(images)
        </svg>
        """
        return try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    /// Image opacities, left to right (top level or inside a group).
    private func imageOpacities(_ doc: VectorDocument) -> [Double] {
        doc.snapshot.objects.values.map(\.shape)
            .filter { $0.embeddedImageData != nil }
            .sorted { $0.bounds.minX < $1.bounds.minX }
            .map(\.opacity)
    }

    func testOpacityAttributeIsImported() throws {
        let doc = try open(["opacity=\"0.4\"", ""])
        XCTAssertEqual(imageOpacities(doc), [0.4, 1])
    }

    func testOpacityInStyleIsImported() throws {
        let doc = try open(["style=\"opacity:0.3\""])
        XCTAssertEqual(imageOpacities(doc), [0.3])
    }

    func testOutOfRangeOpacityIsClamped() throws {
        let doc = try open(["opacity=\"1.5\"", "opacity=\"-0.2\""])
        XCTAssertEqual(imageOpacities(doc), [1, 0])
    }

    func testPlainSVGExportKeepsImageOpacity() throws {
        let doc = try open(["opacity=\"0.4\"", ""])
        let svg = try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
        let imageTags = svg.components(separatedBy: "\n").filter { $0.contains("<image ") }
        XCTAssertEqual(imageTags.count, 2)
        XCTAssertEqual(imageTags.filter { $0.contains(" opacity=\"0.4\"") }.count, 1,
                       "The semi-transparent image must be written with its opacity")
        XCTAssertEqual(imageTags.filter { $0.contains(" opacity=") }.count, 1,
                       "A fully opaque image adds no opacity attribute")
        let reopened = try FileOperations.importFromSVGData(Data(svg.utf8))
        XCTAssertEqual(imageOpacities(reopened), [0.4, 1])
    }

    func testOpacitySetInAppSurvivesPlainSVGExport() throws {
        let doc = try open([""])
        let id = try XCTUnwrap(doc.snapshot.objects.first { $0.value.shape.embeddedImageData != nil }?.key)
        doc.updateShapeOpacityInUnified(id: id, opacity: 0.25)
        let svg = try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
        let reopened = try FileOperations.importFromSVGData(Data(svg.utf8))
        XCTAssertEqual(imageOpacities(reopened), [0.25])
    }
}
