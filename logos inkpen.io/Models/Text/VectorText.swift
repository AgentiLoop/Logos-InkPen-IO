import SwiftUI
import Combine

enum TextRenderMode: String, Codable, Hashable {
    case nstext
    case ctline
}

enum TextBoxState: String, CaseIterable {
    case editing
    case selected
    case unselected

    var description: String {
        switch self {
        case .editing: return "BLUE - Edit Mode"
        case .selected: return "GREEN - Selected & Draggable"
        case .unselected: return "GRAY - Unselected"
        }
    }
}

enum TextAlignment: String, CaseIterable, Codable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
    case justified = "Justified"

    var iconName: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        case .justified: return "text.justify"
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        }
    }
}

struct TypographyProperties: Codable, Hashable {
    var fontFamily: String
    var fontVariant: String?
    var fontSize: Double
    var lineHeight: Double
    var lineSpacing: Double
    var letterSpacing: Double
    var alignment: TextAlignment
    var hasStroke: Bool
    var strokeColor: VectorColor
    var strokeWidth: Double
    var strokeOpacity: Double
    var strokeLineJoin: LineJoin
    var fillColor: VectorColor
    var fillOpacity: Double

    static func == (lhs: TypographyProperties, rhs: TypographyProperties) -> Bool {
        return lhs.fontFamily == rhs.fontFamily
            && lhs.fontVariant == rhs.fontVariant
            && lhs.fontSize == rhs.fontSize
            && lhs.lineHeight == rhs.lineHeight
            && lhs.lineSpacing == rhs.lineSpacing
            && lhs.letterSpacing == rhs.letterSpacing
            && lhs.alignment == rhs.alignment
            && lhs.hasStroke == rhs.hasStroke
            && lhs.strokeColor == rhs.strokeColor
            && lhs.strokeWidth == rhs.strokeWidth
            && lhs.strokeOpacity == rhs.strokeOpacity
            && lhs.strokeLineJoin == rhs.strokeLineJoin
            && lhs.fillColor == rhs.fillColor
            && lhs.fillOpacity == rhs.fillOpacity
    }

    init(
        fontFamily: String = "Helvetica",
        fontVariant: String? = nil,
        fontSize: Double = 24.0,
        lineHeight: Double = 24.0,
        lineSpacing: Double = 0.0,
        letterSpacing: Double = 0.0,
        alignment: TextAlignment = .center,
        hasStroke: Bool = false,
        strokeColor: VectorColor,
        strokeWidth: Double = 1.0,
        strokeOpacity: Double = 1.0,
        strokeLineJoin: LineJoin = .miter,
        fillColor: VectorColor,
        fillOpacity: Double = 1.0
    ) {
        self.fontFamily = fontFamily
        self.fontVariant = fontVariant
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.lineSpacing = lineSpacing
        self.letterSpacing = letterSpacing
        self.alignment = alignment
        self.hasStroke = hasStroke
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.strokeOpacity = strokeOpacity
        self.strokeLineJoin = strokeLineJoin
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
    }

    var nsFont: PlatformFont {
        if let variant = fontVariant {
            let fontManager = NSFontManager.shared
            let members = fontManager.availableMembers(ofFontFamily: fontFamily) ?? []
            for member in members {
                if let postScriptName = member[0] as? String,
                   let displayName = member[1] as? String,
                   displayName == variant {
                    if let font = PlatformFont(name: postScriptName, size: fontSize) {
                        return font
                    }
                }
            }
        }
        return PlatformFont(name: fontFamily, size: fontSize) ?? PlatformFont.systemFont(ofSize: fontSize)
    }

    var swiftUIFont: Font {
        return Font.custom(fontFamily, size: fontSize)
    }

