import XCTest
@testable import logos_inkpen_io

/// Colors survive open → save → open with the default Display P3 export setting — VectorCraft's
/// "Generic CMYK black round-trips through hex" fix: a color written as hex must read back as the same color.
final class SVGColorRoundTripTests: XCTestCase {

    private var savedColorSpace: AppState.ExportColorSpace = .displayP3

    override func setUp() {
        super.setUp()
        savedColorSpace = AppState.shared.exportColorSpace
        AppState.shared.exportColorSpace = .displayP3
    }

    override func tearDown() {
        AppState.shared.exportColorSpace = savedColorSpace
        super.tearDown()
    }

    private func open(_ svg: String) throws -> VectorDocument {
        try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    private func save(_ doc: VectorDocument) throws -> String {
        try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
    }

    private func rect(fill: String, stroke: String = "none") -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
        <rect x="10" y="10" width="50" height="50" fill="\(fill)" stroke="\(stroke)" stroke-width="2"/>
        </svg>
        """
    }

    private func fill(_ doc: VectorDocument) -> VectorColor? {
        doc.snapshot.objects.values.map(\.shape).compactMap { $0.fillStyle?.color }.first { $0 != .clear }
    }

    private func stroke(_ doc: VectorDocument) -> VectorColor? {
        doc.snapshot.objects.values.map(\.shape).compactMap { $0.strokeStyle?.color }.first { $0 != .clear }
    }

    func testHexFillIsWrittenBackAsTheSameHex() throws {
        let doc = try open(rect(fill: "#ff0000", stroke: "#3366cc"))
        let svg = try save(doc)
        XCTAssertTrue(svg.contains("#FF0000"), "red stays #FF0000, not re-encoded P3 values: \(svg)")
        XCTAssertTrue(svg.contains("#3366CC"), "stroke stays #3366CC: \(svg)")
    }

    func testHexColorsDoNotDriftOverRepeatedRoundTrips() throws {
        for hex in ["#ff0000", "#00ff00", "#0000ff", "#123456", "#fedcba", "#808080"] {
            var doc = try open(rect(fill: hex))
            let first = fill(doc)?.svgColor
            for _ in 0..<3 {
                doc = try open(try save(doc))
            }
            XCTAssertEqual(fill(doc)?.svgColor, first, "\(hex) drifts across round trips")
            XCTAssertEqual(first, hex.uppercased())
        }
    }

    func testWideGamutColorIsWrittenAsDisplayP3AndReadBack() throws {
        let p3Red = logos_inkpen_io.RGBColor(red: 1, green: 0, blue: 0)
        let written = VectorColor.rgb(p3Red).svgColor
        XCTAssertEqual(written, "color(display-p3 1.0000 0.0000 0.0000)", "P3 red is outside sRGB")
        guard case .rgb(let read)? = SVGParser().parseColor(written) else { return XCTFail("color() not parsed") }
        XCTAssertEqual(read.red, 1, accuracy: 1e-4)
        XCTAssertEqual(read.green, 0, accuracy: 1e-4)
        XCTAssertEqual(read.blue, 0, accuracy: 1e-4)
    }

    func testWideGamutFillSurvivesRoundTrip() throws {
        let doc = try open(rect(fill: "color(display-p3 0 1 0)"))
        let reopened = try open(try save(doc))
        guard case .rgb(let c)? = fill(reopened) else { return XCTFail("fill not imported") }
        XCTAssertEqual(c.red, 0, accuracy: 1e-4)
        XCTAssertEqual(c.green, 1, accuracy: 1e-4)
        XCTAssertEqual(c.blue, 0, accuracy: 1e-4)
    }

    func testCSSColorFunctionVariantsParse() {
        let parser = SVGParser()
        guard case .rgb(let s)? = parser.parseColor("color(srgb 100% 0% 0% / 0.5)") else { return XCTFail("srgb color() not parsed") }
        XCTAssertEqual(s.alpha, 0.5, accuracy: 1e-9)
        XCTAssertEqual(VectorColor.rgb(s).svgColor, "#FF0000")
        XCTAssertNil(parser.parseColor("color(rec2020 1 0 0)"), "unsupported color spaces fall back to the caller's default")
        XCTAssertNil(parser.parseColor("color(display-p3 1 x 0)"))
    }

    private func sRGBComponents(_ cgColor: CGColor) -> [CGFloat] {
        let extended = CGColorSpace(name: CGColorSpace.extendedSRGB)!
        return Array((ColorManager.shared.convert(cgColor, to: extended).components ?? []).prefix(3))
    }

    private var nonRGBColors: [VectorColor] {
        let mid = logos_inkpen_io.RGBColor(red: 0.4, green: 0.5, blue: 0.6)
        return [
            .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1)),
            .cmyk(CMYKColor(cyan: 0.2, magenta: 0.4, yellow: 0.6, black: 0.1)),
            .cmyk(CMYKColor(cyan: 0, magenta: 1, yellow: 1, black: 0)),
            .hsb(HSBColorModel(hue: 210, saturation: 0.6, brightness: 0.8)),
            .hsb(HSBColorModel(hue: 120, saturation: 1, brightness: 1)),
            .pantone(PantoneLibraryColor(pantone: "286-c", hex: "#0033A0")),
            .spot(SPOTColor(number: "1", name: "Spot", rgbEquivalent: mid,
                            cmykEquivalent: CMYKColor(cyan: 0.7, magenta: 0.3, yellow: 0, black: 0.3),
                            hsbEquivalent: HSBColorModel.fromRGB(mid), alpha: 1)),
            .appleSystem(AppleSystemColor(name: "systemGray3", lightMode: mid)),
        ]
    }

    /// Every color model is written the way the canvas draws it, so reading the SVG back gives the same color.
    func testNonRGBColorModelsReadBackAsTheColorTheCanvasDraws() {
        let parser = SVGParser()
        for color in nonRGBColors {
            let written = color.svgColor
            guard case .rgb(let read)? = parser.parseColor(written) else { XCTFail("\(written) not parsed"); continue }
            let expected = sRGBComponents(color.cgColor)
            let actual = sRGBComponents(read.cgColor)
            XCTAssertEqual(expected.count, 3)
            for (e, a) in zip(expected, actual) {
                XCTAssertEqual(a, e, accuracy: 1.0 / 255.0, "\(color) written as \(written)")
            }
        }
    }

    /// Colors sRGB can show are written as the same hex in both export color space settings.
    func testInGamutNonRGBColorsMatchSRGBExportHex() {
        let inGamut = nonRGBColors.filter { !$0.svgColor.hasPrefix("color(") }
        let p3Hex = inGamut.map(\.svgColor)
        XCTAssertEqual(inGamut.count, 5, "\(p3Hex)")
        AppState.shared.exportColorSpace = .sRGB
        let srgbHex = inGamut.map(\.svgColor)
        XCTAssertEqual(srgbHex, p3Hex)
        XCTAssertEqual(VectorColor.cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1)).svgColor, "#000000",
                       "CMYK black round-trips through hex")
    }
}
