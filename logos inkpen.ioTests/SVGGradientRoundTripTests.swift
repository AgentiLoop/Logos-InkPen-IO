import XCTest
@testable import logos_inkpen_io

/// Gradient fills survive open → save → open through the plain SVG writer: stop opacity,
/// spread method, user-space coordinates and bounding-box geometry (VectorCraft's
/// "gradients round-trip through the SVG writer, tested against the importer" property).
final class SVGGradientRoundTripTests: XCTestCase {

    private func open(_ svg: String) throws -> VectorDocument {
        try FileOperations.importFromSVGData(Data(svg.utf8))
    }

    private func open(defs: String, fill: String = "url(#g)") throws -> VectorDocument {
        try open("""
        <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
        <defs>\(defs)</defs>
        <rect x="20" y="20" width="160" height="160" fill="\(fill)"/>
        </svg>
        """)
    }

    private func save(_ doc: VectorDocument) throws -> String {
        try SVGExporter.shared.exportToSVG(doc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
    }

    private func gradient(_ doc: VectorDocument, file: StaticString = #filePath, line: UInt = #line) throws -> VectorGradient {
        let gradients = doc.snapshot.objects.values.compactMap { object -> VectorGradient? in
            if case .gradient(let g) = object.shape.fillStyle?.color { return g }
            return nil
        }
        XCTAssertEqual(gradients.count, 1, "Expected one gradient-filled shape", file: file, line: line)
        return try XCTUnwrap(gradients.first, file: file, line: line)
    }

    /// open → save → open, returning both gradients and the saved SVG.
    private func roundTrip(defs: String) throws -> (before: VectorGradient, after: VectorGradient, svg: String) {
        let doc = try open(defs: defs)
        let before = try gradient(doc)
        let svg = try save(doc)
        let after = try gradient(try open(svg))
        return (before, after, svg)
    }

    private func linear(_ g: VectorGradient) throws -> LinearGradient {
        guard case .linear(let l) = g else { XCTFail("Expected a linear gradient"); throw CancellationError() }
        return l
    }

    private func radial(_ g: VectorGradient) throws -> RadialGradient {
        guard case .radial(let r) = g else { XCTFail("Expected a radial gradient"); throw CancellationError() }
        return r
    }

    private func assertEqual(_ a: CGPoint?, _ b: CGPoint?, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let a, let b else { return XCTAssertTrue(a == nil && b == nil, message, file: file, line: line) }
        XCTAssertEqual(a.x, b.x, accuracy: 1e-6, message, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: 1e-6, message, file: file, line: line)
    }

    func testStopOpacitySurvivesPlainSVGExport() throws {
        let (before, after, svg) = try roundTrip(defs: """
        <linearGradient id="g"><stop offset="0%" stop-color="#ff0000" stop-opacity="0.25"/>\
        <stop offset="50%" style="stop-color:#0000ff;stop-opacity:0.5"/><stop offset="100%" stop-color="#00ff00"/></linearGradient>
        """)
        XCTAssertEqual(before.stops.map(\.opacity), [0.25, 0.5, 1])
        XCTAssertEqual(svg.components(separatedBy: "stop-opacity=").count - 1, 2, "A fully opaque stop adds no stop-opacity")
        XCTAssertEqual(after.stops.map(\.opacity), [0.25, 0.5, 1])
        XCTAssertEqual(after.stops.map(\.position), before.stops.map(\.position))
    }

    func testSpreadMethodSurvivesPlainSVGExport() throws {
        let (before, after, svg) = try roundTrip(defs: """
        <radialGradient id="g" spreadMethod="reflect"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></radialGradient>
        """)
        XCTAssertEqual(try radial(before).spreadMethod, .reflect)
        XCTAssertTrue(svg.contains("spreadMethod=\"reflect\""))
        XCTAssertEqual(try radial(after).spreadMethod, .reflect)
    }

    func testDefaultPadSpreadMethodIsNotWritten() throws {
        let (_, after, svg) = try roundTrip(defs: """
        <linearGradient id="g"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>
        """)
        XCTAssertFalse(svg.contains("spreadMethod="))
        XCTAssertEqual(try linear(after).spreadMethod, .pad)
    }

    func testUserSpaceLinearGradientKeepsItsCoordinates() throws {
        let (before, after, svg) = try roundTrip(defs: """
        <linearGradient id="g" gradientUnits="userSpaceOnUse" x1="40" y1="30" x2="160" y2="150">\
        <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>
        """)
        let l0 = try linear(before), l1 = try linear(after)
        XCTAssertEqual(l0.units, .userSpaceOnUse)
        XCTAssertTrue(svg.contains("gradientUnits=\"userSpaceOnUse\""))
        XCTAssertEqual(l1.units, .userSpaceOnUse)
        assertEqual(l1.startPoint, CGPoint(x: 40, y: 30))
        assertEqual(l1.endPoint, CGPoint(x: 160, y: 150))
    }

    func testUserSpaceRadialGradientKeepsCenterRadiusAndFocus() throws {
        let (before, after, _) = try roundTrip(defs: """
        <radialGradient id="g" gradientUnits="userSpaceOnUse" cx="100" cy="90" r="60" fx="80" fy="70">\
        <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></radialGradient>
        """)
        let r0 = try radial(before), r1 = try radial(after)
        XCTAssertEqual(r0.units, .userSpaceOnUse)
        XCTAssertEqual(r1.units, .userSpaceOnUse)
        assertEqual(r1.centerPoint, CGPoint(x: 100, y: 90))
        XCTAssertEqual(r1.radius, 60, accuracy: 1e-6)
        assertEqual(r1.focalPoint, CGPoint(x: 80, y: 70))
    }

    func testBoundingBoxLinearGradientKeepsOriginAngleAndLength() throws {
        let (before, after, _) = try roundTrip(defs: """
        <linearGradient id="g" x1="0%" y1="0%" x2="50%" y2="50%">\
        <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>
        """)
        let l0 = try linear(before), l1 = try linear(after)
        assertEqual(l0.originPoint, CGPoint(x: 0.25, y: 0.25))
        XCTAssertEqual(l0.angle, 45, accuracy: 1e-6)
        assertEqual(l1.originPoint, l0.originPoint, "Origin point")
        XCTAssertEqual(l1.angle, l0.angle, accuracy: 1e-6)
        XCTAssertEqual(l1.endPoint.distance(to: l1.startPoint), l0.endPoint.distance(to: l0.startPoint), accuracy: 1e-6)
    }

    func testBoundingBoxLinearAngleSetInAppSurvivesExport() throws {
        let doc = try open(defs: """
        <linearGradient id="g"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>
        """)
        var l = try linear(try gradient(doc))
        l.setAngle(90)
        let shapeID = try XCTUnwrap(doc.snapshot.objects.values.first { $0.shape.fillStyle != nil }?.id)
        doc.updateShapeGradientInUnified(id: shapeID, gradient: .linear(l), target: .fill)
        XCTAssertEqual(try linear(try gradient(doc)).angle, 90, accuracy: 1e-6)
        let after = try linear(try gradient(try open(try save(doc))))
        XCTAssertEqual(after.angle, 90, accuracy: 1e-6)
        assertEqual(after.originPoint, l.originPoint)
    }

    func testBoundingBoxRadialGradientKeepsCenterAndRadius() throws {
        let (before, after, _) = try roundTrip(defs: """
        <radialGradient id="g" cx="30%" cy="40%" r="25%">\
        <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></radialGradient>
        """)
        let r0 = try radial(before), r1 = try radial(after)
        assertEqual(r0.originPoint, CGPoint(x: 0.3, y: 0.4))
        assertEqual(r1.originPoint, r0.originPoint, "Center")
        XCTAssertEqual(r1.radius, 0.25, accuracy: 1e-6)
        assertEqual(r1.focalPoint, r0.focalPoint, "Focal offset")
    }
}
