import Foundation

class SelectionCommand: BaseCommand {
    private let oldSelectedIDs: Set<UUID>
    private let newSelectedIDs: Set<UUID>
    private let oldOrderedIDs: [UUID]
    private let newOrderedIDs: [UUID]

    init(oldSelectedIDs: Set<UUID>, newSelectedIDs: Set<UUID>,
         oldOrderedIDs: [UUID], newOrderedIDs: [UUID]) {
        self.oldSelectedIDs = oldSelectedIDs
        self.newSelectedIDs = newSelectedIDs
        self.oldOrderedIDs = oldOrderedIDs
        self.newOrderedIDs = newOrderedIDs
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            if let object = document.snapshot.objects[objectID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        for objectID in newSelectedIDs {
            if let object = document.snapshot.objects[objectID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        document.viewState.orderedSelectedObjectIDs = newOrderedIDs
        document.viewState.selectedObjectIDs = newSelectedIDs
        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for objectID in document.viewState.selectedObjectIDs {
            if let object = document.snapshot.objects[objectID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        for objectID in oldSelectedIDs {
            if let object = document.snapshot.objects[objectID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        document.viewState.orderedSelectedObjectIDs = oldOrderedIDs
        document.viewState.selectedObjectIDs = oldSelectedIDs
        document.triggerLayerUpdates(for: affectedLayers)
    }

    func mergeWith(_ other: Command) -> Command? {
        guard let otherSelection = other as? SelectionCommand else { return nil }
        return SelectionCommand(
            oldSelectedIDs: self.oldSelectedIDs,
            newSelectedIDs: otherSelection.newSelectedIDs,
            oldOrderedIDs: self.oldOrderedIDs,
            newOrderedIDs: otherSelection.newOrderedIDs
        )
    }
}
