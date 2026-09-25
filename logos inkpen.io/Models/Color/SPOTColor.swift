import SwiftUI

struct SPOTColor: Codable, Hashable {
    var number: String
    var name: String
    var rgbEquivalent: RGBColor
    var cmykEquivalent: CMYKColor
    var hsbEquivalent: HSBColorModel
    var alpha: Double

    var color: Color {
        return ColorManager.shared.makeColor(r: rgbEquivalent.red, g: rgbEquivalent.green, b: rgbEquivalent.blue, a: alpha, source: ColorManager.shared.sRGBCG)
    }
}
