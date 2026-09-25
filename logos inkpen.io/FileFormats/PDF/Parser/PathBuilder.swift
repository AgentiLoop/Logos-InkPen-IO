import SwiftUI

private func offsetPath(_ path: VectorPath, by offset: CGPoint) -> VectorPath {
    let offsetElements = path.elements.map { element -> PathElement in
        switch element {
        case .move(let to):
            return .move(to: VectorPoint(to.x + offset.x, to.y + offset.y))
        case .line(let to):
            return .line(to: VectorPoint(to.x + offset.x, to.y + offset.y))
        case .quadCurve(let to, let control):
            return .quadCurve(
                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                control: VectorPoint(control.x + offset.x, control.y + offset.y)
            )
        case .curve(let to, let control1, let control2):
            return .curve(
                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
            )
        case .close:
            return .close
        }
    }
    return VectorPath(elements: offsetElements, isClosed: path.isClosed)
}

func extractPDFVectorContent(_ page: CGPDFPage) throws -> PDFContent {
    var inkpenMetadata: String? = nil
    if let pdfDoc = page.document {
        if let catalog = pdfDoc.catalog {
            var metadataRef: CGPDFStreamRef?
            if CGPDFDictionaryGetStream(catalog, "Metadata", &metadataRef),

               let metadataStream = metadataRef {
                var format: CGPDFDataFormat = .raw
                if let data = CGPDFStreamCopyData(metadataStream, &format) {
                    if let xmpString = String(data: data as Data, encoding: .utf8) {
                        if let range = xmpString.range(of: "<inkpen:document>"),

                           let endRange = xmpString.range(of: "</inkpen:document>") {
                            let startIndex = range.upperBound
                            let endIndex = endRange.lowerBound
                            let base64Data = String(xmpString[startIndex..<endIndex])
                            inkpenMetadata = base64Data
                        }
                    }
                }
            }
        }
    }
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_pdf_page.pdf")

    var mediaBox = page.getBoxRect(.mediaBox)
    guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
        throw VectorImportError.parsingError("Cannot create PDF context", line: nil)
    }
    context.beginPDFPage(nil)
    context.drawPDFPage(page)
    context.endPDFPage()
    context.closePDF()
    let parser = PDFCommandParser()

    var shapes = parser.parseDocument(at: tempURL)
    if mediaBox.origin != .zero {
        let offset = CGPoint(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
        shapes = shapes.map { shape in
            var offsetShape = shape
            offsetShape.path = offsetPath(shape.path, by: offset)
            return offsetShape
        }
    }
    try? FileManager.default.removeItem(at: tempURL)
    return PDFContent(
        shapes: shapes,
        textCount: 0,
        creator: "PDF Vector Parser",
        version: "Individual Shapes",
        producer: inkpenMetadata
    )
}
