import SwiftUI
import Combine

struct ScaleHandles: View {

    @ObservedObject var document: VectorDocument

    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool

    @Binding var liveScaleTransform: CGAffineTransform
    @Binding var liveScaleDimensions: CGSize

    @State var isScaling = false
    @State var scalingStarted = false
    @State var initialBounds: CGRect = .zero
    @State var initialTransform: CGAffineTransform = .identity
    @State var startLocation: CGPoint = .zero
    @State var previewTransform: CGAffineTransform = .identity
    @State var scalingAnchorPoint: CGPoint = .zero
    @State var finalMarqueeBounds: CGRect = .zero
    @State var isCapsLockPressed = false
    @State var lockedPinPointIndex: Int? = nil
    @State var pathPoints: [VectorPoint] = []
    @State var centerPoint: VectorPoint = VectorPoint(CGPoint.zero)
    @State var pointsRefreshTrigger: Int = 0
    @State var cachedPreviewPath: Path? = nil

    let handleSize: CGFloat = 10

    private var calculatedBounds: CGRect {
        if ImageContentRegistry.containsImage(shape, in: document) {
            let pathBounds = shape.path.cgPath.boundingBoxOfPath
            return pathBounds.applying(shape.transform)
        } else {
            return shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }
    }

    private var calculatedCenter: CGPoint {
        return shape.calculateCentroid()
    }

