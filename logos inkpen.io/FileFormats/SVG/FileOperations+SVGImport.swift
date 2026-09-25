import SwiftUI

extension FileOperations {

    static func importFromSVGData(_ data: Data) throws -> VectorDocument {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).svg")
        try data.write(to: tempURL)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        return try openSVGFile(url: tempURL)
    }

    static func openSVGFile(url: URL) throws -> VectorDocument {
        let document = VectorDocument(settings: DocumentSettings())
        let objectsToKeep = document.snapshot.objects.filter { (_, obj) in
            if case .shape(let shape) = obj.objectType {
                return shape.name == "Canvas Background" || shape.name == "Pasteboard Background"
            }
            return false
        }
        document.snapshot.objects = objectsToKeep
        let result = VectorImportManager.shared.importSVGWithExtremeValueHandling(from: url)
        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }
        if let inkpenMetadata = result.metadata.inkpenMetadata {
            guard let inkpenData = Data(base64Encoded: inkpenMetadata) else {
                Log.error("❌ Failed to decode inkpen metadata from base64", category: .error)
                throw VectorImportError.parsingError("Invalid inkpen metadata encoding", line: nil)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let inkpenDocument = try? decoder.decode(VectorDocument.self, from: inkpenData) {
                Log.fileOperation("📦 Opened inkpen document from SVG, version: \(inkpenDocument.snapshot.formatVersion)", level: .info)
                FileOperations.removeLegacyBackgroundObjects(from: inkpenDocument)
                return inkpenDocument
            }
            Log.fileOperation("⚠️ Current format failed, attempting legacy migration from SVG...", level: .warning)
            if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: inkpenData) {
                return migratedDocument
            }
            Log.error("❌ Failed to decode inkpen metadata from SVG", category: .error)
            throw VectorImportError.parsingError("Invalid inkpen metadata in SVG", line: nil)
        }
        let metadata = result.metadata
        let docSize = metadata.documentSize
        if let viewBoxSize = metadata.viewBoxSize {
            let widthRatio = docSize.width / viewBoxSize.width
            let heightRatio = docSize.height / viewBoxSize.height
            if abs(widthRatio - (96.0/72.0)) < 0.1 && abs(heightRatio - (96.0/72.0)) < 0.1 {
                document.settings.width = viewBoxSize.width / 72.0
                document.settings.height = viewBoxSize.height / 72.0
            } else {
                document.settings.width = docSize.width / 72.0
                document.settings.height = docSize.height / 72.0
            }
        } else {
            document.settings.width = docSize.width / 72.0
            document.settings.height = docSize.height / 72.0
        }
        let importedLayer = Layer(
            id: UUID(),
            name: "Imported SVG",
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .green
        )
        document.snapshot.layers.append(importedLayer)
        let targetLayer = document.snapshot.layers.count - 1

        var clippingMasks: [UUID: (mask: VectorShape, clippedShapes: [VectorShape])] = [:]
        var standaloneShapes: [VectorShape] = []
        for shape in result.shapes {
            autoreleasepool {
                if shape.isClippingPath {
                    if clippingMasks[shape.id] == nil {
                        clippingMasks[shape.id] = (mask: shape, clippedShapes: [])
                    } else {
                        clippingMasks[shape.id]?.mask = shape
                    }
                } else if let clipId = shape.clippedByShapeID {
                    if clippingMasks[clipId] == nil {
                        clippingMasks[clipId] = (mask: VectorShape(name: "Placeholder", path: VectorPath(elements: [])), clippedShapes: [shape])
                    } else {
                        clippingMasks[clipId]?.clippedShapes.append(shape)
                    }
                } else {

                    let shouldSkip: Bool = {
                        let tempObject = VectorObject(shape: shape, layerIndex: 0)
                        switch tempObject.objectType {
                        case .text:
                            let textContent = shape.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            return textContent.isEmpty
                        case .group, .clipGroup:
                            return shape.memberIDs.isEmpty && shape.groupedShapes.isEmpty
                        case .image:
                            if let data = shape.embeddedImageData {
                                if data.count < 16 || SVGParser.looksLikeXML(data) { return true }
                                return false
                            }
                            if shape.linkedImagePath != nil { return false }
                            return true
                        case .shape, .warp, .clipMask, .guide:
                            return shape.path.elements.isEmpty
                        }
                    }()
                    if !shouldSkip {
                        standaloneShapes.append(shape)
                    }
                }
            }
        }
        for shape in standaloneShapes {
            autoreleasepool {
                installShapeRespectingGroups(shape, layerIndex: targetLayer, document: document)
            }
        }
        for (_, maskGroup) in clippingMasks {
            autoreleasepool {
                guard maskGroup.mask.name != "Placeholder" else { return }
                for clippedShape in maskGroup.clippedShapes {
                    document.addShapeToUnifiedSystem(clippedShape, layerIndex: targetLayer)
                }
                document.addShapeToUnifiedSystem(maskGroup.mask, layerIndex: targetLayer)
            }
        }
        document.selectedLayerIndex = targetLayer
        FileOperations.removeLegacyBackgroundObjects(from: document)
        return document
    }

    private static func installShapeRespectingGroups(_ shape: VectorShape, layerIndex: Int, document: VectorDocument) {
        if (shape.isGroup || shape.isClippingGroup) && !shape.groupedShapes.isEmpty {
            var container = shape
            var memberIDs: [UUID] = container.memberIDs
            for child in container.groupedShapes {
                installGroupMemberIntoSnapshot(child, layerIndex: layerIndex, document: document)
                memberIDs.append(child.id)
            }
            container.memberIDs = memberIDs
            container.groupedShapes = []
            document.addShapeToUnifiedSystem(container, layerIndex: layerIndex)
        } else {
            document.addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        }
    }

    private static func installGroupMemberIntoSnapshot(_ shape: VectorShape, layerIndex: Int, document: VectorDocument) {
        var toInstall = shape
        if (toInstall.isGroup || toInstall.isClippingGroup) && !toInstall.groupedShapes.isEmpty {
            var memberIDs: [UUID] = toInstall.memberIDs
            for child in toInstall.groupedShapes {
                installGroupMemberIntoSnapshot(child, layerIndex: layerIndex, document: document)
                memberIDs.append(child.id)
            }
            toInstall.memberIDs = memberIDs
            toInstall.groupedShapes = []
        }
        let objectType = VectorObject.determineType(for: toInstall)
        let vectorObject = VectorObject(id: toInstall.id, layerIndex: layerIndex, objectType: objectType)
        document.snapshot.objects[toInstall.id] = vectorObject
    }
}
