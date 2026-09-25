import SwiftUI

struct SVGContent {
    let shapes: [VectorShape]
    let documentSize: CGSize
    let viewBoxSize: CGSize?
    let colorSpace: String
    let units: VectorUnit
    let dpi: Double
    let missingFonts: [String]
    let creator: String?
    let version: String?
    let inkpenMetadata: String?
}

func parseSVGContent(_ data: Data, useExtremeValueHandling: Bool = false) throws -> SVGContent {
    guard let xmlString = String(data: data, encoding: .utf8) else {
        throw VectorImportError.parsingError("Could not decode SVG as UTF-8", line: nil)
    }
    let parser = SVGParser()
    if useExtremeValueHandling {
        parser.enableExtremeValueHandling()
    }
    let result = try parser.parse(xmlString)

    var allShapes = result.shapes

    let maxWidth = parser.maxTextWidth
    for var textObject in result.textObjects.reversed() {
        if maxWidth > 0 {
            let height = textObject.areaSize?.height ?? CGFloat(textObject.typography.lineHeight)
            textObject.areaSize = CGSize(width: maxWidth, height: height)
            textObject.bounds = CGRect(
                x: textObject.bounds.origin.x,
                y: textObject.bounds.origin.y,
                width: maxWidth,
                height: textObject.bounds.height
            )
        }
        let textShape = textObject.toVectorShape()
        allShapes.append(textShape)
    }
    return SVGContent(
        shapes: allShapes,
        documentSize: result.documentSize,
        viewBoxSize: result.viewBoxSize,
        colorSpace: "RGB",
        units: .points,
        dpi: 72.0,
        missingFonts: [],
        creator: result.creator,
        version: result.version,
        inkpenMetadata: parser.inkpenMetadata
    )
}
