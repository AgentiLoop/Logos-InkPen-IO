import SwiftUI

extension PDFCommandParser {

    func parseGradientFromDictionary(_ dict: CGPDFDictionaryRef) -> VectorGradient? {
        var shadingType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(dict, "ShadingType", &shadingType)
        switch shadingType {
        case 2:
            return parseLinearGradient(from: dict)
        case 3:
            return parseRadialGradient(from: dict)
        default:
            return nil
        }
    }
}
