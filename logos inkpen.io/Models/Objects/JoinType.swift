import SwiftUI

enum JoinType: CaseIterable {
    case round
    case miter
    case bevel
    case square

    var displayName: String {
        switch self {
        case .round: return "Round"
        case .miter: return "Miter"
        case .bevel: return "Bevel"
        case .square: return "Square"
        }
    }

    var iconName: String {
        switch self {
        case .round: return "circle"
        case .miter: return "diamond"
        case .bevel: return "octagon"
        case .square: return "square"
        }
    }

    var description: String {
        switch self {
        case .round: return "Rounded corners (smooth curves)"
        case .miter: return "Sharp pointed corners"
        case .bevel: return "Flat angled corners"
        case .square: return "Square corners"
        }
    }
}
