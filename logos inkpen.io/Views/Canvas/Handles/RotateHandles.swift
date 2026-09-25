import SwiftUI
import Combine
import simd

struct RotateHandles: View {

    @ObservedObject var document: VectorDocument

    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool

    @State private var isRotating = false
    @State private var rotationStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var rotationAnchorPoint: CGPoint = .zero
    @State private var startAngle: CGFloat = 0.0
    @State private var finalMarqueeBounds: CGRect = .zero
    @State private var selectedAnchorPointIndex: Int? = nil
    @State private var pathPoints: [VectorPoint] = []
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero)
    @State private var pointsRefreshTrigger: Int = 0
    @State private var cachedPreviewPath: Path? = nil

    private let handleSize: CGFloat = 10

    private var calculatedBounds: CGRect {
        if ImageContentRegistry.containsImage(shape, in: document) && !shape.transform.isIdentity {
            let baseBounds = shape.bounds
            let t = shape.transform
            let corners = [
                CGPoint(x: baseBounds.minX, y: baseBounds.minY).applying(t),
                CGPoint(x: baseBounds.maxX, y: baseBounds.minY).applying(t),
                CGPoint(x: baseBounds.maxX, y: baseBounds.maxY).applying(t),
                CGPoint(x: baseBounds.minX, y: baseBounds.maxY).applying(t)
            ]
            let minX = corners.map { $0.x }.min() ?? baseBounds.minX
            let minY = corners.map { $0.y }.min() ?? baseBounds.minY
            let maxX = corners.map { $0.x }.max() ?? baseBounds.maxX
            let maxY = corners.map { $0.y }.max() ?? baseBounds.maxY
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
                context.stroke(path, with: .color(.white), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0], dashPhase: 2.0))
                context.stroke(path, with: .color(.blue), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
            }
            .allowsHitTesting(false)
            if isRotating && !previewTransform.isIdentity {
                Canvas { context, size in
                    let zoom = zoomLevel
                    let offset = canvasOffset
                    let currentTransform = previewTransform

                    var path = Path()
                    if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                        for memberID in shape.memberIDs {
                            if let memberObject = document.snapshot.objects[memberID] {
                                let memberShape = memberObject.shape
                                for element in memberShape.path.elements {
                                    switch element {
                                    case .move(let to):
                                        let p = to.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                        path.move(to: screenP)
                                    case .line(let to):
                                        let p = to.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                        path.addLine(to: screenP)
                                    case .curve(let to, let control1, let control2):
                                        let tp = to.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        let tc1 = control1.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        let tc2 = control2.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        path.addCurve(to: CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y),
                                                     control1: CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y),
                                                     control2: CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y))
                                    case .quadCurve(let to, let control):
                                        let tp = to.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        let tc = control.cgPoint.applying(memberShape.transform).applying(currentTransform)
                                        path.addQuadCurve(to: CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y),
                                                         control: CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y))
                                    case .close:
                                        path.closeSubpath()
                                    }
                                }
                            }
                        }
                    } else {
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let p = to.cgPoint.applying(shape.transform).applying(currentTransform)
                                let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                path.move(to: screenP)
                            case .line(let to):
                                let p = to.cgPoint.applying(shape.transform).applying(currentTransform)
                                let screenP = CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
                                path.addLine(to: screenP)
                            case .curve(let to, let control1, let control2):
                                let tp = to.cgPoint.applying(shape.transform).applying(currentTransform)
                                let tc1 = control1.cgPoint.applying(shape.transform).applying(currentTransform)
                                let tc2 = control2.cgPoint.applying(shape.transform).applying(currentTransform)
                                path.addCurve(to: CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y),
                                             control1: CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y),
                                             control2: CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y))
                            case .quadCurve(let to, let control):
                                let tp = to.cgPoint.applying(shape.transform).applying(currentTransform)
                                let tc = control.cgPoint.applying(shape.transform).applying(currentTransform)
                                path.addQuadCurve(to: CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y),
                                                 control: CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y))
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    context.stroke(path, with: .color(.blue.opacity(0.8)), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0]))
                }
                .allowsHitTesting(false)
                .id(previewTransform.a + previewTransform.d)
            }
            pathPointsView()
            let isCenterSelected = selectedAnchorPointIndex == nil
            Circle()
                .fill(isCenterSelected ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = nil
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: nil, dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            setupRotationKeyEventMonitoring()
            extractPathPoints()
        }
        .onDisappear {
            teardownRotationKeyEventMonitoring()
        }
    }

    private func extractPathPoints() {
        pathPoints.removeAll()
        for element in shape.path.elements {
            switch element {
            case .move(let to), .line(let to):
                pathPoints.append(to)
            case .curve(let to, _, _), .quadCurve(let to, _):
                pathPoints.append(to)
            case .close:
                break
            }
        }
        centerPoint = VectorPoint(shape.calculateCentroid())
    }

    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isSelected = selectedAnchorPointIndex == index
            let transformedPoint = CGPoint(x: point.x, y: point.y).applying(shape.transform)
            Circle()
                .fill(isSelected ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: transformedPoint.x * zoomLevel + canvasOffset.x,
                    y: transformedPoint.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = index
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
    }

    private func handlePointRotation(anchorPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !rotationStarted {
            startPointRotation(anchorPointIndex: anchorPointIndex, bounds: bounds, dragValue: dragValue)
        }
        let currentLocation = dragValue.location
        let anchorScreenX = rotationAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = rotationAnchorPoint.y * zoomLevel + canvasOffset.y
        let rotationCenter = CGPoint(x: anchorScreenX, y: anchorScreenY)
        let currentVector = CGPoint(x: currentLocation.x - rotationCenter.x, y: currentLocation.y - rotationCenter.y)
        let startVector = CGPoint(x: startLocation.x - rotationCenter.x, y: startLocation.y - rotationCenter.y)
        let currentAngle = atan2(currentVector.y, currentVector.x)
        let initialAngle = atan2(startVector.y, startVector.x)

        var rotationAngle = currentAngle - initialAngle

        let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
        if isShiftCurrentlyPressed {
            let increment: CGFloat = .pi / 4
            rotationAngle = round(rotationAngle / increment) * increment
        }
        calculatePreviewRotation(angle: rotationAngle, anchor: rotationAnchorPoint)
    }

    private func startPointRotation(anchorPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        selectedAnchorPointIndex = anchorPointIndex
        if let pointIndex = anchorPointIndex {
            let point = pathPoints[pointIndex]
            rotationAnchorPoint = CGPoint(x: point.x, y: point.y)
        } else {
            rotationAnchorPoint = shape.calculateCentroid()
        }
    }

    private func updatePathPointsAfterRotation() {
        pathPoints.removeAll()
        for element in shape.path.elements {
            switch element {
            case .move(let to), .line(let to):
                pathPoints.append(to)
            case .curve(let to, _, _), .quadCurve(let to, _):
                pathPoints.append(to)
            case .close:
                break
            }
        }
        centerPoint = VectorPoint(shape.calculateCentroid())
        pointsRefreshTrigger += 1
    }

    private func getRotationAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    private func isRotationPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.viewState.rotationAnchor {
        case .center:
            return false
        case .topLeft:
            return cornerIndex == 0
        case .topRight:
            return cornerIndex == 1
        case .bottomRight:
            return cornerIndex == 2
        case .bottomLeft:
            return cornerIndex == 3
        }
    }

    private func getRotationAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }

    private func rotationCornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }

    private func applyRotationTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform
        if currentTransform.isIdentity {
            return
        }
        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
            document.applyTransformToGroup(groupID: shape.id, transform: currentTransform)
            return
        }
        var transformedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = to.cgPoint.applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
            case .line(let to):
                let transformedPoint = to.cgPoint.applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
            case .curve(let to, let control1, let control2):
                let transformedTo = to.cgPoint.applying(currentTransform)
                let transformedControl1 = control1.cgPoint.applying(currentTransform)
                let transformedControl2 = control2.cgPoint.applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2),
                ))
            case .quadCurve(let to, let control):
                let transformedTo = to.cgPoint.applying(currentTransform)
                let transformedControl = control.cgPoint.applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl),
                ))
            case .close:
                transformedElements.append(.close)
            }
        }
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        guard let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        if !currentShape.cornerRadii.isEmpty && currentShape.isRoundedRectangle {
            var updatedShape = currentShape
            updatedShape.path = transformedPath
            updatedShape.transform = .identity
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)
            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        } else {
            document.updateShapeTransformAndPathInUnified(id: currentShape.id, path: transformedPath, transform: .identity)
        }
    }

    @State private var rotationKeyEventMonitor: Any?
    private func setupRotationKeyEventMonitoring() {
    }

    private func teardownRotationKeyEventMonitoring() {
        if let monitor = rotationKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            rotationKeyEventMonitor = nil
        }
    }

    private func startRotation(cornerIndex: Int, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        rotationAnchorPoint = getRotationAnchorPoint(for: document.viewState.rotationAnchor, in: originalBounds, cornerIndex: cornerIndex)
    }

    private func calculatePreviewRotation(angle: CGFloat, anchor: CGPoint) {
        let rotationTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .rotated(by: angle)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        previewTransform = initialTransform.concatenating(rotationTransform)
        isRotating = true
    }

    private func finishRotation() {
        rotationStarted = false
        isRotating = false
        document.isHandleScalingActive = false
        var allShapeIDs: [UUID] = []
        var oldShapes: [UUID: VectorShape] = [:]
        collectShapesForUndo(shapeID: shape.id, into: &allShapeIDs, oldShapes: &oldShapes)
        if let vectorObject = document.findObject(by: shape.id),

        let layerIndex = vectorObject.layerIndex < document.snapshot.layers.count ? vectorObject.layerIndex : nil {
        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {
            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                var updatedShape = currentShape
                updatedShape.transform = initialTransform
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            }
            applyRotationTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            previewTransform = .identity
            document.updateTransformPanelValues()
            var newShapes: [UUID: VectorShape] = [:]
            for shapeID in allShapeIDs {
                if let transformedShape = document.findShape(by: shapeID) {
                    newShapes[shapeID] = transformedShape
                }
            }
            if !oldShapes.isEmpty && !newShapes.isEmpty {
                let command = ShapeModificationCommand(
                    objectIDs: allShapeIDs,
                    oldShapes: oldShapes,
                    newShapes: newShapes
                )
                document.executeCommand(command)
            }
            document.triggerLayerUpdate(for: layerIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterRotation()
            }
        }
        } else {
            Log.error("❌ ROTATION FAILED: Could not find shape in unified objects system", category: .error)
        }
        previewTransform = .identity
    }

    private func collectShapesForUndo(shapeID: UUID, into ids: inout [UUID], oldShapes: inout [UUID: VectorShape]) {
        guard let object = document.findObject(by: shapeID) else { return }
        ids.append(shapeID)
        switch object.objectType {
        case .shape(let s), .image(let s), .warp(let s), .clipMask(let s), .guide(let s):
            oldShapes[shapeID] = s
        case .group(let s), .clipGroup(let s):
            oldShapes[shapeID] = s
            for memberID in s.memberIDs {
                collectShapesForUndo(shapeID: memberID, into: &ids, oldShapes: &oldShapes)
            }
        case .text:
            break
        }
    }

    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }

    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.viewState.rotationAnchor {
        case .center: return false
        case .topLeft: return cornerIndex == 0
        case .topRight: return cornerIndex == 1
        case .bottomRight: return cornerIndex == 2
        case .bottomLeft: return cornerIndex == 3
        }
    }

    private func getAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }

    private func getAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center: return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft: return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform
        if currentTransform.isIdentity {
            return
        }
        var transformedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = to.cgPoint.applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
            case .line(let to):
                let transformedPoint = to.cgPoint.applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
            case .curve(let to, let control1, let control2):
                let transformedTo = to.cgPoint.applying(currentTransform)
                let transformedControl1 = control1.cgPoint.applying(currentTransform)
                let transformedControl2 = control2.cgPoint.applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2),
                ))
            case .quadCurve(let to, let control):
                let transformedTo = to.cgPoint.applying(currentTransform)
                let transformedControl = control.cgPoint.applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl),
                ))
            case .close:
                transformedElements.append(.close)
            }
        }
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)

        var updatedShape = shape
        updatedShape.path = transformedPath
        updatedShape.transform = .identity
        updatedShape.updateBounds()
        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
    }

    private func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        let scaleX = simd_length(SIMD2(Double(transform.a), Double(transform.c)))
        let scaleY = simd_length(SIMD2(Double(transform.b), Double(transform.d)))
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0
        if scaleRatio > maxReasonableRatio {
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            return
        }
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius)
            }
        }
    }
}
