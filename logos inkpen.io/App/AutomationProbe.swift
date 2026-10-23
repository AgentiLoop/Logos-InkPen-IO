import SwiftUI
import AppKit

/// Machine-readable document state for end-to-end tests that drive the real app (tools/e2e).
/// Only present when the app is launched with `-InkPenAutomation YES`: an invisible accessibility
/// element (identifier `inkpen.automation.state`) over each canvas whose AXValue is a JSON snapshot
/// of the document — every object's canvas bounds and on-screen rect (CG global coordinates),
/// the selection, the current tool and the undo/redo depth. Computed on every read, never cached.
enum AutomationProbe {
    static let identifier = "inkpen.automation.state"

    static let isEnabled: Bool = UserDefaults.standard.bool(forKey: "InkPenAutomation")
        || ProcessInfo.processInfo.environment["INKPEN_AUTOMATION"] == "1"
}

struct AutomationProbeView: NSViewRepresentable {
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint

    func makeNSView(context: Context) -> AutomationProbeNSView {
        AutomationProbeNSView()
    }

    func updateNSView(_ view: AutomationProbeNSView, context: Context) {
        view.document = document
        view.zoomLevel = zoomLevel
        view.canvasOffset = canvasOffset
    }
}

final class AutomationProbeNSView: NSView {
    weak var document: VectorDocument?
    var zoomLevel: Double = 1
    var canvasOffset: CGPoint = .zero

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .staticText }
    override func accessibilityIdentifier() -> String { AutomationProbe.identifier }
    override func accessibilityLabel() -> String? { "Automation state" }
    override func accessibilityValue() -> Any? { stateJSON() }

    /// Canvas point → CG global screen point (origin top-left of the primary display).
    private func screenPoint(_ canvasPoint: CGPoint) -> CGPoint? {
        guard let window else { return nil }
        let local = CGPoint(x: canvasPoint.x * zoomLevel + canvasOffset.x,
                            y: canvasPoint.y * zoomLevel + canvasOffset.y)
        let cocoa = window.convertPoint(toScreen: convert(local, to: nil))
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: cocoa.x, y: primaryHeight - cocoa.y)
    }

    private func screenRect(_ rect: CGRect) -> CGRect? {
        guard let a = screenPoint(CGPoint(x: rect.minX, y: rect.minY)),
              let b = screenPoint(CGPoint(x: rect.maxX, y: rect.maxY)) else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private static func kind(_ type: VectorObject.ObjectType) -> String {
        switch type {
        case .shape: return "shape"
        case .text: return "text"
        case .image: return "image"
        case .warp: return "warp"
        case .group: return "group"
        case .clipGroup: return "clipGroup"
        case .clipMask: return "clipMask"
        case .guide: return "guide"
        }
    }

    private static func rectArray(_ r: CGRect) -> [Double] {
        [Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)]
    }

    func stateJSON() -> String {
        guard let document else { return "{}" }
        let snapshot = document.snapshot
        var parentOf: [UUID: UUID] = [:]
        for (id, object) in snapshot.objects {
            for member in object.shape.memberIDs { parentOf[member] = id }
        }
        func drawnBounds(_ id: UUID) -> CGRect? {
            guard let shape = snapshot.objects[id]?.shape else { return nil }
            var rect = shape.bounds.applying(shape.transform)
            var child = id
            while let parent = parentOf[child], let parentShape = snapshot.objects[parent]?.shape {
                rect = rect.applying(parentShape.transform)
                child = parent
            }
            return rect
        }

        var objects: [[String: Any]] = []
        for (layerIndex, layer) in snapshot.layers.enumerated() {
            var stack = Array(layer.objectIDs.reversed())
            while let id = stack.popLast() {
                guard let object = snapshot.objects[id], let bounds = drawnBounds(id) else { continue }
                let shape = object.shape
                var entry: [String: Any] = [
                    "id": id.uuidString,
                    "name": shape.name,
                    "kind": Self.kind(object.objectType),
                    "layer": layerIndex,
                    "topLevel": parentOf[id] == nil,
                    "bounds": Self.rectArray(bounds),
                    "transform": [shape.transform.a, shape.transform.b, shape.transform.c,
                                  shape.transform.d, shape.transform.tx, shape.transform.ty].map { Double($0) }
                ]
                if let parent = parentOf[id] { entry["parent"] = parent.uuidString }
                if let screen = screenRect(bounds) { entry["screen"] = Self.rectArray(screen) }
                objects.append(entry)
                stack.append(contentsOf: shape.memberIDs.reversed())
            }
        }

        let state: [String: Any] = [
            "objects": objects,
            "layers": snapshot.layers.map { ["name": $0.name, "locked": $0.isLocked, "visible": $0.isVisible,
                                             "count": $0.objectIDs.count] as [String: Any] },
            "selected": document.viewState.selectedObjectIDs.map(\.uuidString).sorted(),
            "tool": document.viewState.currentTool.rawValue,
            "zoom": zoomLevel,
            "offset": [Double(canvasOffset.x), Double(canvasOffset.y)],
            "undoCount": document.commandManager.undoCount,
            "redoCount": document.commandManager.redoCount,
            "undoStack": document.commandManager.undoStackNames
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
}
