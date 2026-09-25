import SwiftUI
import UniformTypeIdentifiers

struct LineCap: Codable, Hashable {
    private let cap: String

    init(_ cap: CGLineCap) {
        switch cap {
        case .butt:
            self.cap = "butt"
        case .round:
            self.cap = "round"
        case .square:
            self.cap = "square"

        @unknown default:
            self.cap = "butt"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.cap = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(cap)
    }

    var cgLineCap: CGLineCap {
        switch cap {
        case "butt":
            return .butt
        case "round":
            return .round
        case "square":
            return .square
        default:
            return .butt
        }
    }
    static let butt = LineCap(.butt)
    static let round = LineCap(.round)
    static let square = LineCap(.square)
}

struct LineJoin: Codable, Hashable {
    private let join: String

    init(_ join: CGLineJoin) {
        switch join {
        case .miter:
            self.join = "miter"
        case .round:
            self.join = "round"
        case .bevel:
            self.join = "bevel"

        @unknown default:
            self.join = "miter"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.join = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(join)
    }

    var cgLineJoin: CGLineJoin {
        switch join {
        case "miter":
            return .miter
        case "round":
            return .round
        case "bevel":
            return .bevel
        default:
            return .miter
        }
    }
    static let miter = LineJoin(.miter)
    static let round = LineJoin(.round)
    static let bevel = LineJoin(.bevel)
}

enum StrokePlacement: String, CaseIterable, Codable {
    case center = "Center"
    case inside = "Inside"
    case outside = "Outside"

    var iconName: String {
        switch self {
        case .center: return "circle"
        case .inside: return "circle.fill"
        case .outside: return "circle.circle"
        }
    }
}

struct StrokeStyle: Hashable {
    var color: VectorColor
    var width: Double
    var placement: StrokePlacement
    var dashPattern: [Double]
    var lineCap: LineCap
    var lineJoin: LineJoin
    var miterLimit: Double
    var opacity: Double
    var blendMode: BlendMode
    var scaleWithTransform: Bool

    init(color: VectorColor = .black, width: Double = 1.0, placement: StrokePlacement = .center, dashPattern: [Double] = [], lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: Double = 10.0, opacity: Double = 1.0, blendMode: BlendMode = .normal, scaleWithTransform: Bool = false) {
        self.color = color
        self.width = width
        self.placement = placement
        self.dashPattern = dashPattern
        self.lineCap = LineCap(lineCap)
        self.lineJoin = LineJoin(lineJoin)
        self.miterLimit = miterLimit
        self.opacity = opacity
        self.blendMode = blendMode
        self.scaleWithTransform = scaleWithTransform
    }

    init(gradient: VectorGradient, width: Double = 1.0, placement: StrokePlacement = .center, dashPattern: [Double] = [], lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: Double = 10.0, opacity: Double = 1.0, blendMode: BlendMode = .normal, scaleWithTransform: Bool = false) {
        self.color = .gradient(gradient)
        self.width = width
        self.placement = placement
        self.dashPattern = dashPattern
        self.lineCap = LineCap(lineCap)
        self.lineJoin = LineJoin(lineJoin)
        self.miterLimit = miterLimit
        self.opacity = opacity
        self.blendMode = blendMode
        self.scaleWithTransform = scaleWithTransform
    }

    var isGradient: Bool {
        if case .gradient = color {
            return true
        }
        return false
    }

    var gradient: VectorGradient? {
        if case .gradient(let gradient) = color {
            return gradient
        }
        return nil
    }

    var isSolidColor: Bool {
        return !isGradient
    }
}

extension StrokeStyle: Codable {

