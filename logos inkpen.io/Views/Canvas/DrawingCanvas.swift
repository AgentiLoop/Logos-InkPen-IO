import SwiftUI

enum ShiftConstraintAxis {
    case none
    case horizontal
    case vertical
}

struct DrawingCanvas: View {
    var document: VectorDocument = VectorDocument()

    @Binding var zoomLevel: Double
    @Binding var canvasOffset: CGPoint
    @Binding var layerPreviewOpacities: [UUID: Double]
    @Binding var liveDragOffset: CGPoint
    @Binding var liveScaleDimensions: CGSize
    @Binding var liveScaleTransform: CGAffineTransform
    @Binding var livePointPositions: [PointID: CGPoint]
    @Binding var liveHandlePositions: [HandleID: CGPoint]
    @Binding var fillDeltaOpacity: Double?
    @Binding var strokeDeltaOpacity: Double?
    @Binding var strokeDeltaWidth: Double?
    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?
    @Binding var activeGradientDelta: VectorGradient?
    @Binding var fontSizeDelta: Double?
    @Binding var lineSpacingDelta: Double?
    @Binding var lineHeightDelta: Double?
    @Binding var letterSpacingDelta: Double?
    @Binding var textContentDelta: (id: UUID, content: String)?
    @Binding var imagePreviewQuality: Double
    @Binding var imageTileSize: Int
    @Binding var imageInterpolationQuality: Int

    @Environment(AppState.self) internal var appState

    @State internal var currentPath: VectorPath?
    @State internal var tempBoundingBoxPath: VectorPath?
    @State internal var isDrawing = false
    @State internal var drawingStartPoint: CGPoint?
    @State internal var currentDrawingPoints: [CGPoint] = []
    @State internal var initialCanvasOffset = CGPoint.zero
    @State internal var handToolDragStart = CGPoint.zero
    @State internal var selectionDragStart = CGPoint.zero
    @State internal var initialObjectPositions: [UUID: CGPoint] = [:]
    @State internal var initialObjectTransforms: [UUID: CGAffineTransform] = [:]
    @State internal var currentDragDelta: CGPoint = .zero
    @State internal var shiftConstraintAxis: ShiftConstraintAxis = .none
    @State internal var dragPreviewUpdateTrigger: Bool = false
    @State internal var transformBoxOpacity: Double = 1.0
    @State internal var shapeDragStart = CGPoint.zero
    @State internal var shapeStartPoint = CGPoint.zero
    @State internal var isShiftPressed = false
    @State internal var isCommandPressed = false
    @State internal var isOptionPressed = false
    @State internal var isControlPressed = false
    @State internal var spatialIndex = MetalSpatialIndex()!
    @State internal var isDraggingDirectSelectedShapes = false
    @State internal var bezierPath: VectorPath?
    @State internal var bezierPoints: [VectorPoint] = []
    @State internal var isBezierDrawing = false
    @State internal var isDraggingBezierHandle = false
    @State internal var activeBezierPointIndex: Int? = nil
    @State internal var isDraggingBezierPoint = false
    @State internal var bezierHandles: [Int: BezierHandleInfo] = [:]
    @State internal var liveBezierHandles: [Int: BezierHandleInfo] = [:]
    @State internal var originalBezierHandles: [Int: BezierHandleInfo] = [:]
    @State internal var currentMouseLocation: CGPoint? = nil
    @State internal var showClosePathHint = false
    @State internal var closePathHintLocation: CGPoint = .zero
    @State internal var showContinuePathHint = false
    @State internal var continuePathHintLocation: CGPoint = .zero
    @State internal var isCanvasHovering: Bool = false
    @State internal var currentSnapPoint: CGPoint? = nil
    @State internal var currentShapeId: UUID? = nil
    @State internal var activeBezierShape: VectorShape? = nil
    @State internal var isContinuingExistingPath: Bool = false
    @State internal var originalBezierShapeForUndo: VectorShape? = nil
    @State internal var freehandPath: VectorPath?
    @State internal var freehandRawPoints: [CGPoint] = []
    @State internal var freehandSimplifiedPoints: [VectorPoint] = []
    @State internal var freehandRealtimeSmoothingPoints: [CGPoint] = []
    @State internal var isFreehandDrawing = false
    @State internal var activeFreehandShape: VectorShape? = nil
    @State internal var freehandPreviewPath: VectorPath? = nil
    @State internal var brushPath: VectorPath?
    @State internal var brushRawPoints: [BrushPoint] = []
    @State internal var brushSimplifiedPoints: [CGPoint] = []
    @State internal var isBrushDrawing = false
    @State internal var activeBrushShape: VectorShape? = nil
    @State internal var brushPreviewPath: VectorPath? = nil
    @State internal var markerPath: VectorPath?
    @State internal var markerRawPoints: [MarkerPoint] = []
    @State internal var markerSimplifiedPoints: [CGPoint] = []
    @State internal var isMarkerDrawing = false
    @State internal var activeMarkerShape: VectorShape? = nil
    @State internal var markerPreviewPath: VectorPath? = nil
    @State internal var previousTool: DrawingTool = .selection
    @State internal var isTemporaryHandToolActive = false
    @State internal var temporaryToolPreviousTool: DrawingTool? = nil
    @State internal var isTemporarySelectionViaCommand = false
    @State internal var initialZoomLevel: CGFloat = 1.0
    @State internal var isZoomGestureActive = false
    @State internal var isPanGestureActive = false
    @State internal var lastClickTime: Date = Date.distantPast
    @State internal var lastClickLocation: CGPoint = .zero
    @State internal var selectBehindIndex: Int = 0
    @State internal var selectBehindLocation: CGPoint = .zero
    @State internal var dragStartGradient: VectorGradient? = nil
    @State internal var doubleClickTimeout: TimeInterval = NSEvent.doubleClickInterval
    @State internal var isTextEditingMode = false
    @State internal var zoomToolDragStartPoint: CGPoint = .zero
    @State internal var zoomToolInitialZoomLevel: CGFloat = 1.0
    @State internal var liveZoomDelta: CGFloat = 1.0
    @State internal var livePanDelta: CGPoint = .zero
    @State internal var isActivelyZooming: Bool = false
    @State internal var isActivelyPanning: Bool = false
    @State internal var selectedPoints: Set<PointID> = []
    @State internal var selectedHandles: Set<HandleID> = []
    @State internal var visibleHandles: Set<HandleID> = []
    @State internal var selectedObjectIDs: Set<UUID> = []
    @State internal var isCornerRadiusEditMode = false
    @State internal var isDraggingPoint = false
    @State internal var isDraggingHandle = false
    @State internal var isDraggingCurveSegment = false
    @State internal var draggedCurveSegment: (shapeID: UUID, elementIndex: Int)? = nil
    @State internal var curveSegmentDragT: Double = 0.5
    @State internal var dragStartLocation: CGPoint = .zero
    @State internal var lockedObjectIDs: Set<UUID> = []

