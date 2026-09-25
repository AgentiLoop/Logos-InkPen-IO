import Foundation
import CoreGraphics

enum FreeHandEPSParser {

    static func parseToShapes(data: Data) throws -> FreeHandDirectImporter.Result {
        guard let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8),
              text.hasPrefix("%!PS-Adobe") else {
            throw FreeHandImportError.notSupported
        }
        var pageWidth: Double = 612
        var pageHeight: Double = 792
        var bbOriginX: Double = 0
        var bbOriginY: Double = 0
        if let bbRange = text.range(of: "%%BoundingBox:") {
            let bbLine = text[bbRange.upperBound...]
            let nums = bbLine.prefix(100)
                .split { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "%" }
                .prefix(4)
                .compactMap { Double($0) }
            if nums.count >= 4 {
                bbOriginX = nums[0]
                bbOriginY = nums[1]
                pageWidth = nums[2] - nums[0]
                pageHeight = nums[3] - nums[1]
            }
        }
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        guard let defRange = normalized.range(of: "]def") else {
            throw FreeHandImportError.parseFailed(code: 1)
        }
        let afterDef = normalized[defRange.upperBound...]
        guard let vmsRange = afterDef.range(of: "vms") else {
            throw FreeHandImportError.parseFailed(code: 2)
        }
        let drawingText = String(afterDef[vmsRange.upperBound...])
        let rawShapes = parsePostScript(drawingText, pageHeight: pageHeight, originX: bbOriginX, originY: bbOriginY)
        let groupRanges = inferGroupRanges(from: drawingText, totalShapes: rawShapes.count)
        let (preTextShapes, groupIDs): ([VectorShape], [UUID]) = {
            if groupRanges.isEmpty {
                return (mergeFillStrokePairs(rawShapes), [])
            }
            return wrapShapesIntoGroups(rawShapes, ranges: groupRanges)
        }()
        var shapes = preTextShapes
        let textShapes = parseEPSTextRuns(in: drawingText, pageHeight: pageHeight,
                                          originX: bbOriginX, originY: bbOriginY,
                                          fontTable: extractFontTable(from: text))
        shapes.append(contentsOf: textShapes)
        guard !shapes.isEmpty else {
            throw FreeHandImportError.emptyOutput
        }
        let layer = Layer(
            name: "eps-import",
            objectIDs: shapes.map { $0.id },
            isVisible: true,
            isLocked: false,
            opacity: 1.0,
            blendMode: .normal,
            color: .blue
        )
        let stats = FreeHandDirectImporter.Stats(
            paths: rawShapes.count, groups: groupIDs.count, clipGroups: 0,
            compositePaths: 0, newBlends: 0, symbolInstances: 0, contentIdPaths: 0
        )
        return FreeHandDirectImporter.Result(
            shapes: shapes,
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            stats: stats,
            layers: [layer],
            groupShapeIDs: groupIDs
        )
    }

    static func inferGroupRanges(from drawingText: String, totalShapes: Int) -> [Range<Int>] {
        let tokens = tokenize(drawingText)

        struct Frame { let startShapeIdx: Int }
        var stack: [Frame] = []
        var raw: [Range<Int>] = []
        var shapeIdx = 0
        for token in tokens {
            switch token {
            case "gsave":
                stack.append(Frame(startShapeIdx: shapeIdx))
            case "grestore":
                if let frame = stack.popLast() {
                    let count = shapeIdx - frame.startShapeIdx
                    if count >= 2 {
                        raw.append(frame.startShapeIdx..<shapeIdx)
                    }
                }
            case "{fill}", "{ fill }", "{fill }", "{ fill}",
                 "{stroke}", "{ stroke }", "{stroke }", "{ stroke}",
                 "rectfill", "radialfill", "eoradialfill":
                shapeIdx += 1
            default:
                break
            }
        }

        let sortedSmallestFirst = raw.sorted {
            ($0.upperBound - $0.lowerBound) < ($1.upperBound - $1.lowerBound)
        }
        var covered = [Bool](repeating: false, count: totalShapes)
        var kept: [Range<Int>] = []
        for r in sortedSmallestFirst {
            guard r.lowerBound >= 0, r.upperBound <= totalShapes else { continue }
            let hasUncovered = (r.lowerBound..<r.upperBound).contains { !covered[$0] }
            if hasUncovered {
                for i in r.lowerBound..<r.upperBound { covered[i] = true }
                kept.append(r)
            }
        }
        return kept.sorted { $0.lowerBound < $1.lowerBound }
    }

    static func wrapShapesIntoGroups(_ shapes: [VectorShape], ranges: [Range<Int>])
        -> (topLevel: [VectorShape], groupIDs: [UUID])
    {
        guard !ranges.isEmpty else { return (shapes, []) }
        var shapeToRange: [Int: Int] = [:]
        for (rIdx, r) in ranges.enumerated() {
            for i in r where i >= 0 && i < shapes.count { shapeToRange[i] = rIdx }
        }
        var output: [VectorShape] = []
        var groupIDs: [UUID] = []
        var rangeEmitted = Set<Int>()
        for (idx, shape) in shapes.enumerated() {
            if let rIdx = shapeToRange[idx] {
                if !rangeEmitted.contains(rIdx) {
                    rangeEmitted.insert(rIdx)
                    let r = ranges[rIdx]
                    let members = Array(shapes[r])

                    var union = CGRect.null
                    for m in members {
                        let b = m.bounds.applying(m.transform)
                        union = union.union(b)
                    }
                    var group = VectorShape(
                        name: "Group",
                        path: VectorPath(elements: [], isClosed: false),
                        strokeStyle: nil,
                        fillStyle: nil,
                        transform: .identity
                    )
                    group.isGroup = true
                    group.memberIDs = []
                    group.groupedShapes = members
                    group.bounds = union.isNull ? .zero : union
                    output.append(group)
                    groupIDs.append(group.id)
                }
            } else {
                output.append(shape)
            }
        }
        return (output, groupIDs)
    }

    private static func extractFontTable(from text: String) -> [String: String] {
        var table: [String: String] = [:]

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if let fRange = line.range(of: #"/f\d+\s+/"#, options: .regularExpression) {
                let fName = String(line[fRange])
                    .dropFirst()
                    .prefix(while: { !$0.isWhitespace })
                let rest = line[fRange.upperBound...]
                let fontName = String(rest.prefix(while: { $0 != " " && $0 != "\t" }))
                    .replacingOccurrences(of: "|______", with: "")
                if !fontName.isEmpty {
                    table[String(fName)] = fontName
                }
            }
        }
        return table
    }

    private static func parseEPSTextRuns(in drawingText: String,
                                         pageHeight: Double,
                                         originX: Double, originY: Double,
                                         fontTable: [String: String]) -> [VectorShape] {
        var results: [VectorShape] = []

        let ns = drawingText as NSString
        guard let blockRegex = try? NSRegularExpression(
            pattern: #"\{([^{}]*)\}\s*\[([^\]]*)\]\s*sts"#,
            options: [.dotMatchesLineSeparators]
        ) else { return results }
        let tsPattern = #"(-?[\d.]+)\s+(-?[\d.]+)\s+moveto(?:[^()]*)\(([^)]*)\)\s*ts"#
        guard let tsRegex = try? NSRegularExpression(pattern: tsPattern, options: [.dotMatchesLineSeparators]) else {
            return results
        }
        let fontRegex = try? NSRegularExpression(
            pattern: #"(/f\d+)\s+\[(-?[\d.]+)\s+0\s+0\s+(-?[\d.]+)"#,
            options: [.dotMatchesLineSeparators]
        )
        for block in blockRegex.matches(in: drawingText, range: NSRange(location: 0, length: ns.length)) {
            let bodyRange = block.range(at: 1)
            let colorRange = block.range(at: 2)
            guard bodyRange.location != NSNotFound else { continue }
            let body = ns.substring(with: bodyRange)
            let bodyNs = body as NSString

            var psFont = "Helvetica-Bold"
            var fontSize: Double = 12
            if let fr = fontRegex,

               let m = fr.firstMatch(in: body, range: NSRange(location: 0, length: bodyNs.length)) {
                let fKey = bodyNs.substring(with: m.range(at: 1))
                let sizeStr = bodyNs.substring(with: m.range(at: 2))
                if let sz = Double(sizeStr) { fontSize = sz }
                let key = String(fKey.dropFirst())
                if let mapped = fontTable[key] { psFont = mapped }
            }
            var chunks: [(x: Double, y: Double, text: String)] = []
            for tm in tsRegex.matches(in: body, range: NSRange(location: 0, length: bodyNs.length)) {
                let xs = bodyNs.substring(with: tm.range(at: 1))
                let ys = bodyNs.substring(with: tm.range(at: 2))
                let txt = bodyNs.substring(with: tm.range(at: 3))
                guard let x = Double(xs), let y = Double(ys), !txt.isEmpty else { continue }
                chunks.append((x, y, txt))
            }
            guard let first = chunks.first else { continue }
            let sameLine = chunks.filter { abs($0.y - first.y) < 0.01 }
            let literal = sameLine.map { $0.text }.joined()
            guard !literal.isEmpty else { continue }
            let (family, bold, italic) = splitPSFontName(psFont)
            var fill: VectorColor = .black
            if colorRange.location != NSNotFound {
                let args = ns.substring(with: colorRange)
                    .split(whereSeparator: { $0.isWhitespace })
                    .compactMap { Double($0) }
                if args.count == 4 {
                    let c = args[0], m = args[1], y = args[2], k = args[3]
                    let r = (1 - c) * (1 - k)
                    let g = (1 - m) * (1 - k)
                    let b = (1 - y) * (1 - k)
                    fill = .rgb(RGBColor(red: r, green: g, blue: b))
                }
            }
            let ascender = fontSize * 0.8
            let baselineY = pageHeight - (first.y - originY)
            let textOrigin = CGPoint(x: first.x - originX, y: baselineY - ascender)

            var shape = VectorShape(
                name: literal,
                path: VectorPath(elements: [], isClosed: false),
                strokeStyle: StrokeStyle(color: .clear, width: 0, placement: .center),
                fillStyle: FillStyle(color: fill),
                transform: .identity
            )
            shape.textContent = literal
            shape.textPosition = textOrigin

            let variant: String? = {
                switch (bold, italic) {
                case (true, true):   return "BoldItalic"
                case (true, false):  return "Bold"
                case (false, true):  return "Italic"
                case (false, false): return nil
                }
            }()
            shape.typography = TypographyProperties(
                fontFamily: family,
                fontVariant: variant,
                fontSize: fontSize,
                lineHeight: fontSize,
                alignment: .left,
                strokeColor: .clear,
                fillColor: fill
            )
            let estWidth = Double(literal.count) * fontSize * 0.65 * 2.0
            let estHeight = fontSize * 1.25
            shape.areaSize = CGSize(width: estWidth, height: estHeight)
            shape.transform = CGAffineTransform(translationX: textOrigin.x, y: textOrigin.y)
            shape.bounds = CGRect(x: 0, y: 0, width: estWidth, height: estHeight)
            results.append(shape)
        }
        return results
    }

    private static func splitPSFontName(_ psName: String) -> (family: String, bold: Bool, italic: Bool) {
        let parts = psName.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard let family = parts.first.map(String.init) else {
            return (psName, false, false)
        }
        if parts.count < 2 { return (family, false, false) }
        let variant = String(parts[1]).lowercased()
        let bold = variant.contains("bold")
        let italic = variant.contains("italic") || variant.contains("oblique")
        return (family, bold, italic)
    }

    private struct Transform {
        var a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1, tx: Double = 0, ty: Double = 0

        func apply(_ x: Double, _ y: Double) -> (Double, Double) {
            (a * x + c * y + tx, b * x + d * y + ty)
        }

        func concat(_ other: Transform) -> Transform {
            Transform(
                a: a * other.a + c * other.b,
                b: b * other.a + d * other.b,
                c: a * other.c + c * other.d,
                d: b * other.c + d * other.d,
                tx: a * other.tx + c * other.ty + tx,
                ty: b * other.tx + d * other.ty + ty
            )
        }
    }

    private struct GraphicsState {
        var fillColor: VectorColor = .black
        var strokeColor: VectorColor = .black
        var lineWidth: Double = 1.0
        var transform: Transform = Transform()
    }

    private static func parsePostScript(_ text: String, pageHeight: Double, originX: Double = 0, originY: Double = 0) -> [VectorShape] {
        var shapes: [VectorShape] = []
        var stack: [Double] = []
        var elements: [PathElement] = []
        var state = GraphicsState()
        var stateStack: [GraphicsState] = []
        var currentColor: VectorColor = .black
        var pendingGradient: (color1: VectorColor, color2: VectorColor)? = nil

        let tokens = tokenize(text)

        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "moveto":
                if stack.count >= 2 {
                    let y = stack.removeLast(); let x = stack.removeLast()
                    let (tx, ty) = state.transform.apply(x, y)
                    elements.append(.move(to: VectorPoint(tx - originX, pageHeight - (ty - originY))))
                }
            case "lineto":
                if stack.count >= 2 {
                    let y = stack.removeLast(); let x = stack.removeLast()
                    let (tx, ty) = state.transform.apply(x, y)
                    elements.append(.line(to: VectorPoint(tx - originX, pageHeight - (ty - originY))))
                }
            case "curveto":
                if stack.count >= 6 {
                    let y3 = stack.removeLast(); let x3 = stack.removeLast()
                    let y2 = stack.removeLast(); let x2 = stack.removeLast()
                    let y1 = stack.removeLast(); let x1 = stack.removeLast()
                    let (tx1, ty1) = state.transform.apply(x1, y1)
                    let (tx2, ty2) = state.transform.apply(x2, y2)
                    let (tx3, ty3) = state.transform.apply(x3, y3)
                    elements.append(.curve(
                        to: VectorPoint(tx3 - originX, pageHeight - (ty3 - originY)),
                        control1: VectorPoint(tx1 - originX, pageHeight - (ty1 - originY)),
                        control2: VectorPoint(tx2 - originX, pageHeight - (ty2 - originY))
                    ))
                }
            case "closepath":
                elements.append(.close)
            case "newpath":
                elements = []
            case "concat":
                if stack.count >= 6 {
                    let ty = stack.removeLast(); let tx = stack.removeLast()
                    let dd = stack.removeLast(); let cc = stack.removeLast()
                    let bb = stack.removeLast(); let aa = stack.removeLast()
                    let newT = Transform(a: aa, b: bb, c: cc, d: dd, tx: tx, ty: ty)
                    state.transform = state.transform.concat(newT)
                }
            case "gsave":
                stateStack.append(state)
            case "grestore":
                if let saved = stateStack.popLast() {
                    state = saved
                }
            case "setlinewidth":
                if let w = stack.popLast() {
                    state.lineWidth = w
                }
            case "setcolor":
                currentColor = state.fillColor
            case "setcmykcolor":
                if stack.count >= 4 {
                    let k = stack.removeLast(); let y = stack.removeLast()
                    let m = stack.removeLast(); let c = stack.removeLast()
                    let color = cmykToColor(c, m, y, k)
                    state.fillColor = color
                    state.strokeColor = color
                    currentColor = color
                }
            case "radialfill", "eoradialfill":
                if let grad = pendingGradient, !elements.isEmpty {
                    var cx = 0.5, cy = 0.5, rad = 0.5
                    if stack.count >= 3 {
                        rad = stack.removeLast()
                        let rawY = stack.removeLast()
                        let rawX = stack.removeLast()
                        let (tcx, tcy) = state.transform.apply(rawX, rawY)
                        cx = tcx - originX
                        cy = pageHeight - (tcy - originY)
                    }
                    let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
                    let stop1 = GradientStop(position: 0, color: grad.color2)
                    let stop2 = GradientStop(position: 1, color: grad.color1)
                    let radial = RadialGradient(
                        centerPoint: CGPoint(x: cx, y: cy),
                        radius: rad,
                        stops: [stop1, stop2]
                    )
                    let fillStyle = FillStyle(color: .gradient(.radial(radial)))
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                    pendingGradient = nil
                }
                stack.removeAll()
            case "rectfill":
                if let grad = pendingGradient, !elements.isEmpty {
                    let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
                    let stop1 = GradientStop(position: 0, color: grad.color2)
                    let stop2 = GradientStop(position: 1, color: grad.color1)
                    let linear = LinearGradient(
                        startPoint: CGPoint(x: 0, y: 0.5),
                        endPoint: CGPoint(x: 1, y: 0.5),
                        stops: [stop1, stop2]
                    )
                    let fillStyle = FillStyle(color: .gradient(.linear(linear)))
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                    pendingGradient = nil
                }
                stack.removeAll()
            case "{fill}", "{ fill }", "{fill }", "{ fill}":
                if !elements.isEmpty {
                    let isClosed = elements.last.map { if case .close = $0 { return true } else { return false } } ?? false
                    let path = VectorPath(elements: elements, isClosed: isClosed, fillRule: .winding)
                    let fillStyle = FillStyle(color: currentColor)
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                }
            case "{stroke}", "{ stroke }", "{stroke }", "{ stroke}":
                if !elements.isEmpty {
                    let isClosed = elements.last.map { if case .close = $0 { return true } else { return false } } ?? false
                    let path = VectorPath(elements: elements, isClosed: isClosed, fillRule: .winding)
                    let strokeStyle = StrokeStyle(color: currentColor, width: state.lineWidth)
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: strokeStyle, fillStyle: nil, opacity: 1.0
                    ))
                    elements = []
                }
            default:
                if let num = Double(token) {
                    stack.append(num)
                }
                else if token.hasPrefix("[") {
                    var nums: [Double] = []
                    var t = token.dropFirst()
                    if t.hasSuffix("]") { t = t.dropLast() }
                    if let n = Double(t) { nums.append(n) }
                    var j = i + 1
                    while j < tokens.count {
                        var tk = tokens[j]
                        if tk.hasSuffix("]") {
                            tk = String(tk.dropLast())
                            if let n = Double(tk) { nums.append(n) }
                            j += 1
                            break
                        }
                        if let n = Double(tk) { nums.append(n) }
                        j += 1
                    }
                    i = j - 1
                    if nums.count == 6 {
                        stack.append(contentsOf: nums)
                    } else if nums.count == 4 {
                        let color = cmykToColor(nums[0], nums[1], nums[2], nums[3])
                        currentColor = color
                        state.fillColor = color
                        state.strokeColor = color
                        if j < tokens.count && tokens[j].hasPrefix("[") {
                            let firstColor = color

                            var color2Nums: [Double] = []
                            var tk2 = tokens[j].dropFirst()
                            if tk2.hasSuffix("]") { tk2 = tk2.dropLast() }
                            if let n = Double(tk2) { color2Nums.append(n) }
                            var k = j + 1
                            while k < tokens.count {
                                var tkk = tokens[k]
                                if tkk.hasSuffix("]") {
                                    tkk = String(tkk.dropLast())
                                    if let n = Double(tkk) { color2Nums.append(n) }
                                    k += 1
                                    break
                                }
                                if let n = Double(tkk) { color2Nums.append(n) }
                                k += 1
                            }
                            if color2Nums.count == 4 {
                                let secondColor = cmykToColor(color2Nums[0], color2Nums[1], color2Nums[2], color2Nums[3])
                                pendingGradient = (firstColor, secondColor)
                                i = k - 1
                            }
                        }
                    }
                }
            }
            i += 1
        }
        return shapes
    }

    private static func mergeFillStrokePairs(_ shapes: [VectorShape]) -> [VectorShape] {
        var merged: [VectorShape] = []
        var i = 0
        while i < shapes.count {
            let current = shapes[i]
            if i + 1 < shapes.count {
                let next = shapes[i + 1]
                let samePath = current.path.elements.count == next.path.elements.count
                if samePath && current.fillStyle != nil && current.strokeStyle == nil
                    && next.fillStyle == nil && next.strokeStyle != nil {
                    merged.append(VectorShape(
                        name: current.name, path: current.path,
                        geometricType: current.geometricType,
                        strokeStyle: next.strokeStyle,
                        fillStyle: current.fillStyle,
                        opacity: current.opacity
                    ))
                    i += 2
                    continue
                }
            }
            merged.append(current)
            i += 1
        }
        return merged
    }

    private static func cmykToColor(_ c: Double, _ m: Double, _ y: Double, _ k: Double) -> VectorColor {
        let r = (1 - c) * (1 - k)
        let g = (1 - m) * (1 - k)
        let b = (1 - y) * (1 - k)
        return .rgb(RGBColor(red: r, green: g, blue: b))
    }

    private static func tokenize(_ text: String) -> [String] {
        let keywords = ["rectfill","eoclip","closepath","moveto","lineto","curveto",
                        "newpath","gsave","grestore","setlinewidth","setcolor","setcmykcolor",
                        "setlinecap","setlinejoin","setmiterlimit","eofill","setflat",
                        "concat","stroke","fill","clip","def","vms","vmr","end"]
        var processed = text
        processed = processed.replacingOccurrences(of: "eoradialfill", with: " §EORADIALFILL§ ")
        processed = processed.replacingOccurrences(of: "radialfill", with: " §RADIALFILL§ ")
        processed = processed.replacingOccurrences(of: "rectfill", with: " §RECTFILL§ ")
        processed = processed.replacingOccurrences(of: "eofill", with: " §EOFILL§ ")
        processed = processed.replacingOccurrences(of: "eoclip", with: " §EOCLIP§ ")
        for kw in keywords {
            if kw == "rectfill" || kw == "eofill" || kw == "eoclip" { continue }
            processed = processed.replacingOccurrences(of: kw, with: " \(kw) ")
        }
        processed = processed.replacingOccurrences(of: "§EORADIALFILL§", with: "eoradialfill")
        processed = processed.replacingOccurrences(of: "§RADIALFILL§", with: "radialfill")
        processed = processed.replacingOccurrences(of: "§RECTFILL§", with: "rectfill")
        processed = processed.replacingOccurrences(of: "§EOFILL§", with: "eofill")
        processed = processed.replacingOccurrences(of: "§EOCLIP§", with: "eoclip")
        processed = processed.replacingOccurrences(of: "[", with: " [")
        processed = processed.replacingOccurrences(of: "]", with: "] ")
        var tokens: [String] = []
        var current = ""
        var inBrace = 0
        for ch in processed {
            if ch == "{" {
                inBrace += 1
                current.append(ch)
            } else if ch == "}" {
                current.append(ch)
                inBrace -= 1
                if inBrace == 0 {
                    tokens.append(current)
                    current = ""
                }
            } else if inBrace > 0 {
                current.append(ch)
            } else if ch == " " || ch == "\n" || ch == "\r" || ch == "\t" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
