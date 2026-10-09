import SwiftUI

private let polygonCornerSourceKey = "cornerSourcePolygon"

struct PolygonCornerModel {
    var points: [CGPoint]
    var radii: [Double]
}

private struct PolygonCornerGeometry {
    let vertex: CGPoint
    let u1: CGPoint
    let u2: CGPoint
    let theta: Double
    let maxRadius: Double

    var bisector: CGPoint {
        let sum = CGPoint(x: u1.x + u2.x, y: u1.y + u2.y)
        let length = max(hypot(sum.x, sum.y), 0.0001)
        return CGPoint(x: sum.x / length, y: sum.y / length)
    }

    /// Distance from the vertex to the middle of the rounded arc.
    var arcDistancePerRadius: Double { 1.0 / sin(theta / 2.0) - 1.0 }
}

private func polygonCornerGeometry(_ points: [CGPoint], _ i: Int) -> PolygonCornerGeometry? {
    let n = points.count
    guard n >= 3 else { return nil }
    let p0 = points[(i - 1 + n) % n]
    let p1 = points[i]
    let p2 = points[(i + 1) % n]
    let v1 = CGPoint(x: p0.x - p1.x, y: p0.y - p1.y)
    let v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
    let l1 = hypot(v1.x, v1.y)
    let l2 = hypot(v2.x, v2.y)
    guard l1 > 0.001, l2 > 0.001 else { return nil }
    let u1 = CGPoint(x: v1.x / l1, y: v1.y / l1)
    let u2 = CGPoint(x: v2.x / l2, y: v2.y / l2)
    let dot = max(-1.0, min(1.0, Double(u1.x * u2.x + u1.y * u2.y)))
    let theta = acos(dot)
    guard theta > 0.05, theta < Double.pi - 0.02 else { return nil }
    let maxRadius = Double(min(l1, l2)) / 2.0 * tan(theta / 2.0)
    return PolygonCornerGeometry(vertex: p1, u1: u1, u2: u2, theta: theta, maxRadius: maxRadius)
}

/// Builds a closed path from polygon vertices with each corner replaced by a circular arc of the given radius.
func roundedPolygonPath(points: [CGPoint], radii: [Double]) -> VectorPath {
    let n = points.count
    var entries: [(entry: CGPoint, exit: CGPoint, c1: CGPoint, c2: CGPoint)?] = []
    for i in 0..<n {
        let radius = radii.indices.contains(i) ? radii[i] : 0.0
        guard radius > 0.001, let g = polygonCornerGeometry(points, i) else {
            entries.append(nil)
            continue
        }
        let r = min(radius, g.maxRadius)
        let t = r / tan(g.theta / 2.0)
        let handle = 4.0 / 3.0 * tan((Double.pi - g.theta) / 4.0) * r
        let a = CGPoint(x: g.vertex.x + g.u1.x * t, y: g.vertex.y + g.u1.y * t)
        let b = CGPoint(x: g.vertex.x + g.u2.x * t, y: g.vertex.y + g.u2.y * t)
        let c1 = CGPoint(x: a.x - g.u1.x * handle, y: a.y - g.u1.y * handle)
        let c2 = CGPoint(x: b.x - g.u2.x * handle, y: b.y - g.u2.y * handle)
        entries.append((a, b, c1, c2))
    }
    var elements: [PathElement] = []
    if let first = entries[0] {
        elements.append(.move(to: VectorPoint(first.exit)))
    } else {
        elements.append(.move(to: VectorPoint(points[0])))
    }
    for i in 1..<n {
        if let e = entries[i] {
            elements.append(.line(to: VectorPoint(e.entry)))
            elements.append(.curve(to: VectorPoint(e.exit), control1: VectorPoint(e.c1), control2: VectorPoint(e.c2)))
        } else {
            elements.append(.line(to: VectorPoint(points[i])))
        }
    }
    if let first = entries[0] {
        elements.append(.line(to: VectorPoint(first.entry)))
        elements.append(.curve(to: VectorPoint(first.exit), control1: VectorPoint(first.c1), control2: VectorPoint(first.c2)))
    }
    elements.append(.close)
    return VectorPath(elements: elements, isClosed: true)
}

private func flattenedPathPoints(_ elements: [PathElement]) -> (signature: [Int], points: [CGPoint]) {
    var signature: [Int] = []
    var points: [CGPoint] = []
    for element in elements {
        switch element {
        case .move(let p): signature.append(0); points.append(p.cgPoint)
        case .line(let p): signature.append(1); points.append(p.cgPoint)
        case .curve(let p, let c1, let c2): signature.append(2); points.append(contentsOf: [c1.cgPoint, c2.cgPoint, p.cgPoint])
        case .quadCurve(let p, let c): signature.append(3); points.append(contentsOf: [c.cgPoint, p.cgPoint])
        case .close: signature.append(4)
        }
    }
    return (signature, points)
}

