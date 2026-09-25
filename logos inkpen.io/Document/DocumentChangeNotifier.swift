import SwiftUI
import Combine

final class DocumentChangeNotifier: ObservableObject {

    enum ChangeType {
        case objectModified(UUID)
        case objectAdded(UUID)
        case objectRemoved(UUID)
        case selectionChanged
        case layerChanged
        case multipleObjects(Set<UUID>)
    }

    @Published private(set) var objectChangeID: UUID?
    @Published private(set) var selectionChangeToken: UUID = UUID()
    @Published private(set) var layerChangeToken: UUID = UUID()
    @Published private(set) var changeToken: UUID = UUID()
    func notifyObjectChanged(_ id: UUID) {
        objectChangeID = id
        changeToken = UUID()
    }

    func notifySelectionChanged() {
        selectionChangeToken = UUID()
        changeToken = UUID()
    }

    func notifyLayersChanged() {
        layerChangeToken = UUID()
        changeToken = UUID()
    }

    func notifyMultipleObjectsChanged(_ ids: Set<UUID>) {
        changeToken = UUID()
    }

    func notifyGeneralChange() {
        changeToken = UUID()
    }
}
