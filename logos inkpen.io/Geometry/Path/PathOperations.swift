import SwiftUI
import Combine

enum PathfinderOperation: String, CaseIterable, Codable {
    case union = "Union"
case minusFront = "Punch"
case intersect = "Intersect"
case exclude = "Exclude"
    case mosaic = "Mosaic"
    case cut = "Cut"
    case merge = "Merge"
    case crop = "Crop"
    case dieline = "Dieline"
    case kick = "Kick"
    case separate = "Separate"
    case combine = "Combine"

    var iconName: String {
        switch self {
        case .union: return "plus.circle"
        case .minusFront: return "minus.circle"
        case .intersect: return "circle.circle"
        case .exclude: return "xmark.circle"
        case .mosaic: return "mosaic.fill"
        case .cut: return "scissors"
        case .merge: return "arrow.triangle.merge"
        case .crop: return "crop"
        case .dieline: return "line.3.crossed.swirl.circle"
        case .kick: return "minus.circle.fill"
        case .separate: return "square.split.2x1"
        case .combine: return "square.on.square"
        }
    }

    var isShapeMode: Bool {
        switch self {
        case .union, .minusFront, .intersect, .exclude:
            return true
        case .mosaic, .cut, .merge, .crop, .dieline, .kick, .separate, .combine:
            return false
        }
    }

    var description: String {
        switch self {
        case .union: return "Combines exactly two shapes into a single shape"
        case .minusFront: return "Front shape cuts holes in back shape"
        case .intersect: return "Creates a shape from only the overlapping areas"
        case .exclude: return "Removes overlapping areas, keeps non-overlapping parts"
        case .mosaic: return "Creates stained glass effect - preserves ALL visible areas, breaks at intersections, no subtraction (CoreGraphics)"
        case .cut: return "Removes hidden parts with curve preservation (CoreGraphics)"
        case .merge: return "Maintains composite appearance, keeps all pieces separate: 1) Cut all shapes, 2) Group by color (no joining)"
        case .crop: return "Uses top shape to crop shapes beneath it"
        case .dieline: return "Divide shapes then convert to 1px black strokes"
        case .kick: return "Back shape cuts holes in front shape"
        case .separate: return "Separates compound paths into individual components (CoreGraphics)"
        case .combine: return "Combines all selected shapes into one, ignoring colors"
        }
    }
}

class ProfessionalPathOperations {

    static func union(_ paths: [CGPath]) -> CGPath? {
        return professionalUnion(paths)
    }

    static func minusFront(_ frontPath: CGPath, from backPath: CGPath) -> CGPath? {
        return professionalMinusFront(frontPath, from: backPath)
    }

    static func intersect(_ path1: CGPath, _ path2: CGPath) -> CGPath? {
        return professionalIntersect(path1, path2)
    }

    static func exclude(_ path1: CGPath, _ path2: CGPath) -> [CGPath] {
        return professionalExclude(path1, path2)
    }

    static func mosaic(_ paths: [CGPath]) -> [CGPath] {
        return ProfessionalPathOperations.professionalMosaic(paths)
    }

    static func cut(_ paths: [CGPath]) -> [CGPath] {
        return ProfessionalPathOperations.professionalCut(paths)
    }

    static func merge(_ paths: [CGPath]) -> [CGPath] {
        return professionalCut(paths)
    }

    static func crop(_ paths: [CGPath]) -> [CGPath] {
        return professionalCrop(paths)
    }

    static func dieline(_ paths: [CGPath]) -> [CGPath] {
        return professionalDieline(paths)
    }

    static func separate(_ paths: [CGPath]) -> [CGPath] {
        return ProfessionalPathOperations.professionalSeparate(paths)
    }

    static func kick(_ frontPath: CGPath, from backPath: CGPath) -> CGPath? {
        return professionalMinusFront(backPath, from: frontPath)
    }

