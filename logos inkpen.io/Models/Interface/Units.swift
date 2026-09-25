import SwiftUI
import AppKit

enum MeasurementUnit: String, CaseIterable, Codable {
    case inches = "Inches"
    case centimeters = "cm"
    case millimeters = "mm"
    case points = "Points"
    case pixels = "Pixels"
    case picas = "Picas"

    var abbreviation: String {
        switch self {
        case .inches: return "in"
        case .centimeters: return "cm"
        case .millimeters: return "mm"
        case .points: return "pt"
        case .pixels: return "px"
        case .picas: return "pc"
        }
    }

    var pointsPerUnit: Double {
        switch self {
        case .inches: return 72.0
        case .centimeters: return 28.346
        case .millimeters: return 2.835
        case .points: return 1.0
        case .pixels: return 1.0
        case .picas: return 12.0
        }
    }

    var defaultGridSpacing: Double {
        switch self {
        case .inches: return 0.125
        case .centimeters: return 0.5
        case .millimeters: return 1.0
        case .points: return 9.0
        case .pixels: return 10.0
        case .picas: return 1.0
        }
    }

    var defaultGridSpacingInPoints: Double {
        return toPoints(defaultGridSpacing)
    }

    var majorGridInterval: Int {
        switch self {
        case .inches: return 8
        case .centimeters: return 2
        case .millimeters: return 5
        case .points: return 8
        case .pixels: return 10
        case .picas: return 6
        }
    }

    func fromPoints(_ points: Double) -> Double {
        return points / pointsPerUnit
    }

    func toPoints(_ value: Double) -> Double {
        return value * pointsPerUnit
    }

    func format(_ value: Double) -> String {
        return String(format: "%.3f", value)
    }
}

enum ZoomMode: Equatable {
    case zoomIn
    case zoomOut
    case fitToPage
    case actualSize
    case custom(CGPoint)
}

struct ZoomRequest: Equatable {
    let targetZoom: CGFloat
    let mode: ZoomMode

    init(targetZoom: CGFloat, mode: ZoomMode) {
        self.targetZoom = targetZoom
        self.mode = mode
    }
}
