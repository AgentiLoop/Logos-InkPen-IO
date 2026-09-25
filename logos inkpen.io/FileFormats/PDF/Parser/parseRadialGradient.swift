import SwiftUI

extension PDFCommandParser {

    func parseRadialGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),

              let coords = coordsArray else {
            return nil
        }
        var x0: CGFloat = 0, y0: CGFloat = 0, r0: CGFloat = 0
        var x1: CGFloat = 0, y1: CGFloat = 0, r1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &r0)
        CGPDFArrayGetNumber(coords, 3, &x1)
        CGPDFArrayGetNumber(coords, 4, &y1)
        CGPDFArrayGetNumber(coords, 5, &r1)
        let centerPoint = CGPoint(x: x1 / pageSize.width, y: 1.0 - (y1 / pageSize.height))
        let focalPoint = r0 > 0 ? CGPoint(x: x0 / pageSize.width, y: 1.0 - (y0 / pageSize.height)) : nil
        let radius = Double(r1 / max(pageSize.width, pageSize.height))
        let stops = extractGradientStops(from: dict)
        let radialGradient = RadialGradient(
            centerPoint: centerPoint,
            radius: radius,
            stops: stops,
            focalPoint: focalPoint,
            spreadMethod: GradientSpreadMethod.pad
        )
        return .radial(radialGradient)
    }
}
