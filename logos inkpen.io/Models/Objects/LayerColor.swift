import SwiftUI

struct LayerColorName {
    static let maroon = "Maroon"
    static let red = "Red"
    static let vermillion = "Vermillion"
    static let rust = "Rust"
    static let orange = "Orange"
    static let amber = "Amber"
    static let yellow = "Yellow"
    static let chartreuse = "Chartreuse"
    static let lime = "Lime"
    static let green = "Green"
    static let emerald = "Emerald"
    static let spring = "Spring"
    static let ocean = "Ocean"
    static let cyan = "Cyan"
    static let sky = "Sky"
    static let blue = "Blue"
    static let azure = "Azure"
    static let indigo = "Indigo"
    static let violet = "Violet"
    static let orchid = "Orchid"
    static let purple = "Purple"
    static let magenta = "Magenta"
    static let pink = "Pink"
    static let rose = "Rose"
    static let gray = "Gray"
}

struct LayerColor: Equatable, Codable, Hashable {
    let name: String

    static let maroon = LayerColor(name: LayerColorName.maroon)
    static let red = LayerColor(name: LayerColorName.red)
    static let vermillion = LayerColor(name: LayerColorName.vermillion)
    static let rust = LayerColor(name: LayerColorName.rust)
    static let orange = LayerColor(name: LayerColorName.orange)
    static let amber = LayerColor(name: LayerColorName.amber)
    static let yellow = LayerColor(name: LayerColorName.yellow)
    static let chartreuse = LayerColor(name: LayerColorName.chartreuse)
    static let lime = LayerColor(name: LayerColorName.lime)
    static let green = LayerColor(name: LayerColorName.green)
    static let emerald = LayerColor(name: LayerColorName.emerald)
    static let spring = LayerColor(name: LayerColorName.spring)
    static let ocean = LayerColor(name: LayerColorName.ocean)
    static let cyan = LayerColor(name: LayerColorName.cyan)
    static let sky = LayerColor(name: LayerColorName.sky)
    static let blue = LayerColor(name: LayerColorName.blue)
    static let azure = LayerColor(name: LayerColorName.azure)
    static let indigo = LayerColor(name: LayerColorName.indigo)
    static let violet = LayerColor(name: LayerColorName.violet)
    static let orchid = LayerColor(name: LayerColorName.orchid)
    static let purple = LayerColor(name: LayerColorName.purple)
    static let magenta = LayerColor(name: LayerColorName.magenta)
    static let pink = LayerColor(name: LayerColorName.pink)
    static let rose = LayerColor(name: LayerColorName.rose)
    static let gray = LayerColor(name: LayerColorName.gray)
}
