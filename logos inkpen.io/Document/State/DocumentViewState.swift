import SwiftUI
import Combine

class DocumentViewState: ObservableObject {

    @Published var currentTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(currentTool.rawValue, forKey: "lastUsedTool")
            if currentTool == .selection || currentTool == .directSelection {
                lastSelectionTool = currentTool
            }
            if transformToolOrigin != nil { transformToolOrigin = nil }
        }
    }

    /// Selection tool that Cmd switches to temporarily from other tools (Illustrator: last used of Selection / Direct Selection).
    var lastSelectionTool: DrawingTool = .selection

    /// Group the Selection tool has entered by double-click (Illustrator isolation mode); nil = normal editing.
    var isolatedGroupID: UUID? = nil

    /// Reference point set by clicking with Rotate / Scale / Reflect / Shear (nil = centre of the selection).
    @Published var transformToolOrigin: CGPoint? = nil

    /// True while a shape tool is mid-drag; Space then repositions the shape instead of switching to the Hand tool (Illustrator).
    var isShapeDrawingInProgress: Bool = false
    var isSpaceHeldDuringShapeDrag: Bool = false
    var lastShapeDragLocation: CGPoint? = nil

    @Published var scalingAnchor: ScalingAnchor = .center
    @Published var rotationAnchor: RotationAnchor = .center
    @Published var shearAnchor: ShearAnchor = .center
    @Published var transformOrigin: TransformOrigin = .center
    @Published var viewMode: ViewMode = .color
    @Published var zoomRequest: ZoomRequest? = nil
    @Published var handleRefreshTrigger: Bool = false
    @Published var activeColorTarget: ColorTarget = .fill
    @Published var colorChangeNotification: UUID = UUID()
    @Published var lastColorChangeType: ColorChangeType = .fillOpacity
    @Published var objectPositionUpdateTrigger: Bool = false
    @Published var layerUpdateTriggers: [UUID: UInt] = [:]

    var isLivePointDrag: Bool = false

    @Published var warpEnvelopeCorners: [UUID: [CGPoint]] = [:]
    @Published var warpBounds: [UUID: CGRect] = [:]
    @Published var hasPressureInput: Bool = false

    var isDraggingVisibility: Bool = false
    var isDraggingLock: Bool = false

    @Published var liveGradientOriginX: Double? = nil
    @Published var liveGradientOriginY: Double? = nil
    @Published var liveNudgeOffset: CGVector = .zero
    var selectedObjectIDs: Set<UUID> = [] {
        didSet {
            PublishedSelectedObjectIDs = selectedObjectIDs
            if transformToolOrigin != nil && selectedObjectIDs != oldValue { transformToolOrigin = nil }
            orderedSelectedObjectIDs = orderedSelectedObjectIDs.filter { selectedObjectIDs.contains($0) }
        }
    }

    @Published var PublishedSelectedObjectIDs: Set<UUID> = []

    var orderedSelectedObjectIDs: [UUID] = []

    var selectedPoints: Set<PointID> = [] {
        didSet {
            PublishedSelectedPoints = selectedPoints
        }
    }

    @Published var PublishedSelectedPoints: Set<PointID> = []
    var selectedHandles: Set<HandleID> = [] {
        didSet {
            PublishedSelectedHandles = selectedHandles
        }
    }

    @Published var PublishedSelectedHandles: Set<HandleID> = []
    init() {}
}