    @State private var cachedObjectCount: Int = 0
    internal func syncDirectSelectionWithDocument() {
        document.viewState.selectedObjectIDs = selectedObjectIDs
        document.viewState.selectedPoints = selectedPoints
        document.viewState.selectedHandles = selectedHandles
        if !selectedObjectIDs.isEmpty {
            document.viewState.selectedObjectIDs = selectedObjectIDs
        } else if document.viewState.currentTool == .directSelection ||
                  document.viewState.currentTool == .convertAnchorPoint ||
                    document.viewState.currentTool == .penPlusMinus {
            document.viewState.selectedObjectIDs.removeAll()
        }
    }

    internal func rebuildLockedObjectsCache() {
        lockedObjectIDs.removeAll(keepingCapacity: true)
        for layer in document.snapshot.layers where layer.isLocked {
            for objectID in layer.objectIDs {
                lockedObjectIDs.insert(objectID)
            }
        }
        for (id, object) in document.snapshot.objects {
            if object.shape.isLocked {
                lockedObjectIDs.insert(id)
            }
        }
    }

    @State internal var originalPointPositions: [PointID: VectorPoint] = [:]
    @State internal var originalHandlePositions: [HandleID: VectorPoint] = [:]
    @State internal var originalDragShapes: [UUID: VectorShape] = [:]
    @State internal var cornerDragStart: CGPoint = .zero
    @State internal var initialCornerRadius: Double = 0.0
    @State internal var isDraggingCorner = false
    @State internal var draggedCornerIndex: Int? = nil
    @State internal var currentMousePosition: CGPoint = .zero
    @State internal var liveCornerRadii: [Double] = []
    @State internal var originalCornerRadii: [Double] = []
    @State internal var coincidentPointTolerance: Double = 0.1
    @State internal var isEditingText = false
    @State internal var editingTextID: UUID? = nil
    @State internal var currentCursorPosition: Int = 0
    @State internal var currentSelectionRange: NSRange = NSRange(location: 0, length: 0)
    @State internal var lastTapLocation: CGPoint = .zero
    @State internal var isHit = false
    @State internal var foundPointOrHandle = false
    @State internal var sharedOriginalShape: VectorShape?
    @State internal var hasPerformedInitialFitToPage = false
    @State internal var hasSpatialIndexInitialized = false
    @State internal var cachedSelectionBoundsForDrag: CGRect? = nil

