import Foundation

@MainActor
final class ImportCommand: BaseCommand {
    private let newLayers: [Layer]
    private let topLevel: [VectorObject]
    private let members: [VectorObject]

    private var appendedLayerIndexes: [Int] = []

    init(newLayers: [Layer], topLevel: [VectorObject], members: [VectorObject]) {
        self.newLayers = newLayers
        self.topLevel = topLevel
        self.members = members
    }

    override func execute(on document: VectorDocument) {
        Log.info("📥 ImportCommand.execute: \(newLayers.count) layers, \(topLevel.count) top, \(members.count) members. Doc had \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects", category: .general)
        appendedLayerIndexes.removeAll(keepingCapacity: true)
        for layer in newLayers {
            document.snapshot.layers.append(layer)
            appendedLayerIndexes.append(document.snapshot.layers.count - 1)
        }
        for member in members {
            document.snapshot.objects[member.id] = member
        }
        var affectedLayers = Set<Int>()
        for obj in topLevel {
            let layerIndex = obj.layerIndex
            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else {
                Log.error("📥 ImportCommand: SKIPPED top obj \(obj.id) — layerIndex \(layerIndex) out of range (have \(document.snapshot.layers.count) layers)", category: .error)
                continue
            }
            document.snapshot.objects[obj.id] = obj
            if !document.snapshot.layers[layerIndex].objectIDs.contains(obj.id) {
                document.snapshot.layers[layerIndex].objectIDs.append(obj.id)
            }
            affectedLayers.insert(layerIndex)
        }
        affectedLayers.formUnion(appendedLayerIndexes)
        document.triggerLayerUpdates(for: affectedLayers)
        Log.info("📥 ImportCommand.execute DONE: doc has \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects, affectedLayers=\(affectedLayers.sorted())", category: .general)
    }

    override func undo(on document: VectorDocument) {
        Log.info("↩️ ImportCommand.undo: removing \(topLevel.count) top, \(members.count) members, popping layers \(appendedLayerIndexes). Doc has \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects", category: .general)
        var affectedLayers = Set<Int>()
        for obj in topLevel {
            document.snapshot.objects.removeValue(forKey: obj.id)
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == obj.id }
                affectedLayers.insert(layerIndex)
            }
        }
        for member in members {
            document.snapshot.objects.removeValue(forKey: member.id)
        }
        for idx in appendedLayerIndexes.sorted(by: >) {
            guard idx >= 0 && idx < document.snapshot.layers.count else { continue }
            document.snapshot.layers.remove(at: idx)
        }
        appendedLayerIndexes.removeAll(keepingCapacity: true)
        document.triggerLayerUpdates(for: affectedLayers)
        Log.info("↩️ ImportCommand.undo DONE: doc has \(document.snapshot.layers.count) layers, \(document.snapshot.objects.count) objects", category: .general)
    }
}