    private static func pathToPolygon(_ path: CGPath) -> [[CGPoint]]? {
        var subpaths: [[CGPoint]] = []
        var currentSubpath: [CGPoint] = []
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                if !currentSubpath.isEmpty {
                    subpaths.append(currentSubpath)
                    currentSubpath = []
                }
                currentSubpath.append(element.pointee.points[0])
            case .addLineToPoint:
                currentSubpath.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                let start = currentSubpath.last ?? CGPoint.zero
                let control = element.pointee.points[0]
                let end = element.pointee.points[1]
                let segments = bezierToLineSegments(start: start, control: control, end: end)
                currentSubpath.append(contentsOf: segments)
            case .addCurveToPoint:
                let start = currentSubpath.last ?? CGPoint.zero
                let control1 = element.pointee.points[0]
                let control2 = element.pointee.points[1]
                let end = element.pointee.points[2]
                let segments = cubicBezierToLineSegments(start: start, control1: control1, control2: control2, end: end)
                currentSubpath.append(contentsOf: segments)
            case .closeSubpath:
                if !currentSubpath.isEmpty {
                    subpaths.append(currentSubpath)
                    currentSubpath = []
                }

            @unknown default:
                break
            }
        }
        if !currentSubpath.isEmpty {
            subpaths.append(currentSubpath)
        }
        return subpaths.isEmpty ? nil : subpaths
    }

    private static func polygonToPath(_ polygons: [[CGPoint]]) -> CGPath? {
        guard !polygons.isEmpty else { return nil }
        let path = CGMutablePath()
        for polygon in polygons {
            guard !polygon.isEmpty else { continue }
            path.move(to: polygon[0])
            for i in 1..<polygon.count {
                path.addLine(to: polygon[i])
            }
            path.closeSubpath()
        }
        return path
    }

    private static func unionPolygons(_ polygon1: [[CGPoint]], _ polygon2: [[CGPoint]]) -> [[CGPoint]] {
        return sutherland_hodgman_union(polygon1, polygon2)
    }

    private static func differencePolygons(_ polygon1: [[CGPoint]], _ polygon2: [[CGPoint]]) -> [[CGPoint]] {
        return sutherland_hodgman_difference(polygon1, polygon2)
    }

    private static func intersectPolygons(_ polygon1: [[CGPoint]], _ polygon2: [[CGPoint]]) -> [[CGPoint]] {
        return sutherland_hodgman_intersection(polygon1, polygon2)
    }

    private static func xorPolygons(_ polygon1: [[CGPoint]], _ polygon2: [[CGPoint]]) -> [[CGPoint]] {
        let union = unionPolygons(polygon1, polygon2)
        let intersection = intersectPolygons(polygon1, polygon2)
        return differencePolygons(union, intersection)
    }

    private static func sutherland_hodgman_union(_ poly1: [[CGPoint]], _ poly2: [[CGPoint]]) -> [[CGPoint]] {
        guard let first1 = poly1.first, let first2 = poly2.first else { return poly1 + poly2 }
        let bounds1 = getBounds(first1)
        let bounds2 = getBounds(first2)
        if bounds1.intersects(bounds2) {
            let combined = first1 + first2
            return [convexHull(combined)]
        } else {
            return poly1 + poly2
        }
    }

    private static func sutherland_hodgman_difference(_ poly1: [[CGPoint]], _ poly2: [[CGPoint]]) -> [[CGPoint]] {
        guard let first1 = poly1.first, let first2 = poly2.first else { return poly1 }
        let bounds1 = getBounds(first1)
        let bounds2 = getBounds(first2)
        if !bounds1.intersects(bounds2) {
            return poly1
        }
        let area1 = polygonArea(first1)
        let area2 = polygonArea(first2)
        if area2 >= area1 {
            return []
        } else {
            return poly1
        }
    }

    private static func sutherland_hodgman_intersection(_ poly1: [[CGPoint]], _ poly2: [[CGPoint]]) -> [[CGPoint]] {
        guard let first1 = poly1.first, let first2 = poly2.first else { return [] }
        let bounds1 = getBounds(first1)
        let bounds2 = getBounds(first2)
        let intersection = bounds1.intersection(bounds2)
        if intersection.isEmpty {
            return []
        }
        return [[
            CGPoint(x: intersection.minX, y: intersection.minY),
            CGPoint(x: intersection.maxX, y: intersection.minY),
            CGPoint(x: intersection.maxX, y: intersection.maxY),
            CGPoint(x: intersection.minX, y: intersection.maxY)
        ]]
    }

    private static func bezierToLineSegments(start: CGPoint, control: CGPoint, end: CGPoint, segments: Int = 10) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = quadraticBezierPoint(t: t, start: start, control: control, end: end)
            points.append(point)
        }
        return points
    }

    private static func cubicBezierToLineSegments(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, segments: Int = 15) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let point = cubicBezierPoint(t: t, start: start, control1: control1, control2: control2, end: end)
            points.append(point)
        }
        return points
    }

    private static func quadraticBezierPoint(t: CGFloat, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let x = (1-t)*(1-t)*start.x + 2*(1-t)*t*control.x + t*t*end.x
        let y = (1-t)*(1-t)*start.y + 2*(1-t)*t*control.y + t*t*end.y
        return CGPoint(x: x, y: y)
    }

    private static func cubicBezierPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let x = (1-t)*(1-t)*(1-t)*start.x + 3*(1-t)*(1-t)*t*control1.x + 3*(1-t)*t*t*control2.x + t*t*t*end.x
        let y = (1-t)*(1-t)*(1-t)*start.y + 3*(1-t)*(1-t)*t*control1.y + 3*(1-t)*t*t*control2.y + t*t*t*end.y
        return CGPoint(x: x, y: y)
    }

    private static func getBounds(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func polygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        return abs(area) / 2.0
    }

    private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let sortedPoints = points.sorted { point1, point2 in
            if point1.x == point2.x {
                return point1.y < point2.y
            }
            return point1.x < point2.x
        }
        var lower: [CGPoint] = []
        for point in sortedPoints {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sortedPoints.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func cross(_ O: CGPoint, _ A: CGPoint, _ B: CGPoint) -> CGFloat {
        return (A.x - O.x) * (B.y - O.y) - (A.y - O.y) * (B.x - O.x)
    }

    static func canPerformOperation(_ operation: PathfinderOperation, on paths: [CGPath]) -> Bool {
        switch operation {
        case .mosaic, .cut, .merge, .crop:
            return paths.count >= 2
        case .union:
            return paths.count == 2
        case .minusFront, .intersect, .exclude, .kick:
            return paths.count == 2
        case .dieline:
            return paths.count >= 1
        case .separate:
            return !paths.isEmpty
        case .combine:
            return paths.count >= 2
        }
    }

    static func isValidPath(_ path: CGPath) -> Bool {
        guard !path.isEmpty else { return false }
        let bounds = path.boundingBoxOfPath
        return !bounds.isEmpty && bounds.width > 0 && bounds.height > 0
    }

    static func pathToSVGString(_ path: CGPath) -> String {
        var pathString = ""
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                let point = element.pointee.points[0]
                pathString += "M \(point.x) \(point.y) "
            case .addLineToPoint:
                let point = element.pointee.points[0]
                pathString += "L \(point.x) \(point.y) "
            case .addQuadCurveToPoint:
                let control = element.pointee.points[0]
                let point = element.pointee.points[1]
                pathString += "Q \(control.x) \(control.y) \(point.x) \(point.y) "
            case .addCurveToPoint:
                let control1 = element.pointee.points[0]
                let control2 = element.pointee.points[1]
                let point = element.pointee.points[2]
                pathString += "C \(control1.x) \(control1.y) \(control2.x) \(control2.y) \(point.x) \(point.y) "
            case .closeSubpath:
                pathString += "Z "

            @unknown default:
                break
            }
        }
        return pathString.trimmingCharacters(in: .whitespaces)
    }
}

