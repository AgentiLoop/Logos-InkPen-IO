import SwiftUI
import Combine
import simd

struct EnvelopeHandles: View {

    @ObservedObject var document: VectorDocument

    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint

    @State private var isWarping = false
    @State private var warpingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewPath: VectorPath? = nil
    @State private var isShiftPressed = false
    @State private var originalCorners: [CGPoint] = []
    @State private var warpedCorners: [CGPoint] = []
    @State private var draggingCornerIndex: Int? = nil

    private let handleSize: CGFloat = 10
    private let handleHitAreaSize: CGFloat = 15

    var body: some View {
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        ZStack {
            Canvas { context, size in
                let zoom = zoomLevel
                let offset = canvasOffset
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    for groupedShape in shape.groupedShapes {
                        var path = Path()
                        for element in groupedShape.path.elements {
                            switch element {
                            case .move(let to):
                                let p = to.cgPoint.applying(groupedShape.transform)
                                let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                path.move(to: screenP)
                            case .line(let to):
                                let p = to.cgPoint.applying(groupedShape.transform)
                                let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                path.addLine(to: screenP)
                            case .curve(let to, let control1, let control2):
                                let tp = to.cgPoint.applying(groupedShape.transform)
                                let tc1 = control1.cgPoint.applying(groupedShape.transform)
                                let tc2 = control2.cgPoint.applying(groupedShape.transform)
                                let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                                let screenC1 = CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y)
                                let screenC2 = CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y)
                                path.addCurve(to: screenTo, control1: screenC1, control2: screenC2)
                            case .quadCurve(let to, let control):
                                let tp = to.cgPoint.applying(groupedShape.transform)
                                let tc = control.cgPoint.applying(groupedShape.transform)
                                let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                                let screenC = CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y)
                                path.addQuadCurve(to: screenTo, control: screenC)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                        context.stroke(path, with: .color(.purple), lineWidth: 2.0)
                    }
                } else {
                    var path = Path()
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            let p = to.cgPoint.applying(shape.transform)
                            let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                            path.move(to: screenP)
                        case .line(let to):
                            let p = to.cgPoint.applying(shape.transform)
                            let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                            path.addLine(to: screenP)
                        case .curve(let to, let control1, let control2):
                            let tp = to.cgPoint.applying(shape.transform)
                            let tc1 = control1.cgPoint.applying(shape.transform)
                            let tc2 = control2.cgPoint.applying(shape.transform)
                            let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                            let screenC1 = CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y)
                            let screenC2 = CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y)
                            path.addCurve(to: screenTo, control1: screenC1, control2: screenC2)
                        case .quadCurve(let to, let control):
                            let tp = to.cgPoint.applying(shape.transform)
                            let tc = control.cgPoint.applying(shape.transform)
                            let screenTo = CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y)
                            let screenC = CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y)
                            path.addQuadCurve(to: screenTo, control: screenC)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                    context.stroke(path, with: .color(.purple), lineWidth: 2.0)
                }
            }
            .allowsHitTesting(false)
            envelopeCornerHandles()
            if document.viewState.currentTool == .warp && warpedCorners.count == 4 && isWarping {
                envelopeGridPreview()
            }
            if previewPath != nil && !isWarping {
                warpedShapePreview()
            }
        }
        .onAppear {
            initialBounds = bounds
            initialTransform = shape.transform
            setupEnvelopeKeyEventMonitoring()
            initializeEnvelopeCorners()
        }
        .onDisappear {
            teardownEnvelopeKeyEventMonitoring()
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            if !isWarping && !warpingStarted && warpedCorners.isEmpty && oldBounds != newBounds {
                initializeEnvelopeCorners()
            }
        }
        .onChange(of: document.viewState.currentTool) { oldTool, newTool in
            if oldTool == .warp && newTool != .warp {
                if previewPath != nil {
                    commitEnvelopeWarp()
                }
            }
            if oldTool != .warp && newTool == .warp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
            }
        }
        .onChange(of: document.viewState.selectedObjectIDs) { oldSelection, newSelection in
            if document.viewState.currentTool == .warp && oldSelection != newSelection {
                if previewPath != nil {
                    commitEnvelopeWarp()
                }
                previewPath = nil
                originalCorners.removeAll()
                warpedCorners.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
            }
        }
        .onChange(of: shape.warpEnvelope) { _, newEnvelope in
            if document.viewState.currentTool == .warp && !newEnvelope.isEmpty && newEnvelope != warpedCorners {
                initializeEnvelopeCorners()
            }
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
            if document.viewState.currentTool == .warp && !isWarping {
                if let updatedObject = document.snapshot.objects.values.first(where: { $0.id == shape.id }) {
                    let s = updatedObject.shape
                    if s.isWarpObject && !s.warpEnvelope.isEmpty {
                        warpedCorners = s.warpEnvelope
                    } else {
                        let bounds = s.bounds
                        let resetCorners = [
                            CGPoint(x: bounds.minX, y: bounds.minY),
                            CGPoint(x: bounds.maxX, y: bounds.minY),
                            CGPoint(x: bounds.maxX, y: bounds.maxY),
                            CGPoint(x: bounds.minX, y: bounds.maxY)
                        ]
                        warpedCorners = resetCorners
                        originalCorners = resetCorners
                        previewPath = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func envelopeCornerHandles() -> some View {
        if warpedCorners.count == 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = warpedCorners[cornerIndex]
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize + 2, height: handleSize + 2)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: handleSize, height: handleSize)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: handleHitAreaSize, height: handleHitAreaSize)
                        .contentShape(Circle())
                }
            .position(CGPoint(x: cornerPos.x * zoomLevel + canvasOffset.x,
                              y: cornerPos.y * zoomLevel + canvasOffset.y))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleEnvelopeWarp(cornerIndex: cornerIndex, dragValue: value)
                    }
                    .onEnded { _ in
                        finishEnvelopeWarp()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func envelopeGridPreview() -> some View {
        Canvas { context, size in
            let zoom = zoomLevel
            let offset = canvasOffset
            let gridLines = 4
            for row in 0..<4 {
                let t = CGFloat(row) / CGFloat(gridLines - 1)
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 0.0, v: t
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 1.0, v: t
                )
                let screenStart = CGPoint(x: startPoint.x * zoom + offset.x, y: startPoint.y * zoom + offset.y)
                let screenEnd = CGPoint(x: endPoint.x * zoom + offset.x, y: endPoint.y * zoom + offset.y)

                var path = Path()
                path.move(to: screenStart)
                path.addLine(to: screenEnd)
                context.stroke(path, with: .color(.blue.opacity(0.6)), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
            }
            for col in 0..<4 {
                let u = CGFloat(col) / CGFloat(gridLines - 1)
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 0.0
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 1.0
                )
                let screenStart = CGPoint(x: startPoint.x * zoom + offset.x, y: startPoint.y * zoom + offset.y)
                let screenEnd = CGPoint(x: endPoint.x * zoom + offset.x, y: endPoint.y * zoom + offset.y)

                var path = Path()
                path.move(to: screenStart)
                path.addLine(to: screenEnd)
                context.stroke(path, with: .color(.blue.opacity(0.6)), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func warpedShapePreview() -> some View {
        if let warpedPath = previewPath {
            Canvas { context, size in
                let zoom = zoomLevel
                let offset = canvasOffset

                var path = Path()
                for element in warpedPath.elements {
                    switch element {
                    case .move(let to):
                        let screenP = CGPoint(x: to.x * zoom + offset.x, y: to.y * zoom + offset.y)
                        path.move(to: screenP)
                    case .line(let to):
                        let screenP = CGPoint(x: to.x * zoom + offset.x, y: to.y * zoom + offset.y)
                        path.addLine(to: screenP)
                    case .curve(let to, let control1, let control2):
                        let screenTo = CGPoint(x: to.x * zoom + offset.x, y: to.y * zoom + offset.y)
                        let screenC1 = CGPoint(x: control1.x * zoom + offset.x, y: control1.y * zoom + offset.y)
                        let screenC2 = CGPoint(x: control2.x * zoom + offset.x, y: control2.y * zoom + offset.y)
                        path.addCurve(to: screenTo, control1: screenC1, control2: screenC2)
                    case .quadCurve(let to, let control):
                        let screenTo = CGPoint(x: to.x * zoom + offset.x, y: to.y * zoom + offset.y)
                        let screenC = CGPoint(x: control.x * zoom + offset.x, y: control.y * zoom + offset.y)
                        path.addQuadCurve(to: screenTo, control: screenC)
                    case .close:
                        path.closeSubpath()
                    }
                }
                context.stroke(path, with: .color(.blue.opacity(0.8)), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0]))
            }
            .allowsHitTesting(false)
        }
    }

    private func initializeEnvelopeCorners() {
        if shape.isWarpObject && !shape.warpEnvelope.isEmpty, let originalPath = shape.originalPath {
            let originalBounds = originalPath.cgPath.boundingBoxOfPath
            originalCorners = [
                CGPoint(x: originalBounds.minX, y: originalBounds.minY),
                CGPoint(x: originalBounds.maxX, y: originalBounds.minY),
                CGPoint(x: originalBounds.maxX, y: originalBounds.maxY),
                CGPoint(x: originalBounds.minX, y: originalBounds.maxY)
            ]
            warpedCorners = shape.warpEnvelope
            previewPath = shape.path
            return
        }
        if let storedCorners = document.viewState.warpEnvelopeCorners[shape.id], storedCorners.count == 4 {
            originalCorners = storedCorners
            warpedCorners = storedCorners
            return
        }
        if shape.path.elements.count <= 4 || shape.isGroup {
            let bounds = shape.path.cgPath.boundingBoxOfPath
            let newOriginalCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners
            if document.viewState.warpBounds[shape.id] == nil {
                let minX = newOriginalCorners.map { $0.x }.min() ?? 0
                let maxX = newOriginalCorners.map { $0.x }.max() ?? 0
                let minY = newOriginalCorners.map { $0.y }.min() ?? 0
                let maxY = newOriginalCorners.map { $0.y }.max() ?? 0
                let newBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                Log.warning("⚠️ INITIALIZING NEW WARP BOUNDS (4-point shape): \(newBounds)", category: .general)
                document.viewState.warpBounds[shape.id] = newBounds
                document.viewState.warpEnvelopeCorners[shape.id] = newOriginalCorners
            }
        } else {
            let bounds = shape.bounds
            let newOriginalCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners
            if document.viewState.warpBounds[shape.id] == nil {
                Log.warning("⚠️ INITIALIZING NEW WARP BOUNDS (regular shape): \(bounds)", category: .general)
                document.viewState.warpBounds[shape.id] = bounds
                document.viewState.warpEnvelopeCorners[shape.id] = newOriginalCorners
            }
        }
    }

    private func cornersHaveChangedSignificantly(from oldCorners: [CGPoint], to newCorners: [CGPoint]) -> Bool {
        guard oldCorners.count == 4 && newCorners.count == 4 else { return true }
        let threshold: CGFloat = 1.0
        for i in 0..<4 {
            let oldCorner = oldCorners[i]
            let newCorner = newCorners[i]
            if abs(oldCorner.x - newCorner.x) > threshold || abs(oldCorner.y - newCorner.y) > threshold {
                return true
            }
        }
        return false
    }

    private func handleEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        if !warpingStarted {
            startEnvelopeWarp(cornerIndex: cornerIndex, dragValue: dragValue)
        }
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        let canvasLocation = CGPoint(
            x: (currentLocation.x - canvasOffset.x) / preciseZoom,
            y: (currentLocation.y - canvasOffset.y) / preciseZoom
        )
        warpedCorners[cornerIndex] = canvasLocation
    }

    private func startEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        warpingStarted = true
        isWarping = true
        document.isHandleScalingActive = true
        if shape.isWarpObject && originalCorners.count == 4 {
            let minX = min(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let maxX = max(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let minY = min(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            let maxY = max(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            initialBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        } else if shape.isWarpObject, let originalPath = shape.originalPath {
            initialBounds = originalPath.cgPath.boundingBoxOfPath
        } else {
            initialBounds = shape.bounds
        }
        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        draggingCornerIndex = cornerIndex
    }

    private func calculateEnvelopeWarpPreview() {
        guard originalCorners.count == 4 && warpedCorners.count == 4 else { return }
        if shape.isWarpObject, let originalPath = shape.originalPath {
            let warpedElements = warpPathElements(originalPath.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: originalPath.isClosed)
        } else if shape.isGroup && !shape.groupedShapes.isEmpty {
            var allWarpedElements: [PathElement] = []
            for groupedShape in shape.groupedShapes {
                let warpedElements = warpPathElements(groupedShape.path.elements)
                allWarpedElements.append(contentsOf: warpedElements)
                if !allWarpedElements.isEmpty && groupedShape != shape.groupedShapes.last {
                }
            }
            previewPath = VectorPath(elements: allWarpedElements, isClosed: false)
        } else {
            let warpedElements = warpPathElements(shape.path.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: shape.path.isClosed)
        }
    }

    private func warpPathElements(_ elements: [PathElement]) -> [PathElement] {
        var warpedElements: [PathElement] = []
        for element in elements {
            switch element {
            case .move(let to):
                let warpedPoint = warpPoint(to.cgPoint)
                warpedElements.append(.move(to: VectorPoint(warpedPoint)))
            case .line(let to):
                let warpedPoint = warpPoint(to.cgPoint)
                warpedElements.append(.line(to: VectorPoint(warpedPoint)))
            case .curve(let to, let control1, let control2):
                let warpedTo = warpPoint(to.cgPoint)
                let warpedControl1 = warpPoint(control1.cgPoint)
                let warpedControl2 = warpPoint(control2.cgPoint)
                warpedElements.append(.curve(
                    to: VectorPoint(warpedTo),
                    control1: VectorPoint(warpedControl1),
                    control2: VectorPoint(warpedControl2),
                ))
            case .quadCurve(let to, let control):
                let warpedTo = warpPoint(to.cgPoint)
                let warpedControl = warpPoint(control.cgPoint)
                warpedElements.append(.quadCurve(
                    to: VectorPoint(warpedTo),
                    control: VectorPoint(warpedControl),
                ))
            case .close:
                warpedElements.append(.close)
            }
        }
        return warpedElements
    }

    private func warpPoint(_ point: CGPoint) -> CGPoint {
        guard originalCorners.count == 4 else {
            let bounds = initialBounds
            let u = (point.x - bounds.minX) / bounds.width
            let v = (point.y - bounds.minY) / bounds.height
            return bilinearInterpolation(
                topLeft: warpedCorners[0],
                topRight: warpedCorners[1],
                bottomLeft: warpedCorners[3],
                bottomRight: warpedCorners[2],
                u: u, v: v
            )
        }
        let (u, v) = inverseBilinearInterpolation(
            point: point,
            topLeft: originalCorners[0],
            topRight: originalCorners[1],
            bottomLeft: originalCorners[3],
            bottomRight: originalCorners[2]
        )
        return bilinearInterpolation(
            topLeft: warpedCorners[0],
            topRight: warpedCorners[1],
            bottomLeft: warpedCorners[3],
            bottomRight: warpedCorners[2],
            u: u, v: v
        )
    }

    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )
        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }

    private func inverseBilinearInterpolation(point: CGPoint, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> (u: CGFloat, v: CGFloat) {
        let rightVector = CGPoint(x: topRight.x - topLeft.x, y: topRight.y - topLeft.y)
        let downVector = CGPoint(x: bottomLeft.x - topLeft.x, y: bottomLeft.y - topLeft.y)
        let pointVector = CGPoint(x: point.x - topLeft.x, y: point.y - topLeft.y)
        let det = rightVector.x * downVector.y - rightVector.y * downVector.x
        if abs(det) < 1e-10 {
            let rightLength = simd_length(SIMD2(Double(rightVector.x), Double(rightVector.y)))
            let downLength = simd_length(SIMD2(Double(downVector.x), Double(downVector.y)))
            let u: CGFloat = rightLength > 0 ?
            (pointVector.x * rightVector.x + pointVector.y * rightVector.y) / (rightLength * rightLength) : 0
            let v: CGFloat = downLength > 0 ?
            (pointVector.x * downVector.x + pointVector.y * downVector.y) / (downLength * downLength) : 0
            return (u: max(0, min(1, u)), v: max(0, min(1, v)))
        }
        let u = (pointVector.x * downVector.y - pointVector.y * downVector.x) / det
        let v = (rightVector.x * pointVector.y - rightVector.y * pointVector.x) / det
        return (u: max(0, min(1, u)), v: max(0, min(1, v)))
    }

    private func buildWarpedShape(from currentShape: VectorShape) -> VectorShape {
        if currentShape.isWarpObject {
            var updatedWarpObject = currentShape
            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                var warpedGroupedShapes: [VectorShape] = []
                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)

                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    warpedGrouped.updateBounds()
                    warpedGroupedShapes.append(warpedGrouped)
                }
                updatedWarpObject.groupedShapes = warpedGroupedShapes
            } else if let finalWarpedPath = previewPath {
                updatedWarpObject.path = finalWarpedPath
            }
            updatedWarpObject.warpEnvelope = warpedCorners
            updatedWarpObject.updateBounds()
            return updatedWarpObject
        } else {
            var warpObject = currentShape
            warpObject.name = "Warped " + currentShape.name
            warpObject.isWarpObject = true
            warpObject.warpEnvelope = warpedCorners
            warpObject.transform = .identity
            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                warpObject.originalPath = nil
                var warpedGroupedShapes: [VectorShape] = []
                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)

                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    warpedGrouped.updateBounds()
                    warpedGroupedShapes.append(warpedGrouped)
                }
                warpObject.groupedShapes = warpedGroupedShapes
            } else if let finalWarpedPath = previewPath {
                warpObject.originalPath = currentShape.path
                warpObject.path = finalWarpedPath
            }
            warpObject.updateBounds()
            return warpObject
        }
    }

    private func finishEnvelopeWarp() {
        warpingStarted = false
        isWarping = false
        document.isHandleScalingActive = false
        draggingCornerIndex = nil
        calculateEnvelopeWarpPreview()
        guard let oldObject = document.findObject(by: shape.id) else { return }
        let oldShape = oldObject.shape
        if warpedCorners.count == 4 {
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.viewState.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            document.viewState.warpEnvelopeCorners[shape.id] = warpedCorners
        }
        let newShape = buildWarpedShape(from: oldShape)
        let command = ShapeModificationCommand(
            objectIDs: [shape.id],
            oldShapes: [shape.id: oldShape],
            newShapes: [shape.id: newShape]
        )
        document.executeCommand(command)
    }

    private func commitEnvelopeWarp() {
        if warpedCorners.count == 4 {
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.viewState.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            document.viewState.warpEnvelopeCorners[shape.id] = warpedCorners
        }
    }

    @State private var envelopeKeyEventMonitor: Any?
    private func setupEnvelopeKeyEventMonitoring() {
    }

    private func teardownEnvelopeKeyEventMonitoring() {
        if let monitor = envelopeKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            envelopeKeyEventMonitor = nil
        }
    }
}
