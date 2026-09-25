import SwiftUI
import simd

struct MarkerPoint {
    let location: CGPoint
    let pressure: Double

    init(location: CGPoint, pressure: Double = 1.0) {
        self.location = location
        self.pressure = pressure
    }
}

extension DrawingCanvas {

    internal func cancelMarkerDrawing() {
        markerPath = nil
        markerRawPoints.removeAll()
        markerSimplifiedPoints.removeAll()
        isMarkerDrawing = false
        activeMarkerShape = nil
    }

    internal func handleMarkerDragStart(at location: CGPoint) {
        guard !isMarkerDrawing else { return }
        isMarkerDrawing = true
        markerRawPoints = [MarkerPoint(location: location, pressure: 1.0)]
        markerSimplifiedPoints = []
        PressureManager.shared.resetForNewDrawing()
        let startPoint = VectorPoint(location)
        markerPath = VectorPath(elements: [.move(to: startPoint)])
        let strokeColor = ApplicationSettings.shared.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth()
        let markerFillColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerOpacity = ApplicationSettings.shared.currentMarkerOpacity
        let actualStrokeWidth = (document.strokeDefaults.placement == .center) ? strokeWidth : strokeWidth * 2.0
        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: actualStrokeWidth,
            placement: .center,
            lineCap: .round,
            lineJoin: .round,
            opacity: markerOpacity
        ) : nil
        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: markerOpacity
        )
        guard let path = markerPath else { return }
        activeMarkerShape = VectorShape(
            name: "Marker Stroke",
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
    }

    internal func handleMarkerDragUpdate(at location: CGPoint, pressure: Double? = nil) {
        guard isMarkerDrawing else { return }
        let actualPressure = pressure ?? PressureManager.shared.currentPressure
        let markerPoint = MarkerPoint(location: location, pressure: actualPressure)
        markerRawPoints.append(markerPoint)
        updateMarkerPreview()
        if markerRawPoints.count > 1000 {
            markerRawPoints = Array(markerRawPoints.suffix(800))
        }
    }

    internal func handleMarkerDragEnd() {
        guard isMarkerDrawing else { return }
        if let preview = markerPreviewPath {
            finalizeMarkerFromPreview(preview)
        } else {
            processMarkerStroke()
        }
        markerPreviewPath = nil
        cancelMarkerDrawing()
        document.viewState.selectedObjectIDs.removeAll()
    }

    private func calculateMarkerPressure(at location: CGPoint) -> Double {
        if !appState.pressureSensitivityEnabled {
            return 1.0
        }
        guard markerRawPoints.count > 1,
              let lastPointData = markerRawPoints.last else { return 1.0 }
        let lastPoint = lastPointData.location
        let distance = location.distance(to: lastPoint)
        let maxSpeed: Double = 100.0
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5)
        let sensitivity = 0.5
        let pressureVariation = (basePressure - 0.5) * sensitivity
        let finalPressure = max(0.1, min(1.0, 0.5 + pressureVariation))
        return finalPressure
    }

    private func updateMarkerPreview() {
        guard markerRawPoints.count >= 2 else { return }
        let previewPath = generateMarkerLivePreviewPath()
        markerPreviewPath = previewPath
    }

    private func generateMarkerLivePreviewPath() -> VectorPath {
        guard markerRawPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(markerRawPoints[0].location))])
        }
        let rawPointLocations = markerRawPoints.map { $0.location }
        return createSmoothMarkerStroke(
            centerPoints: rawPointLocations,
            recentRawPoints: markerRawPoints
        )
    }

    private func processMarkerStroke() {
        guard markerRawPoints.count >= 2,
              activeMarkerShape != nil,
              document.selectedLayerIndex != nil else {
            return
        }
        let rawPointLocations = markerRawPoints.map { $0.location }

        var processedPoints = rawPointLocations
        if ApplicationSettings.shared.advancedSmoothingEnabled {
            let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                points: processedPoints,
                iterations: ApplicationSettings.shared.chaikinSmoothingIterations,
                ratio: 0.25
            )
            processedPoints = chaikinSmoothed
        }
        let smoothingTolerance = (ApplicationSettings.shared.currentMarkerSmoothingTolerance / 100.0) * 3.0
        markerSimplifiedPoints = ApplicationSettings.shared.advancedSmoothingEnabled ?
            CurveSmoothing.improvedDouglassPeucker(
                points: processedPoints,
                tolerance: smoothingTolerance,
                preserveSharpCorners: ApplicationSettings.shared.preserveSharpCorners
            ) :
            DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: smoothingTolerance)
        let minPoints = appState.pressureSensitivityEnabled ? 8 : 20
        if markerSimplifiedPoints.count < minPoints && processedPoints.count > 2 {
            let minTolerance = smoothingTolerance * 0.05
            markerSimplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: minTolerance)
            if markerSimplifiedPoints.count < minPoints {
                let stepSize = max(1, processedPoints.count / (minPoints + 10))
                markerSimplifiedPoints = []
                for i in Swift.stride(from: 0, to: processedPoints.count, by: stepSize) {
                    markerSimplifiedPoints.append(processedPoints[i])
                }
                if let last = processedPoints.last, markerSimplifiedPoints.last != last {
                    markerSimplifiedPoints.append(last)
                }
            }
        }
        let markerStrokePath = createFinalMarkerStroke(
            centerPoints: markerSimplifiedPoints,
            recentRawPoints: markerRawPoints
        )
        let strokeColor = ApplicationSettings.shared.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth()
        let markerFillColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerOpacity = ApplicationSettings.shared.currentMarkerOpacity
        let actualStrokeWidth = (document.strokeDefaults.placement == .center) ? strokeWidth : strokeWidth * 2.0
        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: actualStrokeWidth,
            placement: .center,
            lineCap: .round,
            lineJoin: .round,
            opacity: markerOpacity
        ) : nil
        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: markerOpacity
        )
        var finalShape = VectorShape(
            name: "Marker Stroke",
            path: markerStrokePath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        if ApplicationSettings.shared.markerRemoveOverlap {
            var currentPath = finalShape.path.cgPath
            var cleanedFillPath: CGPath? = nil
            cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .evenOdd) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .evenOdd) }
            if let cleaned = cleanedFillPath, !cleaned.isEmpty, isPathBoundsFinite(cleaned.boundingBox) {
                currentPath = cleaned
                finalShape.path = VectorPath(cgPath: cleaned)
            }
            if let stroke = finalShape.strokeStyle, stroke.width > 0 {
                if let expandedStroke = PathOperations.outlineStroke(path: currentPath, strokeStyle: stroke) {
                    var unionedStroke: CGPath? = nil
                    unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding)
                    if unionedStroke == nil {
                        unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .evenOdd)
                    }
                    let strokeToMerge = unionedStroke ?? expandedStroke

                    var merged: CGPath? = nil
                    merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .winding)
                    if merged == nil {
                        merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .evenOdd)
                    }
                    if let mergedPath = merged, !mergedPath.isEmpty, isPathBoundsFinite(mergedPath.boundingBox) {
                        finalShape.path = VectorPath(cgPath: mergedPath)
                        finalShape.strokeStyle = nil
                    }
                }
            }
            finalShape.path = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalShape.path, tolerance: 1.1)
        } else {
            finalShape.path = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalShape.path, tolerance: 1.1)
        }
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.addShapeToFrontOfUnifiedSystem(finalShape, layerIndex: layerIndex)
        let objectIDs = [finalShape.id]
        let oldShapes: [UUID: VectorShape] = [:]

        var newShapes: [UUID: VectorShape] = [:]
        newShapes[finalShape.id] = finalShape
        let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
        document.commandManager.execute(command)
    }

    private func finalizeMarkerFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }
        let strokeColor = ApplicationSettings.shared.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth()
        let markerFillColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerOpacity = ApplicationSettings.shared.currentMarkerOpacity
        let actualStrokeWidth = (document.strokeDefaults.placement == .center) ? strokeWidth : strokeWidth * 2.0
        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: actualStrokeWidth,
            placement: .center,
            lineCap: .round,
            lineJoin: .round,
            opacity: markerOpacity
        ) : nil
        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: markerOpacity
        )
        var finalPath = preview
        var finalStrokeStyle = strokeStyle
        if ApplicationSettings.shared.markerRemoveOverlap {
            var currentPath = preview.cgPath
            var cleanedFillPath: CGPath? = nil
            cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .evenOdd) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .evenOdd) }
            if let cleaned = cleanedFillPath, !cleaned.isEmpty, isPathBoundsFinite(cleaned.boundingBox) {
                currentPath = cleaned
                finalPath = VectorPath(cgPath: cleaned)
            }
            if let stroke = strokeStyle, stroke.width > 0 {
                if let expandedStroke = PathOperations.outlineStroke(path: currentPath, strokeStyle: stroke) {
                    var unionedStroke: CGPath? = nil
                    unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding)
                    if unionedStroke == nil {
                        unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .evenOdd)
                    }
                    let strokeToMerge = unionedStroke ?? expandedStroke

                    var merged: CGPath? = nil
                    merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .winding)
                    if merged == nil {
                        merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .evenOdd)
                    }
                    if let mergedPath = merged, !mergedPath.isEmpty, isPathBoundsFinite(mergedPath.boundingBox) {
                        finalPath = VectorPath(cgPath: mergedPath)
                        finalStrokeStyle = nil
                    }
                }
            }
            finalPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalPath, tolerance: 1.1)
        } else {
            finalPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: finalPath, tolerance: 1.1)
        }
        let shape = VectorShape(name: "Marker Stroke", path: finalPath, geometricType: .brushStroke, strokeStyle: finalStrokeStyle, fillStyle: fillStyle)
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.addShapeToFrontOfUnifiedSystem(shape, layerIndex: layerIndex)
        let objectIDs = [shape.id]
        let oldShapes: [UUID: VectorShape] = [:]

        var newShapes: [UUID: VectorShape] = [:]
        newShapes[shape.id] = shape
        let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
        document.commandManager.execute(command)
    }

    private func createSmoothMarkerStroke(centerPoints: [CGPoint], recentRawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return createMarkerDot(at: centerPoints[0])
        }
        return createVariableWidthMarkerStroke(centerPoints: centerPoints, rawPoints: recentRawPoints)
    }

    private func createFinalMarkerStroke(centerPoints: [CGPoint], recentRawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return createMarkerDot(at: centerPoints[0])
        }
        return createVariableWidthMarkerStroke(centerPoints: centerPoints, rawPoints: recentRawPoints)
    }

    private func createVariableWidthMarkerStroke(centerPoints: [CGPoint], rawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return createMarkerDot(at: centerPoints[0])
        }
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            let pressure = getPressureAtPoint(point, rawPoints: rawPoints)

            var finalThickness = ApplicationSettings.shared.currentMarkerTipSize

            let strokeLength = Double(centerPoints.count)
            let isShortStroke = strokeLength < 5
            if isShortStroke {
                if progress < 0.3 {
                    finalThickness *= pow(progress / 0.3, 1.5)
                } else if progress > 0.7 {
                    let endProgress = (1.0 - progress) / 0.3
                    finalThickness *= pow(endProgress, 1.5)
                }
            } else {
                let startTaper = max(0.25, ApplicationSettings.shared.currentMarkerTaperStart)
                let endTaper = max(0.25, ApplicationSettings.shared.currentMarkerTaperEnd)
                if progress < startTaper {
                    finalThickness *= pow(progress / startTaper, 1.5)
                } else if progress > (1.0 - endTaper) {
                    let endProgress = (1.0 - progress) / endTaper
                    finalThickness *= pow(endProgress, 1.5)
                }
            }
            let feathering = ApplicationSettings.shared.currentMarkerFeathering
            if isShortStroke {
                finalThickness *= (1.0 - feathering * 0.15)
            } else {
                finalThickness *= (1.0 - feathering * 0.2)
            }
            if appState.pressureSensitivityEnabled {
                var curve: [CGPoint] = []
                if let data = UserDefaults.standard.array(forKey: "pressureCurve") {
                    curve = data.compactMap { item -> CGPoint? in
                        if let dict = item as? [String: Any],
                           let x = dict["x"] as? Double,

                           let y = dict["y"] as? Double {
                            return CGPoint(x: x, y: y)
                        } else if let dict = item as? [String: Double],
                                  let x = dict["x"],

                                  let y = dict["y"] {
                            return CGPoint(x: x, y: y)
                        }
                        return nil
                    }
                }
                if curve.count < 2 {
                    curve = [
                        CGPoint(x: 0.0, y: 0.0),
                        CGPoint(x: 0.25, y: 0.25),
                        CGPoint(x: 0.5, y: 0.5),
                        CGPoint(x: 0.75, y: 0.75),
                        CGPoint(x: 1.0, y: 1.0)
                    ]
                }
                let mappedPressure = getThicknessFromPressureCurve(pressure: pressure, curve: curve)
                finalThickness *= mappedPressure
            }
            let minThickness = ApplicationSettings.shared.currentMarkerMinTaperThickness
            if finalThickness > 0 {
                finalThickness = max(finalThickness, minThickness)
            }
            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        let leftEdgePoints = generateMarkerOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateMarkerOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        return createSimpleMarkerOutline(leftEdgePoints: leftEdgePoints, rightEdgePoints: rightEdgePoints)
    }

    private func getPressureAtPoint(_ point: CGPoint, rawPoints: [MarkerPoint]) -> Double {
        guard rawPoints.count > 0 else {
            return 1.0
        }
        var closestDistance1 = Double.infinity
        var closestDistance2 = Double.infinity
        var closestPressure1: Double = 1.0
        var closestPressure2: Double = 1.0
        for rawPoint in rawPoints {
            let distance = point.distance(to: rawPoint.location)
            if distance < closestDistance1 {
                closestDistance2 = closestDistance1
                closestPressure2 = closestPressure1
                closestDistance1 = distance
                closestPressure1 = rawPoint.pressure
            } else if distance < closestDistance2 {
                closestDistance2 = distance
                closestPressure2 = rawPoint.pressure
            }
        }
        if closestDistance1 < Double.infinity && closestDistance2 < Double.infinity {
            let totalDistance = closestDistance1 + closestDistance2
            if totalDistance > 0 {
                let weight1 = closestDistance2 / totalDistance
                let weight2 = closestDistance1 / totalDistance
                let interpolatedPressure = closestPressure1 * weight1 + closestPressure2 * weight2
                return interpolatedPressure
            }
        }
        return closestPressure1
    }

    private func generateMarkerOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
        var offsetPoints: [CGPoint] = []
        for i in 0..<centerPoints.count {
            let point = centerPoints[i]
            let thickness = point.thickness

            var perpVec: SIMD2<Double>
            if i == 0 {
                if i + 1 < centerPoints.count {
                    let nextPoint = centerPoints[i + 1].location
                    let dir = nextPoint.simd - point.location.simd
                    perpVec = SIMD2(-dir.y, dir.x)
                } else {
                    perpVec = SIMD2(0, 1)
                }
            } else if i == centerPoints.count - 1 {
                let prevPoint = centerPoints[i - 1].location
                let dir = point.location.simd - prevPoint.simd
                perpVec = SIMD2(-dir.y, dir.x)
            } else {
                let prevPoint = centerPoints[i - 1].location
                let nextPoint = centerPoints[i + 1].location
                let dir = nextPoint.simd - prevPoint.simd
                perpVec = SIMD2(-dir.y, dir.x)
            }
            let length = simd_length(perpVec)
            if length > 0 {
                perpVec = simd_normalize(perpVec)
            }
            let offsetDistance = thickness / 2.0
            let multiplier: Double = isLeftSide ? 1.0 : -1.0
            let offsetVec = point.location.simd + perpVec * offsetDistance * multiplier
            let offsetPoint = CGPoint(offsetVec)
            offsetPoints.append(offsetPoint)
        }
        return offsetPoints
    }

    private func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
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
        return VectorPath(elements: elements)
    }

    private func createSimpleMarkerOutline(leftEdgePoints: [CGPoint], rightEdgePoints: [CGPoint]) -> VectorPath {
        guard leftEdgePoints.count >= 2 && rightEdgePoints.count >= 2 else {
            if let firstPoint = leftEdgePoints.first {
                return VectorPath(elements: [.move(to: VectorPoint(firstPoint))])
            }
            return VectorPath(elements: [])
        }
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(leftEdgePoints[0])))
        if leftEdgePoints.count == 2 {
            elements.append(.line(to: VectorPoint(leftEdgePoints[1])))
        } else {
            let leftCurves = fitBezierCurves(through: leftEdgePoints)
            elements.append(contentsOf: leftCurves)
        }
        if let lastRightEdge = rightEdgePoints.last {
            elements.append(.line(to: VectorPoint(lastRightEdge)))
        }
        let reversedRightPoints = rightEdgePoints.reversed()
        if reversedRightPoints.count == 2 {
            elements.append(.line(to: VectorPoint(Array(reversedRightPoints)[1])))
        } else {
            let rightCurves = fitBezierCurves(through: Array(reversedRightPoints))
            elements.append(contentsOf: rightCurves)
        }
        elements.append(.close)
        return VectorPath(elements: elements)
    }

    private func createMarkerDot(at center: CGPoint) -> VectorPath {
        let radius = ApplicationSettings.shared.currentMarkerTipSize / 2.0

        var elements: [PathElement] = []

        let controlPointDistance = radius * 0.552284749831
        elements.append(.move(to: VectorPoint(center.x + radius, center.y)))
        elements.append(.curve(
            to: VectorPoint(center.x, center.y + radius),
            control1: VectorPoint(center.x + radius, center.y + controlPointDistance),
            control2: VectorPoint(center.x + controlPointDistance, center.y + radius)
        ))
        elements.append(.curve(
            to: VectorPoint(center.x - radius, center.y),
            control1: VectorPoint(center.x - controlPointDistance, center.y + radius),
            control2: VectorPoint(center.x - radius, center.y + controlPointDistance)
        ))
        elements.append(.curve(
            to: VectorPoint(center.x, center.y - radius),
            control1: VectorPoint(center.x - radius, center.y - controlPointDistance),
            control2: VectorPoint(center.x - controlPointDistance, center.y - radius)
        ))
        elements.append(.curve(
            to: VectorPoint(center.x + radius, center.y),
            control1: VectorPoint(center.x + controlPointDistance, center.y - radius),
            control2: VectorPoint(center.x + radius, center.y - controlPointDistance)
        ))
        elements.append(.close)
        return VectorPath(elements: elements)
    }

    private func fitBezierCurves(through points: [CGPoint]) -> [PathElement] {
        var elements: [PathElement] = []
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let isFirstSegment = (i == 1)
            let isLastSegment = (i == points.count - 1)
            if isFirstSegment || isLastSegment {
                elements.append(.line(to: VectorPoint(p1)))
            } else {
                let tension: Double = 0.25
                let distance = p1.distance(to: p0)
                let prevTangent = i > 1 ? calculateTangent(p0: points[i - 2], p1: p0, p2: p1) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let nextTangent = i < points.count - 1 ? calculateTangent(p0: p0, p1: p1, p2: points[i + 1]) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let controlLength = distance * tension
                let control1 = CGPoint(
                    x: p0.x + prevTangent.x * controlLength,
                    y: p0.y + prevTangent.y * controlLength
                )
                let control2 = CGPoint(
                    x: p1.x - nextTangent.x * controlLength,
                    y: p1.y - nextTangent.y * controlLength
                )
                elements.append(.curve(
                    to: VectorPoint(p1),
                    control1: VectorPoint(control1),
                    control2: VectorPoint(control2)
                ))
            }
        }
        return elements
    }

    private func calculateTangent(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let p0Vec = SIMD2<Double>(Double(p0.x), Double(p0.y))
        let p1Vec = SIMD2<Double>(Double(p1.x), Double(p1.y))
        let p2Vec = SIMD2<Double>(Double(p2.x), Double(p2.y))
        let d1 = p1Vec - p0Vec
        let d2 = p2Vec - p1Vec
        let avgDir = (d1 + d2) / 2.0
        let length = simd_length(avgDir)
        if length > 0 {
            let normalized = simd_normalize(avgDir)
            return CGPoint(x: normalized.x, y: normalized.y)
        } else {
            return CGPoint(x: 1, y: 0)
        }
    }

    private func applySelfUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        let shapes = document.getShapesForLayer(layerIndex)
        guard shapeIndex < shapes.count else {
            return
        }
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            return
        }
        guard markerStroke.id == activeMarkerShape?.id else {
            return
        }
        let hasStroke = markerStroke.strokeStyle != nil
        let hasFill = markerStroke.fillStyle != nil
        if hasStroke && hasFill,
           let strokeColor = markerStroke.strokeStyle?.color,

           let fillColor = markerStroke.fillStyle?.color {
            if strokeColor == fillColor {
                applyExpandedStrokeUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            } else {
                applyDualUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }

    private func applySingleUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            return
        }
        let originalPath = markerStroke.path.cgPath
        guard !originalPath.isEmpty else {
            return
        }
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            return
        }
        if let cleanedPath = CoreGraphicsPathOperations.union(originalPath, originalPath) {
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                return
            }
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)

            var updatedShape = markerStroke
            updatedShape.path = cleanedVectorPath
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
        }
    }

    private func applyExpandedStrokeUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            return
        }
        let originalPath = markerStroke.path.cgPath
        guard !originalPath.isEmpty else {
            return
        }
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            return
        }
        if let strokeStyle = markerStroke.strokeStyle,

           let expandedStroke = PathOperations.outlineStroke(path: originalPath, strokeStyle: strokeStyle) {
            if let unionedExpandedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding) {
                if let finalPath = CoreGraphicsPathOperations.union(originalPath, unionedExpandedStroke, using: .winding) {
                    guard !finalPath.isEmpty && isPathBoundsFinite(finalPath.boundingBox) else {
                        return
                    }
                    let finalVectorPath = VectorPath(cgPath: finalPath)

                    var updatedShape = markerStroke
                    updatedShape.path = finalVectorPath
                    updatedShape.strokeStyle = nil
                    updatedShape.fillStyle = FillStyle(
                        color: markerStroke.strokeStyle?.color ?? .black,
                        opacity: markerStroke.strokeStyle?.opacity ?? 1.0
                    )
                    document.updateEntireShapeInUnified(id: updatedShape.id) { shape in
                        shape.path = updatedShape.path
                        shape.fillStyle = updatedShape.fillStyle
                    }
                }
            }
        } else {
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }

    private func applyDualUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            return
        }
        if let strokeStyle = markerStroke.strokeStyle {
            if let expandedStroke = PathOperations.outlineStroke(path: markerStroke.path.cgPath, strokeStyle: strokeStyle) {
                if let unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding) {
                    let strokeVectorPath = VectorPath(cgPath: unionedStroke)
                    let strokeShape = VectorShape(
                        name: "Marker Stroke (Outline)",
                        path: strokeVectorPath,
                        strokeStyle: nil,
                        fillStyle: FillStyle(color: strokeStyle.color, opacity: strokeStyle.opacity)
                    )
                    var originalShape = markerStroke
                    originalShape.strokeStyle = nil
                    if let cleanedFillPath = CoreGraphicsPathOperations.union(markerStroke.path.cgPath, markerStroke.path.cgPath) {
                        originalShape.path = VectorPath(cgPath: cleanedFillPath)
                    }
                    document.updateShapePathUnified(id: originalShape.id, path: originalShape.path)
                    document.addShapeToUnifiedSystem(strokeShape, layerIndex: layerIndex)
                } else {
                    applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
                }
            } else {
                applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }

    private func removeCoincidentPointsFromPath(_ path: VectorPath, tolerance: Double = 0.5) -> VectorPath {
        let elements = path.elements
        guard elements.count > 2 else { return path }
        var cleanedElements: [PathElement] = []
        var lastPosition: CGPoint? = nil
        for element in elements {
            switch element {
            case .move(let to):
                cleanedElements.append(element)
                lastPosition = to.cgPoint
            case .line(let to):
                let currentPos = to.cgPoint
                if let last = lastPosition {
                    let distance = currentPos.distance(to: last)
                    if distance > tolerance {
                        cleanedElements.append(element)
                        lastPosition = currentPos
                    }
                } else {
                    cleanedElements.append(element)
                    lastPosition = currentPos
                }
            case .curve(let to, _, _):
                let currentPos = to.cgPoint
                if let last = lastPosition {
                    let distance = currentPos.distance(to: last)
                    if distance > tolerance {
                        cleanedElements.append(element)
                        lastPosition = currentPos
                    }
                } else {
                    cleanedElements.append(element)
                    lastPosition = currentPos
                }
            case .quadCurve(let to, _):
                let currentPos = to.cgPoint
                if let last = lastPosition {
                    let distance = currentPos.distance(to: last)
                    if distance > tolerance {
                        cleanedElements.append(element)
                        lastPosition = currentPos
                    }
                } else {
                    cleanedElements.append(element)
                    lastPosition = currentPos
                }
            case .close:
                cleanedElements.append(element)
            }
        }
        return VectorPath(elements: cleanedElements)
    }

    private func applyAdditionalSimplification(_ path: VectorPath, simplifyAmount: Double) -> VectorPath {
        let elements = path.elements
        guard elements.count > 3 else { return path }
        var points: [CGPoint] = []
        for element in elements {
            switch element {
            case .move(let to), .line(let to):
                points.append(to.cgPoint)
            case .curve(let to, _, _), .quadCurve(let to, _):
                points.append(to.cgPoint)
            case .close:
                break
            }
        }
        guard points.count > 2 else { return path }
        let normalizedAmount = (simplifyAmount - 50.0) / 50.0
        let tolerance = 2.0 + (normalizedAmount * 8.0)
        let simplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(
            points: points,
            tolerance: tolerance
        )
        guard simplifiedPoints.count > 1 else { return path }
        var newElements: [PathElement] = []
        newElements.append(.move(to: VectorPoint(simplifiedPoints[0])))
        for i in 1..<simplifiedPoints.count {
            newElements.append(.line(to: VectorPoint(simplifiedPoints[i])))
        }
        if elements.last?.isClose ?? false {
            newElements.append(.close)
        }
        return VectorPath(elements: newElements)
    }
}

private extension PathElement {

    var isClose: Bool {
        if case .close = self { return true }
        return false
    }
}
