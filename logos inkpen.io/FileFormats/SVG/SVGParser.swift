import SwiftUI

class SVGParser: NSObject, XMLParserDelegate {
    var shapes: [VectorShape] = []

    internal var textObjects: [VectorText] = []
    internal var currentTransform = CGAffineTransform.identity

    private var transformStack: [CGAffineTransform] = []
    private var documentSize = CGSize(width: 100, height: 100)

    internal var viewBoxWidth: Double = 100.0
    internal var viewBoxHeight: Double = 100.0

    private var viewBoxX: Double = 0.0
    private var viewBoxY: Double = 0.0
    private var hasViewBox: Bool = false
    private var creator: String?
    private var version: String?
    private var currentElementName = ""
    private var cssStyles: [String: [String: String]] = [:]
    private var currentStyleContent = ""

    internal var currentTextContent = ""
    internal var currentTextAttributes: [String: String] = [:]

    internal lazy var sharedTextStorage = NSTextStorage()
    internal lazy var sharedLayoutManager = NSLayoutManager()
    internal lazy var sharedTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))

    internal var fontCache: [String: PlatformFont] = [:]
    internal var currentTextSpans: [(content: String, attributes: [String: String], x: Double, y: Double)] = []
    internal var isInMultiLineText: Bool = false
    internal var maxTextWidth: CGFloat = 0
    internal var currentGroupId: String? = nil
    internal var textBoxBounds: [String: CGRect] = [:]
    internal var pendingTextBoxRect: CGRect? = nil
    internal var groupElementStack: [(startIndex: Int, attrs: [String: String])] = []
    internal var currentPatternId: String? = nil
    internal var currentPatternWidth: CGFloat = 0
    internal var currentPatternHeight: CGFloat = 0
    internal var patternDefinitions: [String: [VectorShape]] = [:]
    internal var statGroupsOpened: Int = 0
    internal var statGroupsWrapped: Int = 0
    internal var statGroupsEmpty: Int = 0
    internal var statGroupsAllClip: Int = 0
    internal var statPaths: Int = 0
    internal var statCompoundPaths: Int = 0
    internal var statImagesTotal: Int = 0
    internal var statImagesDropped: Int = 0
    internal var statImageHrefSamples: [String] = []

    static func looksLikeXML(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        var i = 0
        if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF { i = 3 }
        while i < data.count && (data[i] == 0x20 || data[i] == 0x09 || data[i] == 0x0A || data[i] == 0x0D) { i += 1 }
        guard i + 1 < data.count else { return false }
        if data[i] == 0x3C {
            let n = data[i+1]
            return n == 0x3F || n == 0x73 || n == 0x53 || n == 0x21
        }
        return false
    }

    static func isSyntheticGroupId(_ id: String) -> Bool {
        guard id.hasPrefix("Group") else { return false }
        let suffix = id.dropFirst(5)
        return !suffix.isEmpty && suffix.allSatisfy { $0.isASCII && $0.isNumber }
    }
    internal var gradientDefinitions: [String: VectorGradient] = [:]
    internal var currentGradientId: String?
    internal var currentGradientType: String?
    internal var currentGradientStops: [GradientStop] = []
    internal var currentGradientAttributes: [String: String] = [:]
    internal var isParsingGradient = false
    internal var useExtremeValueHandling = false
    internal var detectedExtremeValues = false
    internal var clipPathDefinitions: [String: VectorPath] = [:]
    internal var currentClipPathId: String?
    internal var currentClipPath: VectorPath?
    internal var isParsingClipPath = false
    internal var pendingClipPathId: String?
    internal var clipPathStack: [String?] = []
    internal var elementDefinitions: [String: (elementName: String, attributes: [String: String])] = [:]
    internal var symbolDefinitions: [String: [VectorShape]] = [:]
    internal var symbolStack: [(id: String?, startIndex: Int)] = []
    internal var markerDefinitions: [String: MarkerDefinition] = [:]
    internal var markerStack: [(id: String?, startIndex: Int, attrs: [String: String])] = []
    internal var defsDepth: Int = 0
    internal var hiddenDepth: Int = 0
    internal var elementHiddenStack: [Bool] = []

    private var useRecursionDepth = 0

    private let maxUseRecursionDepth = 10

    struct MarkerDefinition {
        let shapes: [VectorShape]
        let refX: Double
        let refY: Double
        let markerWidth: Double
        let markerHeight: Double
        let orient: String
        let unitsStrokeWidth: Bool
    }

    private func isElementHidden(_ attributes: [String: String]) -> Bool {
        if attributes["display"] == "none" { return true }
        if attributes["visibility"] == "hidden" { return true }
        if let style = attributes["style"] {
            let dict = parseStyleAttribute(style)
            if dict["display"] == "none" { return true }
            if dict["visibility"] == "hidden" { return true }
        }
        return false
    }
    var inkpenMetadata: String? = nil

    private var isInMetadata = false
    private var isInInkpenDocument = false
    private var currentMetadataContent = ""

    private var viewBoxScale: (x: Double, y: Double) {
        return (documentSize.width / viewBoxWidth, documentSize.height / viewBoxHeight)
    }

    struct ParseResult {
        let shapes: [VectorShape]
        let textObjects: [VectorText]
        let documentSize: CGSize
        let viewBoxSize: CGSize?
        let creator: String?
        let version: String?
    }

    func parse(_ xmlString: String) throws -> ParseResult {
        guard let data = xmlString.data(using: .utf8) else {
            throw VectorImportError.parsingError("Invalid SVG string", line: nil)
        }
        sharedTextStorage = NSTextStorage()
        sharedLayoutManager = NSLayoutManager()
        sharedTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        sharedTextContainer.lineFragmentPadding = 0
        sharedTextContainer.lineBreakMode = .byWordWrapping
        sharedTextStorage.addLayoutManager(sharedLayoutManager)
        sharedLayoutManager.addTextContainer(sharedTextContainer)
        fontCache.removeAll()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        if !xmlParser.parse() {
            if let error = xmlParser.parserError {
                throw VectorImportError.parsingError("XML parsing failed: \(error.localizedDescription)", line: xmlParser.lineNumber)
            } else {
                throw VectorImportError.parsingError("Unknown XML parsing error", line: nil)
            }
        }
        var finalShapes = shapes
        if !clipPathDefinitions.isEmpty {
            let unclippedImages = finalShapes.filter { shape in
                shape.name == "Image" && shape.clippedByShapeID == nil && shape.embeddedImageData != nil
            }
            if !unclippedImages.isEmpty, let firstClipPathEntry = clipPathDefinitions.first {
                let clipPath = firstClipPathEntry.value

                var updatedShapes: [VectorShape] = []
                for shape in finalShapes {
                    if shape.id == unclippedImages[0].id {
                        var maskedImage = shape

                        let clipShapeId = UUID()
                        maskedImage.clippedByShapeID = clipShapeId
                        maskedImage.name = "Masked Image"
                        updatedShapes.append(maskedImage)
                        var clipShape = VectorShape(
                            name: "Clip Path",
                            path: clipPath,
                            strokeStyle: nil,
                            fillStyle: FillStyle(color: .clear, opacity: 0),
                            transform: .identity
                        )
                        clipShape.id = clipShapeId
                        clipShape.isClippingPath = true
                        clipShape.isCompoundPath = true
                        updatedShapes.append(clipShape)
                    } else if !unclippedImages.contains(where: { $0.id == shape.id }) {
                        updatedShapes.append(shape)
                    }
                }
                finalShapes = updatedShapes
            }
        }
        let consolidatedShapes = SVGConsolidationHelpers.consolidateSharedGradientsFixed(in: finalShapes)

        var topLevelGroups = 0
        var topLevelCompound = 0
        var topLevelImages = 0
        var topLevelPaths = 0
        for s in consolidatedShapes {
            if s.isGroup && (!s.memberIDs.isEmpty || !s.groupedShapes.isEmpty) { topLevelGroups += 1 }
            else if s.isCompoundPath { topLevelCompound += 1 }
            else if s.embeddedImageData != nil || s.linkedImagePath != nil { topLevelImages += 1 }
            else { topLevelPaths += 1 }
        }
        return ParseResult(
            shapes: consolidatedShapes,
            textObjects: textObjects,
            documentSize: documentSize,
            viewBoxSize: hasViewBox ? CGSize(width: viewBoxWidth, height: viewBoxHeight) : nil,
            creator: creator,
            version: version
        )
    }

    func enableExtremeValueHandling() {
        useExtremeValueHandling = true
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementName = elementName
        let elementIsHidden = isElementHidden(attributeDict)
        elementHiddenStack.append(elementIsHidden)
        if elementIsHidden {
            hiddenDepth += 1
        }
        if hiddenDepth > 0 {
            return
        }
        if let id = attributeDict["id"] {
            switch elementName {
            case "path", "rect", "circle", "ellipse", "line", "polyline", "polygon":
                elementDefinitions[id] = (elementName: elementName, attributes: attributeDict)
            default:
                break
            }
        }
        if isParsingClipPath {
            switch elementName {
            case "path", "rect", "circle", "ellipse", "polygon":
                parseShapeForClipPath(elementName: elementName, attributes: attributeDict)
                return
            default:
                break
            }
        }
        switch elementName {
        case "svg":
            parseSVGRoot(attributes: attributeDict)
        case "defs":
            defsDepth += 1
        case "pattern":
            if let id = attributeDict["id"] {
                currentPatternId = id
                currentPatternWidth = CGFloat(parseLength(attributeDict["width"]) ?? 0)
                currentPatternHeight = CGFloat(parseLength(attributeDict["height"]) ?? 0)
            }
        case "symbol":
            symbolStack.append((id: attributeDict["id"], startIndex: shapes.count))
        case "marker":
            markerStack.append((id: attributeDict["id"], startIndex: shapes.count, attrs: attributeDict))
        case "style":
            currentStyleContent = ""
        case "metadata":
            isInMetadata = true
            currentMetadataContent = ""
        case "inkpen:document":
            if isInMetadata {
                isInInkpenDocument = true
                currentMetadataContent = ""
            }
        case "g":
            parseGroup(attributes: attributeDict)
        case "path":
            parsePath(attributes: attributeDict)
        case "rect":
            parseRectangle(attributes: attributeDict)
        case "circle":
            parseCircle(attributes: attributeDict)
        case "ellipse":
            parseEllipse(attributes: attributeDict)
        case "line":
            parseLine(attributes: attributeDict)
        case "polyline", "polygon":
            parsePolyline(attributes: attributeDict, closed: elementName == "polygon")
        case "text":
            parseText(attributes: attributeDict)
        case "tspan":
            isInMultiLineText = true
            var overlay = attributeDict
            if let classAttr = attributeDict["class"], !classAttr.isEmpty {
                applyCSSClasses(classAttr, into: &overlay)
            }
            if let style = attributeDict["style"], !style.isEmpty {
                let styleDict = parseStyleAttribute(style)
                for (k, v) in styleDict { overlay[k] = v }
            }
            let tspanX = parseLength(overlay["x"]) ?? 0
            let tspanY = parseLength(overlay["y"]) ?? 0

            var tspanAttributes = currentTextAttributes
            if let fam = overlay["font-family"], !fam.isEmpty { tspanAttributes["font-family"] = fam }
            if let size = overlay["font-size"], !size.isEmpty { tspanAttributes["font-size"] = size }
            if let fill = overlay["fill"], !fill.isEmpty { tspanAttributes["fill"] = fill }
            currentTextSpans.append((content: "", attributes: tspanAttributes, x: tspanX, y: tspanY))
            break
        case "linearGradient":
            parseLinearGradient(attributes: attributeDict)
        case "radialGradient":
            parseRadialGradient(attributes: attributeDict)
        case "stop":
            parseGradientStop(attributes: attributeDict)
        case "clipPath":
            parseClipPath(attributes: attributeDict)
        case "mask":
            isParsingClipPath = true
            currentClipPathId = attributeDict["id"]
            currentClipPath = nil
        case "image":
            if currentPatternId != nil {
                resolvePatternImage(attributes: attributeDict)
            } else {
                parseImage(attributes: attributeDict)
            }
        case "use":
            parseUseElement(attributes: attributeDict)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let wasHidden = elementHiddenStack.popLast(), wasHidden {
            hiddenDepth = max(0, hiddenDepth - 1)
        }
        if hiddenDepth > 0 {
            return
        }
        switch elementName {
        case "metadata":
            isInMetadata = false
        case "inkpen:document":
            if isInInkpenDocument {
                inkpenMetadata = currentMetadataContent.trimmingCharacters(in: .whitespacesAndNewlines)
                isInInkpenDocument = false
                currentMetadataContent = ""
            }
        case "svg":
            if hasViewBox {
                currentTransform = CGAffineTransform.identity
                    .translatedBy(x: -viewBoxX, y: -viewBoxY)
                    .scaledBy(x: viewBoxScale.x, y: viewBoxScale.y)
                } else {
                currentTransform = .identity
            }
        case "g":
            if !transformStack.isEmpty {
                transformStack.removeLast()
                currentTransform = transformStack.last ?? (hasViewBox ?
                    CGAffineTransform.identity
                        .translatedBy(x: -viewBoxX, y: -viewBoxY)
                        .scaledBy(x: viewBoxScale.x, y: viewBoxScale.y) :
                    .identity)
            }
            if !clipPathStack.isEmpty {
                let previousClipPath = clipPathStack.removeLast()
                pendingClipPathId = previousClipPath
            } else if pendingClipPathId != nil {
                pendingClipPathId = nil
            }
            if let entry = groupElementStack.popLast() {
                let endIndex = shapes.count
                guard entry.startIndex <= endIndex else { break }
                let childRange = entry.startIndex..<endIndex
                if childRange.isEmpty {
                    statGroupsEmpty += 1
                    break
                }
                let children = Array(shapes[childRange])

                let allClippingRelated = children.allSatisfy {
                    $0.isClippingPath || $0.clippedByShapeID != nil || $0.isClippingGroup
                }
                if allClippingRelated {
                    let maskShape = children.first { $0.isClippingPath }
                    let contentShapes = children.filter { !$0.isClippingPath }
                        .map { shape -> VectorShape in
                            var cleaned = shape
                            cleaned.clippedByShapeID = nil
                            return cleaned
                        }
                    if let mask = maskShape, !contentShapes.isEmpty {
                        var cleanedMask = mask
                        cleanedMask.isClippingPath = false
                        let members = [cleanedMask] + contentShapes

                        var clipGroup = VectorShape.group(
                            from: members,
                            name: "Clipping Group",
                            isClippingGroup: true
                        )
                        clipGroup.memberIDs = []
                        clipGroup.groupedShapes = members
                        shapes.removeSubrange(childRange)
                        shapes.append(clipGroup)
                        statGroupsWrapped += 1
                    } else {
                        statGroupsAllClip += 1
                    }
                    break
                }
                if children.count <= 1 {
                    break
                }
                shapes.removeSubrange(childRange)
                var mergedAttrs = entry.attrs
                if let style = entry.attrs["style"], !style.isEmpty {
                    for (k, v) in parseStyleAttribute(style) {
                        if mergedAttrs[k] == nil { mergedAttrs[k] = v }
                    }
                }
                let groupOpacity = parseLength(mergedAttrs["opacity"]) ?? 1.0

                var groupShape = VectorShape.group(from: children, name: "Group")
                groupShape.memberIDs = []
                groupShape.groupedShapes = children
                groupShape.opacity = groupOpacity
                if let id = entry.attrs["id"], !id.isEmpty, !Self.isSyntheticGroupId(id) {
                    groupShape.name = id
                }
                shapes.append(groupShape)
                statGroupsWrapped += 1
            }
        case "style":
            parseCSSStyles(currentStyleContent)
            currentStyleContent = ""
        case "text":
            finishTextElement()
        case "linearGradient", "radialGradient":
            finishGradientElement()
        case "clipPath", "mask":
            isParsingClipPath = false
            if let clipId = currentClipPathId, let clipPath = currentClipPath {
                clipPathDefinitions[clipId] = clipPath
            }
            currentClipPathId = nil
            currentClipPath = nil
        case "defs":
            defsDepth = max(0, defsDepth - 1)
        case "pattern":
            currentPatternId = nil
            currentPatternWidth = 0
            currentPatternHeight = 0
        case "symbol":
            if !symbolStack.isEmpty {
                let entry = symbolStack.removeLast()
                if entry.startIndex <= shapes.count {
                    let symbolShapes = Array(shapes[entry.startIndex..<shapes.count])
                    if let id = entry.id {
                        symbolDefinitions[id] = symbolShapes
                    }
                    shapes.removeSubrange(entry.startIndex..<shapes.count)
                }
            }
        case "marker":
            if !markerStack.isEmpty {
                let entry = markerStack.removeLast()
                if entry.startIndex <= shapes.count {
                    let markerShapes = Array(shapes[entry.startIndex..<shapes.count])
                    if let id = entry.id {
                        markerDefinitions[id] = MarkerDefinition(
                            shapes: markerShapes,
                            refX: parseLength(entry.attrs["refX"]) ?? 0,
                            refY: parseLength(entry.attrs["refY"]) ?? 0,
                            markerWidth: parseLength(entry.attrs["markerWidth"]) ?? 3,
                            markerHeight: parseLength(entry.attrs["markerHeight"]) ?? 3,
                            orient: entry.attrs["orient"] ?? "0",
                            unitsStrokeWidth: (entry.attrs["markerUnits"] ?? "strokeWidth") == "strokeWidth"
                        )
                    }
                    shapes.removeSubrange(entry.startIndex..<shapes.count)
                }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElementName == "style" {
            currentStyleContent += string
        } else if isInInkpenDocument {
            currentMetadataContent += string
        } else if currentElementName == "text" {
            currentTextContent += string
        } else if currentElementName == "tspan" {
            if !currentTextSpans.isEmpty {
                let lastIndex = currentTextSpans.count - 1
                currentTextSpans[lastIndex].content += string
            } else {
                currentTextContent += string
            }
        }
    }

    private func parseCSSStyles(_ cssContent: String) {
        let rules = cssContent.components(separatedBy: "}")
        for rule in rules {
            let parts = rule.components(separatedBy: "{")
            if parts.count == 2 {
                let selector = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let declarations = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

                var styles: [String: String] = [:]

                let declParts = declarations.components(separatedBy: ";")
                for decl in declParts {
                    let keyValue = decl.components(separatedBy: ":")
                    if keyValue.count >= 2 {
                        let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                        styles[key] = value
                    }
                }
                cssStyles[selector] = styles
            }
        }
    }

    internal func applyCSSClasses(_ classAttr: String, into attributes: inout [String: String]) {
        let classNames = classAttr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for cls in classNames {
            let selector = "." + cls
            if let classStyles = cssStyles[selector] {
                for (key, value) in classStyles {
                    if attributes[key] == nil { attributes[key] = value }
                }
            }
        }
        for (selector, styles) in cssStyles where selector.contains(",") {
            let selectors = selector.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for cls in classNames {
                if selectors.contains("." + cls) {
                    for (key, value) in styles {
                        if attributes[key] == nil { attributes[key] = value }
                    }
                }
            }
        }
    }

    private func parseSVGRoot(attributes: [String: String]) {
        if let width = attributes["width"], let height = attributes["height"] {
            let w = parseLength(width) ?? 100
            let h = parseLength(height) ?? 100
            documentSize = CGSize(width: w, height: h)
        }
        if let viewBox = attributes["viewBox"] {
            let parts = viewBox.split(separator: " ").compactMap { Double($0) }
            if parts.count >= 4 {
                viewBoxX = parts[0]
                viewBoxY = parts[1]
                viewBoxWidth = parts[2]
                viewBoxHeight = parts[3]
                hasViewBox = true
                if attributes["width"] == nil && attributes["height"] == nil {
                    documentSize = CGSize(width: viewBoxWidth, height: viewBoxHeight)
                }
                let scaleX = viewBoxScale.x
                let scaleY = viewBoxScale.y
                let par = attributes["preserveAspectRatio"] ?? "xMidYMid meet"
                let parParts = par.split(separator: " ").map { String($0) }
                let alignment = parParts.first ?? "xMidYMid"
                let meetOrSlice = parParts.count > 1 ? parParts[1] : "meet"
                if alignment == "none" {
                    currentTransform = CGAffineTransform.identity
                        .translatedBy(x: -viewBoxX, y: -viewBoxY)
                        .scaledBy(x: scaleX, y: scaleY)
                } else {
                    let uniformScale = meetOrSlice == "slice" ? max(scaleX, scaleY) : min(scaleX, scaleY)
                    let scaledWidth = viewBoxWidth * uniformScale
                    let scaledHeight = viewBoxHeight * uniformScale
                    let translateX: Double
                    if alignment.hasPrefix("xMin") {
                        translateX = 0
                    } else if alignment.hasPrefix("xMax") {
                        translateX = documentSize.width - scaledWidth
                    } else {
                        translateX = (documentSize.width - scaledWidth) / 2.0
                    }
                    let translateY: Double
                    if alignment.contains("YMin") {
                        translateY = 0
                    } else if alignment.contains("YMax") {
                        translateY = documentSize.height - scaledHeight
                    } else {
                        translateY = (documentSize.height - scaledHeight) / 2.0
                    }
                    currentTransform = CGAffineTransform.identity
                        .translatedBy(x: translateX - viewBoxX * uniformScale, y: translateY - viewBoxY * uniformScale)
                        .scaledBy(x: uniformScale, y: uniformScale)
                }
            }
        } else {
            viewBoxWidth = documentSize.width
            viewBoxHeight = documentSize.height
        }
        creator = attributes["data-name"] ?? attributes["generator"]
        version = attributes["version"]
    }

    private func parseGroup(attributes: [String: String]) {
        transformStack.append(currentTransform)
        currentGroupId = attributes["id"]
        groupElementStack.append((startIndex: shapes.count, attrs: attributes))
        statGroupsOpened += 1
        clipPathStack.append(pendingClipPathId)
        if let transform = attributes["transform"] {
            let groupTransform = parseTransform(transform)
            currentTransform = currentTransform.concatenating(groupTransform)
        }
        var mergedAttributes = attributes
        if let className = attributes["class"] {
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                }
            }
        }
        if let clipPathAttr = mergedAttributes["clip-path"] {
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let clipId = String(idPart[..<endRange.lowerBound])
                    if clipPathDefinitions[clipId] != nil {
                        pendingClipPathId = clipId
                    } else {
                        pendingClipPathId = clipId
                        Log.warning("⚠️ Group references clip path '\(clipId)' which is not yet defined. Will attempt to resolve later.", category: .fileOperations)
                    }
                }
            }
        }
    }

    private func parseUseElement(attributes: [String: String]) {
        guard useRecursionDepth < maxUseRecursionDepth else { return }
        let href = attributes["xlink:href"] ?? attributes["href"] ?? ""
        let refId = href.hasPrefix("#") ? String(href.dropFirst()) : href
        guard !refId.isEmpty else { return }
        let useX = parseLength(attributes["x"]) ?? 0
        let useY = parseLength(attributes["y"]) ?? 0
        let savedTransform = currentTransform
        if useX != 0 || useY != 0 {
            currentTransform = currentTransform.translatedBy(x: useX, y: useY)
        }
        if let useTransform = attributes["transform"] {
            currentTransform = currentTransform.concatenating(parseTransform(useTransform))
        }
        useRecursionDepth += 1
        if let symbolShapes = symbolDefinitions[refId] {
            for shape in symbolShapes {
                var instance = shape
                instance.id = UUID()
                if !currentTransform.isIdentity {
                    let useTransform = CGAffineTransform(translationX: useX, y: useY)

                    var combined = useTransform
                    if let userTransform = attributes["transform"].map(parseTransform) {
                        combined = combined.concatenating(userTransform)
                    }
                    let transformedElements = instance.path.elements.map { el -> PathElement in
                        switch el {
                        case .move(let to): return .move(to: VectorPoint(to.cgPoint.applying(combined)))
                        case .line(let to): return .line(to: VectorPoint(to.cgPoint.applying(combined)))
                        case .curve(let to, let c1, let c2):
                            return .curve(to: VectorPoint(to.cgPoint.applying(combined)),
                                         control1: VectorPoint(c1.cgPoint.applying(combined)),
                                         control2: VectorPoint(c2.cgPoint.applying(combined)))
                        case .quadCurve(let to, let c):
                            return .quadCurve(to: VectorPoint(to.cgPoint.applying(combined)),
                                             control: VectorPoint(c.cgPoint.applying(combined)))
                        case .close: return .close
                        }
                    }
                    instance.path = VectorPath(elements: transformedElements, isClosed: instance.path.isClosed, fillRule: instance.path.fillRule.cgPathFillRule)
                }
                shapes.append(instance)
            }
        } else if let def = elementDefinitions[refId] {
            var mergedAttributes = def.attributes
            for (key, value) in attributes where key != "xlink:href" && key != "href" && key != "id" && key != "x" && key != "y" {
                mergedAttributes[key] = value
            }
            switch def.elementName {
            case "path":       parsePath(attributes: mergedAttributes)
            case "rect":       parseRectangle(attributes: mergedAttributes)
            case "circle":     parseCircle(attributes: mergedAttributes)
            case "ellipse":    parseEllipse(attributes: mergedAttributes)
            case "line":       parseLine(attributes: mergedAttributes)
            case "polyline":   parsePolyline(attributes: mergedAttributes, closed: false)
            case "polygon":    parsePolyline(attributes: mergedAttributes, closed: true)
            default: break
            }
        }
        useRecursionDepth -= 1
        currentTransform = savedTransform
    }

    private func parsePath(attributes: [String: String]) {
        guard let d = attributes["d"] else { return }
        let pathData = parsePathData(d)
        let hasCloseElement = pathData.contains { if case .close = $0 { return true }; return false }
        let vectorPath = VectorPath(elements: pathData, isClosed: hasCloseElement)
        let (shouldClip, clipPathId) = checkForClipPath(attributes)
        if let patternId = Self.patternIdInFill(attributes: attributes),

           let patternShapes = patternDefinitions[patternId] {
            expandPatternInPlace(patternShapes: patternShapes, pathElements: pathData, originalAttributes: attributes)
            return
        }
        let detected = PathShapeDetector.detect(elements: pathData)
        let shape = createShape(
            name: detected?.name ?? "Path",
            path: vectorPath,
            attributes: attributes,
            geometricType: detected?.type
        )
        if shouldClip, let clipId = clipPathId {
            applyClipPathToShape(shape, clipPathId: clipId)
        } else {
            shapes.append(shape)
        }
    }

    static func patternIdInFill(attributes: [String: String]) -> String? {

        func extract(_ s: String) -> String? {
            guard let urlStart = s.range(of: "url(#") else { return nil }
            let after = s[urlStart.upperBound...]
            guard let endParen = after.range(of: ")") else { return nil }
            return String(after[..<endParen.lowerBound])
        }
        if let fill = attributes["fill"], let id = extract(fill) { return id }
        if let style = attributes["style"] {
            for pair in style.split(separator: ";") {
                let kv = pair.split(separator: ":", maxSplits: 1)
                if kv.count == 2, kv[0].trimmingCharacters(in: .whitespaces) == "fill" {
                    if let id = extract(String(kv[1])) { return id }
                }
            }
        }
        return nil
    }

    private func expandPatternInPlace(patternShapes: [VectorShape], pathElements: [PathElement], originalAttributes: [String: String]) {
        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var maxY: CGFloat = -.infinity
        for el in pathElements {
            let p: VectorPoint
            switch el {
            case .move(let to): p = to
            case .line(let to): p = to
            case .curve(let to, _, _): p = to
            case .quadCurve(let to, _): p = to
            case .close: continue
            }
            minX = min(minX, p.cgPoint.x); minY = min(minY, p.cgPoint.y)
            maxX = max(maxX, p.cgPoint.x); maxY = max(maxY, p.cgPoint.y)
        }
        guard minX.isFinite, minY.isFinite else { return }
        let translate = CGAffineTransform(translationX: minX, y: minY)
        for src in patternShapes {
            var copy = src
            copy.id = UUID()
            copy.transform = copy.transform.concatenating(translate)
            shapes.append(copy)
        }
    }

    private func resolvePatternImage(attributes: [String: String]) {
        guard let patternId = currentPatternId else { return }
        let href = attributes["href"] ?? attributes["xlink:href"] ?? ""
        guard href.hasPrefix("data:") else { return }
        guard let commaIdx = href.range(of: ",") else { return }
        let payload = String(href[commaIdx.upperBound...])
        let isBase64 = href[..<commaIdx.lowerBound].contains("base64")
        guard isBase64, let decoded = Data(base64Encoded: payload) else { return }
        guard let innerSVG = String(data: decoded, encoding: .utf8) else { return }
        let inner = SVGParser()
        guard let result = try? inner.parse(innerSVG) else { return }
        patternDefinitions[patternId] = result.shapes
    }

    private func parseImage(attributes: [String: String]) {
        var mergedAttributes = attributes
        if let className = attributes["class"] {
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                }
            }
        }
        let x = parseLength(mergedAttributes["x"]) ?? 0
        let y = parseLength(mergedAttributes["y"]) ?? 0
        let width = parseLength(mergedAttributes["width"]) ?? 100
        let height = parseLength(mergedAttributes["height"]) ?? 100
        let imageHref = mergedAttributes["href"] ?? mergedAttributes["xlink:href"] ?? ""
        statImagesTotal += 1
        let hrefPrefix = String(imageHref.prefix(80))
        if statImageHrefSamples.count < 5 {
            statImageHrefSamples.append(hrefPrefix)
        }
        let lowerHref = imageHref.lowercased()
        if lowerHref.hasPrefix("data:image/svg+xml") ||
           lowerHref.hasPrefix("data:application/xml") ||
           lowerHref.hasPrefix("data:text/xml") ||
           lowerHref.hasPrefix("data:application/octet-stream") {
            statImagesDropped += 1
            return
        }
        if imageHref.isEmpty {
            statImagesDropped += 1
            return
        }
        if imageHref.hasPrefix("data:"), let commaIdx = imageHref.range(of: ",") {
            let payload = String(imageHref[commaIdx.upperBound...])
            let isBase64 = imageHref[..<commaIdx.lowerBound].contains("base64")
            if isBase64 {
                if let decoded = Data(base64Encoded: payload), decoded.count < 16 || Self.looksLikeXML(decoded) {
                    statImagesDropped += 1
                    return
                }
            } else if payload.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                statImagesDropped += 1
                return
            }
        }
        var clipPathId: String? = nil
        if let clipPathAttr = mergedAttributes["clip-path"], !clipPathAttr.isEmpty {
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let extractedId = String(idPart[..<endRange.lowerBound])
                    if !extractedId.isEmpty {
                        clipPathId = extractedId
                    }
                }
            }
        }
        if clipPathId == nil, let pendingId = pendingClipPathId {
            clipPathId = pendingId
        }
        let imageRect = CGRect(x: x, y: y, width: width, height: height)
        let imagePath = VectorPath(elements: [
            .move(to: VectorPoint(imageRect.minX, imageRect.minY)),
            .line(to: VectorPoint(imageRect.maxX, imageRect.minY)),
            .line(to: VectorPoint(imageRect.maxX, imageRect.maxY)),
            .line(to: VectorPoint(imageRect.minX, imageRect.maxY)),
            .close
        ], isClosed: true)
        var imageAttributes = mergedAttributes
        imageAttributes["fill"] = "none"
        imageAttributes["fill-opacity"] = "0"
        var imageShape = createShape(
            name: "Image",
            path: imagePath,
            attributes: imageAttributes,
            geometricType: .rectangle
        )
        imageShape.fillStyle = nil
        if imageHref.hasPrefix("data:") {
            if let dataRange = imageHref.range(of: "base64,") {
                let base64String = String(imageHref[dataRange.upperBound...])
                imageShape.embeddedImageData = Data(base64Encoded: base64String)
            }
        } else if !imageHref.isEmpty {
            imageShape.linkedImagePath = imageHref
        }
        if let clipId = clipPathId {
            if let clipPath = clipPathDefinitions[clipId] {
                var closedClipPath = clipPath
                if !closedClipPath.isClosed {
                    var elements = closedClipPath.elements
                    if !elements.isEmpty && !elements.contains(where: { if case .close = $0 { return true }; return false }) {
                        elements.append(.close)
                    }
                    closedClipPath = VectorPath(elements: elements, isClosed: true)
                }
                var maskedImageShape = imageShape

                let clipShapeId = UUID()
                maskedImageShape.clippedByShapeID = clipShapeId
                maskedImageShape.name = "Masked Image"
                shapes.append(maskedImageShape)
                var clipShape = VectorShape(
                    name: "Clip Path",
                    path: closedClipPath,
                    strokeStyle: nil,
                    fillStyle: FillStyle(color: .clear, opacity: 0),
                    transform: .identity
                )
                clipShape.id = clipShapeId
                clipShape.isClippingPath = true
                clipShape.isCompoundPath = true
                shapes.append(clipShape)
                return
            } else {
                Log.warning("⚠️ Clip path '\(clipId)' referenced but not found in definitions. Available: \(clipPathDefinitions.keys.joined(separator: ", "))", category: .fileOperations)
                Log.warning("⚠️ Falling back to no clipping for this image", category: .fileOperations)
            }
        }
        shapes.append(imageShape)
    }

    private func parseClipPath(attributes: [String: String]) {
        isParsingClipPath = true
        currentClipPathId = attributes["id"]
        currentClipPath = nil
    }

    private func parseShapeForClipPath(elementName: String, attributes: [String: String]) {
        var clipPath: VectorPath?
        switch elementName {
        case "path":
            if let d = attributes["d"] {
                let pathData = parsePathData(d)
                let fillRuleStr = attributes["clip-rule"] ?? attributes["fill-rule"] ?? "nonzero"
                let fillRule: CGPathFillRule = (fillRuleStr == "evenodd") ? .evenOdd : .winding
                clipPath = VectorPath(elements: pathData, isClosed: true, fillRule: fillRule)
            }
        case "rect":
            let x = parseLength(attributes["x"]) ?? 0
            let y = parseLength(attributes["y"]) ?? 0
            let width = parseLength(attributes["width"]) ?? 0
            let height = parseLength(attributes["height"]) ?? 0
            let rect = CGRect(x: x, y: y, width: width, height: height)
            clipPath = VectorPath(elements: [
                .move(to: VectorPoint(rect.minX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.maxY)),
                .line(to: VectorPoint(rect.minX, rect.maxY)),
                .close
            ], isClosed: true)
        case "circle":
            let cx = parseLength(attributes["cx"]) ?? 0
            let cy = parseLength(attributes["cy"]) ?? 0
            let r = parseLength(attributes["r"]) ?? 0
            let center = CGPoint(x: cx, y: cy)
            clipPath = VectorPath(elements: [
                .move(to: VectorPoint(center.x + r, center.y)),
                .curve(to: VectorPoint(center.x, center.y + r),
                       control1: VectorPoint(center.x + r, center.y + r * 0.552),
                       control2: VectorPoint(center.x + r * 0.552, center.y + r)),
                .curve(to: VectorPoint(center.x - r, center.y),
                       control1: VectorPoint(center.x - r * 0.552, center.y + r),
                       control2: VectorPoint(center.x - r, center.y + r * 0.552)),
                .curve(to: VectorPoint(center.x, center.y - r),
                       control1: VectorPoint(center.x - r, center.y - r * 0.552),
                       control2: VectorPoint(center.x - r * 0.552, center.y - r)),
                .curve(to: VectorPoint(center.x + r, center.y),
                       control1: VectorPoint(center.x + r * 0.552, center.y - r),
                       control2: VectorPoint(center.x + r, center.y - r * 0.552)),
                .close
            ], isClosed: true)
        case "ellipse":
            let cx = parseLength(attributes["cx"]) ?? 0
            let cy = parseLength(attributes["cy"]) ?? 0
            let rx = parseLength(attributes["rx"]) ?? 0
            let ry = parseLength(attributes["ry"]) ?? 0
            let center = CGPoint(x: cx, y: cy)
            clipPath = VectorPath(elements: [
                .move(to: VectorPoint(center.x + rx, center.y)),
                .curve(to: VectorPoint(center.x, center.y + ry),
                       control1: VectorPoint(center.x + rx, center.y + ry * 0.552),
                       control2: VectorPoint(center.x + rx * 0.552, center.y + ry)),
                .curve(to: VectorPoint(center.x - rx, center.y),
                       control1: VectorPoint(center.x - rx * 0.552, center.y + ry),
                       control2: VectorPoint(center.x - rx, center.y + ry * 0.552)),
                .curve(to: VectorPoint(center.x, center.y - ry),
                       control1: VectorPoint(center.x - rx, center.y - ry * 0.552),
                       control2: VectorPoint(center.x - rx * 0.552, center.y - ry)),
                .curve(to: VectorPoint(center.x + rx, center.y),
                       control1: VectorPoint(center.x + rx * 0.552, center.y - ry),
                       control2: VectorPoint(center.x + rx, center.y - ry * 0.552)),
                .close
            ], isClosed: true)
        case "polygon":
            if let points = attributes["points"] {
                let parsedPoints = parsePoints(points)

                var elements: [PathElement] = []
                for (index, point) in parsedPoints.enumerated() {
                    if index == 0 {
                        elements.append(.move(to: VectorPoint(point.x, point.y)))
                    } else {
                        elements.append(.line(to: VectorPoint(point.x, point.y)))
                    }
                }
                elements.append(.close)
                clipPath = VectorPath(elements: elements, isClosed: true)
            }
        default:
            break
        }
        if let path = clipPath {
            if currentClipPath == nil {
                currentClipPath = path
            } else {
                let combined = CGMutablePath()
                combined.addPath(currentClipPath!.cgPath)
                combined.addPath(path.cgPath)
                let rule: CGPathFillRule = (currentClipPath!.fillRule == .evenOdd || path.fillRule == .evenOdd) ? .evenOdd : .winding
                currentClipPath = VectorPath(cgPath: combined, fillRule: rule)
            }
        }
    }

    func createShape(name: String, path: VectorPath, attributes: [String: String], geometricType: GeometricShapeType? = nil) -> VectorShape {
        var mergedAttributes = attributes
        if let style = attributes["style"], !style.isEmpty {
            let styleDict = parseStyleAttribute(style)
            for (k, v) in styleDict { mergedAttributes[k] = v }
        }
        if let className = attributes["class"] {
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                } else {
                    Log.error("❌ No styles found for \(selector)", category: .error)
                }
            }
        }
        for (selector, styles) in cssStyles {
            if selector.contains(",") {
                let selectors = selector.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if let className = attributes["class"] {
                    let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    for cls in classNames {
                        if selectors.contains("." + cls) {
                            for (key, value) in styles {
                                if mergedAttributes[key] == nil {
                                    mergedAttributes[key] = value
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
        let stroke = parseStrokeStyle(mergedAttributes)
        let fill = parseFillStyle(mergedAttributes)
        let transform: CGAffineTransform
        if mergedAttributes["transform"] != nil {
            let shapeTransform = parseTransform(mergedAttributes["transform"] ?? "")
            transform = currentTransform.concatenating(shapeTransform)
        } else {
            transform = currentTransform.isIdentity ? .identity : currentTransform
        }
        var resolvedPath = path

        let fillRuleAttr = mergedAttributes["fill-rule"] ?? "nonzero"
        if fillRuleAttr == "evenodd" {
            resolvedPath.fillRule = .evenOdd
        }
        let moveCount = resolvedPath.elements.reduce(0) { count, el in
            if case .move = el { return count + 1 }
            return count
        }
        let isCompound = moveCount >= 2
        let isLoopingFill = resolvedPath.fillRule.cgPathFillRule != .evenOdd
        if isCompound { statCompoundPaths += 1 } else { statPaths += 1 }
        let shapeName: String
        if isCompound {
            shapeName = isLoopingFill ? "Looping Path" : "Compound Path"
        } else {
            shapeName = name
        }
        if !transform.isIdentity {
            let flattenedElements = resolvedPath.elements.map { element -> PathElement in
                switch element {
                case .move(let to):
                    let p = to.cgPoint.applying(transform)
                    return .move(to: VectorPoint(p))
                case .line(let to):
                    let p = to.cgPoint.applying(transform)
                    return .line(to: VectorPoint(p))
                case .curve(let to, let c1, let c2):
                    let p = to.cgPoint.applying(transform)
                    let cp1 = c1.cgPoint.applying(transform)
                    let cp2 = c2.cgPoint.applying(transform)
                    return .curve(to: VectorPoint(p), control1: VectorPoint(cp1), control2: VectorPoint(cp2))
                case .quadCurve(let to, let c):
                    let p = to.cgPoint.applying(transform)
                    let cp = c.cgPoint.applying(transform)
                    return .quadCurve(to: VectorPoint(p), control: VectorPoint(cp))
                case .close:
                    return .close
                }
            }
            resolvedPath = VectorPath(elements: flattenedElements, isClosed: resolvedPath.isClosed, fillRule: resolvedPath.fillRule.cgPathFillRule)
            var resolvedStroke = stroke
            if var s = resolvedStroke {
                let avgScale = (abs(transform.a) + abs(transform.d)) / 2.0
                s.width *= avgScale
                resolvedStroke = s
            }
            return VectorShape(
                name: shapeName,
                path: resolvedPath,
                geometricType: isCompound ? nil : geometricType,
                strokeStyle: resolvedStroke,
                fillStyle: fill,
                transform: .identity,
                isCompoundPath: isCompound
            )
        }
        return VectorShape(
            name: shapeName,
            path: resolvedPath,
            geometricType: isCompound ? nil : geometricType,
            strokeStyle: stroke,
            fillStyle: fill,
            transform: transform,
            isCompoundPath: isCompound
        )
    }

    internal func checkForClipPath(_ attributes: [String: String]) -> (shouldClip: Bool, clipPathId: String?) {
        var mergedAttributes = attributes
        if let className = attributes["class"] {
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                }
            }
        }
        let clipOrMaskAttr = mergedAttributes["clip-path"] ?? mergedAttributes["mask"]
        if let clipPathAttr = clipOrMaskAttr {
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let clipPathId = String(idPart[..<endRange.lowerBound])
                    return (true, clipPathId)
                }
            }
        }
        if let pending = pendingClipPathId {
            return (true, pending)
        }
        return (false, nil)
    }

    internal func applyClipPathToShape(_ shape: VectorShape, clipPathId: String) {
        guard let clipPath = clipPathDefinitions[clipPathId] else {
            Log.error("❌ Clip path not found: \(clipPathId)", category: .error)
            shapes.append(shape)
            return
        }
        var closedClipPath = clipPath
        if !closedClipPath.isClosed {
            var elements = closedClipPath.elements
            if !elements.isEmpty && !elements.contains(where: { if case .close = $0 { return true }; return false }) {
                elements.append(.close)
            }
            closedClipPath = VectorPath(elements: elements, isClosed: true)
        }
        var maskedShape = shape

        let clipShapeId = UUID()
        maskedShape.clippedByShapeID = clipShapeId
        maskedShape.name = "Masked \(shape.name)"
        shapes.append(maskedShape)
        var clipShape = VectorShape(
            name: "Clip Path",
            path: closedClipPath,
            strokeStyle: nil,
            fillStyle: FillStyle(color: .clear, opacity: 0),
            transform: .identity
        )
        clipShape.id = clipShapeId
        clipShape.isClippingPath = true
        clipShape.isCompoundPath = true
        shapes.append(clipShape)
    }

    internal func parseGradientCoordinate(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, useExtremeValueHandling: Bool = false) -> Double {
        return GradientCoordinateConverter.parseGradientCoordinate(
            value,
            gradientUnits: gradientUnits,
            isXCoordinate: isXCoordinate,
            useExtremeValueHandling: useExtremeValueHandling,
            viewBoxWidth: viewBoxWidth,
            viewBoxHeight: viewBoxHeight
        )
    }

    private func parseRadialGradientCoordinateExtreme(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true) -> Double {
        return GradientCoordinateConverter.parseRadialGradientCoordinateExtreme(
            value,
            gradientUnits: gradientUnits,
            isXCoordinate: isXCoordinate,
            viewBoxWidth: viewBoxWidth,
            viewBoxHeight: viewBoxHeight
        )
    }
}
