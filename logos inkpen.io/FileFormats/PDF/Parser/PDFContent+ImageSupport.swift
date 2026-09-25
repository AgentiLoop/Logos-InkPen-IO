import SwiftUI
import PDFKit
import AppKit

extension PDFCommandParser {

    func processImageXObject(name: String, xObjectStream: CGPDFStreamRef, currentTransform: CGAffineTransform) {
        if hasClipOperatorPending {
            createClippingPathFromPending()
        }
        guard let streamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            Log.error("PDF: Failed to get stream dictionary for image '\(name)'", category: .error)
            return
        }
        var width: CGPDFInteger = 0
        var height: CGPDFInteger = 0
        guard CGPDFDictionaryGetInteger(streamDict, "Width", &width),
              CGPDFDictionaryGetInteger(streamDict, "Height", &height) else {
            Log.error("PDF: Failed to get image dimensions for '\(name)'", category: .error)
            return
        }
        var sMaskRef: CGPDFStreamRef?

        let hasSMask = CGPDFDictionaryGetStream(streamDict, "SMask", &sMaskRef)

        var maskData: Data?
        if hasSMask, let sMask = sMaskRef {
            var maskFormat: CGPDFDataFormat = .raw
            if let sMaskData = CGPDFStreamCopyData(sMask, &maskFormat) {
                maskData = sMaskData as Data
                hasUpcomingTransparentImage = true
            }
        }
        var colorSpaceObj: CGPDFObjectRef?
        var colorSpaceName: String = "Unknown"
        var isIndexedColor = false
        var colorPalette: Data?
        if CGPDFDictionaryGetObject(streamDict, "ColorSpace", &colorSpaceObj), let csObj = colorSpaceObj {
            var namePtr: UnsafePointer<CChar>?
            if CGPDFObjectGetValue(csObj, .name, &namePtr), let name = namePtr {
                colorSpaceName = String(cString: name)
            } else if CGPDFObjectGetValue(csObj, .array, &colorSpaceObj) {
                var arrayRef: CGPDFArrayRef?
                if CGPDFObjectGetValue(csObj, .array, &arrayRef), let array = arrayRef {
                    var firstElement: CGPDFObjectRef?
                    if CGPDFArrayGetObject(array, 0, &firstElement), let first = firstElement {
                        if CGPDFObjectGetValue(first, .name, &namePtr), let name = namePtr {
                            colorSpaceName = String(cString: name)
                            isIndexedColor = (colorSpaceName == "Indexed")
                            if isIndexedColor && CGPDFArrayGetCount(array) >= 4 {
                                var paletteString: CGPDFStringRef?
                                var paletteStream: CGPDFStreamRef?
                                if CGPDFArrayGetString(array, 3, &paletteString), let palString = paletteString {
                                    let length = CGPDFStringGetLength(palString)
                                    if let bytePtr = CGPDFStringGetBytePtr(palString) {
                                        colorPalette = Data(bytes: bytePtr, count: length)
                                    }
                                } else if CGPDFArrayGetStream(array, 3, &paletteStream), let palStream = paletteStream {
                                    var palFormat: CGPDFDataFormat = .raw
                                    if let palData = CGPDFStreamCopyData(palStream, &palFormat) {
                                        colorPalette = palData as Data
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        var format: CGPDFDataFormat = .raw
        guard let imageData = CGPDFStreamCopyData(xObjectStream, &format) else {
            Log.error("PDF: Failed to extract image data for '\(name)'", category: .error)
            return
        }
        let nsData = imageData as NSData
        let debugPath = "/Users/toddbruss/Documents/pdf_raw_image_\(name)_\(width)x\(height).dat"
        try? (nsData as Data).write(to: URL(fileURLWithPath: debugPath))
        var imageShape = VectorShape(name: "Image \(name)", path: VectorPath(elements: []))
        if format == .jpegEncoded {
            imageShape.embeddedImageData = nsData as Data
        } else if format == .JPEG2000 {
            imageShape.embeddedImageData = nsData as Data
        } else {
            let totalPixels = width * height
            let bytesPerPixel = nsData.length / totalPixels
            if bytesPerPixel == 1 && isIndexedColor, let palette = colorPalette {
                if let gpuRGBAData = PDFMetalProcessor.shared.convertIndexedToRGBA(
                    indexData: nsData as Data,
                    paletteData: palette,
                    maskData: maskData,
                    width: width,
                    height: height
                ) {
                    let rgbaData = gpuRGBAData
                let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_indexed_rgba_image_\(name)_\(width)x\(height).dat"
                try? rgbaData.write(to: URL(fileURLWithPath: rgbaDebugPath))
                if let pngData = createPNGData(from: rgbaData, width: width, height: height, hasAlpha: hasSMask) {
                    imageShape.embeddedImageData = pngData
                    let pngDebugPath = "/Users/toddbruss/Documents/pdf_indexed_final_image_\(name).png"
                    try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                } else {
                    imageShape.embeddedImageData = rgbaData
                }
                } else {
                    Log.warning("⚠️ Using CPU fallback for indexed->RGBA conversion", category: .general)
                    guard let rgbaData = NSMutableData(capacity: width * height * 4) else {
                        Log.error("PDF: Failed to allocate RGBA data for indexed image", category: .error)
                        return
                    }
                    let indexBytes = nsData.bytes.assumingMemoryBound(to: UInt8.self)
                    let paletteBytes = palette.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
                    guard let paletteBase = paletteBytes.baseAddress else {
                        Log.error("PDF: Failed to get palette base address", category: .error)
                        return
                    }
                    let paletteEntries = palette.count / 3
                    for i in 0..<(width * height) {
                        let paletteIndex = Int(indexBytes[i])
                        if paletteIndex < paletteEntries {
                            let paletteOffset = paletteIndex * 3
                            rgbaData.append(paletteBase + paletteOffset, length: 3)
                        } else {
                            var black: [UInt8] = [0, 0, 0]
                            rgbaData.append(&black, length: 3)
                        }
                        var alpha: UInt8
                        if let maskBytes = maskData?.withUnsafeBytes({ $0.bindMemory(to: UInt8.self) }), i < (maskData?.count ?? 0) {
                            alpha = maskBytes[i]
                        } else {
                            alpha = 255
                        }
                        rgbaData.append(&alpha, length: 1)
                    }
                    let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_indexed_rgba_image_\(name)_\(width)x\(height).dat"
                    try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))
                    if let pngData = createPNGData(from: rgbaData as Data, width: width, height: height, hasAlpha: hasSMask) {
                        imageShape.embeddedImageData = pngData
                        let pngDebugPath = "/Users/toddbruss/Documents/pdf_indexed_final_image_\(name).png"
                        try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                    } else {
                        imageShape.embeddedImageData = rgbaData as Data
                    }
                }
            }
            else if bytesPerPixel == 3 {
                if let gpuRGBAData = PDFMetalProcessor.shared.convertRGBtoRGBA(
                    rgbData: nsData as Data,
                    maskData: maskData,
                    width: width,
                    height: height
                ) {
                    let rgbaData = gpuRGBAData
                let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_rgba_image_\(name)_\(width)x\(height).dat"
                try? rgbaData.write(to: URL(fileURLWithPath: rgbaDebugPath))
                if let pngData = createPNGData(from: rgbaData, width: width, height: height, hasAlpha: hasSMask) {
                    imageShape.embeddedImageData = pngData
                    let pngDebugPath = "/Users/toddbruss/Documents/pdf_final_image_\(name).png"
                    try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                } else {
                    imageShape.embeddedImageData = rgbaData
                }
                } else {
                    Log.warning("⚠️ Using CPU fallback for RGB->RGBA conversion", category: .general)
                    guard let rgbaData = NSMutableData(capacity: width * height * 4) else {
                        Log.error("PDF: Failed to allocate RGBA data", category: .error)
                        return
                    }
                    let sourceBytes = nsData.bytes.assumingMemoryBound(to: UInt8.self)
                    let maskBytes = maskData?.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
                    for i in 0..<(width * height) {
                        let srcOffset = i * 3
                        rgbaData.append(sourceBytes + srcOffset, length: 3)
                        var alpha: UInt8
                        if let maskBytes = maskBytes, i < (maskData?.count ?? 0) {
                            alpha = maskBytes[i]
                        } else {
                            alpha = 255
                        }
                        rgbaData.append(&alpha, length: 1)
                    }
                    let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_rgba_image_\(name)_\(width)x\(height).dat"
                    try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))
                    if let pngData = createPNGData(from: rgbaData as Data, width: width, height: height, hasAlpha: hasSMask) {
                        imageShape.embeddedImageData = pngData
                        let pngDebugPath = "/Users/toddbruss/Documents/pdf_final_image_\(name).png"
                        try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                    } else {
                        imageShape.embeddedImageData = rgbaData as Data
                    }
                }
            } else if bytesPerPixel == 4 {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                if let context = CGContext(
                    data: UnsafeMutableRawPointer(mutating: nsData.bytes),
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) {
                    if let cgImage = context.makeImage() {
                        let pngData = NSMutableData()
                        if let destination = CGImageDestinationCreateWithData(
                            pngData as CFMutableData,
                            "public.png" as CFString,
                            1,
                            nil
                        ) {
                            CGImageDestinationAddImage(destination, cgImage, nil)
                            if CGImageDestinationFinalize(destination) {
                                imageShape.embeddedImageData = pngData as Data
                            } else {
                                imageShape.embeddedImageData = nsData as Data
                            }
                        } else {
                            imageShape.embeddedImageData = nsData as Data
                        }
                    } else {
                        imageShape.embeddedImageData = nsData as Data
                    }
                } else {
                    imageShape.embeddedImageData = nsData as Data
                }
            } else {
                if let imageSource = CGImageSourceCreateWithData(nsData as CFData, nil),
                   CGImageSourceCreateImageAtIndex(imageSource, 0, nil) != nil {
                    imageShape.embeddedImageData = nsData as Data
                } else {
                    imageShape.embeddedImageData = nsData as Data
                    Log.warning("PDF: WARNING - Storing raw data as-is, may not render", category: .general)
                }
            }
        }
        let unitRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        let pdfRect = unitRect.applying(currentTransform).standardized
        let flippedY = pageSize.height - pdfRect.maxY
        let finalRect = CGRect(x: pdfRect.minX, y: flippedY, width: pdfRect.width, height: pdfRect.height)
        if hasUpcomingTransparentImage {
            transparentImageBounds = finalRect
        }
        var imagePath = VectorPath(elements: [])
        imagePath.elements.append(.move(to: VectorPoint(finalRect.minX, finalRect.minY)))
        imagePath.elements.append(.line(to: VectorPoint(finalRect.maxX, finalRect.minY)))
        imagePath.elements.append(.line(to: VectorPoint(finalRect.maxX, finalRect.maxY)))
        imagePath.elements.append(.line(to: VectorPoint(finalRect.minX, finalRect.maxY)))
        imagePath.elements.append(.close)
        imageShape.path = imagePath
        imageShape.bounds = finalRect
        imageShape.transform = .identity
        if isInsideClippingPath {
            if let clipId = currentClippingPathId {
                imageShape.clippedByShapeID = clipId
            }
        }
        imageShape.opacity = Double(currentFillOpacity)
        shapes.append(imageShape)
        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            pendingClippingPath = nil
            isInsideClippingPath = false
            currentClippingPathId = nil
            isInCompoundPath = false
            compoundPathParts.removeAll()
            moveToCount = 0
            hasClipOperatorPending = false
            clipOperatorPath.removeAll()
        }
        if hasUpcomingTransparentImage {
            hasUpcomingTransparentImage = false
        }
    }

    func handleXObjectWithImageSupport(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("PDF: Failed to read XObject name", category: .error)
            return
        }
        guard let namePtr else {
            Log.error("PDF: XObject name pointer was nil", category: .error)
            return
        }
        let name = String(cString: namePtr)
        processXObjectWithImageSupport(name: name)
    }

    func processXObjectWithImageSupport(name: String) {
        guard let page = currentPage,

              let resourceDict = page.dictionary else {
            return
        }
        var resourcesRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),

              let resourcesDict = resourcesRef else {
            return
        }
        var xObjectDictRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),

