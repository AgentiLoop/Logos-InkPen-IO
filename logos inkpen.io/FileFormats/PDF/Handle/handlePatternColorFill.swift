import SwiftUI

extension PDFCommandParser {

    func handlePatternColorFill(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),

           let name = nameObj {
            let patternName = String(cString: name)
            if let gradient = extractGradientFromPattern(patternName: patternName, scanner: scanner) {
                currentFillGradient = gradient
            }
        }
    }
}