private func parsePolygonVertices(_ elements: [PathElement]) -> [CGPoint]? {
    var points: [CGPoint] = []
    var closed = false
    for (index, element) in elements.enumerated() {
        switch element {
        case .move(let p):
            guard index == 0 else { return nil }
            points.append(p.cgPoint)
        case .line(let p):
            guard index > 0, !closed else { return nil }
            points.append(p.cgPoint)
        case .close:
            guard index == elements.count - 1 else { return nil }
            closed = true
        default:
            return nil
        }
    }
    guard closed else { return nil }
    if points.count > 1, let first = points.first, let last = points.last, hypot(first.x - last.x, first.y - last.y) < 0.01 {
        points.removeLast()
    }
    guard points.count >= 3 else { return nil }
    for i in 0..<points.count {
        let next = points[(i + 1) % points.count]
        if hypot(points[i].x - next.x, points[i].y - next.y) < 0.01 { return nil }
    }
    return points
}

private func encodePolygonSource(_ points: [CGPoint]) -> String {
    points.map { String(format: "%.6f,%.6f", Double($0.x), Double($0.y)) }.joined(separator: ";")
}

private func decodePolygonSource(_ text: String) -> [CGPoint]? {
    var points: [CGPoint] = []
    for pair in text.split(separator: ";") {
        let parts = pair.split(separator: ",")
        guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) else { return nil }
        points.append(CGPoint(x: x, y: y))
    }
    return points.count >= 3 ? points : nil
}

extension DrawingCanvas {

    /// A single selected, untransformed, closed polygon (straight edges only), or one that this tool rounded earlier in the session.
    internal func getSelectedPolygonShape() -> (shape: VectorShape, model: PolygonCornerModel)? {
        guard document.viewState.selectedObjectIDs.count == 1,
              let id = document.viewState.selectedObjectIDs.first,
              let object = document.snapshot.objects[id],
              case .shape(let shape) = object.objectType else { return nil }
        guard !shape.isGroup, !shape.isCompoundPath, !shape.isGuide, !shape.isWarpObject,
              shape.textContent == nil, shape.embeddedImageData == nil, shape.transform.isIdentity else { return nil }
        if let source = shape.metadata[polygonCornerSourceKey],
           let points = decodePolygonSource(source),
           shape.cornerRadii.count == points.count {
            let built = flattenedPathPoints(roundedPolygonPath(points: points, radii: shape.cornerRadii).elements)
            let current = flattenedPathPoints(shape.path.elements)
            if built.signature == current.signature, built.points.count == current.points.count, let b0 = built.points.first, let c0 = current.points.first {
                let dx = c0.x - b0.x
                let dy = c0.y - b0.y
                let matches = zip(built.points, current.points).allSatisfy {
                    abs($0.x + dx - $1.x) < 0.05 && abs($0.y + dy - $1.y) < 0.05
                }
                if matches {
                    let moved = points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
                    return (shape, PolygonCornerModel(points: moved, radii: shape.cornerRadii))
                }
            }
        }
        guard let points = parsePolygonVertices(shape.path.elements) else { return nil }
        return (shape, PolygonCornerModel(points: points, radii: Array(repeating: 0.0, count: points.count)))
    }

    private func polygonHandleCanvasPositions(model: PolygonCornerModel, radii: [Double]) -> [(index: Int, position: CGPoint)] {
        var result: [(index: Int, position: CGPoint)] = []
        for i in 0..<model.points.count {
            guard let g = polygonCornerGeometry(model.points, i) else { continue }
            let r = min(radii.indices.contains(i) ? radii[i] : 0.0, g.maxRadius)
            let d = r * g.arcDistancePerRadius
            let b = g.bisector
            result.append((i, CGPoint(x: g.vertex.x + b.x * d, y: g.vertex.y + b.y * d)))
        }
        return result
    }

