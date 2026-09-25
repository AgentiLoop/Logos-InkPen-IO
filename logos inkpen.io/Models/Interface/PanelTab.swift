import SwiftUI

enum PanelTab: String, CaseIterable {
    case layers = "Layer"
    case properties = "Paint"
    case gradient = "Grade"
    case color = "Ink"
    case pathOps = "Path"
    case font = "Font"

    var iconName: String {
        switch self {
        case .layers: return "square.stack"
        case .properties: return "paintbrush"
        case .gradient: return "circle.lefthalf.striped.horizontal"
        case .color: return "drop.fill"
        case .pathOps: return "square.grid.2x2"
        case .font: return "textformat"
        }
    }
}
