import Foundation
import Combine

class StrokeWidthCommand: BaseCommand {
    private let objectIDs: [UUID]
    private let oldWidths: [UUID: Double]
    private let newWidths: [UUID: Double]

    init(objectIDs: [UUID], oldWidths: [UUID: Double], newWidths: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.oldWidths = oldWidths
        self.newWidths = newWidths
    }

    override func execute(on document: VectorDocument) {
        applyWidths(newWidths, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyWidths(oldWidths, to: document)
    }

    private func applyWidths(_ widths: [UUID: Double], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard let width = widths[id],
                  var obj = document.snapshot.objects[id] else { continue }
            switch obj.objectType {
            case .text(var shape):
                if var typography = shape.typography {
                    typography.strokeWidth = width
                    shape.typography = typography
                }
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.strokeStyle?.width = width
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .guide:
                continue
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