    enum CodingKeys: String, CodingKey {
        case color, width, placement, dashPattern, lineCap, lineJoin, miterLimit, opacity, blendMode, scaleWithTransform
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)
        try container.encode(width, forKey: .width)
        try container.encode(placement, forKey: .placement)
        if !dashPattern.isEmpty {
            try container.encode(dashPattern, forKey: .dashPattern)
        }
        try container.encode(lineCap, forKey: .lineCap)
        try container.encode(lineJoin, forKey: .lineJoin)
        try container.encode(miterLimit, forKey: .miterLimit)
        if opacity != 1.0 {
            try container.encode(opacity, forKey: .opacity)
        }
        if blendMode != .normal {
            try container.encode(blendMode, forKey: .blendMode)
        }
        if scaleWithTransform {
            try container.encode(scaleWithTransform, forKey: .scaleWithTransform)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(VectorColor.self, forKey: .color)
        width = try container.decode(Double.self, forKey: .width)
        placement = try container.decode(StrokePlacement.self, forKey: .placement)
        dashPattern = try container.decodeIfPresent([Double].self, forKey: .dashPattern) ?? []
        lineCap = try container.decode(LineCap.self, forKey: .lineCap)
        lineJoin = try container.decode(LineJoin.self, forKey: .lineJoin)
        miterLimit = try container.decode(Double.self, forKey: .miterLimit)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
        scaleWithTransform = try container.decodeIfPresent(Bool.self, forKey: .scaleWithTransform) ?? false
    }
}

struct FillStyle: Codable, Hashable {
    var color: VectorColor
    var opacity: Double
    var blendMode: BlendMode

    init(color: VectorColor = .clear, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = color
        self.opacity = opacity
        self.blendMode = blendMode
    }

    enum CodingKeys: String, CodingKey {
        case color, opacity, blendMode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)
        if opacity != 1.0 {
            try container.encode(opacity, forKey: .opacity)
        }
        if blendMode != .normal {
            try container.encode(blendMode, forKey: .blendMode)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(VectorColor.self, forKey: .color)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
    }

    init(gradient: VectorGradient, opacity: Double = 1.0, blendMode: BlendMode = .normal) {
        self.color = .gradient(gradient)
        self.opacity = opacity
        self.blendMode = blendMode
    }

    var isGradient: Bool {
        if case .gradient = color {
            return true
        }
        return false
    }

    var gradient: VectorGradient? {
        if case .gradient(let gradient) = color {
            return gradient
        }
        return nil
    }

    var isSolidColor: Bool {
        return !isGradient
    }

    var solidColor: VectorColor? {
        if isGradient {
            return nil
        }
        return color
    }

    static func linearGradient(from startColor: VectorColor, to endColor: VectorColor, opacity: Double = 1.0) -> FillStyle {
        let stops = [
            GradientStop(position: 0.0, color: startColor, opacity: 1.0),
            GradientStop(position: 1.0, color: endColor, opacity: 1.0)
        ]
        let linear = LinearGradient(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 1, y: 0),
            stops: stops,
            spreadMethod: .pad
        )
        let gradient = VectorGradient.linear(linear)
        return FillStyle(gradient: gradient, opacity: opacity)
    }

    static func radialGradient(from innerColor: VectorColor, to outerColor: VectorColor, opacity: Double = 1.0) -> FillStyle {
        let stops = [
            GradientStop(position: 0.0, color: innerColor, opacity: 1.0),
            GradientStop(position: 1.0, color: outerColor, opacity: 1.0)
        ]
        let radial = RadialGradient(
            centerPoint: CGPoint(x: 0.5, y: 0.5),
            radius: 0.5,
            stops: stops,
            focalPoint: nil,
            spreadMethod: .pad
        )
        let gradient = VectorGradient.radial(radial)
        return FillStyle(gradient: gradient, opacity: opacity)
    }
}

enum GeometricShapeType: String, CaseIterable, Codable {
    case rectangle = "Rectangle"
    case square = "Square"
    case roundedRectangle = "Rounded Rectangle"
    case circle = "Circle"
    case ellipse = "Ellipse"
    case triangle = "Triangle"
    case pentagon = "Pentagon"
    case hexagon = "Hexagon"
    case heptagon = "Heptagon"
    case octagon = "Octagon"
    case star = "Star"
    case polygon = "Polygon"
    case line = "Line"
    case arrow = "Arrow"
    case diamond = "Diamond"
    case heart = "Heart"
    case stopSign = "Stop Sign"
    case brushStroke = "Brush Stroke"

    var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .square: return "square"
        case .roundedRectangle: return "rectangle.roundedtop"
        case .circle: return "circle"
        case .ellipse: return "oval"
        case .triangle: return "triangle"
        case .pentagon: return "pentagon"
        case .hexagon: return "hexagon"
        case .heptagon: return "heptagon"
        case .octagon: return "octagon"
        case .star: return "star"
        case .polygon: return "octagon"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .diamond: return "diamond"
        case .heart: return "heart"
        case .stopSign: return "octagon.fill"
        case .brushStroke: return "scribble.variable"
        }
    }
}

