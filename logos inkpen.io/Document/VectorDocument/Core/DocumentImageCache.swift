import CoreGraphics
import Foundation

/// Decoded images for the document's image shapes, keyed by shape ID.
struct DocumentImageCache {
    var images: [UUID: CGImage] = [:]
    var baseDirectoryURL: URL? = nil
    var lastDrawnHash: [UUID: Int] = [:]

    mutating func removeAll() {
        images.removeAll()
        lastDrawnHash.removeAll()
    }
}
