import SwiftUI

extension DrawingCanvas {

    @ViewBuilder
    internal func fillClosePreview(geometry: GeometryProxy) -> some View {
        if showClosePathHint && bezierPoints.count >= 3,

           let currentBezierPath = bezierPath {
            let lastPointIndex = bezierPoints.count - 1
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            let lastPointHandles = liveBezierHandles[lastPointIndex] ?? bezierHandles[lastPointIndex]
            let firstPointHandles = liveBezierHandles[0] ?? bezierHandles[0]
            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)
                let fillPath = Path { path in
                    addPathElements(currentBezierPath.elements, to: &path)
                    let lastPoint = bezierPoints[lastPointIndex]
                    let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
                    if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                    } else if let lastControl2 = lastPointHandles?.control2 {
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                    } else if let firstControl1 = firstPointHandles?.control1 {
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                    } else {
                        path.addLine(to: firstPointLocation)
                    }
                    path.closeSubpath()
                }
                context.fill(
                    fillPath,
                    with: .color(document.defaultFillColor.color.opacity(0.3))
                )
            }
        }
    }

    @ViewBuilder
    internal func rubberBandFillPreview(geometry: GeometryProxy) -> some View {
        if let mouseLocation = currentMouseLocation,
           bezierPoints.count >= 2 {
            let rawCanvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            let canvasMouseLocation = isShiftPressed ?
                constrainToAngle(from: lastPointLocation, to: rawCanvasMouseLocation) :
                rawCanvasMouseLocation
            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)
                let fillPath = Path { path in
                    path.move(to: firstPointLocation)
                    for i in 1..<bezierPoints.count {
                        let currentPoint = bezierPoints[i]
                        let previousPoint = bezierPoints[i - 1]
                        let previousHandles = liveBezierHandles[i - 1] ?? bezierHandles[i - 1]
                        let currentHandles = liveBezierHandles[i] ?? bezierHandles[i]
                        let hasOutgoingHandle = previousHandles?.control2 != nil
                        let hasIncomingHandle = currentHandles?.control1 != nil
                        if hasOutgoingHandle || hasIncomingHandle {
                            let control1 = previousHandles?.control2 ?? VectorPoint(previousPoint.x, previousPoint.y)
                            let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                            path.addCurve(
                                to: CGPoint(x: currentPoint.x, y: currentPoint.y),
                                control1: control1.cgPoint,
                                control2: control2.cgPoint
                            )
                        } else {
                            path.addLine(to: CGPoint(x: currentPoint.x, y: currentPoint.y))
                        }
                    }
                    let lastPointHandles = liveBezierHandles[lastPointIndex] ?? bezierHandles[lastPointIndex]
                    if let lastPointHandles = lastPointHandles,

                       let lastControl2 = lastPointHandles.control2 {
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        path.addCurve(
                            to: canvasMouseLocation,
                            control1: lastControl2Location,
                            control2: canvasMouseLocation
                        )
                    } else {
                        path.addLine(to: canvasMouseLocation)
                    }
                    let firstPointHandles = liveBezierHandles[0] ?? bezierHandles[0]
                    if let firstPointHandles = firstPointHandles,

                       let firstControl1 = firstPointHandles.control1 {
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(
                            to: firstPointLocation,
                            control1: canvasMouseLocation,
                            control2: firstControl1Location
                        )
                    } else {
                        path.addLine(to: firstPointLocation)
                    }
                    path.closeSubpath()
                }
                context.fill(
                    fillPath,
                    with: .color(document.defaultFillColor.color.opacity(0.15))
                )
            }
        }
    }

    @ViewBuilder
    internal func rubberBandPreview(geometry: GeometryProxy) -> some View {
        if isBezierDrawing && document.viewState.currentTool == .bezierPen,
           let mouseLocation = currentMouseLocation,
           bezierPoints.count > 0 {
            let rawCanvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            let canvasMouseLocation = isShiftPressed ?
                constrainToAngle(from: lastPointLocation, to: rawCanvasMouseLocation) :
                rawCanvasMouseLocation
            if isShiftPressed && bezierPoints.count >= 1 {
                if let snapPoint = findBestIntersectionPoint(from: lastPointLocation, toward: rawCanvasMouseLocation) {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 16 / zoomLevel, height: 16 / zoomLevel)
                        .overlay(
                            Circle()
                                .stroke(Color.purple, lineWidth: 2 / zoomLevel)
                        )
                        .position(
                            x: snapPoint.x * zoomLevel + canvasOffset.x,
                            y: snapPoint.y * zoomLevel + canvasOffset.y
                        )
                    Canvas { context, size in
                        context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                        context.scaleBy(x: zoomLevel, y: zoomLevel)
                        let path1 = Path { path in
                            path.move(to: lastPointLocation)
                            path.addLine(to: snapPoint)
                        }
                        context.stroke(
                            path1,
                            with: .color(Color.purple.opacity(0.5)),
                            style: SwiftUI.StrokeStyle(
                                lineWidth: 1 / zoomLevel,
                                lineCap: .round,
                                dash: [4, 2]
                            )
                        )
                        let firstPoint = bezierPoints[0]
                        let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                        let path2 = Path { path in
                            path.move(to: snapPoint)
                            path.addLine(to: firstPointLocation)
                        }
                        context.stroke(
                            path2,
                            with: .color(Color.purple.opacity(0.5)),
                            style: SwiftUI.StrokeStyle(
                                lineWidth: 1 / zoomLevel,
                                lineCap: .round,
                                dash: [4, 2]
                            )
                        )
                    }
                }
            }
            let strokeWidth = 2.0 / zoomLevel
            let rubberBandWidth = 1.0 / zoomLevel
            if bezierPoints.count >= 2 && !showClosePathHint {
                rubberBandFillPreview(geometry: geometry)
            }
            if showClosePathHint && bezierPoints.count >= 3 {
                fillClosePreview(geometry: geometry)
            }
            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)
                if showClosePathHint && bezierPoints.count >= 3 {
                    let firstPoint = bezierPoints[0]
                    let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                    let lastPointHandles = liveBezierHandles[lastPointIndex] ?? bezierHandles[lastPointIndex]
                    let firstPointHandles = liveBezierHandles[0] ?? bezierHandles[0]
                    let closePath = Path { path in
                        path.move(to: lastPointLocation)
                        if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                            let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                            let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                            path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                        } else if let lastControl2 = lastPointHandles?.control2 {
                            let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                            path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                        } else if let firstControl1 = firstPointHandles?.control1 {
                            let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                            path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                        } else {
                            path.addLine(to: firstPointLocation)
                        }
                    }
                    context.stroke(
                        closePath,
                        with: .color(Color.green),
                        style: SwiftUI.StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                } else {
                    let rubberPath = Path { path in
                        path.move(to: lastPointLocation)
                        let lastPointHandlesForRubber = liveBezierHandles[lastPointIndex] ?? bezierHandles[lastPointIndex]
                        if let lastPointHandles = lastPointHandlesForRubber,

                           let lastControl2 = lastPointHandles.control2 {
                            let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                            path.addCurve(
                                to: canvasMouseLocation,
                                control1: lastControl2Location,
                                control2: canvasMouseLocation
                            )
                        } else {
                            path.addLine(to: canvasMouseLocation)
                        }
                    }
                    context.stroke(
                        rubberPath,
                        with: .color(Color.blue.opacity(0.8)),
                        style: SwiftUI.StrokeStyle(lineWidth: rubberBandWidth, lineCap: .round, dash: [4, 2])
                    )
                }
            }
        }
    }

    private func constrainToAngle(from reference: CGPoint, to target: CGPoint) -> CGPoint {
        return GeometryUtils.constrainToAngle(from: reference, to: target, constraintAngles: constraintAngles)
    }
}
