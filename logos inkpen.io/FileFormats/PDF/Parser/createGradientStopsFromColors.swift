import SwiftUI

extension PDFCommandParser {

    func createGradientStopsFromColors(_ colors: [VectorColor]) -> [GradientStop] {
        guard colors.count > 1 else {
            return [GradientStop(position: 0.0, color: colors.first ?? .black, opacity: 1.0)]
        }
        let targetStops = 11
        let subSampledColors = subsampleColors(colors, targetCount: targetStops)

        var stops: [GradientStop] = []
        for i in 0..<targetStops {
            let position = Double(i) / Double(targetStops - 1)
            let colorIndex = min(i, subSampledColors.count - 1)
            let color = subSampledColors[colorIndex]
            stops.append(GradientStop(position: position, color: color, opacity: 1.0))
        }
        return stops
    }
}