    @ViewBuilder
    func polygonCornerRadiusTool(geometry: GeometryProxy) -> some View {
        if document.viewState.currentTool == .cornerRadius,
           let selected = getSelectedPolygonShape() {
            let model = selected.model
            let activeRadii = (isDraggingCorner && !liveCornerRadii.isEmpty) ? liveCornerRadii : model.radii
            let handles = polygonHandleCanvasPositions(model: model, radii: activeRadii)
            let screenHandles = handles.map { (index: $0.index, position: canvasToScreen($0.position, geometry: geometry)) }
            if isDraggingCorner && !liveCornerRadii.isEmpty {
                let previewPath = roundedPolygonPath(points: model.points, radii: liveCornerRadii)
                Path { path in
                    addPathElements(previewPath.elements, to: &path)
                }
                .stroke(Color.blue.opacity(0.8), lineWidth: 2.0 / zoomLevel)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
            }
            Canvas { context, _ in
                for handle in screenHandles {
                    let outer = CGRect(x: handle.position.x - 6, y: handle.position.y - 6, width: 12, height: 12)
                    context.fill(Path(ellipseIn: outer), with: .color(.orange.opacity(0.8)))
                    context.stroke(Path(ellipseIn: outer), with: .color(.white), lineWidth: 2.0)
                    let inner = CGRect(x: handle.position.x - 2, y: handle.position.y - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: inner), with: .color(.white))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handlePolygonCornerDrag(value: value, selected: selected, screenHandles: screenHandles, geometry: geometry)
                    }
                    .onEnded { value in
                        if isDraggingCorner {
                            finishPolygonCornerDrag(selected: selected)
                        } else if hypot(value.translation.width, value.translation.height) < 3 {
                            handleSelectionTap(at: screenToCanvas(value.location, geometry: geometry))
                        }
                    }
            )
        }
    }

    private func handlePolygonCornerDrag(
        value: DragGesture.Value,
        selected: (shape: VectorShape, model: PolygonCornerModel),
        screenHandles: [(index: Int, position: CGPoint)],
        geometry: GeometryProxy
    ) {
        let model = selected.model
        if !isDraggingCorner {
            var nearest: Int?
            var nearestDistance = CGFloat.infinity
            for handle in screenHandles {
                let distance = hypot(value.startLocation.x - handle.position.x, value.startLocation.y - handle.position.y)
                if distance < 15.0 && distance < nearestDistance {
                    nearestDistance = distance
                    nearest = handle.index
                }
            }
            guard let cornerIndex = nearest else { return }
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = model.radii[cornerIndex]
            sharedOriginalShape = selected.shape
            originalCornerRadii = model.radii
            liveCornerRadii = model.radii
        }
        guard let cornerIndex = draggedCornerIndex,
              let g = polygonCornerGeometry(model.points, cornerIndex),
              g.arcDistancePerRadius > 0.0001 else { return }
        currentMousePosition = value.location
        let canvasLocation = screenToCanvas(value.location, geometry: geometry)
        let canvasStart = screenToCanvas(cornerDragStart, geometry: geometry)
        let b = g.bisector
        let startDistance = initialCornerRadius * g.arcDistancePerRadius
        let projected = startDistance + Double((canvasLocation.x - canvasStart.x) * b.x + (canvasLocation.y - canvasStart.y) * b.y)
        let newRadius = max(0.0, min(g.maxRadius, projected / g.arcDistancePerRadius))
        let flags = NSEvent.modifierFlags
        let editsSingleCorner = flags.contains(.command) || flags.contains(.option)
        if editsSingleCorner {
            liveCornerRadii = originalCornerRadii
            liveCornerRadii[cornerIndex] = newRadius
        } else {
            let original = originalCornerRadii[cornerIndex]
            for i in 0..<liveCornerRadii.count {
                let wanted = original > 0 ? originalCornerRadii[i] * (newRadius / original) : newRadius
                let limit = polygonCornerGeometry(model.points, i)?.maxRadius ?? 0.0
                liveCornerRadii[i] = max(0.0, min(limit, wanted))
            }
        }
    }

    private func finishPolygonCornerDrag(selected: (shape: VectorShape, model: PolygonCornerModel)) {
        let model = selected.model
        let finalRadii = liveCornerRadii.map { $0 < 0.05 ? 0.0 : round($0 * 10) / 10 }
        if finalRadii.count == model.points.count, finalRadii != originalCornerRadii {
            let newPath = roundedPolygonPath(points: model.points, radii: finalRadii)
            let source = encodePolygonSource(model.points)
            let anyRounded = finalRadii.contains { $0 > 0 }
            document.modifyShapesWithUndo(shapeIDs: [selected.shape.id]) { shape in
                shape.path = newPath
                shape.cornerRadii = anyRounded ? finalRadii : []
                if anyRounded {
                    shape.metadata[polygonCornerSourceKey] = source
                } else {
                    shape.metadata.removeValue(forKey: polygonCornerSourceKey)
                }
                shape.updateBounds()
            }
        }
        sharedOriginalShape = nil
        liveCornerRadii.removeAll()
        originalCornerRadii.removeAll()
        isDraggingCorner = false
        draggedCornerIndex = nil
        cornerDragStart = .zero
        initialCornerRadius = 0.0
        currentMousePosition = .zero
    }
}
