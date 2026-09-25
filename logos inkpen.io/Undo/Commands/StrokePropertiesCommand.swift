import Foundation
import Combine
import CoreGraphics

class StrokePropertiesCommand: BaseCommand {

    enum PropertyType {
        case placement
        case lineJoin
        case lineCap
        case miterLimit
        case imageOpacity
    }
    private let objectIDs: [UUID]
    private let propertyType: PropertyType
    private let oldPlacements: [UUID: StrokePlacement]?
    private let newPlacements: [UUID: StrokePlacement]?
    private let oldLineJoins: [UUID: CGLineJoin]?
    private let newLineJoins: [UUID: CGLineJoin]?
    private let oldLineCaps: [UUID: CGLineCap]?
    private let newLineCaps: [UUID: CGLineCap]?
    private let oldMiterLimits: [UUID: Double]?
    private let newMiterLimits: [UUID: Double]?
    private let oldOpacities: [UUID: Double]?
    private let newOpacities: [UUID: Double]?

    init(objectIDs: [UUID],
         placement old: [UUID: StrokePlacement],
         new: [UUID: StrokePlacement]) {
        self.objectIDs = objectIDs
        self.propertyType = .placement
        self.oldPlacements = old
        self.newPlacements = new
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         lineJoin old: [UUID: CGLineJoin],
         new: [UUID: CGLineJoin]) {
        self.objectIDs = objectIDs
        self.propertyType = .lineJoin
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = old
        self.newLineJoins = new
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         lineCap old: [UUID: CGLineCap],
         new: [UUID: CGLineCap]) {
        self.objectIDs = objectIDs
        self.propertyType = .lineCap
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = old
        self.newLineCaps = new
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         miterLimit old: [UUID: Double],
         new: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.propertyType = .miterLimit
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = old
        self.newMiterLimits = new
        self.oldOpacities = nil
        self.newOpacities = nil
    }

    init(objectIDs: [UUID],
         imageOpacity old: [UUID: Double],
         new: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.propertyType = .imageOpacity
        self.oldPlacements = nil
        self.newPlacements = nil
        self.oldLineJoins = nil
        self.newLineJoins = nil
        self.oldLineCaps = nil
        self.newLineCaps = nil
        self.oldMiterLimits = nil
        self.newMiterLimits = nil
        self.oldOpacities = old
        self.newOpacities = new
    }

    override func execute(on document: VectorDocument) {
        switch propertyType {
        case .placement:
            if let placements = newPlacements {
                applyPlacements(placements, to: document)
            }
        case .lineJoin:
            if let lineJoins = newLineJoins {
                applyLineJoins(lineJoins, to: document)
            }
        case .lineCap:
            if let lineCaps = newLineCaps {
                applyLineCaps(lineCaps, to: document)
            }
        case .miterLimit:
            if let miterLimits = newMiterLimits {
                applyMiterLimits(miterLimits, to: document)
            }
        case .imageOpacity:
            if let opacities = newOpacities {
                applyImageOpacities(opacities, to: document)
            }
        }
    }

    override func undo(on document: VectorDocument) {
        switch propertyType {
        case .placement:
            if let placements = oldPlacements {
                applyPlacements(placements, to: document)
            }
        case .lineJoin:
            if let lineJoins = oldLineJoins {
                applyLineJoins(lineJoins, to: document)
            }
        case .lineCap:
            if let lineCaps = oldLineCaps {
                applyLineCaps(lineCaps, to: document)
            }
        case .miterLimit:
            if let miterLimits = oldMiterLimits {
                applyMiterLimits(miterLimits, to: document)
            }
        case .imageOpacity:
            if let opacities = oldOpacities {
                applyImageOpacities(opacities, to: document)
            }
        }
    }

    private func applyPlacements(_ placements: [UUID: StrokePlacement], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard let placement = placements[id],
                  var obj = document.snapshot.objects[id] else { continue }
            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.strokeStyle?.placement = placement
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .text, .guide:
                continue
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func applyLineJoins(_ lineJoins: [UUID: CGLineJoin], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard let lineJoin = lineJoins[id],
                  var obj = document.snapshot.objects[id] else { continue }
            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.strokeStyle?.lineJoin = LineJoin(lineJoin)
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .text, .guide:
                continue
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func applyLineCaps(_ lineCaps: [UUID: CGLineCap], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard let lineCap = lineCaps[id],
                  var obj = document.snapshot.objects[id] else { continue }
            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.strokeStyle?.lineCap = LineCap(lineCap)
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .text, .guide:
                continue
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func applyMiterLimits(_ miterLimits: [UUID: Double], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard let miterLimit = miterLimits[id],
                  var obj = document.snapshot.objects[id] else { continue }
            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.strokeStyle?.miterLimit = miterLimit
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .text, .guide:
                continue
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    private func applyImageOpacities(_ opacities: [UUID: Double], to document: VectorDocument) {
        var affectedLayers = Set<Int>()
        for id in objectIDs {
            guard let opacity = opacities[id],
                  var obj = document.snapshot.objects[id] else { continue }
            switch obj.objectType {
            case .shape(var shape), .image(var shape), .warp(var shape), .group(var shape), .clipGroup(var shape), .clipMask(var shape):
                shape.opacity = opacity
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                document.snapshot.objects[id] = obj
                affectedLayers.insert(obj.layerIndex)
            case .text, .guide:
                continue
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }
}
