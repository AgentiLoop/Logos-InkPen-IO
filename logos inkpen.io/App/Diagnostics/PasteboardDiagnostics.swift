import SwiftUI

class PasteboardDiagnostics {
    static let shared = PasteboardDiagnostics()

    private init() {}

    func runDiagnostics(on document: VectorDocument) -> DiagnosticReport {
        var report = DiagnosticReport()
        report.layerStructure = testLayerStructure(document)
        report.backgroundShapes = testBackgroundShapes(document)
        report.hitTesting = testHitTestingSimulation(document)
        report.realWorldScenarios = testRealWorldScenarios(document)
        report.performance = testPerformance(document)
        return report
    }

    private func testLayerStructure(_ document: VectorDocument) -> LayerStructureTest {
        var test = LayerStructureTest()
        test.layerCount = document.snapshot.layers.count
        test.expectedLayerCount = 3
        test.layerCountCorrect = (test.layerCount == test.expectedLayerCount)
        if document.snapshot.layers.count >= 3 {
            test.pasteboardLayerName = document.snapshot.layers[0].name
            test.canvasLayerName = document.snapshot.layers[1].name
            test.workingLayerName = document.snapshot.layers[2].name
            test.layerNamesCorrect = (
                test.pasteboardLayerName == "Pasteboard" &&
                test.canvasLayerName == "Canvas" &&
                test.workingLayerName == "Layer 1"
            )
            test.pasteboardLocked = document.snapshot.layers[0].isLocked
            test.canvasLocked = document.snapshot.layers[1].isLocked
            test.workingLayerLocked = document.snapshot.layers[2].isLocked
            test.lockStatusCorrect = (
                test.pasteboardLocked == true &&
                test.canvasLocked == true &&
                test.workingLayerLocked == false
            )
        }
        test.passed = test.layerCountCorrect && test.layerNamesCorrect && test.lockStatusCorrect
        Log.error("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        return test
    }

    private func testBackgroundShapes(_ document: VectorDocument) -> BackgroundShapesTest {
        var test = BackgroundShapesTest()
        if document.snapshot.layers.count >= 2 {
            let pasteboardShapes = document.getShapesForLayer(0)
            test.pasteboardShapeCount = pasteboardShapes.count
            if pasteboardShapes.count > 0 {
                let pasteboardShape = pasteboardShapes[0]
                test.pasteboardShapeName = pasteboardShape.name
                test.pasteboardBounds = pasteboardShape.bounds
            }
            let canvasShapes = document.getShapesForLayer(1)
            test.canvasShapeCount = canvasShapes.count
            if canvasShapes.count > 0 {
                let canvasShape = canvasShapes[0]
                test.canvasShapeName = canvasShape.name
                test.canvasBounds = canvasShape.bounds
            }
            test.pasteboardShapeCorrect = (
                test.pasteboardShapeCount == 1 &&
                test.pasteboardShapeName == "Pasteboard Background"
            )
            test.canvasShapeCorrect = (
                test.canvasShapeCount == 1 &&
                test.canvasShapeName == "Canvas Background"
            )
            if let canvasBounds = test.canvasBounds,

               let pasteboardBounds = test.pasteboardBounds {
                let expectedPasteboardWidth = canvasBounds.width * 10
                let expectedPasteboardHeight = canvasBounds.height * 10
                test.sizingCorrect = (
                    abs(pasteboardBounds.width - expectedPasteboardWidth) < 1.0 &&
                    abs(pasteboardBounds.height - expectedPasteboardHeight) < 1.0
                )
                let expectedOriginX = (canvasBounds.width - pasteboardBounds.width) / 2
                let expectedOriginY = (canvasBounds.height - pasteboardBounds.height) / 2
                test.positioningCorrect = (
                    abs(pasteboardBounds.origin.x - expectedOriginX) < 1.0 &&
                    abs(pasteboardBounds.origin.y - expectedOriginY) < 1.0
                )
            }
        }
        test.passed = test.pasteboardShapeCorrect && test.canvasShapeCorrect && test.sizingCorrect && test.positioningCorrect
        Log.error("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        return test
    }

    private func testHitTestingSimulation(_ document: VectorDocument) -> HitTestingTest {
        var test = HitTestingTest()
        guard document.snapshot.layers.count >= 3 else {
            test.passed = false
            return test
        }
        let pasteboardShape = document.getShapeAtIndex(layerIndex: 0, shapeIndex: 0)
        let pasteboardBounds = pasteboardShape?.bounds ?? .zero
        let pasteboardOnlyPoint = CGPoint(
            x: pasteboardBounds.minX + 100,
            y: pasteboardBounds.minY + 100
        )
        let pasteboardHit = simulateHitTest(document: document, at: pasteboardOnlyPoint)
        test.pasteboardOnlyHit = pasteboardHit
        test.pasteboardHitCorrect = (
            pasteboardHit.hitShape?.name == "Pasteboard Background" &&
            pasteboardHit.layerIndex == 0
        )
        let canvasShape = document.getShapeAtIndex(layerIndex: 1, shapeIndex: 0)
        let canvasBounds = canvasShape?.bounds ?? .zero
        let canvasPoint = CGPoint(x: canvasBounds.midX, y: canvasBounds.midY)
        let canvasHit = simulateHitTest(document: document, at: canvasPoint)
        test.canvasPriorityHit = canvasHit
        test.canvasPriorityCorrect = (
            canvasHit.hitShape?.name == "Canvas Background" &&
            canvasHit.layerIndex == 1
        )
        test.layerIterationTest = testLayerIteration(document)
        test.passed = test.pasteboardHitCorrect && test.canvasPriorityCorrect && test.layerIterationTest.passed
        Log.error("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        return test
    }

    private func testLayerIteration(_ document: VectorDocument) -> LayerIterationTest {
        var test = LayerIterationTest()

        let testPoint = CGPoint(x: 100, y: 100)

        var testedLayers: [String] = []
        var testedShapes: [String] = []
        for layerIndex in document.snapshot.layers.indices.reversed() {
            let layer = document.snapshot.layers[layerIndex]
            testedLayers.append("Layer \(layerIndex): \(layer.name)")
            if !layer.isVisible { continue }
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer.reversed() {
                if !shape.isVisible { continue }
                testedShapes.append("Layer \(layerIndex) - Shape: \(shape.name)")
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    let isHit = shapeBounds.contains(testPoint)
                    if isHit {
                        break
                    }
                }
            }
        }
        let expectedLayers = ["Layer 2: Layer 1", "Layer 1: Canvas", "Layer 0: Pasteboard"]
        test.allLayersTested = expectedLayers.allSatisfy { expected in
            testedLayers.contains(expected)
        }
        let expectedShapes = ["Layer 1 - Shape: Canvas Background", "Layer 0 - Shape: Pasteboard Background"]
        test.allBackgroundShapesTested = expectedShapes.allSatisfy { expected in
            testedShapes.contains(expected)
        }
        test.passed = test.allLayersTested && test.allBackgroundShapesTested
        return test
    }

    private func testRealWorldScenarios(_ document: VectorDocument) -> RealWorldScenariosTest {
        var test = RealWorldScenariosTest()

        let pasteboardShape = document.getShapeAtIndex(layerIndex: 0, shapeIndex: 0)
        let pasteboardBounds = pasteboardShape?.bounds ?? .zero
        let canvasShape = document.getShapeAtIndex(layerIndex: 1, shapeIndex: 0)
        let canvasBounds = canvasShape?.bounds ?? .zero
        let pasteboardObjectLocation = CGPoint(
            x: pasteboardBounds.minX + 50,
            y: pasteboardBounds.minY + 50
        )
        let pasteboardObject = VectorShape.rectangle(
            at: pasteboardObjectLocation,
            size: CGSize(width: 50, height: 50)
        )
        var pasteboardTestShape = pasteboardObject
        pasteboardTestShape.name = "Test Pasteboard Object"
        pasteboardTestShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0)), opacity: 1.0)
        let canvasObjectLocation = CGPoint(
            x: canvasBounds.midX - 25,
            y: canvasBounds.midY - 25
        )
        let canvasObject = VectorShape.rectangle(
            at: canvasObjectLocation,
            size: CGSize(width: 50, height: 50)
        )
        var canvasTestShape = canvasObject
        canvasTestShape.name = "Test Canvas Object"
        canvasTestShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 0, green: 0, blue: 1)), opacity: 1.0)
        document.appendShapeToLayerUnified(layerIndex: 2, shape: pasteboardTestShape)
        document.appendShapeToLayerUnified(layerIndex: 2, shape: canvasTestShape)
        let pasteboardObjectCenter = CGPoint(
            x: pasteboardObjectLocation.x + 25,
            y: pasteboardObjectLocation.y + 25
        )
        let pasteboardObjectHit = simulateHitTest(document: document, at: pasteboardObjectCenter)
        test.pasteboardObjectHit = pasteboardObjectHit
        test.pasteboardObjectHitCorrect = (
            pasteboardObjectHit.hitShape?.name == "Test Pasteboard Object" &&
            pasteboardObjectHit.layerIndex == 2
        )
        let canvasObjectCenter = CGPoint(
            x: canvasObjectLocation.x + 25,
            y: canvasObjectLocation.y + 25
        )
        let canvasObjectHit = simulateHitTest(document: document, at: canvasObjectCenter)
        test.canvasObjectHit = canvasObjectHit
        test.canvasObjectHitCorrect = (
            canvasObjectHit.hitShape?.name == "Test Canvas Object" &&
            canvasObjectHit.layerIndex == 2
        )
        let emptyPasteboardPoint = CGPoint(
            x: pasteboardBounds.minX + 200,
            y: pasteboardBounds.minY + 200
        )
        let emptyPasteboardHit = simulateHitTest(document: document, at: emptyPasteboardPoint)
        test.emptyPasteboardHit = emptyPasteboardHit
        test.emptyPasteboardHitCorrect = (
            emptyPasteboardHit.hitShape?.name == "Pasteboard Background" &&
            emptyPasteboardHit.layerIndex == 0
        )
        document.removeShapesUnified(layerIndex: 2, where: { shape in
            shape.name == "Test Pasteboard Object" || shape.name == "Test Canvas Object"
        })
        test.passed = test.pasteboardObjectHitCorrect && test.canvasObjectHitCorrect && test.emptyPasteboardHitCorrect
        Log.error("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        return test
    }

    private func testPerformance(_ document: VectorDocument) -> PerformanceTest {
        var test = PerformanceTest()

        let originalShapeCount = document.getShapesForLayer(2).count
        for i in 0..<100 {
            let testRect = VectorShape.rectangle(
                at: CGPoint(x: Double(i * 5), y: Double(i * 5)),
                size: CGSize(width: 10, height: 10)
            )
            var testShape = testRect
            testShape.name = "Perf Test \(i)"
            document.appendShapeToLayerUnified(layerIndex: 2, shape: testShape)
        }
        let testPoint = CGPoint(x: 250, y: 250)
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<1000 {
            simulateHitTest(document: document, at: testPoint)
        }
        let endTime = CFAbsoluteTimeGetCurrent()
        test.totalTime = endTime - startTime
        test.averageTimePerHitTest = test.totalTime / 1000.0
        let shapes = document.getShapesForLayer(2)
        let shapesToRemove = shapes.count - originalShapeCount
        if shapesToRemove > 0 {
            let shapeIDsToRemove = shapes.suffix(shapesToRemove).map { $0.id }
            document.removeShapesUnified(layerIndex: 2, where: { shapeIDsToRemove.contains($0.id) })
        }
        test.passed = test.averageTimePerHitTest < 0.001
        Log.error("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        return test
    }

    @discardableResult
    private func simulateHitTest(document: VectorDocument, at location: CGPoint) -> HitTestResult {
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        var testedLayers: [String] = []
        var testedShapes: [String] = []
        for layerIndex in document.snapshot.layers.indices.reversed() {
            let layer = document.snapshot.layers[layerIndex]
            testedLayers.append("Layer \(layerIndex): \(layer.name)")
            if !layer.isVisible { continue }
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer.reversed() {
                if !shape.isVisible { continue }
                testedShapes.append("Layer \(layerIndex) - Shape: \(shape.name)")
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")

                var isHit = false
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                } else {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                }
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    break
                }
            }
            if hitShape != nil { break }
        }
        return HitTestResult(
            hitShape: hitShape,
            layerIndex: hitLayerIndex,
            testLocation: location
        )
    }
}

