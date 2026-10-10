import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted (object: VectorDocument) when Return/Enter/Esc should end the pen path in progress.
    static let penToolEndPathRequested = Notification.Name("penToolEndPathRequested")
    /// Posted (object: VectorDocument, userInfo["handled"]: PenRequestResult) when Delete/Backspace should remove the last pen anchor.
    /// Posted (object: VectorDocument) when Transform Again (Cmd+D) should replay the last transform on the selection.
    static let transformAgainRequested = Notification.Name("transformAgainRequested")
    static let penToolRemoveLastAnchorRequested = Notification.Name("penToolRemoveLastAnchorRequested")
}

/// Filled in synchronously by the canvas so the key monitor knows whether it consumed the key.
final class PenRequestResult {
    var handled = false
}

final class AppEventMonitor {
    static let shared = AppEventMonitor()

    private var keyEventMonitor: Any?

    private let lock = NSLock()
    private(set) weak var activeDocument: VectorDocument?
    private var isSpacebarPressed = false

    private init() {
        setupKeyEventMonitoring()
        // If the app loses focus while Space/Cmd/an arrow is held (e.g. Cmd-Tab), the key-up or
        // flags-changed event never arrives and the temporary tool / live nudge would stick.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.resetTransientKeyState()
        }
    }

    func setActiveDocument(_ document: VectorDocument) {
        lock.lock()
        defer { lock.unlock() }
        activeDocument = document
    }

    private func resetTransientKeyState() {
        lock.lock()
        let activeDoc = activeDocument
        lock.unlock()
        isSpacebarPressed = false
        if let doc = activeDoc {
            if let previous = previousTool, temporaryTool != nil {
                doc.viewState.currentTool = previous
            }
            if isNudging && accumulatedNudgeOffset != .zero {
                doc.nudgeSelectedObjects(by: accumulatedNudgeOffset)
            }
            doc.viewState.liveNudgeOffset = .zero
        }
        temporaryTool = nil
        previousTool = nil
        accumulatedNudgeOffset = .zero
        isNudging = false
    }

    private func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] (event: NSEvent) -> NSEvent? in
            guard let self = self else { return event }
            guard let keyWindow = NSApp.keyWindow,
                  keyWindow == event.window else {
                return event
            }
            self.lock.lock()
            let activeDoc = self.activeDocument
            self.lock.unlock()
            guard let activeDoc = activeDoc else {
                return event
            }
            return self.handleKeyEvent(event, activeDoc: activeDoc)
        }
    }
    private var temporaryTool: DrawingTool?
    private var previousTool: DrawingTool?
    private var accumulatedNudgeOffset: CGVector = .zero
    private var lastNudgeTime: Date = Date.distantPast
    private var isNudging: Bool = false

    private static let returnKeyCode: UInt16 = 36
    private static let keypadEnterKeyCode: UInt16 = 76
    private static let escapeKeyCode: UInt16 = 53

    private func handleKeyEvent(_ event: NSEvent, activeDoc: VectorDocument) -> NSEvent? {
        if let window = NSApp.keyWindow,
           let firstResponder = window.firstResponder,
           firstResponder is NSTextView {
            return event
        }
        if event.type == .keyDown,
           [DrawingTool.bezierPen, .curvature].contains(activeDoc.viewState.currentTool),
           [Self.returnKeyCode, Self.keypadEnterKeyCode, Self.escapeKeyCode].contains(event.keyCode),
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            NotificationCenter.default.post(name: .penToolEndPathRequested, object: activeDoc)
            return nil
        }
        if event.type == .keyDown,
           [DrawingTool.bezierPen, .curvature].contains(activeDoc.viewState.currentTool),
           event.keyCode == 51 || event.keyCode == 117,
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            // Illustrator: Delete/Backspace while drawing removes the last anchor placed.
            let result = PenRequestResult()
            NotificationCenter.default.post(name: .penToolRemoveLastAnchorRequested, object: activeDoc, userInfo: ["handled": result])
            if result.handled { return nil }
        }
        if event.type == .keyDown,
           activeDoc.viewState.currentTool == .eraser || activeDoc.viewState.currentTool == .blobBrush,
           let bracket = event.charactersIgnoringModifiers, bracket == "[" || bracket == "]",
           event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            let settings = ApplicationSettings.shared
            if activeDoc.viewState.currentTool == .blobBrush {
                let size = settings.blobBrushSize
                let step = size >= 20 ? 5.0 : (size >= 5 ? 1.0 : 0.5)
                settings.blobBrushSize = bracket == "]" ? min(500, size + step) : max(1, size - step)
            } else {
                let step = settings.eraserSize >= 20 ? 5.0 : (settings.eraserSize >= 5 ? 1.0 : 0.5)
                settings.eraserSize = bracket == "]" ? min(500, settings.eraserSize + step) : max(1, settings.eraserSize - step)
            }
            return nil
        }
        if event.type == .keyDown,
           event.keyCode == Self.escapeKeyCode,
           activeDoc.viewState.isolatedGroupID != nil,
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            NotificationCenter.default.post(name: .exitIsolationRequested, object: activeDoc)
            return nil
        }
        if event.type == .keyDown,
           activeDoc.viewState.isShapeDrawingInProgress,
           activeDoc.viewState.currentTool == .roundedRectangle,
           [123, 124, 125, 126].contains(event.keyCode) {
            // Illustrator: Up/Down arrow while dragging a rounded rectangle changes the corner radius; Left = square corners, Right = fully rounded.
            let radius = activeDoc.viewState.roundedRectCornerRadius
            switch event.keyCode {
            case 126: activeDoc.viewState.roundedRectCornerRadius = min(5000, radius + 5)
            case 125: activeDoc.viewState.roundedRectCornerRadius = max(0, radius - 5)
            case 123: activeDoc.viewState.roundedRectCornerRadius = 0
            default: activeDoc.viewState.roundedRectCornerRadius = 5000
            }
            return nil
        }
        if event.type == .keyDown,
           activeDoc.viewState.isShapeDrawingInProgress,
           activeDoc.viewState.currentTool == .polygon || activeDoc.viewState.currentTool == .star,
           event.keyCode == 126 || event.keyCode == 125 {
            // Illustrator: Up/Down arrow while dragging a polygon or star adds/removes a side/point.
            let tool = activeDoc.viewState.currentTool
            let delta = event.keyCode == 126 ? 1 : -1
            let base: Int
            if tool == .polygon {
                base = 6
            } else {
                switch ToolGroupManager.shared.selectedVariant {
                case .threePoint: base = 3
                case .fourPoint: base = 4
                case .fivePoint: base = 5
                case .sixPoint: base = 6
                case .sevenPoint: base = 7
                }
            }
            let adjusted = activeDoc.viewState.radialCountAdjustment[tool, default: 0] + delta
            activeDoc.viewState.radialCountAdjustment[tool] = max(3 - base, min(100, adjusted))
            return nil
        }
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            if activeDoc.viewState.isShapeDrawingInProgress {
                activeDoc.viewState.isSpaceHeldDuringShapeDrag = true
                return nil
            }
            if !isSpacebarPressed && temporaryTool == nil {
                isSpacebarPressed = true
                previousTool = activeDoc.viewState.currentTool
                temporaryTool = .hand
                activeDoc.viewState.currentTool = .hand
            }
            return nil
        }
        if event.type == .keyUp,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
            activeDoc.viewState.isSpaceHeldDuringShapeDrag = false
            isSpacebarPressed = false
            if let previous = previousTool, (temporaryTool == .hand || temporaryTool == .zoom) {
                activeDoc.viewState.currentTool = previous
                temporaryTool = nil
                previousTool = nil
            }
            return nil
        }
        if event.type == .flagsChanged {
            let cmdPressed = event.modifierFlags.contains(.command)
            if isSpacebarPressed && cmdPressed && temporaryTool == .hand {
                temporaryTool = .zoom
                activeDoc.viewState.currentTool = .zoom
            }
            else if isSpacebarPressed && !cmdPressed && temporaryTool == .zoom {
                temporaryTool = .hand
                activeDoc.viewState.currentTool = .hand
            }
            else if cmdPressed && !isSpacebarPressed && temporaryTool == nil
                        && !(activeDoc.viewState.isShapeDrawingInProgress && activeDoc.viewState.currentTool == .star)
                        && activeDoc.viewState.currentTool != .selection && activeDoc.viewState.currentTool != .directSelection {
                let selectionTool = activeDoc.viewState.lastSelectionTool
                previousTool = activeDoc.viewState.currentTool
                temporaryTool = selectionTool
                activeDoc.viewState.currentTool = selectionTool
            }
            else if !cmdPressed && (temporaryTool == .selection || temporaryTool == .directSelection) {
                if let previous = previousTool {
                    activeDoc.viewState.currentTool = previous
                    temporaryTool = nil
                    previousTool = nil
                }
            }
        }
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == "\t" {
            activeDoc.viewState.selectedObjectIDs = []
            for newVectorObject in activeDoc.snapshot.objects.values {
                if case .text(let shape) = newVectorObject.objectType, shape.isEditing == true {
                    activeDoc.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }
            return nil
        }
        if event.type == .keyDown,

           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"
            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) {
                if !event.modifierFlags.contains(.control) &&
                   !event.modifierFlags.contains(.command) {
                    if activeDoc.viewState.selectedObjectIDs.isEmpty && activeDoc.viewState.selectedPoints.isEmpty {
                        // Nothing to nudge: let lists, steppers, etc. receive the arrow key.
                        return event
                    }
                    var nudgeDirection: CGVector? = nil
                    switch characters {
                    case arrowUp:
                        nudgeDirection = CGVector(dx: 0, dy: -1)
                    case arrowDown:
                        nudgeDirection = CGVector(dx: 0, dy: 1)
                    case arrowLeft:
                        nudgeDirection = CGVector(dx: -1, dy: 0)
                    case arrowRight:
                        nudgeDirection = CGVector(dx: 1, dy: 0)
                    default:
                        break
                    }
                    if let direction = nudgeDirection {
                        let now = Date()
                        if now.timeIntervalSince(lastNudgeTime) > 0.5 {
                            accumulatedNudgeOffset = .zero
                            isNudging = false
                        }
                        lastNudgeTime = now
                        let gridSpacingInPoints = activeDoc.settings.gridSpacing * activeDoc.settings.unit.pointsPerUnit
                        let increment = NudgeMath.increment(
                            gridSpacingInPoints: CGFloat(gridSpacingInPoints),
                            snapToGrid: activeDoc.settings.snapToGrid,
                            shift: event.modifierFlags.contains(.shift),
                            option: event.modifierFlags.contains(.option)
                        )
                        let nudgeAmount = CGVector(
                            dx: direction.dx * increment,
                            dy: direction.dy * increment
                        )
                        accumulatedNudgeOffset.dx += nudgeAmount.dx
                        accumulatedNudgeOffset.dy += nudgeAmount.dy
                        isNudging = true
                        let isDirectSelectWithPoints = activeDoc.viewState.currentTool == DrawingTool.directSelection && !activeDoc.viewState.selectedPoints.isEmpty
                        if !isDirectSelectWithPoints {
                            activeDoc.viewState.liveNudgeOffset = accumulatedNudgeOffset
                        }
                        return nil
                    }
                }
            }
        }
        if event.type == .keyUp,

           let characters = event.charactersIgnoringModifiers {
            let arrowUp = "\u{F700}"
            let arrowDown = "\u{F701}"
            let arrowLeft = "\u{F702}"
            let arrowRight = "\u{F703}"
            if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) && isNudging {
                if accumulatedNudgeOffset != .zero {
                    activeDoc.nudgeSelectedObjects(by: accumulatedNudgeOffset)
                }
                accumulatedNudgeOffset = .zero
                activeDoc.viewState.liveNudgeOffset = .zero
                isNudging = false
                return nil
            }
        }
        return event
    }
}
