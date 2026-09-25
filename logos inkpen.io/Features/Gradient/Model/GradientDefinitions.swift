import SwiftUI

struct GradientStop: Codable, Hashable, Identifiable {
    var id: UUID
    var position: Double
    var color: VectorColor
    var opacity: Double

    init(position: Double, color: VectorColor, opacity: Double = 1.0, id: UUID = UUID()) {
        self.id = id
        self.position = max(0.0, min(1.0, position))
        self.color = color
        self.opacity = max(0.0, min(1.0, opacity))
    }

    private enum CodingKeys: String, CodingKey {
        case id, position, color, opacity
    }
}

enum GradientSpreadMethod: String, Codable, CaseIterable {
    case pad = "pad"
    case reflect = "reflect"
    case `repeat` = "repeat"
}

enum GradientUnits: String, Codable {
    case objectBoundingBox = "objectBoundingBox"
    case userSpaceOnUse = "userSpaceOnUse"
}

struct LinearGradient: Codable, Hashable, Identifiable {
    var id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var stops: [GradientStop]
    var spreadMethod: GradientSpreadMethod = .pad
    var units: GradientUnits = .objectBoundingBox
    var originPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var scale: Double = 1.0
    var scaleX: Double = 1.0
    var scaleY: Double = 1.0
    var storedAngle: Double = 0.0

    init(startPoint: CGPoint, endPoint: CGPoint, stops: [GradientStop], spreadMethod: GradientSpreadMethod = .pad, units: GradientUnits = .objectBoundingBox, id: UUID = UUID()) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.stops = stops.sorted { $0.position < $1.position }
        self.spreadMethod = spreadMethod
        self.units = units
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let radians = atan2(deltaY, deltaX)
        self.storedAngle = radians * 180.0 / .pi
    }

    private enum CodingKeys: String, CodingKey {
        case id, startPoint, endPoint, stops, spreadMethod, units
        case originPoint, scaleX, scaleY, storedAngle, scale
    }

    var angle: Double {
        get {
            return storedAngle
        }
        set {
            setAngle(newValue)
        }
    }

    mutating func setAngle(_ degrees: Double) {
        storedAngle = degrees
        let radians = degrees * .pi / 180.0

        var centerX = originPoint.x
        var centerY = originPoint.y
        if units == .objectBoundingBox &&
           startPoint.x >= 0 && startPoint.x <= 1 && startPoint.y >= 0 && startPoint.y <= 1 &&
           endPoint.x >= 0 && endPoint.x <= 1 && endPoint.y >= 0 && endPoint.y <= 1 {
            centerX = (startPoint.x + endPoint.x) / 2.0
            centerY = (startPoint.y + endPoint.y) / 2.0
        }
        let currentLength = endPoint.distance(to: startPoint)
        let halfLength = currentLength > 0 ? currentLength / 2.0 : (units == .objectBoundingBox ? 0.25 : 50.0)
        let deltaX = cos(radians) * halfLength
        let deltaY = sin(radians) * halfLength
        startPoint = CGPoint(x: centerX - deltaX, y: centerY - deltaY)
        endPoint = CGPoint(x: centerX + deltaX, y: centerY + deltaY)
        if units == .objectBoundingBox {
            startPoint.x = max(0, min(1, startPoint.x))
            startPoint.y = max(0, min(1, startPoint.y))
            endPoint.x = max(0, min(1, endPoint.x))
            endPoint.y = max(0, min(1, endPoint.y))
        }
    }
}

struct RadialGradient: Codable, Hashable, Identifiable {
    var id: UUID
    var centerPoint: CGPoint
    var focalPoint: CGPoint?
    var radius: Double
    var stops: [GradientStop]
    var spreadMethod: GradientSpreadMethod = .pad
    var units: GradientUnits = .objectBoundingBox
    var originPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var scale: Double = 1.0
    var scaleX: Double = 1.0
    var scaleY: Double = 1.0
    var angle: Double = 0.0

    init(centerPoint: CGPoint, radius: Double, stops: [GradientStop], focalPoint: CGPoint? = nil, spreadMethod: GradientSpreadMethod = .pad, units: GradientUnits = .objectBoundingBox, id: UUID = UUID()) {
        self.id = id
        self.centerPoint = centerPoint
        self.radius = max(0.0, radius)
        self.stops = stops.sorted { $0.position < $1.position }
        self.focalPoint = focalPoint
        self.spreadMethod = spreadMethod
        self.units = units
    }

    private enum CodingKeys: String, CodingKey {
        case id, centerPoint, focalPoint, radius, stops, spreadMethod, units
        case originPoint, scaleX, scaleY, angle, scale
    }
}
