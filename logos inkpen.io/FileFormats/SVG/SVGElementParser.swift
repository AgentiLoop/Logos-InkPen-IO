import SwiftUI

extension SVGParser {

    func parseRectangle(attributes: [String: String]) {
        let x = parseLength(attributes["x"]) ?? 0
        let y = parseLength(attributes["y"]) ?? 0
        let width = parseLength(attributes["width"]) ?? 0
        let height = parseLength(attributes["height"]) ?? 0
        let rx = parseLength(attributes["rx"]) ?? 0
        let ry = parseLength(attributes["ry"]) ?? 0
        let fill = attributes["fill"] ?? ""
        let opacity = parseLength(attributes["opacity"]) ?? 1.0
        if (fill == "none" || fill.isEmpty) && opacity == 0 && width > 0 && height > 0 {
            let rect = CGRect(x: x, y: y, width: width, height: height)
            if let groupId = currentGroupId {
                textBoxBounds[groupId] = rect
            }
            pendingTextBoxRect = rect
            return
        }
        let elements: [PathElement]
        if rx > 0 || ry > 0 {
            let radiusX = rx
            let radiusY = ry == 0 ? rx : ry
            elements = [
                .move(to: VectorPoint(x + radiusX, y)),
                .line(to: VectorPoint(x + width - radiusX, y)),
                .curve(to: VectorPoint(x + width, y + radiusY),
                       control1: VectorPoint(x + width, y),
                       control2: VectorPoint(x + width, y + radiusY)),
                .line(to: VectorPoint(x + width, y + height - radiusY)),
                .curve(to: VectorPoint(x + width - radiusX, y + height),
                       control1: VectorPoint(x + width, y + height),
                       control2: VectorPoint(x + width - radiusX, y + height)),
                .line(to: VectorPoint(x + radiusX, y + height)),
                .curve(to: VectorPoint(x, y + height - radiusY),
                       control1: VectorPoint(x, y + height),
                       control2: VectorPoint(x, y + height - radiusY)),
                .line(to: VectorPoint(x, y + radiusY)),
                .curve(to: VectorPoint(x + radiusX, y),
                       control1: VectorPoint(x, y),
                       control2: VectorPoint(x + radiusX, y)),
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
        let vectorPath = VectorPath(elements: elements, isClosed: true)
        let (shouldClip, clipPathId) = checkForClipPath(attributes)
        let shape = createShape(
            name: "Rectangle",
            path: vectorPath,
            attributes: attributes,
            geometricType: rx > 0 || ry > 0 ? .roundedRectangle : .rectangle
        )
        if shouldClip, let clipId = clipPathId {
            applyClipPathToShape(shape, clipPathId: clipId)
        } else {
            shapes.append(shape)
        }
    }

    func parseCircle(attributes: [String: String]) {
        let cx = parseLength(attributes["cx"]) ?? 0
        let cy = parseLength(attributes["cy"]) ?? 0
        let r = parseLength(attributes["r"]) ?? 0
        let center = CGPoint(x: cx, y: cy)
        let shape = VectorShape.circle(center: center, radius: r)
        let (shouldClip, clipPathId) = checkForClipPath(attributes)
        let finalShape = createShape(
            name: "Circle",
            path: shape.path,
            attributes: attributes,
            geometricType: .circle
        )
        if shouldClip, let clipId = clipPathId {
            applyClipPathToShape(finalShape, clipPathId: clipId)
        } else {
            shapes.append(finalShape)
        }
    }

    func parseEllipse(attributes: [String: String]) {
        let cx = parseLength(attributes["cx"]) ?? 0
        let cy = parseLength(attributes["cy"]) ?? 0
        let rx = parseLength(attributes["rx"]) ?? 0
        let ry = parseLength(attributes["ry"]) ?? 0
        let elements: [PathElement] = [
            .move(to: VectorPoint(cx + rx, cy)),
            .curve(to: VectorPoint(cx, cy + ry),
                   control1: VectorPoint(cx + rx, cy + ry * 0.552),
                   control2: VectorPoint(cx + rx * 0.552, cy + ry)),
            .curve(to: VectorPoint(cx - rx, cy),
                   control1: VectorPoint(cx - rx * 0.552, cy + ry),
                   control2: VectorPoint(cx - rx, cy + ry * 0.552)),
            .curve(to: VectorPoint(cx, cy - ry),
                   control1: VectorPoint(cx - rx, cy - ry * 0.552),
                   control2: VectorPoint(cx - rx * 0.552, cy - ry)),
            .curve(to: VectorPoint(cx + rx, cy),
                   control1: VectorPoint(cx + rx * 0.552, cy - ry),
                   control2: VectorPoint(cx + rx, cy - ry * 0.552)),
            .close
        ]
        let vectorPath = VectorPath(elements: elements, isClosed: true)
        let (shouldClip, clipPathId) = checkForClipPath(attributes)
        let shape = createShape(
            name: "Ellipse",
            path: vectorPath,
            attributes: attributes,
            geometricType: .ellipse
        )
        if shouldClip, let clipId = clipPathId {
            applyClipPathToShape(shape, clipPathId: clipId)
        } else {
            shapes.append(shape)
        }
    }

    func parseLine(attributes: [String: String]) {
        let x1 = parseLength(attributes["x1"]) ?? 0
        let y1 = parseLength(attributes["y1"]) ?? 0
        let x2 = parseLength(attributes["x2"]) ?? 0
        let y2 = parseLength(attributes["y2"]) ?? 0
        let elements: [PathElement] = [
            .move(to: VectorPoint(x1, y1)),
            .line(to: VectorPoint(x2, y2))
        ]
        let vectorPath = VectorPath(elements: elements, isClosed: false)
        let shape = createShape(
            name: "Line",
            path: vectorPath,
            attributes: attributes,
            geometricType: .line
        )
        shapes.append(shape)
    }

    func parsePolyline(attributes: [String: String], closed: Bool) {
        guard let pointsString = attributes["points"] else { return }
        let points = parsePoints(pointsString)
        guard !points.isEmpty else { return }
        var elements: [PathElement] = [.move(to: VectorPoint(points[0]))]
        for i in 1..<points.count {
            elements.append(.line(to: VectorPoint(points[i])))
        }
        if closed {
            elements.append(.close)
        }
        let vectorPath = VectorPath(elements: elements, isClosed: closed)
        let shape = createShape(
            name: closed ? "Polygon" : "Polyline",
            path: vectorPath,
            attributes: attributes,
            geometricType: closed ? .polygon : nil
        )
        shapes.append(shape)
    }
}