struct VectorShape: Hashable, Identifiable {
    var id: UUID
    var name: String

    var path: VectorPath {
        didSet { _cachedCGPath = nil }
    }
    var geometricType: GeometricShapeType?
    var strokeStyle: StrokeStyle?
    var fillStyle: FillStyle?

    var transform: CGAffineTransform {
        didSet { _cachedCGPath = nil }
    }
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    var blendMode: BlendMode
    var bounds: CGRect
    var embeddedImageData: Data? = nil
    var linkedImagePath: String? = nil
    var linkedImageBookmarkData: Data? = nil
    var isGroup: Bool
    var groupedShapes: [VectorShape]
    var memberIDs: [UUID]
    var groupTransform: CGAffineTransform
    var isClippingGroup: Bool = false
    var isCompoundPath: Bool
    var isClippingPath: Bool = false
    var clippedByShapeID: UUID?
    var isWarpObject: Bool
    var isGuide: Bool = false
    var guideOrientation: Guide.Orientation? = nil
    var originalPath: VectorPath?
    var warpEnvelope: [CGPoint]
    var originalEnvelope: [CGPoint]
    var warpedBounds: CGRect?
    var isRoundedRectangle: Bool = false
    var originalBounds: CGRect?
    var cornerRadii: [Double] = []
    var textContent: String? = nil
    var typography: TypographyProperties? = nil
    var cursorPosition: Int? = nil
    var areaSize: CGSize? = nil
    var isEditing: Bool? = nil
    var textPosition: CGPoint? = nil
    var metadata: [String: String] = [:]
    var transformOrigin: TransformOrigin? = nil
    var anchorTypes: [Int: AnchorPointType] = [:]

    private var _cachedCGPath: CGPath?
    private var _cacheUpdateTrigger: UInt = 0

    var cachedRenderedImage: CGImage? = nil
    var cachedImageQuality: Double = 1.0
    var cachedImageTileSize: Int = 32

    func cachedCGPath(updateTrigger: UInt? = nil) -> CGPath {
        if let trigger = updateTrigger, _cacheUpdateTrigger != trigger {
            return buildCGPath()
        }
        if let cached = _cachedCGPath {
            return cached
        }
        return buildCGPath()
    }

    var cachedCGPath: CGPath {
        if let cached = _cachedCGPath {
            return cached
        }
        return buildCGPath()
    }

    mutating func invalidateCGPathCache() {
        _cachedCGPath = nil
    }

    private func buildCGPath() -> CGPath {
        let mutablePath = CGMutablePath()
        for element in path.elements {
            switch element {
            case .move(let to):
                mutablePath.move(to: to.cgPoint)
            case .line(let to):
                mutablePath.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                mutablePath.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                mutablePath.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                if !mutablePath.isEmpty {
                    mutablePath.closeSubpath()
                }
            }
        }
        if !transform.isIdentity {
            var mutableTransform = transform
            return mutablePath.copy(using: &mutableTransform) ?? mutablePath
        }
        return mutablePath
    }

