import SwiftUI
import AppKit

private var lastTransformDialogClose = Date.distantPast

extension DrawingCanvas {

    /// Illustrator: Option-click with Rotate / Scale / Reflect / Shear sets the reference point
    /// at the click and opens a dialog to type exact values (OK applies, Copy applies to a duplicate).
    internal func showTransformToolDialog(at canvasPoint: CGPoint) {
        let tool = document.viewState.currentTool
        guard DrawingCanvas.isTransformDragTool(tool), !document.viewState.selectedObjectIDs.isEmpty else { return }
        guard Date().timeIntervalSince(lastTransformDialogClose) > 0.5 else { return }
        defer { lastTransformDialogClose = Date() }

        document.viewState.transformToolOrigin = canvasPoint

        let alert = NSAlert()
        alert.messageText = tool.rawValue.capitalized
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Copy")

        let rowHeight: CGFloat = 28
        let width: CGFloat = 250
        var rowCount = 0
        let container = NSView()

        func addLabel(_ text: String, row: Int) {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 0, y: CGFloat(row) * rowHeight + 2, width: 100, height: 20)
            container.addSubview(label)
        }
        func addField(_ value: String, row: Int) -> NSTextField {
            let field = NSTextField(string: value)
            field.frame = NSRect(x: 104, y: CGFloat(row) * rowHeight, width: 100, height: 22)
            container.addSubview(field)
            return field
        }
        func addPopup(_ items: [String], row: Int) -> NSPopUpButton {
            let popup = NSPopUpButton(frame: NSRect(x: 100, y: CGFloat(row) * rowHeight - 2, width: 140, height: 26), pullsDown: false)
            popup.addItems(withTitles: items)
            container.addSubview(popup)
            return popup
        }
        func number(_ field: NSTextField?) -> Double {
            Double((field?.stringValue ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        // Rows are laid out bottom-up (AppKit coordinates); `rowCount` is counted top-down then flipped below.
        var angleField: NSTextField?
        var hField: NSTextField?
        var vField: NSTextField?
        var uniformCheck: NSButton?
        var axisPopup: NSPopUpButton?
        var axisAngleField: NSTextField?

        switch tool {
        case .rotate:
            rowCount = 1
            addLabel("Angle (°):", row: 0)
            angleField = addField("0", row: 0)
        case .scale:
            rowCount = 3
            let check = NSButton(checkboxWithTitle: "Uniform", target: nil, action: nil)
            check.state = .on
            check.frame = NSRect(x: 104, y: 2 * rowHeight, width: 120, height: 20)
            container.addSubview(check)
            uniformCheck = check
            addLabel("Horizontal (%):", row: 1)
            hField = addField("100", row: 1)
            addLabel("Vertical (%):", row: 0)
            vField = addField("100", row: 0)
        case .reflect:
            rowCount = 2
            addLabel("Axis:", row: 1)
            axisPopup = addPopup(["Horizontal", "Vertical", "Angle"], row: 1)
            addLabel("Angle (°):", row: 0)
            axisAngleField = addField("0", row: 0)
        case .shear:
            rowCount = 3
            addLabel("Shear angle (°):", row: 2)
            angleField = addField("0", row: 2)
            addLabel("Axis:", row: 1)
            axisPopup = addPopup(["Horizontal", "Vertical", "Angle"], row: 1)
            addLabel("Axis angle (°):", row: 0)
            axisAngleField = addField("0", row: 0)
        default:
            return
        }
        container.frame = NSRect(x: 0, y: 0, width: width, height: CGFloat(rowCount) * rowHeight)
        alert.accessoryView = container
        let firstField = angleField ?? hField ?? axisAngleField
        alert.window.initialFirstResponder = firstField

        let response = alert.runModal()
        let isCopy = response == .alertThirdButtonReturn
        guard response == .alertFirstButtonReturn || isCopy else { return }

        // Illustrator measures positive angles counter-clockwise; the canvas is y-down, so negate.
        func radians(_ degrees: Double) -> CGFloat { CGFloat(-degrees * .pi / 180) }

        var matrix = CGAffineTransform.identity
        switch tool {
        case .rotate:
            matrix = CGAffineTransform(rotationAngle: radians(number(angleField)))
        case .scale:
            let h = number(hField) / 100
            let v = (uniformCheck?.state == .on) ? h : number(vField) / 100
            guard h != 0, v != 0 else { return }
            matrix = CGAffineTransform(scaleX: CGFloat(h), y: CGFloat(v))
        case .reflect, .shear:
            let axisIndex = axisPopup?.indexOfSelectedItem ?? 0
            let axis: CGFloat = axisIndex == 0 ? 0 : (axisIndex == 1 ? -.pi / 2 : radians(number(axisAngleField)))
            if tool == .reflect {
                matrix = CGAffineTransform(rotationAngle: -axis)
                    .concatenating(CGAffineTransform(scaleX: 1, y: -1))
                    .concatenating(CGAffineTransform(rotationAngle: axis))
            } else {
                let tangent = CGFloat(tan(-number(angleField) * .pi / 180))
                let shear = CGAffineTransform(a: 1, b: 0, c: tangent, d: 1, tx: 0, ty: 0)
                matrix = CGAffineTransform(rotationAngle: -axis)
                    .concatenating(shear)
                    .concatenating(CGAffineTransform(rotationAngle: axis))
            }
        default:
            return
        }
        guard !matrix.isIdentity else { return }

        let transform = CGAffineTransform(translationX: -canvasPoint.x, y: -canvasPoint.y)
            .concatenating(matrix)
            .concatenating(CGAffineTransform(translationX: canvasPoint.x, y: canvasPoint.y))

        document.viewState.lastTransformAgain = (transform, isCopy)
        if isCopy {
            ClipboardManager.shared.duplicateSelectionInPlace(in: document)
        }
        guard let session = makeTransformSession() else { return }
        applyTransform(transform, to: session)
        commitTransform(session)
    }
}