    var nsParagraphStyle: NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, lineSpacing)
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        return paragraphStyle
    }

    func textAttributes(includeColor: Bool = false) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .kern: letterSpacing,
            .paragraphStyle: nsParagraphStyle
        ]
        if includeColor {
            attributes[.foregroundColor] = fillColor.cgColor.platformColor
        }
        return attributes
    }

    enum CodingKeys: String, CodingKey {
        case fontFamily, fontVariant, fontSize, lineHeight, lineSpacing
        case letterSpacing, alignment, hasStroke, strokeColor, strokeWidth
        case strokeOpacity, strokeLineJoin, fillColor, fillOpacity
        case fontWeight, fontStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontFamily = try container.decode(String.self, forKey: .fontFamily)
        fontVariant = try container.decodeIfPresent(String.self, forKey: .fontVariant)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        lineHeight = try container.decode(Double.self, forKey: .lineHeight)
        lineSpacing = try container.decode(Double.self, forKey: .lineSpacing)
        letterSpacing = try container.decode(Double.self, forKey: .letterSpacing)
        alignment = try container.decode(TextAlignment.self, forKey: .alignment)
        hasStroke = try container.decode(Bool.self, forKey: .hasStroke)
        strokeColor = try container.decode(VectorColor.self, forKey: .strokeColor)
        strokeWidth = try container.decode(Double.self, forKey: .strokeWidth)
        strokeOpacity = try container.decode(Double.self, forKey: .strokeOpacity)
        strokeLineJoin = try container.decodeIfPresent(LineJoin.self, forKey: .strokeLineJoin) ?? .miter
        fillColor = try container.decode(VectorColor.self, forKey: .fillColor)
        fillOpacity = try container.decode(Double.self, forKey: .fillOpacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encodeIfPresent(fontVariant, forKey: .fontVariant)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(lineHeight, forKey: .lineHeight)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(letterSpacing, forKey: .letterSpacing)
        try container.encode(alignment, forKey: .alignment)
        try container.encode(hasStroke, forKey: .hasStroke)
        try container.encode(strokeColor, forKey: .strokeColor)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(strokeOpacity, forKey: .strokeOpacity)
        try container.encode(strokeLineJoin, forKey: .strokeLineJoin)
        try container.encode(fillColor, forKey: .fillColor)
        try container.encode(fillOpacity, forKey: .fillOpacity)
    }
}

struct VectorText: Identifiable, Codable, Hashable {
    var id: UUID
    var content: String
    var typography: TypographyProperties
    var position: CGPoint
    var transform: CGAffineTransform
    var bounds: CGRect
    var isVisible: Bool
    var isLocked: Bool
    var isEditing: Bool
    var layerIndex: Int?
    var cursorPosition: Int
    var areaSize: CGSize?

    func getState(in document: VectorDocument) -> TextBoxState {
        if isEditing {
            return .editing
        } else if document.viewState.selectedObjectIDs.contains(id) {
            return .selected
        } else {
            return .unselected
        }
    }

    var canBeEdited: Bool {
        return isVisible && !isLocked
    }

    func shouldShowFontSettings(in document: VectorDocument) -> Bool {
        let state = getState(in: document)
        return state == .editing || state == .selected
    }

