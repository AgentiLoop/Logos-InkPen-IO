import XCTest
import CoreGraphics
@testable import logos_inkpen_io

final class PathCuttingTests: XCTestCase {

    private func square() -> [PathElement] {
        [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(10, 0)), .line(to: VectorPoint(10, 10)),
         .line(to: VectorPoint(0, 10)), .line(to: VectorPoint(0, 0)), .close]
    }

    func testOpenPathCutOnSegmentGivesTwoPaths() {
        let open: [PathElement] = [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(10, 0)), .line(to: VectorPoint(10, 10))]
        let pieces = cuttingPath(open, at: .segment(elementIndex: 1, near: CGPoint(x: 5, y: 1)))
        XCTAssertEqual(pieces?.count, 2)
        XCTAssertEqual(pieces?[0].count, 2)
        XCTAssertEqual(pieces?[1].count, 3)
        XCTAssertEqual(pieces?[0].last?.endpointCGPoint, CGPoint(x: 5, y: 0))
        XCTAssertEqual(pieces?[1].first?.endpointCGPoint, CGPoint(x: 5, y: 0))
    }

    func testOpenPathCutOnEndAnchorDoesNothing() {
        let open: [PathElement] = [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(10, 0)), .line(to: VectorPoint(10, 10))]
        XCTAssertNil(cuttingPath(open, at: .anchor(elementIndex: 0)))
        XCTAssertNil(cuttingPath(open, at: .anchor(elementIndex: 2)))
    }

    func testOpenPathCutOnInteriorAnchor() {
        let open: [PathElement] = [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(10, 0)), .line(to: VectorPoint(10, 10))]
        let pieces = cuttingPath(open, at: .anchor(elementIndex: 1))
        XCTAssertEqual(pieces?.count, 2)
        XCTAssertEqual(pieces?[0].count, 2)
        XCTAssertEqual(pieces?[1].count, 2)
    }

    func testClosedPathCutOnSegmentGivesOneOpenPathWithFiveSegments() {
        let pieces = cuttingPath(square(), at: .segment(elementIndex: 2, near: CGPoint(x: 10, y: 5)))
        XCTAssertEqual(pieces?.count, 1)
        XCTAssertEqual(pieces?[0].count, 6)
        XCTAssertEqual(pieces?[0].first?.endpointCGPoint, CGPoint(x: 10, y: 5))
        XCTAssertEqual(pieces?[0].last?.endpointCGPoint, CGPoint(x: 10, y: 5))
    }

    func testClosedPathCutOnStartAnchorKeepsFourSegments() {
        let pieces = cuttingPath(square(), at: .anchor(elementIndex: 0))
        XCTAssertEqual(pieces?.count, 1)
        XCTAssertEqual(pieces?[0].count, 5)
    }

    func testCurveSplitKeepsEndpoints() {
        let curve: [PathElement] = [.move(to: VectorPoint(0, 0)),
                                    .curve(to: VectorPoint(10, 0), control1: VectorPoint(0, 10), control2: VectorPoint(10, 10))]
        let pieces = cuttingPath(curve, at: .segment(elementIndex: 1, near: CGPoint(x: 5, y: 7.5)))
        XCTAssertEqual(pieces?.count, 2)
        XCTAssertEqual(pieces?[1].last?.endpointCGPoint, CGPoint(x: 10, y: 0))
        let cut = pieces?[0].last?.endpointCGPoint
        XCTAssertEqual(Double(cut?.x ?? 0), 5, accuracy: 0.1)
        XCTAssertEqual(Double(cut?.y ?? 0), 7.5, accuracy: 0.1)
    }
}

final class KnifeCuttingTests: XCTestCase {

    private func squarePath() -> CGPath { CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil) }

    func testKnifeAcrossSquareGivesTwoPiecesCoveringTheSquare() {
        let pieces = knifeCutPieces(shapePath: squarePath(), fillRule: .winding, knife: [CGPoint(x: 5, y: -3), CGPoint(x: 5, y: 13)])
        XCTAssertEqual(pieces?.count, 2)
        let total = (pieces ?? []).reduce(0.0) { $0 + Double($1.boundingBoxOfPath.width * $1.boundingBoxOfPath.height) }
        XCTAssertEqual(total, 100, accuracy: 0.01)
        let widths = (pieces ?? []).map { Double($0.boundingBoxOfPath.width) }.sorted()
        XCTAssertEqual(widths[0], 5, accuracy: 0.01)
        XCTAssertEqual(widths[1], 5, accuracy: 0.01)
    }

    func testKnifeThatStopsInsideStillCutsLikeInfiniteLine() {
        let pieces = knifeCutPieces(shapePath: squarePath(), fillRule: .winding, knife: [CGPoint(x: -2, y: 5), CGPoint(x: 4, y: 5)])
        XCTAssertEqual(pieces?.count, 2)
    }

    func testKnifeMissingShapeGivesNil() {
        XCTAssertNil(knifeCutPieces(shapePath: squarePath(), fillRule: .winding, knife: [CGPoint(x: 20, y: -3), CGPoint(x: 20, y: 13)]))
    }

    func testKnifeAcrossUShapeGivesThreePieces() {
        let u = CGMutablePath()
        u.addLines(between: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 7, y: 10),
                             CGPoint(x: 7, y: 3), CGPoint(x: 3, y: 3), CGPoint(x: 3, y: 10), CGPoint(x: 0, y: 10)])
        u.closeSubpath()
        let pieces = knifeCutPieces(shapePath: u, fillRule: .winding, knife: [CGPoint(x: -1, y: 6), CGPoint(x: 11, y: 6)])
        XCTAssertEqual(pieces?.count, 3)
    }
}
