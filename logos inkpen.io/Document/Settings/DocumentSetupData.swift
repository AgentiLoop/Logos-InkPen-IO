import SwiftUI

struct DocumentSetupData {
    var width: Double = 11.0
    var height: Double = 8.5
    var unit: MeasurementUnit = .inches
    var filename: String = "Untitled"
    var colorMode: ColorMode = .rgb
    var resolution: Double = 72.0
    var showRulers: Bool = true
    var showGrid: Bool = false
    var snapToGrid: Bool = false
    var backgroundColor: VectorColor = .white

    var documentSettings: DocumentSettings {
        DocumentSettings(
            width: width,
            height: height,
            unit: unit,
            colorMode: colorMode,
            resolution: resolution,
            showRulers: showRulers,
            showGrid: showGrid,
            snapToGrid: snapToGrid,
            gridSpacing: 0.125,
            backgroundColor: backgroundColor
        )
    }
}