    var textBounds: CGRect {
        let font = createCoreTextFont()
        let displayText = content.isEmpty ? "" : content
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: typography.letterSpacing
        ]
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return textBounds
    }

    init(
        content: String = "",
        typography: TypographyProperties = TypographyProperties(strokeColor: .black, fillColor: .black),
        position: CGPoint = .zero,
        transform: CGAffineTransform = .identity,
        isVisible: Bool = true,
        isLocked: Bool = false,
        isEditing: Bool = false,
        layerIndex: Int? = nil,
        cursorPosition: Int = 0,
        areaSize: CGSize? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.typography = typography
        self.position = position
        self.transform = transform
        self.bounds = .zero
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isEditing = isEditing
        self.layerIndex = layerIndex
        self.cursorPosition = cursorPosition
        self.areaSize = areaSize
        updateBounds()
    }

    mutating func updateBounds() {
        if let userAreaSize = areaSize {
            bounds = CGRect(x: 0, y: 0, width: userAreaSize.width, height: userAreaSize.height)
            return
        }
        let hasProperBounds = bounds.width > 0 && bounds.height > 0
        let isSingleLineText = !content.contains("\n") && !content.contains("\r")
        if hasProperBounds && !isSingleLineText {
            return
        }
        let font = createCoreTextFont()
        let displayText = content.isEmpty ? "" : content
        if isSingleLineText {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: typography.letterSpacing
            ]
            let attributedString = NSAttributedString(string: displayText, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            let ascent = CTFontGetAscent(font)
            let descent = CTFontGetDescent(font)
            let leading = CTFontGetLeading(font)
            bounds = CGRect(
                x: 0,
                y: -ascent,
                width: max(textBounds.width, content.isEmpty ? 20 : 1),
                height: ascent + descent + leading
            )
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, typography.lineSpacing)
            paragraphStyle.minimumLineHeight = typography.lineHeight
            paragraphStyle.maximumLineHeight = typography.lineHeight
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: typography.letterSpacing,
                .paragraphStyle: paragraphStyle
            ]
            let attributedString = NSAttributedString(string: displayText, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            let defaultWidth: CGFloat = 300.0
            let constraintSize = CGSize(width: defaultWidth, height: CGFloat.greatestFiniteMagnitude)
            let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRangeMake(0, 0),
                nil,
                constraintSize,
                nil
            )
            let ascent = CTFontGetAscent(font)
            bounds = CGRect(
                x: 0,
                y: -ascent,
                width: max(suggestedSize.width, content.isEmpty ? 20 : 1),
                height: max(suggestedSize.height + 20, typography.lineHeight)
            )
        }
    }

    private func createCoreTextFont() -> CTFont {
        let nsFont = typography.nsFont
        return CTFontCreateWithName(nsFont.fontName as CFString, typography.fontSize, nil)
    }

    static func from(_ vectorShape: VectorShape) -> VectorText? {
        guard vectorShape.typography != nil else { return nil }
        let typography: TypographyProperties
        if let existingTypography = vectorShape.typography {
            typography = existingTypography
        } else if !vectorShape.metadata.isEmpty,
           let fontFamily = vectorShape.metadata["fontFamily"],
           let fontSizeStr = vectorShape.metadata["fontSize"],

           let fontSize = Double(fontSizeStr) {
            let letterSpacing = Double(vectorShape.metadata["letterSpacing"] ?? "0") ?? 0
            let lineSpacing = Double(vectorShape.metadata["lineSpacing"] ?? "0") ?? 0
            typography = TypographyProperties(
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineHeight: fontSize * 1.2,
                lineSpacing: lineSpacing,
                letterSpacing: letterSpacing,
                alignment: .center,
                hasStroke: vectorShape.strokeStyle != nil,
                strokeColor: vectorShape.strokeStyle?.color ?? .black,
                strokeWidth: vectorShape.strokeStyle?.width ?? 1.0,
                strokeOpacity: vectorShape.strokeStyle?.opacity ?? 1.0,
                fillColor: vectorShape.fillStyle?.color ?? .black,
                fillOpacity: vectorShape.fillStyle?.opacity ?? 1.0
            )
        } else {
            typography = TypographyProperties(
                strokeColor: vectorShape.strokeStyle?.color ?? .black,
                fillColor: vectorShape.fillStyle?.color ?? .black
            )
        }
        let position = vectorShape.textPosition ?? CGPoint(x: vectorShape.transform.tx, y: vectorShape.transform.ty)

        var vectorText = VectorText(
            content: vectorShape.textContent ?? "",
            typography: typography,
            position: position,
            areaSize: vectorShape.areaSize
        )
        vectorText.bounds = vectorShape.bounds
        vectorText.id = vectorShape.id
        vectorText.isLocked = vectorShape.isLocked
        vectorText.isVisible = vectorShape.isVisible
        vectorText.isEditing = vectorShape.isEditing ?? false
        vectorText.cursorPosition = vectorShape.cursorPosition ?? 0
        return vectorText
    }
}