class PathOperations {

    static func unite(_ paths: [CGPath]) -> CGPath? {
        return ProfessionalPathOperations.professionalUnion(paths)
    }

    static func union(_ paths: [CGPath]) -> CGPath? {
        return ProfessionalPathOperations.professionalUnion(paths)
    }

    static func intersect(_ path1: CGPath, _ path2: CGPath) -> CGPath? {
        return ProfessionalPathOperations.professionalIntersect(path1, path2)
    }

    static func minusFront(_ frontPath: CGPath, from backPath: CGPath) -> CGPath? {
        return ProfessionalPathOperations.professionalMinusFront(frontPath, from: backPath)
    }

    static func subtract(_ frontPath: CGPath, from backPath: CGPath) -> CGPath? {
        return minusFront(frontPath, from: backPath)
    }

    static func exclude(_ path1: CGPath, _ path2: CGPath) -> [CGPath] {
        return ProfessionalPathOperations.professionalExclude(path1, path2)
    }

    static func split(_ paths: [CGPath]) -> [CGPath] {
        return ProfessionalPathOperations.mosaic(paths)
    }

    static func cut(_ paths: [CGPath]) -> [CGPath] {
        return ProfessionalPathOperations.cut(paths)
    }

    static func crop(_ paths: [CGPath]) -> [CGPath] {
        return ProfessionalPathOperations.crop(paths)
    }

