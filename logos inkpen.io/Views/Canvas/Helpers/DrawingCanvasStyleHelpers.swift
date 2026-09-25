import SwiftUI

extension DrawingCanvas {

    internal func getCurrentFillColor() -> VectorColor {
        if let firstSelectedTextID = document.viewState.selectedObjectIDs.first,

           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.fillColor
        }
        if let firstSelectedID = document.viewState.selectedObjectIDs.first,
           let shape = document.findShape(by: firstSelectedID),

           let fillColor = shape.fillStyle?.color {
            return fillColor
        }
        return document.defaultFillColor
    }

    internal func getCurrentFillOpacity() -> Double {
        if let firstSelectedTextID = document.viewState.selectedObjectIDs.first,

           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.fillOpacity
        }
        if let firstSelectedID = document.viewState.selectedObjectIDs.first,
           let shape = document.findShape(by: firstSelectedID),

           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        return document.defaultFillOpacity
    }

    internal func getCurrentStrokeColor() -> VectorColor {
        if let firstSelectedTextID = document.viewState.selectedObjectIDs.first,

           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.strokeColor
        }
        if let firstSelectedID = document.viewState.selectedObjectIDs.first,
           let shape = document.findShape(by: firstSelectedID),

           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        return document.defaultStrokeColor
    }

    internal func getCurrentStrokeOpacity() -> Double {
        if let firstSelectedTextID = document.viewState.selectedObjectIDs.first,

           let textObject = document.findText(by: firstSelectedTextID) {
            return textObject.typography.strokeOpacity
        }
        if let firstSelectedID = document.viewState.selectedObjectIDs.first,
           let shape = document.findShape(by: firstSelectedID),

           let opacity = shape.strokeStyle?.opacity {
            return opacity
        }
        return document.defaultStrokeOpacity
    }

    internal func getCurrentStrokeWidth() -> Double {
        if let firstSelectedID = document.viewState.selectedObjectIDs.first,
           let shape = document.findShape(by: firstSelectedID),

           let width = shape.strokeStyle?.width {
            return width
        }
        return document.defaultStrokeWidth
    }
}
