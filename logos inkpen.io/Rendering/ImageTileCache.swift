import Foundation
import AppKit
import ImageIO
import simd

typealias TileCoordinate = SIMD2<Int>

class ImageTileCache {
    static let shared = ImageTileCache()

    private init() {}

    func visibleTiles(imageRect: CGRect, viewportRect: CGRect, imageSize: CGSize, canvasSize: CGSize, tileSize: Int) -> [(coord: TileCoordinate, rect: CGRect)] {
        let currentTileSize = tileSize
        let numCols = Int(ceil(imageSize.width / CGFloat(currentTileSize)))
        let numRows = Int(ceil(imageSize.height / CGFloat(currentTileSize)))

        var tiles: [(TileCoordinate, CGRect)] = []
        for row in 0..<numRows {
            for col in 0..<numCols {
                let tileX = CGFloat(col * currentTileSize)
                let tileY = CGFloat(row * currentTileSize)
                let tileW = min(CGFloat(currentTileSize), imageSize.width - tileX)
                let tileH = min(CGFloat(currentTileSize), imageSize.height - tileY)
                let tileRect = CGRect(x: tileX, y: tileY, width: tileW, height: tileH)
                tiles.append((SIMD2(col, row), tileRect))
            }
        }
        return tiles
    }

    func getSourceImage(from imageData: Data, quality: Double, shapeID: UUID) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,

              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        let maxDimension = max(width, height)
        let targetPixelSize = CGFloat(maxDimension) * quality
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    func getSourceImage(from url: URL, quality: Double, shapeID: UUID) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,

              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        let maxDimension = max(width, height)
        let targetPixelSize = CGFloat(maxDimension) * quality
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
}