    static func canPerformOperation(_ operation: PathOperation, on paths: [CGPath]) -> Bool {
        switch operation {
        case .union: return ProfessionalPathOperations.canPerformOperation(.union, on: paths)
        case .intersect: return ProfessionalPathOperations.canPerformOperation(.intersect, on: paths)
        case .frontMinusBack: return ProfessionalPathOperations.canPerformOperation(.minusFront, on: paths)
        case .backMinusFront: return ProfessionalPathOperations.canPerformOperation(.kick, on: paths)
        case .exclude: return ProfessionalPathOperations.canPerformOperation(.exclude, on: paths)
        }
    }

    static func isValidPath(_ path: CGPath) -> Bool {
        return ProfessionalPathOperations.isValidPath(path)
    }

    static func pathToSVGString(_ path: CGPath) -> String {
        return ProfessionalPathOperations.pathToSVGString(path)
    }

	private static func pathHasClosedSubpath(_ path: CGPath) -> Bool {
		var hasClosed = false
		path.applyWithBlock { element in
			if element.pointee.type == .closeSubpath { hasClosed = true }
		}
		return hasClosed
	}

    static func outlineStroke(path: CGPath, strokeStyle: StrokeStyle) -> CGPath? {
		let bounds = path.boundingBoxOfPath
		let hasClosed = pathHasClosedSubpath(path)
		let placement = strokeStyle.placement
		let shouldMaskPlacement = hasClosed && placement != .center
		let effectiveWidth: CGFloat = shouldMaskPlacement ? CGFloat(strokeStyle.width) * 2.0 : CGFloat(strokeStyle.width)
		let expandedBounds = bounds.insetBy(dx: -effectiveWidth * 2, dy: -effectiveWidth * 2)
		guard !expandedBounds.isEmpty && expandedBounds.width > 0 && expandedBounds.height > 0 else { return nil }
		let effectiveStrokeStyle = StrokeStyle(
			color: strokeStyle.color,
			width: Double(effectiveWidth),
			placement: .center,
			dashPattern: strokeStyle.dashPattern,
			lineCap: strokeStyle.lineCap.cgLineCap,
			lineJoin: strokeStyle.lineJoin.cgLineJoin,
			miterLimit: strokeStyle.miterLimit,
			opacity: strokeStyle.opacity,
			blendMode: strokeStyle.blendMode
		)
		let outlinedPath: CGPath?
		if effectiveStrokeStyle.dashPattern.isEmpty {
			outlinedPath = path.copy(
				strokingWithWidth: CGFloat(effectiveStrokeStyle.width),
				lineCap: effectiveStrokeStyle.lineCap.cgLineCap,
				lineJoin: effectiveStrokeStyle.lineJoin.cgLineJoin,
				miterLimit: CGFloat(effectiveStrokeStyle.miterLimit)
			)
		} else {
			outlinedPath = outlineStrokeWithDashPattern(path: path, strokeStyle: effectiveStrokeStyle)
		}
		guard let outlined = outlinedPath else { return nil }
		let unifiedStroke = CoreGraphicsPathOperations.union(outlined, outlined, using: .winding) ?? outlined
		guard shouldMaskPlacement else { return unifiedStroke }
		switch placement {
		case .inside:
			if let insideOnly = CoreGraphicsPathOperations.intersection(unifiedStroke, path, using: .winding) {
				return insideOnly
			} else {
				return unifiedStroke
			}
		case .outside:
			if let outsideOnly = CoreGraphicsPathOperations.subtract(path, from: unifiedStroke, using: .winding) {
				return outsideOnly
			} else {
				return unifiedStroke
			}
		case .center:
			return unifiedStroke
		}
    }

