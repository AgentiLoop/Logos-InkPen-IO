import XCTest
@testable import logos_inkpen_io

/// Layers panel operations: add / remove layer, drag a layer to reorder it, drag objects onto
/// another layer, drag an object within its layer. Every object listed by a layer must know that
/// layer's index, objects must keep their stacking order, and each undoable step must be undone
/// exactly by ⌘Z.
final class LayerManagementTests: XCTestCase {

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

    private var drawingLayer = 0

    private func open() throws -> VectorDocument {
        let doc = try FileOperations.importFromSVGData(Data(svg.utf8))
        doc.viewState.currentTool = .selection
        doc.viewState.selectedPoints.removeAll()
        drawingLayer = try XCTUnwrap(topLevelIDs(doc).first.flatMap { doc.snapshot.objects[$0]?.layerIndex })
        selectLayer(drawingLayer, in: doc)
        return doc
    }

    private func selectLayer(_ index: Int, in doc: VectorDocument) {
        doc.selectedLayerIndex = index
        doc.settings.selectedLayerId = doc.snapshot.layers[index].id
        doc.settings.selectedLayerName = doc.snapshot.layers[index].name
    }

    private func layerOrder(_ doc: VectorDocument) -> [[UUID]] {
        doc.snapshot.layers.map(\.objectIDs)
    }

    private func layerIDs(_ doc: VectorDocument) -> [UUID] {
        doc.snapshot.layers.map(\.id)
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

    /// Adds an empty layer directly above `index` and returns its index.
    private func addLayer(above index: Int, in doc: VectorDocument) -> Int {
        selectLayer(index, in: doc)
        doc.addLayer()
        return index + 1
    }

    /// Every object a layer lists must say it lives on that layer, and appear in exactly one layer.
    private func assertLayerIndexesConsistent(_ doc: VectorDocument, _ message: String,
                                              file: StaticString = #filePath, line: UInt = #line) {
        var seen = Set<UUID>()
        for (index, layer) in doc.snapshot.layers.enumerated() {
            for id in layer.objectIDs {
                XCTAssertTrue(seen.insert(id).inserted, "\(message): object listed by two layers", file: file, line: line)
                guard let object = doc.snapshot.objects[id] else {
                    XCTFail("\(message): layer \(layer.name) lists a missing object", file: file, line: line)
                    continue
                }
                XCTAssertEqual(object.layerIndex, index,
                               "\(message): object on layer \(layer.name) has layerIndex \(object.layerIndex)",
                               file: file, line: line)
            }
        }
    }

    func testFixtureShape() throws {
        let doc = try open()
        XCTAssertEqual(plainShapes(doc).count, 5)
        XCTAssertEqual(topLevelIDs(doc).count, 6)
        XCTAssertGreaterThan(drawingLayer, 2)
        assertLayerIndexesConsistent(doc, "Opened document")
    }

    // MARK: Add layer

    func testAddLayerGoesAboveSelectedLayerWithNextFreeNumberAndBecomesSelected() throws {
        let doc = try open()
        let before = doc.snapshot.layers.count
        let undoCount = doc.commandManager.undoCount

        doc.addLayer()
        doc.addLayer()

        XCTAssertEqual(doc.snapshot.layers.count, before + 2)
        let first = doc.snapshot.layers[drawingLayer + 1]
        let second = doc.snapshot.layers[drawingLayer + 2]
        XCTAssertNotEqual(first.name, second.name, "Two new layers got the same name")
        for layer in [first, second] {
            XCTAssertTrue(layer.name.hasPrefix("Layer "), "New layer is named \(layer.name)")
            XCTAssertTrue(layer.objectIDs.isEmpty)
            XCTAssertTrue(layer.isVisible)
            XCTAssertFalse(layer.isLocked)
        }
        XCTAssertEqual(Set(doc.snapshot.layers.map(\.name)).count, doc.snapshot.layers.count, "Duplicate layer names")
        XCTAssertEqual(doc.selectedLayerIndex, drawingLayer + 2)
        XCTAssertEqual(doc.settings.selectedLayerId, second.id)
        XCTAssertEqual(doc.settings.selectedLayerName, second.name)
        XCTAssertEqual(doc.commandManager.undoCount, undoCount + 2, "Each new layer must be one undo step")
        assertLayerIndexesConsistent(doc, "After adding layers")
    }

    func testAddLayerBelowAnotherLayerShiftsThatLayersObjects() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let d = plainShapes(doc)[3]
        doc.moveObjectToLayer(objectId: d, targetLayerIndex: upper)
        XCTAssertEqual(doc.snapshot.objects[d]?.layerIndex, upper)

        _ = addLayer(above: drawingLayer, in: doc)

        XCTAssertEqual(doc.snapshot.objects[d]?.layerIndex, upper + 1)
        XCTAssertEqual(doc.snapshot.layers[upper + 1].objectIDs, [d])
        assertLayerIndexesConsistent(doc, "After inserting a layer below another one")
    }

