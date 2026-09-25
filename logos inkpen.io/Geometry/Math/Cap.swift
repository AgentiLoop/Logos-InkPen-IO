import SwiftUI

extension CGLineCap {

    var swiftUILineCap: SwiftUI.CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square

        @unknown default: return .butt
        }
    }
}

extension CGLineJoin {

    var swiftUILineJoin: SwiftUI.CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel

        @unknown default: return .miter
        }
    }
}
