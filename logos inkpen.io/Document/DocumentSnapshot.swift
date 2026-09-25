import Foundation

struct
DocumentSnapshot: Equatable, Codable {
    var formatVersion: String
    var objects: [UUID: VectorObject]
    var layers: [Layer]
    var settings: DocumentSettings
    var colorSwatches: ColorSwatches
    var gridSettings: GridSettings
    var parentGroupCache: [UUID: UUID] = [:]
    var clippedObjectsCache: [UUID: [UUID]] = [:]

    enum CodingKeys: String, CodingKey {
        case formatVersion, objects, layers, settings, colorSwatches, gridSettings
    }

    init(
        formatVersion: String = "1.0.27",
        objects: [UUID: VectorObject] = [:],
        layers: [Layer] = [],
        settings: DocumentSettings = DocumentSettings(),
        colorSwatches: ColorSwatches = .empty,
        gridSettings: GridSettings = .default
    ) {
        self.formatVersion = formatVersion
        self.objects = objects
        self.layers = layers
        self.settings = settings
        self.colorSwatches = colorSwatches
        self.gridSettings = gridSettings
        self.parentGroupCache = [:]
        self.clippedObjectsCache = [:]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.formatVersion = try container.decodeIfPresent(String.self, forKey: .formatVersion) ?? "1.0"
        self.objects = try container.decode([UUID: VectorObject].self, forKey: .objects)
        self.layers = try container.decode([Layer].self, forKey: .layers)
        self.settings = try container.decode(DocumentSettings.self, forKey: .settings)
        self.colorSwatches = try container.decode(ColorSwatches.self, forKey: .colorSwatches)
        self.gridSettings = try container.decode(GridSettings.self, forKey: .gridSettings)
        self.parentGroupCache = [:]
        self.clippedObjectsCache = [:]
    }
}
