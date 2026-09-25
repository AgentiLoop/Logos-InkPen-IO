import SwiftUI
import PDFKit

extension PDFCommandParser {

    func PDF17OperatorTable() -> CGPDFOperatorTableRef? {
        guard let operatorTable = CGPDFOperatorTableCreate() else { return nil }
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClosePath()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "rg") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRGBFillColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "RG") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRGBStrokeColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "g") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGrayFillColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "G") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGrayStrokeColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "k") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCMYKFillColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "K") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCMYKStrokeColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "sc") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGenericFillColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "SC") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGenericStrokeColor(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "f") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "F") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleStroke()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.finalizeClippingGroup()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleXObjectWithImageSupport(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
        }
        CGPDFOperatorTableSetCallback(operatorTable, "BT") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleBeginText()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "ET") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleEndText()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tf") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetFont(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tc") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetCharacterSpacing(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tw") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetWordSpacing(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tz") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetHorizontalScaling(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "TL") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextLeading(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tr") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextRenderingMode(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Ts") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextRise(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Td") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleTextMove(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "TD") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleTextMoveWithLeading(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tm") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextMatrix(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "T*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleTextNewLine()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Tj") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleShowText(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "TJ") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleShowTextWithPositioning(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "'") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleMoveAndShowText(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "\"") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSpacingMoveAndShowText(scanner: scanner)
        }
        return operatorTable
    }
}
