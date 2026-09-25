import CoreGraphics

enum PathShapeDetector {

    static func detect(elements: [PathElement]) -> (type: GeometricShapeType, name: String)? {
        var drawn: [PathElement] = []
        for el in elements {
            if case .close = el { continue }
            drawn.append(el)
        }
        guard drawn.count >= 2 else { return nil }
        guard case .move(let start) = drawn[0] else { return nil }
        let body = Array(drawn.dropFirst())
        let lineCount = body.filter { if case .line = $0 { return true }; return false }.count
        let curveCount = body.filter { if case .curve = $0 { return true }; return false }.count
        let allLines = lineCount == body.count && curveCount == 0
        let allCurves = curveCount == body.count && lineCount == 0
        if allLines {
            var points: [CGPoint] = [start.cgPoint]
            for el in body {
                if case .line(let to) = el {
                    points.append(to.cgPoint)
                }
            }
            if body.count == 2 {
                return (.triangle, "Triangle")
            }
            if body.count == 3, approxEqual(points[0], points[3]) {
                return (.triangle, "Triangle")
            }
            let rectPoints: [CGPoint]
            let isRect: Bool
            if body.count == 3 {
                rectPoints = points + [points[0]]
                isRect = true
            } else if body.count == 4, points.count == 5, approxEqual(points[0], points[4]) {
                rectPoints = points
                isRect = true
            } else {
                rectPoints = []
                isRect = false
            }
            if isRect && rectPoints.count == 5 {
                let isAxisAligned = (0..<4).allSatisfy { i in
                    let a = rectPoints[i]
                    let b = rectPoints[i + 1]
                    return approxEqual(a.x, b.x) || approxEqual(a.y, b.y)
                }
                if isAxisAligned {
                    let minX = rectPoints.map { $0.x }.min() ?? 0
                    let maxX = rectPoints.map { $0.x }.max() ?? 0
                    let minY = rectPoints.map { $0.y }.min() ?? 0
                    let maxY = rectPoints.map { $0.y }.max() ?? 0
                    let w = maxX - minX
                    let h = maxY - minY
                    if w > 0 && h > 0 {
                        let ratio = w / h
                        if approxEqual(ratio, 1.0, tolerance: 0.02) {
                            return (.square, "Square")
                        }
                        return (.rectangle, "Rectangle")
                    }
                }
            }
            if body.count >= 5 && body.count <= 8 {
                let closed = approxEqual(points.first ?? .zero, points.last ?? .zero)
                if closed {
                    switch body.count {
                    case 5: return (.pentagon, "Pentagon")
                    case 6: return (.hexagon, "Hexagon")
                    case 7: return (.heptagon, "Heptagon")
                    case 8: return (.octagon, "Octagon")
                    default: break
                    }
                }
            }
        }
        if allCurves && body.count == 4 {
            var pts: [CGPoint] = [start.cgPoint]
            for el in body {
                if case .curve(let to, _, _) = el {
                    pts.append(to.cgPoint)
                }
            }
            guard pts.count == 5 else { return nil }
            guard approxEqual(pts[0], pts[4]) else { return nil }
            let xs = pts.dropLast().map { $0.x }
            let ys = pts.dropLast().map { $0.y }
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { return nil }
            let w = maxX - minX
            let h = maxY - minY
            guard w > 0 && h > 0 else { return nil }
            let cx = (minX + maxX) / 2
            let cy = (minY + maxY) / 2
            let tol = max(w, h) * 0.03
            let expected: [CGPoint] = [
                CGPoint(x: cx, y: minY),
                CGPoint(x: maxX, y: cy),
                CGPoint(x: cx, y: maxY),
                CGPoint(x: minX, y: cy)
            ]
            let actual = Array(pts.dropLast())
            let allMatched = expected.allSatisfy { target in
                actual.contains(where: { approxEqual($0, target, tolerance: tol) })
            }
            if !allMatched { return nil }
            let ratio = w / h
            if approxEqual(ratio, 1.0, tolerance: 0.02) {
                return (.circle, "Circle")
            }
            return (.ellipse, "Ellipse")
        }
        return nil
    }

    private static func approxEqual(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 0.5) -> Bool {
        return abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
    }

    private static func approxEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.5) -> Bool {
        return abs(a - b) <= tolerance
    }
}
