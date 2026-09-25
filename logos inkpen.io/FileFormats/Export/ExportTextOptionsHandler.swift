import AppKit
import Combine

class ExportTextOptionsHandler: NSObject {
    let textToOutlinesCheckbox: NSButton
    let textModeLabel: NSTextField
    let glyphsRadio: NSButton
    let linesRadio: NSButton

    init(textToOutlinesCheckbox: NSButton,
         textModeLabel: NSTextField,
         glyphsRadio: NSButton,
         linesRadio: NSButton) {
        self.textToOutlinesCheckbox = textToOutlinesCheckbox
        self.textModeLabel = textModeLabel
        self.glyphsRadio = glyphsRadio
        self.linesRadio = linesRadio
    }

    @objc func toggleTextOptions(_ sender: NSButton) {
        let shouldHide = sender.state == .on
        textModeLabel.isHidden = shouldHide
        glyphsRadio.isHidden = shouldHide
        linesRadio.isHidden = shouldHide
    }

    @objc func selectGlyphs(_ sender: NSButton) {
        glyphsRadio.state = .on
        linesRadio.state = .off
    }

    @objc func selectLines(_ sender: NSButton) {
        glyphsRadio.state = .off
        linesRadio.state = .on
    }
}

extension DocumentState {

    @discardableResult
    static func exportWithTextToOutlines(
        _ document: VectorDocument,
        exportHandler: () throws -> Data
    ) async throws -> Data {
        let savedSnapshot = document.snapshot
        let savedSelection = document.viewState.selectedObjectIDs
        await MainActor.run {
            DocumentState.convertAllTextToOutlinesForExport(document)
        }
        let exportData = try exportHandler()
        await MainActor.run {
            document.snapshot = savedSnapshot
            document.viewState.selectedObjectIDs = savedSelection
        }
        return exportData
    }

    static func exportSVGWithTextToOutlines(
        _ document: VectorDocument,
        includeBackground: Bool,
        textRenderingMode: AppState.SVGTextRenderingMode,
        includeInkpenData: Bool,
        isAutoDesk: Bool = false
    ) async throws -> String {
        let savedSnapshot = document.snapshot
        let savedSelection = document.viewState.selectedObjectIDs
        await MainActor.run {
            DocumentState.convertAllTextToOutlinesForExport(document)
        }
        let svgContent: String
        if isAutoDesk {
            svgContent = try SVGExporter.shared.exportToAutoDeskSVG(
                document,
                includeBackground: includeBackground,
                textRenderingMode: textRenderingMode,
                includeInkpenData: true
            )
        } else {
            svgContent = try SVGExporter.shared.exportToSVG(
                document,
                includeBackground: includeBackground,
                textRenderingMode: textRenderingMode,
                includeInkpenData: includeInkpenData
            )
        }
        await MainActor.run {
            document.snapshot = savedSnapshot
            document.viewState.selectedObjectIDs = savedSelection
        }
        return svgContent
    }
}
