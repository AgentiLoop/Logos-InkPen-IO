import SwiftUI

/// One non-overlapping region produced by dividing the selected shapes along all of their outlines.
struct ShapeBuilderRegion {
    var path: CGPath
    /// Index into the source shapes of the topmost shape covering this region.
    var owner: Int
}

extension DrawingCanvas {

    // MARK: - Session

    /// Divides the selected closed, filled shapes into their overlap regions. Returns false (and beeps) if fewer than two qualify.
    private func prepareShapeBuilderSession(beepOnFailure: Bool = true) -> Bool {
        var sources: [VectorShape] = []
        var layer: Int?
        for shape in document.getSelectedShapesInStackingOrder() {
            guard let object = document.snapshot.objects[shape.id],
                  shape.isVisible, !shape.isLocked,
                  shape.fillStyle != nil,
                  !shape.isGroup, !shape.isGroupContainer, !shape.isCompoundPath,
                  !shape.isClippingPath, !shape.isWarpObject, shape.textContent == nil,
                  shape.name != "Canvas Background", shape.name != "Pasteboard Background" else { continue }
            if layer == nil { layer = object.layerIndex }
            guard object.layerIndex == layer else { continue }
            sources.append(shape)
        }
        guard let layerIndex = layer, layerIndex >= 0, layerIndex < document.snapshot.layers.count,
              !document.snapshot.layers[layerIndex].isLocked,
              sources.count >= 2 else {
            if beepOnFailure { NSSound.beep() }
            return false
        }
        let paths: [CGPath] = sources.map { shape in
            var transform = shape.transform
            return shape.path.cgPath.copy(using: &transform) ?? shape.path.cgPath
        }
        let pieces = CoreGraphicsPathOperations.splitWithShapeTracking(paths, using: .winding)
        let regions = pieces.compactMap { piece -> ShapeBuilderRegion? in
            piece.1 < sources.count ? ShapeBuilderRegion(path: piece.0, owner: piece.1) : nil
        }
        guard !regions.isEmpty else {
            if beepOnFailure { NSSound.beep() }
            return false
        }
        shapeBuilderSources = sources
        shapeBuilderLayer = layerIndex
        shapeBuilderRegions = regions
        shapeBuilderTouched = []
        shapeBuilderLastPoint = nil
        return true
    }

    private func shapeBuilderRegionIndex(at point: CGPoint) -> Int? {
        shapeBuilderRegions.firstIndex { $0.path.contains(point, using: .winding) }
    }

