import SwiftUI
import SwiftUI

extension DrawingCanvas {

    internal func cancelFreehandDrawing() {
        freehandPath = nil
        freehandRawPoints.removeAll()
        freehandSimplifiedPoints.removeAll()
        freehandRealtimeSmoothingPoints.removeAll()
        isFreehandDrawing = false
        activeFreehandShape = nil
    }

    internal func handleFreehandDragStart(at location: CGPoint) {
        guard !isFreehandDrawing else { return }
        isFreehandDrawing = true
        freehandRawPoints = [location]
        freehandSimplifiedPoints = []
        let startPoint = VectorPoint(location)
        freehandPath = VectorPath(elements: [.move(to: startPoint)])
        var strokeColor = getCurrentStrokeColor()

        let fillColor = getCurrentFillColor()
        if strokeColor == .clear {
            strokeColor = fillColor
        }
        let strokeStyle = StrokeStyle(
            color: strokeColor,
            width: getCurrentStrokeWidth(),
            lineCap: .round,
            lineJoin: .round,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle: FillStyle? = ApplicationSettings.shared.freehandFillMode == .fill
            ? FillStyle(color: fillColor, opacity: getCurrentFillOpacity())
            : nil
        guard let freehandPath = freehandPath else { return }
        activeFreehandShape = VectorShape(
            name: "Freehand Path",
            path: freehandPath,
            geometricType: .brushStroke,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
    }

    internal func handleFreehandDragUpdate(at location: CGPoint) {
        guard isFreehandDrawing else { return }
        MetalDrawingOptimizer.shared.trackDrawingStart()
        let smoothedLocation: CGPoint
        if ApplicationSettings.shared.advancedSmoothingEnabled && ApplicationSettings.shared.realTimeSmoothingEnabled {
            smoothedLocation = RealTimeSmoothing.applyRealTimeSmoothing(
                newPoint: location,
                recentPoints: &freehandRealtimeSmoothingPoints,
                windowSize: 5,
                strength: ApplicationSettings.shared.realTimeSmoothingStrength
            )
        } else {
            smoothedLocation = location
        }
        freehandRawPoints.append(location)
        MetalDrawingOptimizer.shared.optimizePointCollection(&freehandRawPoints, maxPoints: 500)
        updateFreehandPreview(smoothedLocation: smoothedLocation)
    }

    internal func handleFreehandDragEnd() {
        guard isFreehandDrawing else { return }
        processFreehandPath()
        freehandPreviewPath = nil
        cancelFreehandDrawing()
        document.viewState.selectedObjectIDs.removeAll()
    }

    private func updateFreehandPreview(smoothedLocation: CGPoint? = nil) {
        guard freehandRawPoints.count >= 2 else { return }
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(freehandRawPoints[0])))
        for i in 1..<freehandRawPoints.count {
            elements.append(.line(to: VectorPoint(freehandRawPoints[i])))
        }
        let previewPath = VectorPath(elements: elements)
        freehandPreviewPath = previewPath
    }

    private func processFreehandPath() {
        guard freehandRawPoints.count >= 3 else {
            return
        }
        var processedPoints = freehandRawPoints
        if ApplicationSettings.shared.advancedSmoothingEnabled {
            let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                points: processedPoints,
                iterations: ApplicationSettings.shared.chaikinSmoothingIterations,
                ratio: 0.25
            )
            processedPoints = chaikinSmoothed
        }
        let tolerance = ApplicationSettings.shared.freehandSmoothingTolerance
        let cgPoints = processedPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let optimizedCGPoints = MetalDrawingOptimizer.shared.optimizeFreehandDrawing(points: cgPoints, tolerance: tolerance)
        let simplifiedPoints = optimizedCGPoints.map { VectorPoint($0) }
        let finalCGPoints = simplifiedPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let smoothPath = ApplicationSettings.shared.advancedSmoothingEnabled ?
            createAdvancedSmoothBezierPath(from: finalCGPoints) :
            DrawingCanvasPathHelpers.createSmoothBezierPath(from: finalCGPoints)
        updateFinalFreehandShape(with: smoothPath)
    }

    private func createAdvancedSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        guard points.count >= 2 else {
            return VectorPath(elements: [])
        }
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))
        if points.count == 2 {
            elements.append(.line(to: VectorPoint(points[1])))
        } else {
            let curveSegments = CurveSmoothing.adaptiveCurveFitting(
                points: points,
                adaptiveTension: true,
                baseTension: 0.3
            )
            elements.append(contentsOf: curveSegments)
        }
        if ApplicationSettings.shared.freehandClosePath {
            elements.append(.close)
        }
        return VectorPath(elements: elements)
    }

    private func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        return DrawingCanvasPathHelpers.createSmoothBezierPath(from: points)
    }

    private func updateFinalFreehandShape(with smoothPath: VectorPath) {
        var strokeColor = getCurrentStrokeColor()
        var fillColor = getCurrentFillColor()
        if strokeColor == .clear {
            strokeColor = fillColor
        }
        if fillColor == .clear {
            let rgbSwatches = ColorManager.shared.colorDefaults.rgbSwatches
            if rgbSwatches.count > 4 {
                fillColor = rgbSwatches[4]
                strokeColor = rgbSwatches[3]
            }
        }
        let strokeStyle = StrokeStyle(
            color: strokeColor,
            width: getCurrentStrokeWidth(),
            lineCap: .round,
            lineJoin: .round,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle: FillStyle? = ApplicationSettings.shared.freehandFillMode == .fill
            ? FillStyle(color: fillColor, opacity: getCurrentFillOpacity())
            : nil
        if ApplicationSettings.shared.freehandExpandStroke {
            if let expandedPath = PathOperations.outlineStroke(
                path: smoothPath.cgPath,
                strokeStyle: strokeStyle
            ) {
                var cleanedPath = VectorPath(cgPath: expandedPath)
                cleanedPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: cleanedPath, tolerance: 1.1)
                let expandedShape = VectorShape(
                    name: "Freehand Path",
                    path: cleanedPath,
                    geometricType: .brushStroke,
                    strokeStyle: nil,
                    fillStyle: FillStyle(
                        color: strokeStyle.color,
                        opacity: strokeStyle.opacity
                    )
                )
                document.addShapeToFront(expandedShape)
            } else {
                let finalShape = VectorShape(
                    name: "Freehand Path",
                    path: smoothPath,
                    geometricType: .brushStroke,
                    strokeStyle: strokeStyle,
                    fillStyle: fillStyle
                )
                document.addShapeToFront(finalShape)
            }
        } else {
            let finalShape = VectorShape(
                name: "Freehand Path",
                path: smoothPath,
                geometricType: .brushStroke,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            document.addShapeToFront(finalShape)
        }
    }
}
