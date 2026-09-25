import SwiftUI

struct RightPanel: View {
    let snapshot: DocumentSnapshot

    @ObservedObject var viewState: DocumentViewState
    @ObservedObject var document: VectorDocument

    @Binding var layerPreviewOpacities: [UUID: Double]
    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?
    @Binding var colorDeltaBlendMode: BlendMode?
    @Binding var fillDeltaOpacity: Double?
    @Binding var strokeDeltaOpacity: Double?
    @Binding var strokeDeltaWidth: Double?
    @Binding var activeGradientDelta: VectorGradient?
    @Binding var fontSizeDelta: Double?
    @Binding var lineSpacingDelta: Double?
    @Binding var lineHeightDelta: Double?
    @Binding var letterSpacingDelta: Double?
    @Binding var selectedLayerIndex: Int?
    @Binding var processedLayersDuringDrag: Set<Int>
    @Binding var processedObjectsDuringDrag: Set<UUID>

    @Environment(AppState.self) private var appState
    var body: some View {
        VStack(spacing: 0) {
            PanelTabBar(selectedTab: Binding(
                get: { appState.selectedPanelTab },
                set: { appState.selectedPanelTab = $0 }
            ))
            switch appState.selectedPanelTab {
            case .layers:
                LayersPanel(
                        document: document,
                        layerPreviewOpacities: $layerPreviewOpacities,
                        selectedLayerIndex: $selectedLayerIndex,
                        processedLayersDuringDrag: $processedLayersDuringDrag,
                        processedObjectsDuringDrag: $processedObjectsDuringDrag
                    )
                case .properties:
                    StrokeFillPanel(
                        snapshot: Binding(
                            get: { document.snapshot },
                            set: { document.snapshot = $0 }
                        ),
                        selectedObjectIDs: viewState.selectedObjectIDs,
                        selectedPoints: viewState.PublishedSelectedPoints,
                        selectedHandles: viewState.PublishedSelectedHandles,
                        activeColorTarget: viewState.activeColorTarget,
                        colorMode: Binding(
                            get: { document.settings.colorMode },
                            set: { document.settings.colorMode = $0 }
                        ),
                        defaultFillColor: Binding(
                            get: { document.defaultFillColor },
                            set: { document.defaultFillColor = $0 }
                        ),
                        defaultStrokeColor: Binding(
                            get: { document.defaultStrokeColor },
                            set: { document.defaultStrokeColor = $0 }
                        ),
                        defaultFillOpacity: Binding(
                            get: { document.defaultFillOpacity },
                            set: { document.defaultFillOpacity = $0 }
                        ),
                        defaultStrokeOpacity: Binding(
                            get: { document.defaultStrokeOpacity },
                            set: { document.defaultStrokeOpacity = $0 }
                        ),
                        defaultStrokeWidth: Binding(
                            get: { document.defaultStrokeWidth },
                            set: { document.defaultStrokeWidth = $0 }
                        ),
                        strokeDefaults: document.strokeDefaults,
                        currentSwatches: document.currentSwatches,
                        currentTool: viewState.currentTool,
                        hasPressureInput: viewState.hasPressureInput,
                        changeToken: document.changeNotifier.changeToken,
                        document: document,
                        onTriggerLayerUpdates: { indices in document.triggerLayerUpdates(for: indices) },
                        onAddColorSwatch: { color in document.addColorSwatch(color) },
                        onRemoveColorSwatch: { color in document.removeColorSwatch(color) },
                        onSetActiveColor: { color in document.setActiveColor(color) },
                        colorDeltaColor: $colorDeltaColor,
                        colorDeltaOpacity: $colorDeltaOpacity,
                        fillDeltaOpacity: $fillDeltaOpacity,
                        strokeDeltaOpacity: $strokeDeltaOpacity,
                        strokeDeltaWidth: $strokeDeltaWidth,
                        onSetActiveColorTarget: { target in document.viewState.activeColorTarget = target },
                        onUpdateStrokeDefaults: { defaults in document.strokeDefaults = defaults },
                        onOutlineSelectedStrokes: { document.outlineSelectedStrokes() },
                        onDuplicateSelectedShapes: { document.duplicateSelectedShapes() },
                        onUpdateObjectOpacity: { objectID, opacity, target in
                        },
                        onUpdateObjectStrokeWidth: { objectID, width in
                        },
                        onUpdateFillOpacityLive: { opacity, isEditing in PaintSelectionOperations.updateFillOpacityLive(opacity, document: document, isEditing: isEditing) },
                        onUpdateStrokeOpacityLive: { opacity, isEditing in PaintSelectionOperations.updateStrokeOpacityLive(opacity, document: document, isEditing: isEditing) },
                        onUpdateStrokeWidthLive: { width, isEditing in PaintSelectionOperations.updateStrokeWidthLive(width, document: document, isEditing: isEditing) },
                        onUpdateStrokePlacement: { placement in PaintSelectionOperations.updateStrokePlacement(placement, document: document) },
                        onUpdateStrokeLineJoin: { lineJoin in PaintSelectionOperations.updateStrokeLineJoin(lineJoin, document: document) },
                        onUpdateStrokeLineCap: { lineCap in PaintSelectionOperations.updateStrokeLineCap(lineCap, document: document) },
                        onUpdateStrokeMiterLimit: { miterLimit in PaintSelectionOperations.updateStrokeMiterLimit(miterLimit, document: document) },
                        onUpdateStrokeMiterLimitDirectNoUndo: { miterLimit in PaintSelectionOperations.updateStrokeMiterLimitDirectNoUndo(miterLimit, document: document) },
                        onUpdateStrokeScaleWithTransform: { scaleWithTransform in PaintSelectionOperations.updateStrokeScaleWithTransform(scaleWithTransform, document: document) },
                        onUpdateImageOpacity: { opacity in PaintSelectionOperations.updateImageOpacity(opacity, document: document) },
                        onApplyFillToSelectedShapes: { fillColor, fillOpacity in PaintSelectionOperations.applyFillToSelectedShapes(fillColor: fillColor, fillOpacity: fillOpacity, document: document) },
                        onUpdateShapeStrokePlacementInUnified: { id, placement in document.updateShapeStrokePlacementInUnified(id: id, placement: placement) }
                    )
                case .gradient:
                    GradientPanel(
                        snapshot: snapshot,
                        selectedObjectIDs: viewState.selectedObjectIDs,
                        document: document,
                        activeGradientDelta: $activeGradientDelta,
                        activeColorTarget: Binding(
                            get: { viewState.activeColorTarget },
                            set: { viewState.activeColorTarget = $0 }
                        )
                    )
                case .color:
                    ColorPanel(
                        snapshot: Binding(
                            get: { document.snapshot },
                            set: { document.snapshot = $0 }
                        ),
                        selectedObjectIDs: viewState.selectedObjectIDs,
                        activeColorTarget: Binding(
                            get: { viewState.activeColorTarget },
                            set: { viewState.activeColorTarget = $0 }
                        ),
                        colorMode: Binding(
                            get: { document.settings.colorMode },
                            set: { document.settings.colorMode = $0 }
                        ),
                        defaultFillColor: Binding(
                            get: { document.defaultFillColor },
                            set: { document.defaultFillColor = $0 }
                        ),
                        defaultStrokeColor: Binding(
                            get: { document.defaultStrokeColor },
                            set: { document.defaultStrokeColor = $0 }
                        ),
                        defaultFillOpacity: document.defaultFillOpacity,
                        defaultStrokeOpacity: document.defaultStrokeOpacity,
                        currentSwatches: document.currentSwatches,
                        onTriggerLayerUpdates: { indices in document.triggerLayerUpdates(for: indices) },
                        onAddColorSwatch: { color in document.addColorSwatch(color) },
                        onRemoveColorSwatch: { color in document.removeColorSwatch(color) },
                        onSetActiveColor: { color in document.setActiveColor(color) },
                        colorDeltaColor: $colorDeltaColor,
                        colorDeltaOpacity: $colorDeltaOpacity
                    )
                case .pathOps:
                    PathOperationsPanel(
                        snapshot: snapshot,
                        selectedObjectIDs: viewState.selectedObjectIDs,
                        document: document
                    )
                case .font:
                    FontPanel(
                        snapshot: snapshot,
                        selectedObjectIDs: viewState.selectedObjectIDs,
                        document: document,
                        fontSizeDelta: $fontSizeDelta,
                        lineSpacingDelta: $lineSpacingDelta,
                        lineHeightDelta: $lineHeightDelta,
                        letterSpacingDelta: $letterSpacingDelta
                    )
            }
        }
        .background(Color.platformControlBackground)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .leading
        )
    }
}
