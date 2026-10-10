import SwiftUI

extension Notification.Name {
    static let exitIsolationRequested = Notification.Name("exitIsolationRequested")
}

extension DrawingCanvas {

    /// Illustrator: double-clicking a group with the Selection tool enters it, so its members can be
    /// selected and edited on their own. Returns true when the double-click was consumed.
    internal func handleIsolationDoubleClick(at canvasLocation: CGPoint) -> Bool {
        guard document.viewState.currentTool == .selection else { return false }
        if let isolatedID = document.viewState.isolatedGroupID {
            guard let hit = findIsolatedMember(of: isolatedID, at: canvasLocation) else {
                exitIsolation()
                return true
            }
            if isGroupObject(hit) {
                enterIsolation(groupID: hit.id, selecting: canvasLocation)
                return true
            }
            return false
        }
        guard let hit = findObjectAtLocationOptimized(canvasLocation), isGroupObject(hit) else { return false }
        enterIsolation(groupID: hit.id, selecting: canvasLocation)
        return true
    }

    private func isGroupObject(_ object: VectorObject) -> Bool {
        switch object.objectType {
        case .group(let shape), .clipGroup(let shape):
            return !shape.memberIDs.isEmpty
        default:
            return false
        }
    }

    internal func enterIsolation(groupID: UUID, selecting location: CGPoint) {
        refreshGroupBounds(groupID: document.viewState.isolatedGroupID)
        document.viewState.isolatedGroupID = groupID
        isolatedGroupDisplayID = groupID
        if let member = findIsolatedMember(of: groupID, at: location) {
            document.setSelectionWithUndo([member.id], ordered: [member.id])
        } else {
            document.clearSelectionWithUndo()
        }
    }

    internal func exitIsolation() {
        guard let groupID = document.viewState.isolatedGroupID else { return }
        document.viewState.isolatedGroupID = nil
        isolatedGroupDisplayID = nil
        refreshGroupBounds(groupID: groupID)
        document.setSelectionWithUndo([groupID], ordered: [groupID])
    }

    /// Members move independently while isolated, so the group's stored bounds (used for hit testing) must be recomputed.
    private func refreshGroupBounds(groupID: UUID?) {
        guard let groupID, let object = document.snapshot.objects[groupID] else { return }
        var shape = object.shape
        shape.bounds = document.calculateGroupBounds(shape)
        document.snapshot.objects[groupID] = VectorObject(
            id: groupID,
            layerIndex: object.layerIndex,
            objectType: shape.isClippingGroup ? .clipGroup(shape) : .group(shape)
        )
    }

    @ViewBuilder
    internal func isolationOverlay() -> some View {
        if let groupID = isolatedGroupDisplayID, let object = document.snapshot.objects[groupID] {
            let rect = document.calculateGroupBounds(object.shape)
            Canvas { context, _ in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)
                context.stroke(
                    Path(rect),
                    with: .color(Color.gray),
                    style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [6 / zoomLevel, 3 / zoomLevel])
                )
            }
            .allowsHitTesting(false)
            VStack {
                HStack {
                    Text("Isolation Mode — Esc or double-click outside to exit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
            .allowsHitTesting(false)
        }
    }
}
