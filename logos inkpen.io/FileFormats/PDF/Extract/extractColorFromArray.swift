import SwiftUI

extension PDFCommandParser {

    func extractColorFromArray(_ array: CGPDFArrayRef) -> VectorColor {
        let count = CGPDFArrayGetCount(array)
        if count >= 3 {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &r)
            CGPDFArrayGetNumber(array, 1, &g)
            CGPDFArrayGetNumber(array, 2, &b)
            return .rgb(RGBColor(red: Double(r), green: Double(g), blue: Double(b)))
        } else if count == 1 {
            var gray: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &gray)
            return .rgb(RGBColor(red: Double(gray), green: Double(gray), blue: Double(gray)))
        }
        Log.error("PDF: ❌ Invalid color array, using black", category: .error)
        return .black
    }
}
