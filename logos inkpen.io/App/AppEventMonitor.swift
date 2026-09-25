import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted (object: VectorDocument) when Return/Enter/Esc should end the pen path in progress.
    static let penToolEndPathRequested = Notification.Name("penToolEndPathRequested")
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
           activeDoc.viewState.currentTool == .bezierPen,
           [Self.returnKeyCode, Self.keypadEnterKeyCode, Self.escapeKeyCode].contains(event.keyCode),
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            NotificationCenter.default.post(name: .penToolEndPathRequested, object: activeDoc)
            return nil
        }
        if event.type == .keyDown,
           let characters = event.charactersIgnoringModifiers,
           characters == " " {
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
            else if cmdPressed && !isSpacebarPressed && activeDoc.viewState.currentTool != .selection && temporaryTool == nil {
                previousTool = activeDoc.viewState.currentTool
                temporaryTool = .selection
                activeDoc.viewState.currentTool = .selection
            }
            else if !cmdPressed && temporaryTool == .selection {
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
