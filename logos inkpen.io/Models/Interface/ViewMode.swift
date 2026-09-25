import SwiftUI

enum ViewMode: String, CaseIterable, Codable {
    case color = "Color View"
    case keyline = "Keyline View"

    var iconName: String {
        switch self {
        case .color: return "paintbrush.fill"
        case .keyline: return "square.dashed"
        }
    }

    var description: String {
        switch self {
        case .color: return "Show full artwork with fills and strokes"
        case .keyline: return "Show outlines only (keylines)"
        }
    }
}
