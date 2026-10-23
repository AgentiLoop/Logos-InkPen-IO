import XCTest
import AppKit
@testable import logos_inkpen_io

/// Stroke & Fill panel › Image Properties › Opacity: sets the opacity of the selected images only,
/// is one undo step (a whole slider drag too, as VectorCraft #430 / #1389), ⌘Z restores exactly,
/// and a value the images already have adds no undo step (VectorCraft #1331).
final class ImageOpacityUndoTests: XCTestCase {

    private func pngBase64() throws -> String {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:])).base64EncodedString()
    }

    private func open() throws -> VectorDocument {
        let png = try pngBase64()
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="300">
          <image x="10" y="10" width="40" height="40" xlink:href="data:image/png;base64,\(png)"/>
          <image x="100" y="10" width="40" height="40" opacity="0.5" xlink:href="data:image/png;base64,\(png)"/>
          <rect x="200" y="10" width="40" height="40" fill="red"/>
        </svg>
        """
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        return doc
    }

    /// The two images (opacity 1 and 0.5) and the rectangle.
    private func fixture(_ doc: VectorDocument) throws -> (image: UUID, halfImage: UUID, rect: UUID) {
        let ids = doc.snapshot.layers.enumerated()
            .filter { $0.offset > 2 }
            .flatMap(\.element.objectIDs)
        let images = ids.filter { doc.snapshot.objects[$0]?.shape.embeddedImageData != nil }
        XCTAssertEqual(images.count, 2)
        let image = try XCTUnwrap(images.first)
        let half = try XCTUnwrap(images.last)
        XCTAssertEqual(doc.snapshot.objects[image]?.shape.opacity, 1)
        XCTAssertEqual(doc.snapshot.objects[half]?.shape.opacity, 0.5)
        let rect = try XCTUnwrap(ids.first { id in
            guard let s = doc.snapshot.objects[id]?.shape else { return false }
            return s.embeddedImageData == nil
                && s.name != "Canvas Background" && s.name != "Pasteboard Background"
        })
        return (image, half, rect)
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func shapes(_ doc: VectorDocument) -> [UUID: VectorShape] {
        doc.snapshot.objects.mapValues(\.shape)
    }

    private func changedIDs(_ a: [UUID: VectorShape], _ b: [UUID: VectorShape]) -> Set<UUID> {
        Set(a.keys).union(b.keys).filter { a[$0] != b[$0] }
    }

    private func opacity(_ id: UUID, _ doc: VectorDocument) -> Double? {
        doc.snapshot.objects[id]?.shape.opacity
    }

    func testImageOpacityIsOneUndoStepAndUndoesExactly() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.image, f.halfImage], in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        PaintSelectionOperations.updateImageOpacity(0.25, document: doc)
        let after = shapes(doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps + 1)
        XCTAssertEqual(opacity(f.image, doc), 0.25)
        XCTAssertEqual(opacity(f.halfImage, doc), 0.25)
        XCTAssertEqual(changedIDs(before, after), [f.image, f.halfImage])
        doc.commandManager.undo()
        XCTAssertEqual(changedIDs(before, shapes(doc)), [], "undo did not restore")
        doc.commandManager.redo()
        XCTAssertEqual(changedIDs(after, shapes(doc)), [], "redo did not restore")
    }

    func testImageOpacityLeavesSelectedNonImagesAlone() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.image, f.rect], in: doc)
        let rectBefore = doc.snapshot.objects[f.rect]?.shape
        PaintSelectionOperations.updateImageOpacity(0.3, document: doc)
        XCTAssertEqual(opacity(f.image, doc), 0.3)
        XCTAssertEqual(doc.snapshot.objects[f.rect]?.shape, rectBefore, "the image slider changed a rectangle")
    }

    func testSameImageOpacityAddsNoUndoStep() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.halfImage], in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        PaintSelectionOperations.updateImageOpacity(0.5, document: doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps, "unchanged opacity added an undo step")
        XCTAssertEqual(changedIDs(before, shapes(doc)), [])
    }

    func testImageOpacityWithNoImageSelectedAddsNoUndoStep() throws {
        let doc = try open()
        let f = try fixture(doc)
        for selection in [[], [f.rect]] {
            select(selection, in: doc)
            let before = shapes(doc)
            let steps = doc.commandManager.undoCount
            PaintSelectionOperations.updateImageOpacity(0.3, document: doc)
            XCTAssertEqual(doc.commandManager.undoCount, steps, "undo step without an image selected")
            XCTAssertEqual(changedIDs(before, shapes(doc)), [])
        }
    }

    func testSliderDragIsOneUndoStepAndUndoRestoresTheOpacityBeforeTheDrag() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.image, f.halfImage], in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        let start = PaintSelectionOperations.selectedImageOpacities(document: doc)
        XCTAssertEqual(start, [f.image: 1, f.halfImage: 0.5])
        for value in [0.9, 0.7, 0.4] {
            PaintSelectionOperations.updateImageOpacityLive(value, document: doc)
            XCTAssertEqual(opacity(f.image, doc), value, "live drag shows the new opacity")
            XCTAssertEqual(doc.commandManager.undoCount, steps, "undo step while dragging")
        }
        PaintSelectionOperations.commitImageOpacity(0.4, from: start, document: doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps + 1)
        XCTAssertEqual(opacity(f.image, doc), 0.4)
        XCTAssertEqual(opacity(f.halfImage, doc), 0.4)
        let after = shapes(doc)
        doc.commandManager.undo()
        XCTAssertEqual(changedIDs(before, shapes(doc)), [], "undo did not restore the opacity before the drag")
        doc.commandManager.redo()
        XCTAssertEqual(changedIDs(after, shapes(doc)), [], "redo did not restore")
    }

    func testSliderDragBackToTheStartAddsNoUndoStep() throws {
        let doc = try open()
        let f = try fixture(doc)
        select([f.halfImage], in: doc)
        let before = shapes(doc)
        let steps = doc.commandManager.undoCount
        let start = PaintSelectionOperations.selectedImageOpacities(document: doc)
        PaintSelectionOperations.updateImageOpacityLive(0.8, document: doc)
        PaintSelectionOperations.updateImageOpacityLive(0.5, document: doc)
        PaintSelectionOperations.commitImageOpacity(0.5, from: start, document: doc)
        XCTAssertEqual(doc.commandManager.undoCount, steps)
        XCTAssertEqual(changedIDs(before, shapes(doc)), [])
    }
}
