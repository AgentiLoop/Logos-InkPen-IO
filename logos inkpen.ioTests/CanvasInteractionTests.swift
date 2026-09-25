import XCTest
import Combine
import CoreGraphics
@testable import logos_inkpen_io

// MARK: - Zoom

final class ZoomMathTests: XCTestCase {

    func testStepsAreSortedAndUnique() {
        XCTAssertEqual(ZoomMath.steps, ZoomMath.steps.sorted())
        XCTAssertEqual(Set(ZoomMath.steps).count, ZoomMath.steps.count)
        XCTAssertEqual(ZoomMath.steps.first, ZoomMath.minZoom)
        XCTAssertEqual(ZoomMath.steps.last, ZoomMath.maxZoom)
    }

    func testCanZoomOutBelowSeventyFivePercent() {
        // Regression: the old step list bottomed out at 0.75.
        XCTAssertEqual(ZoomMath.stepDown(from: 0.75), 0.667)
        XCTAssertEqual(ZoomMath.clamp(0.3), 0.3)
    }

    func testZoomOutAfterFitToPageNeverZoomsIn() {
        // Regression: fit-to-page can land at e.g. 0.3; Cmd- used to jump UP to 0.75.
        let fitZoom: CGFloat = 0.3
        XCTAssertLessThan(ZoomMath.stepDown(from: fitZoom), fitZoom)
        XCTAssertGreaterThan(ZoomMath.stepUp(from: fitZoom), fitZoom)
    }

    func testStepsSaturateAtLimits() {
        XCTAssertEqual(ZoomMath.stepDown(from: ZoomMath.minZoom), ZoomMath.minZoom)
        XCTAssertEqual(ZoomMath.stepUp(from: ZoomMath.maxZoom), ZoomMath.maxZoom)
    }

    func testClampHandlesExtremesAndNonFinite() {
        XCTAssertEqual(ZoomMath.clamp(0.001), ZoomMath.minZoom)
        XCTAssertEqual(ZoomMath.clamp(10_000), ZoomMath.maxZoom)
        XCTAssertEqual(ZoomMath.clamp(.nan), 1.0)
        XCTAssertEqual(ZoomMath.clamp(.infinity), 1.0)
    }

    func testNearestStep() {
        XCTAssertEqual(ZoomMath.nearestStep(to: 0.98), 1.0)
        XCTAssertEqual(ZoomMath.nearestStep(to: 0.26), 0.25)
        XCTAssertEqual(ZoomMath.nearestStep(to: 0.0), ZoomMath.minZoom)
    }
}

// MARK: - Nudge

final class NudgeMathTests: XCTestCase {

    func testDefaultIncrementIsOnePoint() {
        // Illustrator default keyboard increment is 1 pt, regardless of grid spacing.
        XCTAssertEqual(NudgeMath.increment(gridSpacingInPoints: 9, snapToGrid: false, shift: false, option: false), 1)
    }

    func testShiftIsTenTimesAndOptionIsTenth() {
        XCTAssertEqual(NudgeMath.increment(gridSpacingInPoints: 9, snapToGrid: false, shift: true, option: false), 10)
        XCTAssertEqual(NudgeMath.increment(gridSpacingInPoints: 9, snapToGrid: false, shift: false, option: true), 0.1, accuracy: 1e-9)
    }

    func testSnapToGridUsesGridSpacing() {
        XCTAssertEqual(NudgeMath.increment(gridSpacingInPoints: 9, snapToGrid: true, shift: false, option: false), 9)
        XCTAssertEqual(NudgeMath.increment(gridSpacingInPoints: 9, snapToGrid: true, shift: true, option: false), 90)
    }

    func testSnapToGridWithInvalidSpacingFallsBackToOnePoint() {
        XCTAssertEqual(NudgeMath.increment(gridSpacingInPoints: 0, snapToGrid: true, shift: false, option: false), 1)
    }
}

// MARK: - Hit testing

final class HitTestMathTests: XCTestCase {

    private let square = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

