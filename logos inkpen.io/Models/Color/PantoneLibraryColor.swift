import SwiftUI
import Combine

struct PantoneLibraryColor: Codable, Hashable {
    var pantone: String
    var name: String
    var rgbEquivalent: RGBColor
    var cmykEquivalent: CMYKColor
    var hsbEquivalent: HSBColorModel

    init(pantone: String, hex: String) {
        let cleanedPantone = pantone
            .replacingOccurrences(of: "-c", with: "")
            .replacingOccurrences(of: " C", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.pantone = cleanedPantone
        self.name = "Pantone \(cleanedPantone.uppercased())"
        self.rgbEquivalent = PantoneLibraryColor.hexToRGB(hex)
        self.cmykEquivalent = PantoneLibraryColor.rgbToCMYK(self.rgbEquivalent)
        self.hsbEquivalent = HSBColorModel.fromRGB(self.rgbEquivalent)
    }

    var color: Color {
        rgbEquivalent.color
    }

    static func hexToRGB(_ hex: String) -> RGBColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        return RGBColor(red: red, green: green, blue: blue)
    }

    static func rgbToCMYK(_ rgb: RGBColor) -> CMYKColor {
        let k = 1.0 - max(rgb.red, max(rgb.green, rgb.blue))
        if k == 1.0 {
            return CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1.0)
        }
        let c = (1.0 - rgb.red - k) / (1.0 - k)
        let m = (1.0 - rgb.green - k) / (1.0 - k)
        let y = (1.0 - rgb.blue - k) / (1.0 - k)
        return CMYKColor(cyan: c, magenta: m, yellow: y, black: k)
    }

    func distanceFrom(hsb: HSBColorModel) -> Double {
        let hueDiff = min(abs(hsbEquivalent.hue - hsb.hue), 360 - abs(hsbEquivalent.hue - hsb.hue))
        let satDiff = abs(hsbEquivalent.saturation - hsb.saturation)
        let briDiff = abs(hsbEquivalent.brightness - hsb.brightness)
        return hueDiff * 0.5 + satDiff * 100 * 0.3 + briDiff * 100 * 0.2
    }
}

class PantoneLibrary: ObservableObject {
    static let shared = PantoneLibrary()

    @Published var allColors: [PantoneLibraryColor] = []

    private var isLoaded = false

    private init() {}

    func ensureLoaded() {
        guard !isLoaded else { return }
        loadPantoneColors()
    }

    func releaseColors() {
        allColors = []
        isLoaded = false
    }

    private func loadPantoneColors() {
        guard let url = Bundle.main.url(forResource: "pantone_library", withExtension: "json"),
              let data = try? Data(contentsOf: url),

              let pantoneData = try? JSONDecoder().decode([PantoneRawData].self, from: data) else {
            allColors = [
                PantoneLibraryColor(pantone: "032 C", hex: "#ef3340"),
                PantoneLibraryColor(pantone: "072 C", hex: "#10069f"),
                PantoneLibraryColor(pantone: "355 C", hex: "#00b140"),
                PantoneLibraryColor(pantone: "Yellow C", hex: "#fedd00"),
                PantoneLibraryColor(pantone: "Process Black C", hex: "#2d2926")
            ]
            isLoaded = true
            return
        }
        allColors = pantoneData.map { rawColor in
            PantoneLibraryColor(pantone: rawColor.pms, hex: rawColor.hex)
        }
        isLoaded = true
    }

    func findClosestMatch(to hsb: HSBColorModel) -> PantoneLibraryColor? {
        ensureLoaded()
        guard !allColors.isEmpty else { return nil }
        var closestColor = allColors[0]
        var smallestDistance = Double.greatestFiniteMagnitude
        for pantoneColor in allColors {
            let distance = pantoneColor.distanceFrom(hsb: hsb)
            if distance < smallestDistance {
                smallestDistance = distance
                closestColor = pantoneColor
            }
        }
        return closestColor
    }

    func searchColors(query: String) -> [PantoneLibraryColor] {
        ensureLoaded()
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let exactMatches = allColors.filter { color in
            color.pantone.lowercased().starts(with: lowercaseQuery) ||
            color.pantone.lowercased().starts(with: lowercaseQuery + " c") ||
            color.pantone.lowercased().starts(with: lowercaseQuery + "-c")
        }
        if !exactMatches.isEmpty {
            return exactMatches
        }
        return allColors.filter { color in
            color.pantone.lowercased().contains(lowercaseQuery) ||
            color.name.lowercased().contains(lowercaseQuery)
        }
    }
}

struct PantoneRawData: Codable {
    let pms: String
    let hex: String
}
