import SwiftUI
import UniformTypeIdentifiers

class SVGExporter {
    static let shared = SVGExporter()

    private init() {}

    func exportToSVG(_ document: VectorDocument, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs, includeInkpenData: Bool = false) throws -> String {
        let dpiScale: CGFloat = 1.0
        return try exportSVGWithScale(document, dpiScale: dpiScale, isAutoDesk: false, includeBackground: includeBackground, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData)
    }

    func exportToAutoDeskSVG(_ document: VectorDocument, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs, includeInkpenData: Bool = true) throws -> String {
        let dpiScale: CGFloat = 96.0 / 72.0
        return try exportSVGWithScale(document, dpiScale: dpiScale, isAutoDesk: true, includeBackground: includeBackground, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData)
    }

    private func exportSVGWithScale(_ document: VectorDocument, dpiScale: CGFloat, isAutoDesk: Bool, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs, includeInkpenData: Bool = false) throws -> String {
        let originalSize = document.settings.sizeInPoints
        let scaledWidth = originalSize.width * dpiScale
        let scaledHeight = originalSize.height * dpiScale
        let viewBoxWidth = isAutoDesk ? scaledWidth : originalSize.width
        let viewBoxHeight = isAutoDesk ? scaledHeight : originalSize.height
        let widthStr = formatSVGNumber(scaledWidth)
        let heightStr = formatSVGNumber(scaledHeight)
        let viewBoxWidthStr = formatSVGNumber(viewBoxWidth)
        let viewBoxHeightStr = formatSVGNumber(viewBoxHeight)
        let widthAttr = isAutoDesk ? "\(widthStr)px" : widthStr
        let heightAttr = isAutoDesk ? "\(heightStr)px" : heightStr

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(widthAttr)" height="\(heightAttr)" viewBox="0 0 \(viewBoxWidthStr) \(viewBoxHeightStr)"
             version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
             style="background-color: transparent;">
        """
        svg += "\n<defs>\n"
        svg += generateGradientDefs(from: document)
        svg += generateClipPathDefs(from: document)
        svg += "</defs>\n"
        if includeInkpenData {
            do {
                let inkpenData = try FileOperations.exportToJSONData(document)
                let base64String = inkpenData.base64EncodedString()
                let formatVersion = document.snapshot.formatVersion
                svg += "<metadata>\n"
                svg += "  <inkpen:document xmlns:inkpen=\"https://inkpen.io/ns/\(formatVersion)\">\n"
                svg += "    \(base64String)\n"
                svg += "  </inkpen:document>\n"
                svg += "</metadata>\n"
            } catch {
                Log.error("⚠️ Failed to embed inkpen data: \(error)", category: .error)
            }
        }
        for (layerIndex, layer) in document.snapshot.layers.enumerated() {
            if !layer.isVisible { continue }
            if layer.name == "Pasteboard" { continue }
            if layer.name == "Guides" { continue }
            if !includeBackground && layer.name == "Canvas" {
                continue
            }
            svg += "<!-- Layer: \(layer.name) -->\n"
            var layerAttrs = "id=\"layer_\(layerIndex)\" opacity=\"\(layer.opacity)\""
            if layer.blendMode != BlendMode.normal {
                layerAttrs += " style=\"mix-blend-mode: \(layer.blendMode.svgBlendMode)\""
            }
            svg += "<g \(layerAttrs)>\n"
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            let shapeScale: CGFloat = isAutoDesk ? dpiScale : 1.0
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                if document.snapshot.parentGroupCache[shape.id] != nil { continue }
                if let object = document.findObject(by: shape.id), case .text = object.objectType {
                    svg += exportTextShape(shape, dpiScale: shapeScale, renderingMode: textRenderingMode)
                } else {
                    svg += exportShape(shape, dpiScale: shapeScale, document: document)
                }
            }
            svg += "</g>\n"
        }
        svg += "</svg>"
        return svg
    }

    private func exportShape(_ shape: VectorShape, dpiScale: CGFloat, document: VectorDocument? = nil) -> String {
        var svg = ""
        if shape.isClippingPath {
            return ""
        }
        if shape.isClippingGroup, let members = resolveClippingGroupMembers(shape, in: document), members.count >= 2 {
            let content = Array(members.dropFirst())
            svg += "<g id=\"clipgroup_\(shape.id.uuidString)\" clip-path=\"url(#clip_\(shape.id.uuidString))\">\n"
            for memberShape in content {
                if !memberShape.isVisible { continue }
                if let doc = document, let memberObject = doc.findObject(by: memberShape.id), case .text = memberObject.objectType {
                    svg += exportTextShape(memberShape, dpiScale: dpiScale, renderingMode: .glyphs)
                } else {
                    svg += exportShape(memberShape, dpiScale: dpiScale, document: document)
                }
            }
            svg += "</g>\n"
            return svg
        }
        if (shape.isGroup || shape.isClippingGroup) && !shape.memberIDs.isEmpty, let doc = document {
            svg += "<g id=\"group_\(shape.id.uuidString)\">\n"
            for memberID in shape.memberIDs {
                if let memberShape = doc.findShape(by: memberID) {
                    if !memberShape.isVisible { continue }
                    if let memberObject = doc.findObject(by: memberID), case .text = memberObject.objectType {
                        svg += exportTextShape(memberShape, dpiScale: dpiScale, renderingMode: .glyphs)
                    } else {
                        svg += exportShape(memberShape, dpiScale: dpiScale, document: doc)
                    }
                }
            }
            svg += "</g>\n"
            return svg
        }
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            svg += "<g id=\"group_\(shape.id.uuidString)\">\n"
            for groupedShape in shape.groupedShapes {
                if !groupedShape.isVisible { continue }
                svg += exportShape(groupedShape, dpiScale: dpiScale, document: document)
            }
            svg += "</g>\n"
            return svg
        }
        if let doc = document, let image = ImageContentRegistry.image(for: shape.id, in: doc) ??
                       ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: doc) {
            return exportImageShape(shape, image: image, dpiScale: dpiScale)
        }
        let pathData = generatePathData(from: shape.path, transform: shape.transform, dpiScale: dpiScale)
        svg += "<path d=\"\(pathData)\""
        if let clipId = shape.clippedByShapeID {
            svg += " clip-path=\"url(#clip_\(clipId.uuidString))\""
        }
        if let fillStyle = shape.fillStyle {
            if case .gradient(let gradient) = fillStyle.color {
                svg += " fill=\"url(#gradient_\(gradient.hashValue))\""
            } else {
                svg += " fill=\"\(fillStyle.color.svgColor)\""
            }
            if fillStyle.opacity != 1.0 {
                svg += " fill-opacity=\"\(fillStyle.opacity)\""
            }
        } else {
            svg += " fill=\"none\""
        }
        if let strokeStyle = shape.strokeStyle {
            if case .gradient(let gradient) = strokeStyle.color {
                svg += " stroke=\"url(#gradient_\(gradient.hashValue))\""
            } else {
                svg += " stroke=\"\(strokeStyle.color.svgColor)\""
            }
            let scaledWidth = strokeStyle.width * dpiScale
            svg += " stroke-width=\"\(scaledWidth)\""
            if strokeStyle.opacity != 1.0 {
                svg += " stroke-opacity=\"\(strokeStyle.opacity)\""
            }
        }
        svg += "/>\n"
        return svg
    }

    private func exportTextShape(_ shape: VectorShape, dpiScale: CGFloat, renderingMode: AppState.SVGTextRenderingMode) -> String {
        guard let vectorText = VectorText.from(shape) else { return "" }
        switch renderingMode {
        case .glyphs:
            return exportTextAsGlyphs(vectorText: vectorText, dpiScale: dpiScale)
        case .lines:
            return exportTextAsLines(vectorText: vectorText, dpiScale: dpiScale)
        }
    }

    private func exportTextAsGlyphs(vectorText: VectorText, dpiScale: CGFloat) -> String {
        guard !vectorText.content.isEmpty else { return "" }
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
        var svg = ""
        var skippedGlyphCount = 0
        if let areaSize = vectorText.areaSize, areaSize.width > 0, areaSize.height > 0 {
            let boxX = vectorText.position.x * dpiScale
            let boxY = vectorText.position.y * dpiScale
            let boxWidth = areaSize.width * dpiScale
            let boxHeight = areaSize.height * dpiScale
            svg += "<g id=\"textbox_\(vectorText.id.uuidString)\">\n"
            svg += "  <rect x=\"\(boxX)\" y=\"\(boxY)\" width=\"\(boxWidth)\" height=\"\(boxHeight)\" fill=\"none\" opacity=\"0\"/>\n"
        }
        let fillColor = vectorText.typography.fillColor.svgColor
        let fillOpacity = vectorText.typography.fillOpacity
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                let glyph = layoutManager.cgGlyph(at: glyphIndex)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    if self.isRectangleGlyph(glyphPath) {
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
                let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
                if charIndex < vectorText.content.count {
                    let char = (vectorText.content as NSString).substring(with: NSRange(location: charIndex, length: 1))
                    let escapedChar = self.escapeXML(char)
                    let x = glyphX * dpiScale
                    let y = glyphY * dpiScale
                    let fontSize = vectorText.typography.fontSize * dpiScale
                    svg += "<text x=\"\(x)\" y=\"\(y)\""
                    svg += " font-family=\"\(vectorText.typography.fontFamily)\""
                    svg += " font-size=\"\(fontSize)\""
                    if let svgWeight = self.getSVGFontWeightFrom(variant: vectorText.typography.fontVariant) {
                        svg += " font-weight=\"\(svgWeight)\""
                    }
                    if vectorText.typography.isItalic {
                        svg += " font-style=\"italic\""
                    }
                    svg += " fill=\"\(fillColor)\""
                    if fillOpacity != 1.0 {
                        svg += " fill-opacity=\"\(fillOpacity)\""
                    }
                    if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                        svg += " stroke=\"\(vectorText.typography.strokeColor.svgColor)\""
                        svg += " stroke-width=\"\(vectorText.typography.strokeWidth * dpiScale)\""
                        if vectorText.typography.strokeOpacity != 1.0 {
                            svg += " stroke-opacity=\"\(vectorText.typography.strokeOpacity)\""
                        }
                    }
                    if vectorText.typography.letterSpacing != 0 {
                        svg += " letter-spacing=\"\(vectorText.typography.letterSpacing * dpiScale)\""
                    }
                    svg += ">\(escapedChar)</text>\n"
                }
            }
        }
        if let areaSize = vectorText.areaSize, areaSize.width > 0, areaSize.height > 0 {
            svg += "</g>\n"
        }
        return svg
    }

    private func exportTextAsLines(vectorText: VectorText, dpiScale: CGFloat) -> String {
        guard !vectorText.content.isEmpty else { return "" }
        let nsFont = vectorText.typography.nsFont
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
        var svg = ""
        if let areaSize = vectorText.areaSize, areaSize.width > 0, areaSize.height > 0 {
            let boxX = vectorText.position.x * dpiScale
            let boxY = vectorText.position.y * dpiScale
            let boxWidth = areaSize.width * dpiScale
            let boxHeight = areaSize.height * dpiScale
            svg += "<g id=\"textbox_\(vectorText.id.uuidString)\">\n"
            svg += "  <rect x=\"\(boxX)\" y=\"\(boxY)\" width=\"\(boxWidth)\" height=\"\(boxHeight)\" fill=\"none\" opacity=\"0\"/>\n"
        }
        let fillColor = vectorText.typography.fillColor.svgColor
        let fillOpacity = vectorText.typography.fillOpacity
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            if vectorText.typography.alignment.nsTextAlignment == .justified {
                let lineString = (vectorText.content as NSString).substring(with: lineRange)
                let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
                let isActuallyJustified = abs(lineUsedRect.width - textBoxWidth) < 1.0
                let wordCount = lineString.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
                let isSingleWord = wordCount == 1
                let isLastLine = NSMaxRange(lineRange) >= vectorText.content.count ||
                                 lineRange.location + lineRange.length >= vectorText.content.count
                if !isActuallyJustified || (isSingleWord && !isLastLine) {
                    for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                        let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                        let glyphX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
                        let glyphY = vectorText.position.y + lineRect.origin.y + glyphLocation.y
                        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
                        if charIndex < vectorText.content.count {
                            let char = (vectorText.content as NSString).substring(with: NSRange(location: charIndex, length: 1))
                            let escapedChar = self.escapeXML(char)
                            let x = glyphX * dpiScale
                            let y = glyphY * dpiScale
                            let fontSize = vectorText.typography.fontSize * dpiScale
                            svg += "<text x=\"\(x)\" y=\"\(y)\""
                            svg += " font-family=\"\(vectorText.typography.fontFamily)\""
                            svg += " font-size=\"\(fontSize)\""
                            if let svgWeight = self.getSVGFontWeightFrom(variant: vectorText.typography.fontVariant) {
                                svg += " font-weight=\"\(svgWeight)\""
                            }
                            if vectorText.typography.isItalic {
                                svg += " font-style=\"italic\""
                            }
                            svg += " fill=\"\(fillColor)\""
                            if fillOpacity != 1.0 {
                                svg += " fill-opacity=\"\(fillOpacity)\""
                            }
                            if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                                svg += " stroke=\"\(vectorText.typography.strokeColor.svgColor)\""
                                svg += " stroke-width=\"\(vectorText.typography.strokeWidth * dpiScale)\""
                                if vectorText.typography.strokeOpacity != 1.0 {
                                    svg += " stroke-opacity=\"\(vectorText.typography.strokeOpacity)\""
                                }
                            }
                            if vectorText.typography.letterSpacing != 0 {
                                svg += " letter-spacing=\"\(vectorText.typography.letterSpacing * dpiScale)\""
                            }
                            svg += ">\(escapedChar)</text>\n"
                        }
                    }
                    return
                }
                var words: [(word: String, range: NSRange)] = []
                var currentWordStart = 0
                var inWord = false
                for i in 0..<lineString.count {
                    let char = (lineString as NSString).character(at: i)
                    let isWhitespace = UnicodeScalar(char).map { CharacterSet.whitespaces.contains($0) } ?? false
                    if !isWhitespace && !inWord {
                        currentWordStart = i
                        inWord = true
                    } else if isWhitespace && inWord {
                        let wordLength = i - currentWordStart
                        let wordRange = NSRange(location: currentWordStart, length: wordLength)
                        let word = (lineString as NSString).substring(with: wordRange)
                        let absoluteRange = NSRange(location: lineRange.location + wordRange.location, length: wordRange.length)
                        words.append((word: word, range: absoluteRange))
                        inWord = false
                    }
                }
                if inWord {
                    let wordLength = lineString.count - currentWordStart
                    let wordRange = NSRange(location: currentWordStart, length: wordLength)
                    let word = (lineString as NSString).substring(with: wordRange)
                    let absoluteRange = NSRange(location: lineRange.location + wordRange.location, length: wordRange.length)
                    words.append((word: word, range: absoluteRange))
                }
                for wordInfo in words {
                    let escapedWord = self.escapeXML(wordInfo.word)
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: wordInfo.range, actualCharacterRange: nil)
                    guard glyphRange.length > 0 else { continue }
                    let firstGlyphIndex = glyphRange.location
                    let glyphLocation = layoutManager.location(forGlyphAt: firstGlyphIndex)
                    let wordX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
                    let wordY = vectorText.position.y + lineRect.origin.y + glyphLocation.y
                    let x = wordX * dpiScale
                    let y = wordY * dpiScale
                    let fontSize = vectorText.typography.fontSize * dpiScale
                    svg += "<text x=\"\(x)\" y=\"\(y)\""
                    svg += " font-family=\"\(vectorText.typography.fontFamily)\""
                    svg += " font-size=\"\(fontSize)\""
                    if let svgWeight = self.getSVGFontWeightFrom(variant: vectorText.typography.fontVariant) {
                        svg += " font-weight=\"\(svgWeight)\""
                    }
                    if vectorText.typography.isItalic {
                        svg += " font-style=\"italic\""
                    }
                    svg += " text-anchor=\"start\""
                    svg += " fill=\"\(fillColor)\""
                    if fillOpacity != 1.0 {
                        svg += " fill-opacity=\"\(fillOpacity)\""
                    }
                    if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                        svg += " stroke=\"\(vectorText.typography.strokeColor.svgColor)\""
                        svg += " stroke-width=\"\(vectorText.typography.strokeWidth * dpiScale)\""
                        if vectorText.typography.strokeOpacity != 1.0 {
                            svg += " stroke-opacity=\"\(vectorText.typography.strokeOpacity)\""
                        }
                    }
                    if vectorText.typography.letterSpacing != 0 {
                        svg += " letter-spacing=\"\(vectorText.typography.letterSpacing * dpiScale)\""
                    }
                    svg += ">\(escapedWord)</text>\n"
                }
            } else {
                let lineString = (vectorText.content as NSString).substring(with: lineRange)
                let escapedLine = self.escapeXML(lineString)
                let firstGlyphIndex = lineRange.location
                let glyphLocation = layoutManager.location(forGlyphAt: firstGlyphIndex)
                let lineX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left:
                    lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    lineX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
                default:
                    lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
                }
                let lineY = vectorText.position.y + lineRect.origin.y + glyphLocation.y
                let x = lineX * dpiScale
                let y = lineY * dpiScale
                let fontSize = vectorText.typography.fontSize * dpiScale
                svg += "<text x=\"\(x)\" y=\"\(y)\""
                svg += " font-family=\"\(vectorText.typography.fontFamily)\""
                svg += " font-size=\"\(fontSize)\""
                if let svgWeight = self.getSVGFontWeightFrom(variant: vectorText.typography.fontVariant) {
                    svg += " font-weight=\"\(svgWeight)\""
                }
                if vectorText.typography.isItalic {
                    svg += " font-style=\"italic\""
                }
                svg += " text-anchor=\"start\""
                svg += " fill=\"\(fillColor)\""
                if fillOpacity != 1.0 {
                    svg += " fill-opacity=\"\(fillOpacity)\""
                }
                if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                    svg += " stroke=\"\(vectorText.typography.strokeColor.svgColor)\""
                    svg += " stroke-width=\"\(vectorText.typography.strokeWidth * dpiScale)\""
                    if vectorText.typography.strokeOpacity != 1.0 {
                        svg += " stroke-opacity=\"\(vectorText.typography.strokeOpacity)\""
                    }
                }
                if vectorText.typography.letterSpacing != 0 {
                    svg += " letter-spacing=\"\(vectorText.typography.letterSpacing * dpiScale)\""
                }
                svg += ">\(escapedLine)</text>\n"
            }
        }
        if let areaSize = vectorText.areaSize, areaSize.width > 0, areaSize.height > 0 {
            svg += "</g>\n"
        }
        return svg
    }

    private func exportTextShape_OLD(_ shape: VectorShape, dpiScale: CGFloat) -> String {
        guard let textContent = shape.textContent,
              let typography = shape.typography else { return "" }
        var svg = ""
        if let areaSize = shape.areaSize, areaSize.width > 0, areaSize.height > 0 {
            let boxPosition: CGPoint
            if shape.transform != .identity {
                boxPosition = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            } else if let textPos = shape.textPosition {
                boxPosition = textPos
            } else {
                boxPosition = CGPoint(x: shape.bounds.minX, y: shape.bounds.minY)
            }
            let boxX = boxPosition.x * dpiScale
            let boxY = boxPosition.y * dpiScale
            let boxWidth = areaSize.width * dpiScale
            let boxHeight = areaSize.height * dpiScale
            svg += "<rect x=\"\(boxX)\" y=\"\(boxY)\" width=\"\(boxWidth)\" height=\"\(boxHeight)\""
            svg += " fill=\"none\" stroke=\"#808080\" stroke-width=\"1\"/>\n"
            let fontSize = typography.fontSize * dpiScale

            var textX: CGFloat
            switch typography.alignment {
            case .center:
                textX = boxX + (boxWidth / 2)
            case .right:
                textX = boxX + boxWidth - 20
            default:
                textX = boxX + 20
            }
            let textY = boxY + (boxHeight / 2) + (fontSize / 3)
            svg += "<text x=\"\(textX)\" y=\"\(textY)\""
            svg += " font-family=\"\(typography.fontFamily)\""
            svg += " font-size=\"\(fontSize)\""
            if let svgWeight = getSVGFontWeightFrom(variant: typography.fontVariant) {
                svg += " font-weight=\"\(svgWeight)\""
            }
            if typography.isItalic {
                svg += " font-style=\"italic\""
            }
            let textAnchor = getSVGTextAnchor(typography.alignment)
            svg += " text-anchor=\"\(textAnchor)\""
            svg += " dominant-baseline=\"alphabetic\""
            svg += " fill=\"\(typography.fillColor.svgColor)\""
            if typography.fillOpacity != 1.0 {
                svg += " fill-opacity=\"\(typography.fillOpacity)\""
            }
            if typography.hasStroke && typography.strokeWidth > 0 {
                svg += " stroke=\"\(typography.strokeColor.svgColor)\""
                svg += " stroke-width=\"\(typography.strokeWidth * dpiScale)\""
                if typography.strokeOpacity != 1.0 {
                    svg += " stroke-opacity=\"\(typography.strokeOpacity)\""
                }
            }
            if typography.letterSpacing != 0 {
                svg += " letter-spacing=\"\(typography.letterSpacing * dpiScale)\""
            }
            svg += ">\(escapeXML(textContent))</text>\n"
        } else {
            let position: CGPoint
            if shape.transform != .identity {
                position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            } else if let textPos = shape.textPosition {
                position = textPos
            } else {
                position = CGPoint(
                    x: shape.bounds.midX,
                    y: shape.bounds.midY
                )
            }
            let x = position.x * dpiScale
            let fontSize = typography.fontSize * dpiScale
            let y = (position.y + fontSize) * dpiScale
            svg = "<text x=\"\(x)\" y=\"\(y)\""
            svg += " font-family=\"\(typography.fontFamily)\""
            svg += " font-size=\"\(fontSize)\""
            if let svgWeight = getSVGFontWeightFrom(variant: typography.fontVariant) {
                svg += " font-weight=\"\(svgWeight)\""
            }
            if typography.isItalic {
                svg += " font-style=\"italic\""
            }
            let textAnchor = getSVGTextAnchor(typography.alignment)
            svg += " text-anchor=\"\(textAnchor)\""
            svg += " dominant-baseline=\"alphabetic\""
            svg += " fill=\"\(typography.fillColor.svgColor)\""
            if typography.fillOpacity != 1.0 {
                svg += " fill-opacity=\"\(typography.fillOpacity)\""
            }
            if typography.hasStroke && typography.strokeWidth > 0 {
                svg += " stroke=\"\(typography.strokeColor.svgColor)\""
                svg += " stroke-width=\"\(typography.strokeWidth * dpiScale)\""
                if typography.strokeOpacity != 1.0 {
                    svg += " stroke-opacity=\"\(typography.strokeOpacity)\""
                }
            }
            if typography.letterSpacing != 0 {
                svg += " letter-spacing=\"\(typography.letterSpacing * dpiScale)\""
            }
            svg += ">\(escapeXML(textContent))</text>\n"
        }
        return svg
    }

    private func isRectangleGlyph(_ path: CGPath) -> Bool {
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
        return isNested
    }

    private func isRectangularPath(_ points: [CGPoint]) -> Bool {
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

    private func boundingBox(of points: [CGPoint]) -> CGRect {
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

    private func getSVGFontWeightFrom(variant: String?) -> String? {
        guard let variant = variant else { return nil }
        let lowercased = variant.lowercased()
        if lowercased.contains("thin") { return "100" }
        if lowercased.contains("ultralight") || lowercased.contains("ultra light") { return "200" }
        if lowercased.contains("light") && !lowercased.contains("ultralight") { return "300" }
        if lowercased.contains("medium") { return "500" }
        if lowercased.contains("semibold") || lowercased.contains("semi bold") { return "600" }
        if lowercased.contains("bold") && !lowercased.contains("semibold") { return "700" }
        if lowercased.contains("heavy") || lowercased.contains("black") { return "800" }
        return nil
    }

    private func getSVGTextAnchor(_ alignment: TextAlignment) -> String {
        switch alignment {
        case .left: return "start"
        case .center: return "middle"
        case .right: return "end"
        case .justified: return "start"
        }
    }

    private func exportImageShape(_ shape: VectorShape, image: CGImage, dpiScale: CGFloat) -> String {
        let transformedBounds: CGRect
        if shape.transform != .identity {
            transformedBounds = shape.bounds.applying(shape.transform)
        } else {
            transformedBounds = shape.bounds
        }
        let x = transformedBounds.minX * dpiScale
        let y = transformedBounds.minY * dpiScale
        let width = transformedBounds.width * dpiScale
        let height = transformedBounds.height * dpiScale

        var href: String
        if let embeddedData = shape.embeddedImageData {
            href = "data:image/png;base64,\(embeddedData.base64EncodedString())"
        } else {
            let mutableData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
                return ""
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                return ""
            }
            let base64 = mutableData.base64EncodedString()
            href = "data:image/png;base64,\(base64)"
        }
        var svg = ""
        if let clipId = shape.clippedByShapeID {
            svg += "<g clip-path=\"url(#clip_\(clipId.uuidString))\">\n"
            svg += "  <image x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" xlink:href=\"\(href)\" preserveAspectRatio=\"none\"/>\n"
            svg += "</g>\n"
        } else {
            svg += "<image x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" xlink:href=\"\(href)\" preserveAspectRatio=\"none\"/>\n"
        }
        return svg
    }

    private func generatePathData(from path: VectorPath, transform: CGAffineTransform, dpiScale: CGFloat = 1.0) -> String {
        var pathData = ""

        let scaleTransform = CGAffineTransform(scaleX: dpiScale, y: dpiScale)
        let combinedTransform = transform.concatenating(scaleTransform)
        for element in path.elements {
            switch element {
            case .move(let to):
                let point = to.cgPoint.applying(combinedTransform)
                pathData += "M\(point.x),\(point.y) "
            case .line(let to):
                let point = to.cgPoint.applying(combinedTransform)
                pathData += "L\(point.x),\(point.y) "
            case .curve(let to, let control1, let control2):
                let toPoint = to.cgPoint.applying(combinedTransform)
                let c1 = control1.cgPoint.applying(combinedTransform)
                let c2 = control2.cgPoint.applying(combinedTransform)
                pathData += "C\(c1.x),\(c1.y) \(c2.x),\(c2.y) \(toPoint.x),\(toPoint.y) "
            case .quadCurve(let to, let control):
                let toPoint = to.cgPoint.applying(combinedTransform)
                let c = control.cgPoint.applying(combinedTransform)
                pathData += "Q\(c.x),\(c.y) \(toPoint.x),\(toPoint.y) "
            case .close:
                pathData += "Z "
            }
        }
        return pathData.trimmingCharacters(in: .whitespaces)
    }

    private func generateGradientDefs(from document: VectorDocument) -> String {
        var defs = ""
        var processedGradients = Set<Int>()
        for vectorObject in document.snapshot.objects.values {
            if case .shape(let shape) = vectorObject.objectType {
                if let fillStyle = shape.fillStyle,
                   case .gradient(let gradient) = fillStyle.color {
                    let hash = gradient.hashValue
                    if !processedGradients.contains(hash) {
                        processedGradients.insert(hash)
                        defs += generateGradientDef(gradient, id: "gradient_\(hash)")
                    }
                }
                if let strokeStyle = shape.strokeStyle,
                   case .gradient(let gradient) = strokeStyle.color {
                    let hash = gradient.hashValue
                    if !processedGradients.contains(hash) {
                        processedGradients.insert(hash)
                        defs += generateGradientDef(gradient, id: "gradient_\(hash)")
                    }
                }
            }
        }
        return defs
    }

    private func generateClipPathDefs(from document: VectorDocument) -> String {
        var defs = ""
        var processedClipPaths = Set<UUID>()
        for vectorObject in document.snapshot.objects.values {
            let candidate = vectorObject.shape
            if candidate.isClippingPath && !processedClipPaths.contains(candidate.id) {
                processedClipPaths.insert(candidate.id)
                let pathData = generatePathData(from: candidate.path, transform: candidate.transform)
                let clipRule = candidate.clipFillRule == .evenOdd ? " clip-rule=\"evenodd\"" : ""
                defs += "<clipPath id=\"clip_\(candidate.id.uuidString)\" clipPathUnits=\"userSpaceOnUse\">\n"
                defs += "  <path d=\"\(pathData)\"\(clipRule)/>\n"
                defs += "</clipPath>\n"
            }
            if candidate.isClippingGroup && !processedClipPaths.contains(candidate.id),
               let members = resolveClippingGroupMembers(candidate, in: document),
               let mask = members.first {
                processedClipPaths.insert(candidate.id)
                let pathData = generatePathData(from: mask.path, transform: mask.transform)
                let clipRule = mask.clipFillRule == .evenOdd ? " clip-rule=\"evenodd\"" : ""
                defs += "<clipPath id=\"clip_\(candidate.id.uuidString)\" clipPathUnits=\"userSpaceOnUse\">\n"
                defs += "  <path d=\"\(pathData)\"\(clipRule)/>\n"
                defs += "</clipPath>\n"
            }
        }
        return defs
    }

    private func resolveClippingGroupMembers(_ shape: VectorShape, in document: VectorDocument?) -> [VectorShape]? {
        if !shape.memberIDs.isEmpty, let doc = document {
            let resolved = shape.memberIDs.compactMap { doc.findShape(by: $0) }
            return resolved.isEmpty ? nil : resolved
        }
        if !shape.groupedShapes.isEmpty {
            return shape.groupedShapes
        }
        return nil
    }

    private func generateGradientDef(_ gradient: VectorGradient, id: String) -> String {
        switch gradient {
        case .linear(let linearGradient):
            return generateLinearGradientDef(linearGradient, id: id)
        case .radial(let radialGradient):
            return generateRadialGradientDef(radialGradient, id: id)
        }
    }

    private func generateLinearGradientDef(_ gradient: LinearGradient, id: String) -> String {
        var svg = "<linearGradient id=\"\(id)\""

        let angle = gradient.angle * .pi / 180
        let x1 = 0.5 - cos(angle) * 0.5
        let y1 = 0.5 - sin(angle) * 0.5
        let x2 = 0.5 + cos(angle) * 0.5
        let y2 = 0.5 + sin(angle) * 0.5
        svg += " x1=\"\(x1 * 100)%\" y1=\"\(y1 * 100)%\""
        svg += " x2=\"\(x2 * 100)%\" y2=\"\(y2 * 100)%\">\n"
        for stop in gradient.stops {
            svg += "<stop offset=\"\(stop.position * 100)%\" stop-color=\"\(stop.color.svgColor)\"/>\n"
        }
        svg += "</linearGradient>\n"
        return svg
    }

    private func generateRadialGradientDef(_ gradient: RadialGradient, id: String) -> String {
        var svg = "<radialGradient id=\"\(id)\""
        svg += " cx=\"50%\" cy=\"50%\" r=\"50%\">\n"
        for stop in gradient.stops {
            svg += "<stop offset=\"\(stop.position * 100)%\" stop-color=\"\(stop.color.svgColor)\"/>\n"
        }
        svg += "</radialGradient>\n"
        return svg
    }

    private func formatSVGNumber(_ value: CGFloat) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
