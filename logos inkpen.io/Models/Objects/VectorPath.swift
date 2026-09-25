import SwiftUI
import simd

struct FillRule: Codable, Hashable {
    private let rule: String

    init(_ rule: CGPathFillRule) {
        switch rule {
        case .evenOdd:
            self.rule = "evenOdd"
        case .winding:
            self.rule = "winding"

        @unknown default:
            self.rule = "winding"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rule = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rule)
    }

    var cgPathFillRule: CGPathFillRule {
        switch rule {
        case "evenOdd":
            return .evenOdd
        case "winding":
            return .winding
        default:
            return .winding
        }
    }
    static let winding = FillRule(.winding)
    static let evenOdd = FillRule(.evenOdd)
}

struct VectorPoint: Codable, Hashable {
    internal var simdPoint: SIMD2<Double>

    var x: Double {
        get { simdPoint.x }
        set { simdPoint.x = newValue }
    }

    var y: Double {
        get { simdPoint.y }
        set { simdPoint.y = newValue }
    }

    init(_ x: Double, _ y: Double) {
        self.simdPoint = SIMD2(x, y)
    }

    init(_ point: CGPoint) {
        self.simdPoint = SIMD2(Double(point.x), Double(point.y))
    }

    init(simd: SIMD2<Double>) {
        self.simdPoint = simd
    }

    var cgPoint: CGPoint {
        CGPoint(x: simdPoint.x, y: simdPoint.y)
    }

    static func + (lhs: VectorPoint, rhs: VectorPoint) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint + rhs.simdPoint)
    }

    static func - (lhs: VectorPoint, rhs: VectorPoint) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint - rhs.simdPoint)
    }

    static func * (lhs: VectorPoint, scalar: Double) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint * scalar)
    }

    static func / (lhs: VectorPoint, scalar: Double) -> VectorPoint {
        VectorPoint(simd: lhs.simdPoint / scalar)
    }

    enum CodingKeys: String, CodingKey {
        case x, y
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(simdPoint.x, forKey: .x)
        try container.encode(simdPoint.y, forKey: .y)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.simdPoint = SIMD2(x, y)
    }
}

struct BezierControlPoint: Codable, Hashable {
    var point: VectorPoint
    var inControl: VectorPoint?
    var outControl: VectorPoint?

    init(point: VectorPoint, inControl: VectorPoint? = nil, outControl: VectorPoint? = nil) {
        self.point = point
        self.inControl = inControl
        self.outControl = outControl
    }
}

enum PathElement: Codable, Hashable {
    case move(to: VectorPoint)
    case line(to: VectorPoint)
    case curve(to: VectorPoint, control1: VectorPoint, control2: VectorPoint)
    case quadCurve(to: VectorPoint, control: VectorPoint)
    case close

    var endpoint: VectorPoint? {
        switch self {
        case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
            return to
        case .close:
            return nil
        }
    }

    var endpointCGPoint: CGPoint? {
        endpoint?.cgPoint
    }
}

struct VectorPath: Codable, Hashable, Identifiable {
    var id: UUID
    var elements: [PathElement]
    var isClosed: Bool
    var fillRule: FillRule
    var pendingStartHandle: VectorPoint?
    var pendingEndHandle: VectorPoint?
    var bezierHandles: [String: BezierHandleInfo]?

    init(elements: [PathElement] = [], isClosed: Bool = false, fillRule: CGPathFillRule = .winding, pendingStartHandle: VectorPoint? = nil, pendingEndHandle: VectorPoint? = nil, bezierHandles: [String: BezierHandleInfo]? = nil) {
        self.id = UUID()
        self.elements = elements
        self.isClosed = isClosed
        self.fillRule = FillRule(fillRule)
        self.pendingStartHandle = pendingStartHandle
        self.pendingEndHandle = pendingEndHandle
        self.bezierHandles = bezierHandles
    }

    enum CodingKeys: String, CodingKey {
        case id, elements, isClosed, fillRule, pendingStartHandle, pendingEndHandle, bezierHandles
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if !elements.isEmpty {
            try container.encode(elements, forKey: .elements)
        }
        if isClosed {
            try container.encode(isClosed, forKey: .isClosed)
        }
        try container.encode(fillRule, forKey: .fillRule)
        if let pendingStartHandle = pendingStartHandle {
            try container.encode(pendingStartHandle, forKey: .pendingStartHandle)
        }
        if let pendingEndHandle = pendingEndHandle {
            try container.encode(pendingEndHandle, forKey: .pendingEndHandle)
        }
        if let bezierHandles = bezierHandles, !bezierHandles.isEmpty {
            try container.encode(bezierHandles, forKey: .bezierHandles)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        elements = try container.decodeIfPresent([PathElement].self, forKey: .elements) ?? []
        isClosed = try container.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
        fillRule = try container.decode(FillRule.self, forKey: .fillRule)
        pendingStartHandle = try container.decodeIfPresent(VectorPoint.self, forKey: .pendingStartHandle)
        pendingEndHandle = try container.decodeIfPresent(VectorPoint.self, forKey: .pendingEndHandle)
        bezierHandles = try container.decodeIfPresent([String: BezierHandleInfo].self, forKey: .bezierHandles)
    }

    init(cgPath: CGPath, fillRule: CGPathFillRule = .winding) {
        self.id = UUID()
        self.elements = []
        self.isClosed = false
        self.fillRule = FillRule(fillRule)
        self.pendingStartHandle = nil
        self.pendingEndHandle = nil
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(point.x, point.y)))
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(point.x, point.y)))
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(point.x, point.y),
                    control: VectorPoint(control.x, control.y)
                ))
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(point.x, point.y),
                    control1: VectorPoint(control1.x, control1.y),
                    control2: VectorPoint(control2.x, control2.y)
                ))
            case .closeSubpath:
                elements.append(.close)
                isClosed = true

            @unknown default:
                break
            }
        }
    }

    var cgPath: CGPath {
        let path = CGMutablePath()
        for element in elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                if !path.isEmpty {
                    path.closeSubpath()
                }
            }
        }
        if isClosed && !elements.contains(.close) && !path.isEmpty {
            path.closeSubpath()
        }
        return path
    }

    mutating func addElement(_ element: PathElement) {
        elements.append(element)
    }

    mutating func close() {
        if !isClosed {
            isClosed = true
            if !elements.contains(.close) {
                elements.append(.close)
            }
        }
    }
}

enum PathOperation: String, CaseIterable, Codable {
    case union = "Union"
    case intersect = "Intersect"
    case frontMinusBack = "Front Minus Back"
    case backMinusFront = "Back Minus Front"
    case exclude = "Exclude"

    var iconName: String {
        switch self {
        case .union: return "plus.circle"
        case .intersect: return "circle.circle"
        case .frontMinusBack: return "minus.circle"
        case .backMinusFront: return "minus.circle.fill"
        case .exclude: return "xmark.circle"
        }
    }
}
