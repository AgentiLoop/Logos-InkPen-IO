import SwiftUI

extension PDFCommandParser {

    func handleConcatMatrix(scanner: CGPDFScannerRef) {
        var a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1, tx: CGFloat = 0, ty: CGFloat = 0
        CGPDFScannerPopNumber(scanner, &ty)
        CGPDFScannerPopNumber(scanner, &tx)
        CGPDFScannerPopNumber(scanner, &d)
        CGPDFScannerPopNumber(scanner, &c)
        CGPDFScannerPopNumber(scanner, &b)
        CGPDFScannerPopNumber(scanner, &a)
        let newTransform = PDFSIMDMatrix(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
        simdTransformMatrix.concatenate(newTransform)
        currentTransformMatrix = simdTransformMatrix.cgAffineTransform
    }
}