    init(name: String = "Shape", path: VectorPath, geometricType: GeometricShapeType? = nil, strokeStyle: StrokeStyle? = nil, fillStyle: FillStyle? = nil, transform: CGAffineTransform = .identity, isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal, isGroup: Bool = false, groupedShapes: [VectorShape] = [], memberIDs: [UUID] = [], groupTransform: CGAffineTransform = .identity, isClippingGroup: Bool = false, isCompoundPath: Bool = false, isClippingPath: Bool = false, clippedByShapeID: UUID? = nil, isWarpObject: Bool = false, originalPath: VectorPath? = nil, warpEnvelope: [CGPoint] = [], originalEnvelope: [CGPoint] = [], warpedBounds: CGRect? = nil, isRoundedRectangle: Bool = false, originalBounds: CGRect? = nil, cornerRadii: [Double] = [], textContent: String? = nil, typography: TypographyProperties? = nil, cursorPosition: Int? = nil, areaSize: CGSize? = nil, isEditing: Bool? = nil, textPosition: CGPoint? = nil, metadata: [String: String] = [:], anchorTypes: [Int: AnchorPointType] = [:]) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.geometricType = geometricType
        self.strokeStyle = strokeStyle
        self.fillStyle = fillStyle
        self.transform = transform
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
        self.bounds = path.cgPath.boundingBoxOfPath
        self.isGroup = isGroup
        self.groupedShapes = groupedShapes
        self.memberIDs = memberIDs
        self.groupTransform = groupTransform
        self.isClippingGroup = isClippingGroup
        self.isCompoundPath = isCompoundPath
        self.isClippingPath = isClippingPath
        self.clippedByShapeID = clippedByShapeID
        self.isWarpObject = isWarpObject
        self.originalPath = originalPath
        self.warpEnvelope = warpEnvelope
        self.originalEnvelope = originalEnvelope
        self.warpedBounds = warpedBounds
        self.isRoundedRectangle = isRoundedRectangle
        self.originalBounds = originalBounds
        self.cornerRadii = cornerRadii
        self.textContent = textContent
        self.typography = typography
        self.cursorPosition = cursorPosition
        self.areaSize = areaSize
        self.isEditing = isEditing
        self.textPosition = textPosition
        self.metadata = metadata
        self.anchorTypes = anchorTypes
    }

    var transformedPath: CGPath {
        var mutableTransform = transform
        return path.cgPath.copy(using: &mutableTransform) ?? path.cgPath
    }

    mutating func updateBounds() {
        if typography != nil {
            if let areaSize = areaSize {
                bounds = CGRect(x: 0, y: 0, width: areaSize.width, height: areaSize.height)
            } else {
                bounds = CGRect(x: 0, y: 0, width: 200, height: 50)
            }
            return
        }
        if isGroup {
            return
        }
        let pathBounds = path.cgPath.boundingBoxOfPath
        if !pathBounds.isInfinite && !pathBounds.isNull && !pathBounds.isEmpty {
            bounds = pathBounds
        }
    }

    static func group(from shapes: [VectorShape], name: String = "Group", isClippingGroup: Bool = false) -> VectorShape {
        var calculatedGroupBounds = CGRect.null
        for shape in shapes {
            let shapeBounds: CGRect
            if shape.typography != nil, let textPosition = shape.textPosition, let areaSize = shape.areaSize {
                shapeBounds = CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
            } else if shape.isGroupContainer {
                shapeBounds = shape.groupBounds.applying(shape.transform)
            } else {
                shapeBounds = shape.bounds.applying(shape.transform)
            }
            calculatedGroupBounds = calculatedGroupBounds.union(shapeBounds)
        }
        let memberIDs = shapes.map { $0.id }
        let groupPath = VectorPath(elements: [], isClosed: false)

        var groupShape = VectorShape(
            name: name,
            path: groupPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: .identity,
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            isGroup: true,
            groupedShapes: [],
            memberIDs: memberIDs,
            groupTransform: .identity,
            isClippingGroup: isClippingGroup
        )
        groupShape.bounds = calculatedGroupBounds
        return groupShape
    }

    var isGroupContainer: Bool {
        return isGroup && (!memberIDs.isEmpty || !groupedShapes.isEmpty)
    }

    var isCompoundPathContainer: Bool {
        return isCompoundPath
    }

    var groupBounds: CGRect {
        guard isGroupContainer else { return bounds }
        if !memberIDs.isEmpty {
            return bounds
        }
        var groupBounds = CGRect.null
        for shape in groupedShapes {
            let shapeBounds: CGRect
            if shape.typography != nil, let textPosition = shape.textPosition, let areaSize = shape.areaSize {
                shapeBounds = CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
            } else {
                shapeBounds = shape.bounds.applying(shape.transform)
            }
            groupBounds = groupBounds.union(shapeBounds)
        }
        return groupBounds
    }

    func createWarpObject(warpedPath: VectorPath, warpEnvelope: [CGPoint]) -> VectorShape {
        var warpObject = self
        warpObject.id = UUID()
        warpObject.name = "Warped " + self.name
        warpObject.isWarpObject = true
        warpObject.originalPath = self.path
        warpObject.path = warpedPath
        warpObject.warpEnvelope = warpEnvelope
        warpObject.transform = .identity
        warpObject.updateBounds()
        return warpObject
    }

    func unwrapWarpObject() -> VectorShape? {
        guard isWarpObject else { return nil }
        var unwrappedShape = self
        unwrappedShape.id = UUID()
        unwrappedShape.name = self.name.replacingOccurrences(of: "Warped ", with: "")
        unwrappedShape.isWarpObject = false
        unwrappedShape.warpEnvelope = []
        unwrappedShape.originalEnvelope = []
        unwrappedShape.transform = .identity
        if isGroup && !groupedShapes.isEmpty {
            unwrappedShape.originalPath = nil
        } else if let originalPath = originalPath {
            unwrappedShape.originalPath = nil
            unwrappedShape.path = originalPath
        } else {
            unwrappedShape.originalPath = nil
        }
        unwrappedShape.updateBounds()
        return unwrappedShape
    }

    func expandWarpObject() -> VectorShape? {
        guard isWarpObject else { return nil }
        var expandedShape = self
        expandedShape.id = UUID()
        expandedShape.name = self.name.replacingOccurrences(of: "Warped ", with: "Expanded ")
        expandedShape.isWarpObject = false
        expandedShape.originalPath = nil
        expandedShape.warpEnvelope = []
        expandedShape.originalEnvelope = []
        expandedShape.transform = .identity
        expandedShape.updateBounds()
        return expandedShape
    }

    static func textObject(content: String, typography: TypographyProperties, position: CGPoint, areaSize: CGSize? = nil) -> VectorShape {
        let emptyPath = VectorPath(elements: [], isClosed: false)
        return VectorShape(
            name: "Text: \(content.prefix(20))",
            path: emptyPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: CGAffineTransform(translationX: position.x, y: position.y),
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            textContent: content,
            typography: typography,
            cursorPosition: content.count,
            areaSize: areaSize,
            isEditing: false,
            textPosition: position
        )
    }

    static func from(_ vectorText: VectorText) -> VectorShape {
        let emptyPath = VectorPath(elements: [], isClosed: false)
        let finalTransform = CGAffineTransform(translationX: vectorText.position.x, y: vectorText.position.y).concatenating(vectorText.transform)

        var shape = VectorShape(
            name: "Text: \(vectorText.content.prefix(20))",
            path: emptyPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: finalTransform,
            isVisible: vectorText.isVisible,
            isLocked: vectorText.isLocked,
            opacity: 1.0,
            blendMode: .normal,
            textContent: vectorText.content,
            typography: vectorText.typography,
            cursorPosition: vectorText.cursorPosition,
            areaSize: vectorText.areaSize,
            isEditing: vectorText.isEditing,
            textPosition: vectorText.position
        )
        shape.id = vectorText.id
        if let areaSize = vectorText.areaSize {
            shape.bounds = CGRect(x: 0, y: 0, width: areaSize.width, height: areaSize.height)
        } else if !vectorText.bounds.isInfinite && !vectorText.bounds.isNull &&
                  vectorText.bounds.width > 0 && vectorText.bounds.height > 0 {
            shape.bounds = CGRect(
                x: 0, y: 0,
                width: vectorText.bounds.width,
                height: vectorText.bounds.height
            )
        } else {
            shape.bounds = CGRect(x: 0, y: 0, width: 200, height: 50)
        }
        return shape
    }
}

