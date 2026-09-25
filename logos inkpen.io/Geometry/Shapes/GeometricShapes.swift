import CoreGraphics
import simd

class GeometricShapes {

    static func createRectangle(origin: CGPoint, size: CGSize, cornerRadius: CGFloat = 0) -> VectorPath {
        let rect = CGRect(origin: origin, size: size)

        var elements: [PathElement] = []
        if cornerRadius > 0 {
            let radius = min(cornerRadius, min(size.width, size.height) / 2)
            elements.append(.move(to: VectorPoint(rect.minX + radius, rect.minY)))
            elements.append(.line(to: VectorPoint(rect.maxX - radius, rect.minY)))
            elements.append(.curve(to: VectorPoint(rect.maxX, rect.minY + radius),
                                 control1: VectorPoint(rect.maxX - radius * 0.552, rect.minY),
                                 control2: VectorPoint(rect.maxX, rect.minY + radius * 0.552)))
            elements.append(.line(to: VectorPoint(rect.maxX, rect.maxY - radius)))
            elements.append(.curve(to: VectorPoint(rect.maxX - radius, rect.maxY),
                                 control1: VectorPoint(rect.maxX, rect.maxY - radius * 0.552),
                                 control2: VectorPoint(rect.maxX - radius * 0.552, rect.maxY)))
            elements.append(.line(to: VectorPoint(rect.minX + radius, rect.maxY)))
            elements.append(.curve(to: VectorPoint(rect.minX, rect.maxY - radius),
                                 control1: VectorPoint(rect.minX + radius * 0.552, rect.maxY),
                                 control2: VectorPoint(rect.minX, rect.maxY - radius * 0.552)))
            elements.append(.line(to: VectorPoint(rect.minX, rect.minY + radius)))
            elements.append(.curve(to: VectorPoint(rect.minX + radius, rect.minY),
                                 control1: VectorPoint(rect.minX, rect.minY + radius * 0.552),
                                 control2: VectorPoint(rect.minX + radius * 0.552, rect.minY)))
            elements.append(.close)
        } else {
            elements.append(.move(to: VectorPoint(rect.minX, rect.minY)))
            elements.append(.line(to: VectorPoint(rect.maxX, rect.minY)))
            elements.append(.line(to: VectorPoint(rect.maxX, rect.maxY)))
            elements.append(.line(to: VectorPoint(rect.minX, rect.maxY)))
            elements.append(.close)
        }
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createRoundedRectPathWithIndividualCorners(rect: CGRect, cornerRadii: [Double]) -> VectorPath {
        guard cornerRadii.count == 4 else {
            return createRectangle(origin: rect.origin, size: rect.size, cornerRadius: 0)
        }
        let topLeftRadius = min(cornerRadii[0], min(rect.width, rect.height) / 2)
        let topRightRadius = min(cornerRadii[1], min(rect.width, rect.height) / 2)
        let bottomRightRadius = min(cornerRadii[2], min(rect.width, rect.height) / 2)
        let bottomLeftRadius = min(cornerRadii[3], min(rect.width, rect.height) / 2)
        let topLeftOffset = topLeftRadius * 0.552
        let topRightOffset = topRightRadius * 0.552
        let bottomRightOffset = bottomRightRadius * 0.552
        let bottomLeftOffset = bottomLeftRadius * 0.552
        return VectorPath(elements: [
            .move(to: VectorPoint(rect.minX + topLeftRadius, rect.minY)),
            .line(to: VectorPoint(rect.maxX - topRightRadius, rect.minY)),
            .curve(to: VectorPoint(rect.maxX, rect.minY + topRightRadius),
                   control1: VectorPoint(rect.maxX - topRightRadius + topRightOffset, rect.minY),
                   control2: VectorPoint(rect.maxX, rect.minY + topRightRadius - topRightOffset)),
            .line(to: VectorPoint(rect.maxX, rect.maxY - bottomRightRadius)),
            .curve(to: VectorPoint(rect.maxX - bottomRightRadius, rect.maxY),
                   control1: VectorPoint(rect.maxX, rect.maxY - bottomRightRadius + bottomRightOffset),
                   control2: VectorPoint(rect.maxX - bottomRightRadius + bottomRightOffset, rect.maxY)),
            .line(to: VectorPoint(rect.minX + bottomLeftRadius, rect.maxY)),
            .curve(to: VectorPoint(rect.minX, rect.maxY - bottomLeftRadius),
                   control1: VectorPoint(rect.minX + bottomLeftRadius - bottomLeftOffset, rect.maxY),
                   control2: VectorPoint(rect.minX, rect.maxY - bottomLeftRadius + bottomLeftOffset)),
            .line(to: VectorPoint(rect.minX, rect.minY + topLeftRadius)),
            .curve(to: VectorPoint(rect.minX + topLeftRadius, rect.minY),
                   control1: VectorPoint(rect.minX, rect.minY + topLeftRadius - topLeftOffset),
                   control2: VectorPoint(rect.minX + topLeftRadius - topLeftOffset, rect.minY)),
            .close
        ], isClosed: true)
    }

    static func createCircle(center: CGPoint, radius: CGFloat) -> VectorPath {
        let controlPointOffset = radius * 0.552
        let elements: [PathElement] = [
            .move(to: VectorPoint(center.x + radius, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + controlPointOffset),
                   control2: VectorPoint(center.x + controlPointOffset, center.y + radius)),
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - controlPointOffset, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + controlPointOffset)),
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - controlPointOffset),
                   control2: VectorPoint(center.x - controlPointOffset, center.y - radius)),
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + controlPointOffset, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - controlPointOffset)),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> VectorPath {
        let controlPointOffsetX = radiusX * 0.552
        let controlPointOffsetY = radiusY * 0.552
        let elements: [PathElement] = [
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createTriangle(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        let points = regularPolygonPoints(center: center, radius: radius, sides: 3, orientation: orientation)
        let elements: [PathElement] = [
            .move(to: VectorPoint(points[0])),
            .line(to: VectorPoint(points[1])),
            .line(to: VectorPoint(points[2])),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createRegularPolygon(center: CGPoint, radius: CGFloat, sides: Int, orientation: CGFloat = 0) -> VectorPath {
        let points = regularPolygonPoints(center: center, radius: radius, sides: sides, orientation: orientation)

        var elements: [PathElement] = [.move(to: VectorPoint(points[0]))]
        for i in 1..<points.count {
            elements.append(.line(to: VectorPoint(points[i])))
        }
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createStar(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int, orientation: CGFloat = 0) -> VectorPath {
        var elements: [PathElement] = []

        let angleStep = .pi / Double(points)
        let centerVec = SIMD2<Double>(Double(center.x), Double(center.y))
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep + Double(orientation) - .pi / 2
            let radius = i % 2 == 0 ? Double(outerRadius) : Double(innerRadius)
            let offset = SIMD2<Double>(cos(angle), sin(angle)) * radius
            let point = centerVec + offset
            if i == 0 {
                elements.append(.move(to: VectorPoint(point.x, point.y)))
            } else {
                elements.append(.line(to: VectorPoint(point.x, point.y)))
            }
        }
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createPentagon(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 5, orientation: orientation)
    }

    static func createHexagon(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 6, orientation: orientation)
    }

    static func createOctagon(center: CGPoint, radius: CGFloat, orientation: CGFloat = 0) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 8, orientation: orientation)
    }

    static func createDiamond(center: CGPoint, width: CGFloat, height: CGFloat) -> VectorPath {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let elements: [PathElement] = [
            .move(to: VectorPoint(center.x, center.y - halfHeight)),
            .line(to: VectorPoint(center.x + halfWidth, center.y)),
            .line(to: VectorPoint(center.x, center.y + halfHeight)),
            .line(to: VectorPoint(center.x - halfWidth, center.y)),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createHeart(center: CGPoint, size: CGFloat) -> VectorPath {
        let scale = size / 100.0

        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(center.x, center.y + 30 * scale)))
        elements.append(.curve(to: VectorPoint(center.x - 25 * scale, center.y - 10 * scale),
                             control1: VectorPoint(center.x - 15 * scale, center.y + 15 * scale),
                             control2: VectorPoint(center.x - 25 * scale, center.y + 5 * scale)))
        elements.append(.curve(to: VectorPoint(center.x - 10 * scale, center.y - 25 * scale),
                             control1: VectorPoint(center.x - 25 * scale, center.y - 25 * scale),
                             control2: VectorPoint(center.x - 20 * scale, center.y - 25 * scale)))
        elements.append(.curve(to: VectorPoint(center.x, center.y - 10 * scale),
                             control1: VectorPoint(center.x, center.y - 25 * scale),
                             control2: VectorPoint(center.x, center.y - 15 * scale)))
        elements.append(.curve(to: VectorPoint(center.x + 10 * scale, center.y - 25 * scale),
                             control1: VectorPoint(center.x, center.y - 15 * scale),
                             control2: VectorPoint(center.x, center.y - 25 * scale)))
        elements.append(.curve(to: VectorPoint(center.x + 25 * scale, center.y - 10 * scale),
                             control1: VectorPoint(center.x + 20 * scale, center.y - 25 * scale),
                             control2: VectorPoint(center.x + 25 * scale, center.y - 25 * scale)))
        elements.append(.curve(to: VectorPoint(center.x, center.y + 30 * scale),
                             control1: VectorPoint(center.x + 25 * scale, center.y + 5 * scale),
                             control2: VectorPoint(center.x + 15 * scale, center.y + 15 * scale)))
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createArrow(start: CGPoint, end: CGPoint, headLength: CGFloat = 20, headWidth: CGFloat = 10) -> VectorPath {
        let startVec = SIMD2<Double>(Double(start.x), Double(start.y))
        let endVec = SIMD2<Double>(Double(end.x), Double(end.y))
        let direction = endVec - startVec
        let length = simd_length(direction)
        if length == 0 { return VectorPath() }
        let unit = simd_normalize(direction)
        let perpendicular = SIMD2<Double>(-unit.y, unit.x)
        let headStartVec = endVec - unit * Double(headLength)
        let headStart = CGPoint(x: headStartVec.x, y: headStartVec.y)
        let headPoint1Vec = headStartVec - perpendicular * Double(headWidth)
        let headPoint1 = CGPoint(x: headPoint1Vec.x, y: headPoint1Vec.y)
        let headPoint2Vec = headStartVec + perpendicular * Double(headWidth)
        let headPoint2 = CGPoint(x: headPoint2Vec.x, y: headPoint2Vec.y)
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .line(to: VectorPoint(headStart)),
            .line(to: VectorPoint(headPoint1)),
            .line(to: VectorPoint(end)),
            .line(to: VectorPoint(headPoint2)),
            .line(to: VectorPoint(headStart)),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createStopSign(center: CGPoint, radius: CGFloat) -> VectorPath {
        return createRegularPolygon(center: center, radius: radius, sides: 8, orientation: .pi / 8)
    }

    static func createLine(start: CGPoint, end: CGPoint) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .line(to: VectorPoint(end))
        ]
        return VectorPath(elements: elements, isClosed: false)
    }

    static func createBezierCurve(start: CGPoint, end: CGPoint, control1: CGPoint, control2: CGPoint) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .curve(to: VectorPoint(end), control1: VectorPoint(control1), control2: VectorPoint(control2))
        ]
        return VectorPath(elements: elements, isClosed: false)
    }

    static func createQuadraticCurve(start: CGPoint, end: CGPoint, control: CGPoint) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(start)),
            .quadCurve(to: VectorPoint(end), control: VectorPoint(control))
        ]
        return VectorPath(elements: elements, isClosed: false)
    }

    private static func regularPolygonPoints(center: CGPoint, radius: CGFloat, sides: Int, orientation: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []

        let angleStep = 2 * .pi / Double(sides)
        let centerVec = SIMD2<Double>(Double(center.x), Double(center.y))
        for i in 0..<sides {
            let angle = Double(i) * angleStep + Double(orientation) - .pi / 2
            let offset = SIMD2<Double>(cos(angle), sin(angle)) * Double(radius)
            let point = centerVec + offset
            points.append(CGPoint(x: point.x, y: point.y))
        }
        return points
    }

    static func createCog(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, teeth: Int = 12) -> VectorPath {
        var elements: [PathElement] = []

        let angleStep = 2 * .pi / Double(teeth)
        let toothAngle = angleStep * 0.3
        let centerVec = SIMD2<Double>(Double(center.x), Double(center.y))
        let outerRad = Double(outerRadius)
        let innerRad = Double(innerRadius)
        for i in 0..<teeth {
            let baseAngle = Double(i) * angleStep
            let outerAngle1 = baseAngle - toothAngle / 2
            let outerAngle2 = baseAngle + toothAngle / 2
            let innerAngle1 = baseAngle - angleStep / 2
            let innerAngle2 = baseAngle + angleStep / 2
            let outerOffset1 = SIMD2<Double>(cos(outerAngle1), sin(outerAngle1)) * outerRad
            let outerPoint1 = centerVec + outerOffset1
            let outerOffset2 = SIMD2<Double>(cos(outerAngle2), sin(outerAngle2)) * outerRad
            let outerPoint2 = centerVec + outerOffset2
            let innerOffset1 = SIMD2<Double>(cos(innerAngle1), sin(innerAngle1)) * innerRad
            let innerPoint1 = centerVec + innerOffset1
            let innerOffset2 = SIMD2<Double>(cos(innerAngle2), sin(innerAngle2)) * innerRad
            let innerPoint2 = centerVec + innerOffset2
            if i == 0 {
                elements.append(.move(to: VectorPoint(outerPoint1.x, outerPoint1.y)))
            } else {
                elements.append(.line(to: VectorPoint(outerPoint1.x, outerPoint1.y)))
            }
            elements.append(.line(to: VectorPoint(outerPoint2.x, outerPoint2.y)))
            elements.append(.line(to: VectorPoint(innerPoint2.x, innerPoint2.y)))
            elements.append(.line(to: VectorPoint(innerPoint1.x, innerPoint1.y)))
        }
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }

    static func createSpiral(center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, turns: Double) -> VectorPath {
        var elements: [PathElement] = []

        let steps = Int(turns * 36)
        let centerVec = SIMD2<Double>(Double(center.x), Double(center.y))
        let startRad = Double(startRadius)
        let endRad = Double(endRadius)
        for i in 0..<steps {
            let t = Double(i) / Double(steps - 1)
            let angle = t * turns * 2 * .pi
            let radius = startRad + (endRad - startRad) * t
            let offset = SIMD2<Double>(cos(angle), sin(angle)) * radius
            let point = centerVec + offset
            if i == 0 {
                elements.append(.move(to: VectorPoint(point.x, point.y)))
            } else {
                elements.append(.line(to: VectorPoint(point.x, point.y)))
            }
        }
        return VectorPath(elements: elements, isClosed: false)
    }
}
