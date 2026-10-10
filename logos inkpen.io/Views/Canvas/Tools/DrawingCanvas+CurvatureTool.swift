import SwiftUI

struct CurvatureNode {
    var point: CGPoint
    var isCorner: Bool
}

extension DrawingCanvas {

    // MARK: - Curve computation

    /// Smooth path through the nodes (Illustrator Curvature tool): smooth nodes get a tangent along the line
    /// between their neighbours, corner nodes get no handles, and an end node is bent like a circular arc.
    static func curvatureElements(nodes: [CurvatureNode], closed: Bool) -> [PathElement] {
        guard let first = nodes.first else { return [] }
        var elements: [PathElement] = [.move(to: VectorPoint(first.point))]
        let count = nodes.count
        guard count > 1 else { return elements }
        let useClosed = closed && count >= 3

        func unit(_ a: CGPoint, _ b: CGPoint) -> CGPoint? {
            let dx = b.x - a.x, dy = b.y - a.y
            let length = hypot(dx, dy)
            return length > 1e-9 ? CGPoint(x: dx / length, y: dy / length) : nil
        }
        func previousIndex(_ i: Int) -> Int? {
            if i > 0 { return i - 1 }
            return useClosed ? count - 1 : nil
        }
        func nextIndex(_ i: Int) -> Int? {
            if i < count - 1 { return i + 1 }
            return useClosed ? 0 : nil
        }
        func interiorTangent(_ i: Int) -> CGPoint? {
            guard let p = previousIndex(i), let n = nextIndex(i) else { return nil }
            let a = unit(nodes[p].point, nodes[i].point)
            let b = unit(nodes[i].point, nodes[n].point)
            guard let incoming = a ?? b, let outgoing = b ?? a else { return nil }
            let sum = CGPoint(x: incoming.x + outgoing.x, y: incoming.y + outgoing.y)
            let length = hypot(sum.x, sum.y)
            return length > 1e-6 ? CGPoint(x: sum.x / length, y: sum.y / length) : outgoing
        }
        func tangent(_ i: Int) -> CGPoint? {
            if let t = interiorTangent(i) { return t }
            if let n = nextIndex(i), previousIndex(i) == nil, let u = unit(nodes[i].point, nodes[n].point) {
                let neighbour = (!nodes[n].isCorner ? interiorTangent(n) : nil) ?? u
                let dot = neighbour.x * u.x + neighbour.y * u.y
                return CGPoint(x: 2 * dot * u.x - neighbour.x, y: 2 * dot * u.y - neighbour.y)
            }
            if let p = previousIndex(i), nextIndex(i) == nil, let u = unit(nodes[p].point, nodes[i].point) {
                let neighbour = (!nodes[p].isCorner ? interiorTangent(p) : nil) ?? u
                let dot = neighbour.x * u.x + neighbour.y * u.y
                return CGPoint(x: 2 * dot * u.x - neighbour.x, y: 2 * dot * u.y - neighbour.y)
            }
            return nil
        }
        func outHandle(_ i: Int) -> CGPoint? {
            guard !nodes[i].isCorner, let n = nextIndex(i), let t = tangent(i) else { return nil }
            let length = hypot(nodes[n].point.x - nodes[i].point.x, nodes[n].point.y - nodes[i].point.y) / 3
            return CGPoint(x: nodes[i].point.x + t.x * length, y: nodes[i].point.y + t.y * length)
        }
        func inHandle(_ i: Int) -> CGPoint? {
            guard !nodes[i].isCorner, let p = previousIndex(i), let t = tangent(i) else { return nil }
            let length = hypot(nodes[i].point.x - nodes[p].point.x, nodes[i].point.y - nodes[p].point.y) / 3
            return CGPoint(x: nodes[i].point.x - t.x * length, y: nodes[i].point.y - t.y * length)
        }
        func segment(from i: Int, to j: Int) -> PathElement {
            let c1 = outHandle(i)
            let c2 = inHandle(j)
            if c1 == nil && c2 == nil { return .line(to: VectorPoint(nodes[j].point)) }
            return .curve(
                to: VectorPoint(nodes[j].point),
                control1: VectorPoint(c1 ?? nodes[i].point),
                control2: VectorPoint(c2 ?? nodes[j].point)
            )
        }
        for i in 1..<count { elements.append(segment(from: i - 1, to: i)) }
        if useClosed {
            elements.append(segment(from: count - 1, to: 0))
            elements.append(.close)
        }
        return elements
    }