              let xObjectDict = xObjectDictRef else {
            return
        }
        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFDictionaryGetStream(xObjectDict, name, &xObjectStreamRef),

              let xObjectStream = xObjectStreamRef else {
            return
        }
        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            return
        }
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),

              let subtypeName = subtypeNamePtr else {
            return
        }
        let subtype = String(cString: subtypeName)
        switch subtype {
        case "Form":
            var xObjectResourcesDict: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
            } else {
                xObjectResourcesDict = resourcesDict
            }
            parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)
        case "Image":
            processImageXObject(name: name, xObjectStream: xObjectStream, currentTransform: currentTransformMatrix)
        default:
            break
        }
    }
}

extension PDFCommandParser {

    func handleClipOperator() {
        if isInCompoundPath || !compoundPathParts.isEmpty {
            hasClipOperatorPending = true
            if !currentPath.isEmpty {
                compoundPathParts.append(currentPath)
            }
            clipOperatorPath = currentPath
            return
        }
        if !currentPath.isEmpty {
            hasClipOperatorPending = true
            clipOperatorPath = currentPath
            return
        }
        if !currentPath.isEmpty {
            var pathElements: [PathElement] = []
            for cmd in currentPath {
                switch cmd {
                case .moveTo(let pt):
                    pathElements.append(.move(to: VectorPoint(pt.x, pageSize.height - pt.y)))
                case .lineTo(let pt):
                    pathElements.append(.line(to: VectorPoint(pt.x, pageSize.height - pt.y)))
                case .curveTo(let cp1, let cp2, let pt):
                    pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                              control1: VectorPoint(cp1.x, pageSize.height - cp1.y),
                                              control2: VectorPoint(cp2.x, pageSize.height - cp2.y)))
                case .quadCurveTo(let cp, let pt):
                    pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                              control1: VectorPoint(cp.x, pageSize.height - cp.y),
                                              control2: VectorPoint(cp.x, pageSize.height - cp.y)))
                case .rectangle(let rect):
                    let flippedMinY = pageSize.height - rect.maxY
                    let flippedMaxY = pageSize.height - rect.minY
                    pathElements.append(.move(to: VectorPoint(rect.minX, flippedMinY)))
                    pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMinY)))
                    pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMaxY)))
                    pathElements.append(.line(to: VectorPoint(rect.minX, flippedMaxY)))
                    pathElements.append(.close)
                case .closePath:
                    pathElements.append(.close)
                }
            }
            let clipPath = VectorPath(elements: pathElements)

            var clipShape = VectorShape(name: "Clipping Path", path: clipPath)
            clipShape.isClippingPath = true
            currentClippingPathId = clipShape.id
            isInsideClippingPath = true
            pendingClippingPath = clipShape
        }
    }

    func createClippingPathFromPending() {
        guard hasClipOperatorPending else { return }
        var allPathCommands: [[PathCommand]] = []
        if !compoundPathParts.isEmpty {
            allPathCommands = compoundPathParts
            if !clipOperatorPath.isEmpty {
                allPathCommands.append(clipOperatorPath)
            }
        } else if !clipOperatorPath.isEmpty {
            allPathCommands = [clipOperatorPath]
        } else {
            return
        }
        var pathElements: [PathElement] = []
        for pathCommands in allPathCommands {
            for cmd in pathCommands {
            switch cmd {
            case .moveTo(let pt):
                pathElements.append(.move(to: VectorPoint(pt.x, pageSize.height - pt.y)))
            case .lineTo(let pt):
                pathElements.append(.line(to: VectorPoint(pt.x, pageSize.height - pt.y)))
            case .curveTo(let cp1, let cp2, let pt):
                pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                          control1: VectorPoint(cp1.x, pageSize.height - cp1.y),
                                          control2: VectorPoint(cp2.x, pageSize.height - cp2.y)))
            case .quadCurveTo(let cp, let pt):
                pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                          control1: VectorPoint(cp.x, pageSize.height - cp.y),
                                          control2: VectorPoint(cp.x, pageSize.height - cp.y)))
            case .rectangle(let rect):
                let flippedMinY = pageSize.height - rect.maxY
                let flippedMaxY = pageSize.height - rect.minY
                pathElements.append(.move(to: VectorPoint(rect.minX, flippedMinY)))
                pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMinY)))
                pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMaxY)))
                pathElements.append(.line(to: VectorPoint(rect.minX, flippedMaxY)))
                pathElements.append(.close)
            case .closePath:
                pathElements.append(.close)
            }
            }
        }
        let clipPath = VectorPath(elements: pathElements)

        var clipShape = VectorShape(name: "Clipping Path", path: clipPath)
        clipShape.isClippingPath = true
        currentClippingPathId = clipShape.id
        isInsideClippingPath = true
        pendingClippingPath = clipShape
        hasClipOperatorPending = false
        clipOperatorPath.removeAll()
        if !compoundPathParts.isEmpty {
            compoundPathParts.removeAll()
            isInCompoundPath = false
            currentPath.removeAll()
        }
    }

    func resetClippingState() {
        if isInsideClippingPath {
            if let pendingClip = pendingClippingPath {
                shapes.append(pendingClip)
                pendingClippingPath = nil
            }
            isInsideClippingPath = false
            currentClippingPathId = nil
        }
    }

    func finalizeClippingGroup() {
        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            pendingClippingPath = nil
        }
        isInsideClippingPath = false
        currentClippingPathId = nil
        isInCompoundPath = false
        compoundPathParts.removeAll()
        moveToCount = 0
        hasClipOperatorPending = false
        clipOperatorPath.removeAll()
        currentPath.removeAll()
    }

    func saveGraphicsState() {
        let state = PDFGraphicsState(
            transformMatrix: currentTransformMatrix,
            simdTransformMatrix: simdTransformMatrix,
            fillOpacity: currentFillOpacity,
            strokeOpacity: currentStrokeOpacity,
            clippingPathId: currentClippingPathId,
            isInsideClippingPath: isInsideClippingPath,
            pendingClippingPath: pendingClippingPath
        )
        graphicsStateStack.append(state)
    }

    func restoreGraphicsState() {
        finalizeClippingGroup()
        guard !graphicsStateStack.isEmpty else {
            return
        }
        let state = graphicsStateStack.removeLast()
        currentTransformMatrix = state.transformMatrix
        simdTransformMatrix = state.simdTransformMatrix
        currentFillOpacity = state.fillOpacity
        currentStrokeOpacity = state.strokeOpacity
        currentClippingPathId = state.clippingPathId
        isInsideClippingPath = state.isInsideClippingPath
        pendingClippingPath = state.pendingClippingPath
    }
}

fileprivate func createPNGData(from rgbaData: Data, width: Int, height: Int, hasAlpha: Bool) -> Data? {
    let bytesPerPixel = 4
    let bitsPerComponent = 8
    let bytesPerRow = width * bytesPerPixel
    guard rgbaData.count >= width * height * bytesPerPixel else {
        return nil
    }
    let flippedData = NSMutableData(length: rgbaData.count)!
    let src = (rgbaData as NSData).bytes.bindMemory(to: UInt8.self, capacity: rgbaData.count)
    let dst = flippedData.mutableBytes.bindMemory(to: UInt8.self, capacity: rgbaData.count)
    for row in 0..<height {
        memcpy(dst + row * bytesPerRow, src + (height - 1 - row) * bytesPerRow, bytesPerRow)
    }
    guard let provider = CGDataProvider(data: flippedData as CFData) else {
        return nil
    }
    guard let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bytesPerPixel * bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: hasAlpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        return nil
    }
    let pngData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        pngData as CFMutableData,
        "public.png" as CFString,
        1,
        nil
    ) else {
        return nil
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    return pngData as Data
}