    var body: some View {
        let bounds = calculatedBounds
        let center = calculatedCenter
        ZStack {
            Canvas { context, size in
                let zoom = zoomLevel
                let offset = canvasOffset
                let activeTransform = (isScaling && !previewTransform.isIdentity) ? previewTransform : shape.transform
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    for groupedShape in shape.groupedShapes {
                        var path = Path()
                        for element in groupedShape.path.elements {
                            switch element {
                            case .move(let to):
                                let p = to.cgPoint.applying(activeTransform)
                                let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                path.move(to: screenP)
                            case .line(let to):
                                let p = to.cgPoint.applying(activeTransform)
                                let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                path.addLine(to: screenP)
                            case .curve(let to, let control1, let control2):
                                let tp = to.cgPoint.applying(activeTransform)
                                let tc1 = control1.cgPoint.applying(activeTransform)
                                let tc2 = control2.cgPoint.applying(activeTransform)
                                let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                                let screenC1 = CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y)
                                let screenC2 = CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y)
                                path.addCurve(to: screenTo, control1: screenC1, control2: screenC2)
                            case .quadCurve(let to, let control):
                                let tp = to.cgPoint.applying(activeTransform)
                                let tc = control.cgPoint.applying(activeTransform)
                                let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                                let screenC = CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y)
                                path.addQuadCurve(to: screenTo, control: screenC)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                        context.stroke(path, with: .color(.white), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0], dashPhase: 2.0))
                        context.stroke(path, with: .color(.blue), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
                    }
                } else {
                    var path = Path()
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            let p = to.cgPoint.applying(activeTransform)
                            let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                            path.move(to: screenP)
                        case .line(let to):
                            let p = to.cgPoint.applying(activeTransform)
                            let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                            path.addLine(to: screenP)
                        case .curve(let to, let control1, let control2):
                            let tp = to.cgPoint.applying(activeTransform)
                            let tc1 = control1.cgPoint.applying(activeTransform)
                            let tc2 = control2.cgPoint.applying(activeTransform)
                            let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                            let screenC1 = CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y)
                            let screenC2 = CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y)
                            path.addCurve(to: screenTo, control1: screenC1, control2: screenC2)
                        case .quadCurve(let to, let control):
                            let tp = to.cgPoint.applying(activeTransform)
                            let tc = control.cgPoint.applying(activeTransform)
                            let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                            let screenC = CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y)
                            path.addQuadCurve(to: screenTo, control: screenC)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                    context.stroke(path, with: .color(.white), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0], dashPhase: 2.0))
                    context.stroke(path, with: .color(.blue), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
                }
            }
            .allowsHitTesting(false)
            pathPointsView()
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                let displayBounds = (isScaling && !previewTransform.isIdentity) ? bounds.applying(previewTransform) : bounds
                let displayCenter = CGPoint(x: displayBounds.midX, y: displayBounds.midY)
                Canvas { context, size in
                    let zoom = zoomLevel
                    let offset = canvasOffset
                    let screenRect = CGRect(
                        x: displayBounds.minX * zoom + offset.x,
                        y: displayBounds.minY * zoom + offset.y,
                        width: displayBounds.width * zoom,
                        height: displayBounds.height * zoom
                    )
                    context.stroke(Path(screenRect), with: .color(.green), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [3.0, 3.0]))
                }
                .allowsHitTesting(false)
                ForEach(0..<4) { i in
                    let cornerPos = cornerPosition(for: i, in: displayBounds, center: displayCenter)
                    let cornerIndex = pathPoints.count + i
                    let isLockedPin = lockedPinPointIndex == cornerIndex
                    Circle()
                        .fill(isLockedPin ? Color.red : Color.green)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize)
                        .offset(
                            x: cornerPos.x * zoomLevel + canvasOffset.x - (handleSize) / 2,
                            y: cornerPos.y * zoomLevel + canvasOffset.y - (handleSize) / 2
                        )
                        .onTapGesture {
                            if !isScaling {
                                setLockedPinPoint(cornerIndex)
                            }
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    handleScalingFromPoint(draggedPointIndex: cornerIndex, dragValue: value, bounds: bounds, center: center)
                                }
                                .onEnded { _ in
                                    finishScaling()
                                }
                        )
                }
            }
            let isCenterLockedPin = (lockedPinPointIndex == nil)
            let displayCenter = (isScaling && !previewTransform.isIdentity) ? center.applying(previewTransform) : center
            Circle()
                .fill(isCenterLockedPin ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: displayCenter.x * zoomLevel + canvasOffset.x,
                    y: displayCenter.y * zoomLevel + canvasOffset.y
                ))
                .zIndex(100)
                .onTapGesture {
                    if !isScaling {
                        setLockedPinPoint(nil)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            if !scalingStarted {
                                scalingStarted = true
                                isScaling = true
                                document.isHandleScalingActive = true
                                initialBounds = bounds
                                initialTransform = shape.transform
                                startLocation = value.startLocation
                                scalingAnchorPoint = center
                            }
                            let translation = CGSize(
                                width: value.location.x - value.startLocation.x,
                                height: value.location.y - value.startLocation.y
                            )
                            let sensitivity: CGFloat = 0.005 / zoomLevel

                            var scaleX = 1.0 + (translation.width * sensitivity)
                            var scaleY = 1.0 + (translation.height * sensitivity)
                            scaleX = min(max(scaleX, 0.1), 10.0)
                            scaleY = min(max(scaleY, 0.1), 10.0)
                            if isShiftPressed {
                                let avgScale = (scaleX + scaleY) / 2.0
                                scaleX = avgScale
                                scaleY = avgScale
                            }
                            calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: center)
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )
            if isScaling && !previewTransform.isIdentity, let cachedPath = cachedPreviewPath {
                Canvas { context, size in
                    let zoom = zoomLevel
                    let offset = canvasOffset
                    let transform = CGAffineTransform.identity
                        .translatedBy(x: offset.x, y: offset.y)
                        .scaledBy(x: zoom, y: zoom)
                    context.transform = transform
                    context.stroke(cachedPath, with: .color(.blue.opacity(0.8)), style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoom, dash: [4.0 / zoom, 4.0 / zoom]))
                    if shape.isGroup && !shape.groupedShapes.isEmpty {
                        let transformedBounds = bounds.applying(previewTransform)
                        context.stroke(Path(transformedBounds), with: .color(.green.opacity(0.6)), style: SwiftUI.StrokeStyle(lineWidth: 1.5 / zoom, dash: [3.0 / zoom, 3.0 / zoom]))
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            extractPathPoints()
            if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
                setLockedPinPoint(nil)
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            if !isScaling && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
            }
        }
        .onChange(of: previewTransform) { _, newTransform in
            guard isScaling && newTransform != .identity else {
                cachedPreviewPath = nil
                return
            }
            var path = Path()
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                for groupedShape in shape.groupedShapes {
                    for element in groupedShape.path.elements {
                        switch element {
                        case .move(let to):
                            let p = to.cgPoint.applying(newTransform)
                            path.move(to: p)
                        case .line(let to):
                            let p = to.cgPoint.applying(newTransform)
                            path.addLine(to: p)
                        case .curve(let to, let control1, let control2):
                            let tp = to.cgPoint.applying(newTransform)
                            let tc1 = control1.cgPoint.applying(newTransform)
                            let tc2 = control2.cgPoint.applying(newTransform)
                            path.addCurve(to: tp, control1: tc1, control2: tc2)
                        case .quadCurve(let to, let control):
                            let tp = to.cgPoint.applying(newTransform)
                            let tc = control.cgPoint.applying(newTransform)
                            path.addQuadCurve(to: tp, control: tc)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                }
            } else {
                for element in shape.path.elements {
                    switch element {
                    case .move(let to):
                        let p = to.cgPoint.applying(newTransform)
                        path.move(to: p)
                    case .line(let to):
                        let p = to.cgPoint.applying(newTransform)
                        path.addLine(to: p)
                    case .curve(let to, let control1, let control2):
                        let tp = to.cgPoint.applying(newTransform)
                        let tc1 = control1.cgPoint.applying(newTransform)
                        let tc2 = control2.cgPoint.applying(newTransform)
                        path.addCurve(to: tp, control1: tc1, control2: tc2)
                    case .quadCurve(let to, let control):
                        let tp = to.cgPoint.applying(newTransform)
                        let tc = control.cgPoint.applying(newTransform)
                        path.addQuadCurve(to: tp, control: tc)
                    case .close:
                        path.closeSubpath()
                    }
                }
            }
            cachedPreviewPath = path
        }
    }

    @State var keyEventMonitor: Any?
}