    private static func outlineStrokeWithDashPattern(path: CGPath, strokeStyle: StrokeStyle) -> CGPath? {
        let bounds = path.boundingBoxOfPath
        let expandedBounds = bounds.insetBy(dx: -strokeStyle.width * 2, dy: -strokeStyle.width * 2)
        guard !expandedBounds.isEmpty else { return nil }
        let scale: CGFloat = 2.0
        let contextSize = CGSize(
            width: expandedBounds.width * scale,
            height: expandedBounds.height * scale
        )
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                data: nil,
                width: Int(contextSize.width),
                height: Int(contextSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -expandedBounds.minX, y: -expandedBounds.minY)
        context.setLineWidth(strokeStyle.width)
        context.setLineCap(strokeStyle.lineCap.cgLineCap)
        context.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
        context.setMiterLimit(strokeStyle.miterLimit)
        let cgFloatPattern = strokeStyle.dashPattern.map { CGFloat($0) }
        context.setLineDash(phase: 0, lengths: cgFloatPattern)
        context.addPath(path)
        context.replacePathWithStrokedPath()
        return context.path
    }

    static func canOutlineStroke(path: CGPath, strokeStyle: StrokeStyle) -> Bool {
        guard !path.isEmpty else { return false }
        guard strokeStyle.width > 0 else { return false }
        let bounds = path.boundingBoxOfPath
        return !bounds.isEmpty && bounds.width > 0 && bounds.height > 0
    }

    static func hitTest(_ path: CGPath, point: CGPoint, tolerance: CGFloat = 5.0) -> Bool {
        guard !point.x.isNaN && !point.y.isNaN && !point.x.isInfinite && !point.y.isInfinite else {
            return false
        }
        guard tolerance > 0 && !tolerance.isNaN && !tolerance.isInfinite else {
            return false
        }
        guard !path.isEmpty else { return false }
        let bounds = path.boundingBoxOfPath.insetBy(dx: -tolerance, dy: -tolerance)
        guard bounds.contains(point) else { return false }
        if path.contains(point) {
            return true
        }
        return MetalComputeEngine.shared.pathHitTestGPU(path, point: point, tolerance: tolerance)
    }

    private static func isPointNearStroke(_ path: CGPath, point: CGPoint, tolerance: CGFloat) -> Bool {
        guard !point.x.isNaN && !point.y.isNaN && !point.x.isInfinite && !point.y.isInfinite else {
            return false
        }
        guard tolerance > 0 && !tolerance.isNaN && !tolerance.isInfinite else {
            return false
        }
        var isNear = false
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                let pathPoint = element.pointee.points[0]
                guard !pathPoint.x.isNaN && !pathPoint.y.isNaN && !pathPoint.x.isInfinite && !pathPoint.y.isInfinite else {
                    return
                }
                let distance = point.distance(to: pathPoint)
                if distance <= tolerance {
                    isNear = true
                }
            case .addQuadCurveToPoint, .addCurveToPoint:
                let pathPoint = element.pointee.points[element.pointee.type == .addQuadCurveToPoint ? 1 : 2]
                guard !pathPoint.x.isNaN && !pathPoint.y.isNaN && !pathPoint.x.isInfinite && !pathPoint.y.isInfinite else {
                    return
                }
                let distance = point.distance(to: pathPoint)
                if distance <= tolerance {
                    isNear = true
                }
            case .closeSubpath:
                break

            @unknown default:
                break
            }
        }
        return isNear
    }
}

extension ProfessionalPathOperations {

    static func mergeAdjacentCoincidentPoints(in path: VectorPath, tolerance: Double = 1.1) -> VectorPath {
        guard path.elements.count > 2 else {
            return path
        }
        var firstPointIndex: Int? = nil
        var lastPointIndex: Int? = nil
        for (index, element) in path.elements.enumerated() {
            switch element {
            case .line, .curve, .quadCurve:
                if firstPointIndex == nil {
                    firstPointIndex = index
                }
                lastPointIndex = index
            default:
                break
            }
        }
        var pointData: [(index: Int, position: VectorPoint, element: PathElement)] = []
        for (index, element) in path.elements.enumerated() {
            let position: VectorPoint?
            switch element {
            case .move(let to), .line(let to):
                position = to
            case .curve(let to, _, _), .quadCurve(let to, _):
                position = to
            case .close:
                position = nil
            }
            if let pos = position {
                pointData.append((index, pos, element))
            }
        }
        var currentPointData = pointData
        var indicesToRemove: Set<Int> = []
        var changed = true
        while changed {
            changed = false
            for i in 0..<(currentPointData.count - 1) {
                let currentData = currentPointData[i]
                let nextData = currentPointData[i + 1]
                if nextData.index == currentData.index + 1 {
                    let distance = currentData.position.distance(to: nextData.position)
                    if distance <= tolerance {
                        let actualElementIndex = nextData.index
                        let isFirstOrLast = (actualElementIndex == firstPointIndex || actualElementIndex == lastPointIndex)
                        if !isFirstOrLast {
                            indicesToRemove.insert(actualElementIndex)
                            Log.info("  Removing adjacent coincident point at index \(actualElementIndex)", category: .general)
                            currentPointData.remove(at: i + 1)
                            changed = true
                            break
                        }
                    }
                }
            }
        }
        var cleanedElements: [PathElement] = []
        for (index, element) in path.elements.enumerated() {
            if !indicesToRemove.contains(index) {
                cleanedElements.append(element)
            }
        }
        if cleanedElements.isEmpty {
            return path
        }
        return VectorPath(elements: cleanedElements, isClosed: path.isClosed)
    }

