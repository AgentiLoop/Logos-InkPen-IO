import SwiftUI

class PDFOperatorInterpreter {

    static func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef, parser: PDFCommandParser) {
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
        CGPDFOperatorTableSetCallback(operatorTable, "ca") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAlpha(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "CA") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleStrokeAlpha(scanner: scanner)
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
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
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
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "W") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClipOperator()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "W*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClipOperator()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.saveGraphicsState()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.restoreGraphicsState()
        }
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "ca") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillOpacity(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "CA") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleStrokeOpacity(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleXObjectWithOpacitySaving(scanner: scanner)
        }
        CGPDFOperatorTableSetCallback(operatorTable, "w") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()

            var width: CGFloat = 1.0
            if CGPDFScannerPopNumber(scanner, &width) {
                parser.currentLineWidth = Double(width)
            }
        }
        CGPDFOperatorTableSetCallback(operatorTable, "J") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()

            var cap: CGPDFInteger = 0
            if CGPDFScannerPopInteger(scanner, &cap) {
                parser.currentLineCap = CGLineCap(rawValue: Int32(cap)) ?? .butt
            }
        }
        CGPDFOperatorTableSetCallback(operatorTable, "j") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()

            var join: CGPDFInteger = 0
            if CGPDFScannerPopInteger(scanner, &join) {
                parser.currentLineJoin = CGLineJoin(rawValue: Int32(join)) ?? .miter
            }
        }
        CGPDFOperatorTableSetCallback(operatorTable, "M") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()

            var limit: CGFloat = 10.0
            if CGPDFScannerPopNumber(scanner, &limit) {
                parser.currentMiterLimit = Double(limit)
            }
        }
        CGPDFOperatorTableSetCallback(operatorTable, "d") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.currentLineDashPattern = []
        }
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
        }
        CGPDFOperatorTableSetCallback(operatorTable, "cs") { (scanner, info) in
        }
        CGPDFOperatorTableSetCallback(operatorTable, "CS") { (scanner, info) in
        }
        setupTextOperators(operatorTable)
        setupGradientOperators(operatorTable)
    }

    private static func setupTextOperators(_ operatorTable: CGPDFOperatorTableRef) {
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
    }

    private static func setupGradientOperators(_ operatorTable: CGPDFOperatorTableRef) {
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
