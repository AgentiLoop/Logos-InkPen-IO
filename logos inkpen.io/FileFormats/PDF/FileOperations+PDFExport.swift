import SwiftUI
import UniformTypeIdentifiers

extension FileOperations {

    static func generatePDFDataFromView(from document: VectorDocument, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, includeInkpenData: Bool = false, includeBackground: Bool = true) throws -> Data {
        return try generatePDFDataWithClippingSupport(
            from: document,
            isExport: true,
            useCMYK: false,
            textRenderingMode: textRenderingMode,
            includeInkpenData: includeInkpenData,
            includeBackground: includeBackground
        )
    }

    static func generatePDFDataWithClippingSupport(from document: VectorDocument, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, includeInkpenData: Bool = false, includeBackground: Bool = true) throws -> Data {
        let documentSize = document.settings.sizeInPoints
        let pdfData = NSMutableData()

        var mediaBox = CGRect(origin: .zero, size: documentSize)

        let auxiliaryDict: [String: Any] = [
            kCGPDFContextCreator as String: "Inkpen.io",
            kCGPDFContextAuthor as String: NSFullUserName(),
            kCGPDFContextTitle as String: "Inkpen Document",
            kCGPDFContextSubject as String: "Vector Graphics",
            kCGPDFContextKeywords as String: "vector, graphics, illustration"
        ]
        let auxiliaryInfo = auxiliaryDict as CFDictionary
        guard let pdfConsumer = CGDataConsumer(data: pdfData),

              let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, auxiliaryInfo) else {
            throw VectorImportError.parsingError("Failed to create PDF context", line: nil)
        }
        if includeInkpenData {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let jsonData = try? encoder.encode(document) {
                let base64String = jsonData.base64EncodedString()
                let formatVersion = document.snapshot.formatVersion
                let xmpMetadata = """
                <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
                <x:xmpmeta xmlns:x="adobe:ns:meta/">
                    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                        <rdf:Description rdf:about=""
                            xmlns:inkpen="https://inkpen.io/ns/\(formatVersion)">
                            <inkpen:document>\(base64String)</inkpen:document>
                        </rdf:Description>
                    </rdf:RDF>
                </x:xmpmeta>
                <?xpacket end="w"?>
                """
                if let xmpData = xmpMetadata.data(using: .utf8) {
                    pdfContext.addDocumentMetadata(xmpData as CFData)
                }
            }
        }
        let pageInfo = [
            kCGPDFContextMediaBox as String: mediaBox,
            kCGPDFContextArtBox as String: mediaBox,
            kCGPDFContextTrimBox as String: mediaBox,
            kCGPDFContextBleedBox as String: mediaBox
        ] as [String : Any]
        pdfContext.beginPDFPage(pageInfo as CFDictionary)
        pdfContext.setBlendMode(.normal)
        pdfContext.setShouldAntialias(true)
        pdfContext.setAllowsAntialiasing(true)
        pdfContext.interpolationQuality = CGInterpolationQuality(rawValue: Int32(UserDefaults.standard.object(forKey: "imageInterpolationQuality") as? Int ?? 1)) ?? .none
        pdfContext.translateBy(x: 0, y: documentSize.height)
        pdfContext.scaleBy(x: 1.0, y: -1.0)
        if includeBackground && document.settings.backgroundColor != .clear {
            pdfContext.setFillColor(document.settings.backgroundColor.cgColor)
            pdfContext.fill(mediaBox)
        }
        try renderDocumentToPDFWithClipping(document: document, context: pdfContext, isExport: isExport, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeBackground: includeBackground)
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        return pdfData as Data
    }

    static func renderDocumentToPDFWithClipping(document: VectorDocument, context: CGContext, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, includeBackground: Bool = true) throws {
        context.saveGState()
        var clippingMasks: [UUID: VectorShape] = [:]
        var clippedShapes: [UUID: [VectorShape]] = [:]
        for (index, layer) in document.snapshot.layers.enumerated() {
            autoreleasepool {
                if index == 0 { return }
                if index == 1 && !includeBackground { return }
                guard !layer.isLocked, layer.isVisible else { return }
                let shapesInLayer = document.getShapesForLayer(index)
                for shape in shapesInLayer where shape.isVisible {
                    if shape.isClippingPath {
                        clippingMasks[shape.id] = shape
                        if clippedShapes[shape.id] == nil {
                            clippedShapes[shape.id] = []
                        }
                    } else if let clipId = shape.clippedByShapeID {
                        if clippedShapes[clipId] == nil {
                            clippedShapes[clipId] = []
                        }
                        clippedShapes[clipId]?.append(shape)
                    }
                }
            }
        }
        var renderedShapeIds = Set<UUID>()
        for (index, layer) in document.snapshot.layers.enumerated() {
            if index == 0 { continue }
            if index == 1 && !includeBackground { continue }
            guard !layer.isLocked, layer.isVisible else { continue }
            try autoreleasepool {
                context.saveGState()
                if layer.blendMode != BlendMode.normal {
                    context.setBlendMode(layer.blendMode.cgBlendMode)
                }
                if layer.opacity < 1.0 {
                    context.setAlpha(CGFloat(layer.opacity))
                }
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                let shapesInLayer = document.getShapesForLayer(index)
                Log.info("📄 PDF Export - Layer \(index) has \(shapesInLayer.count) shapes", category: .general)
                for shape in shapesInLayer where shape.isVisible {
                    if !includeBackground && shape.name == "Canvas Background" {
                        continue
                    }
                    guard !renderedShapeIds.contains(shape.id) else { continue }
                    Log.info("📄 PDF Export - Processing shape: \(shape.name), hasTypography: \(shape.typography != nil)", category: .general)
                    if shape.clippedByShapeID != nil {
                        continue
                    }
                    if document.snapshot.parentGroupCache[shape.id] != nil {
                        continue
                    }
                    if shape.isClippingPath, let clipped = clippedShapes[shape.id], !clipped.isEmpty {
                        try renderClippingGroup(
                            clippingMask: shape,
                            clippedShapes: clipped,
                            context: context,
                            isExport: isExport,
                            useCMYK: useCMYK,
                            textRenderingMode: textRenderingMode,
                            document: document
                        )
                        renderedShapeIds.insert(shape.id)
                        clipped.forEach { renderedShapeIds.insert($0.id) }
                    } else if !shape.isClippingPath {
                        try renderShapeToPDFWithImageSupport(shape: shape, context: context, isExport: isExport, useCMYK: useCMYK, textRenderingMode: textRenderingMode, document: document)
                        renderedShapeIds.insert(shape.id)
                    }
                }
                context.endTransparencyLayer()
                context.restoreGState()
            }
        }
        context.restoreGState()
    }

    static func renderClippingGroup(clippingMask: VectorShape, clippedShapes: [VectorShape], context: CGContext, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, document: VectorDocument) throws {
        context.saveGState()
        context.concatenate(clippingMask.transform)
        let clipPath = convertVectorPathToCGPath(clippingMask.path)
        context.addPath(clipPath)
        context.clip(using: clippingMask.clipFillRule)
        context.concatenate(clippingMask.transform.inverted())
        for shape in clippedShapes {
            try renderShapeToPDFWithImageSupport(shape: shape, context: context, isExport: isExport, useCMYK: useCMYK, textRenderingMode: textRenderingMode, document: document)
        }
        context.restoreGState()
    }

    static func renderShapeToPDFWithImageSupport(shape: VectorShape, context: CGContext, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, document: VectorDocument? = nil) throws {
        if let doc = document, let object = doc.findObject(by: shape.id), case .text = object.objectType, let vectorText = VectorText.from(shape) {
            Log.info("📄 PDF Export - Rendering text: '\(vectorText.content)' at position: \(vectorText.position)", category: .general)
            try renderTextToPDF(vectorText: vectorText, context: context, renderingMode: textRenderingMode)
            return
        }
        if shape.isClippingGroup,
           let members = resolveClippingGroupMembersForPDF(shape, in: document),
           members.count >= 2 {
            let mask = members[0]
            let content = Array(members.dropFirst())
            context.saveGState()
            context.concatenate(shape.transform)
            if shape.blendMode != .normal {
                context.setBlendMode(shape.blendMode.cgBlendMode)
            }
            if shape.opacity < 1.0 {
                context.setAlpha(CGFloat(shape.opacity))
            }
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            context.concatenate(mask.transform)
            let clipPath = convertVectorPathToCGPath(mask.path)
            context.addPath(clipPath)
            context.clip(using: mask.clipFillRule)
            context.concatenate(mask.transform.inverted())
            for memberShape in content where memberShape.isVisible {
                try renderShapeToPDFWithImageSupport(
                    shape: memberShape,
                    context: context,
                    isExport: isExport,
                    useCMYK: useCMYK,
                    textRenderingMode: textRenderingMode,
                    document: document
                )
            }
            context.endTransparencyLayer()
            context.restoreGState()
            return
        }
        if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty, let doc = document {
            context.saveGState()
            context.concatenate(shape.transform)
            if shape.blendMode != .normal {
                context.setBlendMode(shape.blendMode.cgBlendMode)
            }
            if shape.opacity < 1.0 {
                context.setAlpha(CGFloat(shape.opacity))
            }
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            for memberID in shape.memberIDs {
                if let memberShape = doc.findShape(by: memberID), memberShape.isVisible {
                    try renderShapeToPDFWithImageSupport(
                        shape: memberShape,
                        context: context,
                        isExport: isExport,
                        useCMYK: useCMYK,
                        textRenderingMode: textRenderingMode,
                        document: document
                    )
                }
            }
            context.endTransparencyLayer()
            context.restoreGState()
            return
        }
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            context.saveGState()
            context.concatenate(shape.transform)
            if shape.blendMode != .normal {
                context.setBlendMode(shape.blendMode.cgBlendMode)
            }
            if shape.opacity < 1.0 {
                context.setAlpha(CGFloat(shape.opacity))
            }
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            for groupedShape in shape.groupedShapes {
                try renderShapeToPDFWithImageSupport(
                    shape: groupedShape,
                    context: context,
                    isExport: isExport,
                    useCMYK: useCMYK,
                    textRenderingMode: textRenderingMode,
                    document: document
                )
            }
            context.endTransparencyLayer()
            context.restoreGState()
            return
        }
        if let imageData = shape.embeddedImageData {
            try renderImageToPDF(shape: shape, imageData: imageData, context: context)
            return
        }
        if let doc = document, let cgImage = ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: doc) {
            let mutableData = NSMutableData()
            if let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, cgImage, nil)
                if CGImageDestinationFinalize(destination) {
                    try renderImageToPDF(shape: shape, imageData: mutableData as Data, context: context)
                    return
                }
            }
        }
        let cgPath = convertVectorPathToCGPath(shape.path)
        context.saveGState()
        context.concatenate(shape.transform)
        if let fillStyle = shape.fillStyle {
            if case .gradient(let gradient) = fillStyle.color {
                context.addPath(cgPath)
                context.saveGState()
                context.clip()
                if isExport {
                    drawPDFGradientForExport(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity, useCMYK: useCMYK)
                } else {
                    drawPDFGradient(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity)
                }
                context.restoreGState()
            } else {
                context.addPath(cgPath)
                setFillStyle(fillStyle, context: context)
                context.fillPath()
            }
        }
        if let strokeStyle = shape.strokeStyle {
            if case .clear = strokeStyle.color {
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                context.addPath(cgPath)
                setStrokeStyle(strokeStyle, context: context)
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    static func resolveClippingGroupMembersForPDF(_ shape: VectorShape, in document: VectorDocument?) -> [VectorShape]? {
        if !shape.memberIDs.isEmpty, let doc = document {
            let resolved = shape.memberIDs.compactMap { doc.findShape(by: $0) }
            return resolved.isEmpty ? nil : resolved
        }
        if !shape.groupedShapes.isEmpty {
            return shape.groupedShapes
        }
        return nil
    }

    static func renderImageToPDF(shape: VectorShape, imageData: Data, context: CGContext) throws {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),

              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            Log.error("Failed to create CGImage from embedded data", category: .error)
            return
        }
        context.saveGState()
        context.concatenate(shape.transform)
        if shape.opacity < 1.0 {
            context.setAlpha(CGFloat(shape.opacity))
        }
        let bounds = shape.bounds
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.minY)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
        context.restoreGState()
    }

    static func renderTextToPDF(vectorText: VectorText, context: CGContext, renderingMode: AppState.PDFTextRenderingMode = .glyphs) throws {
        guard !vectorText.content.isEmpty else { return }
        switch renderingMode {
        case .glyphs:
            try renderTextToPDF_Glyphs(vectorText: vectorText, context: context)
        case .lines:
            try renderTextToPDF_Lines(vectorText: vectorText, context: context)
        }
    }

    private static func renderTextToPDF_Glyphs(vectorText: VectorText, context: CGContext) throws {
        guard !vectorText.content.isEmpty else { return }
        let nsFont = vectorText.typography.nsFont
        let ctFont = nsFont as CTFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
        paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing
        ]
        let attributedString = NSAttributedString(string: vectorText.content, attributes: attributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
        let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
        layoutManager.ensureLayout(for: textContainer)
        context.saveGState()
        context.setAlpha(CGFloat(vectorText.typography.fillOpacity))
        let cgColor = vectorText.typography.fillColor.cgColor
        if let components = cgColor.components, components.count >= 3 {
            context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: vectorText.typography.fillOpacity)
        } else if let components = cgColor.components, components.count == 2 {
            context.setFillColor(gray: components[0], alpha: vectorText.typography.fillOpacity)
        } else {
            context.setFillColor(cgColor)
        }
        context.setTextDrawingMode(.fill)
        let cgFont = CTFontCopyGraphicsFont(ctFont, nil)
        context.setFont(cgFont)
        context.setFontSize(nsFont.pointSize)
        var skippedGlyphCount = 0

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                let glyph = layoutManager.cgGlyph(at: glyphIndex)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    if isRectangleGlyph(glyphPath) {
                        skippedGlyphCount += 1
                        continue
                    }
                }
                var actualLineRect = CGRect.zero
                var actualUsedRect = CGRect.zero
                var effectiveRange = NSRange()
                actualLineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                actualUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                let glyphX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    glyphX = vectorText.position.x + actualUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    glyphX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
                default:
                    glyphX = vectorText.position.x + actualUsedRect.origin.x + glyphLocation.x
                }
                let glyphY = vectorText.position.y + actualLineRect.origin.y + glyphLocation.y
                context.saveGState()
                context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
                context.textPosition = CGPoint(x: glyphX, y: glyphY)
                context.showGlyphs([glyph], at: [CGPoint.zero])
                context.restoreGState()
            }
        }
        context.restoreGState()
    }

    private static func isRectangleGlyph(_ path: CGPath) -> Bool {
        var subpaths: [[CGPoint]] = []
        var currentPath: [CGPoint] = []
        var hasCurves = false
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                }
                currentPath = [element.points[0]]
            case .addLineToPoint:
                currentPath.append(element.points[0])
            case .addQuadCurveToPoint, .addCurveToPoint:
                hasCurves = true
            case .closeSubpath:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = []
                }

            @unknown default:
                break
            }
        }
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        if hasCurves {
            return false
        }
        if subpaths.count != 2 {
            return false
        }
        for subpath in subpaths {
            if subpath.count < 4 || subpath.count > 5 {
                return false
            }
            if !isRectangularPath(subpath) {
                return false
            }
        }
        let bounds1 = boundingBox(of: subpaths[0])
        let bounds2 = boundingBox(of: subpaths[1])
        let isNested = (bounds1.contains(bounds2) || bounds2.contains(bounds1))
        if isNested {
            return true
        }
        return false
    }

    private static func isRectangularPath(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4 else { return false }
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = abs(p2.x - p1.x)
            let dy = abs(p2.y - p1.y)
            let isHorizontal = dy < 0.1 && dx > 0.1
            let isVertical = dx < 0.1 && dy > 0.1
            if !isHorizontal && !isVertical {
                return false
            }
        }
        return true
    }

    private static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func renderTextToPDF_Lines(vectorText: VectorText, context: CGContext) throws {
        guard !vectorText.content.isEmpty else { return }
        let nsFont = vectorText.typography.nsFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
        paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight
        let layoutAttributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing
        ]
        let attributedString = NSAttributedString(string: vectorText.content, attributes: layoutAttributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
        let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
        layoutManager.ensureLayout(for: textContainer)
        context.saveGState()
        context.setAlpha(CGFloat(vectorText.typography.fillOpacity))
        let renderingAttributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing,
            .foregroundColor: vectorText.typography.fillColor.cgColor.platformColor
        ]
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            let lineRange = NSRange(location: lineRange.location, length: lineRange.length)
            let lineString = (vectorText.content as NSString).substring(with: lineRange)
            let lineAttribString = NSAttributedString(string: lineString, attributes: renderingAttributes)

            var line = CTLineCreateWithAttributedString(lineAttribString)
            if vectorText.typography.alignment.nsTextAlignment == .justified {
                if let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                    line = justifiedLine
                }
            }
            let firstGlyphIndex = lineRange.location
            let glyphLocation = layoutManager.location(forGlyphAt: firstGlyphIndex)
            let lineX: CGFloat
            switch vectorText.typography.alignment.nsTextAlignment {
            case .left, .justified:
                lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
            case .center, .right:
                lineX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
            default:
                lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
            }
            let lineY = vectorText.position.y + lineRect.origin.y + glyphLocation.y
            context.saveGState()
            context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
            context.textPosition = CGPoint(x: lineX, y: lineY)
            CTLineDraw(line, context)
            context.restoreGState()
        }
        context.restoreGState()
    }
}
