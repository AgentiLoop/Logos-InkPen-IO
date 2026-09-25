import SwiftUI
import AppKit
import ImageIO
import Darwin

enum ImageContentRegistry {

    private static let quarantineAttribute = "com.apple.quarantine"

    public static func dequarantine(_ url: URL) {
        _ = url.path.withCString { removexattr($0, quarantineAttribute, 0) }
    }

    private static func isXMLPayload(_ data: Data) -> Bool {
        guard data.count >= 5 else { return false }
        var offset = 0
        if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
            offset = 3
        }
        while offset < data.count && (data[offset] == 0x20 || data[offset] == 0x09 || data[offset] == 0x0A || data[offset] == 0x0D) {
            offset += 1
        }
        guard offset + 1 < data.count else { return false }
        if data[offset] == 0x3C {
            let next = data[offset + 1]
            return next == 0x3F || next == 0x73 || next == 0x53 || next == 0x21
        }
        return false
    }

    static func register(image: CGImage, for shapeID: UUID, in document: VectorDocument) {
        document.imageStorage[shapeID] = image
    }

    static func image(for shapeID: UUID, in document: VectorDocument) -> CGImage? {
        return document.imageStorage[shapeID]
    }

    static func containsImage(_ shape: VectorShape, in document: VectorDocument) -> Bool {
        return document.imageStorage[shape.id] != nil
    }

    @discardableResult
    static func hydrateImageIfAvailable(for shape: VectorShape, in document: VectorDocument) -> CGImage? {
        if let existing = document.imageStorage[shape.id] {
            return existing
        }
        var loadedCGImage: CGImage? = nil
        if let data = shape.embeddedImageData, !isXMLPayload(data),
           let imageSource = CGImageSourceCreateWithData(data as CFData, nil),

           let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            loadedCGImage = cgImage
        }
        else if shape.linkedImageBookmarkData != nil || shape.linkedImagePath != nil {
            func loadFromURL(_ cfurl: CFURL) -> CGImage? {
                guard let imageSource = CGImageSourceCreateWithURL(cfurl, nil),
                      let sourceCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                    return nil
                }
                let width = sourceCGImage.width
                let height = sourceCGImage.height
                let colorSpace = sourceCGImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
                if let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    ctx.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                    return ctx.makeImage() ?? sourceCGImage
                }
                return sourceCGImage
            }
            if let bookmark = shape.linkedImageBookmarkData {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    let started = url.startAccessingSecurityScopedResource()
                    defer { if started { url.stopAccessingSecurityScopedResource() } }
                    dequarantine(url)
                    loadedCGImage = loadFromURL(url as CFURL)
                }
            }
            if loadedCGImage == nil, let path = shape.linkedImagePath {
                let fileURL = URL(fileURLWithPath: path)
                dequarantine(fileURL)
                loadedCGImage = loadFromURL(fileURL as CFURL)
            }
        }
        if let cgImage = loadedCGImage {
            document.imageStorage[shape.id] = cgImage
            return cgImage
        }
        return nil
    }

    static func setBaseDirectory(_ url: URL?, for document: VectorDocument) {
        document.baseDirectoryURL = url
    }

    static func remove(for shapeID: UUID, in document: VectorDocument) {
        document.imageStorage.removeValue(forKey: shapeID)
    }

    static func cleanup(keepingShapes shapeIDs: Set<UUID>, in document: VectorDocument) {
        let keysToRemove = document.imageStorage.keys.filter { !shapeIDs.contains($0) }
        for key in keysToRemove {
            document.imageStorage.removeValue(forKey: key)
        }
    }

    static func clearAll(in document: VectorDocument) {
        document.imageStorage.removeAll()
    }

    static func storageSize(in document: VectorDocument) -> Int {
        return document.imageStorage.count
    }
}
