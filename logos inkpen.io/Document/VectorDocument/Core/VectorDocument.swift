import SwiftUI
import Combine

final class VectorDocument: ObservableObject, Codable {
    var snapshot: DocumentSnapshot = DocumentSnapshot()
    var viewState: DocumentViewState = DocumentViewState()

    @Published var settings: DocumentSettings = DocumentSettings()

    var layerIndex: Int = 0
    var selectedLayerIndex: Int?

    @Published var documentColorDefaults: ColorDefaults = ColorDefaults() {
        didSet {
            settings.fillColor = documentColorDefaults.fillColor
            settings.strokeColor = documentColorDefaults.strokeColor
        }
    }

    @Published var colorSwatches: ColorSwatches = .empty {
        didSet {
            settings.customRgbSwatches = colorSwatches.rgb
            settings.customCmykSwatches = colorSwatches.cmyk
            settings.customHsbSwatches = colorSwatches.hsb
        }
    }
    var processedLayersDuringDrag: Set<Int> = []
    var processedObjectsDuringDrag: Set<UUID> = []
    var activeLayerIndexDuringDrag: Int? = nil
    var isHandleScalingActive = false

    let changeNotifier = DocumentChangeNotifier()

    private var cancellables = Set<AnyCancellable>()

    var textPreviewTypography: [UUID: TypographyProperties] = [:]
    var currentDragOffset: CGPoint = .zero
    var cachedSelectionBounds: CGRect? = nil
    var dragPreviewCoordinates: CGPoint = .zero

    enum FreehandFillMode: String, CaseIterable {
        case fill = "Fill"
        case noFill = "No Fill"
    }

    @Published var gridSettings: GridSettings = .default

    internal var isUndoRedoOperation: Bool = false

    lazy var commandManager: CommandManager = {
        let manager = CommandManager(maxStackSize: maxUndoStackSize)
        manager.document = self
        return manager
    }()
    internal var imageStorage: [UUID: CGImage] = [:]
    internal var baseDirectoryURL: URL? = nil
    internal var lastDrawnImageHash: [UUID: Int] = [:]

    @Published var fontManager: FontManager = FontManager()
    @Published var strokeDefaults: StrokeDefaults = .default {
        didSet { saveStrokeStyleDefaults() }
    }
    internal let maxUndoStackSize = 50

    var originalHandlePositions: [String: VectorPoint] = [:]

    deinit {
        imageStorage.removeAll()
    }

