import SwiftUI

extension PDFCommandParser {

    func extractAllColorsFromFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        switch functionType {
        case 0:
            return extractColorsFromSampledFunction(function)
        case 2:
            let (start, end) = extractColorsFromFunction(function)
            return [start, end]
        default:
            return [.black, .white]
        }
    }
}
