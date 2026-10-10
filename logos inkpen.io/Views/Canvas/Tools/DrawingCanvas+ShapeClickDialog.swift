import SwiftUI
import AppKit

private var lastShapeDialogClose = Date.distantPast

extension DrawingCanvas {

    /// Illustrator: clicking (without dragging) with a shape tool opens a dialog to type the exact size.
    /// Box shapes put their top-left corner at the click; polygons and stars use the click as the centre.
    internal func showShapeSizeDialog(at canvasPoint: CGPoint) {
        let tool = document.viewState.currentTool
        let boxTools: [DrawingTool] = [.rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval]
        let radialTools: [DrawingTool] = [.polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .star]
        // Egg and the triangles are box-style (top-left at the click); the line starts at the click.
        let extraBoxTools: [DrawingTool] = [.egg, .cone, .isoscelesTriangle, .acuteTriangle, .rightTriangle, .equilateralTriangle]
        let isBox = boxTools.contains(tool) || extraBoxTools.contains(tool)
        let isLine = tool == .line
        guard isBox || isLine || radialTools.contains(tool) else { return }
        // Guard against a duplicate tap callback firing a second dialog right after the first closes.
        guard Date().timeIntervalSince(lastShapeDialogClose) > 0.5 else { return }
        defer { lastShapeDialogClose = Date() }
        let isSquareLike = tool == .square || tool == .circle

        let alert = NSAlert()
        alert.messageText = tool.rawValue.capitalized
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        // Lengths are shown and typed in the document's units (Illustrator); the canvas stores points.
        let unit = document.settings.unit
        func makeField(_ value: Double) -> NSTextField {
            let field = NSTextField(string: String(format: "%g", (value * 10000).rounded() / 10000))
            field.frame = NSRect(x: 80, y: 0, width: 100, height: 22)
            return field
        }
        func makeLabel(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 0, y: 0, width: 80, height: 20)
            return label
        }

        var rows: [(String, Double)] = isLine
            ? [("Length:", 100), ("Angle:", 0)]
            : isBox
                ? (isSquareLike ? [(tool == .circle ? "Diameter:" : "Size:", 100)]
                   : tool == .equilateralTriangle ? [("Height:", 100)]
                   : [("Width:", 100), ("Height:", 100)])
                : [("Radius:", 50)]
        if tool == .roundedRectangle { rows.append(("Corner Radius:", document.viewState.roundedRectCornerRadius)) }
        // The line's angle (row 1) is the only value that isn't a length.
        let isLength: (Int) -> Bool = { index in !(isLine && index == 1) }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 236, height: CGFloat(rows.count) * 28))
        var fields: [NSTextField] = []
        for (index, row) in rows.enumerated() {
            let y = CGFloat(rows.count - 1 - index) * 28
            let lengthRow = isLength(index)
            let label = makeLabel(lengthRow ? "\(row.0.dropLast()) (\(unit.abbreviation)):" : row.0)
            label.frame = NSRect(x: 0, y: y + 2, width: 124, height: 20)
            let field = makeField(lengthRow ? unit.fromPoints(row.1) : row.1)
            field.frame.origin.x = 128
            field.frame.origin.y = y
            container.addSubview(label)
            container.addSubview(field)
            fields.append(field)
        }
        alert.accessoryView = container
        alert.window.initialFirstResponder = fields.first

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let values = fields.enumerated().map { index, field -> Double in
            let typed = abs(Double(field.stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0)
            if !isLength(index) { return typed }
            // Untouched defaults keep their exact point value instead of a rounded unit round-trip.
            let untouched = field.stringValue == String(format: "%g", (unit.fromPoints(rows[index].1) * 10000).rounded() / 10000)
            return untouched ? rows[index].1 : unit.toPoints(typed)
        }
        let signedAngle = isLine ? (Double(fields[1].stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0) : 0
        guard let first = values.first, first > 0 else { return }

        let path: VectorPath?
        if isLine {
            // Angle is counter-clockwise from the +x axis, as in Illustrator; canvas y points down.
            let radians = signedAngle * .pi / 180
            let end = CGPoint(x: canvasPoint.x + first * cos(radians), y: canvasPoint.y - first * sin(radians))
            path = VectorPath(elements: [
                .move(to: VectorPoint(canvasPoint)),
                .line(to: VectorPoint(end))
            ])
        } else if isBox {
            let width = first
            let height = isSquareLike ? first : (values.count > 1 ? values[1] : first)
            guard height > 0 else { return }
            var rect = CGRect(x: canvasPoint.x, y: canvasPoint.y, width: width, height: height)
            if tool == .equilateralTriangle {
                let equilateralWidth = first * 2 / 3.0.squareRoot()
                rect = CGRect(x: canvasPoint.x, y: canvasPoint.y, width: equilateralWidth, height: first)
            }
            switch tool {
            case .egg:
                path = createEggPath(rect: rect)
            case .cone:
                path = createConePath(rect: rect)
            case .isoscelesTriangle:
                path = createIsoscelesTrianglePath(rect: rect)
            case .acuteTriangle:
                path = createAcuteTrianglePath(rect: rect)
            case .rightTriangle:
                path = createRightTrianglePath(rect: rect, dragDirection: "RIGHT_DOWN")
            case .equilateralTriangle:
                path = VectorPath(elements: [
                    .move(to: VectorPoint(rect.midX, rect.minY)),
                    .line(to: VectorPoint(rect.minX, rect.maxY)),
                    .line(to: VectorPoint(rect.maxX, rect.maxY)),
                    .close
                ], isClosed: true)
            case .rectangle, .square:
                path = VectorPath(elements: [
                    .move(to: VectorPoint(rect.minX, rect.minY)),
                    .line(to: VectorPoint(rect.maxX, rect.minY)),
                    .line(to: VectorPoint(rect.maxX, rect.maxY)),
                    .line(to: VectorPoint(rect.minX, rect.maxY)),
                    .close
                ], isClosed: true)
            case .roundedRectangle:
                let requested = values.count > 2 ? values[2] : document.viewState.roundedRectCornerRadius
                path = createRoundedRectPath(rect: rect, cornerRadius: min(requested, min(width, height) / 2))
            case .pill:
                path = createRoundedRectPath(rect: rect, cornerRadius: min(width, height) / 2)
            case .circle:
                path = createCirclePath(rect: rect)
            default:
                path = createEllipsePath(rect: rect)
            }
        } else {
            let cursor = CGPoint(x: canvasPoint.x, y: canvasPoint.y - first)
            path = radialShapePath(tool: tool, center: canvasPoint, cursor: cursor)
        }
        guard let newPath = path else { return }
        currentPath = newPath
        commitCurrentShapePath()
        currentPath = nil
        drawingStartPoint = nil
    }
}
