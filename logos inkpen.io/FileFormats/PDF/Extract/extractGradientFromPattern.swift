import SwiftUI

extension PDFCommandParser {

    func extractGradientFromPattern(patternName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let patternCString = patternName.cString(using: .utf8),

              let pdfPage = CGPDFContentStreamGetResource(stream, "Pattern", patternCString) else {
            return nil
        }
        var patternDictRef: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(pdfPage, .dictionary, &patternDictRef),

              let patternDict = patternDictRef else {
            return nil
        }
        return parseGradientFromDictionary(patternDict)
    }
}
