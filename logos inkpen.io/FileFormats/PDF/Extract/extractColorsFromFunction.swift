import SwiftUI

extension PDFCommandParser {

    func extractColorsFromFunction(_ function: CGPDFDictionaryRef) -> (VectorColor, VectorColor) {
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        var colors: [VectorColor] = []
        switch functionType {
        case 0:
            colors = extractColorsFromSampledFunction(function)
        case 2:
            var c0Array: CGPDFArrayRef?
            var c1Array: CGPDFArrayRef?
            var startColor = VectorColor.black
            var endColor = VectorColor.white
            if CGPDFDictionaryGetArray(function, "C0", &c0Array),

               let c0 = c0Array {
                startColor = extractColorFromArray(c0)
            } else {
                Log.error("PDF: ❌ No C0 array found in function", category: .error)
            }
            if CGPDFDictionaryGetArray(function, "C1", &c1Array),

               let c1 = c1Array {
                endColor = extractColorFromArray(c1)
            } else {
                Log.error("PDF: ❌ No C1 array found in function", category: .error)
            }
            colors = [startColor, endColor]
        case 3:
            colors = [.black, .white]
        default:
            Log.error("PDF: ❌ Unsupported function type \(functionType)", category: .error)
            colors = [.black, .white]
        }
        return (colors.first ?? .black, colors.last ?? .white)
    }
}
