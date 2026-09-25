import SwiftUI
import Combine

extension VectorDocument {

    internal func createCanvasAndWorkingLayers() {
        snapshot.layers.removeAll()
        snapshot.layers.append(Layer(
            id: UUID(),
            name: "Pasteboard",
            objectIDs: [],
            isVisible: true,
            isLocked: true,
            opacity: 1.0,
            blendMode: .normal,
            color: .gray
        ))
        snapshot.layers.append(Layer(
            id: UUID(),
            name: "Canvas",
            objectIDs: [],
            isVisible: true,
            isLocked: true,
            opacity: 1.0,
            blendMode: .normal,
            color: .blue
        ))
        snapshot.layers.append(Layer(
            id: UUID(),
            name: "Guides",
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .cyan
        ))
        snapshot.layers.append(Layer(
            id: UUID(),
            name: "Layer 1",
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .green
        ))
    }

    var documentBounds: CGRect {
        return CGRect(origin: .zero, size: settings.sizeInPoints)
    }

    func translateAllContent(by delta: CGPoint, includeBackgrounds: Bool = false) {
        guard delta != .zero else { return }
        for layerIndex in snapshot.layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, _) in shapes.enumerated() {
                var updatedShape = shapes[shapeIndex]
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
            }
        }
        translateAllTextInUnified(delta: delta)
    }

    func onSettingsChanged() {
        gridSettings.gridSpacing = settings.gridSpacing
    }

    func migrateBackgroundShapesToCanvas() {
        var needsMigration = false
        if snapshot.layers.count > 0 && snapshot.layers[0].name == "Pasteboard" {
            let pasteboardShapes = getShapesForLayer(0)
            if let bgShape = pasteboardShapes.first(where: { $0.name == "Pasteboard Background" }) {
                needsMigration = true
                Log.info("🔄 Found old Pasteboard Background shape - removing for Canvas migration", category: .general)
                removeShapeFromUnifiedSystem(id: bgShape.id)
            }
        }
        if snapshot.layers.count > 1 && snapshot.layers[1].name == "Canvas" {
            let canvasShapes = getShapesForLayer(1)
            if let bgShape = canvasShapes.first(where: { $0.name == "Canvas Background" }) {
                needsMigration = true
                Log.info("🔄 Found old Canvas Background shape - removing for Canvas migration", category: .general)
                removeShapeFromUnifiedSystem(id: bgShape.id)
            }
        }
        if needsMigration {
            Log.info("✅ Document migrated to SwiftUI Canvas-based backgrounds", category: .general)
        }
    }
}
