import SwiftUI

enum ShearAnchor: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var displayName: String {
        return self.rawValue
    }
}
