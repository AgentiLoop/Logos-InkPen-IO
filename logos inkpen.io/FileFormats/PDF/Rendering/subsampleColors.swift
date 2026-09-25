import SwiftUI

extension PDFCommandParser {

    func subsampleColors(_ colors: [VectorColor], targetCount: Int) -> [VectorColor] {
        guard colors.count > targetCount else {
            return colors
        }
        var sampledColors: [VectorColor] = []
        for i in 0..<targetCount {
            let sourceIndex = Int((Double(i) / Double(targetCount - 1)) * Double(colors.count - 1))
            let clampedIndex = min(sourceIndex, colors.count - 1)
            sampledColors.append(colors[clampedIndex])
        }
        return sampledColors
    }
}
