import SwiftUI
import UniformTypeIdentifiers

class VectorImportManager {
    static let shared = VectorImportManager()

    private init() {}
    private static let freehandExtensions: Set<String> = [
        "fh", "fh1", "fh2", "fh3", "fh4", "fh5", "fh6", "fh7", "fh8", "fh9",
        "fh10", "fh11", "fhmx", "ft11", "ftmx", "eps"
    ]

    func importVectorFile(from url: URL) async -> VectorImportResult {
        if Self.freehandExtensions.contains(url.pathExtension.lowercased()) {
            return await importFreeHand(from: url)
        }
        if let raster = detectRaster(from: url) {
            return await importRaster(from: url, raster: raster)
        }
        guard let format = detectFormat(from: url) else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.svg)],
                warnings: ["Could not detect file format"]
            )
        }
        guard format.isCurrentlySupported else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.commercialLicenseRequired(format)],
                warnings: ["Professional CAD formats require commercial licensing"]
            )
        }
        switch format {
        case .svg:
            return importSVG(from: url)
        case .pdf:
            return await importPDF(from: url)
        }
    }

    func importSVGWithExtremeValueHandling(from url: URL) -> VectorImportResult {
        guard let format = detectFormat(from: url) else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.svg)],
                warnings: ["Could not detect file format"]
            )
        }
        guard format.isCurrentlySupported else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.commercialLicenseRequired(format)],
                warnings: ["Professional CAD formats require commercial licensing"]
            )
        }
        switch format {
        case .svg:
            return importSVG(from: url, useExtremeValueHandling: true)
        case .pdf:
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.pdf)],
                warnings: ["PDF import not available on SVG path"]
            )
        }
    }

    private func detectFormat(from url: URL) -> VectorFileFormat? {
        let pathExtension = url.pathExtension.lowercased()
        if let format = VectorFileFormat.allCases.first(where: { $0.rawValue == pathExtension }) {
            return format
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return detectFormatByContent(data)
    }

    enum RasterFormat: String, CaseIterable {
        case png = "png"
        case jpg = "jpg"
        case jpeg = "jpeg"
        case tif = "tif"
        case tiff = "tiff"
        case bmp = "bmp"
        case psd = "psd"
        case heic = "heic"
        case heif = "heif"
        case gif = "gif"
        case webp = "webp"
    }

    private func detectRaster(from url: URL) -> RasterFormat? {
        let ext = url.pathExtension.lowercased()
        return RasterFormat.allCases.first { $0.rawValue == ext }
    }

    private func detectFormatByContent(_ data: Data) -> VectorFileFormat? {
        guard let string = String(data: data.prefix(1024), encoding: .utf8) else { return nil }
        if string.contains("<svg") || string.contains("<?xml") && string.contains("svg") {
            return .svg
        }
        if string.hasPrefix("%PDF-") {
            return .pdf
        }
        if string.hasPrefix("%!PS-Adobe") {
            return .pdf
        }
        return nil
    }

    private func importSVG(from url: URL, useExtremeValueHandling: Bool = false) -> VectorImportResult {
        var errors: [VectorImportError] = []
        var warnings: [String] = []
        var shapes: [VectorShape] = []
        do {
            guard let data = try? Data(contentsOf: url) else {
                throw VectorImportError.fileNotFound
            }
            if let svgString = String(data: data, encoding: .utf8) {
                if let range = svgString.range(of: "<inkpen:document"),

                   let endRange = svgString.range(of: "</inkpen:document>") {
                    if let openTagEnd = svgString.range(of: ">", range: range.upperBound..<endRange.lowerBound) {
                        let base64Data = String(svgString[openTagEnd.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

                        var documentSize = CGSize(width: 8.5 * 72, height: 11 * 72)
                        if let widthRange = svgString.range(of: "width=\""),
                           let widthEnd = svgString.range(of: "\"", range: widthRange.upperBound..<svgString.endIndex),

                           let width = Double(svgString[widthRange.upperBound..<widthEnd.lowerBound]) {
                            documentSize.width = width
                        }
                        if let heightRange = svgString.range(of: "height=\""),
                           let heightEnd = svgString.range(of: "\"", range: heightRange.upperBound..<svgString.endIndex),

                           let height = Double(svgString[heightRange.upperBound..<heightEnd.lowerBound]) {
                            documentSize.height = height
                        }
                        let metadata = VectorImportMetadata(
                            originalFormat: .svg,
                            documentSize: documentSize,
                            viewBoxSize: nil,
                            colorSpace: "RGB",
                            units: .points,
                            dpi: 72.0,
                            layerCount: 1,
                            shapeCount: 0,
                            textObjectCount: 0,
                            importDate: Date(),
                            sourceApplication: "Inkpen.io",
                            documentVersion: nil,
                            inkpenMetadata: base64Data
                        )
                        return VectorImportResult(
                            success: true,
                            shapes: [],
                            metadata: metadata,
                            errors: errors,
                            warnings: warnings
                        )
                    }
                }
            }
            let svgContent = try parseSVGContent(data, useExtremeValueHandling: useExtremeValueHandling)
            shapes = svgContent.shapes
            if !svgContent.missingFonts.isEmpty {
                warnings.append("Missing fonts: \(svgContent.missingFonts.joined(separator: ", "))")
            }
            let metadata = VectorImportMetadata(
                originalFormat: .svg,
                documentSize: svgContent.documentSize,
                viewBoxSize: svgContent.viewBoxSize,
                colorSpace: svgContent.colorSpace,
                units: svgContent.units,
                dpi: svgContent.dpi,
                layerCount: 1,
                shapeCount: shapes.count,
                textObjectCount: 0,
                importDate: Date(),
                sourceApplication: svgContent.creator,
                documentVersion: svgContent.version,
                inkpenMetadata: svgContent.inkpenMetadata
            )
            return VectorImportResult(
                success: true,
                shapes: shapes,
                metadata: metadata,
                errors: errors,
                warnings: warnings
            )
        } catch {
            errors.append(.parsingError(error.localizedDescription, line: nil))
            Log.error("❌ SVG import failed: \(error)", category: .error)
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
    }

    private func importFreeHand(from url: URL) async -> VectorImportResult {
        do {
            let direct = try FreeHandDirectImporter.parseToShapes(url: url)
            Log.info("🪶 FH direct: \(direct.shapes.count) top, page \(Int(direct.pageSize.width))×\(Int(direct.pageSize.height)) | paths=\(direct.stats.paths) grp=\(direct.stats.groups) clipGrp=\(direct.stats.clipGroups) comp=\(direct.stats.compositePaths) blend=\(direct.stats.newBlends) sym=\(direct.stats.symbolInstances) contentId=\(direct.stats.contentIdPaths)", category: .general)
            let metadata = VectorImportMetadata(
                originalFormat: .svg,
                documentSize: direct.pageSize,
                viewBoxSize: nil,
                colorSpace: "RGB",
                units: .points,
                dpi: 72.0,
                layerCount: 1,
                shapeCount: direct.shapes.count,
                textObjectCount: 0,
                importDate: Date(),
                sourceApplication: "FreeHand (direct)",
                documentVersion: nil,
                inkpenMetadata: nil
            )
            return VectorImportResult(
                success: true,
                shapes: direct.shapes,
                metadata: metadata,
                errors: [],
                warnings: [],
                layers: direct.layers,
                groupShapeIDs: direct.groupShapeIDs
            )
        } catch FreeHandImportError.notSupported {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.parsingError("Not a supported FreeHand file (libfreehand handles FH3 + FH5-FH11)", line: nil)],
                warnings: []
            )
        } catch {
            Log.error("❌ FreeHand import failed: \(error)", category: .error)
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.parsingError("FreeHand import failed: \(error.localizedDescription)", line: nil)],
                warnings: []
            )
        }
    }

    private func importRaster(from url: URL, raster: RasterFormat) async -> VectorImportResult {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),

              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.parsingError("Failed to open image", line: nil)],
                warnings: []
            )
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        var rectShape = VectorShape(
            name: "[IMG] \(url.lastPathComponent)",
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(size.width, 0)),
                .line(to: VectorPoint(size.width, size.height)),
                .line(to: VectorPoint(0, size.height)),
                .close
            ], isClosed: true),
            strokeStyle: StrokeStyle(color: .clear, width: 0, placement: .center),
            fillStyle: FillStyle(color: .clear),
            transform: .identity
        )
        rectShape.bounds = CGRect(origin: .zero, size: size)
        let shouldEmbed = ApplicationSettings.shared.embedImagesByDefault
        if shouldEmbed {
            let mutableData = NSMutableData()
            if let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, cgImage, nil)
                if CGImageDestinationFinalize(destination) {
                    rectShape.embeddedImageData = mutableData as Data
                }
            }
        } else {
            rectShape.linkedImagePath = url.path
            if let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                rectShape.linkedImageBookmarkData = bookmark
            }
            ImageContentRegistry.dequarantine(url)
        }
        let meta = VectorImportMetadata(
            originalFormat: .pdf,
            documentSize: size,
            viewBoxSize: nil,
            colorSpace: "sRGB",
            units: .pixels,
            dpi: 72,
            layerCount: 1,
            shapeCount: 1,
            textObjectCount: 0,
            importDate: Date(),
            sourceApplication: nil,
            documentVersion: nil,
            inkpenMetadata: nil
        )
        return VectorImportResult(success: true, shapes: [rectShape], metadata: meta, errors: [], warnings: [])
    }

    private func importPDF(from url: URL) async -> VectorImportResult {
        var errors: [VectorImportError] = []

        let warnings: [String] = []

        var shapes: [VectorShape] = []
        guard let pdfDocument = CGPDFDocument(url as CFURL) else {
            errors.append(.corruptedFile)
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
        guard let page = pdfDocument.page(at: 1) else {
            errors.append(.invalidStructure("No pages found"))
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
        var inkpenMetadata: String? = nil
        if let pdfDoc = page.document, let catalog = pdfDoc.catalog {
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
        let mediaBox = page.getBoxRect(.mediaBox)
        if let metadata = inkpenMetadata {
            let importMetadata = VectorImportMetadata(
                originalFormat: .pdf,
                documentSize: mediaBox.size,
                viewBoxSize: nil,
                colorSpace: "RGB",
                units: .points,
                dpi: 72.0,
                layerCount: 1,
                shapeCount: 0,
                textObjectCount: 0,
                importDate: Date(),
                sourceApplication: "Inkpen.io",
                documentVersion: nil,
                inkpenMetadata: metadata
            )
            return VectorImportResult(
                success: true,
                shapes: [],
                metadata: importMetadata,
                errors: errors,
                warnings: warnings
            )
        }
        do {
            let pdfContent = try extractPDFVectorContent(page)
            shapes = pdfContent.shapes
            let metadata = VectorImportMetadata(
                originalFormat: .pdf,
                documentSize: mediaBox.size,
                viewBoxSize: nil,
                colorSpace: "RGB",
                units: .points,
                dpi: 72.0,
                layerCount: 1,
                shapeCount: shapes.count,
                textObjectCount: pdfContent.textCount,
                importDate: Date(),
                sourceApplication: pdfContent.creator,
                documentVersion: pdfContent.version,
                inkpenMetadata: inkpenMetadata
            )
            return VectorImportResult(
                success: true,
                shapes: shapes,
                metadata: metadata,
                errors: errors,
                warnings: warnings
            )
        } catch {
            errors.append(.parsingError(error.localizedDescription, line: nil))
            Log.error("❌ PDF import failed: \(error)", category: .error)
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
    }

    private func createDefaultMetadata() -> VectorImportMetadata {
        return VectorImportMetadata(
            originalFormat: .svg,
            documentSize: CGSize(width: 8.5 * 72, height: 11 * 72),
            viewBoxSize: nil,
            colorSpace: "RGB",
            units: .points,
            dpi: 72.0,
            layerCount: 1,
            shapeCount: 0,
            textObjectCount: 0,
            importDate: Date(),
            sourceApplication: nil,
            documentVersion: nil,
            inkpenMetadata: nil
        )
    }
}
