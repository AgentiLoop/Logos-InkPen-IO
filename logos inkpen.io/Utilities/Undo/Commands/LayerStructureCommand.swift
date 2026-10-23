import Foundation

/// Undo step for adding or removing a layer: swaps the whole layer list, the objects and the
/// selected layer / objects between the state before and after the change.
class LayerStructureCommand: BaseCommand {
    struct State {
        let layers: [Layer]
        let objects: [UUID: VectorObject]
        let selectedLayerIndex: Int?
        let layerIndex: Int
        let selectedLayerId: UUID?
        let selectedLayerName: String?
        let selectedObjectIDs: Set<UUID>
        let orderedSelectedObjectIDs: [UUID]

        init(of document: VectorDocument) {
            layers = document.snapshot.layers
            objects = document.snapshot.objects
            selectedLayerIndex = document.selectedLayerIndex
            layerIndex = document.layerIndex
            selectedLayerId = document.settings.selectedLayerId
            selectedLayerName = document.settings.selectedLayerName
            selectedObjectIDs = document.viewState.selectedObjectIDs
            orderedSelectedObjectIDs = document.viewState.orderedSelectedObjectIDs
        }
    }

    private let before: State
    private let after: State

    init(before: State, after: State) {
        self.before = before
        self.after = after
    }

    override func execute(on document: VectorDocument) {
        apply(after, to: document)
    }

    override func undo(on document: VectorDocument) {
        apply(before, to: document)
    }

    private func apply(_ state: State, to document: VectorDocument) {
        document.snapshot.layers = state.layers
        document.snapshot.objects = state.objects
        document.selectedLayerIndex = state.selectedLayerIndex
        document.layerIndex = state.layerIndex
        document.settings.selectedLayerId = state.selectedLayerId
        document.settings.selectedLayerName = state.selectedLayerName
        document.viewState.selectedObjectIDs = state.selectedObjectIDs
        document.viewState.orderedSelectedObjectIDs = state.orderedSelectedObjectIDs
        document.onSettingsChanged()
        document.changeNotifier.notifyLayersChanged()
    }
}
