import SwiftUI
import UniformTypeIdentifiers

struct InkpenDocument: FileDocument {
    var document: VectorDocument

    static var readableContentTypes: [UTType] { [.inkpen, .svg, .pdf, .freehandDocument, .encapsulatedPostScript] }
    static var writableContentTypes: [UTType] { [.inkpen, .svg, .pdf] }

    private static let freehandExtensions: Set<String> = [
        "fh", "fh1", "fh2", "fh3", "fh4", "fh5", "fh6", "fh7", "fh8", "fh9",
        "fh10", "fh11", "fhmx", "ft11", "ftmx", "eps"
    ]

    init() {
        self.document = VectorDocument()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            Log.error("❌ InkpenDocument: regularFileContents is nil for \(configuration.file.preferredFilename ?? "?")", category: .error)
            throw CocoaError(.fileReadCorruptFile)
        }
        let fileExtension = configuration.file.preferredFilename?.components(separatedBy: ".").last?.lowercased()
        let contentType = configuration.contentType
        Log.info("📂 InkpenDocument.init: filename=\(configuration.file.preferredFilename ?? "?") ext=\(fileExtension ?? "nil") contentType=\(contentType.identifier) bytes=\(data.count)", category: .general)

        let hasFHMagic: Bool = {
            guard data.count >= 4 else { return false }
            let b0 = data[0], b1 = data[1], b2 = data[2]
            if b0 == UInt8(ascii: "A"), b1 == UInt8(ascii: "G"), b2 == UInt8(ascii: "D") { return true }
            if b0 == UInt8(ascii: "F"), b1 == UInt8(ascii: "H"), b2 == UInt8(ascii: "3") { return true }
            if b0 == UInt8(ascii: "F"), b1 == UInt8(ascii: "H"), b2 == UInt8(ascii: "D") { return true }
            if b0 == UInt8(ascii: "%"), b1 == UInt8(ascii: "!"), b2 == UInt8(ascii: "P") { return true }
            if b0 == 0x1c { return true }
            return false
        }()

