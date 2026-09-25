import SwiftUI
import Combine

extension FileOperations {

    static func exportToJSON(_ document: VectorDocument, url: URL) throws {
        let jsonData = try exportToJSONData(document)
        let baseDir = url.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDir, for: document)
        do {
            try jsonData.write(to: url)
        } catch {
            Log.error("❌ JSON export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }

    static func exportToJSONData(_ document: VectorDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let jsonData = try encoder.encode(document)
            return jsonData
        } catch {
            Log.error("❌ JSON data export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }

    static func importFromJSON(url: URL) throws -> VectorDocument {
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let document = try? decoder.decode(VectorDocument.self, from: jsonData) {
            Log.fileOperation("📦 Opened inkpen document version: \(document.snapshot.formatVersion)", level: .info)
            removeLegacyBackgroundObjects(from: document)
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent(), for: document)
            hydrateAllObjectImages(in: document)
            return document
        }
        Log.fileOperation("⚠️ Current format failed, attempting legacy migration...", level: .warning)
        if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: jsonData) {
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent(), for: migratedDocument)
            hydrateAllObjectImages(in: migratedDocument)
            return migratedDocument
        }
        Log.error("❌ JSON import failed: Unable to decode as current or legacy format", category: .error)
        throw VectorImportError.parsingError("Failed to import JSON: Unable to decode document", line: nil)
    }

    static func importFromJSONData(_ data: Data, sourceURL: URL? = nil) throws -> VectorDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let document = try? decoder.decode(VectorDocument.self, from: data) {
            removeLegacyBackgroundObjects(from: document)
            let baseDirectory = sourceURL?.deletingLastPathComponent()
            ImageContentRegistry.setBaseDirectory(baseDirectory, for: document)
            hydrateAllObjectImages(in: document)
            return document
        }
        Log.fileOperation("⚠️ Current format failed, attempting legacy migration...", level: .warning)
        if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: data) {
            let baseDirectory = sourceURL?.deletingLastPathComponent()
            ImageContentRegistry.setBaseDirectory(baseDirectory, for: migratedDocument)
            hydrateAllObjectImages(in: migratedDocument)
            return migratedDocument
        }
        Log.error("❌ JSON data import failed: Unable to decode as current or legacy format", category: .error)
        throw VectorImportError.parsingError("Failed to import JSON: Unable to decode document", line: nil)
    }

    private static func hydrateAllObjectImages(in document: VectorDocument) {
        for obj in document.snapshot.objects.values {
            let shape: VectorShape
            switch obj.objectType {
            case .shape(let s), .image(let s), .clipGroup(let s), .clipMask(let s), .group(let s), .warp(let s), .guide(let s):
                shape = s
            case .text(let s):
                shape = s
            }
            hydrateGroupImagesRecursive(shape, in: document)
        }
    }

    private static func hydrateGroupImagesRecursive(_ shape: VectorShape, in document: VectorDocument) {
        if shape.embeddedImageData != nil || shape.linkedImagePath != nil || shape.linkedImageBookmarkData != nil {
            ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
        }
        if shape.isGroup || shape.isClippingGroup {
            for child in shape.groupedShapes {
                hydrateGroupImagesRecursive(child, in: document)
            }
            for memberID in shape.memberIDs {
                if let obj = document.snapshot.objects[memberID] {
                    let childShape: VectorShape
                    switch obj.objectType {
                    case .shape(let s), .image(let s), .clipGroup(let s), .clipMask(let s), .group(let s), .warp(let s), .guide(let s):
                        childShape = s
                    case .text(let s):
                        childShape = s
                    }
                    hydrateGroupImagesRecursive(childShape, in: document)
                }
            }
        }
    }

    static func removeLegacyBackgroundObjects(from document: VectorDocument) {
        for layerIndex in 0..<document.snapshot.layers.count {
            var layer = document.snapshot.layers[layerIndex]
            var objectsToRemove: [UUID] = []
            for objectID in layer.objectIDs {
                guard let obj = document.snapshot.objects[objectID] else { continue }
                let shapeName: String?
                switch obj.objectType {
                case .shape(let shape), .text(let shape), .image(let shape),
                     .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape),
                     .guide(let shape):
                    shapeName = shape.name
                }
                if shapeName == "Canvas Background" || shapeName == "Pasteboard Background" {
                    objectsToRemove.append(objectID)
                }
            }
            if !objectsToRemove.isEmpty {
                layer.objectIDs.removeAll { objectsToRemove.contains($0) }
                document.snapshot.layers[layerIndex] = layer
                for objectID in objectsToRemove {
                    document.snapshot.objects.removeValue(forKey: objectID)
                }
                Log.fileOperation("🧹 Removed \(objectsToRemove.count) legacy background object(s) from layer '\(layer.name)'", level: .info)
            }
        }
    }
}