extension VectorShape: Codable {

    enum CodingKeys: String, CodingKey {
        case id, name, path, geometricType, strokeStyle, fillStyle
        case transform, isVisible, isLocked, opacity, blendMode, bounds
        case embeddedImageData, linkedImagePath, linkedImageBookmarkData
        case isGroup, groupedShapes, memberIDs, groupTransform, isClippingGroup
        case isCompoundPath, isClippingPath, clippedByShapeID
        case isWarpObject, originalPath, warpEnvelope, originalEnvelope, warpedBounds
        case isGuide, guideOrientation
        case isRoundedRectangle, originalBounds, cornerRadii
        case textContent, typography
        case cursorPosition, areaSize, isEditing, textPosition
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(geometricType, forKey: .geometricType)
        try container.encodeIfPresent(strokeStyle, forKey: .strokeStyle)
        try container.encodeIfPresent(fillStyle, forKey: .fillStyle)
        if transform != .identity {
            try container.encode(transform, forKey: .transform)
        }
        if !isVisible { try container.encode(isVisible, forKey: .isVisible) }
        if isLocked { try container.encode(isLocked, forKey: .isLocked) }
        if opacity != 1.0 {
            try container.encode(opacity, forKey: .opacity)
        }
        if blendMode != .normal {
            try container.encode(blendMode, forKey: .blendMode)
        }
        let validBounds: CGRect
        if bounds.isInfinite || bounds.isNull ||
           bounds.width.isInfinite || bounds.height.isInfinite ||
           bounds.width.isNaN || bounds.height.isNaN {
            if typography != nil {
                validBounds = CGRect(x: 0, y: 0, width: areaSize?.width ?? 200, height: areaSize?.height ?? 50)
            } else {
                validBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
        } else {
            validBounds = bounds
        }
        try container.encode(validBounds, forKey: .bounds)
        try container.encodeIfPresent(embeddedImageData, forKey: .embeddedImageData)
        try container.encodeIfPresent(linkedImagePath, forKey: .linkedImagePath)
        try container.encodeIfPresent(linkedImageBookmarkData, forKey: .linkedImageBookmarkData)
        if isGroup {
            try container.encode(isGroup, forKey: .isGroup)
            if !memberIDs.isEmpty {
                try container.encode(memberIDs, forKey: .memberIDs)
            }
            if !groupedShapes.isEmpty {
                try container.encode(groupedShapes, forKey: .groupedShapes)
            }
            if groupTransform != .identity {
                try container.encode(groupTransform, forKey: .groupTransform)
            }
            if isClippingGroup {
                try container.encode(isClippingGroup, forKey: .isClippingGroup)
            }
        }
        if isCompoundPath { try container.encode(isCompoundPath, forKey: .isCompoundPath) }
        if isClippingPath { try container.encode(isClippingPath, forKey: .isClippingPath) }
        try container.encodeIfPresent(clippedByShapeID, forKey: .clippedByShapeID)
        if isWarpObject { try container.encode(isWarpObject, forKey: .isWarpObject) }
        try container.encodeIfPresent(originalPath, forKey: .originalPath)
        if !warpEnvelope.isEmpty { try container.encode(warpEnvelope, forKey: .warpEnvelope) }
        if !originalEnvelope.isEmpty { try container.encode(originalEnvelope, forKey: .originalEnvelope) }
        try container.encodeIfPresent(warpedBounds, forKey: .warpedBounds)
        if isGuide { try container.encode(isGuide, forKey: .isGuide) }
        try container.encodeIfPresent(guideOrientation, forKey: .guideOrientation)
        if isRoundedRectangle { try container.encode(isRoundedRectangle, forKey: .isRoundedRectangle) }
        try container.encodeIfPresent(originalBounds, forKey: .originalBounds)
        if !cornerRadii.isEmpty { try container.encode(cornerRadii, forKey: .cornerRadii) }
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(typography, forKey: .typography)
        try container.encodeIfPresent(cursorPosition, forKey: .cursorPosition)
        try container.encodeIfPresent(areaSize, forKey: .areaSize)
        if let isEditing = isEditing, isEditing { try container.encode(isEditing, forKey: .isEditing) }
        try container.encodeIfPresent(textPosition, forKey: .textPosition)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            id = try container.decode(UUID.self, forKey: .id)
        } catch {
            Log.error("❌ Failed to decode 'id': \(error)", category: .error)
            throw error
        }
        do {
            name = try container.decode(String.self, forKey: .name)
        } catch {
            Log.error("❌ Failed to decode 'name': \(error)", category: .error)
            throw error
        }
        do {
            path = try container.decode(VectorPath.self, forKey: .path)
        } catch {
            Log.error("❌ Failed to decode 'path': \(error)", category: .error)
            throw error
        }
        geometricType = try container.decodeIfPresent(GeometricShapeType.self, forKey: .geometricType)
        strokeStyle = try container.decodeIfPresent(StrokeStyle.self, forKey: .strokeStyle)
        fillStyle = try container.decodeIfPresent(FillStyle.self, forKey: .fillStyle)
        transform = try container.decodeIfPresent(CGAffineTransform.self, forKey: .transform) ?? .identity
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
        let decodedBounds = try container.decode(CGRect.self, forKey: .bounds)
        if decodedBounds.isInfinite || decodedBounds.isNull ||
           decodedBounds.width.isInfinite || decodedBounds.height.isInfinite ||
           decodedBounds.width.isNaN || decodedBounds.height.isNaN {
            bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        } else {
            bounds = decodedBounds
        }
        embeddedImageData = try container.decodeIfPresent(Data.self, forKey: .embeddedImageData)
        linkedImagePath = try container.decodeIfPresent(String.self, forKey: .linkedImagePath)
        linkedImageBookmarkData = try container.decodeIfPresent(Data.self, forKey: .linkedImageBookmarkData)
        isGroup = try container.decodeIfPresent(Bool.self, forKey: .isGroup) ?? false
        groupedShapes = try container.decodeIfPresent([VectorShape].self, forKey: .groupedShapes) ?? []
        memberIDs = try container.decodeIfPresent([UUID].self, forKey: .memberIDs) ?? []
        groupTransform = try container.decodeIfPresent(CGAffineTransform.self, forKey: .groupTransform) ?? .identity
        isClippingGroup = try container.decodeIfPresent(Bool.self, forKey: .isClippingGroup) ?? false
        isCompoundPath = try container.decodeIfPresent(Bool.self, forKey: .isCompoundPath) ?? false
        isClippingPath = try container.decodeIfPresent(Bool.self, forKey: .isClippingPath) ?? false
        clippedByShapeID = try container.decodeIfPresent(UUID.self, forKey: .clippedByShapeID)
        isWarpObject = try container.decodeIfPresent(Bool.self, forKey: .isWarpObject) ?? false
        originalPath = try container.decodeIfPresent(VectorPath.self, forKey: .originalPath)
        warpEnvelope = try container.decodeIfPresent([CGPoint].self, forKey: .warpEnvelope) ?? []
        originalEnvelope = try container.decodeIfPresent([CGPoint].self, forKey: .originalEnvelope) ?? []
        warpedBounds = try container.decodeIfPresent(CGRect.self, forKey: .warpedBounds)
        isGuide = try container.decodeIfPresent(Bool.self, forKey: .isGuide) ?? false
        guideOrientation = try container.decodeIfPresent(Guide.Orientation.self, forKey: .guideOrientation)
        isRoundedRectangle = try container.decodeIfPresent(Bool.self, forKey: .isRoundedRectangle) ?? false
        originalBounds = try container.decodeIfPresent(CGRect.self, forKey: .originalBounds)
        cornerRadii = try container.decodeIfPresent([Double].self, forKey: .cornerRadii) ?? []
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        typography = try container.decodeIfPresent(TypographyProperties.self, forKey: .typography)
        cursorPosition = try container.decodeIfPresent(Int.self, forKey: .cursorPosition)
        areaSize = try container.decodeIfPresent(CGSize.self, forKey: .areaSize)
        isEditing = try container.decodeIfPresent(Bool.self, forKey: .isEditing)
        textPosition = try container.decodeIfPresent(CGPoint.self, forKey: .textPosition)
    }
}

