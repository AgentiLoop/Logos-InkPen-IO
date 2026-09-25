import SwiftUI

extension PDFCommandParser {

    func applyGradientToWhiteShapes(gradient: VectorGradient) {
        activeGradient = gradient
        gradientShapes.removeAll()
        if !currentPath.isEmpty {
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            let recentShapeCount = min(5, shapes.count)
            let startIndex = max(0, shapes.count - recentShapeCount)
            for i in startIndex..<shapes.count {
                let shape = shapes[i]
                if let fillStyle = shape.fillStyle,
                   case .rgb(let rgbColor) = fillStyle.color,
                   rgbColor.red > 0.95 && rgbColor.green > 0.95 && rgbColor.blue > 0.95 {
                    gradientShapes.append(i)
                }
            }
        } else {
        }
    }
}
