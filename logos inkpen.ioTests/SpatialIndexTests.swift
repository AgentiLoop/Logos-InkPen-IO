import XCTest
import CoreGraphics
@testable import logos_inkpen_io

/// Regression tests for canvas hit-test candidates (MetalSpatialIndex). Each case is a way the
/// old GPU index lost objects, which made imported SVGs hard or impossible to select.
final class SpatialIndexTests: XCTestCase {

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> VectorShape {
        VectorShape.rectangle(at: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
    }

    private func line(from a: CGPoint, to b: CGPoint) -> VectorShape {
        let path = VectorPath(elements: [.move(to: VectorPoint(a.x, a.y)), .line(to: VectorPoint(b.x, b.y))])
        return VectorShape(name: "Line", path: path, strokeStyle: StrokeStyle(color: .black, width: 1.0))
    }

    private func snapshot(_ layers: [(id: UUID, shapes: [VectorShape])]) -> DocumentSnapshot {
        var snap = DocumentSnapshot()
        for (layerIndex, entry) in layers.enumerated() {
            snap.layers.append(Layer(id: entry.id, name: "Layer \(layerIndex)", objectIDs: entry.shapes.map { $0.id }))
            for shape in entry.shapes {
                snap.objects[shape.id] = VectorObject(shape: shape, layerIndex: layerIndex)
            }
        }
        return snap
    }

    private func makeIndex(_ snap: DocumentSnapshot) -> MetalSpatialIndex {
        let index = MetalSpatialIndex()!
        index.rebuildLayers(Set(snap.layers.map { $0.id }), from: snap)
        return index
    }

    func testFindsObjectUnderPointAndNotElsewhere() {
        let shape = rect(100, 100, 50, 50)
        let index = makeIndex(snapshot([(UUID(), [shape])]))
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 120, y: 120)), [shape.id])
        XCTAssertTrue(index.candidateObjectIDs(at: CGPoint(x: 400, y: 400)).isEmpty)
    }

    /// Old index kept change fingerprints in a static cache shared by every instance, so a second
    /// canvas showing layers with the same IDs skipped its build and nothing could be clicked.
    func testSecondIndexWithSameLayerIDsIsStillBuilt() {
        let snap = snapshot([(UUID(), [rect(0, 0, 40, 40)])])
        _ = makeIndex(snap)
        let second = makeIndex(snap)
        XCTAssertFalse(second.candidateObjectIDs(at: CGPoint(x: 20, y: 20)).isEmpty)
    }

    /// Old index gave up on any layer spanning more than 10,000 grid cells (~5000 x 5000 pt).
    func testLargeDocumentLayerIsIndexed() {
        let near = rect(0, 0, 20, 20)
        let far = rect(20_000, 15_000, 20, 20)
        let index = makeIndex(snapshot([(UUID(), [near, far])]))
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 10, y: 10)), [near.id])
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 20_010, y: 15_010)), [far.id])
    }

    /// Old index stored at most 256 objects per 50 pt cell; dense SVG artwork lost the rest.
    func testDenseCellKeepsEveryObject() {
        let shapes = (0..<600).map { i in rect(10 + CGFloat(i % 20), 10 + CGFloat(i / 20), 5, 5) }
        let index = makeIndex(snapshot([(UUID(), shapes)]))
        let found = index.candidateObjectIDs(in: CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(found, Set(shapes.map { $0.id }))
    }

    /// Old index skipped any object whose bounds had zero width or height (SVG <line>, hairlines).
    func testHorizontalLineIsHittableWithinTolerance() {
        let horizontal = line(from: CGPoint(x: 0, y: 100), to: CGPoint(x: 300, y: 100))
        let index = makeIndex(snapshot([(UUID(), [horizontal])]))
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 150, y: 103), tolerance: 4), [horizontal.id])
        XCTAssertTrue(index.candidateObjectIDs(at: CGPoint(x: 150, y: 120), tolerance: 4).isEmpty)
    }

    func testObjectSpanningManyCellsIsFound() {
        let background = rect(-50_000, -50_000, 100_000, 100_000)
        let index = makeIndex(snapshot([(UUID(), [background])]))
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 12_345, y: -6_789)), [background.id])
    }

    func testRebuildAfterMoveDropsOldPosition() {
        let layerID = UUID()
        var shape = rect(0, 0, 40, 40)
        let index = makeIndex(snapshot([(layerID, [shape])]))
        shape.transform = CGAffineTransform(translationX: 1000, y: 0)
        index.rebuildLayers([layerID], from: snapshot([(layerID, [shape])]))
        XCTAssertTrue(index.candidateObjectIDs(at: CGPoint(x: 20, y: 20)).isEmpty)
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 1020, y: 20)), [shape.id])
    }

    /// Old fingerprint only hashed group bounds, so moving a child inside an unchanged group
    /// left the child indexed at its old spot.
    func testMovingChildInsideUnchangedGroupBoundsIsReindexed() {
        let layerID = UUID()
        let corner1 = rect(0, 0, 10, 10)
        let corner2 = rect(190, 190, 10, 10)
        var child = rect(20, 20, 10, 10)
        func group() -> VectorShape {
            VectorShape(name: "Group", path: VectorPath(), isGroup: true, groupedShapes: [corner1, corner2, child])
        }
        let first = group()
        let index = makeIndex(snapshot([(layerID, [first])]))
        child.transform = CGAffineTransform(translationX: 100, y: 100)
        var moved = group()
        moved.id = first.id
        XCTAssertEqual(first.groupBounds, moved.groupBounds)
        index.rebuildLayers([layerID], from: snapshot([(layerID, [moved])]))
        XCTAssertFalse(index.candidateObjectIDs(at: CGPoint(x: 25, y: 25)).contains(child.id))
        XCTAssertTrue(index.candidateObjectIDs(at: CGPoint(x: 125, y: 125)).contains(child.id))
    }

    func testHiddenLayerAndPurgedLayerAreNotHit() {
        let visibleID = UUID()
        let hiddenID = UUID()
        let a = rect(0, 0, 40, 40)
        let b = rect(0, 0, 40, 40)
        var snap = snapshot([(visibleID, [a]), (hiddenID, [b])])
        snap.layers[1].isVisible = false
        let index = makeIndex(snap)
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 20, y: 20)), [a.id])
        snap.layers.removeFirst()
        index.purgeRemovedLayers(from: snap)
        XCTAssertTrue(index.candidateObjectIDs(at: CGPoint(x: 20, y: 20)).isEmpty)
    }

    func testNonFiniteBoundsAreIgnored() {
        var bad = rect(0, 0, 10, 10)
        bad.transform = CGAffineTransform(translationX: .nan, y: 0)
        let good = rect(0, 0, 10, 10)
        let index = makeIndex(snapshot([(UUID(), [bad, good])]))
        XCTAssertEqual(index.candidateObjectIDs(at: CGPoint(x: 5, y: 5)), [good.id])
    }
}