    @State private var previousWindowSize: CGSize = .zero
    var body: some View {
        GeometryReader { geometry in
            enhancedCanvasMainContent(geometry: geometry)
                .onChange(of: geometry.size) { oldSize, newSize in
                    guard hasPerformedInitialFitToPage else { return }
                    guard previousWindowSize != .zero else {
                        previousWindowSize = newSize
                        return
                    }
                    let widthChanged = abs(newSize.width - previousWindowSize.width) > 1
                    let heightChanged = abs(newSize.height - previousWindowSize.height) > 1
                    if widthChanged || heightChanged {
                        previousWindowSize = newSize
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                    }
                }
                .onAppear {
                    MemoryDiag.checkpoint("DrawingCanvas.onAppear START")
                    selectedObjectIDs = document.viewState.selectedObjectIDs
                    cachedObjectCount = document.snapshot.objects.count
                    let allLayerIDs = Set(document.snapshot.layers.map { $0.id })
                    spatialIndex.rebuildLayers(allLayerIDs, from: document.snapshot)
                    rebuildLockedObjectsCache()
                    hasSpatialIndexInitialized = true
                    MemoryDiag.report("DrawingCanvas.onAppear END", document: document)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak document] in
                        guard let document else { return }
                        MemoryDiag.checkpoint("DrawingCanvas +2s (after SwiftUI layout)")
                        MemoryDiag.report("DrawingCanvas +2s", document: document)
                    }
                }
                .onChange(of: document.viewState.layerUpdateTriggers) { oldTriggers, newTriggers in
                    guard hasSpatialIndexInitialized else { return }
                    guard !document.viewState.isLivePointDrag else { return }
                    guard !isDraggingPoint else { return }
                    guard !isDraggingHandle else { return }
                    var changedLayerIDs = Set<UUID>()
                    for (layerID, newValue) in newTriggers {
                        if oldTriggers[layerID] != newValue {
                            changedLayerIDs.insert(layerID)
                        }
                    }
                    if !changedLayerIDs.isEmpty {
                        spatialIndex.rebuildLayers(changedLayerIDs, from: document.snapshot)
                        MemoryDiag.report("spatialIndex.rebuild", document: document)
                        rebuildLockedObjectsCache()
                    }
                }
                .onChange(of: document.snapshot.objects.count) { _, newCount in
                    guard hasSpatialIndexInitialized else { return }
                    if newCount != cachedObjectCount {
                        cachedObjectCount = newCount
                        let allLayerIDs = Set(document.snapshot.layers.map { $0.id })
                        spatialIndex.rebuildLayers(allLayerIDs, from: document.snapshot)
                        rebuildLockedObjectsCache()
                    }
                }
                .onChange(of: document.snapshot.layers.count) { _, _ in
                    guard hasSpatialIndexInitialized else { return }
                    spatialIndex.purgeRemovedLayers(from: document.snapshot)
                    let allLayerIDs = Set(document.snapshot.layers.map { $0.id })
                    spatialIndex.rebuildLayers(allLayerIDs, from: document.snapshot)
                    rebuildLockedObjectsCache()
                }
                .onChange(of: ApplicationSettings.shared.boundingBoxIncludesStrokes) { _, _ in
                    guard hasSpatialIndexInitialized else { return }
                    let allLayerIDs = Set(document.snapshot.layers.map { $0.id })
                    spatialIndex.rebuildLayers(allLayerIDs, from: document.snapshot)
                }
                .onChange(of: document.viewState.handleRefreshTrigger) {
                    if document.viewState.currentTool == .directSelection {
                        showHandlesForSelectedPoints()
                    }
                }
                .onChange(of: document.viewState.selectedObjectIDs) { _, newSelection in
                    if selectedObjectIDs != newSelection {
                        selectedObjectIDs = newSelection
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        visibleHandles.removeAll()
                    }
                }
        }
    }
}
