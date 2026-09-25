import SwiftUI

struct ColorDefaults: Codable {
    var fillColor: VectorColor
    var strokeColor: VectorColor
    var fillOpacity: Double
    var strokeOpacity: Double
    var strokeWidth: Double
    var rgbSwatches: [VectorColor]
    var cmykSwatches: [VectorColor]
    var hsbSwatches: [VectorColor]

    init() {
        self.fillColor = ColorManager.defaultBlue
        self.strokeColor = ColorManager.defaultRed
        self.fillOpacity = 1.0
        self.strokeOpacity = 1.0
        self.strokeWidth = 2.0
        self.rgbSwatches = Self.createDefaultRGBSwatches()
        self.cmykSwatches = Self.createDefaultCMYKSwatches()
        self.hsbSwatches = Self.createDefaultHSBSwatches()
        loadFromUserDefaults()
    }
    private static let userDefaultsKey = "logosinkpen-colorsv2"

    mutating func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),

              let dict = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return
        }
        if let fillData = dict["fill"],

           let color = try? JSONDecoder().decode(VectorColor.self, from: fillData) {
            if color != .black {
                fillColor = color
            }
        }
        if let strokeData = dict["stroke"],

           let color = try? JSONDecoder().decode(VectorColor.self, from: strokeData) {
            strokeColor = color
        }
        if let fillOpData = dict["fillOp"],

           let value = try? JSONDecoder().decode(Double.self, from: fillOpData) {
            fillOpacity = value
        }
        if let strokeOpData = dict["strokeOp"],

           let value = try? JSONDecoder().decode(Double.self, from: strokeOpData) {
            strokeOpacity = value
        }
        if let strokeWData = dict["strokeW"],

           let value = try? JSONDecoder().decode(Double.self, from: strokeWData) {
            strokeWidth = value
        }
        if let rgbData = dict["rgb"],

           let swatches = try? JSONDecoder().decode([VectorColor].self, from: rgbData) {
            rgbSwatches = swatches.count == 40 ? swatches : Self.createDefaultRGBSwatches()
        }
        if let cmykData = dict["cmyk"],

           let swatches = try? JSONDecoder().decode([VectorColor].self, from: cmykData) {
            cmykSwatches = swatches.count == 40 ? swatches : Self.createDefaultCMYKSwatches()
        }
        if let hsbData = dict["hsb"],

           let swatches = try? JSONDecoder().decode([VectorColor].self, from: hsbData) {
            hsbSwatches = swatches.count == 40 ? swatches : Self.createDefaultHSBSwatches()
        }
    }

    static func createDefaultRGBSwatches() -> [VectorColor] {
        var colors: [VectorColor] = []
        colors.append(.black)
        colors.append(.white)
        colors.append(.clear)
        colors.append(ColorManager.defaultBlue)
        colors.append(ColorManager.defaultRed)
        colors.append(.rgb(RGBColor(red: 0.5, green: 0, blue: 0)))
        colors.append(.rgb(RGBColor(red: 1, green: 0.8, blue: 0.8)))
        colors.append(.rgb(RGBColor(red: 1, green: 0.5, blue: 0)))
        colors.append(.rgb(RGBColor(red: 0.8, green: 0.5, blue: 0.2)))
        colors.append(.rgb(RGBColor(red: 1, green: 0.75, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.25, blue: 0)))
        colors.append(.rgb(RGBColor(red: 0.3, green: 0.2, blue: 0.1)))
        colors.append(.rgb(RGBColor(red: 0.6, green: 0.4, blue: 0.2)))
        colors.append(.rgb(RGBColor(red: 1, green: 0.9, blue: 0.7)))
        colors.append(.rgb(RGBColor(red: 1, green: 1, blue: 0)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.5, blue: 0)))
        colors.append(.rgb(RGBColor(red: 1, green: 1, blue: 0.8)))
        colors.append(.rgb(RGBColor(red: 0.9, green: 1, blue: 0.7)))
        colors.append(.rgb(RGBColor(red: 0.6, green: 0.8, blue: 0.4)))
        colors.append(.rgb(RGBColor(red: 0, green: 1, blue: 0)))
        colors.append(.rgb(RGBColor(red: 0, green: 0.5, blue: 0)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 1, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.8, green: 1, blue: 0.8)))
        colors.append(.rgb(RGBColor(red: 0, green: 0.5, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.7, green: 1, blue: 0.9)))
        colors.append(.rgb(RGBColor(red: 0, green: 1, blue: 1)))
        colors.append(.rgb(RGBColor(red: 0.7, green: 0.9, blue: 1)))
        colors.append(.rgb(RGBColor(red: 0.4, green: 0.6, blue: 0.8)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.5, blue: 1)))
        colors.append(.rgb(RGBColor(red: 0.8, green: 0.8, blue: 1)))
        colors.append(.rgb(RGBColor(red: 0, green: 0, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 0, blue: 1)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 0, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.9, green: 0.7, blue: 1)))
        colors.append(.rgb(RGBColor(red: 1, green: 0.5, blue: 1)))
        colors.append(.rgb(RGBColor(red: 1, green: 0.7, blue: 0.9)))
        colors.append(.rgb(RGBColor(red: 1, green: 0, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.25, green: 0.25, blue: 0.25)))
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5)))
        colors.append(.rgb(RGBColor(red: 0.75, green: 0.75, blue: 0.75)))
        return Array(colors.prefix(40))
    }

    static func createDefaultCMYKSwatches() -> [VectorColor] {
        var colors: [VectorColor] = []
        colors.append(.black)
        colors.append(.white)
        colors.append(.clear)
        colors.append(ColorManager.defaultBlue)
        for c in stride(from: 0, through: 1, by: 0.25) {
            for m in stride(from: 0, through: 1, by: 0.5) {
                for y in stride(from: 0, through: 1, by: 0.5) {
                    if colors.count < 40 {
                        colors.append(.cmyk(CMYKColor(cyan: c, magenta: m, yellow: y, black: 0)))
                    }
                }
            }
        }
        for k in stride(from: 0.2, through: 0.8, by: 0.2) {
            if colors.count < 40 {
                colors.append(.cmyk(CMYKColor(cyan: 0.5, magenta: 0.5, yellow: 0, black: k)))
            }
        }
        return Array(colors.prefix(40))
    }

    static func createDefaultHSBSwatches() -> [VectorColor] {
        var colors: [VectorColor] = []
        colors.append(.black)
        colors.append(.white)
        colors.append(.clear)
        colors.append(ColorManager.defaultBlue)
        for hue in stride(from: 0, to: 360, by: 30.0) {
            if colors.count < 40 {
                colors.append(.hsb(HSBColorModel(hue: hue, saturation: 1, brightness: 1)))
            }
        }
        for hue in stride(from: 0, to: 360, by: 30.0) {
            if colors.count < 40 {
                colors.append(.hsb(HSBColorModel(hue: hue, saturation: 0.5, brightness: 1)))
            }
        }
        for hue in stride(from: 0, to: 360, by: 30.0) {
            if colors.count < 40 {
                colors.append(.hsb(HSBColorModel(hue: hue, saturation: 1, brightness: 0.5)))
            }
        }
        return Array(colors.prefix(40))
    }

    func saveToUserDefaults() {
        var dict: [String: Data] = [:]
        if let fillData = try? JSONEncoder().encode(fillColor) {
            dict["fill"] = fillData
        }
        if let strokeData = try? JSONEncoder().encode(strokeColor) {
            dict["stroke"] = strokeData
        }
        if let fillOpData = try? JSONEncoder().encode(fillOpacity) {
            dict["fillOp"] = fillOpData
        }
        if let strokeOpData = try? JSONEncoder().encode(strokeOpacity) {
            dict["strokeOp"] = strokeOpData
        }
        if let strokeWData = try? JSONEncoder().encode(strokeWidth) {
            dict["strokeW"] = strokeWData
        }
        if let rgbData = try? JSONEncoder().encode(rgbSwatches) {
            dict["rgb"] = rgbData
        }
        if let cmykData = try? JSONEncoder().encode(cmykSwatches) {
            dict["cmyk"] = cmykData
        }
        if let hsbData = try? JSONEncoder().encode(hsbSwatches) {
            dict["hsb"] = hsbData
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
}
