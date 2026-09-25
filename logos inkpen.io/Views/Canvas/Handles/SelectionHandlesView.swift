import SwiftUI
import AppKit

struct SelectionHandlesView: View {

    @ObservedObject var document: VectorDocument

    let geometry: GeometryProxy
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool
    let isOptionPressed: Bool
    let isCommandPressed: Bool
    let isTemporarySelectionViaCommand: Bool
    let dragPreviewDelta: CGPoint
    let transformBoxOpacity: Double

    @Binding var liveScaleTransform: CGAffineTransform
    @Binding var liveScaleDimensions: CGSize
    private var selectionID: String {
        document.viewState.selectedObjectIDs.map { $0.uuidString }.sorted().joined()
    }

    var body: some View {
        ZStack {
            if !document.viewState.selectedObjectIDs.isEmpty {
                if document.viewState.selectedObjectIDs.count > 1 {
                    renderCombinedSelectionBox()
                } else {
                    ForEach(Array(document.viewState.selectedObjectIDs), id: \.self) { selectedID in
                        if let newVectorObject = document.snapshot.objects[selectedID] {
                            if case .group(let groupShape) = newVectorObject.objectType {
                                ForEach(groupShape.groupedShapes, id: \.id) { childShape in
                                    if document.viewState.selectedObjectIDs.contains(childShape.id) {
                                        renderHandlesForShape(childShape)
                                    }
                                }
                            }
                            switch newVectorObject.objectType {
                            case .guide:
                                EmptyView()
                            case .shape(let shape),
                                 .image(let shape),
                                 .warp(let shape),
                                 .group(let shape),
                                 .clipGroup(let shape),
                                 .clipMask(let shape),
                                 .text(let shape):
                                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                                if !isBackgroundShape {
                                    if document.viewState.currentTool == .warp {
                                        EnvelopeHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset
                                        )
                                    } else if shape.isWarpObject {
                                        PersistentWarpMarquee(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isEnvelopeTool: false
                                        )
                                    } else {
                                        let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                                                 .circle, .ellipse, .oval, .egg, .cone,
                                                                 .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                                                 .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)
                                        if document.viewState.currentTool == .selection || document.viewState.currentTool == .font || isShapeDrawingTool {
                                            TransformBoxHandles(
                                                document: document,
                                                shape: shape,
                                                zoomLevel: zoomLevel,
                                                canvasOffset: canvasOffset,
                                                dragPreviewDelta: dragPreviewDelta,
                                                transformBoxOpacity: transformBoxOpacity,
                                                isShiftPressed: isShiftPressed,
                                                transformOrigin: document.viewState.transformOrigin,
                                                strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5),
                                                liveScaleTransform: $liveScaleTransform,
                                                liveScaleDimensions: $liveScaleDimensions
                                            )
                                    } else if document.viewState.currentTool == .scale {
                                        ScaleHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed,
                                            liveScaleTransform: $liveScaleTransform,
                                            liveScaleDimensions: $liveScaleDimensions
                                        )
                                    } else if document.viewState.currentTool == .rotate {
                                        RotateHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed
                                        )
                                    } else if document.viewState.currentTool == .reflect {
                                        ReflectHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed
                                        )
                                    } else if document.viewState.currentTool == .shear {
                                        ShearHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }

    @ViewBuilder
    private func renderHandlesForShape(_ shape: VectorShape) -> some View {
        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
        if !isBackgroundShape {
            if document.viewState.currentTool == .warp {
                EnvelopeHandles(
                    document: document,
                    shape: shape,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset
                )
            } else if shape.isWarpObject {
                PersistentWarpMarquee(
                    document: document,
                    shape: shape,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    isEnvelopeTool: false
                )
            } else {
                let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                         .circle, .ellipse, .oval, .egg, .cone,
                                         .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                         .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)
                if document.viewState.currentTool == .selection || document.viewState.currentTool == .font || isShapeDrawingTool {
                    TransformBoxHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        dragPreviewDelta: dragPreviewDelta,
                        transformBoxOpacity: transformBoxOpacity,
                        isShiftPressed: isShiftPressed,
                        transformOrigin: document.viewState.transformOrigin,
                        strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5),
                        liveScaleTransform: $liveScaleTransform,
                        liveScaleDimensions: $liveScaleDimensions
                    )
                } else if document.viewState.currentTool == .scale {
                    ScaleHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed,
                        liveScaleTransform: $liveScaleTransform,
                        liveScaleDimensions: $liveScaleDimensions
                    )
                } else if document.viewState.currentTool == .rotate {
                    RotateHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                } else if document.viewState.currentTool == .reflect {
                    ReflectHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                } else if document.viewState.currentTool == .shear {
                    ShearHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                }
            }
        }
    }

    private var combinedSelectionBounds: CGRect? {
        var combinedBounds: CGRect?

        let settings = ApplicationSettings.shared
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                let textBounds: CGRect
                if let position = shape.textPosition, let size = shape.areaSize {
                    textBounds = CGRect(origin: position, size: size)
                } else {
                    textBounds = shape.bounds.applying(shape.transform)
                }
                if let existing = combinedBounds {
                    combinedBounds = existing.union(textBounds)
                } else {
                    combinedBounds = textBounds
                }
                continue
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                var baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                if settings.boundingBoxIncludesStrokes && shape.strokeStyle != nil && shape.typography == nil {
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeExpansion = strokeWidth / 2.0
                    baseBounds = baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                }
                let transformedBounds = baseBounds.applying(shape.transform)
                if let existing = combinedBounds {
                    combinedBounds = existing.union(transformedBounds)
                } else {
                    combinedBounds = transformedBounds
                }
            }
        }
        return combinedBounds
    }

    private func createCombinedShape(from bounds: CGRect) -> VectorShape {
        var combinedShape = VectorShape(
            name: "Combined Selection",
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(bounds.width, 0)),
                .line(to: VectorPoint(bounds.width, bounds.height)),
                .line(to: VectorPoint(0, bounds.height)),
                .close
            ], isClosed: true)
        )
        combinedShape.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        combinedShape.transform = CGAffineTransform(translationX: bounds.origin.x, y: bounds.origin.y)
        return combinedShape
    }

    @ViewBuilder
    private func renderCombinedSelectionBox() -> some View {
        if let bounds = combinedSelectionBounds {
            let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                     .circle, .ellipse, .oval, .egg, .cone,
                                     .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                     .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)
            if document.viewState.currentTool == .selection || document.viewState.currentTool == .font || isShapeDrawingTool {
                TransformBoxHandles(
                    document: document,
                    shape: createCombinedShape(from: bounds),
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    dragPreviewDelta: dragPreviewDelta,
                    transformBoxOpacity: transformBoxOpacity,
                    isShiftPressed: isShiftPressed,
                    transformOrigin: document.viewState.transformOrigin,
                    strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5),
                    liveScaleTransform: $liveScaleTransform,
                    liveScaleDimensions: $liveScaleDimensions
                )
            }
        }
    }
}