class FontManager: ObservableObject {
    private static var sharedAvailableFonts: [String] = []
    private static var sharedSystemFonts: [String] = []
    private static var sharedFontsLoaded = false

    var availableFonts: [String] { Self.sharedAvailableFonts }
    var systemFonts: [String] { Self.sharedSystemFonts }
    var googleFonts: [String] = []

    private static var sharedFontVariantsCache: [String: [String]] = [:]
    private static var sharedPostScriptNameCache: [String: String] = [:]

    @Published var selectedFontFamily: String = "Helvetica Neue"
    @Published var selectedFontVariant: String = "Regular"
    @Published var selectedFontSize: Double = 24.0
    @Published var selectedLineSpacing: Double = 0.0
    @Published var selectedLineHeight: Double = 24.0
    @Published var selectedTextAlignment: TextAlignment = .center
    init() {
        if !Self.sharedFontsLoaded {
            loadAvailableFonts()
            Self.sharedFontsLoaded = true
        }
    }

    func clearVariantsCache() {
        Self.sharedFontVariantsCache.removeAll()
        Self.sharedPostScriptNameCache.removeAll()
    }

    private func loadAvailableFonts() {
        let fontManager = NSFontManager.shared
        Self.sharedSystemFonts = fontManager.availableFontFamilies.sorted()
        let excludedFontPrefixes = [
            "Noto ",
            ".Apple"
        ]
        let excludedFontSuffixes = [
            " HK",
            " MO",
            " SC",
            " TC",
            " MN",
            " MT",
            " GB",
            "Sangam MN"
        ]
        let excludedSymbolFonts = [
            "Zapf Dingbats",
            "Webdings",
            "Wingdings",
            "Wingdings 2",
            "Wingdings 3",
            "Symbol",
            "Apple Symbols",
            "Apple Color Emoji",
            "Bodoni Ornaments",
            "GB18030 Bitmap"
        ]
        var orderedFonts: [String] = []
        for font in systemFonts {
            let hasExcludedPrefix = excludedFontPrefixes.contains { prefix in
                font.hasPrefix(prefix)
            }
            let hasExcludedSuffix = excludedFontSuffixes.contains { suffix in
                font.hasSuffix(suffix)
            }
            let isSymbolFont = excludedSymbolFonts.contains(font)
            if !hasExcludedPrefix && !hasExcludedSuffix && !isSymbolFont && !orderedFonts.contains(font) {
                orderedFonts.append(font)
            }
        }
        Self.sharedAvailableFonts = orderedFonts
    }

    private func getWeightOrder(_ variantName: String) -> Int {
        let name = variantName.lowercased()
        let isItalic = name.contains("italic") || name.contains("oblique")
        if name.contains("condensed") && name.contains("black") {
            return isItalic ? 31 : 30
        }
        if name.contains("condensed") && name.contains("bold") {
            return isItalic ? 29 : 28
        }
        if name.contains("extra") && name.contains("black") {
            return isItalic ? 27 : 26
        }
        if name.contains("ultra") && name.contains("black") {
            return isItalic ? 25 : 24
        }
        if name.contains("extra") && name.contains("bold") {
            return isItalic ? 19 : 18
        }
        if name.contains("ultra") && name.contains("light") {
            return isItalic ? 1 : 0
        }
        if name.contains("demi") && name.contains("bold") {
            return isItalic ? 13 : 12
        }
        if name.contains("semi") && name.contains("bold") {
            return isItalic ? 15 : 14
        }
        if name.contains("black") {
            return isItalic ? 23 : 22
        }
        if name.contains("heavy") {
            return isItalic ? 21 : 20
        }
        if name.contains("bold") {
            return isItalic ? 17 : 16
        }
        if name.contains("medium") {
            return isItalic ? 11 : 10
        }
        if name.contains("book") {
            return isItalic ? 7 : 6
        }
        if name.contains("light") {
            return isItalic ? 5 : 4
        }
        if name.contains("thin") {
            return isItalic ? 3 : 2
        }
        if name.contains("regular") || name.contains("normal") {
            return isItalic ? 9 : 8
        }
        if isItalic {
            return 9
        }
        return 1000
    }

