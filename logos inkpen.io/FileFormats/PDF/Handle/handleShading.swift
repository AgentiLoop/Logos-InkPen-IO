import SwiftUI

extension PDFCommandParser {

    func handleShading(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),

           let name = nameObj {
            let shadingName = String(cString: name)
            if hasClipOperatorPending {
                hasClipOperatorPending = false
                clipOperatorPath.removeAll()
            }
            if let gradient = extractGradientFromShading(shadingName: shadingName, scanner: scanner) {
                handleGradientInContext(gradient: gradient)
            }
        }
    }
}
