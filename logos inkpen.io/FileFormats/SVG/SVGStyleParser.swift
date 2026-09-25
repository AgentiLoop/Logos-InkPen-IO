import SwiftUI

extension SVGParser {

    func parseStrokeStyle(_ attributes: [String: String]) -> StrokeStyle? {
        if let strokeWidth = attributes["stroke-width"] {
            let width = parseLength(strokeWidth) ?? 1.0
            if width == 0.0 {
                return nil
            }
        }
        let stroke = attributes["stroke"] ?? "none"
        guard stroke != "none" else { return nil }
        let width = parseLength(attributes["stroke-width"]) ?? 1.0
        let opacity = parseLength(attributes["stroke-opacity"]) ?? 1.0
        let lineCap = parseLineCap(attributes["stroke-linecap"])
        let lineJoin = parseLineJoin(attributes["stroke-linejoin"])
        let miterLimit = parseLength(attributes["stroke-miterlimit"]) ?? 10.0
        let dashPattern = parseDashArray(attributes["stroke-dasharray"])
        if stroke.hasPrefix("url(#") && stroke.hasSuffix(")") {
            let gradientId = String(stroke.dropFirst(5).dropLast(1))
            if let gradient = gradientDefinitions[gradientId] {
                return StrokeStyle(gradient: gradient, width: width, placement: .center, dashPattern: dashPattern, lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit, opacity: opacity)
            }
            Log.error("Gradient reference not found for stroke: \(gradientId)", category: .error)
            return StrokeStyle(color: .black, width: width, placement: .center, dashPattern: dashPattern, lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit, opacity: opacity)
        }
        let color = parseColor(stroke) ?? .black
        return StrokeStyle(color: color, width: width, placement: .center, dashPattern: dashPattern, lineCap: lineCap, lineJoin: lineJoin, miterLimit: miterLimit, opacity: opacity)
    }

    private func parseLineCap(_ value: String?) -> CGLineCap {
        switch value?.lowercased() {
        case "round": return .round
        case "square": return .square
        default: return .butt
        }
    }

    private func parseLineJoin(_ value: String?) -> CGLineJoin {
        switch value?.lowercased() {
        case "round": return .round
        case "bevel": return .bevel
        default: return .miter
        }
    }

