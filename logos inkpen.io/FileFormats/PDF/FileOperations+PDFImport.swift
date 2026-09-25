import SwiftUI

extension FileOperations {

    static func importFromPDFData(_ data: Data) throws -> VectorDocument {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        do {
            try data.write(to: tempURL)
            let document = try importFromPDFSync(url: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            return document
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    static func importFromPDFSync(url: URL) throws -> VectorDocument {
        let semaphore = DispatchSemaphore(value: 0)

        var resultDocument: VectorDocument?
        var resultError: Error?
        Task {
            do {
                resultDocument = try await importFromPDF(url: url)
            } catch {
                resultError = error
            }
            semaphore.signal()
        }
        semaphore.wait()
        if let error = resultError {
            throw error
        }
        guard let document = resultDocument else {
            throw VectorImportError.parsingError("Failed to import PDF: Unknown error", line: nil)
        }
        return document
    }

    static func importFromPDF(url: URL) async throws -> VectorDocument {
        let result = await VectorImportManager.shared.importVectorFile(from: url)
        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown PDF import error"
            throw VectorImportError.parsingError("Failed to import PDF: \(errorMessage)", line: nil)
        }
        if let inkpenMetadata = result.metadata.inkpenMetadata {
            guard let inkpenData = Data(base64Encoded: inkpenMetadata) else {
                Log.error("❌ Failed to decode inkpen metadata from base64", category: .error)
                throw VectorImportError.parsingError("Invalid inkpen metadata encoding", line: nil)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let inkpenDocument = try? decoder.decode(VectorDocument.self, from: inkpenData) {
                Log.fileOperation("📦 Opened inkpen document from PDF, version: \(inkpenDocument.snapshot.formatVersion)", level: .info)
                return inkpenDocument
            }
            Log.fileOperation("⚠️ Current format failed, attempting legacy migration from PDF...", level: .warning)
            if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: inkpenData) {
                return migratedDocument
            }
            Log.error("❌ Failed to decode inkpen metadata from PDF", category: .error)
            throw VectorImportError.parsingError("Invalid inkpen metadata in PDF", line: nil)
        }
        let document = VectorDocument()
        let pdfDocumentSize = result.metadata.documentSize
        let canvasWidth = pdfDocumentSize.width
        let canvasHeight = pdfDocumentSize.height
        document.settings.width = canvasWidth / 72.0
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches
        let importedLayer = Layer(
            id: UUID(),
            name: "Imported PDF",
            objectIDs: [],
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .green
        )
        document.snapshot.layers.append(importedLayer)
        let targetLayer = document.snapshot.layers.count - 1
        for shape in result.shapes {
            var importedShape = shape
            importedShape.isLocked = false
            importedShape.isVisible = true
            if let imageData = importedShape.embeddedImageData {
                if let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
                   CGImageSourceCreateImageAtIndex(imageSource, 0, nil) == nil {
                    Log.error("PDF IMPORT: ❌ Failed to create CGImage from \(imageData.count) bytes of data", category: .error)
                    Log.error("❌ Could not create CGImage from embedded data for '\(importedShape.name)'", category: .error)
                } else if CGImageSourceCreateWithData(imageData as CFData, nil) == nil {
                    Log.error("PDF IMPORT: ❌ Failed to create image source from \(imageData.count) bytes of data", category: .error)
                    Log.error("❌ Could not create image from embedded data for '\(importedShape.name)'", category: .error)
                }
            }
            document.addShapeToUnifiedSystem(importedShape, layerIndex: targetLayer)
        }
        document.selectedLayerIndex = targetLayer
        return document
    }
}
