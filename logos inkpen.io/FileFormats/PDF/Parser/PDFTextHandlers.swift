import SwiftUI

extension PDFCommandParser {

    func handleBeginText() {
        isInTextObject = true
        currentTextMatrix = .identity
        currentLineMatrix = .identity
        simdTextMatrix = PDFSIMDMatrix()
        simdLineMatrix = PDFSIMDMatrix()
        currentTextStartPosition = CGPoint(
            x: currentTransformMatrix.tx,
            y: currentTransformMatrix.ty
        )
        currentTextContent = ""
    }

    func handleEndText() {
        guard isInTextObject else { return }
        isInTextObject = false
        if !currentTextContent.isEmpty {
            createVectorTextFromAccumulated()
        }
        currentTextContent = ""
        currentTextMatrix = .identity
        currentLineMatrix = .identity
        simdTextMatrix = PDFSIMDMatrix()
        simdLineMatrix = PDFSIMDMatrix()
    }

    func handleSetFont(scanner: CGPDFScannerRef) {
        var fontNamePointer: UnsafePointer<CChar>?
        var fontSize: CGPDFReal = 12.0
        if CGPDFScannerPopNumber(scanner, &fontSize),
           CGPDFScannerPopName(scanner, &fontNamePointer) {
            let fontName = fontNamePointer.map { String(cString: $0) } ?? "Helvetica"
            currentFontName = fontName
            currentFontSize = Double(fontSize)
            if let (resolvedFont, fontDict) = resolveFontFromResourcesWithDict(fontName) {
                currentFontName = resolvedFont
                currentFontDict = fontDict
            } else if let resolvedFont = resolveFontFromResources(fontName) {
                currentFontName = resolvedFont
                currentFontDict = nil
            }
        } else {
            Log.error("PDF Text: Failed to parse Tf operator", category: .error)
        }
    }