    func testUndoAddLayerRemovesItAndRedoBringsItBack() throws {
        let doc = try open()
        let layers = layerIDs(doc), order = layerOrder(doc)
        let selectedID = doc.settings.selectedLayerId

        doc.addLayer()
        let added = doc.snapshot.layers[drawingLayer + 1]

        doc.undo()
        XCTAssertEqual(layerIDs(doc), layers, "Undo add layer")
        XCTAssertEqual(layerOrder(doc), order)
        XCTAssertEqual(doc.settings.selectedLayerId, selectedID, "Undo add layer must reselect the old layer")
        XCTAssertEqual(doc.selectedLayerIndex, drawingLayer)
        assertLayerIndexesConsistent(doc, "After undo add layer")

        doc.redo()
        XCTAssertEqual(doc.snapshot.layers[drawingLayer + 1], added, "Redo add layer")
        XCTAssertEqual(doc.settings.selectedLayerId, added.id)
        assertLayerIndexesConsistent(doc, "After redo add layer")
    }

    // MARK: Remove layer

    func testRemoveLayerDeletesItsObjectsAndReindexesLayersAbove() throws {
        let doc = try open()
        let middle = addLayer(above: drawingLayer, in: doc)
        let top = addLayer(above: middle, in: doc)
        let shapes = plainShapes(doc)
        let group = try groupID(doc)
        let members = try XCTUnwrap(doc.snapshot.objects[group]?.shape.memberIDs)
        doc.moveObjectsToLayer(objectIds: [shapes[0], group], targetLayerIndex: middle)
        doc.moveObjectToLayer(objectId: shapes[4], targetLayerIndex: top)
        select([shapes[0], shapes[1]], in: doc)
        selectLayer(middle, in: doc)

        doc.removeLayer(at: middle)

        XCTAssertNil(doc.snapshot.objects[shapes[0]], "Object on the removed layer still exists")
        XCTAssertNil(doc.snapshot.objects[group])
        for m in members { XCTAssertNil(doc.snapshot.objects[m], "Member of a group on the removed layer still exists") }
        XCTAssertEqual(doc.viewState.selectedObjectIDs, [shapes[1]], "Removed object is still selected")
        XCTAssertEqual(doc.snapshot.objects[shapes[4]]?.layerIndex, top - 1)
        let selectedID = try XCTUnwrap(doc.settings.selectedLayerId)
        XCTAssertNotNil(doc.snapshot.layers.firstIndex { $0.id == selectedID }, "Selected layer id points at a removed layer")
        assertLayerIndexesConsistent(doc, "After removing a layer")
    }

    func testUndoRemoveLayerBringsBackLayerAndObjects() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let shapes = plainShapes(doc)
        let group = try groupID(doc)
        doc.moveObjectsToLayer(objectIds: [shapes[1], group, shapes[3]], targetLayerIndex: upper)
        let objects = doc.snapshot.objects, layers = doc.snapshot.layers
        selectLayer(upper, in: doc)
        let selectedID = doc.settings.selectedLayerId

        doc.removeLayer(at: upper)
        doc.undo()

        XCTAssertEqual(doc.snapshot.layers, layers, "Undo remove layer must restore every layer")
        XCTAssertEqual(doc.snapshot.objects, objects, "Undo remove layer must restore its objects and group members")
        XCTAssertEqual(doc.settings.selectedLayerId, selectedID)
        XCTAssertEqual(doc.selectedLayerIndex, upper)