    private func diagonalLine() -> CGPath {
        let p = CGMutablePath()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: 100, y: 100))
        return p
    }

    func testFilledShapeHitsInterior() {
        XCTAssertTrue(HitTestMath.hits(path: square, point: CGPoint(x: 50, y: 50), filled: true,
                                       fillRule: .winding, strokeWidth: 1, tolerance: 4))
    }

    func testUnfilledShapeIgnoresInteriorButHitsEdge() {
        XCTAssertFalse(HitTestMath.hits(path: square, point: CGPoint(x: 50, y: 50), filled: false,
                                        fillRule: .winding, strokeWidth: 1, tolerance: 4))
        XCTAssertTrue(HitTestMath.hits(path: square, point: CGPoint(x: 2, y: 50), filled: false,
                                       fillRule: .winding, strokeWidth: 1, tolerance: 4))
    }

    func testDiagonalLineOnlyHitsNearTheLine() {
        // Regression: bounding-box hit testing selected this line from (90, 10).
        let line = diagonalLine()
        XCTAssertFalse(HitTestMath.hits(path: line, point: CGPoint(x: 90, y: 10), filled: false,
                                        fillRule: .winding, strokeWidth: 1, tolerance: 4))
        XCTAssertTrue(HitTestMath.hits(path: line, point: CGPoint(x: 51, y: 49), filled: false,
                                       fillRule: .winding, strokeWidth: 1, tolerance: 4))
    }

    func testThickStrokeWidensHitArea() {
        let line = diagonalLine()
        let point = CGPoint(x: 60, y: 40) // ~14pt from the line
        XCTAssertFalse(HitTestMath.hits(path: line, point: point, filled: false,
                                        fillRule: .winding, strokeWidth: 1, tolerance: 4))
        XCTAssertTrue(HitTestMath.hits(path: line, point: point, filled: false,
                                       fillRule: .winding, strokeWidth: 30, tolerance: 4))
    }

    func testEvenOddHoleIsNotHit() {
        let donut = CGMutablePath()
        donut.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
        donut.addRect(CGRect(x: 25, y: 25, width: 50, height: 50))
        XCTAssertFalse(HitTestMath.hits(path: donut, point: CGPoint(x: 50, y: 50), filled: true,
                                        fillRule: .evenOdd, strokeWidth: 0, tolerance: 1))
        XCTAssertTrue(HitTestMath.hits(path: donut, point: CGPoint(x: 10, y: 50), filled: true,
                                       fillRule: .evenOdd, strokeWidth: 0, tolerance: 1))
    }

    func testFarPointAndInvalidInputMiss() {
        XCTAssertFalse(HitTestMath.hits(path: square, point: CGPoint(x: 500, y: 500), filled: true,
                                        fillRule: .winding, strokeWidth: 1, tolerance: 4))
        XCTAssertFalse(HitTestMath.hits(path: square, point: CGPoint(x: CGFloat.nan, y: 0), filled: true,
                                        fillRule: .winding, strokeWidth: 1, tolerance: 4))
        XCTAssertFalse(HitTestMath.hits(path: CGMutablePath(), point: .zero, filled: true,
                                        fillRule: .winding, strokeWidth: 1, tolerance: 4))
    }

    func testToleranceIsConstantInScreenSpace() {
        XCTAssertEqual(HitTestMath.canvasTolerance(zoom: 1), 4)
        XCTAssertEqual(HitTestMath.canvasTolerance(zoom: 4), 1)
        XCTAssertEqual(HitTestMath.canvasTolerance(zoom: 0.5), 8)
        XCTAssertEqual(HitTestMath.canvasTolerance(zoom: 0), 4)
    }
}

// MARK: - Dirty tracking

private final class RecordingCommand: BaseCommand {
    var executed = 0
    var undone = 0
    override func execute(on document: VectorDocument) { executed += 1 }
    override func undo(on document: VectorDocument) { undone += 1 }
}

final class CommandManagerChangeTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testRecordUndoRedoEachSignalContentChange() {
        let document = VectorDocument()
        let manager = document.commandManager
        manager.document = document
        var changes = 0
        manager.contentDidChange.sink { changes += 1 }.store(in: &cancellables)

        let command = RecordingCommand()
        manager.recordCompletedCommand(command)
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(manager.canUndo)

        manager.undo()
        XCTAssertEqual(changes, 2)
        XCTAssertEqual(command.undone, 1)
        XCTAssertTrue(manager.canRedo)

        manager.redo()
        XCTAssertEqual(changes, 3)
        XCTAssertEqual(command.executed, 1)
    }

    func testClearDoesNotSignalContentChange() {
        let document = VectorDocument()
        let manager = document.commandManager
        manager.document = document
        var changes = 0
        manager.contentDidChange.sink { changes += 1 }.store(in: &cancellables)
        manager.clear()
        XCTAssertEqual(changes, 0)
    }
}