    static func mergeDuplicatePoints(in path: VectorPath, tolerance: Double = 5.0) -> VectorPath {
        guard path.elements.count > 2 else {
            return path
        }
        var firstPoint: VectorPoint?
        if case .move(let to) = path.elements.first {
            firstPoint = to
        }
        var elementsToSkip: Set<Int> = []
        var duplicatesRemoved = 0
        if let first = firstPoint {
            for (index, element) in path.elements.enumerated() {
                if index == 0 { continue }
                var endpoint: VectorPoint?
                switch element {
                case .line(let to):
                    endpoint = to
                case .curve(let to, _, _):
                    endpoint = to
                case .quadCurve(let to, _):
                    endpoint = to
                case .move(_), .close:
                    continue
                }
                if let end = endpoint {
                    let distance = first.distance(to: end)
                    if distance <= tolerance {
                        elementsToSkip.insert(index)
                        duplicatesRemoved += 1
                    }
                }
            }
        }
        var cleanedElements: [PathElement] = []
        for (index, element) in path.elements.enumerated() {
            if elementsToSkip.contains(index) {
            } else {
                cleanedElements.append(element)
            }
        }
        if cleanedElements.isEmpty {
            return path
        }
        if case .move = cleanedElements.first {
        } else {
            return path
        }
        let cleanedPath = VectorPath(elements: cleanedElements, isClosed: path.isClosed)
        return cleanedPath
    }

    static func mergeDuplicatePoints(in shape: VectorShape, tolerance: Double = 1.0) -> VectorShape {
        let cleanedPath = mergeDuplicatePoints(in: shape.path, tolerance: tolerance)

        var cleanedShape = shape
        cleanedShape.path = cleanedPath
        cleanedShape.updateBounds()
        return cleanedShape
    }
}

extension ProfessionalPathOperations {

    static func cleanupDocumentDuplicates(_ document: VectorDocument, tolerance: Double = 5.0) {
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        for layerIndex in document.snapshot.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            for shapeIndex in shapes.indices {
                guard let originalShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                let cleanedShape = mergeDuplicatePoints(in: originalShape, tolerance: tolerance)
                if cleanedShape.path.elements.count != originalShape.path.elements.count {
                    oldShapes[originalShape.id] = originalShape
                    newShapes[cleanedShape.id] = cleanedShape
                    objectIDs.append(originalShape.id)
                }
            }
        }
        if !oldShapes.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: objectIDs,
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            document.commandManager.execute(command)
        }
    }

    static func cleanupSelectedShapesDuplicates(_ document: VectorDocument, tolerance: Double = 5.0) {
        guard !document.viewState.selectedObjectIDs.isEmpty else {
            return
        }
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        for layerIndex in document.snapshot.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            for shapeIndex in shapes.indices {
                guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                if document.viewState.selectedObjectIDs.contains(shape.id) {
                    let originalShape = shape
                    let cleanedShape = mergeDuplicatePoints(in: originalShape, tolerance: tolerance)
                    if cleanedShape.path.elements.count != originalShape.path.elements.count {
                        oldShapes[originalShape.id] = originalShape
                        newShapes[cleanedShape.id] = cleanedShape
                        objectIDs.append(originalShape.id)
                    }
                }
            }
        }
        if !oldShapes.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: objectIDs,
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            document.commandManager.execute(command)
        }
    }
}