    private func touchShapeBuilderRegions(from start: CGPoint, to end: CGPoint) {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let step = max(1.0 / zoomLevel, 0.5)
        let samples = max(1, Int(distance / step))
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            if let index = shapeBuilderRegionIndex(at: point), !shapeBuilderTouched.contains(index) {
                shapeBuilderTouched.append(index)
            }
        }
    }

    // MARK: - Gestures

    internal func handleShapeBuilderDragUpdate(at location: CGPoint) {
        if shapeBuilderAborted { return }
        if shapeBuilderRegions.isEmpty {
            guard prepareShapeBuilderSession() else {
                shapeBuilderAborted = true
                return
            }
        }
        touchShapeBuilderRegions(from: shapeBuilderLastPoint ?? location, to: location)
        shapeBuilderLastPoint = location
    }

    internal func handleShapeBuilderDragEnd() {
        defer { resetShapeBuilderSession() }
        guard !shapeBuilderAborted, !shapeBuilderRegions.isEmpty, !shapeBuilderTouched.isEmpty else { return }
        commitShapeBuilderSession(deleting: NSEvent.modifierFlags.contains(.option))
    }

    /// A plain click on a region separates it from the other overlapping shapes (Option-click deletes it).
    internal func handleShapeBuilderTap(at location: CGPoint) {
        resetShapeBuilderSession()
        guard prepareShapeBuilderSession() else { return }
        defer { resetShapeBuilderSession() }
        guard let index = shapeBuilderRegionIndex(at: location) else { return }
        shapeBuilderTouched = [index]
        commitShapeBuilderSession(deleting: NSEvent.modifierFlags.contains(.option))
    }

    /// Illustrator highlights the region under the cursor before the drag starts.
    internal func updateShapeBuilderHover(at location: CGPoint?) {
        guard let location, shapeBuilderLastPoint == nil else {
            shapeBuilderHoverIndex = nil
            return
        }
        let selection = document.viewState.selectedObjectIDs
        if shapeBuilderHoverSelection != selection {
            resetShapeBuilderSession()
            _ = prepareShapeBuilderSession(beepOnFailure: false)
            shapeBuilderHoverSelection = selection
        }
        let index = shapeBuilderRegionIndex(at: location)
        if index != shapeBuilderHoverIndex { shapeBuilderHoverIndex = index }
    }

    internal func resetShapeBuilderSession() {
        shapeBuilderHoverIndex = nil
        shapeBuilderHoverSelection = nil
        shapeBuilderRegions = []
        shapeBuilderSources = []
        shapeBuilderTouched = []
        shapeBuilderLastPoint = nil
        shapeBuilderAborted = false
    }

    // MARK: - Commit

    /// Illustrator Shape Builder: the touched regions merge into one shape (taking the appearance of the first region
    /// touched) or, with Option, are deleted. Everything that was not touched keeps its look: each source shape is
    /// rebuilt from the regions it still shows.
    private func commitShapeBuilderSession(deleting: Bool) {
        let regions = shapeBuilderRegions
        let sources = shapeBuilderSources
        let touched = shapeBuilderTouched
        let touchedSet = Set(touched)
        var results: [VectorShape] = []

        func makeShape(from source: VectorShape, path: CGPath) -> VectorShape {
            var shape = source
            shape.id = UUID()
            shape.path = VectorPath(cgPath: path, fillRule: .winding)
            shape.transform = .identity
            shape.updateBounds()
            return shape
        }

        var remainingByOwner: [Int: [CGPath]] = [:]
        for (index, region) in regions.enumerated() where !touchedSet.contains(index) {
            remainingByOwner[region.owner, default: []].append(region.path)
        }
        for owner in remainingByOwner.keys.sorted() {
            guard let paths = remainingByOwner[owner],
                  let united = CoreGraphicsPathOperations.unionMultiplePaths(paths) else { continue }
            results.append(makeShape(from: sources[owner], path: united))
        }
        if !deleting {
            let touchedPaths = touched.map { regions[$0].path }
            if let merged = CoreGraphicsPathOperations.unionMultiplePaths(touchedPaths) {
                results.append(makeShape(from: sources[regions[touched[0]].owner], path: merged))
            }
        }

        var removed: [UUID: VectorShape] = [:]
        for source in sources { removed[source.id] = source }
        var added: [UUID: VectorShape] = [:]
        for shape in results { added[shape.id] = shape }
        let command = GroupCommand(
            operation: .pathOperation,
            layerIndex: shapeBuilderLayer,
            removedObjectIDs: sources.map { $0.id },
            removedShapes: removed,
            addedObjectIDs: results.map { $0.id },
            addedShapes: added,
            oldSelectedObjectIDs: document.viewState.selectedObjectIDs,
            newSelectedObjectIDs: Set(results.map { $0.id })
        )
        document.commandManager.execute(command)
        document.viewState.orderedSelectedObjectIDs = results.map { $0.id }
    }

    // MARK: - Overlay

    /// Highlights the regions the Shape Builder drag has touched so far.
    @ViewBuilder
    internal func shapeBuilderOverlay(geometry: GeometryProxy) -> some View {
        if document.viewState.currentTool == .shapeBuilder,
           !shapeBuilderTouched.isEmpty || shapeBuilderHoverIndex != nil {
            let deleting = NSEvent.modifierFlags.contains(.option)
            let highlighted = shapeBuilderTouched.isEmpty ? [shapeBuilderHoverIndex ?? 0] : shapeBuilderTouched
            Canvas { context, _ in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)
                for index in highlighted where index < shapeBuilderRegions.count {
                    let path = Path(shapeBuilderRegions[index].path)
                    context.fill(path, with: .color((deleting ? Color.red : Color.blue).opacity(0.35)))
                    context.stroke(path, with: .color(deleting ? Color.red : Color.blue),
                                   style: SwiftUI.StrokeStyle(lineWidth: max(1.0, 1.5 / zoomLevel)))
                }
            }
            .allowsHitTesting(false)
        }
    }
}