extension VectorShape {

    var isEvenOddCompoundPath: Bool {
        return isCompoundPath && path.fillRule.cgPathFillRule == .evenOdd
    }

    var isWindingLoopingPath: Bool {
        return isCompoundPath && path.fillRule.cgPathFillRule == .winding
    }

    var clipFillRule: CGPathFillRule {
        if isCompoundPath {
            return .evenOdd
        }
        return path.fillRule.cgPathFillRule
    }

    var isTrueCompoundPath: Bool {
        return isEvenOddCompoundPath
    }

    var isTrueLoopingPath: Bool {
        return isWindingLoopingPath
    }

    static func rectangle(at origin: CGPoint, size: CGSize) -> VectorShape {
        let rect = CGRect(origin: origin, size: size)
        let path = VectorPath(elements: [
            .move(to: VectorPoint(rect.minX, rect.minY)),
            .line(to: VectorPoint(rect.maxX, rect.minY)),
            .line(to: VectorPoint(rect.maxX, rect.maxY)),
            .line(to: VectorPoint(rect.minX, rect.maxY)),
            .close
        ], isClosed: true)
        return VectorShape(
            name: "Rectangle",
            path: path,
            geometricType: .rectangle,
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0),
            fillStyle: FillStyle(color: .white, opacity: 1.0)
        )
    }

    static func circle(center: CGPoint, radius: Double) -> VectorShape {
        let path = VectorPath(elements: [
            .move(to: VectorPoint(center.x + radius, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + radius * 0.552),
                   control2: VectorPoint(center.x + radius * 0.552, center.y + radius)),
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - radius * 0.552, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + radius * 0.552)),
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - radius * 0.552),
                   control2: VectorPoint(center.x - radius * 0.552, center.y - radius)),
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + radius * 0.552, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - radius * 0.552)),
            .close
        ], isClosed: true)
        return VectorShape(
            name: "Circle",
            path: path,
            geometricType: .circle,
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0),
            fillStyle: FillStyle(color: .white, opacity: 1.0)
        )
    }

    static func star(center: CGPoint, outerRadius: Double, innerRadius: Double, points: Int = 5) -> VectorShape {
        var elements: [PathElement] = []

        let angleStep = .pi / Double(points)
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        let path = VectorPath(elements: elements, isClosed: true)
        return VectorShape(name: "Star", path: path, geometricType: .star, strokeStyle: StrokeStyle(placement: .center), fillStyle: FillStyle(color: .white))
    }
}

