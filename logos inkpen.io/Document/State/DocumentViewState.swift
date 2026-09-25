import SwiftUI
import Combine

class DocumentViewState: ObservableObject {

    @Published var currentTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(currentTool.rawValue, forKey: "lastUsedTool")
        }
    }

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
