import SwiftUI

class TemplateManager {
    static let shared = TemplateManager()

    private var isInitialized = false

    private init() {
        loadAvailableTemplates()
        isInitialized = true
    }

    enum TemplateType: String, CaseIterable {
        case blank = "blank"
        case businessCard = "business_card"
        case letterhead = "letterhead"
        case poster = "poster"
        case logo = "logo"
        case architectural = "architectural"
        case engineering = "engineering"
        case webGraphics = "web_graphics"
    }

    private func loadAvailableTemplates() {
    }

    func createBlankDocument(with defaultTool: DrawingTool = .selection) -> VectorDocument {
        let blankSettings = DocumentSettings(
            width: 11.0,
            height: 8.5,
            unit: .inches,
            colorMode: .rgb,
            resolution: 72,
            showRulers: true,
            showGrid: false,
            snapToGrid: false,
            gridSpacing: 0.125,
            backgroundColor: VectorColor.white
        )
        let document = VectorDocument(settings: blankSettings)
        document.selectedLayerIndex = 3
        document.viewState.selectedObjectIDs.removeAll()
        document.removeAllText()
        document.viewState.currentTool = defaultTool
        return document
    }
}