struct VectorLayer: Hashable, Identifiable {
    var id: UUID
    var name: String
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    var blendMode: BlendMode
    var color: Color

    init(name: String, shapes: [VectorShape] = [], isVisible: Bool = true, isLocked: Bool = false, opacity: Double = 1.0, blendMode: BlendMode = .normal, color: Color = .blue) {
        self.id = UUID()
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
        self.color = color
    }

    mutating func addShape(_ shape: VectorShape) {
    }

    mutating func removeShape(_ shape: VectorShape) {
    }
}

extension VectorLayer: Codable {

    enum CodingKeys: String, CodingKey {
        case id, name, isVisible, isLocked, opacity, blendMode, color
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if !isVisible { try container.encode(isVisible, forKey: .isVisible) }
        if isLocked { try container.encode(isLocked, forKey: .isLocked) }
        if opacity != 1.0 { try container.encode(opacity, forKey: .opacity) }
        if blendMode != .normal { try container.encode(blendMode, forKey: .blendMode) }
        try container.encode(color.description, forKey: .color)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        blendMode = try container.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
        if let colorString = try container.decodeIfPresent(String.self, forKey: .color) {
            self.color = Self.parseColor(from: colorString)
        } else {
            self.color = .blue
        }
    }

    private static func parseColor(from string: String) -> Color {
        switch string.lowercased() {
        case let s where s.contains("gray"): return .gray
        case let s where s.contains("blue"): return .blue
        case let s where s.contains("green"): return .green
        case let s where s.contains("orange"): return .orange
        case let s where s.contains("purple"): return .purple
        case let s where s.contains("red"): return .red
        case let s where s.contains("pink"): return .pink
        case let s where s.contains("yellow"): return .yellow
        case let s where s.contains("cyan"): return .cyan
        default: return .blue
        }
    }
}

