import SwiftUI

@Observable
class AppState {
    static let shared = AppState()

    var selectedPanelTab: PanelTab = .layers

    var enableVerboseLogging: Bool = false {
        didSet { UserDefaults.standard.set(enableVerboseLogging, forKey: "enableVerboseLogging") }
    }

    var enablePressureLogging: Bool = false {
        didSet { UserDefaults.standard.set(enablePressureLogging, forKey: "enablePressureLogging") }
    }

    var showSpatialIndexBounds: Bool = false {
        didSet { UserDefaults.standard.set(showSpatialIndexBounds, forKey: "showSpatialIndexBounds") }
    }

    var defaultTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(defaultTool.rawValue, forKey: "defaultTool")
        }
    }

    var pressureSensitivityEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(pressureSensitivityEnabled, forKey: "pressureSensitivityEnabled")
        }
    }

    var showClippingInKeyline: Bool = UserDefaults.standard.object(forKey: "showClippingInKeyline") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(showClippingInKeyline, forKey: "showClippingInKeyline")
        }
    }

    var cropImageBoxInKeyline: Bool = UserDefaults.standard.object(forKey: "cropImageBoxInKeyline") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(cropImageBoxInKeyline, forKey: "cropImageBoxInKeyline")
        }
    }

    var cropShapeClipInKeyline: Bool = UserDefaults.standard.object(forKey: "cropShapeClipInKeyline") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(cropShapeClipInKeyline, forKey: "cropShapeClipInKeyline")
        }
    }
    internal var _pressureCurve: [CGPoint] = [
        CGPoint(x: 0.0, y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0, y: 1.0)
    ]

    var pressureCurve: [CGPoint] {
        get { _pressureCurve }
        set {
            _pressureCurve = newValue
            savePressureCurve()
        }
    }

    private func savePressureCurve() {
        let data = pressureCurve.map { ["x": $0.x, "y": $0.y] }
        UserDefaults.standard.set(data, forKey: "pressureCurve")
        UserDefaults.standard.synchronize()
    }

    private func loadPressureCurve() {
        if let data = UserDefaults.standard.array(forKey: "pressureCurve") as? [[String: Double]] {
            let loadedCurve = data.compactMap { dict -> CGPoint? in
                guard let x = dict["x"], let y = dict["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }
            if loadedCurve.count >= 2 {
                _pressureCurve = loadedCurve
            }
        }
    }

    var enableClippingMaskContentSelection: Bool = false {
        didSet {
            UserDefaults.standard.set(enableClippingMaskContentSelection, forKey: "enableClippingMaskContentSelection")
        }
    }
    var openWindowAction: ((String) -> Void)?
    var dismissWindowAction: ((String) -> Void)?
    var pendingNewDocument: VectorDocument? = nil
    var showSetupOnNewDoc: Bool = false
    var shouldShowDocumentSetup: Bool = false

    enum BrushPreviewStyle: String, CaseIterable { case outline, fill }

    var brushPreviewStyle: BrushPreviewStyle = .fill {
        didSet { UserDefaults.standard.set(brushPreviewStyle.rawValue, forKey: "brushPreviewStyle") }
    }

    var brushPreviewIsFinal: Bool = false {
        didSet { UserDefaults.standard.set(brushPreviewIsFinal, forKey: "brushPreviewIsFinal") }
    }

    enum PDFGradientMethod: String, CaseIterable {
        case cgGradient = "cgGradient"
        case cgShading = "cgShading"
        case cmyk = "cmyk"
        case blend = "blend"
        case mesh = "mesh"
    }

    var pdfGradientMethod: PDFGradientMethod = .cgGradient {
        didSet {
            UserDefaults.standard.set(pdfGradientMethod.rawValue, forKey: "pdfGradientMethod")
        }
    }

    enum PDFTextRenderingMode: String, CaseIterable {
        case glyphs = "glyphs"
        case lines = "lines"
    }

    var pdfTextRenderingMode: PDFTextRenderingMode = .glyphs {
        didSet {
            UserDefaults.standard.set(pdfTextRenderingMode.rawValue, forKey: "pdfTextRenderingMode")
        }
    }

    typealias SVGTextRenderingMode = PDFTextRenderingMode

    var svgTextRenderingMode: SVGTextRenderingMode = .glyphs {
        didSet {
            UserDefaults.standard.set(svgTextRenderingMode.rawValue, forKey: "svgTextRenderingMode")
        }
    }

    enum ExportColorSpace: String, CaseIterable {
        case displayP3 = "displayP3"
        case sRGB = "sRGB"
    }

    var exportColorSpace: ExportColorSpace = .displayP3 {
        didSet {
            UserDefaults.standard.set(exportColorSpace.rawValue, forKey: "exportColorSpace")
        }
    }

    var pdfBlendSteps: Int = 20 {
        didSet {
            let clampedValue = min(max(pdfBlendSteps, 10), 255)
            if pdfBlendSteps != clampedValue {
                pdfBlendSteps = clampedValue
            }
            UserDefaults.standard.set(pdfBlendSteps, forKey: "pdfBlendSteps")
        }
    }

    var pdfMeshGridX: Int = 8 {
        didSet {
            let clampedValue = min(max(pdfMeshGridX, 4), 50)
            if pdfMeshGridX != clampedValue {
                pdfMeshGridX = clampedValue
            }
            UserDefaults.standard.set(pdfMeshGridX, forKey: "pdfMeshGridX")
        }
    }

    var pdfMeshGridY: Int = 8 {
        didSet {
            let clampedValue = min(max(pdfMeshGridY, 4), 50)
            if pdfMeshGridY != clampedValue {
                pdfMeshGridY = clampedValue
            }
            UserDefaults.standard.set(pdfMeshGridY, forKey: "pdfMeshGridY")
        }
    }

    private init() {
        if let toolRawValue = UserDefaults.standard.string(forKey: "defaultTool"),

           let tool = DrawingTool(rawValue: toolRawValue) {
            self.defaultTool = tool
        } else {
            self.defaultTool = .brush
        }
        self.pressureSensitivityEnabled = UserDefaults.standard.object(forKey: "pressureSensitivityEnabled") as? Bool ?? false
        loadPressureCurve()
        if let styleRaw = UserDefaults.standard.string(forKey: "brushPreviewStyle"),

           let style = BrushPreviewStyle(rawValue: styleRaw) {
            self.brushPreviewStyle = style
        }
        self.brushPreviewIsFinal = UserDefaults.standard.object(forKey: "brushPreviewIsFinal") as? Bool ?? false
        self.enableVerboseLogging = UserDefaults.standard.object(forKey: "enableVerboseLogging") as? Bool ?? false
        self.enablePressureLogging = UserDefaults.standard.object(forKey: "enablePressureLogging") as? Bool ?? false
        if let methodRaw = UserDefaults.standard.string(forKey: "pdfGradientMethod") {
            let actualRaw = (methodRaw == "deviceN") ? "cmyk" : methodRaw
            if let method = PDFGradientMethod(rawValue: actualRaw) {
                self.pdfGradientMethod = method
            }
        }
        let savedSteps = UserDefaults.standard.object(forKey: "pdfBlendSteps") as? Int
        self.pdfBlendSteps = savedSteps ?? 20
        let savedGridX = UserDefaults.standard.object(forKey: "pdfMeshGridX") as? Int
        self.pdfMeshGridX = savedGridX ?? 8
        let savedGridY = UserDefaults.standard.object(forKey: "pdfMeshGridY") as? Int
        self.pdfMeshGridY = savedGridY ?? 8
        if let modeRaw = UserDefaults.standard.string(forKey: "pdfTextRenderingMode"),

           let mode = PDFTextRenderingMode(rawValue: modeRaw) {
            self.pdfTextRenderingMode = mode
        }
        if let modeRaw = UserDefaults.standard.string(forKey: "svgTextRenderingMode"),

           let mode = SVGTextRenderingMode(rawValue: modeRaw) {
            self.svgTextRenderingMode = mode
        }
        if let colorSpaceRaw = UserDefaults.standard.string(forKey: "exportColorSpace"),

           let colorSpace = ExportColorSpace(rawValue: colorSpaceRaw) {
            self.exportColorSpace = colorSpace
        }
    }

    func setWindowActions(openWindow: @escaping (String) -> Void, dismissWindow: @escaping (String) -> Void) {
        self.openWindowAction = { id in
            openWindow(id)
        }
        self.dismissWindowAction = { id in
            dismissWindow(id)
        }
    }
}
