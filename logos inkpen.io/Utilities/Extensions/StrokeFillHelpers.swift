import SwiftUI
import AppKit

func formatNumberForDisplay(_ value: Double, maxDecimals: Int = 2) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", value)
    }
    return String(format: "%.\(maxDecimals)f", value)
}

extension CGLineJoin {

    var iconName: String {
        switch self {
        case .miter: return "triangle"
        case .round: return "circle"
        case .bevel: return "hexagon"

        @unknown default: return "triangle"
        }
    }

    var displayName: String {
        switch self {
        case .miter: return "Miter"
        case .round: return "Round"
        case .bevel: return "Bevel"

        @unknown default: return "Miter"
        }
    }

    var description: String {
        switch self {
        case .miter: return "Sharp pointed corners (Professional default)"
        case .round: return "Smooth rounded corners"
        case .bevel: return "Chamfered corners (cuts off sharp points)"

        @unknown default: return "Sharp pointed corners"
        }
    }
}

extension CGLineCap {

    var iconName: String {
        switch self {
        case .butt: return "minus"
        case .round: return "circle"
        case .square: return "square"

        @unknown default: return "minus"
        }
    }

    var displayName: String {
        switch self {
        case .butt: return "Butt"
        case .round: return "Round"
        case .square: return "Square"

        @unknown default: return "Butt"
        }
    }

    var description: String {
        switch self {
        case .butt: return "Square end aligned with path endpoint"
        case .round: return "Rounded end extending beyond path endpoint"
        case .square: return "Square end extending beyond path endpoint"

        @unknown default: return "Square end aligned with path endpoint"
        }
    }
}
