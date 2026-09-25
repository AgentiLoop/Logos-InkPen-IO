import SwiftUI

extension PDFCommandParser {

    func createGradientFromShading(from shadingDict: CGPDFDictionaryRef? = nil) -> VectorGradient {
        var stops: [GradientStop] = []
        if let shadingDict = shadingDict {
            stops = extractGradientStopsFromPDFStream(shadingDict: shadingDict)
        }
        if stops.isEmpty {
            Log.error("PDF: ❌ CRITICAL ERROR: No gradient stops extracted from PDF stream!", category: .error)
            Log.error("PDF: ❌ Cannot create gradient without actual PDF data", category: .error)
            stops = [
                GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), opacity: 1.0),
                GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)), opacity: 1.0)
            ]
        }
        let ctmAngle = atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        let correctedAngle = -ctmAngle

        var linearGradient = LinearGradient(
            startPoint: CGPoint(x: 0.0, y: 0.5),
            endPoint: CGPoint(x: 1.0, y: 0.5),
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )
        linearGradient.storedAngle = correctedAngle
        return .linear(linearGradient)
    }
}
