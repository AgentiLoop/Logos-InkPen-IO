import SwiftUI

extension Color {

    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        #if canImport(AppKit)
        let platformColor = PlatformColor(self)
        if let converted = platformColor.usingColorSpace(.sRGB) ?? platformColor.usingColorSpace(.deviceRGB) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            converted.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b), Double(a))
        }
        let cg = platformColor.cgColor
        #elseif canImport(UIKit)
        let cg = PlatformColor(self).cgColor
        #else
        let cg = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        #endif
        let rgba = cg.rgbaComponents
        return (Double(rgba.r), Double(rgba.g), Double(rgba.b), Double(rgba.a))
    }
}
