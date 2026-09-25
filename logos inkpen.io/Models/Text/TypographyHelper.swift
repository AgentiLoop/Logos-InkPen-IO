import Foundation

extension TypographyProperties {

    var isItalic: Bool {
        guard let variant = fontVariant else { return false }
        let lowercased = variant.lowercased()
        return lowercased.contains("italic") || lowercased.contains("oblique")
    }

    var svgFontStyle: String? {
        return isItalic ? "italic" : nil
    }
}
