import SwiftUI

extension SVGParser {

    internal func getCachedFont(family: String, size: Double) -> PlatformFont {
        let cacheKey = "\(family)-\(size)"
        if let cached = fontCache[cacheKey] {
            return cached
        }
        let byPostScriptName = PlatformFont(name: family, size: size)

        let byFamily: PlatformFont? = {
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family])
            return NSFont(descriptor: descriptor, size: size)
        }()
        let nsFont = byPostScriptName ?? byFamily ?? PlatformFont.systemFont(ofSize: size)
        fontCache[cacheKey] = nsFont
        return nsFont
    }

    internal func calculateTextWidth(for text: String, font: PlatformFont, alignment: TextAlignment) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        sharedTextStorage.setAttributedString(attributedString)
        let glyphRange = sharedLayoutManager.glyphRange(for: sharedTextContainer)
        let boundingRect = sharedLayoutManager.boundingRect(forGlyphRange: glyphRange, in: sharedTextContainer)
        return ceil(boundingRect.width)
    }

    internal func calculateMaxLineWidth(for text: String, font: PlatformFont, alignment: TextAlignment) -> CGFloat {
        let lines = text.components(separatedBy: "\n")

        var maxWidth: CGFloat = 0
        for line in lines {
            let lineWidth = calculateTextWidth(for: line, font: font, alignment: alignment)
            maxWidth = max(maxWidth, lineWidth)
        }
        return maxWidth
    }

    func extractFontFamily(from attributes: [String: String]) -> String? {
        if let explicit = attributes["font-family"], !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicit
        }
        if let style = attributes["style"], !style.isEmpty {
            let pairs = style.split(separator: ";")
            for pair in pairs {
                let parts = pair.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2, parts[0].lowercased() == "font-family" {
                    return parts[1]
                }
            }
        }
        return nil
    }

    func normalizeFontFamily(_ rawFamily: String?) -> String {
        guard let raw = rawFamily?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Helvetica Neue"
        }
        let candidates = raw.split(separator: ",").map { token -> String in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        let available = Set(NSFontManager.shared.availableFontFamilies.map { $0.lowercased() })
        for name in candidates {
            if available.contains(name.lowercased()) {
                return name
            }
        }
        return "Helvetica Neue"
    }

    func detectTextAlignment(from tspans: [(content: String, attributes: [String: String], x: Double, y: Double)]) -> TextAlignment {
        guard tspans.count > 1 else { return .left }
        if let firstTspan = tspans.first,

           let textAnchor = firstTspan.attributes["text-anchor"] {
            switch textAnchor.lowercased() {
            case "start": return .left
            case "middle": return .center
            case "end": return .right
            default: return .left
            }
        }
        let lines = tspans.map { (x: $0.x, contentLength: $0.content.count) }
        let sortedByLength = lines.sorted { $0.contentLength > $1.contentLength }
        if sortedByLength.count >= 2 {
            let longestLine = sortedByLength[0]
            guard let shortestLine = sortedByLength.last else { return .left }
            if shortestLine.x > longestLine.x {
                let xDifference = abs(shortestLine.x - longestLine.x)
                if xDifference > 5.0 {
                    return .center
                }
            }
        }
        let xValues = lines.map { $0.x }
        let minX = xValues.min() ?? 0
        let maxX = xValues.max() ?? 0
        if abs(maxX - minX) < 5.0 {
            return .left
        }
        return .left
    }

    func parseText(attributes: [String: String]) {
        currentTextContent = ""
        currentTextSpans.removeAll()
        isInMultiLineText = false
        var merged = attributes
        if let classAttr = attributes["class"], !classAttr.isEmpty {
            applyCSSClasses(classAttr, into: &merged)
        }
        if let style = attributes["style"], !style.isEmpty {
            let styleDict = parseStyleAttribute(style)
            for (k, v) in styleDict { merged[k] = v }
        }
        currentTextAttributes = merged
    }

    func finishTextElement() {
        if isInMultiLineText && !currentTextSpans.isEmpty {
            let baseX = parseLength(currentTextAttributes["x"]) ?? 0
            let baseY = parseLength(currentTextAttributes["y"]) ?? 0
            let textOwnTransform = parseTransform(currentTextAttributes["transform"] ?? "")
            let finalTextTransform = currentTransform.concatenating(textOwnTransform)

            var combinedContent: [String] = []
            var firstFontSize: Double = 12
            var firstFontFamily: String = "System Font"
            var firstFillColor: VectorColor = .black
            for (index, span) in currentTextSpans.enumerated() {
                let cleanContent = span.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanContent.isEmpty else { continue }
                if index == 0 || (combinedContent.isEmpty) {
                    firstFontSize = parseLength(span.attributes["font-size"]) ?? 12
                    let rawFontFamily = extractFontFamily(from: span.attributes)
                    firstFontFamily = normalizeFontFamily(rawFontFamily)
                    let fill = span.attributes["fill"] ?? "black"
                    firstFillColor = parseColor(fill) ?? .black
                }
                combinedContent.append(cleanContent)
            }
            if !combinedContent.isEmpty {
                let multiLineContent = combinedContent.joined(separator: "\n")
                let textAlignment = detectTextAlignment(from: currentTextSpans)
                let lineHeight = firstFontSize * 1.2
                let typography = TypographyProperties(
                    fontFamily: firstFontFamily,
                    fontSize: firstFontSize,
                    lineHeight: lineHeight,
                    lineSpacing: 0.0,
                    letterSpacing: 0.0,
                    alignment: textAlignment,
                    hasStroke: false,
                    strokeColor: .black,
                    strokeWidth: 0.0,
                    strokeOpacity: 1.0,
                    fillColor: firstFillColor,
                    fillOpacity: 1.0
                )
                let textAnchor = currentTextAttributes["text-anchor"]?.lowercased() ??
                                 currentTextSpans.first?.attributes["text-anchor"]?.lowercased() ??
                                 "start"
                let nsFont = getCachedFont(family: firstFontFamily, size: firstFontSize)
                let maxLineWidth = calculateMaxLineWidth(for: multiLineContent, font: nsFont, alignment: textAlignment)
                let actualWidth: CGFloat
                if let pendingRect = pendingTextBoxRect, pendingRect.width > 0 {
                    actualWidth = pendingRect.width
                    pendingTextBoxRect = nil
                } else {
                    actualWidth = maxLineWidth
                }
                var adjustedX = baseX
                if textAnchor == "middle" {
                    adjustedX -= actualWidth / 2.0
                } else if textAnchor == "end" {
                    adjustedX -= actualWidth
                }
                maxTextWidth = max(maxTextWidth, actualWidth)
                let actualHeight = lineHeight * Double(max(1, combinedContent.count))
                let finalY = baseY - (firstFontSize)

                var textObject = VectorText(
                    content: multiLineContent,
                    typography: typography,
                    position: CGPoint(x: adjustedX, y: finalY),
                    transform: finalTextTransform,
                    areaSize: CGSize(width: actualWidth, height: actualHeight)
                )
                textObject.bounds = CGRect(
                    x: adjustedX,
                    y: finalY,
                    width: actualWidth,
                    height: actualHeight
                )
                textObjects.append(textObject)
            }
        } else {
            guard !currentTextContent.isEmpty else { return }
            let x = parseLength(currentTextAttributes["x"]) ?? 0
            let y = parseLength(currentTextAttributes["y"]) ?? 0
            let fontSize = parseLength(currentTextAttributes["font-size"]) ?? 12
            let rawFontFamily = extractFontFamily(from: currentTextAttributes)
            let fontFamily = normalizeFontFamily(rawFontFamily)
            let fill = currentTextAttributes["fill"] ?? "black"
            let textOwnTransform = parseTransform(currentTextAttributes["transform"] ?? "")
            let finalTextTransform = currentTransform.concatenating(textOwnTransform)
            let textAlignment: TextAlignment
            let textAnchor = currentTextAttributes["text-anchor"]?.lowercased() ?? "start"
            switch textAnchor {
            case "start": textAlignment = .left
            case "middle": textAlignment = .center
            case "end": textAlignment = .right
            default: textAlignment = .left
            }
            let lineHeight = fontSize * 1.2
            let typography = TypographyProperties(
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineHeight: lineHeight,
                lineSpacing: 0.0,
                letterSpacing: 0.0,
                alignment: textAlignment,
                hasStroke: false,
                strokeColor: .black,
                strokeWidth: 0.0,
                strokeOpacity: 1.0,
                fillColor: parseColor(fill) ?? .black,
                fillOpacity: 1.0
            )
            let trimmedContent = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let nsFont = getCachedFont(family: fontFamily, size: fontSize)
            let textWidth = calculateTextWidth(for: trimmedContent, font: nsFont, alignment: textAlignment)
            let actualWidth: CGFloat
            if let pendingRect = pendingTextBoxRect, pendingRect.width > 0 {
                actualWidth = pendingRect.width
                pendingTextBoxRect = nil
            } else {
                actualWidth = textWidth
            }
            maxTextWidth = max(maxTextWidth, actualWidth)
            var adjustedX = x
            if textAnchor == "middle" {
                adjustedX -= actualWidth / 2.0
            } else if textAnchor == "end" {
                adjustedX -= actualWidth
            }
            let lineCount = max(1, trimmedContent.components(separatedBy: "\n").count)
            let actualHeight = lineHeight * Double(lineCount)
            let finalY = y - (fontSize)

            var textObject = VectorText(
                content: trimmedContent,
                typography: typography,
                position: CGPoint(x: adjustedX, y: finalY),
                transform: finalTextTransform,
                areaSize: CGSize(width: actualWidth, height: actualHeight)
            )
            textObject.bounds = CGRect(
                x: adjustedX,
                y: finalY,
                width: actualWidth,
                height: actualHeight
            )
            textObjects.append(textObject)
        }
        currentTextContent = ""
        currentTextAttributes = [:]
        currentTextSpans.removeAll()
        isInMultiLineText = false
    }
}
