import SwiftUI
import Combine

class InkPenUIColors: ObservableObject {
    static let shared = InkPenUIColors()

    private init() {}

    var windowBackground: Color {
        Color.platformWindowBackground
    }

    var controlBackground: Color {
        Color.platformControlBackground
    }

    var lightGrayBackground: Color {
        Color.gray.opacity(0.1)
    }

    var semiTransparentControlBackground: Color {
        Color.platformControlBackground.opacity(0.5)
    }

    var primaryBlue: Color {
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 1.0, source: ColorManager.shared.displayP3CG)
    }

    var lightBlueBackground: Color {
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 0.1, source: ColorManager.shared.displayP3CG)
    }

    var mediumBlueBackground: Color {
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 0.6, source: ColorManager.shared.displayP3CG)
    }

    var veryLightBlueBackground: Color {
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 0.05, source: ColorManager.shared.displayP3CG)
    }

    var toolSelectionBlue: Color {
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 1.0, source: ColorManager.shared.displayP3CG)
    }

    var standardBorder: Color {
        Color.gray
    }

    var lightGrayBorder: Color {
        Color.gray.opacity(0.3)
    }

    var primaryText: Color {
        Color.primary
    }

    var secondaryText: Color {
        Color.secondary
    }

    var darkOverlay: Color {
        Color.black.opacity(0.8)
    }

    var lightSuccessBackground: Color {
        Color.green.opacity(0.1)
    }

    var errorColor: Color {
        Color.red
    }

    var lightErrorBackground2: Color {
        Color.red.opacity(0.2)
    }

    var clear: Color {
        Color.clear
    }

    var white: Color {
        Color.white
    }

    var toolOrange: Color {
        ColorManager.shared.makeColor(r: 1.0, g: 0.584, b: 0.0, a: 1.0, source: ColorManager.shared.displayP3CG)
    }

    var textBackground: Color {
        Color.platformTextBackground
    }

    func color(_ baseColor: Color, opacity: Double) -> Color {
        baseColor.opacity(opacity)
    }

    func systemColor(_ nsColor: PlatformColor, opacity: Double = 1.0) -> Color {
        Color(nsColor).opacity(opacity)
    }
}

extension Color {

    static var ui: InkPenUIColors {
        InkPenUIColors.shared
    }
}
