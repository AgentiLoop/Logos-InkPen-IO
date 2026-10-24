import SwiftUI

enum VectorColor: Hashable {
    case rgb(RGBColor)
    case cmyk(CMYKColor)
    case hsb(HSBColorModel)
    case pantone(PantoneLibraryColor)
    case spot(SPOTColor)
    case appleSystem(AppleSystemColor)
    case gradient(VectorGradient)
    case clear
    case black
    case white

    var color: Color {
        switch self {
        case .rgb(let rgb):
            return rgb.color
        case .cmyk(let cmyk):
            return cmyk.color
        case .hsb(let hsb):
            return hsb.color
        case .pantone(let pantone):
            return pantone.color
        case .spot(let spot):
            return spot.color
        case .appleSystem(let systemColor):
            return systemColor.color
        case .gradient(let gradient):
            return gradient.stops.first?.color.color ?? Color.black
        case .clear:
            return Color.clear
        case .black:
            return Color.black
        case .white:
            return Color.white
        }
    }

    var cgColor: CGColor {
        switch self {
        case .rgb(let rgb):
            return rgb.cgColor
        case .cmyk(let cmyk):
            return cmyk.rgbColor.cgColor
        case .hsb(let hsb):
            return hsb.rgbColor.cgColor
        case .pantone(let pantone):
            return ColorManager.shared.convert(pantone.rgbEquivalent.cgColor, to: ColorManager.shared.displayP3CG)
        case .spot(let spot):
            return ColorManager.shared.convert(spot.rgbEquivalent.cgColor, to: ColorManager.shared.displayP3CG)
        case .appleSystem(let systemColor):
            return systemColor.rgbEquivalent.cgColor
        case .gradient(let gradient):
            if let firstStop = gradient.stops.first {
                return firstStop.color.cgColor
            }
            let comps: [CGFloat] = [0, 0, 0, 1]
            return CGColor(colorSpace: ColorManager.shared.workingCGColorSpace, components: comps) ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .clear:
            let comps: [CGFloat] = [0, 0, 0, 0]
            return CGColor(colorSpace: ColorManager.shared.workingCGColorSpace, components: comps) ?? CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .black:
            let comps: [CGFloat] = [0, 0, 0, 1]
            return CGColor(colorSpace: ColorManager.shared.workingCGColorSpace, components: comps) ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .white:
            let comps: [CGFloat] = [1, 1, 1, 1]
            return CGColor(colorSpace: ColorManager.shared.workingCGColorSpace, components: comps) ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }
    static let basicColors: [VectorColor] = [
        .black, .white, .clear
    ]

    var svgColor: String {
        let useDisplayP3 = AppState.shared.exportColorSpace == .displayP3
        switch self {
        case .clear:
            return "none"
        case .black:
            return "#000000"
        case .white:
            return "#FFFFFF"
        case .rgb(let rgbColor):
            if useDisplayP3 {
                return Self.svgDisplayP3Color(rgbColor)
            } else {
                return ColorManager.shared.cgColorToSRGBHex(rgbColor.cgColor)
            }
        case .cmyk(let cmykColor):
            if useDisplayP3 {
                return Self.svgDisplayP3Color(cmykColor.rgbColor)
            } else {
                return ColorManager.shared.cgColorToSRGBHex(cmykColor.rgbColor.cgColor)
            }
        case .hsb(let hsbColor):
            if useDisplayP3 {
                return Self.svgDisplayP3Color(hsbColor.rgbColor)
            } else {
                return ColorManager.shared.cgColorToSRGBHex(hsbColor.rgbColor.cgColor)
            }
        case .pantone(let pantoneColor):
            if useDisplayP3 {
                return Self.svgDisplayP3Color(pantoneColor.rgbEquivalent)
            } else {
                return ColorManager.shared.cgColorToSRGBHex(pantoneColor.rgbEquivalent.cgColor)
            }
        case .spot(let spotColor):
            if useDisplayP3 {
                return Self.svgDisplayP3Color(spotColor.rgbEquivalent)
            } else {
                return ColorManager.shared.cgColorToSRGBHex(spotColor.rgbEquivalent.cgColor)
            }
        case .appleSystem(let systemColor):
            if useDisplayP3 {
                return Self.svgDisplayP3Color(systemColor.rgbEquivalent)
            } else {
                return ColorManager.shared.cgColorToSRGBHex(systemColor.rgbEquivalent.cgColor)
            }
        case .gradient(let gradient):
            return gradient.stops.first?.color.svgColor ?? "#000000"
        }
    }

    /// SVG hex is sRGB, so a working-space color inside the sRGB gamut is written as its sRGB hex;
    /// a wide-gamut color that sRGB cannot hold is written as CSS `color(display-p3 r g b)`.
    static func svgDisplayP3Color(_ rgbColor: RGBColor) -> String {
        let cgColor = rgbColor.cgColor
        let tolerance: CGFloat = 0.5 / 255.0
        if let extendedSRGB = CGColorSpace(name: CGColorSpace.extendedSRGB),
           let comps = ColorManager.shared.convert(cgColor, to: extendedSRGB).components, comps.count >= 3,
           comps[0..<3].allSatisfy({ $0 >= -tolerance && $0 <= 1 + tolerance }) {
            return ColorManager.shared.cgColorToSRGBHex(cgColor)
        }
        let p3 = ColorManager.shared.convert(cgColor, to: ColorManager.shared.displayP3CG).components ?? []
        guard p3.count >= 3 else { return ColorManager.shared.cgColorToSRGBHex(cgColor) }
        let clamped = p3[0..<3].map { min(1, max(0, Double($0))) }
        return String(format: "color(display-p3 %.4f %.4f %.4f)", clamped[0], clamped[1], clamped[2])
    }

    private func hsbToRgb(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let hue = h * 360
        let saturation = s
        let brightness = b
        let c = brightness * saturation
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r, g, b): (Double, Double, Double)
        switch Int(hue) / 60 {
        case 0:
            (r, g, b) = (c, x, 0)
        case 1:
            (r, g, b) = (x, c, 0)
        case 2:
            (r, g, b) = (0, c, x)
        case 3:
            (r, g, b) = (0, x, c)
        case 4:
            (r, g, b) = (x, 0, c)
        case 5:
            (r, g, b) = (c, 0, x)
        default:
            (r, g, b) = (0, 0, 0)
        }
        return (r + m, g + m, b + m)
    }
}

