import SwiftUI

class PressureSensitiveCanvasView: NSView {
    var onPressureEvent: ((CGPoint, Double, PressureEventType, Bool) -> Void)?
    private(set) var hasPressureSupport = false
    private var isDragging = false
    private var startLocation: CGPoint = .zero

    enum PressureEventType {
        case began
        case changed
        case ended
    }

    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setupPressureDetection()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPressureDetection()
    }

    private func setupPressureDetection() {
        detectPressureSupport()
    }

    private func detectPressureSupport() {
        hasPressureSupport = false
    }

    private func logEvent(_ event: NSEvent, context: String) {
    }

    override func mouseDown(with event: NSEvent) {
        logEvent(event, context: "MOUSE_DOWN")
        startLocation = convert(event.locationInWindow, from: nil)
        isDragging = true
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(startLocation)
        let isTabletEvent = (event.subtype == .tabletPoint)
        onPressureEvent?(canvasLocation, pressure, .began, isTabletEvent)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        logEvent(event, context: "MOUSE_DRAGGED")
        guard isDragging else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        let isTabletEvent = (event.subtype == .tabletPoint)
        onPressureEvent?(canvasLocation, pressure, .changed, isTabletEvent)
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        logEvent(event, context: "MOUSE_UP")
        guard isDragging else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        let isTabletEvent = (event.subtype == .tabletPoint)
        onPressureEvent?(canvasLocation, pressure, .ended, isTabletEvent)
        isDragging = false
        super.mouseUp(with: event)
    }

    override func pressureChange(with event: NSEvent) {
        logEvent(event, context: "PRESSURE_CHANGE")
        guard isDragging else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        onPressureEvent?(canvasLocation, pressure, .changed, false)
        super.pressureChange(with: event)
    }

    override func tabletPoint(with event: NSEvent) {
        logEvent(event, context: "TABLET_POINT")
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        let eventType: PressureEventType
        if !isDragging && pressure > 0.1 {
            isDragging = true
            eventType = .began
            startLocation = currentLocation
        } else if isDragging && pressure <= 0.1 {
            isDragging = false
            eventType = .ended
        } else {
            eventType = .changed
        }
        onPressureEvent?(canvasLocation, pressure, eventType, true)
        super.tabletPoint(with: event)
    }

    override func tabletProximity(with event: NSEvent) {
        logEvent(event, context: "TABLET_PROXIMITY")
        if event.isEnteringProximity {
        } else {
            if isDragging {
                isDragging = false
                let canvasLocation = convertToCanvasCoordinates(startLocation)
                onPressureEvent?(canvasLocation, 0.1, .ended, true)
            }
        }
        super.tabletProximity(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        logEvent(event, context: "RIGHT_MOUSE_DOWN")
        super.rightMouseDown(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        logEvent(event, context: "RIGHT_MOUSE_DRAGGED")
        super.rightMouseDragged(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        logEvent(event, context: "RIGHT_MOUSE_UP")
        super.rightMouseUp(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        logEvent(event, context: "OTHER_MOUSE_DOWN")
        super.otherMouseDown(with: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        logEvent(event, context: "OTHER_MOUSE_DRAGGED")
        super.otherMouseDragged(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        logEvent(event, context: "OTHER_MOUSE_UP")
        super.otherMouseUp(with: event)
    }

    override func magnify(with event: NSEvent) {
        logEvent(event, context: "MAGNIFY")
        super.magnify(with: event)
    }

    override func rotate(with event: NSEvent) {
        logEvent(event, context: "ROTATE")
        super.rotate(with: event)
    }

    override func swipe(with event: NSEvent) {
        logEvent(event, context: "SWIPE")
        super.swipe(with: event)
    }

    override func beginGesture(with event: NSEvent) {
        logEvent(event, context: "BEGIN_GESTURE")
        super.beginGesture(with: event)
    }

    override func endGesture(with event: NSEvent) {
        logEvent(event, context: "END_GESTURE")
        super.endGesture(with: event)
    }

    override func smartMagnify(with event: NSEvent) {
        logEvent(event, context: "SMART_MAGNIFY")
        super.smartMagnify(with: event)
    }

    private func extractPressure(from event: NSEvent) -> Double {
        var pressure: Double = 1.0
        var foundRealPressure = false
        switch event.type {
        case .tabletPoint:
            pressure = Double(event.pressure)
            foundRealPressure = true
        case .leftMouseDown, .leftMouseDragged, .leftMouseUp:
            if event.subtype == .tabletPoint {
                pressure = Double(event.pressure)
                foundRealPressure = true
            } else if event.pressure > 0.0 && event.pressure != 1.0 {
                pressure = Double(event.pressure)
                foundRealPressure = true
            } else {
                pressure = 1.0
            }
        case .pressure:
            pressure = Double(event.pressure)
            foundRealPressure = true
        default:
            pressure = 1.0
        }
        if foundRealPressure && !hasPressureSupport {
            hasPressureSupport = true
        }
        return pressure
    }

    private func convertToCanvasCoordinates(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: frame.height - point.y)
    }
}

struct PressureSensitiveCanvasRepresentable: NSViewRepresentable {
    let onPressureEvent: (CGPoint, Double, PressureSensitiveCanvasView.PressureEventType, Bool) -> Void

    @Binding var hasPressureSupport: Bool
    func makeNSView(context: Context) -> PressureSensitiveCanvasView {
        let view = PressureSensitiveCanvasView()
        view.onPressureEvent = onPressureEvent
        return view
    }

    func updateNSView(_ nsView: PressureSensitiveCanvasView, context: Context) {
        nsView.onPressureEvent = onPressureEvent
        hasPressureSupport = nsView.hasPressureSupport
    }
}
