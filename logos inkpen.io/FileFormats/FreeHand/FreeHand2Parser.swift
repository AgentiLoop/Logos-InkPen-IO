import Foundation
import CoreGraphics

enum FreeHand2Parser {
    private static let headerSize = 256
    private static let magic: [UInt8] = [0x46, 0x48, 0x44, 0x32]
    private static let pathRecordType: UInt16 = 0x151C
    private static let ovalRecordType: UInt16 = 0x151A
    private static let rectRecordType: UInt16 = 0x1519
    private static let lineRecordType: UInt16 = 0x151D
    private static let unitsPerPoint: Double = 10.0
    private static let cornerPointType: UInt16 = 0x001B
    private static let curvePointType: UInt16 = 0x0009

    private struct FH2Point {
        let type: UInt16
        let controlIn: CGPoint
        let onCurve: CGPoint
        let controlOut: CGPoint

        var isCorner: Bool { type == cornerPointType }
    }

    private static func readUInt16BE(_ data: Data, offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) << 8 | UInt16(data[base + 1])
    }

    private static func readInt16BE(_ data: Data, offset: Int) -> Int16 {
        return Int16(bitPattern: readUInt16BE(data, offset: offset))
    }

    private static func readUInt32BE(_ data: Data, offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base]) << 24
             | UInt32(data[base + 1]) << 16
             | UInt32(data[base + 2]) << 8
             | UInt32(data[base + 3])
    }

    private struct RecordEntry {
        let offset: Int
        let type: UInt16
        let size: Int
    }

    enum GradientType { case linear, radial }

    struct GradientInfo {
        let type: GradientType
        let colors: [VectorColor]

        init(type: GradientType = .linear, colors: [VectorColor]) {
            self.type = type; self.colors = colors
        }

        init(color1: VectorColor, color2: VectorColor) {
            self.type = .linear; self.colors = [color1, color2]
        }
    }

    private static func buildColorAndWidthTables(data: Data) -> ([Int: VectorColor], [Int: Double], [Int: GradientInfo], [Int: String]) {
        var colorTable: [Int: VectorColor] = [:]
        var widthTable: [Int: Double] = [:]
        var gradientTable: [Int: GradientInfo] = [:]
        var nameTable: [Int: String] = [:]
        var firstChildID = 18
        var tableChildIDs: [Int] = []
        for i in stride(from: headerSize, to: min(data.count - 10, headerSize + 2000), by: 1) {
            guard i + 6 <= data.count else { break }
            if readUInt16BE(data, offset: i + 2) == 0x0005 {
                let size = Int(readUInt16BE(data, offset: i))
                if size >= 16 && size < 200 {
                    let count = Int(readUInt16BE(data, offset: i + 4))
                    if count > 0 && i + 10 < data.count {
                        firstChildID = Int(readUInt16BE(data, offset: i + 10))
                        for k in 0..<count {
                            let off = i + 10 + k * 2
                            guard off + 2 <= data.count, off + 2 <= i + size else { break }
                            tableChildIDs.append(Int(readUInt16BE(data, offset: off)))
                        }
                    }
                    break
                }
            }
        }
        var allRecords: [(offset: Int, type: UInt16, styleRid: Int, globalRid: Int)] = []
        var offset = headerSize
        var globalSeq = firstChildID
        var styleIdx = 0
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)

            var matched = false
            if (rtype == 0x1452 && size == 30) ||
               (rtype == 0x1453 && size == 30) ||
               (rtype == 0x1454 && size == 32 && offset + 22 <= data.count) {
                allRecords.append((offset, rtype, firstChildID + styleIdx, globalSeq))
                styleIdx += 1
                matched = true
            }
            else if (rtype >= 0x14B0 && rtype <= 0x14FF && size >= 10 && size <= 100) ||
                    (rtype == 0x157D && size >= 10 && size <= 100) {
                allRecords.append((offset, rtype, firstChildID + styleIdx, globalSeq))
                styleIdx += 1
                matched = true
            }
            else if rtype == 0x0006 && size >= 6 && size <= 60 {
                allRecords.append((offset, rtype, firstChildID + styleIdx, globalSeq))
                styleIdx += 1
                matched = true
            }
            else if (rtype == 0x1389 && size == 56) ||
                    (rtype == 0x0005 && size >= 16 && size < 300) ||
                    (rtype == 0x138A && size >= 20 && size <= 200) ||
                    (rtype == 0x151C && size >= 44 && offset + size <= data.count
                        && offset + 30 <= data.count
                        && size == 44 + Int(readUInt16BE(data, offset: offset + 28)) * 16) ||
                    (rtype == 0x1519 && size == 60) ||
                    (rtype == 0x151A && size == 56) ||
                    (rtype == 0x151D && size == 48) ||
                    (rtype == 0x13ED && size == 56) ||
                    (rtype == 0x13EE) ||
                    (rtype == 0x12C0 && size == 32) {
                matched = true
            }
            if matched { globalSeq += 1 }
            offset += 1
        }
        for rec in allRecords {
            let rid = rec.styleRid
            let gid = rec.globalRid
            let off = rec.offset

            func storeColor(_ color: VectorColor) {
                colorTable[rid] = color
                colorTable[gid] = color
                let eid = Int(readUInt16BE(data, offset: off + 4))
                if eid > 0 { colorTable[eid] = color }
            }
            if rec.type == 0x1452 || rec.type == 0x1453 {
                let r = Double(readUInt16BE(data, offset: off + 6)) / 65535.0
                let g = Double(readUInt16BE(data, offset: off + 8)) / 65535.0
                let b = Double(readUInt16BE(data, offset: off + 10)) / 65535.0
                storeColor(VectorColor.rgb(RGBColor(red: r, green: g, blue: b)))
            } else if rec.type == 0x1454 {
                let c = Double(readUInt16BE(data, offset: off + 14)) / 65535.0
                let m = Double(readUInt16BE(data, offset: off + 16)) / 65535.0
                let y = Double(readUInt16BE(data, offset: off + 18)) / 65535.0
                let k = Double(readUInt16BE(data, offset: off + 20)) / 65535.0
                let r = (1 - c) * (1 - k); let g = (1 - m) * (1 - k); let b = (1 - y) * (1 - k)
                storeColor(VectorColor.rgb(RGBColor(red: r, green: g, blue: b)))
            }
            if rec.type >= 0x14B0 && off + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: off + 10))
                if rec.type == 0x14B8 && innerRef > 0 {
                    if let edgeColor = colorTable[innerRef] {
                        gradientTable[rid] = GradientInfo(type: .radial, colors: [.white, edgeColor])
                        gradientTable[gid] = GradientInfo(type: .radial, colors: [.white, edgeColor])
                        colorTable[rid] = edgeColor
                        colorTable[gid] = edgeColor
                    }
                } else if rec.type == 0x14B7 && off + 14 <= data.count {
                    let ref2 = Int(readUInt16BE(data, offset: off + 12))
                    if let c1 = colorTable[innerRef], let c2 = colorTable[ref2] {
                        gradientTable[rid] = GradientInfo(color1: c2, color2: c1)
                        gradientTable[gid] = GradientInfo(color1: c2, color2: c1)
                        colorTable[rid] = c1
                        colorTable[gid] = c1
                    }
                } else if innerRef > 0, let color = colorTable[innerRef] {
                    colorTable[rid] = color
                    colorTable[gid] = color
                } else if innerRef == 0 {
                    if let black = colorTable[firstChildID] {
                        colorTable[rid] = black
                        colorTable[gid] = black
                    }
                }
            }
            if rec.type == 0x14B6 && off + 20 <= data.count {
                let rawWidth = Int(readUInt16BE(data, offset: off + 18))
                if rawWidth > 0 {
                    widthTable[rid] = Double(rawWidth) / 10.0
                    widthTable[gid] = Double(rawWidth) / 10.0
                }
            }
            if rec.type == 0x0006, off + 5 <= data.count {
                let nameLen = Int(data[off + 4])
                if nameLen > 0, off + 5 + nameLen <= data.count {
                    let bytes = data[(off + 5)..<(off + 5 + nameLen)]
                    if let str = String(bytes: bytes, encoding: .ascii) {
                        nameTable[rid] = str
                        nameTable[gid] = str
                    }
                }
            }
        }
        let colorRecords = allRecords
            .filter { $0.type == 0x1452 || $0.type == 0x1453 || $0.type == 0x1454 }
            .prefix(tableChildIDs.count)
        for (slotID, colorRec) in zip(tableChildIDs, colorRecords) {
            let off = colorRec.offset
            if colorRec.type == 0x1454 {
                let c = Double(readUInt16BE(data, offset: off + 14)) / 65535.0
                let m = Double(readUInt16BE(data, offset: off + 16)) / 65535.0
                let y = Double(readUInt16BE(data, offset: off + 18)) / 65535.0
                let k = Double(readUInt16BE(data, offset: off + 20)) / 65535.0
                let r = (1 - c) * (1 - k); let g = (1 - m) * (1 - k); let b = (1 - y) * (1 - k)
                colorTable[slotID] = .rgb(RGBColor(red: r, green: g, blue: b))
            } else {
                let r = Double(readUInt16BE(data, offset: off + 6)) / 65535.0
                let g = Double(readUInt16BE(data, offset: off + 8)) / 65535.0
                let b = Double(readUInt16BE(data, offset: off + 10)) / 65535.0
                colorTable[slotID] = .rgb(RGBColor(red: r, green: g, blue: b))
            }
        }
        return (colorTable, widthTable, gradientTable, nameTable)
    }

    private static func parseGroupColorsByAbsID(data: Data,
                                                 colorTable: [Int: VectorColor]) -> [Int: VectorColor] {
        var result: [Int: VectorColor] = [:]
        var offset = headerSize
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            guard rtype == 0x138A, size >= 20, size <= 200,
                  offset + size <= data.count,
                  offset + 34 <= data.count else {
                offset += 1
                continue
            }
            let count = Int(readUInt16BE(data, offset: offset + 32))
            guard count > 0, count < 100, offset + 34 + count * 2 <= data.count else {
                offset += 1
                continue
            }
            var shapeIDs: [Int] = []
            for i in 0..<count {
                let id = Int(readUInt16BE(data, offset: offset + 34 + i * 2))
                if id > 0 { shapeIDs.append(id) }
            }
            guard !shapeIDs.isEmpty else {
                offset += 1
                continue
            }
            if let groupColor = scanForwardForStyleColor(data: data,
                                                         startOffset: offset + size,
                                                         colorTable: colorTable) {
                for id in shapeIDs { result[id] = groupColor }
            }
            offset += 1
        }
        return result
    }

    static func parseNamedStrings(data: Data) -> [String] {
        var names: [String] = []
        var offset = headerSize
        while offset + 6 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            if rtype == 0x0006, size >= 6, size <= 60, offset + size <= data.count {
                let nameLen = Int(data[offset + 4])
                if nameLen > 0, offset + 5 + nameLen <= data.count {
                    let bytes = data[(offset + 5)..<(offset + 5 + nameLen)]
                    if let str = String(bytes: bytes, encoding: .ascii) {
                        names.append(str)
                    }
                }
            }
            offset += 1
        }
        return names
    }

    static func parseTextRecords(data: Data,
                                  colorTable: [Int: VectorColor] = [:],
                                  nameTable: [Int: String] = [:])
        -> [(text: String, x: Double, y: Double, fontSize: Double,
             fontFamily: String, color: VectorColor, layerIndex: Int,
             bold: Bool, italic: Bool, alignment: Int)]
    {
        var distinctFontRefs: [Int] = []
        var seenFontRefs = Set<Int>()
        var scanOffset = headerSize
        while scanOffset + 94 <= data.count {
            let sz = Int(readUInt16BE(data, offset: scanOffset))
            let rt = readUInt16BE(data, offset: scanOffset + 2)
            if rt == 0x13EE, sz >= 94, scanOffset + sz <= data.count {
                let ref = Int(readUInt16BE(data, offset: scanOffset + 90))
                if !seenFontRefs.contains(ref) {
                    seenFontRefs.insert(ref)
                    distinctFontRefs.append(ref)
                }
            }
            scanOffset += 1
        }
        distinctFontRefs.sort()
        var fontRefToRank: [Int: Int] = [:]
        for (rank, ref) in distinctFontRefs.enumerated() {
            fontRefToRank[ref] = rank
        }
        let allNames = parseNamedStrings(data: data)
        let fontNames = Array(allNames.prefix(distinctFontRefs.count))

        var results: [(String, Double, Double, Double, String, VectorColor, Int, Bool, Bool, Int)] = []
        var offset = headerSize
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            guard rtype == 0x13EE, size >= 94, offset + size <= data.count else {
                offset += 1
                continue
            }
            var ascii = ""
            var longest = ""
            for i in (offset + 4)..<(offset + size) {
                let b = data[i]
                if b >= 0x20 && b <= 0x7E {
                    ascii.append(Character(UnicodeScalar(b)))
                } else {
                    if ascii.count > longest.count { longest = ascii }
                    ascii = ""
                }
            }
            if ascii.count > longest.count { longest = ascii }
            guard !longest.isEmpty else {
                offset += 1
                continue
            }
            let layerIdx = Int(readUInt16BE(data, offset: offset + 8))
            let xAnchor  = Int(readUInt16BE(data, offset: offset + 30))
            let yAnchor  = Int(readUInt16BE(data, offset: offset + 32))
            let xDelta   = Int(readInt16BE(data, offset: offset + 58))
            let yDelta   = Int(readInt16BE(data, offset: offset + 62))
            let alignRaw = Int(readUInt16BE(data, offset: offset + 66))
            let fontRef  = Int(readUInt16BE(data, offset: offset + 90))
            let fontSize = Double(readUInt16BE(data, offset: offset + 92))
            let styleBits = Int(readUInt16BE(data, offset: offset + 102))
            let colorRef = Int(readUInt16BE(data, offset: offset + 104))
            let epsX = Double(xAnchor + xDelta) / unitsPerPoint
            let epsY = Double(yAnchor + yDelta) / unitsPerPoint

            let family: String = {
                if let rank = fontRefToRank[fontRef], rank < fontNames.count {
                    return fontNames[rank]
                }
                return ""
            }()
            let bold = (styleBits & 0x1) != 0
            let italic = (styleBits & 0x2) != 0
            let alignment = alignRaw / 256
            let color = colorTable[colorRef]
                        ?? scanForwardForStyleColor(data: data,
                                                     startOffset: offset + size,
                                                     colorTable: colorTable)
                        ?? VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
            results.append((longest, epsX, epsY, fontSize, family, color, layerIdx,
                             bold, italic, alignment))
            offset += 1
        }
        return results
    }

    private static func parseLayers(data: Data) -> [[Int]] {
        var layers: [[Int]] = []
        var offset = headerSize
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            if rtype == 0x138A && size >= 20 && size <= 200 {
                var vals: [Int] = []
                var j = offset + 6
                while j + 1 < offset + size && j + 1 < data.count {
                    vals.append(Int(readUInt16BE(data, offset: j)))
                    j += 2
                }
                var children: [Int] = []
                for (idx, v) in vals.enumerated() {
                    if idx > 0 && v > 0 && v != 16 && v < 10000 {
                        let count = v
                        for k in (idx+1)..<min(idx+1+count, vals.count) {
                            if vals[k] > 0 { children.append(vals[k]) }
                        }
                        break
                    }
                }
                if !children.isEmpty {
                    layers.append(children)
                }
            }
            offset += 1
        }
        return layers
    }

    private static func parsePathStylesByPosition(data: Data,
                                                   pathCount: Int,
                                                   colorTable: [Int: VectorColor])
        -> [Int: VectorColor]
    {
        var pathStyleColors: [VectorColor] = []
        var offset = headerSize
        while offset + 22 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            if rtype == 0x14B5, size >= 10, size <= 100,
               offset + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: offset + 10))
                if innerRef > 0, let color = colorTable[innerRef] {
                    pathStyleColors.append(color)
                }
            }
            offset += 1
        }
        guard pathStyleColors.count >= pathCount else {
            return [:]
        }
        let startIdx = pathStyleColors.count - pathCount

        var result: [Int: VectorColor] = [:]
        for i in 0..<pathCount {
            result[i] = pathStyleColors[startIdx + i]
        }
        return result
    }

    static func debugColorTable(data: Data) -> ([Int: VectorColor], [Int: Double]) {
        let (ct, wt, _, _) = buildColorAndWidthTables(data: data)
        return (ct, wt)
    }

    static func debugGradientTable(data: Data) -> [Int: GradientInfo] {
        let (_, _, gt, _) = buildColorAndWidthTables(data: data)
        return gt
    }

    static func debugNameTable(data: Data) -> [Int: String] {
        let (_, _, _, nt) = buildColorAndWidthTables(data: data)
        return nt
    }

    static func parseToShapes(data: Data) throws -> FreeHandDirectImporter.Result {
        guard data.count >= headerSize + 4 else {
            throw FreeHandImportError.notSupported
        }
        for i in 0..<4 {
            guard data[data.startIndex + i] == magic[i] else {
                throw FreeHandImportError.notSupported
            }
        }
        let pageWidthRaw = Double(readUInt16BE(data, offset: 8))
        let pageHeightRaw = Double(readUInt16BE(data, offset: 10))
        let pageWidth = pageWidthRaw / unitsPerPoint
        let pageHeight = pageHeightRaw / unitsPerPoint
        let pageSize = CGSize(width: pageWidth, height: pageHeight)
        let (colorTable, widthTable, gradientTable, nameTable) = buildColorAndWidthTables(data: data)
        _ = parseLayers(data: data)
        let groupColorByAbsID = parseGroupColorsByAbsID(data: data, colorTable: colorTable)

        var offsetToAbsID: [Int: Int] = [:]
        var preAbsID = 2
        var preOff = headerSize
        while preOff + 4 <= data.count {
            let sz = Int(readUInt16BE(data, offset: preOff))
            let rt = readUInt16BE(data, offset: preOff + 2)

            var found = false
            if rt == 0x138A {  }
            else if rt == 0x1389 && sz == 56 { found = true }
            else if rt == 0x0005 && sz >= 16 && sz < 300 { found = true }
            else if rt == pathRecordType && sz >= 44 && preOff + sz <= data.count && preOff + 29 < data.count {
                if sz == 44 + Int(readUInt16BE(data, offset: preOff + 28)) * 16 { found = true }
            }
            else if (rt == rectRecordType && sz == 60) || (rt == ovalRecordType && sz == 56) ||
                    (rt == lineRecordType && sz == 48) { found = true }
            else if (rt >= 0x1452 && rt <= 0x1454 && sz >= 30 && sz <= 32) { found = true }
            else if (rt >= 0x14B0 && rt <= 0x14FF && sz >= 10 && sz <= 100) { found = true }
            else if (rt == 0x157D && sz >= 10 && sz <= 100) { found = true }
            else if (rt == 0x13ED && sz == 56) { found = true }
            if found {
                offsetToAbsID[preOff] = preAbsID
                preAbsID += 1
            }
            preOff += 1
        }
        var shapes: [VectorShape] = []
        var shapeAbsIDs: [Int] = []
        var shapeLayerIdx: [Int] = []
        var offset = headerSize
        while offset + 4 <= data.count {
            let word = readUInt16BE(data, offset: offset)
            let rtype = readUInt16BE(data, offset: offset + 2)

            func recordLayerIdx() -> Int {
                guard offset + 10 <= data.count else { return 1 }
                return max(1, Int(readUInt16BE(data, offset: offset + 8)))
            }
            if offset + 44 <= data.count {
                if rtype == pathRecordType && word >= 44 && offset + Int(word) <= data.count {
                    let recordSize = Int(word)
                    let pointCount = Int(readUInt16BE(data, offset: offset + 28))
                    let expectedSize = 44 + pointCount * 16
                    if recordSize == expectedSize {
                        if let shape = parsePathRecord(data: data, recordOffset: offset,
                                                       recordSize: recordSize,
                                                       pageHeight: pageHeight,
                                                       colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                            shapes.append(shape)
                            shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                            shapeLayerIdx.append(recordLayerIdx())
                        }
                    }
                } else if rtype == ovalRecordType && word == 56 && offset + 40 <= data.count {
                    if let shape = parseOvalRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                        shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                        shapeLayerIdx.append(recordLayerIdx())
                    }
                } else if rtype == rectRecordType && word == 60 && offset + 44 <= data.count {
                    if let shape = parseRectRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                        shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                        shapeLayerIdx.append(recordLayerIdx())
                    }
                } else if rtype == lineRecordType && word == 48 && offset + 40 <= data.count {
                    if let shape = parseLineRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                        shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                        shapeLayerIdx.append(recordLayerIdx())
                    }
                }
            }
            offset += 1
        }
        guard !shapes.isEmpty else {
            throw FreeHandImportError.emptyOutput
        }
        if !groupColorByAbsID.isEmpty {
            for i in 0..<shapes.count {
                let absID = shapeAbsIDs[i]
                if let groupColor = groupColorByAbsID[absID] {
                    shapes[i].fillStyle = FillStyle(color: groupColor)
                }
            }
        }
        let positionalColors = parsePathStylesByPosition(data: data,
                                                          pathCount: shapes.count,
                                                          colorTable: colorTable)
        if !positionalColors.isEmpty {
            for i in 0..<shapes.count {
                if groupColorByAbsID[shapeAbsIDs[i]] == nil,

                   let c = positionalColors[i] {
                    shapes[i].fillStyle = FillStyle(color: c)
                }
            }
        }
        var nativeLayers: [Layer] = []

        let totalLayers = max(1, (shapeLayerIdx + [1]).max() ?? 1)
        for layer in 1...totalLayers {
            var objectIDs: [UUID] = []
            for (i, idx) in shapeLayerIdx.enumerated() where idx == layer {
                objectIDs.append(shapes[i].id)
            }
            nativeLayers.append(Layer(
                name: "Layer \(layer)",
                objectIDs: objectIDs,
                isVisible: true,
                isLocked: false,
                opacity: 1.0,
                blendMode: .normal,
                color: .blue
            ))
        }
        let stats = FreeHandDirectImporter.Stats(
            paths: shapes.count,
            groups: 0,
            clipGroups: 0,
            compositePaths: 0,
            newBlends: 0,
            symbolInstances: 0,
            contentIdPaths: 0
        )
        let textRuns = parseTextRecords(data: data, colorTable: colorTable, nameTable: nameTable)
        let effectiveSize = inferEffectivePageSize(shapes: shapes,
                                                    textRuns: textRuns,
                                                    storedPage: pageSize)
        if effectiveSize != pageSize {
            let deltaH = pageSize.height - effectiveSize.height
            for i in 0..<shapes.count {
                shapes[i] = translateShapeY(shapes[i], by: -deltaH)
            }
        }
        for run in textRuns {
            let flippedY = effectiveSize.height - CGFloat(run.y)
            let textOrigin = CGPoint(x: CGFloat(run.x), y: flippedY)
            let estWidth = Double(run.text.count) * run.fontSize * 0.55

            var textShape = VectorShape(
                name: run.text,
                path: VectorPath(elements: [], isClosed: false),
                strokeStyle: nil,
                fillStyle: FillStyle(color: run.color),
                transform: .identity
            )
            textShape.textContent = run.text
            textShape.textPosition = textOrigin

            let variant: String? = {
                switch (run.bold, run.italic) {
                case (true, true): return "BoldItalic"
                case (true, false): return "Bold"
                case (false, true): return "Italic"
                case (false, false): return nil
                }
            }()

            let alignment: TextAlignment = {
                switch run.alignment {
                case 1: return .center
                case 2: return .right
                case 3: return .justified
                default: return .left
                }
            }()
            textShape.typography = TypographyProperties(
                fontFamily: run.fontFamily,
                fontVariant: variant,
                fontSize: run.fontSize,
                lineHeight: run.fontSize,
                alignment: alignment,
                strokeColor: .clear,
                fillColor: run.color
            )
            let estHeight = run.fontSize * 1.25
            textShape.areaSize = CGSize(width: estWidth, height: estHeight)
            textShape.transform = CGAffineTransform(translationX: textOrigin.x, y: textOrigin.y)
            textShape.bounds = CGRect(x: 0, y: 0, width: estWidth, height: estHeight)
            shapes.append(textShape)
            shapeAbsIDs.append(0)
            let targetLayer = max(1, run.layerIndex)
            while nativeLayers.count < targetLayer {
                nativeLayers.append(Layer(
                    name: "Layer \(nativeLayers.count + 1)",
                    objectIDs: [],
                    isVisible: true,
                    isLocked: false,
                    opacity: 1.0,
                    blendMode: .normal,
                    color: .blue
                ))
            }
            nativeLayers[targetLayer - 1].objectIDs.append(textShape.id)
        }
        return FreeHandDirectImporter.Result(
            shapes: shapes,
            pageSize: effectiveSize,
            stats: stats,
            layers: nativeLayers,
            groupShapeIDs: []
        )
    }

    private static func inferEffectivePageSize(shapes: [VectorShape],
                                                textRuns: [(text: String, x: Double, y: Double, fontSize: Double, fontFamily: String, color: VectorColor, layerIndex: Int, bold: Bool, italic: Bool, alignment: Int)],
                                                storedPage: CGSize) -> CGSize {
        var union = CGRect.null
        for s in shapes {
            let b = s.bounds.applying(s.transform)
            if !b.isNull && !b.isInfinite && b.width > 0 && b.height > 0 {
                union = union.union(b)
            }
        }
        for run in textRuns {
            let estW = CGFloat(Double(run.text.count) * run.fontSize * 0.55)
            let estH = CGFloat(run.fontSize * 1.25)
            let b = CGRect(x: CGFloat(run.x), y: CGFloat(run.y - run.fontSize), width: estW, height: estH)
            union = union.union(b)
        }
        guard !union.isNull, union.width > 0, union.height > 0 else { return storedPage }
        let pageIsPortrait = storedPage.height > storedPage.width
        let contentOverflowsWidth = union.maxX > storedPage.width
        let drawingIsLandscape = union.width > union.height * 1.05
        if pageIsPortrait && (contentOverflowsWidth || drawingIsLandscape) {
            return CGSize(width: storedPage.height, height: storedPage.width)
        }
        return storedPage
    }

    private static func translateShapeY(_ shape: VectorShape, by dy: CGFloat) -> VectorShape {
        var s = shape

        let t = CGAffineTransform(translationX: 0, y: dy)
        s.path = s.path.applying(t)
        s.bounds = s.bounds.offsetBy(dx: 0, dy: dy)
        if let tp = s.textPosition {
            s.textPosition = CGPoint(x: tp.x, y: tp.y + dy)
        }
        if !s.transform.isIdentity {
            s.transform = s.transform.concatenating(t)
        }
        return s
    }

    private static func parsePathRecord(data: Data, recordOffset: Int,
                                        recordSize: Int,
                                        pageHeight: Double,
                                        colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
        guard recordSize >= 44 else { return nil }
        let pointCount = Int(readUInt16BE(data, offset: recordOffset + 28))
        guard pointCount > 0 else { return nil }
        let expectedSize = 44 + pointCount * 16
        guard recordSize >= expectedSize else { return nil }
        let pointDataStart = recordOffset + 30

        var fh2Points: [FH2Point] = []
        fh2Points.reserveCapacity(pointCount)
        for i in 0..<pointCount {
            let pOffset = pointDataStart + i * 16
            let pointType = readUInt16BE(data, offset: pOffset + 2)
            let x1 = Double(readInt16BE(data, offset: pOffset + 4))
            let y1 = Double(readInt16BE(data, offset: pOffset + 6))
            let x2 = Double(readInt16BE(data, offset: pOffset + 8))
            let y2 = Double(readInt16BE(data, offset: pOffset + 10))
            let x3 = Double(readInt16BE(data, offset: pOffset + 12))
            let y3 = Double(readInt16BE(data, offset: pOffset + 14))
            let onCurve = CGPoint(
                x: x1 / unitsPerPoint,
                y: pageHeight - y1 / unitsPerPoint
            )
            let controlIn = CGPoint(
                x: x2 / unitsPerPoint,
                y: pageHeight - y2 / unitsPerPoint
            )
            let controlOut = CGPoint(
                x: x3 / unitsPerPoint,
                y: pageHeight - y3 / unitsPerPoint
            )
            fh2Points.append(FH2Point(
                type: pointType,
                controlIn: controlIn,
                onCurve: onCurve,
                controlOut: controlOut
            ))
        }
        let filledFlag = readUInt16BE(data, offset: recordOffset + 26)
        let firstOnCurve = fh2Points[0].onCurve
        let lastOnCurve = fh2Points[fh2Points.count - 1].onCurve
        let pointsMatch = fh2Points.count > 1
            && abs(firstOnCurve.x - lastOnCurve.x) < 0.01
            && abs(firstOnCurve.y - lastOnCurve.y) < 0.01
        let isClosed = pointsMatch || filledFlag == 1
        let elements = buildPathElements(from: fh2Points, closed: isClosed)
        guard !elements.isEmpty else { return nil }
        let path = VectorPath(
            elements: elements,
            isClosed: isClosed,
            fillRule: .winding
        )
        let (fillStyle, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                          colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: isClosed)
        return VectorShape(
            name: "Path",
            path: path,
            geometricType: nil,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: 1.0
        )
    }

    private static func scanForwardForStyleColor(data: Data, startOffset: Int,
                                                  colorTable: [Int: VectorColor]) -> VectorColor? {
        let limit = min(startOffset + 2048, data.count - 4)

        var o = startOffset
        while o < limit {
            let size = Int(readUInt16BE(data, offset: o))
            let rtype = readUInt16BE(data, offset: o + 2)
            if rtype == 0x14B5, size >= 12, o + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: o + 10))
                if innerRef > 0, let c = colorTable[innerRef] {
                    return c
                }
            }
            o += 1
        }
        return nil
    }

    private static func extractFillStroke(data: Data, recordOffset: Int,
                                           colorTable: [Int: VectorColor],
                                           widthTable: [Int: Double], gradientTable: [Int: GradientInfo] = [:],
                                           isClosed: Bool) -> (fill: FillStyle?, stroke: StrokeStyle?) {
        let fillRef = Int(readUInt16BE(data, offset: recordOffset + 18))
        let strokeRef = Int(readUInt16BE(data, offset: recordOffset + 20))
        let whiteFillFlag = data[recordOffset + 13] & 0x80 != 0

        var fillStyle: FillStyle? = nil
        if isClosed && whiteFillFlag {
            fillStyle = FillStyle(color: .white)
        } else if isClosed && fillRef > 0 {
            if let grad = gradientTable[fillRef], grad.colors.count >= 2 {
                var stops: [GradientStop] = []
                for (idx, color) in grad.colors.enumerated() {
                    let pos = grad.colors.count > 1 ? Double(idx) / Double(grad.colors.count - 1) : 0
                    stops.append(GradientStop(position: pos, color: color))
                }
                switch grad.type {
                case .linear:
                    let linear = LinearGradient(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5), stops: stops)
                    fillStyle = FillStyle(color: .gradient(.linear(linear)))
                case .radial:
                    let radial = RadialGradient(centerPoint: CGPoint(x: 0.5, y: 0.5), radius: 0.5, stops: stops)
                    fillStyle = FillStyle(color: .gradient(.radial(radial)))
                }
            } else if let fillColor = colorTable[fillRef] {
                fillStyle = FillStyle(color: fillColor)
            } else if let scanned = Self.scanForwardForStyleColor(data: data, startOffset: recordOffset + 44, colorTable: colorTable) {
                fillStyle = FillStyle(color: scanned)
            } else {
                let fillGrayByte = data[recordOffset + 12]
                let fillGray = 1.0 - Double(fillGrayByte) / 127.0
                fillStyle = FillStyle(color: .rgb(RGBColor(red: fillGray, green: fillGray, blue: fillGray)))
            }
        }
        let strokeStyle: StrokeStyle?
        if strokeRef > 0, let strokeColor = colorTable[strokeRef] {
            let strokeWidth = widthTable[strokeRef] ?? 0.5
            strokeStyle = StrokeStyle(color: strokeColor, width: strokeWidth)
        } else {
            strokeStyle = nil
        }
        return (fillStyle, strokeStyle)
    }

    private static func parseRectRecord(data: Data, recordOffset: Int,
                                         pageHeight: Double,
                                         colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
        let left = Double(readInt16BE(data, offset: recordOffset + 26)) / unitsPerPoint
        let top = Double(readInt16BE(data, offset: recordOffset + 28)) / unitsPerPoint
        let right = Double(readInt16BE(data, offset: recordOffset + 30)) / unitsPerPoint
        let bottom = Double(readInt16BE(data, offset: recordOffset + 32)) / unitsPerPoint
        let width = right - left
        let height = top - bottom
        guard width > 0.1 && height > 0.1 else { return nil }
        let cornerRadiusX = Double(readUInt16BE(data, offset: recordOffset + 38)) / unitsPerPoint
        let cornerRadiusY = Double(readUInt16BE(data, offset: recordOffset + 40)) / unitsPerPoint
        let cr = min(cornerRadiusX, cornerRadiusY, width / 2, height / 2)
        let x = left
        let y = pageHeight - top
        let elements: [PathElement]
        if cr > 0.1 {
            let k: Double = 0.5522847498
            elements = [
                .move(to: VectorPoint(x + cr, y)),
                .line(to: VectorPoint(x + width - cr, y)),
                .curve(to: VectorPoint(x + width, y + cr),
                       control1: VectorPoint(x + width - cr + cr * k, y),
                       control2: VectorPoint(x + width, y + cr - cr * k)),
                .line(to: VectorPoint(x + width, y + height - cr)),
                .curve(to: VectorPoint(x + width - cr, y + height),
                       control1: VectorPoint(x + width, y + height - cr + cr * k),
                       control2: VectorPoint(x + width - cr + cr * k, y + height)),
                .line(to: VectorPoint(x + cr, y + height)),
                .curve(to: VectorPoint(x, y + height - cr),
                       control1: VectorPoint(x + cr - cr * k, y + height),
                       control2: VectorPoint(x, y + height - cr + cr * k)),
                .line(to: VectorPoint(x, y + cr)),
                .curve(to: VectorPoint(x + cr, y),
                       control1: VectorPoint(x, y + cr - cr * k),
                       control2: VectorPoint(x + cr - cr * k, y)),
                .close
            ]
        } else {
            elements = [
                .move(to: VectorPoint(x, y)),
                .line(to: VectorPoint(x + width, y)),
                .line(to: VectorPoint(x + width, y + height)),
                .line(to: VectorPoint(x, y + height)),
                .close
            ]
        }
        let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
        let (fillStyle, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                          colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: true)
        return VectorShape(
            name: cr > 0.1 ? "Rounded Rectangle" : "Rectangle",
            path: path,
            geometricType: .rectangle,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: 1.0
        )
    }

    private static func parseLineRecord(data: Data, recordOffset: Int,
                                          pageHeight: Double,
                                          colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
        let x1 = Double(readInt16BE(data, offset: recordOffset + 26)) / unitsPerPoint
        let y1 = pageHeight - Double(readInt16BE(data, offset: recordOffset + 28)) / unitsPerPoint
        let x2 = Double(readInt16BE(data, offset: recordOffset + 30)) / unitsPerPoint
        let y2 = pageHeight - Double(readInt16BE(data, offset: recordOffset + 32)) / unitsPerPoint
        let elements: [PathElement] = [
            .move(to: VectorPoint(x1, y1)),
            .line(to: VectorPoint(x2, y2))
        ]
        let path = VectorPath(elements: elements, isClosed: false, fillRule: .winding)
        let (_, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                  colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: false)
        return VectorShape(
            name: "Line",
            path: path,
            geometricType: nil,
            strokeStyle: strokeStyle,
            fillStyle: nil,
            opacity: 1.0
        )
    }

    private static func parseOvalRecord(data: Data, recordOffset: Int,
                                         pageHeight: Double,
                                         colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
        let left = Double(readInt16BE(data, offset: recordOffset + 26)) / unitsPerPoint
        let top = Double(readInt16BE(data, offset: recordOffset + 28)) / unitsPerPoint
        let right = Double(readInt16BE(data, offset: recordOffset + 30)) / unitsPerPoint
        let bottom = Double(readInt16BE(data, offset: recordOffset + 32)) / unitsPerPoint
        let width = right - left
        let height = top - bottom
        guard width > 0.1 && height > 0.1 else { return nil }
        let cx = left + width / 2.0
        let cy = pageHeight - (bottom + height / 2.0)
        let rx = width / 2.0
        let ry = height / 2.0
        let k: Double = 0.5522847498
        let elements: [PathElement] = [
            .move(to: VectorPoint(cx + rx, cy)),
            .curve(to: VectorPoint(cx, cy - ry),
                   control1: VectorPoint(cx + rx, cy - ry * k),
                   control2: VectorPoint(cx + rx * k, cy - ry)),
            .curve(to: VectorPoint(cx - rx, cy),
                   control1: VectorPoint(cx - rx * k, cy - ry),
                   control2: VectorPoint(cx - rx, cy - ry * k)),
            .curve(to: VectorPoint(cx, cy + ry),
                   control1: VectorPoint(cx - rx, cy + ry * k),
                   control2: VectorPoint(cx - rx * k, cy + ry)),
            .curve(to: VectorPoint(cx + rx, cy),
                   control1: VectorPoint(cx + rx * k, cy + ry),
                   control2: VectorPoint(cx + rx, cy + ry * k)),
            .close
        ]
        let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
        let (fillStyle, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                          colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: true)
        return VectorShape(
            name: "Ellipse",
            path: path,
            geometricType: .ellipse,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: 1.0
        )
    }

    private static func buildPathElements(from points: [FH2Point], closed: Bool = false) -> [PathElement] {
        guard let first = points.first else { return [] }
        var elements: [PathElement] = []
        elements.reserveCapacity(points.count + 1)
        elements.append(.move(to: VectorPoint(first.onCurve.x, first.onCurve.y)))
        let segmentCount = points.count - 1
        for i in 0..<segmentCount {
            let prev = points[i]
            let next = points[(i + 1) % points.count]
            let prevOutCoincident =
                abs(prev.controlOut.x - prev.onCurve.x) < 0.01
                && abs(prev.controlOut.y - prev.onCurve.y) < 0.01
            let nextInCoincident =
                abs(next.controlIn.x - next.onCurve.x) < 0.01
                && abs(next.controlIn.y - next.onCurve.y) < 0.01
            if prevOutCoincident && nextInCoincident {
                elements.append(.line(to: VectorPoint(next.onCurve.x, next.onCurve.y)))
            } else {
                elements.append(.curve(
                    to: VectorPoint(next.onCurve.x, next.onCurve.y),
                    control1: VectorPoint(prev.controlOut.x, prev.controlOut.y),
                    control2: VectorPoint(next.controlIn.x, next.controlIn.y)
                ))
            }
        }
        if closed {
            let last = points[points.count - 1]
            let prevOutCoincident = abs(last.controlOut.x - last.onCurve.x) < 0.01
                && abs(last.controlOut.y - last.onCurve.y) < 0.01
            let nextInCoincident = abs(first.controlIn.x - first.onCurve.x) < 0.01
                && abs(first.controlIn.y - first.onCurve.y) < 0.01
            if prevOutCoincident && nextInCoincident {
                elements.append(.line(to: VectorPoint(first.onCurve.x, first.onCurve.y)))
            } else {
                elements.append(.curve(
                    to: VectorPoint(first.onCurve.x, first.onCurve.y),
                    control1: VectorPoint(last.controlOut.x, last.controlOut.y),
                    control2: VectorPoint(first.controlIn.x, first.controlIn.y)
                ))
            }
            elements.append(.close)
        }
        return elements
    }
}
