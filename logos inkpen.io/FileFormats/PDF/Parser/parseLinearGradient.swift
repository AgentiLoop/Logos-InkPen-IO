import SwiftUI

extension PDFCommandParser {

    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray,
              CGPDFArrayGetCount(coords) >= 4 else {
            return nil
        }
        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &x1)
        CGPDFArrayGetNumber(coords, 3, &y1)
        let startPoint = CGPoint(x: Double(x0), y: Double(y0))
        let endPoint = CGPoint(x: Double(x1), y: Double(y1))
        let spreadMethod: GradientSpreadMethod = .pad
        let stops = extractGradientStops(from: dict)

        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: spreadMethod
        )
        let deltaX = x1 - x0
        let deltaY = y1 - y0
        linearGradient.storedAngle = atan2(deltaY, deltaX) * 180.0 / .pi
        return .linear(linearGradient)
    }
}
