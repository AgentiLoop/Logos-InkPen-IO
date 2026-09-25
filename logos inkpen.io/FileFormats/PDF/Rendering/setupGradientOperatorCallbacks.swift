import SwiftUI

extension PDFCommandParser {

    func setupGradientOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
        CGPDFOperatorTableSetCallback(operatorTable, "SCN") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handlePatternColorStroke(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "scn") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handlePatternColorFill(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "cm") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleConcatMatrix(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "sh") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleShading(scanner: scanner)
        }
    }
}
