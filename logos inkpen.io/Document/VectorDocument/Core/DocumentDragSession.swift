import CoreGraphics
import Foundation

/// Transient state for an in-progress drag. Not persisted or observed.
struct DocumentDragSession {
    var processedLayers: Set<Int> = []
    var processedObjects: Set<UUID> = []
    var activeLayerIndex: Int? = nil
    var currentDragOffset: CGPoint = .zero
    var dragPreviewCoordinates: CGPoint = .zero
    var cachedSelectionBounds: CGRect? = nil
}
