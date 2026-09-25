import SwiftUI
import Combine
import simd

struct ReflectHandles: View {

    @ObservedObject var document: VectorDocument

    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool

    @State private var isReflecting = false
    @State private var reflectionStarted = false
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var reflectionAnchorPoint: CGPoint = .zero

    private let handleSize: CGFloat = 10

    private var boundsInWorld: CGRect {
        return shape.isGroupContainer ? shape.groupBounds : shape.bounds
    }

    private func screenPoint(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: p.x * zoomLevel + canvasOffset.x, y: p.y * zoomLevel + canvasOffset.y)
    }

    var body: some View {
        let bounds = boundsInWorld
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        ZStack {
            Canvas { context, size in
                let tl = screenPoint(CGPoint(x: bounds.minX, y: bounds.minY))
                let tr = screenPoint(CGPoint(x: bounds.maxX, y: bounds.minY))
                let br = screenPoint(CGPoint(x: bounds.maxX, y: bounds.maxY))
                let bl = screenPoint(CGPoint(x: bounds.minX, y: bounds.maxY))
                var rect = Path()
                rect.move(to: tl)
                rect.addLine(to: tr)
                rect.addLine(to: br)
                rect.addLine(to: bl)
                rect.closeSubpath()
                context.stroke(rect, with: .color(.white), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0], dashPhase: 2.0))
                context.stroke(rect, with: .color(.blue), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
            }
            .allowsHitTesting(false)
            if isReflecting && !previewTransform.isIdentity {
                Canvas { context, size in
                    let zoom = zoomLevel
                    let offset = canvasOffset
                    let currentTransform = previewTransform
                    var path = Path()
                    if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                        for memberID in shape.memberIDs {
                            if let memberObject = document.snapshot.objects[memberID] {
                                let memberShape = memberObject.shape
                                appendPreviewElements(of: memberShape, to: &path, baseTransform: memberShape.transform, currentTransform: currentTransform, zoom: zoom, offset: offset)
                            }
                        }
                    } else {
                        appendPreviewElements(of: shape, to: &path, baseTransform: shape.transform, currentTransform: currentTransform, zoom: zoom, offset: offset)
                    }
                    context.stroke(path, with: .color(.blue.opacity(0.8)), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0]))
                    drawAxis(context: context, zoom: zoom, offset: offset)
                }
                .allowsHitTesting(false)
                .id("\(previewTransform.a)_\(previewTransform.b)_\(previewTransform.tx)_\(previewTransform.ty)")
            }
            midpointHandle(at: CGPoint(x: bounds.midX, y: bounds.minY), horizontal: false)
            midpointHandle(at: CGPoint(x: bounds.midX, y: bounds.maxY), horizontal: false)
            midpointHandle(at: CGPoint(x: bounds.minX, y: bounds.midY), horizontal: true)
            midpointHandle(at: CGPoint(x: bounds.maxX, y: bounds.midY), horizontal: true)
            Circle()
                .fill(Color.red)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(screenPoint(center))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handleCenterReflection(dragValue: value, center: center)
                        }
                        .onEnded { _ in
                            finishReflection()
                        }
                )
        }
        .onAppear {
            initialTransform = shape.transform
        }
    }

    @ViewBuilder
    private func midpointHandle(at worldPoint: CGPoint, horizontal: Bool) -> some View {
        Rectangle()
            .fill(Color.green)
            .stroke(Color.white, lineWidth: 1.0)
            .frame(width: handleSize, height: handleSize)
            .position(screenPoint(worldPoint))
            .onTapGesture {
                performFlip(horizontal: horizontal)
            }
    }

    private func appendPreviewElements(of previewShape: VectorShape, to path: inout Path, baseTransform: CGAffineTransform, currentTransform: CGAffineTransform, zoom: Double, offset: CGPoint) {
        for element in previewShape.path.elements {
            switch element {
            case .move(let to):
                let p = to.cgPoint.applying(baseTransform).applying(currentTransform)
                path.move(to: CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y))
            case .line(let to):
                let p = to.cgPoint.applying(baseTransform).applying(currentTransform)
                path.addLine(to: CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y))
            case .curve(let to, let control1, let control2):
                let tp = to.cgPoint.applying(baseTransform).applying(currentTransform)
                let tc1 = control1.cgPoint.applying(baseTransform).applying(currentTransform)
                let tc2 = control2.cgPoint.applying(baseTransform).applying(currentTransform)
                path.addCurve(to: CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y),
                              control1: CGPoint(x: tc1.x * zoom + offset.x, y: tc1.y * zoom + offset.y),
                              control2: CGPoint(x: tc2.x * zoom + offset.x, y: tc2.y * zoom + offset.y))
            case .quadCurve(let to, let control):
                let tp = to.cgPoint.applying(baseTransform).applying(currentTransform)
                let tc = control.cgPoint.applying(baseTransform).applying(currentTransform)
                path.addQuadCurve(to: CGPoint(x: tp.x * zoom + offset.x, y: tp.y * zoom + offset.y),
                                  control: CGPoint(x: tc.x * zoom + offset.x, y: tc.y * zoom + offset.y))
            case .close:
                path.closeSubpath()
            }
        }
    }

    private func drawAxis(context: GraphicsContext, zoom: Double, offset: CGPoint) {
        let anchorScreen = CGPoint(x: reflectionAnchorPoint.x * zoom + offset.x, y: reflectionAnchorPoint.y * zoom + offset.y)
        let dx = startLocation.x - anchorScreen.x
        let dy = startLocation.y - anchorScreen.y
        let length = max(sqrt(dx * dx + dy * dy), 1.0)
        let ux = dx / length
        let uy = dy / length
        let extent: CGFloat = 4000.0
        var axis = Path()
        axis.move(to: CGPoint(x: anchorScreen.x - ux * extent, y: anchorScreen.y - uy * extent))
        axis.addLine(to: CGPoint(x: anchorScreen.x + ux * extent, y: anchorScreen.y + uy * extent))
        context.stroke(axis, with: .color(.red.opacity(0.7)), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [6.0, 4.0]))
    }

    private func handleCenterReflection(dragValue: DragGesture.Value, center: CGPoint) {
        if !reflectionStarted {
            reflectionStarted = true
            document.isHandleScalingActive = true
            initialTransform = shape.transform
            reflectionAnchorPoint = center
            startLocation = dragValue.location
        }
        let anchorScreenX = reflectionAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = reflectionAnchorPoint.y * zoomLevel + canvasOffset.y
        let axisVector = CGPoint(x: dragValue.location.x - anchorScreenX, y: dragValue.location.y - anchorScreenY)
        if abs(axisVector.x) < 0.001 && abs(axisVector.y) < 0.001 {
            return
        }
        var axisAngle = atan2(axisVector.y, axisVector.x)
        let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
        if isShiftCurrentlyPressed {
            let increment: CGFloat = .pi / 4
            axisAngle = round(axisAngle / increment) * increment
        }
        calculatePreviewReflection(axisAngle: axisAngle, anchor: reflectionAnchorPoint)
    }

    private func performFlip(horizontal: Bool) {
        let bounds = boundsInWorld
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        initialTransform = shape.transform
        reflectionAnchorPoint = center
        let axisAngle: CGFloat = horizontal ? (.pi / 2.0) : 0.0
        calculatePreviewReflection(axisAngle: axisAngle, anchor: center)
        finishReflection()
    }

    private func calculatePreviewReflection(axisAngle: CGFloat, anchor: CGPoint) {
        let twoTheta = 2.0 * axisAngle
        let cos2 = cos(twoTheta)
        let sin2 = sin(twoTheta)
        let reflectMatrix = CGAffineTransform(a: cos2, b: sin2, c: sin2, d: -cos2, tx: 0, ty: 0)
        let reflectionTransform = CGAffineTransform(translationX: -anchor.x, y: -anchor.y)
            .concatenating(reflectMatrix)
            .concatenating(CGAffineTransform(translationX: anchor.x, y: anchor.y))
        previewTransform = initialTransform.concatenating(reflectionTransform)
        isReflecting = true
    }

    private func finishReflection() {
        reflectionStarted = false
        isReflecting = false
        document.isHandleScalingActive = false
        if previewTransform.isIdentity {
            previewTransform = .identity
            return
        }
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
            applyReflectionTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
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
        }
        } else {
            Log.error("❌ REFLECT FAILED: Could not find shape in unified objects system", category: .error)
        }
        previewTransform = .identity
    }

    private func applyReflectionTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform
        if currentTransform.isIdentity {
            return
        }
        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
            document.applyTransformToGroup(groupID: shape.id, transform: currentTransform)
            reflectGroupGradients(groupID: shape.id, transform: currentTransform)
            return
        }
        let oldBounds = boundsOfElements(shape.path.elements)
        var transformedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                transformedElements.append(.move(to: VectorPoint(to.cgPoint.applying(currentTransform))))
            case .line(let to):
                transformedElements.append(.line(to: VectorPoint(to.cgPoint.applying(currentTransform))))
            case .curve(let to, let control1, let control2):
                transformedElements.append(.curve(
                    to: VectorPoint(to.cgPoint.applying(currentTransform)),
                    control1: VectorPoint(control1.cgPoint.applying(currentTransform)),
                    control2: VectorPoint(control2.cgPoint.applying(currentTransform))
                ))
            case .quadCurve(let to, let control):
                transformedElements.append(.quadCurve(
                    to: VectorPoint(to.cgPoint.applying(currentTransform)),
                    control: VectorPoint(control.cgPoint.applying(currentTransform))
                ))
            case .close:
                transformedElements.append(.close)
            }
        }
        let newBounds = boundsOfElements(transformedElements)
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed, fillRule: shape.path.fillRule.cgPathFillRule)
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
        reflectGradientForShape(id: currentShape.id, transform: currentTransform, oldBounds: oldBounds, newBounds: newBounds)
    }

    private func reflectGroupGradients(groupID: UUID, transform: CGAffineTransform) {
        guard let object = document.snapshot.objects[groupID] else { return }
        var memberIDs: [UUID] = []
        switch object.objectType {
        case .group(let s), .clipGroup(let s):
            memberIDs = s.memberIDs
        default:
            return
        }
        for memberID in memberIDs {
            guard let memberObject = document.snapshot.objects[memberID] else { continue }
            switch memberObject.objectType {
            case .group, .clipGroup:
                reflectGroupGradients(groupID: memberID, transform: transform)
            default:
                let memberShape = memberObject.shape
                let bounds = boundsOfElements(memberShape.path.elements)
                reflectGradientForShape(id: memberID, transform: transform, oldBounds: bounds, newBounds: bounds)
            }
        }
    }

    private func reflectGradientForShape(id: UUID, transform: CGAffineTransform, oldBounds: CGRect, newBounds: CGRect) {
        guard let object = document.snapshot.objects[id], let gradient = object.shape.fillStyle?.gradient else { return }
        let reflected = reflectGradient(gradient, transform: transform, oldBounds: oldBounds, newBounds: newBounds)
        document.updateShapeByID(id) { s in
            if var fill = s.fillStyle {
                fill.color = .gradient(reflected)
                s.fillStyle = fill
            }
        }
    }

    private func reflectGradient(_ gradient: VectorGradient, transform: CGAffineTransform, oldBounds: CGRect, newBounds: CGRect) -> VectorGradient {
        func remap(_ p: CGPoint) -> CGPoint {
            let worldX = oldBounds.minX + p.x * oldBounds.width
            let worldY = oldBounds.minY + p.y * oldBounds.height
            let r = CGPoint(x: worldX, y: worldY).applying(transform)
            let nx = newBounds.width != 0 ? (r.x - newBounds.minX) / newBounds.width : p.x
            let ny = newBounds.height != 0 ? (r.y - newBounds.minY) / newBounds.height : p.y
            return CGPoint(x: nx, y: ny)
        }
        func reflectedAngle(_ degrees: Double) -> Double {
            let rad = degrees * .pi / 180.0
            let dx = cos(rad)
            let dy = sin(rad)
            let rx = Double(transform.a) * dx + Double(transform.c) * dy
            let ry = Double(transform.b) * dx + Double(transform.d) * dy
            return atan2(ry, rx) * 180.0 / .pi
        }
        switch gradient {
        case .linear(var lg):
            lg.originPoint = remap(lg.originPoint)
            lg.startPoint = remap(lg.startPoint)
            lg.endPoint = remap(lg.endPoint)
            lg.storedAngle = reflectedAngle(lg.storedAngle)
            return .linear(lg)
        case .radial(var rg):
            rg.originPoint = remap(rg.originPoint)
            rg.centerPoint = remap(rg.centerPoint)
            if let focal = rg.focalPoint {
                rg.focalPoint = remap(focal)
            }
            rg.angle = reflectedAngle(rg.angle)
            return .radial(rg)
        }
    }

    private func boundsOfElements(_ elements: [PathElement]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        func include(_ p: CGPoint) {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        for element in elements {
            switch element {
            case .move(let to), .line(let to):
                include(to.cgPoint)
            case .curve(let to, let control1, let control2):
                include(to.cgPoint)
                include(control1.cgPoint)
                include(control2.cgPoint)
            case .quadCurve(let to, let control):
                include(to.cgPoint)
                include(control.cgPoint)
            case .close:
                break
            }
        }
        if minX > maxX || minY > maxY {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
                shape.cornerRadii[i] = max(0.0, shape.cornerRadii[i] * Double(averageScale))
            }
        }
    }
}
