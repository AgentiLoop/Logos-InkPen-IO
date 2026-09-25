import SwiftUI

#if os(macOS)
import AppKit

struct CanvasCursorOverlayView: View {
    let isHovering: Bool
    let currentTool: DrawingTool
    let isPanActive: Bool
    let zoomLevel: CGFloat
    let canvasOffset: CGPoint

    var body: some View {
        CanvasCursorOverlayRepresentable(
            isHovering: isHovering,
            currentTool: currentTool,
            isPanActive: isPanActive,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CanvasCursorOverlayRepresentable: NSViewRepresentable {
    let isHovering: Bool
    let currentTool: DrawingTool
    let isPanActive: Bool
    let zoomLevel: CGFloat
    let canvasOffset: CGPoint

    func makeNSView(context: Context) -> CursorOverlayNSView {
        let v = CursorOverlayNSView()
        v.isHovering = isHovering
        v.currentTool = currentTool
        v.isPanActive = isPanActive
        return v
    }

    func updateNSView(_ nsView: CursorOverlayNSView, context: Context) {
        nsView.isHovering = isHovering
        nsView.currentTool = currentTool
        nsView.isPanActive = isPanActive
        DispatchQueue.main.async {
            nsView.window?.invalidateCursorRects(for: nsView)
        }
        if isHovering {
            nsView.activateCursorLock(duration: 0.5)
        }
    }
}

private final class CursorOverlayNSView: NSView {
    var isHovering: Bool = false
    var currentTool: DrawingTool = .selection
    var isPanActive: Bool = false

    private var eventMonitors: [Any] = []
    private var cursorLockTimer: Timer?
    private var cursorLockUntil: Date = .distantPast

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeEventMonitors()
        installEventMonitors()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        removeEventMonitors()
        invalidateCursorLock()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        discardCursorRects()
        guard isHovering else { return }

        let cursor: NSCursor? = {
            switch currentTool {
            case .hand:
                return isPanActive ? HandClosedCursor : HandOpenCursor
            case .eyedropper:
                return EyedropperCursor
            case .selectSameColor:
                return EyedropperCursor
            case .zoom:
                return MagnifyingGlassCursor
            case .rectangle, .square, .circle,
                 .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle,
                 .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                return CrosshairCursor
            default:
                return nil
            }
        }()
        if let cursor = cursor {
            addCursorRect(bounds, cursor: cursor)
            cursor.set()
        }
    }

    private func installEventMonitors() {
        let cursorMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.cursorUpdate, .mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        ) { [weak self] event in
            guard let self = self else { return event }
            guard self.window === event.window else { return event }
            let p = self.convert(event.locationInWindow, from: nil)
            let shouldForce = self.isHovering && self.bounds.contains(p) && self.shouldForceCustomCursor()
            if shouldForce {
                self.applyForcedCursor()
                return event.type == .cursorUpdate ? nil : event
            }
            return event
        }
        eventMonitors.append(cursorMonitor as Any)
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
        eventMonitors.removeAll()
    }

    private func shouldForceCustomCursor() -> Bool {
        switch currentTool {
        case .hand, .eyedropper, .selectSameColor, .zoom,
             .rectangle, .square, .circle,
             .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle,
             .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
            return true
        default:
            return false
        }
    }

    private func applyForcedCursor() {

        let cursor: NSCursor? = {
            switch currentTool {
            case .hand:
                return isPanActive ? HandClosedCursor : HandOpenCursor
            case .eyedropper:
                return EyedropperCursor
            case .selectSameColor:
                return EyedropperCursor
            case .zoom:
                return MagnifyingGlassCursor
            case .rectangle, .square, .circle,
                 .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle,
                 .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                return CrosshairCursor
            default:
                return nil
            }
        }()
        cursor?.set()
    }

    func activateCursorLock(duration: TimeInterval) {
        cursorLockUntil = Date().addingTimeInterval(duration)
        cursorLockTimer?.invalidate()
        cursorLockTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if Date() >= self.cursorLockUntil {
                t.invalidate()
                return
            }
            if self.window != nil, self.isHovering, self.shouldForceCustomCursor() {
                self.applyForcedCursor()
            }
        }
        if let timer = cursorLockTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func invalidateCursorLock() {
        cursorLockTimer?.invalidate()
        cursorLockTimer = nil
        cursorLockUntil = .distantPast
    }
}
#endif
