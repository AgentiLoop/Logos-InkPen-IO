import SwiftUI

extension PDFCommandParser {

    func extractColorFromFunctionIndex(_ functions: CGPDFArrayRef, index: Int) -> VectorColor {
        var functionObj: CGPDFObjectRef?
        guard CGPDFArrayGetObject(functions, index, &functionObj),

              let obj = functionObj else {
            return .black
        }
        var functionDict: CGPDFDictionaryRef?
        if CGPDFObjectGetValue(obj, .dictionary, &functionDict),

           let function = functionDict {
            let (color, _) = extractColorsFromFunction(function)
            return color
        }
        return .black
    }
}
