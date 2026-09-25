import SwiftUI

extension FileOperations {

    static func exportSingleIcon(_ document: VectorDocument, url: URL, pixelSize: Int) throws {
        let artworkBounds = calculateArtworkBounds(from: document)
        let artworkSize = artworkBounds.size
        let scaleX = CGFloat(pixelSize) / artworkSize.width
        let scaleY = CGFloat(pixelSize) / artworkSize.height
        let scale = min(scaleX, scaleY)
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: ColorManager.shared.workingCGColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap context for \(pixelSize)×\(pixelSize)", line: nil)
        }
        context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        let scaledWidth = artworkSize.width * scale
        let scaledHeight = artworkSize.height * scale
        let offsetX = (CGFloat(pixelSize) - scaledWidth) / 2.0
        let offsetY = (CGFloat(pixelSize) - scaledHeight) / 2.0
        context.translateBy(x: offsetX, y: CGFloat(pixelSize) - offsetY)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -artworkBounds.minX, y: -artworkBounds.minY)
        for (index, layer) in document.snapshot.layers.enumerated() {
            if !layer.isVisible { continue }
            if index <= 1 || layer.name == "Guides" { continue }
            context.saveGState()
            if layer.blendMode != BlendMode.normal {
                context.setBlendMode(layer.blendMode.cgBlendMode)
            }
            context.setAlpha(layer.opacity)
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                drawShapeInPDF(shape, context: context, document: document)
            }
            context.restoreGState()
        }
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            drawTextInPDF(text, context: context)
        }
        try ColorExportManager.shared.exportFromContext(
            context,
            format: .png,
            colorSpace: .displayP3,
            to: url
        )
    }

    static func exportIconSet(_ document: VectorDocument, folderURL: URL) throws {
        let iconSizes: [Int] = [1024, 512, 256, 128, 64, 32, 16]
        let artworkBounds = calculateArtworkBounds(from: document)
        let artworkSize = artworkBounds.size
        for pixelSize in iconSizes {
            let filename = "icon_\(pixelSize)x\(pixelSize).png"
            let fileURL = folderURL.appendingPathComponent(filename)
            let scaleX = CGFloat(pixelSize) / artworkSize.width
            let scaleY = CGFloat(pixelSize) / artworkSize.height
            let scale = min(scaleX, scaleY)
            guard let context = CGContext(
                data: nil,
                width: pixelSize,
                height: pixelSize,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: ColorManager.shared.workingCGColorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                throw VectorImportError.parsingError("Failed to create bitmap context for \(pixelSize)x\(pixelSize)", line: nil)
            }
            context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
            let scaledWidth = artworkSize.width * scale
            let scaledHeight = artworkSize.height * scale
            let offsetX = (CGFloat(pixelSize) - scaledWidth) / 2.0
            let offsetY = (CGFloat(pixelSize) - scaledHeight) / 2.0
            context.translateBy(x: offsetX, y: CGFloat(pixelSize) - offsetY)
            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: -artworkBounds.minX, y: -artworkBounds.minY)
            for (index, layer) in document.snapshot.layers.enumerated() {
                if !layer.isVisible { continue }
                if index <= 1 || layer.name == "Guides" { continue }
                context.saveGState()
                if layer.blendMode != BlendMode.normal {
                    context.setBlendMode(layer.blendMode.cgBlendMode)
                }
                context.setAlpha(layer.opacity)
                let shapesInLayer = document.getShapesForLayer(index)
                for shape in shapesInLayer {
                    if !shape.isVisible { continue }
                    drawShapeInPDF(shape, context: context, document: document)
                }
                context.restoreGState()
            }
            document.forEachTextInOrder { text in
                if !text.isVisible { return }
                drawTextInPDF(text, context: context)
            }
            try ColorExportManager.shared.exportFromContext(
                context,
                format: .png,
                colorSpace: .displayP3,
                to: fileURL
            )
        }
    }

    private static func calculateArtworkBounds(from document: VectorDocument) -> CGRect {
        var bounds = CGRect.null
        for (index, layer) in document.snapshot.layers.enumerated() {
            if !layer.isVisible || index <= 1 || layer.name == "Guides" { continue }
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                let shapeBounds = shape.bounds
                bounds = bounds.isNull ? shapeBounds : bounds.union(shapeBounds)
            }
        }
        document.forEachTextInOrder { text in
            if text.isVisible {
                let textBounds = text.bounds
                bounds = bounds.isNull ? textBounds : bounds.union(textBounds)
            }
        }
        if bounds.isNull {
            bounds = CGRect(origin: .zero, size: document.settings.sizeInPoints)
        }
        return bounds
    }

    static func exportToPNGFromView(_ document: VectorDocument, url: URL, scale: CGFloat, includeBackground: Bool = true) throws {
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        guard outputSize.width > 0 && outputSize.height > 0 &&
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }
        let contentView = PNGExportView(document: document, scale: scale, includeBackground: includeBackground, outputSize: outputSize)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = CGRect(origin: .zero, size: outputSize)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.display()
        let colorSpace = ColorManager.shared.workingCGColorSpace
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let cgContext = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VectorImportError.parsingError("Failed to create CGContext", line: nil)
        }
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: cgContext, flipped: true)
        NSGraphicsContext.current = nsContext
        cgContext.translateBy(x: 0, y: outputSize.height)
        cgContext.scaleBy(x: 1, y: -1)
        hostingView.displayIfNeeded()
        hostingView.layer?.render(in: cgContext)
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = cgContext.makeImage() else {
            throw VectorImportError.parsingError("Failed to create CGImage", line: nil)
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw VectorImportError.parsingError("Failed to create PNG data", line: nil)
        }
        try pngData.write(to: url)
    }

    static func exportToPNG(_ document: VectorDocument, url: URL, scale: CGFloat, includeBackground: Bool = true) throws {
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        guard outputSize.width > 0 && outputSize.height > 0 &&
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }
        let colorSpace = ColorManager.shared.workingCGColorSpace
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap context", line: nil)
        }
        context.clear(CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: scale, y: -scale)
        for (index, layer) in document.snapshot.layers.enumerated() {
            if !layer.isVisible { continue }
            if index == 0 { continue }
            if !includeBackground && index == 1 { continue }
            if layer.name == "Guides" { continue }
            context.saveGState()
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            if layer.blendMode != BlendMode.normal {
                context.setBlendMode(layer.blendMode.cgBlendMode)
            }
            if layer.opacity < 1.0 {
                context.setAlpha(layer.opacity)
            }
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                drawShapeInPDF(shape, context: context, document: document)
            }
            context.endTransparencyLayer()
            context.restoreGState()
        }
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            drawTextInPDF(text, context: context)
        }
        try ColorExportManager.shared.exportFromContext(
            context,
            format: .png,
            colorSpace: .displayP3,
            to: url
        )
    }

    internal static func drawShapeInPDF(_ shape: VectorShape, context: CGContext, document: VectorDocument? = nil) {
        context.saveGState()
        context.setAlpha(shape.opacity)
        if !shape.transform.isIdentity {
            context.concatenate(shape.transform)
        }
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            for groupedShape in shape.groupedShapes {
                drawShapeInPDF(groupedShape, context: context, document: document)
            }
            context.restoreGState()
            return
        }
        if let imageData = shape.embeddedImageData {
            if let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),

               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                let bounds = shape.bounds
                context.saveGState()
                context.translateBy(x: bounds.minX, y: bounds.maxY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
                context.restoreGState()
            }
            context.restoreGState()
            return
        } else if let doc = document, let cgImage = ImageContentRegistry.image(for: shape.id, in: doc) {
            let bounds = shape.bounds
            context.saveGState()
            context.translateBy(x: bounds.minX, y: bounds.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
            context.restoreGState()
            context.restoreGState()
            return
        }
        let path = shape.path.cgPath

        var hasValidStroke = false
        if let strokeStyle = shape.strokeStyle {
            if case .clear = strokeStyle.color {
                hasValidStroke = false
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                hasValidStroke = true
            }
        }
        var hasValidFill = false
        if let fillStyle = shape.fillStyle {
            if case .clear = fillStyle.color {
                hasValidFill = false
            } else if fillStyle.opacity > 0 {
                hasValidFill = true
            }
        }
        if hasValidFill, let fillStyle = shape.fillStyle {
            if case .gradient(let gradient) = fillStyle.color {
                context.addPath(path)
                context.saveGState()
                context.clip()
                FileOperations.drawPDFGradient(gradient, in: context, bounds: path.boundingBox, opacity: fillStyle.opacity)
                context.restoreGState()
            } else {
                context.addPath(path)
                if hasValidStroke, let strokeStyle = shape.strokeStyle {
                    FileOperations.setFillStyle(fillStyle, context: context)
                    FileOperations.setStrokeStyle(strokeStyle, context: context)
                    context.drawPath(using: .fillStroke)
                } else {
                    FileOperations.setFillStyle(fillStyle, context: context)
                    context.fillPath()
                }
            }
        }
        if hasValidStroke, let strokeStyle = shape.strokeStyle {
            let fillIsGradient: Bool
            if let fillStyle = shape.fillStyle, case .gradient = fillStyle.color {
                fillIsGradient = true
            } else {
                fillIsGradient = false
            }
            if !hasValidFill || (hasValidFill && fillIsGradient) {
                context.addPath(path)
                FileOperations.setStrokeStyle(strokeStyle, context: context)
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    internal static func drawTextInPDF(_ text: VectorText, context: CGContext) {
        context.saveGState()
        context.setAlpha(text.isVisible ? 1.0 : 0.0)
        if !text.transform.isIdentity {
            context.concatenate(text.transform)
        }
        let font = text.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: text.typography.fillColor.cgColor.platformColor,
            .kern: text.typography.letterSpacing
        ]
        let attributedString = NSAttributedString(string: text.content, attributes: attributes)
        let textPosition = CGPoint(x: text.position.x, y: text.position.y)
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = textPosition
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

private struct PNGExportView: View {
    let document: VectorDocument
    let scale: CGFloat
    let includeBackground: Bool
    let outputSize: CGSize

    @State private var activeGradientDelta: VectorGradient? = nil
    var body: some View {
        ZStack {
            if includeBackground {
                PasteboardBackgroundView(
                    pasteboardSize: CGSize(
                        width: document.settings.sizeInPoints.width * 10,
                        height: document.settings.sizeInPoints.height * 10
                    ),
                    pasteboardOrigin: CGPoint(
                        x: -(document.settings.sizeInPoints.width * 10 - document.settings.sizeInPoints.width) / 2,
                        y: -(document.settings.sizeInPoints.height * 10 - document.settings.sizeInPoints.height) / 2
                    ),
                    zoomLevel: scale,
                    canvasOffset: .zero
                )
                CanvasBackgroundView(
                    canvasSize: document.settings.sizeInPoints,
                    backgroundColor: document.settings.backgroundColor.color,
                    zoomLevel: scale,
                    canvasOffset: .zero
                )
            }
            ForEach(Array(document.snapshot.layers.indices), id: \.self) { layerIndex in
                if document.snapshot.layers[layerIndex].isVisible,
                   layerIndex >= 2 {
                    let layer = document.snapshot.layers[layerIndex]
                    IsolatedLayerView(
                        objectIDs: layer.objectIDs,
                        document: document,
                        zoomLevel: scale,
                        canvasOffset: .zero,
                        selectedObjectIDs: [],
                        viewMode: .color,
                        dragPreviewDelta: .zero,
                        liveNudgeOffset: .zero,
                        dragPreviewTrigger: false,
                        liveScaleTransform: .identity,
                        layerOpacity: layer.opacity,
                        layerBlendMode: layer.blendMode,
                        livePointPositions: [:],
                        liveHandlePositions: [:],
                        fillDeltaOpacity: nil,
                        strokeDeltaOpacity: nil,
                        strokeDeltaWidth: nil,
                        colorDeltaColor: nil,
                        colorDeltaOpacity: nil,
                        activeGradientDelta: $activeGradientDelta,
                        activeColorTarget: .fill,
                        textContentDelta: .constant(nil),
                        fontSizeDelta: nil,
                        lineSpacingDelta: nil,
                        lineHeightDelta: nil,
                        letterSpacingDelta: nil,
                        imagePreviewQuality: UserDefaults.standard.object(forKey: "imagePreviewQuality") as? Double ?? 1.0,
                        imageTileSize: UserDefaults.standard.object(forKey: "imageTileSize") as? Int ?? 512,
                        imageInterpolationQuality: CGInterpolationQuality(rawValue: Int32(UserDefaults.standard.object(forKey: "imageInterpolationQuality") as? Int ?? 1)) ?? .none,
                        liveCornerRadii: [],
                        selectedShapeIDForCornerRadius: nil,
                        layerUpdateTrigger: 0,
                        isPanning: false
                    )
                }
            }
        }
        .frame(width: outputSize.width, height: outputSize.height)
        .background(Color.clear)
    }
}