    func handleSetCharacterSpacing(scanner: CGPDFScannerRef) {
        var charSpace: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &charSpace) {
            textCharacterSpacing = Double(charSpace)
        }
    }

    func handleSetWordSpacing(scanner: CGPDFScannerRef) {
        var wordSpace: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &wordSpace) {
            textWordSpacing = Double(wordSpace)
        }
    }

    func handleSetHorizontalScaling(scanner: CGPDFScannerRef) {
        var scale: CGPDFReal = 100
        if CGPDFScannerPopNumber(scanner, &scale) {
            textHorizontalScaling = Double(scale)
        }
    }

    func handleSetTextLeading(scanner: CGPDFScannerRef) {
        var leading: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &leading) {
            textLeading = Double(leading)
        }
    }

    func handleSetTextRenderingMode(scanner: CGPDFScannerRef) {
        var mode: CGPDFInteger = 0
        if CGPDFScannerPopInteger(scanner, &mode) {
            textRenderingMode = Int(mode)
        }
    }

    func handleSetTextRise(scanner: CGPDFScannerRef) {
        var rise: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &rise) {
            textRise = Double(rise)
        }
    }

    private func appendInterWordSpaceIfNeeded() {
        guard !currentTextContent.isEmpty else { return }
        let last = currentTextContent.unicodeScalars.last
        if let scalar = last, CharacterSet.whitespaces.contains(scalar) { return }
        currentTextContent += " "
    }

    func handleTextMove(scanner: CGPDFScannerRef) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &ty),
           CGPDFScannerPopNumber(scanner, &tx) {
            let translation = PDFSIMDMatrix.translation(tx: CGFloat(tx), ty: CGFloat(ty))
            simdLineMatrix.concatenate(translation)
            simdTextMatrix = simdLineMatrix
            currentLineMatrix = simdLineMatrix.cgAffineTransform
            currentTextMatrix = simdTextMatrix.cgAffineTransform
            let isNewLine = abs(ty) > 0.01
            if isNewLine {
                if !currentTextContent.isEmpty {
                    createVectorTextFromAccumulated()
                    currentTextContent = ""
                }
                currentTextStartPosition = CGPoint(x: simdTextMatrix.tx, y: simdTextMatrix.ty)
            } else {
                appendInterWordSpaceIfNeeded()
            }
        }
    }

    func handleTextMoveWithLeading(scanner: CGPDFScannerRef) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &ty),
           CGPDFScannerPopNumber(scanner, &tx) {
            textLeading = -Double(ty)
            let translation = PDFSIMDMatrix.translation(tx: CGFloat(tx), ty: CGFloat(ty))
            simdLineMatrix.concatenate(translation)
            simdTextMatrix = simdLineMatrix
            currentLineMatrix = simdLineMatrix.cgAffineTransform
            currentTextMatrix = simdTextMatrix.cgAffineTransform
            let isNewLine = abs(ty) > 0.01
            if isNewLine {
                if !currentTextContent.isEmpty {
                    createVectorTextFromAccumulated()
                    currentTextContent = ""
                }
                currentTextStartPosition = CGPoint(x: simdTextMatrix.tx, y: simdTextMatrix.ty)
            } else {
                appendInterWordSpaceIfNeeded()
            }
        }
    }

    func handleSetTextMatrix(scanner: CGPDFScannerRef) {
        var a: CGPDFReal = 1, b: CGPDFReal = 0
        var c: CGPDFReal = 0, d: CGPDFReal = 1
        var e: CGPDFReal = 0, f: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &f),
           CGPDFScannerPopNumber(scanner, &e),
           CGPDFScannerPopNumber(scanner, &d),
           CGPDFScannerPopNumber(scanner, &c),
           CGPDFScannerPopNumber(scanner, &b),
           CGPDFScannerPopNumber(scanner, &a) {
            let oldF = CGFloat(simdTextMatrix.ty)
            let newF = CGFloat(f)
            let yDelta = abs(newF - oldF)
            if !currentTextContent.isEmpty && isInTextObject {
                if yDelta > 1.0 {
                    createVectorTextFromAccumulated()
                    currentTextContent = ""
                } else {
                    appendInterWordSpaceIfNeeded()
                }
            }
            simdTextMatrix = PDFSIMDMatrix(a: CGFloat(a), b: CGFloat(b),
                                           c: CGFloat(c), d: CGFloat(d),
                                           tx: CGFloat(e), ty: CGFloat(f))
            simdLineMatrix = simdTextMatrix
            currentTextMatrix = simdTextMatrix.cgAffineTransform
            currentLineMatrix = simdLineMatrix.cgAffineTransform
            if usesTextMatrixForPosition == nil {
                let tmHasPosition = abs(e) > 1.0 || abs(f) > 1.0
                let ctmHasPosition = abs(currentTransformMatrix.tx) > 1.0 || abs(currentTransformMatrix.ty) > 1.0
                if tmHasPosition && !ctmHasPosition {
                    usesTextMatrixForPosition = true
                } else if ctmHasPosition && (!tmHasPosition || (abs(e) < 1.0 && abs(f) < 1.0)) {
                    usesTextMatrixForPosition = false
                }
            }
            if currentTextContent.isEmpty {
                currentTextStartPosition = CGPoint(x: CGFloat(e), y: CGFloat(f))
            }
        }
    }

    func handleTextNewLine() {
        if !currentTextContent.isEmpty {
            createVectorTextFromAccumulated()
            currentTextContent = ""
        }
        let translation = CGAffineTransform(translationX: 0, y: -CGFloat(textLeading))
        currentLineMatrix = currentLineMatrix.concatenating(translation)
        currentTextMatrix = currentLineMatrix
        currentTextStartPosition = CGPoint(x: currentTextMatrix.tx, y: currentTextMatrix.ty)
    }

    func handleShowText(scanner: CGPDFScannerRef) {
        var stringRef: CGPDFStringRef?
        if CGPDFScannerPopString(scanner, &stringRef),

           let stringRef = stringRef {
            let text = extractTextFromPDFString(stringRef)
            currentTextContent += text
            advanceTextPosition(for: text)
        }
    }

    func handleShowTextWithPositioning(scanner: CGPDFScannerRef) {
        var arrayRef: CGPDFArrayRef?
        if CGPDFScannerPopArray(scanner, &arrayRef),

           let arrayRef = arrayRef {
            let count = CGPDFArrayGetCount(arrayRef)

            var combinedText = ""
            for index in 0..<count {
                var stringRef: CGPDFStringRef?
                var numberValue: CGPDFReal = 0
                if CGPDFArrayGetString(arrayRef, index, &stringRef),

                   let stringRef = stringRef {
                    let text = extractTextFromPDFString(stringRef)
                    combinedText += text
                } else if CGPDFArrayGetNumber(arrayRef, index, &numberValue) {
                    if numberValue < -100 {
                        combinedText += " "
                    }
                }
            }
            currentTextContent += combinedText
            advanceTextPosition(for: combinedText)
        }
    }

    func handleMoveAndShowText(scanner: CGPDFScannerRef) {
        handleTextNewLine()
        handleShowText(scanner: scanner)
    }

    func handleSpacingMoveAndShowText(scanner: CGPDFScannerRef) {
        var stringRef: CGPDFStringRef?
        var wordSpace: CGPDFReal = 0
        var charSpace: CGPDFReal = 0
        if CGPDFScannerPopString(scanner, &stringRef),
           CGPDFScannerPopNumber(scanner, &charSpace),
           CGPDFScannerPopNumber(scanner, &wordSpace) {
            textWordSpacing = Double(wordSpace)
            textCharacterSpacing = Double(charSpace)
            handleTextNewLine()
            if let stringRef = stringRef {
                let text = extractTextFromPDFString(stringRef)
                currentTextContent += text
                advanceTextPosition(for: text)
            }
        }
    }

    private func extractTextFromPDFString(_ pdfString: CGPDFStringRef) -> String {
        if let fontDict = currentFontDict {
            if let decodedText = decodeTextUsingToUnicode(pdfString, fontDict: fontDict) {
                return decodedText
            }
        }
        if let cfString = CGPDFStringCopyTextString(pdfString) {
            let result = cfString as String
            if result.contains("\u{FB00}") || result.contains("\u{FB01}") ||
               result.contains("\u{FB02}") || result.contains("\u{FB03}") || result.contains("\u{FB04}") {
            }
            return result
        }
        let length = CGPDFStringGetLength(pdfString)
        if length > 0, let bytes = CGPDFStringGetBytePtr(pdfString) {
            let data = Data(bytes: bytes, count: length)
            if let text = String(data: data, encoding: .utf8) {
                return text
            } else if let text = String(data: data, encoding: .ascii) {
                return text
            } else {
                if let text = String(data: data, encoding: .macOSRoman) {
                    return text
                }
            }
            Log.warning("   Could not decode text, raw bytes: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))", category: .general)
        }
        return ""
    }

    private func decodeTextUsingToUnicode(_ pdfString: CGPDFStringRef, fontDict: CGPDFDictionaryRef) -> String? {
        var toUnicodeStream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(fontDict, "ToUnicode", &toUnicodeStream),

              let toUnicodeStream = toUnicodeStream else {
            return nil
        }
        var format = CGPDFDataFormat.raw
        guard let streamData = CGPDFStreamCopyData(toUnicodeStream, &format) as Data? else {
            return nil
        }
        guard let cmapString = String(data: streamData, encoding: .utf8) ??
                               String(data: streamData, encoding: .ascii) else {
            return nil
        }
        let codeToUnicode = parseCMap(cmapString)
        guard !codeToUnicode.isEmpty else { return nil }
        let length = CGPDFStringGetLength(pdfString)
        guard length > 0, let bytes = CGPDFStringGetBytePtr(pdfString) else {
            return nil
        }
        let isTwoByteFont = isCIDFont(fontDict) || codeToUnicode.keys.contains(where: { $0 > 0xFF })
        let stride = isTwoByteFont ? 2 : 1

        var result = ""
        var i = 0
        while i < length {
            let charCode: UInt16
            if stride == 2 && i + 1 < length {
                charCode = (UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1])
            } else {
                charCode = UInt16(bytes[i])
            }
            if let unicodeString = codeToUnicode[charCode] {
                result += unicodeString
            } else if stride == 1 {
                let scalar = UnicodeScalar(UInt8(charCode))
                result += String(scalar)
            }
            i += stride
        }
        return result.isEmpty ? nil : result
    }

    private func isCIDFont(_ fontDict: CGPDFDictionaryRef) -> Bool {
        var subtype: UnsafePointer<CChar>?
        if CGPDFDictionaryGetName(fontDict, "Subtype", &subtype),

           let subtype = subtype {
            let name = String(cString: subtype)
            return name == "Type0"
        }
        return false
    }

    private func parseCMap(_ cmapString: String) -> [UInt16: String] {
        var mapping: [UInt16: String] = [:]

        let bfcharPattern = "<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>"
        if let regex = try? NSRegularExpression(pattern: bfcharPattern, options: []) {
            let range = NSRange(cmapString.startIndex..., in: cmapString)
            regex.enumerateMatches(in: cmapString, options: [], range: range) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges == 3,
                      let charCodeRange = Range(match.range(at: 1), in: cmapString),

                      let unicodeRange = Range(match.range(at: 2), in: cmapString) else {
                    return
                }
                let charCodeHex = String(cmapString[charCodeRange])
                let unicodeHex = String(cmapString[unicodeRange])
                if let charCode = UInt16(charCodeHex, radix: 16) {
                    var unicodeString = ""

                    let hexChars = Array(unicodeHex)
                    for i in stride(from: 0, to: hexChars.count, by: 4) {
                        if i + 4 <= hexChars.count {
                            let hexValue = String(hexChars[i..<min(i+4, hexChars.count)])
                            if let scalar = UInt32(hexValue, radix: 16),

                               let unicodeScalar = UnicodeScalar(scalar) {
                                unicodeString.append(Character(unicodeScalar))
                            }
                        }
                    }
                    if !unicodeString.isEmpty {
                        mapping[charCode] = unicodeString
                    }
                }
            }
        }
        let bfrangePattern = "<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>"
        if let regex = try? NSRegularExpression(pattern: bfrangePattern, options: []) {
            let range = NSRange(cmapString.startIndex..., in: cmapString)
            regex.enumerateMatches(in: cmapString, options: [], range: range) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges == 4,
                      let startCodeRange = Range(match.range(at: 1), in: cmapString),
                      let endCodeRange = Range(match.range(at: 2), in: cmapString),

                      let unicodeRange = Range(match.range(at: 3), in: cmapString) else {
                    return
                }
                let startCodeHex = String(cmapString[startCodeRange])
                let endCodeHex = String(cmapString[endCodeRange])
                let unicodeHex = String(cmapString[unicodeRange])
                if let startCode = UInt16(startCodeHex, radix: 16),
                   let endCode = UInt16(endCodeHex, radix: 16),

                   let baseUnicode = UInt32(unicodeHex, radix: 16) {
                    for charCode in startCode...endCode {
                        let unicodeValue = baseUnicode + UInt32(charCode - startCode)

                        var unicodeString = ""

                        let hexChars = String(format: "%04X", unicodeValue)
                        for i in stride(from: 0, to: hexChars.count, by: 4) {
                            let startIdx = hexChars.index(hexChars.startIndex, offsetBy: i)
                            let endIdx = hexChars.index(startIdx, offsetBy: min(4, hexChars.count - i))
                            let hexValue = String(hexChars[startIdx..<endIdx])
                            if let scalar = UInt32(hexValue, radix: 16),

                               let unicodeScalar = UnicodeScalar(scalar) {
                                unicodeString.append(Character(unicodeScalar))
                            }
                        }
                        if !unicodeString.isEmpty {
                            mapping[charCode] = unicodeString
                        }
                    }
                }
            }
        }
        return mapping
    }

    private func cleanPDFFontName(_ fontName: String) -> String {
        if let plusIndex = fontName.firstIndex(of: "+") {
            return String(fontName[fontName.index(after: plusIndex)...])
        }
        return fontName
    }

    private func resolveFontFromResources(_ resourceName: String) -> String? {
        guard let resources = pageResourcesDict else { return nil }
        var fontDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fontDict),

           let fontDict = fontDict {
            var fontRef: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(fontDict, resourceName, &fontRef),

               let fontRef = fontRef {
                var baseFontName: UnsafePointer<CChar>?
                if CGPDFDictionaryGetName(fontRef, "BaseFont", &baseFontName),

                   let baseFontName = baseFontName {
                    return cleanPDFFontName(String(cString: baseFontName))
                }
            }
        }
        return nil
    }

    private func resolveFontFromResourcesWithDict(_ resourceName: String) -> (String, CGPDFDictionaryRef)? {
        guard let resources = pageResourcesDict else { return nil }
        var fontDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fontDict),

           let fontDict = fontDict {
            var fontRef: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(fontDict, resourceName, &fontRef),

               let fontRef = fontRef {
                var baseFontName: UnsafePointer<CChar>?
                if CGPDFDictionaryGetName(fontRef, "BaseFont", &baseFontName),

                   let baseFontName = baseFontName {
                    return (cleanPDFFontName(String(cString: baseFontName)), fontRef)
                }
            }
        }
        return nil
    }

    private func resolveMacOSFont(postScriptName rawName: String) -> (family: String, variant: String?) {
        if let result = macOSFontFromPostScriptName(rawName) {
            return result
        }
        let suffixesToStrip = ["PSMT", "PS", "MT"]

        var stripped = rawName
        for suffix in suffixesToStrip {
            if stripped.hasSuffix(suffix) {
                stripped = String(stripped.dropLast(suffix.count))
                if stripped.hasSuffix("-") {
                    stripped = String(stripped.dropLast())
                }
                if let result = macOSFontFromPostScriptName(stripped) {
                    return result
                }
            }
        }
        let (rawFamily, rawVariant) = dashSplitFamilyVariant(stripped)
        let availableFamilies = NSFontManager.shared.availableFontFamilies
        if let exactFamily = availableFamilies.first(where: { $0.caseInsensitiveCompare(rawFamily) == .orderedSame }) {
            return (family: exactFamily, variant: closestVariantDisplayName(in: exactFamily, requested: rawVariant))
        }
        let fallbackFamily = availableFamilies.first(where: { $0 == "Helvetica Neue" })
            ?? availableFamilies.first(where: { $0 == "Helvetica" })
            ?? availableFamilies.first
            ?? "Helvetica Neue"
        return (family: fallbackFamily, variant: closestVariantDisplayName(in: fallbackFamily, requested: rawVariant))
    }

    private func macOSFontFromPostScriptName(_ name: String) -> (family: String, variant: String?)? {
        guard let font = PlatformFont(name: name, size: 12) else { return nil }
        let returnedPS = font.fontName
        let family = font.familyName ?? name
        let members = NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []
        for member in members {
            if let postScript = member[0] as? String,
               let displayName = member[1] as? String,
               postScript == name || postScript == returnedPS {
                return (family: family, variant: displayName)
            }
        }
        return (family: family, variant: nil)
    }

    private func dashSplitFamilyVariant(_ name: String) -> (family: String, variant: String?) {
        if let dashIdx = name.lastIndex(of: "-") {
            return (family: String(name[..<dashIdx]),
                    variant: String(name[name.index(after: dashIdx)...]))
        }
        return (family: name, variant: nil)
    }

    private func closestVariantDisplayName(in family: String, requested: String?) -> String? {
        let members = NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []
        let displayNames: [String] = members.compactMap { $0[1] as? String }
        guard !displayNames.isEmpty else { return nil }
        guard let req = requested, !req.isEmpty else {
            return displayNames.first(where: { $0 == "Regular" }) ?? displayNames.first
        }
        if displayNames.contains(req) { return req }
        if let match = displayNames.first(where: { $0.caseInsensitiveCompare(req) == .orderedSame }) {
            return match
        }
        let reqLower = req.lowercased()
        let wantBold = reqLower.contains("bold") || reqLower.contains("heavy") || reqLower.contains("black")
        let wantItalic = reqLower.contains("italic") || reqLower.contains("oblique")
        let wantLight = reqLower.contains("light") || reqLower.contains("thin")
        let wantMedium = reqLower.contains("medium")

        func score(_ name: String) -> Int {
            let n = name.lowercased()
            let isBold = n.contains("bold") || n.contains("heavy") || n.contains("black")
            let isItalic = n.contains("italic") || n.contains("oblique")
            let isLight = n.contains("light") || n.contains("thin")
            let isMedium = n.contains("medium")

            var s = 0
            if isBold == wantBold { s += 8 }
            if isItalic == wantItalic { s += 4 }
            if isLight == wantLight { s += 2 }
            if isMedium == wantMedium { s += 1 }
            s -= name.count / 20
            return s
        }
        return displayNames.max(by: { score($0) < score($1) }) ?? displayNames.first
    }

    private func advanceTextPosition(for text: String) {
        let estimatedWidth = Double(text.count) * currentFontSize * 0.5
        let advance = estimatedWidth * (textHorizontalScaling / 100.0)
        let translation = CGAffineTransform(translationX: CGFloat(advance), y: 0)
        currentTextMatrix = currentTextMatrix.concatenating(translation)
    }

    private func createVectorTextFromAccumulated() {
        let trimmed = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        currentTextContent = normalized
        var pdfX = currentTextStartPosition.x
        var pdfY = currentTextStartPosition.y

        let tm = currentTextMatrix
        let matrixFontSize = abs(tm.d)
        let actualFontSize = currentFontSize * matrixFontSize
        if let usesTm = usesTextMatrixForPosition, !usesTm {
            pdfX = currentTransformMatrix.tx
            pdfY = currentTransformMatrix.ty
        }
        let flippedY = pageSize.height - pdfY
        let finalY = flippedY - actualFontSize
        let position = CGPoint(x: pdfX, y: finalY)
        let fullFontName = currentFontName ?? "Helvetica"
        let (fontFamily, fontVariant) = resolveMacOSFont(postScriptName: fullFontName)
        let fontSize = actualFontSize
        let hasFill = textRenderingMode == 0 || textRenderingMode == 2 || textRenderingMode == 4 || textRenderingMode == 6
        let hasStroke = textRenderingMode == 1 || textRenderingMode == 2 || textRenderingMode == 5 || textRenderingMode == 6
        let fillColor: VectorColor
        let strokeColor: VectorColor
        if hasFill, let components = currentFillColor.components, components.count >= 3 {
            fillColor = .rgb(RGBColor(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2])))
        } else {
            fillColor = .black
        }
        if hasStroke, let components = currentStrokeColor.components, components.count >= 3 {
            strokeColor = .rgb(RGBColor(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2])))
        } else {
            strokeColor = .black
        }
        let typography = TypographyProperties(
            fontFamily: fontFamily,
            fontVariant: fontVariant,
            fontSize: fontSize,
            lineHeight: fontSize * 1.2,
            lineSpacing: textLeading,
            letterSpacing: textCharacterSpacing,
            alignment: .left,
            hasStroke: hasStroke,
            strokeColor: strokeColor,
            strokeWidth: hasStroke ? currentLineWidth : 1.0,
            strokeOpacity: hasStroke ? currentStrokeOpacity : 1.0,
            fillColor: fillColor,
            fillOpacity: hasFill ? currentFillOpacity : 1.0
        )
        let lines = currentTextContent.components(separatedBy: .newlines)
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        let estimatedWidth = Double(maxLineLength) * fontSize * 0.6
        let estimatedHeight = Double(lines.count) * fontSize * 1.2

        var vectorText = VectorText(
            content: currentTextContent,
            typography: typography,
            position: position,
            areaSize: CGSize(width: max(100, estimatedWidth), height: max(fontSize, estimatedHeight))
        )
        vectorText.bounds = CGRect(
            x: position.x,
            y: position.y,
            width: max(100, estimatedWidth),
            height: max(fontSize, estimatedHeight)
        )
        let shape = vectorText.toVectorShape()
        shapes.append(shape)
        onShapeCreated?(shape)
    }
}