    init(settings: DocumentSettings = DocumentSettings()) {
        self.settings = settings
        self.documentColorDefaults = ColorDefaults()
        self.colorSwatches = .empty
        self.gridSettings = .default
        self.strokeDefaults = .default
        loadStrokeStyleDefaults()
        self.selectedLayerIndex = nil
        if let lastToolRaw = UserDefaults.standard.string(forKey: "lastUsedTool"),

           let lastTool = DrawingTool(rawValue: lastToolRaw) {
            self.viewState.currentTool = lastTool
        } else {
            self.viewState.currentTool = .selection
        }
        self.viewState.scalingAnchor = .center
        self.viewState.viewMode = .color
        self.gridSettings = GridSettings(
            showRulers: settings.showRulers,
            showGrid: settings.showGrid,
            snapToGrid: settings.snapToGrid,
            snapToPoint: settings.snapToPoint,
            gridSpacing: settings.gridSpacing,
            gridOnTop: UserDefaults.standard.bool(forKey: "gridOnTop"),
            guides: [],
            showGuides: true,
            guidesLocked: false,
            snapToGuides: true
        )
        createCanvasAndWorkingLayers()
        self.selectedLayerIndex = 3
        self.layerIndex = snapshot.layers.count
        if snapshot.layers.count > 3 {
            let workingLayer = snapshot.layers[3]
            self.settings.selectedLayerId = workingLayer.id
            self.settings.selectedLayerName = workingLayer.name
        }
        if let fillColor = settings.fillColor {
            self.documentColorDefaults.fillColor = fillColor
        } else {
            self.documentColorDefaults.fillColor = ColorManager.shared.colorDefaults.fillColor
        }
        if let strokeColor = settings.strokeColor {
            self.documentColorDefaults.strokeColor = strokeColor
        } else {
            self.documentColorDefaults.strokeColor = ColorManager.shared.colorDefaults.strokeColor
        }
        self.colorSwatches = ColorSwatches(
            rgb: settings.customRgbSwatches ?? [],
            cmyk: settings.customCmykSwatches ?? [],
            hsb: settings.customHsbSwatches ?? []
        )
        setupViewStateForwarding()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSettings = try container.decode(DocumentSettings.self, forKey: .settings)
        let decodedSnapshot = try container.decode(DocumentSnapshot.self, forKey: .snapshot)
        settings = decodedSettings
        snapshot = decodedSnapshot
        layerIndex = snapshot.layers.count
        rebuildParentGroupCache()
        documentColorDefaults = ColorDefaults()
        colorSwatches = decodedSnapshot.colorSwatches
        gridSettings = decodedSnapshot.gridSettings
        strokeDefaults = .default
        selectedLayerIndex = nil
        viewState.selectedObjectIDs = []
        isHandleScalingActive = false
        viewState.currentTool = .selection
        viewState.scalingAnchor = .center
        viewState.rotationAnchor = .center
        viewState.shearAnchor = .center
        viewState.transformOrigin = .center
        viewState.objectPositionUpdateTrigger = false
        currentDragOffset = .zero
        cachedSelectionBounds = nil
        dragPreviewCoordinates = .zero
        viewState.warpEnvelopeCorners = [:]
        viewState.warpBounds = [:]
        viewState.viewMode = .color
        viewState.zoomRequest = nil
        isUndoRedoOperation = false
        fontManager = FontManager()
        viewState.hasPressureInput = false
        viewState.activeColorTarget = .fill
        viewState.colorChangeNotification = UUID()
        viewState.lastColorChangeType = .fillOpacity
        viewState.isDraggingVisibility = false
        viewState.isDraggingLock = false
        originalHandlePositions = [:]
        ensureGuidesLayerExists()
        validateSelectedLayer()
        if let fillColor = settings.fillColor {
            documentColorDefaults.fillColor = fillColor
        } else {
            documentColorDefaults.fillColor = ColorManager.shared.colorDefaults.fillColor
        }
        if let strokeColor = settings.strokeColor {
            documentColorDefaults.strokeColor = strokeColor
        } else {
            documentColorDefaults.strokeColor = ColorManager.shared.colorDefaults.strokeColor
        }
        colorSwatches = ColorSwatches(
            rgb: settings.customRgbSwatches ?? [],
            cmyk: settings.customCmykSwatches ?? [],
            hsb: settings.customHsbSwatches ?? []
        )
        loadStrokeStyleDefaults()
        setupViewStateForwarding()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshSystemLayers()
        }
    }

    private func setupViewStateForwarding() {
        viewState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        changeNotifier.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        fontManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    private func refreshSystemLayers() {
        changeNotifier.notifyGeneralChange()
    }

    func triggerLayerUpdates(for layerIndices: Set<Int>) {
        for layerIndex in layerIndices {
            guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { continue }
            let layerID = snapshot.layers[layerIndex].id
            viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
        }
    }

    func triggerLayerUpdate(for layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let layerID = snapshot.layers[layerIndex].id
        viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
    }

    func updateLayerObjectIDs(layerIndex: Int, newObjectIDs: [UUID]) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        var layer = snapshot.layers[layerIndex]
        layer.objectIDs = newObjectIDs
        snapshot.layers[layerIndex] = layer
        triggerLayerUpdate(for: layerIndex)
    }

    func appendToLayer(layerIndex: Int, objectID: UUID) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        if !snapshot.layers[layerIndex].objectIDs.contains(objectID) {
            var layer = snapshot.layers[layerIndex]
            layer.objectIDs.append(objectID)
            snapshot.layers[layerIndex] = layer
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func removeFromLayer(layerIndex: Int, objectID: UUID) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        var layer = snapshot.layers[layerIndex]
        layer.objectIDs.removeAll { $0 == objectID }
        snapshot.layers[layerIndex] = layer
        triggerLayerUpdate(for: layerIndex)
    }

    func insertIntoLayer(layerIndex: Int, objectID: UUID, at index: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        var layer = snapshot.layers[layerIndex]
        layer.objectIDs.insert(objectID, at: index)
        snapshot.layers[layerIndex] = layer
        triggerLayerUpdate(for: layerIndex)
    }

    func findParentGroup(for childID: UUID) -> VectorObject? {
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                if groupShape.groupedShapes.contains(where: { $0.id == childID }) {
                    return object
                }
            default:
                continue
            }
        }
        return nil
    }

    func updateChildInParentGroup(childID: UUID, updatedShape: VectorShape) {
        guard let parentGroup = findParentGroup(for: childID) else { return }
        var parentShape = parentGroup.shape
        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childID }) {
            parentShape.groupedShapes[childIndex] = updatedShape
            parentShape.updateBounds()
            let updatedParent = VectorObject(shape: parentShape, layerIndex: parentGroup.layerIndex)
            snapshot.objects[parentGroup.id] = updatedParent
            triggerLayerUpdate(for: parentGroup.layerIndex)
        }
    }

    func regenerateAllImages() {
        imageStorage.removeAll()
        lastDrawnImageHash.removeAll()
        objectWillChange.send()
    }
}