    private func parseDashArray(_ value: String?) -> [Double] {
        guard let value = value, value != "none" else { return [] }
        return value
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    func parseFillStyle(_ attributes: [String: String]) -> FillStyle? {
        let fill = attributes["fill"] ?? "black"
        guard fill != "none" else { return nil }
        if fill.hasPrefix("url(#") && fill.hasSuffix(")") {
            let gradientId = String(fill.dropFirst(5).dropLast(1))
            if let gradient = gradientDefinitions[gradientId] {
                let opacity = parseLength(attributes["fill-opacity"]) ?? 1.0
                return FillStyle(gradient: gradient, opacity: opacity)
            }
            Log.error("❌ Gradient reference not found for fill: \(gradientId)", category: .error)
            return FillStyle(color: .black, opacity: parseLength(attributes["fill-opacity"]) ?? 1.0)
        }
        let color = parseColor(fill) ?? .black
        let opacity = parseLength(attributes["fill-opacity"]) ?? 1.0
        let fillRule = attributes["fill-rule"] ?? "nonzero"
        let fillStyle = FillStyle(color: color, opacity: opacity)
        if fillRule == "evenodd" {
        }
        return fillStyle
    }

    func parseColor(_ colorString: String) -> VectorColor? {
        let color = colorString.trimmingCharacters(in: .whitespaces)
        if color == "none" || color == "transparent" { return .clear }
        if color == "currentColor" { return .black }
        if color.hasPrefix("#") {
            let hex = String(color.dropFirst())
            if hex.count == 6 {
                let r = Double(Int(hex.prefix(2), radix: 16) ?? 0) / 255.0
                let g = Double(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
                let b = Double(Int(hex.suffix(2), radix: 16) ?? 0) / 255.0
                return .rgb(convertSRGBToP3(red: r, green: g, blue: b))
            } else if hex.count == 3 {
                let r = Double(Int(String(hex.prefix(1)), radix: 16) ?? 0) / 15.0
                let g = Double(Int(String(hex.dropFirst().prefix(1)), radix: 16) ?? 0) / 15.0
                let b = Double(Int(String(hex.suffix(1)), radix: 16) ?? 0) / 15.0
                return .rgb(convertSRGBToP3(red: r, green: g, blue: b))
            }
        } else if color.hasPrefix("rgb(") {
            let content = color.dropFirst(4).dropLast()
            let components = content.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if components.count >= 3 {
                return .rgb(convertSRGBToP3(red: components[0]/255.0, green: components[1]/255.0, blue: components[2]/255.0))
            }
        } else if color.hasPrefix("rgba(") {
            let content = color.dropFirst(5).dropLast()
            let components = content.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if components.count >= 4 {
                return .rgb(convertSRGBToP3(red: components[0]/255.0, green: components[1]/255.0, blue: components[2]/255.0, alpha: components[3]))
            }
        } else if color.hasPrefix("device-cmyk(") {
            let content = color.dropFirst(12).dropLast()
            let parts = content.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).compactMap { part -> Double? in
                let s = part.trimmingCharacters(in: .whitespaces)
                if s.hasSuffix("%"), let v = Double(s.dropLast()) { return v / 100.0 }
                return Double(s)
            }
            if parts.count >= 4 {
                let c = max(0, min(1, parts[0]))
                let m = max(0, min(1, parts[1]))
                let y = max(0, min(1, parts[2]))
                let k = max(0, min(1, parts[3]))
                let a = parts.count >= 5 ? max(0, min(1, parts[4])) : 1.0
                return .cmyk(CMYKColor(cyan: c, magenta: m, yellow: y, black: k, alpha: a))
            }
        } else if color.hasPrefix("spot(") {
            let name = String(color.dropFirst(5).dropLast()).trimmingCharacters(in: .whitespaces)
            let normalized = name.lowercased()
            PantoneLibrary.shared.ensureLoaded()
            if let pantone = PantoneLibrary.shared.allColors.first(where: {
                $0.pantone.lowercased() == normalized ||
                $0.name.lowercased() == normalized ||
                $0.name.lowercased() == "pantone \(normalized)"
            }) {
                return .pantone(pantone)
            }
        } else if let (r, g, b) = Self.svgNamedColors[color.lowercased()] {
            if color.lowercased() == "black" { return .black }
            if color.lowercased() == "white" { return .white }
            return .rgb(convertSRGBToP3(red: r, green: g, blue: b))
        }
        return nil
    }
    private static let svgNamedColors: [String: (Double, Double, Double)] = [
        "aliceblue": (240/255.0, 248/255.0, 255/255.0),
        "antiquewhite": (250/255.0, 235/255.0, 215/255.0),
        "aqua": (0, 255/255.0, 255/255.0),
        "aquamarine": (127/255.0, 255/255.0, 212/255.0),
        "azure": (240/255.0, 255/255.0, 255/255.0),
        "beige": (245/255.0, 245/255.0, 220/255.0),
        "bisque": (255/255.0, 228/255.0, 196/255.0),
        "black": (0, 0, 0),
        "blanchedalmond": (255/255.0, 235/255.0, 205/255.0),
        "blue": (0, 0, 1),
        "blueviolet": (138/255.0, 43/255.0, 226/255.0),
        "brown": (165/255.0, 42/255.0, 42/255.0),
        "burlywood": (222/255.0, 184/255.0, 135/255.0),
        "cadetblue": (95/255.0, 158/255.0, 160/255.0),
        "chartreuse": (127/255.0, 255/255.0, 0),
        "chocolate": (210/255.0, 105/255.0, 30/255.0),
        "coral": (255/255.0, 127/255.0, 80/255.0),
        "cornflowerblue": (100/255.0, 149/255.0, 237/255.0),
        "cornsilk": (255/255.0, 248/255.0, 220/255.0),
        "crimson": (220/255.0, 20/255.0, 60/255.0),
        "cyan": (0, 255/255.0, 255/255.0),
        "darkblue": (0, 0, 139/255.0),
        "darkcyan": (0, 139/255.0, 139/255.0),
        "darkgoldenrod": (184/255.0, 134/255.0, 11/255.0),
        "darkgray": (169/255.0, 169/255.0, 169/255.0),
        "darkgreen": (0, 100/255.0, 0),
        "darkgrey": (169/255.0, 169/255.0, 169/255.0),
        "darkkhaki": (189/255.0, 183/255.0, 107/255.0),
        "darkmagenta": (139/255.0, 0, 139/255.0),
        "darkolivegreen": (85/255.0, 107/255.0, 47/255.0),
        "darkorange": (255/255.0, 140/255.0, 0),
        "darkorchid": (153/255.0, 50/255.0, 204/255.0),
        "darkred": (139/255.0, 0, 0),
        "darksalmon": (233/255.0, 150/255.0, 122/255.0),
        "darkseagreen": (143/255.0, 188/255.0, 143/255.0),
        "darkslateblue": (72/255.0, 61/255.0, 139/255.0),
        "darkslategray": (47/255.0, 79/255.0, 79/255.0),
        "darkslategrey": (47/255.0, 79/255.0, 79/255.0),
        "darkturquoise": (0, 206/255.0, 209/255.0),
        "darkviolet": (148/255.0, 0, 211/255.0),
        "deeppink": (255/255.0, 20/255.0, 147/255.0),
        "deepskyblue": (0, 191/255.0, 255/255.0),
        "dimgray": (105/255.0, 105/255.0, 105/255.0),
        "dimgrey": (105/255.0, 105/255.0, 105/255.0),
        "dodgerblue": (30/255.0, 144/255.0, 255/255.0),
        "firebrick": (178/255.0, 34/255.0, 34/255.0),
        "floralwhite": (255/255.0, 250/255.0, 240/255.0),
        "forestgreen": (34/255.0, 139/255.0, 34/255.0),
        "fuchsia": (1, 0, 1),
        "gainsboro": (220/255.0, 220/255.0, 220/255.0),
        "ghostwhite": (248/255.0, 248/255.0, 255/255.0),
        "gold": (255/255.0, 215/255.0, 0),
        "goldenrod": (218/255.0, 165/255.0, 32/255.0),
        "gray": (128/255.0, 128/255.0, 128/255.0),
        "green": (0, 128/255.0, 0),
        "greenyellow": (173/255.0, 255/255.0, 47/255.0),
        "grey": (128/255.0, 128/255.0, 128/255.0),
        "honeydew": (240/255.0, 255/255.0, 240/255.0),
        "hotpink": (255/255.0, 105/255.0, 180/255.0),
        "indianred": (205/255.0, 92/255.0, 92/255.0),
        "indigo": (75/255.0, 0, 130/255.0),
        "ivory": (255/255.0, 255/255.0, 240/255.0),
        "khaki": (240/255.0, 230/255.0, 140/255.0),
        "lavender": (230/255.0, 230/255.0, 250/255.0),
        "lavenderblush": (255/255.0, 240/255.0, 245/255.0),
        "lawngreen": (124/255.0, 252/255.0, 0),
        "lemonchiffon": (255/255.0, 250/255.0, 205/255.0),
        "lightblue": (173/255.0, 216/255.0, 230/255.0),
        "lightcoral": (240/255.0, 128/255.0, 128/255.0),
        "lightcyan": (224/255.0, 255/255.0, 255/255.0),
        "lightgoldenrodyellow": (250/255.0, 250/255.0, 210/255.0),
        "lightgray": (211/255.0, 211/255.0, 211/255.0),
        "lightgreen": (144/255.0, 238/255.0, 144/255.0),
        "lightgrey": (211/255.0, 211/255.0, 211/255.0),
        "lightpink": (255/255.0, 182/255.0, 193/255.0),
        "lightsalmon": (255/255.0, 160/255.0, 122/255.0),
        "lightseagreen": (32/255.0, 178/255.0, 170/255.0),
        "lightskyblue": (135/255.0, 206/255.0, 250/255.0),
        "lightslategray": (119/255.0, 136/255.0, 153/255.0),
        "lightslategrey": (119/255.0, 136/255.0, 153/255.0),
        "lightsteelblue": (176/255.0, 196/255.0, 222/255.0),
        "lightyellow": (255/255.0, 255/255.0, 224/255.0),
        "lime": (0, 1, 0),
        "limegreen": (50/255.0, 205/255.0, 50/255.0),
        "linen": (250/255.0, 240/255.0, 230/255.0),
        "magenta": (1, 0, 1),
        "maroon": (128/255.0, 0, 0),
        "mediumaquamarine": (102/255.0, 205/255.0, 170/255.0),
        "mediumblue": (0, 0, 205/255.0),
        "mediumorchid": (186/255.0, 85/255.0, 211/255.0),
        "mediumpurple": (147/255.0, 112/255.0, 219/255.0),
        "mediumseagreen": (60/255.0, 179/255.0, 113/255.0),
        "mediumslateblue": (123/255.0, 104/255.0, 238/255.0),
        "mediumspringgreen": (0, 250/255.0, 154/255.0),
        "mediumturquoise": (72/255.0, 209/255.0, 204/255.0),
        "mediumvioletred": (199/255.0, 21/255.0, 133/255.0),
        "midnightblue": (25/255.0, 25/255.0, 112/255.0),
        "mintcream": (245/255.0, 255/255.0, 250/255.0),
        "mistyrose": (255/255.0, 228/255.0, 225/255.0),
        "moccasin": (255/255.0, 228/255.0, 181/255.0),
        "navajowhite": (255/255.0, 222/255.0, 173/255.0),
        "navy": (0, 0, 128/255.0),
        "oldlace": (253/255.0, 245/255.0, 230/255.0),
        "olive": (128/255.0, 128/255.0, 0),
        "olivedrab": (107/255.0, 142/255.0, 35/255.0),
        "orange": (1, 165/255.0, 0),
        "orangered": (255/255.0, 69/255.0, 0),
        "orchid": (218/255.0, 112/255.0, 214/255.0),
        "palegoldenrod": (238/255.0, 232/255.0, 170/255.0),
        "palegreen": (152/255.0, 251/255.0, 152/255.0),
        "paleturquoise": (175/255.0, 238/255.0, 238/255.0),
        "palevioletred": (219/255.0, 112/255.0, 147/255.0),
        "papayawhip": (255/255.0, 239/255.0, 213/255.0),
        "peachpuff": (255/255.0, 218/255.0, 185/255.0),
        "peru": (205/255.0, 133/255.0, 63/255.0),
        "pink": (255/255.0, 192/255.0, 203/255.0),
        "plum": (221/255.0, 160/255.0, 221/255.0),
        "powderblue": (176/255.0, 224/255.0, 230/255.0),
        "purple": (128/255.0, 0, 128/255.0),
        "rebeccapurple": (102/255.0, 51/255.0, 153/255.0),
        "red": (1, 0, 0),
        "rosybrown": (188/255.0, 143/255.0, 143/255.0),
        "royalblue": (65/255.0, 105/255.0, 225/255.0),
        "saddlebrown": (139/255.0, 69/255.0, 19/255.0),
        "salmon": (250/255.0, 128/255.0, 114/255.0),
        "sandybrown": (244/255.0, 164/255.0, 96/255.0),
        "seagreen": (46/255.0, 139/255.0, 87/255.0),
        "seashell": (255/255.0, 245/255.0, 238/255.0),
        "sienna": (160/255.0, 82/255.0, 45/255.0),
        "silver": (192/255.0, 192/255.0, 192/255.0),
        "skyblue": (135/255.0, 206/255.0, 235/255.0),
        "slateblue": (106/255.0, 90/255.0, 205/255.0),
        "slategray": (112/255.0, 128/255.0, 144/255.0),
        "slategrey": (112/255.0, 128/255.0, 144/255.0),
        "snow": (255/255.0, 250/255.0, 250/255.0),
        "springgreen": (0, 255/255.0, 127/255.0),
        "steelblue": (70/255.0, 130/255.0, 180/255.0),
        "tan": (210/255.0, 180/255.0, 140/255.0),
        "teal": (0, 128/255.0, 128/255.0),
        "thistle": (216/255.0, 191/255.0, 216/255.0),
        "tomato": (255/255.0, 99/255.0, 71/255.0),
        "turquoise": (64/255.0, 224/255.0, 208/255.0),
        "violet": (238/255.0, 130/255.0, 238/255.0),
        "wheat": (245/255.0, 222/255.0, 179/255.0),
        "white": (1, 1, 1),
        "whitesmoke": (245/255.0, 245/255.0, 245/255.0),
        "yellow": (1, 1, 0),
        "yellowgreen": (154/255.0, 205/255.0, 50/255.0),
    ]

    private func convertSRGBToP3(red: Double, green: Double, blue: Double, alpha: Double = 1.0) -> RGBColor {
        let srgbComponents: [CGFloat] = [CGFloat(red), CGFloat(green), CGFloat(blue), CGFloat(alpha)]
        guard let srgbColor = CGColor(colorSpace: ColorManager.shared.sRGBCG, components: srgbComponents) else {
            return RGBColor(red: red, green: green, blue: blue, alpha: alpha, colorSpace: .displayP3)
        }
        let p3Color = ColorManager.shared.toWorking(srgbColor)
        if let components = p3Color.components, components.count >= 3 {
            return RGBColor(
                red: Double(components[0]),
                green: Double(components[1]),
                blue: Double(components[2]),
                alpha: components.count > 3 ? Double(components[3]) : alpha,
                colorSpace: .displayP3
            )
        }
        return RGBColor(red: red, green: green, blue: blue, alpha: alpha, colorSpace: .displayP3)
    }

    func parseLength(_ value: String?) -> Double? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed == "0" {
            return 0.0
        }
        if trimmed.hasSuffix("px") {
            return Double(String(trimmed.dropLast(2)))
        } else if trimmed.hasSuffix("pt") {
            return Double(String(trimmed.dropLast(2)))
        } else if trimmed.hasSuffix("mm") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 2.834645669
        } else if trimmed.hasSuffix("cm") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 28.346456693
        } else if trimmed.hasSuffix("in") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 72.0
        } else if trimmed.hasSuffix("em") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 16.0
        } else if trimmed.hasSuffix("%") {
            return (Double(String(trimmed.dropLast(1))) ?? 0) / 100.0
        } else {
            return Double(trimmed)
        }
    }
}
