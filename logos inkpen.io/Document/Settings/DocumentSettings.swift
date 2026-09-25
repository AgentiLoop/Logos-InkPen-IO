import SwiftUI

struct DocumentSettings: Codable, Hashable {
    var width: Double
    var height: Double
    var unit: MeasurementUnit
    var colorMode: ColorMode
    var resolution: Double
    var showRulers: Bool
    var showGrid: Bool
    var snapToGrid: Bool
    var snapToPoint: Bool
    var gridSpacing: Double
    var backgroundColor: VectorColor
    var selectedLayerId: UUID?
    var selectedLayerName: String?
    var layerExpansionState: [UUID: Bool]
    var groupExpansionState: [UUID: Bool]
    var pageOrigin: CGPoint?
    var fillColor: VectorColor?
    var strokeColor: VectorColor?
    var customRgbSwatches: [VectorColor]?
    var customCmykSwatches: [VectorColor]?
    var customHsbSwatches: [VectorColor]?

    private var _sizeInPoints: CGSize?

    init(width: Double = 11.0, height: Double = 8.5, unit: MeasurementUnit = .inches, colorMode: ColorMode = .rgb, resolution: Double = 72.0, showRulers: Bool? = nil, showGrid: Bool? = nil, snapToGrid: Bool? = nil, snapToPoint: Bool? = nil, gridSpacing: Double = 0.125, backgroundColor: VectorColor = .white, selectedLayerId: UUID? = nil, selectedLayerName: String? = "Layer 1", layerExpansionState: [UUID: Bool] = [:], groupExpansionState: [UUID: Bool] = [:], fillColor: VectorColor? = nil, strokeColor: VectorColor? = nil, customRgbSwatches: [VectorColor]? = nil, customCmykSwatches: [VectorColor]? = nil, customHsbSwatches: [VectorColor]? = nil) {
        self.width = width
        self.height = height
        self.unit = unit
        self.colorMode = colorMode
        self.resolution = resolution
        if let showRulersValue = showRulers {
            self.showRulers = showRulersValue
        } else {
            if UserDefaults.standard.object(forKey: "showRulers") != nil {
                self.showRulers = UserDefaults.standard.bool(forKey: "showRulers")
            } else {
                self.showRulers = true
            }
        }
        self.showGrid = showGrid ?? UserDefaults.standard.bool(forKey: "showGrid")
        self.snapToGrid = snapToGrid ?? UserDefaults.standard.bool(forKey: "snapToGrid")
        self.snapToPoint = snapToPoint ?? UserDefaults.standard.bool(forKey: "snapToPoint")
        self.gridSpacing = gridSpacing
        self.backgroundColor = backgroundColor
        self.selectedLayerId = selectedLayerId
        self.selectedLayerName = selectedLayerName ?? "Layer 1"
        self.layerExpansionState = layerExpansionState
        self.groupExpansionState = groupExpansionState
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.customRgbSwatches = customRgbSwatches
        self.customCmykSwatches = customCmykSwatches
        self.customHsbSwatches = customHsbSwatches
    }

    enum CodingKeys: String, CodingKey {
        case width, height, unit, colorMode, resolution, showRulers, showGrid, snapToGrid, snapToPoint, gridSpacing, backgroundColor, selectedLayerId, selectedLayerName
        case layerExpansionState, groupExpansionState
        case fillColor, strokeColor, customRgbSwatches, customCmykSwatches, customHsbSwatches
        case pageOrigin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        unit = try container.decode(MeasurementUnit.self, forKey: .unit)
        colorMode = try container.decode(ColorMode.self, forKey: .colorMode)
        resolution = try container.decode(Double.self, forKey: .resolution)
        showRulers = try container.decode(Bool.self, forKey: .showRulers)
        showGrid = try container.decode(Bool.self, forKey: .showGrid)
        snapToGrid = try container.decode(Bool.self, forKey: .snapToGrid)
        snapToPoint = try container.decodeIfPresent(Bool.self, forKey: .snapToPoint) ?? false
        gridSpacing = try container.decode(Double.self, forKey: .gridSpacing)
        backgroundColor = try container.decode(VectorColor.self, forKey: .backgroundColor)
        selectedLayerId = try container.decodeIfPresent(UUID.self, forKey: .selectedLayerId)
        selectedLayerName = try container.decodeIfPresent(String.self, forKey: .selectedLayerName) ?? "Layer 1"
        layerExpansionState = try container.decodeIfPresent([UUID: Bool].self, forKey: .layerExpansionState) ?? [:]
        groupExpansionState = try container.decodeIfPresent([UUID: Bool].self, forKey: .groupExpansionState) ?? [:]
        pageOrigin = try container.decodeIfPresent(CGPoint.self, forKey: .pageOrigin)
        fillColor = try container.decodeIfPresent(VectorColor.self, forKey: .fillColor)
        strokeColor = try container.decodeIfPresent(VectorColor.self, forKey: .strokeColor)
        customRgbSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .customRgbSwatches)
        customCmykSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .customCmykSwatches)
        customHsbSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .customHsbSwatches)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(unit, forKey: .unit)
        try container.encode(colorMode, forKey: .colorMode)
        try container.encode(resolution, forKey: .resolution)
        try container.encode(showRulers, forKey: .showRulers)
        try container.encode(showGrid, forKey: .showGrid)
        try container.encode(snapToGrid, forKey: .snapToGrid)
        try container.encode(snapToPoint, forKey: .snapToPoint)
        try container.encode(gridSpacing, forKey: .gridSpacing)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(selectedLayerId, forKey: .selectedLayerId)
        try container.encode(selectedLayerName, forKey: .selectedLayerName)
        try container.encode(layerExpansionState, forKey: .layerExpansionState)
        try container.encode(groupExpansionState, forKey: .groupExpansionState)
        try container.encodeIfPresent(pageOrigin, forKey: .pageOrigin)
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
        try container.encodeIfPresent(strokeColor, forKey: .strokeColor)
        try container.encodeIfPresent(customRgbSwatches, forKey: .customRgbSwatches)
        try container.encodeIfPresent(customCmykSwatches, forKey: .customCmykSwatches)
        try container.encodeIfPresent(customHsbSwatches, forKey: .customHsbSwatches)
    }

    var sizeInPoints: CGSize {
        if let storedSize = _sizeInPoints {
            return storedSize
        } else {
            let pointsPerUnit = unit.pointsPerUnit
            return CGSize(width: width * pointsPerUnit, height: height * pointsPerUnit)
        }
    }

    mutating func changeUnit(to newUnit: MeasurementUnit) {
        let currentSizeInPoints = sizeInPoints
        unit = newUnit
        let newPointsPerUnit = newUnit.pointsPerUnit
        width = currentSizeInPoints.width / newPointsPerUnit
        height = currentSizeInPoints.height / newPointsPerUnit
        gridSpacing = newUnit.defaultGridSpacing
        _sizeInPoints = currentSizeInPoints
    }

    mutating func setSizeInPoints(_ newSize: CGSize) {
        _sizeInPoints = newSize
        let ppu = unit.pointsPerUnit
        width = newSize.width / ppu
        height = newSize.height / ppu
    }
}