enum DraggableItem: Codable, Transferable {
    case vectorObject(DraggableVectorObject)
    case layer(DraggableLayer)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .draggableItem)
    }
}

struct DraggableVectorObject: Codable, Transferable {

    enum ObjectType: String, Codable {
        case shape = "shape"
        case text = "text"
    }
    let objectType: ObjectType
    let objectId: UUID
    let sourceLayerIndex: Int

    init(objectType: ObjectType, objectId: UUID, sourceLayerIndex: Int) {
        self.objectType = objectType
        self.objectId = objectId
        self.sourceLayerIndex = sourceLayerIndex
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .draggableVectorObject)
    }
}

struct DraggableLayer: Codable, Transferable {
    let layerIndex: Int
    let layerId: UUID

    init(layerIndex: Int, layerId: UUID) {
        self.layerIndex = layerIndex
        self.layerId = layerId
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .draggableLayer)
    }
}

extension UTType {

    static var inkpen: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.document")
    }

    static var inkpenSVG: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.svg")
    }

    static var inkpenPDF: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.pdf")
    }

    static var draggableVectorObject: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.draggableVectorObject")
    }

    static var draggableLayer: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.draggableLayer")
    }

    static var draggableItem: UTType {
        UTType(exportedAs: "io.logos.logos-inkpen-io.draggableItem")
    }
}
