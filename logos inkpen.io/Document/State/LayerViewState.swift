import SwiftUI

struct ViewportState: Equatable {
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let viewMode: ViewMode
}

struct InteractionState: Equatable {
    let selectedObjectIDs: Set<UUID>
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
}

struct TransformState: Equatable {
    let liveScaleTransform: CGAffineTransform
    let liveGradientOriginX: Double?
    let liveGradientOriginY: Double?
}

struct LayerProperties: Equatable {
    let layerOpacity: Double
    let layerBlendMode: BlendMode
}

struct CanvasUpdateTriggers: Equatable {
    var fillColor: Bool = false
    var fillOpacity: Bool = false
    var fillGradient: Bool = false
    var strokeColor: Bool = false
    var strokeOpacity: Bool = false
    var strokeWidth: Bool = false
    var strokePlacement: Bool = false
    var gradientCenterpoint: Bool = false
    var gradientStops: Bool = false
    var gradientAttributes: Bool = false
    var textContent: Bool = false
    var textAttributes: Bool = false
    var pathGeometry: Bool = false
    var objectTransform: Bool = false

    mutating func toggleAll() {
        fillColor.toggle()
        fillOpacity.toggle()
        fillGradient.toggle()
        strokeColor.toggle()
        strokeOpacity.toggle()
        strokeWidth.toggle()
        strokePlacement.toggle()
        gradientCenterpoint.toggle()
        gradientStops.toggle()
        gradientAttributes.toggle()
        textContent.toggle()
        textAttributes.toggle()
        pathGeometry.toggle()
        objectTransform.toggle()
    }
}