    func getAvailableVariantNames(for family: String) -> [String] {
        if let cached = Self.sharedFontVariantsCache[family] {
            return cached
        }
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        let excludeKeywords = ["ornament", "swash", "alternate", "expert", "small cap",
                               "oldstyle", "lining", "tabular", "proportional"]
        var variants: [(name: String, weight: Int, traits: Int, originalIndex: Int)] = []
        var seenNames = Set<String>()
        for (index, member) in members.enumerated() {
            if let postScriptName = member[0] as? String,
               let displayName = member[1] as? String,
               let weightNumber = member[2] as? NSNumber,

               let traitsNumber = member[3] as? NSNumber {
                let lowercasedName = displayName.lowercased()
                let shouldExclude = excludeKeywords.contains { keyword in
                    lowercasedName.contains(keyword)
                }
                if !shouldExclude, !seenNames.contains(displayName), PlatformFont(name: postScriptName, size: 12) != nil {
                    variants.append((
                        name: displayName,
                        weight: weightNumber.intValue,
                        traits: traitsNumber.intValue,
                        originalIndex: index
                    ))
                    seenNames.insert(displayName)
                }
            }
        }
        let sortedVariants = variants.sorted { lhs, rhs in
            let lhsOrder = getWeightOrder(lhs.name)
            let rhsOrder = getWeightOrder(rhs.name)
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            } else if lhs.traits != rhs.traits {
                return lhs.traits < rhs.traits
            } else {
                return lhs.originalIndex < rhs.originalIndex
            }
        }.map { $0.name }
        Self.sharedFontVariantsCache[family] = sortedVariants
        return sortedVariants
    }

    func getPostScriptName(family: String, variant: String) -> String? {
        let cacheKey = "\(family)-\(variant)"
        if let cached = Self.sharedPostScriptNameCache[cacheKey] {
            return cached
        }
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        for member in members {
            if let postScriptName = member[0] as? String,
               let displayName = member[1] as? String,
               displayName == variant {
                Self.sharedPostScriptNameCache[cacheKey] = postScriptName
                return postScriptName
            }
        }
        return nil
    }
}

extension VectorText {

    func toVectorShape() -> VectorShape {
        let fillStyle = FillStyle(
            color: typography.fillColor,
            opacity: typography.fillOpacity
        )
        let strokeStyle = typography.hasStroke ? StrokeStyle(
            color: typography.strokeColor,
            width: typography.strokeWidth,
            opacity: typography.strokeOpacity
        ) : nil
        let positionTranslation = CGAffineTransform(translationX: position.x, y: position.y)
        let finalTransform = positionTranslation.concatenating(transform)

        var shape = VectorShape(
            name: "Text: \(content.prefix(20))",
            path: VectorPath(elements: []),
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            transform: finalTransform
        )
        shape.id = self.id
        shape.textContent = content
        shape.typography = typography
        shape.textPosition = position
        shape.areaSize = areaSize
        shape.bounds = bounds
        shape.cursorPosition = 0
        shape.metadata["fontFamily"] = typography.fontFamily
        shape.metadata["fontSize"] = "\(typography.fontSize)"
        shape.metadata["letterSpacing"] = "\(typography.letterSpacing)"
        shape.metadata["lineSpacing"] = "\(typography.lineSpacing)"
        return shape
    }
}
