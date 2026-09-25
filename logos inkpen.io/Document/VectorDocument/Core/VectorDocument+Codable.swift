import SwiftUI

extension VectorDocument {

    enum CodingKeys: CodingKey {
        case settings, snapshot, layers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var settingsToSave = settings
        settingsToSave.fillColor = documentColorDefaults.fillColor
        settingsToSave.strokeColor = documentColorDefaults.strokeColor
        settingsToSave.customRgbSwatches = colorSwatches.rgb.isEmpty ? nil : colorSwatches.rgb
        settingsToSave.customCmykSwatches = colorSwatches.cmyk.isEmpty ? nil : colorSwatches.cmyk
        settingsToSave.customHsbSwatches = colorSwatches.hsb.isEmpty ? nil : colorSwatches.hsb
        var snapshotToSave = snapshot
        snapshotToSave.settings = settingsToSave
        snapshotToSave.colorSwatches = colorSwatches
        snapshotToSave.gridSettings = gridSettings
        try container.encode(settingsToSave, forKey: .settings)
        try container.encode(snapshotToSave, forKey: .snapshot)
    }
}
