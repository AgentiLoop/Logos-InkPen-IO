import SwiftUI

extension FileOperations {

    static func exportToSVG(_ document: VectorDocument, url: URL, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs) throws {
        do {
            let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: includeBackground, textRenderingMode: textRenderingMode)
            try svgContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Log.error("❌ SVG export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export SVG: \(error.localizedDescription)", line: nil)
        }
    }
}
