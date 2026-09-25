import SwiftUI

class ColorManagement {

    static func rgbToCMYK(_ rgb: RGBColor) -> CMYKColor {
        let r = rgb.red
        let g = rgb.green
        let b = rgb.blue
        let k = 1 - max(r, max(g, b))
        if k >= 1.0 {
            return CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1, alpha: rgb.alpha)
        }
        let c = (1 - r - k) / (1 - k)
        let m = (1 - g - k) / (1 - k)
        let y = (1 - b - k) / (1 - k)
        return CMYKColor(cyan: c, magenta: m, yellow: y, black: k, alpha: rgb.alpha)
    }

    static func loadPantoneColors() -> [PantoneLibraryColor] {
        PantoneLibrary.shared.ensureLoaded()
        return PantoneLibrary.shared.allColors
    }
}
