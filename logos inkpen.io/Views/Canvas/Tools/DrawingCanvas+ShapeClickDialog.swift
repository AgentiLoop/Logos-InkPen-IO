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
        let isBox = boxTools.contains(tool)
        guard isBox || radialTools.contains(tool) else { return }
        // Guard against a duplicate tap callback firing a second dialog right after the first closes.
        guard Date().timeIntervalSince(lastShapeDialogClose) > 0.5 else { return }
        defer { lastShapeDialogClose = Date() }
        let isSquareLike = tool == .square || tool == .circle

        let alert = NSAlert()
        alert.messageText = tool.rawValue.capitalized
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        func makeField(_ value: Double) -> NSTextField {
            let field = NSTextField(string: String(format: "%g", value))
            field.frame = NSRect(x: 80, y: 0, width: 100, height: 22)
            return field
        }
        func makeLabel(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 0, y: 0, width: 80, height: 20)
            return label
        }

        var rows: [(String, Double)] = isBox
            ? (isSquareLike ? [(tool == .circle ? "Diameter:" : "Size:", 100)] : [("Width:", 100), ("Height:", 100)])
            : [("Radius:", 50)]
        if tool == .roundedRectangle { rows.append(("Corner Radius:", 20)) }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 190, height: CGFloat(rows.count) * 28))
        var fields: [NSTextField] = []
        for (index, row) in rows.enumerated() {
            let y = CGFloat(rows.count - 1 - index) * 28
            let label = makeLabel(row.0)
            label.frame.origin.y = y + 2
            let field = makeField(row.1)
            field.frame.origin.y = y
            container.addSubview(label)
            container.addSubview(field)
            fields.append(field)
        }
        alert.accessoryView = container
        alert.window.initialFirstResponder = fields.first

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let values = fields.map { abs(Double($0.stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0) }
        guard let first = values.first, first > 0 else { return }

        let path: VectorPath?
        if isBox {
            let width = first
            let height = isSquareLike ? first : (values.count > 1 ? values[1] : first)
            guard height > 0 else { return }
            let rect = CGRect(x: canvasPoint.x, y: canvasPoint.y, width: width, height: height)
            switch tool {
            case .rectangle, .square:
                path = VectorPath(elements: [
                    .move(to: VectorPoint(rect.minX, rect.minY)),
                    .line(to: VectorPoint(rect.maxX, rect.minY)),
                    .line(to: VectorPoint(rect.maxX, rect.maxY)),
                    .line(to: VectorPoint(rect.minX, rect.maxY)),
                    .close
                ], isClosed: true)
            case .roundedRectangle:
                let requested = values.count > 2 ? values[2] : 20.0
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