        let extSaysFreehand: Bool = {
            if let ext = fileExtension, Self.freehandExtensions.contains(ext) { return true }
            if contentType == .freehandDocument { return true }
            if contentType.conforms(to: .freehandDocument) { return true }
            if contentType.identifier.contains("freehand") { return true }
            if contentType == .encapsulatedPostScript { return true }
            if contentType.conforms(to: .encapsulatedPostScript) { return true }
            return false
        }()
        let isFreehand = extSaysFreehand && hasFHMagic
        if fileExtension == "svg" {
            do {
                self.document = try FileOperations.importFromSVGData(data)
                var minX: CGFloat = .infinity
                var minY: CGFloat = .infinity
                for obj in self.document.snapshot.objects.values {
                    switch obj.objectType {
                    case .text(let shape),
                         .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape),
                         .guide(let shape):
                        if let textPos = shape.textPosition {
                            minX = min(minX, textPos.x)
                            minY = min(minY, textPos.y)
                        } else {
                            minX = min(minX, shape.bounds.minX)
                            minY = min(minY, shape.bounds.minY)
                        }
                    }
                }
                if minX != .infinity && minY != .infinity {
                }
                for unifiedObj in self.document.snapshot.objects.values {
                    if case .text(let shape) = unifiedObj.objectType {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }
            } catch {
                Log.error("❌ Failed to load SVG document: \(error)", category: .error)
                throw error
            }
        } else if isFreehand {
            do {
                let parsed = try FreeHandDirectImporter.parseToShapes(data: data)
                Log.info("📂 FH parsed: \(parsed.shapes.count) shapes, \(parsed.layers.count) layers, \(parsed.groupShapeIDs.count) groups, page \(Int(parsed.pageSize.width))×\(Int(parsed.pageSize.height))", category: .general)
                let newDoc = VectorDocument()
                if parsed.pageSize.width > 0 && parsed.pageSize.height > 0 {
                    newDoc.settings.setSizeInPoints(parsed.pageSize)
                    newDoc.onSettingsChanged()
                }
                let defaultLayerIndex = newDoc.snapshot.layers.firstIndex(where: { $0.name == "Layer 1" })
                    ?? newDoc.selectedLayerIndex
                    ?? (newDoc.snapshot.layers.count - 1)
                var parsedToDocLayer: [Int: Int] = [:]
                if parsed.layers.isEmpty {
                    parsedToDocLayer[0] = defaultLayerIndex
                } else {
                    for (idx, parsedLayer) in parsed.layers.enumerated() {
                        if idx == 0 {
                            newDoc.snapshot.layers[defaultLayerIndex].name = parsedLayer.name
                            parsedToDocLayer[idx] = defaultLayerIndex
                        } else {
                            newDoc.snapshot.layers.append(parsedLayer)
                            parsedToDocLayer[idx] = newDoc.snapshot.layers.count - 1
                        }
                    }
                }
                let fallbackLayer = parsedToDocLayer[0] ?? defaultLayerIndex

                var shapeIDToParsedLayer: [UUID: Int] = [:]
                for (idx, parsedLayer) in parsed.layers.enumerated() {
                    for id in parsedLayer.objectIDs { shapeIDToParsedLayer[id] = idx }
                }
                for shape in parsed.shapes {
                    let target = shapeIDToParsedLayer[shape.id].flatMap { parsedToDocLayer[$0] } ?? fallbackLayer
                    newDoc.addImportedShape(shape, to: target)
                }
                let allLayerIndices = Set(0..<newDoc.snapshot.layers.count)
                newDoc.triggerLayerUpdates(for: allLayerIndices)
                self.document = newDoc
            } catch {
                Log.error("❌ Failed to load FreeHand document: \(error) filename=\(configuration.file.preferredFilename ?? "?") ext=\(fileExtension ?? "nil") bytes=\(data.count)", category: .error)
                throw error
            }
        } else if fileExtension == "pdf" {
            do {
                self.document = try FileOperations.importFromPDFData(data)
                for unifiedObj in self.document.snapshot.objects.values {
                    if case .text(let shape) = unifiedObj.objectType {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }
            } catch {
                Log.error("❌ Failed to load PDF document: \(error)", category: .error)
                throw error
            }
        } else {
            do {
                self.document = try FileOperations.importFromJSONData(data)
                for unifiedObj in self.document.snapshot.objects.values {
                    if case .text(let shape) = unifiedObj.objectType {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                }
            } catch {
                Log.error("❌ Failed to load JSON document: \(error)", category: .error)
                throw error
            }
        }
        self.document.cleanupOrphanedObjects()
        MemoryDiag.checkpoint("InkpenDocument.init DONE (\(configuration.file.preferredFilename ?? "?"))")
        MemoryDiag.dumpObjects(self.document)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        dequarantineLinkedImages()
        if configuration.contentType == .svg ||
            configuration.contentType.conforms(to: .svg) ||
           configuration.contentType.identifier.contains("svg") {
            do {
                let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: false, textRenderingMode: .lines, includeInkpenData: true)
                let data = svgContent.data(using: .utf8) ?? Data()
                return FileWrapper(regularFileWithContents: data)
            } catch {
                Log.error("❌ Failed to save SVG document: \(error)", category: .error)
                throw error
            }
        } else if configuration.contentType == .pdf ||
                  configuration.contentType.conforms(to: .pdf) ||
                  configuration.contentType.identifier.contains("pdf") {
            do {
                let pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: false, textRenderingMode: .lines, includeInkpenData: true, includeBackground: false)
                return FileWrapper(regularFileWithContents: pdfData)
            } catch {
                Log.error("❌ Failed to save PDF document: \(error)", category: .error)
                throw error
            }
        } else {
            do {
                let data = try FileOperations.exportToJSONData(document)
                return FileWrapper(regularFileWithContents: data)
            } catch {
                Log.error("❌ Failed to save JSON document: \(error)", category: .error)
                throw error
            }
        }
    }

    private func dequarantineLinkedImages() {
        for obj in document.snapshot.objects.values {
            let shape: VectorShape
            switch obj.objectType {
            case .shape(let s), .image(let s), .clipGroup(let s), .clipMask(let s), .group(let s), .warp(let s), .guide(let s):
                shape = s
            case .text(let s):
                shape = s
            }
            if let path = shape.linkedImagePath {
                ImageContentRegistry.dequarantine(URL(fileURLWithPath: path))
            }
            if shape.isGroup || shape.isClippingGroup {
                dequarantineGroupImages(shape)
            }
        }
    }

    private func dequarantineGroupImages(_ shape: VectorShape) {
        for child in shape.groupedShapes {
            if let path = child.linkedImagePath {
                ImageContentRegistry.dequarantine(URL(fileURLWithPath: path))
            }
            if child.isGroup || child.isClippingGroup {
                dequarantineGroupImages(child)
            }
        }
        for memberID in shape.memberIDs {
            guard let obj = document.snapshot.objects[memberID] else { continue }
            let childShape = obj.shape
            if let path = childShape.linkedImagePath {
                ImageContentRegistry.dequarantine(URL(fileURLWithPath: path))
            }
            if childShape.isGroup || childShape.isClippingGroup {
                dequarantineGroupImages(childShape)
            }
        }
    }
}