extension VectorColor: Codable {

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .rgb(let color):
            try container.encode(["rgb": color])
        case .cmyk(let color):
            try container.encode(["cmyk": color])
        case .hsb(let color):
            try container.encode(["hsb": color])
        case .pantone(let color):
            try container.encode(["pantone": color])
        case .spot(let color):
            try container.encode(["spot": color])
        case .appleSystem(let color):
            try container.encode(["appleSystem": color])
        case .gradient(let gradient):
            try container.encode(["gradient": gradient])
        case .clear:
            try container.encode("clear")
        case .black:
            try container.encode("black")
        case .white:
            try container.encode("white")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let simpleColor = try? container.decode(String.self) {
            switch simpleColor {
            case "black":
                self = .black
            case "white":
                self = .white
            case "clear":
                self = .clear
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown color string: \(simpleColor)"
                ))
            }
        } else {
            let dict = try container.decode([String: AnyCodable].self)
            guard let (key, value) = dict.first, dict.count == 1 else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "VectorColor should have exactly one color type"
                ))
            }
            switch key {
            case "rgb":
                let color = try value.decode(RGBColor.self)
                self = .rgb(color)
            case "cmyk":
                let color = try value.decode(CMYKColor.self)
                self = .cmyk(color)
            case "hsb":
                let color = try value.decode(HSBColorModel.self)
                self = .hsb(color)
            case "pantone":
                let color = try value.decode(PantoneLibraryColor.self)
                self = .pantone(color)
            case "spot":
                let color = try value.decode(SPOTColor.self)
                self = .spot(color)
            case "appleSystem":
                let color = try value.decode(AppleSystemColor.self)
                self = .appleSystem(color)
            case "gradient":
                let gradient = try value.decode(VectorGradient.self)
                self = .gradient(gradient)
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown color type: \(key)"
                ))
            }
        }
    }
}

private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable(wrapping: $0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable(wrapping: $0) })
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        default:
            try container.encodeNil()
        }
    }

    init(wrapping value: Any) {
        self.value = value
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(type, from: data)
    }
}
