import Foundation
import CoreGraphics

enum FreeHandImportError: Error {
    case notSupported
    case parseFailed(code: Int)
    case emptyOutput
    case allocationFailed
}

enum FreeHandDirectImporter {

    struct Stats {
        let paths: Int
        let groups: Int
        let clipGroups: Int
        let compositePaths: Int
        let newBlends: Int
        let symbolInstances: Int
        let contentIdPaths: Int
    }

    struct Result {
        let shapes: [VectorShape]
        let pageSize: CGSize
        let stats: Stats
        let layers: [Layer]
        let groupShapeIDs: [UUID]
    }

    private static func stripIPTCWrapper(_ data: Data) -> Data {
        guard data.count >= 4 else { return data }
        let b0 = data[data.startIndex]
        if b0 == UInt8(ascii: "A") || b0 == UInt8(ascii: "F") { return data }
        let a = UInt8(ascii: "A"), g = UInt8(ascii: "G"), d = UInt8(ascii: "D")
        let end = data.count - 3
        for i in 1..<end {
            if data[data.startIndex + i] == a,
               data[data.startIndex + i + 1] == g,
               data[data.startIndex + i + 2] == d {
                return data.suffix(from: data.startIndex + i)
            }
        }
        return data
    }

    static func parseToShapes(data: Data) throws -> Result {
        if data.count >= 4,
           data[data.startIndex] == 0x46,
           data[data.startIndex + 1] == 0x48,
           data[data.startIndex + 2] == 0x44,
           data[data.startIndex + 3] == 0x32
        {
            return try FreeHand2Parser.parseToShapes(data: data)
        }
        if data.count >= 10,
           data[data.startIndex] == 0x25,
           data[data.startIndex + 1] == 0x21,
           data[data.startIndex + 2] == 0x50,
           data[data.startIndex + 3] == 0x53
        {
            return try FreeHandEPSParser.parseToShapes(data: data)
        }
        let fhData = stripIPTCWrapper(data)
        return try fhData.withUnsafeBytes { bytes -> Result in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw FreeHandImportError.notSupported
            }
            var handle: OpaquePointer? = nil

            let rc = freehand_parse_to_shapes(base, fhData.count, &handle)
            guard rc == 0, let result = handle else {
                switch rc {
                case 2: throw FreeHandImportError.notSupported
                case 4: throw FreeHandImportError.emptyOutput
                case 5: throw FreeHandImportError.allocationFailed
                default: throw FreeHandImportError.parseFailed(code: Int(rc))
                }
            }
            defer { fh_result_free(result) }
            let shapes = Self.buildShapes(from: result)
            let pageSize = CGSize(
                width: fh_result_page_width(result),
                height: fh_result_page_height(result)
            )
            let stats = Stats(
                paths: Int(fh_result_stat_paths(result)),
                groups: Int(fh_result_stat_groups(result)),
                clipGroups: Int(fh_result_stat_clip_groups(result)),
                compositePaths: Int(fh_result_stat_composite_paths(result)),
                newBlends: Int(fh_result_stat_new_blends(result)),
                symbolInstances: Int(fh_result_stat_symbol_instances(result)),
                contentIdPaths: Int(fh_result_stat_content_id_paths(result))
            )
            return Result(shapes: shapes, pageSize: pageSize, stats: stats, layers: [], groupShapeIDs: [])
        }
    }

    static func parseToShapes(url: URL) throws -> Result {
        let data = try Data(contentsOf: url)
        return try parseToShapes(data: data)
    }

    private static func buildShapes(from result: OpaquePointer) -> [VectorShape] {
        let count = fh_result_shape_count(result)

        var built: [VectorShape?] = Array(repeating: nil, count: count)
        var consumed = Set<size_t>()
        for idx in 0..<count {
            let kind = Int(fh_result_shape_kind(result, idx))
            switch kind {
            case FH_SHAPE_KIND_PATH:
                built[idx] = makePathShape(from: result, index: idx, isCompound: false)
            case FH_SHAPE_KIND_COMPOUND_PATH:
                built[idx] = makePathShape(from: result, index: idx, isCompound: true)
            case FH_SHAPE_KIND_GROUP, FH_SHAPE_KIND_CLIP_GROUP:
                built[idx] = makeGroupShape(
                    from: result,
                    index: idx,
                    built: &built,
                    consumed: &consumed,
                    isClip: kind == FH_SHAPE_KIND_CLIP_GROUP
                )
            default:
                break
            }
        }
        var top: [VectorShape] = []
        top.reserveCapacity(count)
        for (idx, shape) in built.enumerated() {
            guard let shape = shape else { continue }
            if consumed.contains(idx) { continue }
            top.append(shape)
        }
        return top
    }

    private static func makePathShape(from result: OpaquePointer, index: size_t, isCompound: Bool) -> VectorShape? {
        let elementCount = fh_result_shape_path_element_count(result, index)
        guard elementCount > 0 else { return nil }
        var elements: [PathElement] = []
        elements.reserveCapacity(elementCount)
        for elIdx in 0..<elementCount {
            let kind = Int(fh_result_shape_path_element_kind(result, index, elIdx))
            let x = fh_result_shape_path_element_coord(result, index, elIdx, 0)
            let y = fh_result_shape_path_element_coord(result, index, elIdx, 1)
            let x1 = fh_result_shape_path_element_coord(result, index, elIdx, 2)
            let y1 = fh_result_shape_path_element_coord(result, index, elIdx, 3)
            let x2 = fh_result_shape_path_element_coord(result, index, elIdx, 4)
            let y2 = fh_result_shape_path_element_coord(result, index, elIdx, 5)
            switch kind {
            case FH_PATH_MOVE:
                elements.append(.move(to: VectorPoint(x, y)))
            case FH_PATH_LINE:
                elements.append(.line(to: VectorPoint(x, y)))
            case FH_PATH_CUBIC:
                elements.append(.curve(
                    to: VectorPoint(x, y),
                    control1: VectorPoint(x1, y1),
                    control2: VectorPoint(x2, y2)
                ))
            case FH_PATH_QUAD:
                elements.append(.quadCurve(to: VectorPoint(x, y), control: VectorPoint(x1, y1)))
            case FH_PATH_CLOSE:
                elements.append(.close)
            default:
                break
            }
        }
        guard !elements.isEmpty else { return nil }
        let isClosed = fh_result_shape_is_closed(result, index) != 0
        let evenOdd = fh_result_shape_even_odd(result, index) != 0
        let path = VectorPath(
            elements: elements,
            isClosed: isClosed,
            fillRule: evenOdd ? .evenOdd : .winding
        )
        let fillKind = Int(fh_result_shape_fill_kind(result, index))

        var fillStyle: FillStyle? = nil
        switch fillKind {
        case FH_FILL_SOLID:
            let color = VectorColor.rgb(RGBColor(
                red: fh_result_shape_fill_r(result, index),
                green: fh_result_shape_fill_g(result, index),
                blue: fh_result_shape_fill_b(result, index),
                alpha: fh_result_shape_fill_a(result, index)
            ))
            fillStyle = FillStyle(color: color)
        case FH_FILL_LINEAR:
            if let gradient = buildLinearGradient(from: result, index: index) {
                fillStyle = FillStyle(color: .gradient(gradient))
            }
        case FH_FILL_RADIAL:
            if let gradient = buildRadialGradient(from: result, index: index) {
                fillStyle = FillStyle(color: .gradient(gradient))
            }
        default:
            break
        }
        var strokeStyle: StrokeStyle? = nil
        if fh_result_shape_has_stroke(result, index) != 0 {
            let color = VectorColor.rgb(RGBColor(
                red: fh_result_shape_stroke_r(result, index),
                green: fh_result_shape_stroke_g(result, index),
                blue: fh_result_shape_stroke_b(result, index),
                alpha: fh_result_shape_stroke_a(result, index)
            ))
            strokeStyle = StrokeStyle(
                color: color,
                width: fh_result_shape_stroke_width(result, index)
            )
        }
        if fillStyle == nil && strokeStyle == nil {
            if ApplicationSettings.shared.importFreeHandEffects {
                strokeStyle = StrokeStyle(color: .black, width: 0.5)
            } else {
                return nil
            }
        }
        let opacity = fh_result_shape_opacity(result, index)

        var detectedType: GeometricShapeType? = nil
        var baseName = isCompound ? "Compound Path" : "Path"
        if !isCompound, let detected = PathShapeDetector.detect(elements: elements) {
            detectedType = detected.type
            baseName = detected.name
        }
        return VectorShape(
            name: baseName,
            path: path,
            geometricType: detectedType,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: opacity,
            isCompoundPath: isCompound
        )
    }

    private static func readGradientStops(from result: OpaquePointer, index: size_t) -> [GradientStop] {
        let count = fh_result_shape_gradient_stop_count(result, index)

        var stops: [GradientStop] = []
        stops.reserveCapacity(count)
        for s in 0..<count {
            let color = VectorColor.rgb(RGBColor(
                red: fh_result_shape_gradient_stop_r(result, index, s),
                green: fh_result_shape_gradient_stop_g(result, index, s),
                blue: fh_result_shape_gradient_stop_b(result, index, s),
                alpha: fh_result_shape_gradient_stop_a(result, index, s)
            ))
            stops.append(GradientStop(
                position: fh_result_shape_gradient_stop_position(result, index, s),
                color: color
            ))
        }
        if stops.isEmpty {
            stops.append(GradientStop(position: 0, color: .black))
            stops.append(GradientStop(position: 1, color: .white))
        }
        return stops
    }

    private static func buildLinearGradient(from result: OpaquePointer, index: size_t) -> VectorGradient? {
        let stops = readGradientStops(from: result, index: index)
        let angleDeg = fh_result_shape_fill_angle(result, index)
        let angleRad = angleDeg * .pi / 180.0
        let dx = cos(angleRad) * 0.5
        let dy = sin(angleRad) * 0.5
        let start = CGPoint(x: 0.5 - dx, y: 0.5 - dy)
        let end = CGPoint(x: 0.5 + dx, y: 0.5 + dy)
        let linear = LinearGradient(startPoint: start, endPoint: end, stops: stops)
        return .linear(linear)
    }

    private static func buildRadialGradient(from result: OpaquePointer, index: size_t) -> VectorGradient? {
        let stops = readGradientStops(from: result, index: index)
        let cx = fh_result_shape_fill_center_x(result, index)
        let cy = fh_result_shape_fill_center_y(result, index)
        let radial = RadialGradient(
            centerPoint: CGPoint(x: cx, y: cy),
            radius: 0.5,
            stops: stops
        )
        return .radial(radial)
    }

    private static func makeGroupShape(
        from result: OpaquePointer,
        index: size_t,
        built: inout [VectorShape?],
        consumed: inout Set<size_t>,
        isClip: Bool
    ) -> VectorShape? {
        let memberCount = fh_result_shape_member_count(result, index)
        guard memberCount > 0 else { return nil }
        var peerIndices: [size_t] = []
        peerIndices.reserveCapacity(memberCount)
        for m in 0..<memberCount {
            let peerIdx = fh_result_shape_member_index(result, index, m)
            guard peerIdx < built.count, built[peerIdx] != nil else { continue }
            consumed.insert(peerIdx)
            peerIndices.append(peerIdx)
        }
        guard !peerIndices.isEmpty else { return nil }
        var memberShapes: [VectorShape] = []
        memberShapes.reserveCapacity(peerIndices.count)
        for peerIdx in peerIndices {
            if let shape = built[peerIdx] { memberShapes.append(shape) }
        }
        if isClip && !memberShapes.isEmpty {
            memberShapes[0].name = "Clip Path"
            for i in 1..<memberShapes.count {
                memberShapes[i].name = "Masked " + memberShapes[i].name
            }
        }
        let name = isClip ? "Clipping Group" : "Group"

        var container = VectorShape.group(from: memberShapes, name: name, isClippingGroup: isClip)
        container.memberIDs = []
        container.groupedShapes = memberShapes
        return container
    }
}