    // MARK: - Interaction

    private func curvatureNodeTolerance() -> Double { 7.0 / zoomLevel }

    private func curvatureNodeIndex(near location: CGPoint) -> Int? {
        let tolerance = curvatureNodeTolerance()
        var best: (Int, Double)?
        for (index, node) in curvatureNodes.enumerated() {
            let d = hypot(node.point.x - location.x, node.point.y - location.y)
            if d <= tolerance, d < (best?.1 ?? .infinity) { best = (index, d) }
        }
        return best?.0
    }

    private func syncCurvatureShape() {
        guard let id = curvatureShapeID else { return }
        let elements = DrawingCanvas.curvatureElements(nodes: curvatureNodes, closed: false)
        document.updateShapeByID(id) { shape in
            shape.path = VectorPath(elements: elements)
            shape.updateBounds()
        }
    }

    private func startCurvatureShape(at location: CGPoint) {
        guard let layerIndex = document.selectedLayerIndex,
              layerIndex >= 0, layerIndex < document.snapshot.layers.count else { return }
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            placement: document.strokeDefaults.placement,
            dashPattern: [],
            lineCap: document.strokeDefaults.lineCap,
            lineJoin: document.strokeDefaults.lineJoin,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let shape = VectorShape(
            name: "Curvature Path",
            path: VectorPath(elements: [.move(to: VectorPoint(location))]),
            strokeStyle: strokeStyle,
            fillStyle: nil
        )
        let object = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: VectorObject.determineType(for: shape))
        document.snapshot.objects[shape.id] = object
        document.snapshot.layers[layerIndex].objectIDs.append(shape.id)
        document.triggerLayerUpdate(for: layerIndex)
        document.viewState.orderedSelectedObjectIDs = [shape.id]
        document.viewState.selectedObjectIDs = [shape.id]
        curvatureShapeID = shape.id
        curvatureNodes = [CurvatureNode(point: location, isCorner: false)]
    }

    /// Click adds a smooth point; clicking the first point (3+ points) closes the path;
    /// Option-click on a point toggles smooth/corner.
    internal func handleCurvatureTap(at canvasLocation: CGPoint) {
        let location = applySnapping(to: canvasLocation)
        if curvatureShapeID == nil {
            startCurvatureShape(at: location)
            return
        }
        if curvatureNodes.count >= 3, curvatureNodeIndex(near: canvasLocation) == 0 {
            finishCurvaturePath(close: true)
            return
        }
        if let index = curvatureNodeIndex(near: canvasLocation) {
            if NSEvent.modifierFlags.contains(.option) {
                curvatureNodes[index].isCorner.toggle()
                syncCurvatureShape()
            }
            return
        }
        curvatureNodes.append(CurvatureNode(point: location, isCorner: false))
        syncCurvatureShape()
    }

    /// Double-click on a point toggles it between smooth and corner. Returns false when no point is under the cursor.
    internal func handleCurvatureDoubleClick(at canvasLocation: CGPoint) -> Bool {
        guard curvatureShapeID != nil, let index = curvatureNodeIndex(near: canvasLocation) else { return false }
        curvatureNodes[index].isCorner.toggle()
        syncCurvatureShape()
        return true
    }

    /// Dragging a placed point moves it and the curve follows.
    internal func handleCurvatureDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard curvatureShapeID != nil else { return }
        if !curvatureDragEvaluated {
            curvatureDragEvaluated = true
            curvatureDragIndex = curvatureNodeIndex(near: screenToCanvas(value.startLocation, geometry: geometry))
        }
        guard let index = curvatureDragIndex, index < curvatureNodes.count else { return }
        curvatureNodes[index].point = applySnapping(to: screenToCanvas(value.location, geometry: geometry))
        syncCurvatureShape()
    }

    internal func handleCurvatureDragEnd() {
        curvatureDragIndex = nil
        curvatureDragEvaluated = false
    }

    /// Delete/Backspace removes the last point placed.
    @discardableResult
    internal func removeLastCurvatureNode() -> Bool {
        guard curvatureShapeID != nil, curvatureNodes.count >= 2 else { return false }
        curvatureNodes.removeLast()
        syncCurvatureShape()
        return true
    }

    /// Return / Esc / switching tools ends the path (open, or closed when `close` is set).
    internal func finishCurvaturePath(close: Bool = false) {
        guard let id = curvatureShapeID else { return }
        let nodes = curvatureNodes
        curvatureShapeID = nil
        curvatureNodes = []
        curvatureDragIndex = nil
        curvatureDragEvaluated = false
        guard let object = document.snapshot.objects[id] else { return }
        let layerIndex = object.layerIndex
        if nodes.count < 2 {
            document.snapshot.objects.removeValue(forKey: id)
            if layerIndex >= 0, layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == id }
            }
            document.viewState.selectedObjectIDs.remove(id)
            document.viewState.orderedSelectedObjectIDs.removeAll { $0 == id }
            document.triggerLayerUpdate(for: layerIndex)
            return
        }
        let closed = close && nodes.count >= 3
        let elements = DrawingCanvas.curvatureElements(nodes: nodes, closed: closed)
        let fill = FillStyle(color: document.defaultFillColor, opacity: document.defaultFillOpacity)
        document.updateShapeByID(id) { shape in
            shape.path = VectorPath(elements: elements, isClosed: closed)
            if closed { shape.fillStyle = fill }
            shape.updateBounds()
        }
        if let finished = document.snapshot.objects[id] {
            document.commandManager.recordCompletedCommand(AddObjectCommand(object: finished))
        }
        document.triggerLayerUpdate(for: layerIndex)
    }

    // MARK: - Overlay

    @ViewBuilder
    internal func curvatureOverlay(geometry: GeometryProxy) -> some View {
        if curvatureShapeID != nil, document.viewState.currentTool == .curvature, !curvatureNodes.isEmpty {
            let cursor = currentMouseLocation.map { screenToCanvas($0, geometry: geometry) }
            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)
                let accent = Color.accentColor
                if let cursor = cursor {
                    let tentative = curvatureNodes + [CurvatureNode(point: applySnapping(to: cursor), isCorner: false)]
                    let elements = DrawingCanvas.curvatureElements(nodes: tentative, closed: false)
                    let path = Path { path in addPathElements(elements, to: &path) }
                    context.stroke(
                        path,
                        with: .color(accent.opacity(0.7)),
                        style: SwiftUI.StrokeStyle(lineWidth: max(1.0, 1.0 / zoomLevel), dash: [4 / zoomLevel, 3 / zoomLevel])
                    )
                }
                let half = 3.5 / zoomLevel
                for node in curvatureNodes {
                    let rect = CGRect(x: node.point.x - half, y: node.point.y - half, width: half * 2, height: half * 2)
                    let shape = node.isCorner
                        ? Path { $0.move(to: CGPoint(x: rect.midX, y: rect.minY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); $0.addLine(to: CGPoint(x: rect.minX, y: rect.midY)); $0.closeSubpath() }
                        : Path(ellipseIn: rect)
                    context.fill(shape, with: .color(.white))
                    context.stroke(shape, with: .color(accent), lineWidth: max(1.0, 1.0 / zoomLevel))
                }
            }
            .allowsHitTesting(false)
        }
    }
}
