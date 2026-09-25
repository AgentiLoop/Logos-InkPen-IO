import SwiftUI

struct StrokeDefaults: Equatable {
    var placement: StrokePlacement
    var lineJoin: CGLineJoin
    var lineCap: CGLineCap
    var miterLimit: Double
    static let `default` = StrokeDefaults(
        placement: .center,
        lineJoin: .miter,
        lineCap: .butt,
        miterLimit: 10.0
    )
}

extension StrokeDefaults: Codable {

    enum CodingKeys: String, CodingKey {
        case placement, lineJoin, lineCap, miterLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placement = try container.decode(StrokePlacement.self, forKey: .placement)
        let lineJoinRaw = try container.decode(Int32.self, forKey: .lineJoin)
        lineJoin = CGLineJoin(rawValue: lineJoinRaw) ?? .miter
        let lineCapRaw = try container.decode(Int32.self, forKey: .lineCap)
        lineCap = CGLineCap(rawValue: lineCapRaw) ?? .butt
        miterLimit = try container.decode(Double.self, forKey: .miterLimit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placement, forKey: .placement)
        try container.encode(lineJoin.rawValue, forKey: .lineJoin)
        try container.encode(lineCap.rawValue, forKey: .lineCap)
        try container.encode(miterLimit, forKey: .miterLimit)
    }
}

struct GridSettings: Equatable {
    var showRulers: Bool
    var showGrid: Bool
    var snapToGrid: Bool
    var snapToPoint: Bool
    var gridSpacing: Double
    var gridOnTop: Bool
    var guides: [Guide]
    var showGuides: Bool
    var guidesLocked: Bool
    var snapToGuides: Bool
    static let `default` = GridSettings(
        showRulers: false,
        showGrid: false,
        snapToGrid: false,
        snapToPoint: false,
        gridSpacing: 12.0,
        gridOnTop: false,
        guides: [],
        showGuides: true,
        guidesLocked: false,
        snapToGuides: true
    )
}

extension GridSettings: Codable {

    enum CodingKeys: String, CodingKey {
        case showRulers, showGrid, snapToGrid, snapToPoint, gridSpacing, gridOnTop
        case guides, showGuides, guidesLocked, snapToGuides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showRulers = try container.decode(Bool.self, forKey: .showRulers)
        showGrid = try container.decode(Bool.self, forKey: .showGrid)
        snapToGrid = try container.decode(Bool.self, forKey: .snapToGrid)
        snapToPoint = try container.decode(Bool.self, forKey: .snapToPoint)
        gridSpacing = try container.decode(Double.self, forKey: .gridSpacing)
        gridOnTop = try container.decodeIfPresent(Bool.self, forKey: .gridOnTop) ?? false
        guides = try container.decodeIfPresent([Guide].self, forKey: .guides) ?? []
        showGuides = try container.decodeIfPresent(Bool.self, forKey: .showGuides) ?? true
        guidesLocked = try container.decodeIfPresent(Bool.self, forKey: .guidesLocked) ?? false
        snapToGuides = try container.decodeIfPresent(Bool.self, forKey: .snapToGuides) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showRulers, forKey: .showRulers)
        try container.encode(showGrid, forKey: .showGrid)
        try container.encode(snapToGrid, forKey: .snapToGrid)
        try container.encode(snapToPoint, forKey: .snapToPoint)
        try container.encode(gridSpacing, forKey: .gridSpacing)
        try container.encode(gridOnTop, forKey: .gridOnTop)
        try container.encode(guides, forKey: .guides)
        try container.encode(showGuides, forKey: .showGuides)
        try container.encode(guidesLocked, forKey: .guidesLocked)
        try container.encode(snapToGuides, forKey: .snapToGuides)
    }
}

struct ColorSwatches: Codable, Equatable {
    var rgb: [VectorColor]
    var cmyk: [VectorColor]
    var hsb: [VectorColor]

    static let empty = ColorSwatches(
        rgb: [],
        cmyk: [],
        hsb: []
    )
}
