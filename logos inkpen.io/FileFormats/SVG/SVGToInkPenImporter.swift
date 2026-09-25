import SwiftUI
import Combine
import UniformTypeIdentifiers

class SVGToInkPenImporter: ObservableObject {
    static var svgShapeRegistry: [UUID: (data: Data, document: SVGDocument)] = [:]

    @Published var importResults: [ImportResult] = []
    @Published var currentOperation: String = "Ready"
    @Published var isImporting: Bool = false
    struct ImportResult: Identifiable {
        let id = UUID()
        let operation: String
        let success: Bool
        let message: String
        let details: String
        let timestamp: Date
    }

    @objc class CGSVGDocument: NSObject { }
    static let CoreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)

    static var CGSVGDocumentRelease: (@convention(c) (CGSVGDocument?) -> Void) = load("CGSVGDocumentRelease")
    static var CGSVGDocumentCreateFromData: (@convention(c) (CFData?, CFDictionary?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentCreateFromData")
    static var CGContextDrawSVGDocument: (@convention(c) (CGContext?, CGSVGDocument?) -> Void) = load("CGContextDrawSVGDocument")
    static var CGSVGDocumentGetCanvasSize: (@convention(c) (CGSVGDocument?) -> CGSize) = load("CGSVGDocumentGetCanvasSize")

    static func load<T>(_ name: String) -> T {
        unsafeBitCast(dlsym(CoreSVG, name), to: T.self)
    }

    class SVGDocument {

        deinit { SVGToInkPenImporter.CGSVGDocumentRelease(document) }
        let document: CGSVGDocument

        init?(_ data: Data) {
            guard let document = SVGToInkPenImporter.CGSVGDocumentCreateFromData(data as CFData, nil)?.takeUnretainedValue() else { return nil }
            guard SVGToInkPenImporter.CGSVGDocumentGetCanvasSize(document) != .zero else { return nil }
            self.document = document
        }

        var size: CGSize {
            SVGToInkPenImporter.CGSVGDocumentGetCanvasSize(document)
        }

        func renderToVectorContext(_ context: CGContext, targetSize: CGSize) {
            let originalSize = self.size
            context.saveGState()
            let scaleX = targetSize.width / originalSize.width
            let scaleY = targetSize.height / originalSize.height
            let scale = min(scaleX, scaleY)
            let scaledWidth = originalSize.width * scale
            let scaledHeight = originalSize.height * scale
            let offsetX = (targetSize.width - scaledWidth) / 2
            let offsetY = (targetSize.height - scaledHeight) / 2
            context.translateBy(x: offsetX, y: offsetY + scaledHeight)
            context.scaleBy(x: scale, y: -scale)
            SVGToInkPenImporter.CGContextDrawSVGDocument(context, document)
            context.restoreGState()
        }
    }

    func importSVGFile(from url: URL) -> VectorDocument? {
        isImporting = true
        importResults.removeAll()
        addResult("Starting SVG Import", success: true, message: "Processing file: \(url.lastPathComponent)")
        do {
            let data = try Data(contentsOf: url)
            addResult("File Loaded", success: true, message: "File size: \(data.count) bytes")
            guard let svgDoc = SVGDocument(data) else {
                addResult("SVG Parsing Failed", success: false, message: "Could not parse SVG document")
                isImporting = false
                return nil
            }
            addResult("SVG Parsed", success: true, message: "Document size: \(Int(svgDoc.size.width)) × \(Int(svgDoc.size.height))")
            let document = createVectorDocumentFromSVG(svgDoc, svgData: data)
            addResult("Import Complete", success: true, message: "Created document with \(document.snapshot.layers.count) layers")
            isImporting = false
            return document
        } catch {
            addResult("File Loading Failed", success: false, message: "Error: \(error.localizedDescription)")
            isImporting = false
            return nil
        }
    }

    func importSVGString(_ svgString: String, name: String = "Imported SVG") -> VectorDocument? {
        isImporting = true
        importResults.removeAll()
        addResult("Starting SVG String Import", success: true, message: "Processing SVG string")
        guard let data = svgString.data(using: .utf8) else {
            addResult("String Conversion Failed", success: false, message: "Could not convert string to data")
            isImporting = false
            return nil
        }
        guard let svgDoc = SVGDocument(data) else {
            addResult("SVG Parsing Failed", success: false, message: "Could not parse SVG document")
            isImporting = false
            return nil
        }
        addResult("SVG Parsed", success: true, message: "Document size: \(Int(svgDoc.size.width)) × \(Int(svgDoc.size.height))")
        let document = createVectorDocumentFromSVG(svgDoc, svgData: data, name: name)
        addResult("Import Complete", success: true, message: "Created document with \(document.snapshot.layers.count) layers")
        isImporting = false
        return document
    }

    private func createVectorDocumentFromSVG(_ svgDoc: SVGDocument, svgData: Data, name: String = "Imported SVG") -> VectorDocument {
        let svgSize = svgDoc.size
        let settings = createDocumentSettings(from: svgSize)
        let shapes = extractShapesFromSVG(svgDoc, svgData: svgData)
        let document = VectorDocument(settings: settings)
        document.snapshot.layers.append(Layer(
            name: name,
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .blue
        ))
        let importedLayerIndex = document.snapshot.layers.count - 1
        for shape in shapes {
            document.addShapeToUnifiedSystem(shape, layerIndex: importedLayerIndex)
        }
        addResult("Shapes Extracted", success: true, message: "Created \(shapes.count) shapes from SVG")
        return document
    }

    private func createDocumentSettings(from svgSize: CGSize) -> DocumentSettings {
        let widthInPoints = svgSize.width
        let heightInPoints = svgSize.height
        let widthInInches = widthInPoints / 72.0
        let heightInInches = heightInPoints / 72.0
        return DocumentSettings(
            width: widthInInches,
            height: heightInInches,
            unit: .inches,
            colorMode: .rgb,
            resolution: 72.0,
            showRulers: true,
            showGrid: false,
            snapToGrid: false,
            gridSpacing: 0.125,
            backgroundColor: .white
        )
    }

    private func extractShapesFromSVG(_ svgDoc: SVGDocument, svgData: Data) -> [VectorShape] {
        var shapes: [VectorShape] = []

        let svgSize = svgDoc.size
        addResult("SVG Processing", success: true, message: "Processing SVG with dimensions \(Int(svgSize.width)) × \(Int(svgSize.height))")
        let svgContentShape = createSVGContentShape(size: svgSize, document: svgDoc, svgData: svgData)
        shapes.append(svgContentShape)
        addResult("SVG Shape Creation", success: true, message: "Created SVG content shape",
                 details: "Shape will be rendered using CoreSVG when drawn")
        return shapes
    }

    private func createSVGContentShape(size: CGSize, document: SVGDocument, svgData: Data) -> VectorShape {
        let svgShape = VectorShape(
            name: "[SVG] Content (\(Int(size.width))×\(Int(size.height)))",
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(size.width, 0)),
                .line(to: VectorPoint(size.width, size.height)),
                .line(to: VectorPoint(0, size.height)),
                .close
            ], isClosed: true),
            strokeStyle: StrokeStyle(
                color: .rgb(RGBColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)),
                width: 2.0,
                placement: .center
            ),
            fillStyle: FillStyle(
                color: .rgb(RGBColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.3))
            ),
            transform: .identity
        )
        SVGToInkPenImporter.svgShapeRegistry[svgShape.id] = (data: svgData, document: document)
        return svgShape
    }

    static func containsSVGContent(_ shape: VectorShape) -> Bool {
        return svgShapeRegistry[shape.id] != nil || shape.name.hasPrefix("[SVG]")
    }

    static func getSVGData(for shape: VectorShape) -> (data: Data, document: SVGDocument)? {
        return svgShapeRegistry[shape.id]
    }

    private func addResult(_ operation: String, success: Bool, message: String, details: String = "") {
        DispatchQueue.main.async {
            self.currentOperation = operation
            self.importResults.append(ImportResult(
                operation: operation,
                success: success,
                message: message,
                details: details,
                timestamp: Date()
            ))
        }
    }
}