struct DiagnosticReport {
    var layerStructure = LayerStructureTest()
    var backgroundShapes = BackgroundShapesTest()
    var hitTesting = HitTestingTest()
    var realWorldScenarios = RealWorldScenariosTest()
    var performance = PerformanceTest()

    var overallPassed: Bool {
        return layerStructure.passed &&
               backgroundShapes.passed &&
               hitTesting.passed &&
               realWorldScenarios.passed &&
               performance.passed
    }

    func printSummary() {
        Log.error("Layer Structure:     \(layerStructure.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        Log.error("Background Shapes:   \(backgroundShapes.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        Log.error("Hit Testing:         \(hitTesting.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        Log.error("Real-World Scenarios:\(realWorldScenarios.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        Log.error("Performance:         \(performance.passed ? "✓ PASS" : "✗ FAIL")", category: .error)
        Log.error("OVERALL:             \(overallPassed ? "✅ PASS" : "❌ FAIL")", category: .error)
    }
}

struct LayerStructureTest {
    var layerCount = 0
    var expectedLayerCount = 3
    var layerCountCorrect = false
    var pasteboardLayerName = ""
    var canvasLayerName = ""
    var workingLayerName = ""
    var layerNamesCorrect = false
    var pasteboardLocked = false
    var canvasLocked = false
    var workingLayerLocked = false
    var lockStatusCorrect = false
    var passed = false
}

struct BackgroundShapesTest {
    var pasteboardShapeCount = 0
    var pasteboardShapeName = ""
    var pasteboardBounds: CGRect?
    var pasteboardShapeCorrect = false
    var canvasShapeCount = 0
    var canvasShapeName = ""
    var canvasBounds: CGRect?
    var canvasShapeCorrect = false
    var sizingCorrect = false
    var positioningCorrect = false
    var passed = false
}

struct HitTestingTest {
    var pasteboardOnlyHit = HitTestResult()
    var pasteboardHitCorrect = false
    var canvasPriorityHit = HitTestResult()
    var canvasPriorityCorrect = false
    var layerIterationTest = LayerIterationTest()
    var passed = false
}

struct LayerIterationTest {
    var allLayersTested = false
    var allBackgroundShapesTested = false
    var passed = false
}

struct RealWorldScenariosTest {
    var pasteboardObjectHit = HitTestResult()
    var pasteboardObjectHitCorrect = false
    var canvasObjectHit = HitTestResult()
    var canvasObjectHitCorrect = false
    var emptyPasteboardHit = HitTestResult()
    var emptyPasteboardHitCorrect = false
    var passed = false
}

struct PerformanceTest {
    var totalTime: Double = 0.0
    var averageTimePerHitTest: Double = 0.0
    var passed = false
}

struct HitTestResult {
    var hitShape: VectorShape?
    var layerIndex: Int?
    var testLocation = CGPoint.zero
}
