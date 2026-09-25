import SwiftUI

struct AppleSystemColor: Codable, Hashable {
    var name: String
    var lightMode: RGBColor

    var color: Color {
        switch name {
        case "systemBlue": return Color(.systemBlue)
        case "systemRed": return Color(.systemRed)
        case "systemGreen": return Color(.systemGreen)
        case "systemYellow": return Color(.systemYellow)
        case "systemOrange": return Color(.systemOrange)
        case "systemPurple": return Color(.systemPurple)
        case "systemPink": return Color(.systemPink)
        case "systemTeal": return Color(.systemTeal)
        case "systemIndigo": return Color(.systemIndigo)
        case "systemBrown": return Color(.systemBrown)
        case "systemGray": return Color(.systemGray)
        case "systemGray2": return lightMode.color
        case "systemGray3": return lightMode.color
        case "systemGray4": return lightMode.color
        case "systemGray5": return lightMode.color
        case "systemGray6": return lightMode.color
        case "label": return Color(.labelColor)
        case "secondaryLabel": return Color(.secondaryLabelColor)
        case "tertiaryLabel": return Color(.tertiaryLabelColor)
        case "quaternaryLabel": return Color(.quaternaryLabelColor)
        case "link": return Color(.linkColor)
        case "placeholderText": return Color(.placeholderTextColor)
        case "separator": return Color(.separatorColor)
        case "opaqueSeparator": return Color(.separatorColor)
        case "systemBackground": return Color(.windowBackgroundColor)
        case "secondarySystemBackground": return Color(.controlBackgroundColor)
        case "tertiarySystemBackground": return Color(.controlBackgroundColor)
        case "systemGroupedBackground": return Color(.windowBackgroundColor)
        case "secondarySystemGroupedBackground": return Color(.controlBackgroundColor)
        case "tertiarySystemGroupedBackground": return Color(.controlBackgroundColor)
        case "systemFill": return Color(.controlBackgroundColor)
        case "secondarySystemFill": return Color(.controlBackgroundColor)
        case "tertiarySystemFill": return Color(.controlBackgroundColor)
        case "quaternarySystemFill": return Color(.controlBackgroundColor)
        default: return lightMode.color
        }
    }

    var rgbEquivalent: RGBColor {
        return lightMode
    }
}