        doc.redo()
        XCTAssertNil(doc.snapshot.objects[group], "Redo must remove the layer again")
        XCTAssertFalse(layerIDs(doc).contains(layers[upper].id))
        assertLayerIndexesConsistent(doc, "After redo remove layer")
    }

    // MARK: Move objects to another layer

    func testMoveObjectsToLayerKeepsTheirStackingOrder() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let shapes = plainShapes(doc)

        // The Layers panel passes the selection Set, so the order it hands over is arbitrary.
        doc.moveObjectsToLayer(objectIds: [shapes[4], shapes[0], shapes[2]], targetLayerIndex: upper)

        XCTAssertEqual(doc.snapshot.layers[upper].objectIDs, [shapes[0], shapes[2], shapes[4]],
                       "Objects moved to a layer must keep their back-to-front order")
        assertLayerIndexesConsistent(doc, "After moving objects to a layer")
    }

    func testUndoMoveObjectsToLayerRestoresOriginalStackingOrder() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let shapes = plainShapes(doc)
        let order = layerOrder(doc)

        doc.moveObjectsToLayer(objectIds: [shapes[3], shapes[1]], targetLayerIndex: upper)
        let moved = layerOrder(doc)

        doc.undo()
        XCTAssertEqual(layerOrder(doc), order, "Undo must put the objects back where they were in their layer")
        assertLayerIndexesConsistent(doc, "After undo move to layer")
        doc.redo()
        XCTAssertEqual(layerOrder(doc), moved, "Redo move to layer")
        assertLayerIndexesConsistent(doc, "After redo move to layer")
    }

    func testUndoMoveSingleObjectToLayerRestoresItsPosition() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let b = plainShapes(doc)[1]
        let order = layerOrder(doc)

        doc.moveObjectToLayer(objectId: b, targetLayerIndex: upper)
        XCTAssertEqual(doc.snapshot.layers[upper].objectIDs, [b])
        XCTAssertEqual(doc.snapshot.objects[b]?.layerIndex, upper)

        doc.undo()
        XCTAssertEqual(layerOrder(doc), order, "Undo must put the object back at its old position")
        assertLayerIndexesConsistent(doc, "After undo move one object")
    }

    func testMoveObjectOntoCanvasOrGuidesLayerLandsOnFirstDrawingLayer() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let a = plainShapes(doc)[0]
        doc.moveObjectToLayer(objectId: a, targetLayerIndex: upper)

        doc.moveObjectToLayer(objectId: a, targetLayerIndex: 0)

        XCTAssertEqual(doc.snapshot.objects[a]?.layerIndex, 3)
        XCTAssertTrue(doc.snapshot.layers[3].objectIDs.contains(a))
        XCTAssertFalse(doc.snapshot.layers[0].objectIDs.contains(a))
        assertLayerIndexesConsistent(doc, "After dropping on the canvas layer")
    }

    func testMoveObjectsToTheirOwnLayerAddsNoUndoStep() throws {
        let doc = try open()
        let order = layerOrder(doc)
        let undoCount = doc.commandManager.undoCount
        let shapes = plainShapes(doc)

        doc.moveObjectsToLayer(objectIds: [shapes[0], shapes[1]], targetLayerIndex: drawingLayer)
        doc.moveObjectToLayer(objectId: shapes[2], targetLayerIndex: drawingLayer)

        XCTAssertEqual(layerOrder(doc), order)
        XCTAssertEqual(doc.commandManager.undoCount, undoCount)
    }

    func testGroupMovesToLayerAsOneObject() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let group = try groupID(doc)
        let members = try XCTUnwrap(doc.snapshot.objects[group]?.shape.memberIDs)
        let before = doc.snapshot.objects[group]?.shape

        doc.moveObjectToLayer(objectId: group, targetLayerIndex: upper)

        XCTAssertEqual(doc.snapshot.layers[upper].objectIDs, [group])
        XCTAssertEqual(doc.snapshot.objects[group]?.shape, before, "Moving a group to a layer changed the group")
        let listed = Set(layerOrder(doc).flatMap { $0 })
        for m in members {
            XCTAssertNotNil(doc.snapshot.objects[m], "Group member lost when moving its group")
            XCTAssertFalse(listed.contains(m), "Group member became a top-level object")
        }
        assertLayerIndexesConsistent(doc, "After moving a group")
    }

    // MARK: Reorder layers

    func testDragLayerOntoAnotherMovesItAndItsObjectsAndUndoRestores() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let shapes = plainShapes(doc)
        doc.moveObjectsToLayer(objectIds: [shapes[0], shapes[1]], targetLayerIndex: upper)
        let layers = layerIDs(doc), order = layerOrder(doc)
        let objects = doc.snapshot.objects

        doc.reorderLayer(sourceLayerId: layers[upper], targetLayerId: layers[drawingLayer])

        XCTAssertEqual(doc.snapshot.layers[drawingLayer].id, layers[upper])
        XCTAssertEqual(doc.snapshot.layers[upper].id, layers[drawingLayer])
        XCTAssertEqual(doc.snapshot.objects[shapes[0]]?.layerIndex, drawingLayer)
        XCTAssertEqual(doc.snapshot.objects[shapes[2]]?.layerIndex, upper)
        assertLayerIndexesConsistent(doc, "After reordering layers")
        let reordered = layerOrder(doc)

        doc.undo()
        XCTAssertEqual(layerIDs(doc), layers, "Undo layer reorder")
        XCTAssertEqual(layerOrder(doc), order)
        XCTAssertEqual(doc.snapshot.objects, objects, "Undo layer reorder must restore every object")
        doc.redo()
        XCTAssertEqual(layerOrder(doc), reordered, "Redo layer reorder")
        assertLayerIndexesConsistent(doc, "After redo layer reorder")
    }

    func testDragLayerOntoItselfAddsNoUndoStep() throws {
        let doc = try open()
        let undoCount = doc.commandManager.undoCount
        let id = doc.snapshot.layers[drawingLayer].id

        doc.reorderLayer(sourceLayerId: id, targetLayerId: id)

        XCTAssertEqual(doc.commandManager.undoCount, undoCount)
    }

    // MARK: Reorder objects inside a layer

    func testDragObjectWithinLayerReordersItAndIsUndoable() throws {
        let doc = try open()
        let shapes = plainShapes(doc)
        let order = layerOrder(doc)

        // Drag e (front) onto a (back): e takes a's place, a and the rest move up one.
        doc.reorderObject(objectId: shapes[4], targetObjectId: shapes[0])

        let ids = doc.snapshot.layers[drawingLayer].objectIDs
        let a = try XCTUnwrap(ids.firstIndex(of: shapes[0]))
        XCTAssertGreaterThan(a, 0)
        XCTAssertEqual(ids[a - 1], shapes[4], "Dragged object must sit right behind the drop target")

        doc.undo()
        XCTAssertEqual(layerOrder(doc), order, "Undo of a drag inside the Layers panel")
        doc.redo()
        XCTAssertEqual(doc.snapshot.layers[drawingLayer].objectIDs, ids, "Redo of a drag inside the Layers panel")
    }

    func testDragObjectOntoObjectInAnotherLayerThenUndoRestoresBothLayers() throws {
        let doc = try open()
        let upper = addLayer(above: drawingLayer, in: doc)
        let shapes = plainShapes(doc)
        doc.moveObjectsToLayer(objectIds: [shapes[3], shapes[4]], targetLayerIndex: upper)
        let order = layerOrder(doc)

        // What ObjectRow does when an object from another layer is dropped on a row.
        doc.moveObjectToLayer(objectId: shapes[1], targetLayerIndex: upper)
        doc.reorderObject(objectId: shapes[1], targetObjectId: shapes[3])
        XCTAssertEqual(doc.snapshot.layers[upper].objectIDs, [shapes[1], shapes[3], shapes[4]])
        assertLayerIndexesConsistent(doc, "After cross-layer drop")

        doc.undo()
        doc.undo()
        XCTAssertEqual(layerOrder(doc), order, "Two undos must undo the cross-layer drop")
        assertLayerIndexesConsistent(doc, "After undoing a cross-layer drop")
    }
}
