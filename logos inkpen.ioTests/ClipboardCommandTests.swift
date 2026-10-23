import XCTest
import AppKit
@testable import logos_inkpen_io

/// Edit menu Cut / Copy / Paste / Paste in Front / Paste in Back go through ClipboardManager.
/// Pasted objects must be independent copies that keep their stacking order, and every paste
/// and cut must be undoable.
final class ClipboardCommandTests: XCTestCase {

    private let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
      <rect id="a" x="10" y="10" width="20" height="20" fill="red"/>
      <rect id="b" x="50" y="10" width="20" height="20" fill="green"/>
      <rect id="c" x="90" y="10" width="20" height="20" fill="blue"/>
      <rect id="d" x="130" y="10" width="20" height="20" fill="yellow"/>
      <rect id="e" x="170" y="10" width="20" height="20" fill="purple"/>
      <g id="g">
        <rect x="200" y="10" width="20" height="20" fill="black"/>
        <circle cx="260" cy="20" r="10" fill="orange"/>
      </g>
    </svg>
    """

    private var savedPasteboard: [NSPasteboardItem] = []

    override func setUp() {
        super.setUp()
        // The clipboard manager uses the general pasteboard; keep the user's clipboard intact.
        savedPasteboard = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    override func tearDown() {
        NSPasteboard.general.clearContents()
        if !savedPasteboard.isEmpty { NSPasteboard.general.writeObjects(savedPasteboard) }
        super.tearDown()
    }

    private let clipboard = ClipboardManager.shared

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        let layer = try XCTUnwrap(topLevelIDs(doc).first.flatMap { doc.snapshot.objects[$0]?.layerIndex })
        doc.selectedLayerIndex = layer
        doc.settings.selectedLayerId = doc.snapshot.layers[layer].id
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

    private func plainShapes(_ doc: VectorDocument) -> [UUID] {
        topLevelIDs(doc).filter { doc.snapshot.objects[$0]?.shape.isGroup == false }
    }

    private func groupID(_ doc: VectorDocument) throws -> UUID {
        try XCTUnwrap(topLevelIDs(doc).first { doc.snapshot.objects[$0]?.shape.isGroup == true })
    }

    private func select(_ ids: [UUID], in doc: VectorDocument) {
        doc.viewState.orderedSelectedObjectIDs = ids
        doc.viewState.selectedObjectIDs = Set(ids)
    }

    private func bounds(_ id: UUID, _ doc: VectorDocument) -> CGRect? {
        doc.snapshot.objects[id]?.shape.bounds
    }

    /// For each pasted id (in stacking order), the original it copies — matched by bounds,
    /// since a paste lands exactly on top of its source.
    private func sources(of pasted: [UUID], among originals: [UUID], _ doc: VectorDocument) -> [UUID?] {
        pasted.map { p in originals.first { bounds($0, doc) == bounds(p, doc) } }
    }

    private func assertRestored(_ doc: VectorDocument, _ before: [UUID: VectorShape], _ order: [[UUID]],
                                _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        for (id, shape) in before {
            XCTAssertEqual(shapes(doc)[id], shape, "\(message): \(shape.name) differs", file: file, line: line)
        }
        XCTAssertEqual(layerOrder(doc), order, "\(message): stacking order differs", file: file, line: line)
    }

    // MARK: Paste

    func testPasteAddsIndependentCopiesOnTopAndUndoRemovesThem() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let target = try XCTUnwrap(plainShapes(doc).first)

        select([target], in: doc)
        clipboard.copy(from: doc)
        XCTAssertTrue(clipboard.canPaste())
        XCTAssertEqual(shapes(doc), before, "Copy must not change the document")

        clipboard.paste(to: doc)
        let pasted = try XCTUnwrap(doc.viewState.selectedObjectIDs.first)
        XCTAssertEqual(doc.viewState.selectedObjectIDs.count, 1)
        XCTAssertNotEqual(pasted, target)
        XCTAssertEqual(topLevelIDs(doc).last, pasted, "Paste goes on top of the layer")
        XCTAssertEqual(bounds(pasted, doc), before[target]?.bounds)

        doc.nudgeSelectedObjects(by: CGVector(dx: 7, dy: 0))
        XCTAssertEqual(shapes(doc)[target], before[target], "Moving the pasted copy moved the original")

        doc.undo() // nudge
        doc.undo() // paste
        assertRestored(doc, before, order, "Undo paste")
        XCTAssertNil(doc.snapshot.objects[pasted])

        doc.redo()
        XCTAssertEqual(topLevelIDs(doc).last, pasted, "Redo must paste the same object again")
    }

    func testPastingSeveralObjectsKeepsTheirStackingOrder() throws {
        let doc = try open()
        let originals = plainShapes(doc)
        XCTAssertEqual(originals.count, 5)

        // Select in an order different from the stacking order.
        select([originals[3], originals[0], originals[4], originals[2], originals[1]], in: doc)
        clipboard.copy(from: doc)
        clipboard.paste(to: doc)

        let pasted = Array(topLevelIDs(doc).suffix(5))
        XCTAssertEqual(Set(pasted), doc.viewState.selectedObjectIDs)
        XCTAssertEqual(sources(of: pasted, among: originals, doc), originals,
                       "Pasted copies must stack in the same order as the originals")

        doc.undo()
        doc.redo()
        XCTAssertEqual(sources(of: Array(topLevelIDs(doc).suffix(5)), among: originals, doc), originals,
                       "Redo of paste must keep the stacking order")
    }

    func testPasteInBackAndInFrontKeepStackingOrder() throws {
        let doc = try open()
        let originals = plainShapes(doc)
        let copied = [originals[0], originals[2], originals[4]]
        select(copied.reversed(), in: doc)
        clipboard.copy(from: doc)

        select([], in: doc)
        clipboard.pasteInBack(to: doc)
        let back = Array(topLevelIDs(doc).prefix(3))
        XCTAssertEqual(Set(back), doc.viewState.selectedObjectIDs, "Paste in Back with nothing selected goes to the back")
        XCTAssertEqual(sources(of: back, among: copied, doc), copied, "Paste in Back scrambled the stacking order")
        doc.undo()

        select([originals[1]], in: doc)
        clipboard.pasteInFront(to: doc)
        let ids = topLevelIDs(doc)
        let at = try XCTUnwrap(ids.firstIndex(of: originals[1]))
        let front = Array(ids[(at + 1)...(at + 3)])
        XCTAssertEqual(Set(front), doc.viewState.selectedObjectIDs, "Paste in Front goes just above the selection")
        XCTAssertEqual(sources(of: front, among: copied, doc), copied, "Paste in Front scrambled the stacking order")
    }

    func testPastedGroupHasItsOwnMembers() throws {
        let doc = try open()
        let group = try groupID(doc)
        let members = try XCTUnwrap(doc.snapshot.objects[group]?.shape.memberIDs)
        let memberBounds = members.compactMap { bounds($0, doc) }

        select([group], in: doc)
        clipboard.copy(from: doc)
        clipboard.paste(to: doc)

        let pastedID = try XCTUnwrap(doc.viewState.selectedObjectIDs.first)
        XCTAssertEqual(doc.viewState.selectedObjectIDs.count, 1, "Group members must not be pasted as top-level objects")
        let pasted = try XCTUnwrap(doc.snapshot.objects[pastedID]?.shape)
        XCTAssertTrue(pasted.isGroup)
        XCTAssertTrue(Set(pasted.memberIDs).isDisjoint(with: members), "Pasted group shares members with the original")
        XCTAssertEqual(pasted.memberIDs.compactMap { bounds($0, doc) }, memberBounds)
        for m in pasted.memberIDs { XCTAssertFalse(topLevelIDs(doc).contains(m)) }

        doc.nudgeSelectedObjects(by: CGVector(dx: 5, dy: 5))
        XCTAssertEqual(members.compactMap { bounds($0, doc) }, memberBounds, "Moving the pasted group moved the original")
    }

    func testPasteIntoLockedLayerDoesNothing() throws {
        let doc = try open()
        let before = shapes(doc)
        select([try XCTUnwrap(plainShapes(doc).first)], in: doc)
        clipboard.copy(from: doc)

        let layer = try XCTUnwrap(doc.selectedLayerIndex)
        doc.snapshot.layers[layer].isLocked = true
        let lockedOrder = layerOrder(doc)
        clipboard.paste(to: doc)
        XCTAssertEqual(layerOrder(doc), lockedOrder)
        XCTAssertEqual(Set(shapes(doc).keys), Set(before.keys))
    }

    // MARK: Cut

    func testCutRemovesSelectionAndPasteBringsItBack() throws {
        let doc = try open()
        let before = shapes(doc), order = layerOrder(doc)
        let targets = Array(plainShapes(doc).prefix(2))

        select(targets, in: doc)
        clipboard.cut(from: doc)
        for t in targets { XCTAssertNil(doc.snapshot.objects[t], "Cut must remove the selection") }
        XCTAssertTrue(clipboard.canPaste())

        clipboard.paste(to: doc)
        let pasted = Array(topLevelIDs(doc).suffix(2))
        XCTAssertEqual(pasted.map { bounds($0, doc) }, targets.map { before[$0]?.bounds })

        doc.undo() // paste
        doc.undo() // cut
        assertRestored(doc, before, order, "Undo cut+paste")
    }
}
