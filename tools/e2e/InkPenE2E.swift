// End-to-end test that drives the real Logos InkPen app — no human involved.
// Launches a build with -InkPenAutomation YES, opens an SVG, performs real mouse drags and
// keyboard shortcuts (CGEvent), and checks the document through the app's accessibility
// probe (App/AutomationProbe.swift: element "inkpen.automation.state", AXValue = JSON).
// Needs Accessibility permission for the process that runs it. Run via tools/e2e/run.sh.
import AppKit
import ApplicationServices

// MARK: - Reporting

var failures: [String] = []
func log(_ s: String) { print(s); fflush(stdout) }
func check(_ ok: Bool, _ what: String) {
    log((ok ? "  PASS " : "  FAIL ") + what)
    if !ok { failures.append(what) }
}
func pause(_ s: Double) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }
func waitFor(_ timeout: Double = 5, _ cond: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end { if cond() { return true }; pause(0.1) }
    return cond()
}

// MARK: - Accessibility

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}
func children(_ el: AXUIElement) -> [AXUIElement] { (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func windows(_ app: AXUIElement) -> [AXUIElement] { (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] }
func title(_ el: AXUIElement) -> String { (attr(el, kAXTitleAttribute) as? String) ?? "" }

func findFirst(_ root: AXUIElement, maxNodes: Int = 20000, _ match: (AXUIElement) -> Bool) -> AXUIElement? {
    var queue = [root]; var seen = 0
    while !queue.isEmpty && seen < maxNodes {
        let el = queue.removeFirst(); seen += 1
        if match(el) { return el }
        queue.append(contentsOf: children(el))
    }
    return nil
}

func probe(in window: AXUIElement) -> AXUIElement? {
    findFirst(window) { (attr($0, kAXIdentifierAttribute) as? String) == "inkpen.automation.state" }
}

// MARK: - Document state from the probe

struct Obj {
    let id: String, name: String, kind: String, topLevel: Bool, parent: String?
    let bounds: CGRect, screen: CGRect?
}
struct State {
    let objects: [Obj], selected: [String], tool: String, zoom: Double, undoCount: Int, redoCount: Int
    let undoStack: [String]
    /// Undo steps that change content (selection changes are undoable too, but are not edits).
    var editSteps: Int { undoStack.filter { !$0.contains("Selection") }.count }
    func obj(_ id: String) -> Obj? { objects.first { $0.id == id } }
}
func rect(_ a: Any?) -> CGRect? {
    guard let n = a as? [Double], n.count == 4 else { return nil }
    return CGRect(x: n[0], y: n[1], width: n[2], height: n[3])
}
func readState(_ probe: AXUIElement) -> State? {
    guard let json = attr(probe, kAXValueAttribute) as? String,
          let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
          let objs = root["objects"] as? [[String: Any]] else { return nil }
    let objects = objs.compactMap { o -> Obj? in
        guard let id = o["id"] as? String, let b = rect(o["bounds"]) else { return nil }
        return Obj(id: id, name: o["name"] as? String ?? "", kind: o["kind"] as? String ?? "",
                   topLevel: o["topLevel"] as? Bool ?? false, parent: o["parent"] as? String,
                   bounds: b, screen: rect(o["screen"]))
    }
    return State(objects: objects, selected: root["selected"] as? [String] ?? [], tool: root["tool"] as? String ?? "",
                 zoom: root["zoom"] as? Double ?? 1, undoCount: root["undoCount"] as? Int ?? -1,
                 redoCount: root["redoCount"] as? Int ?? -1, undoStack: root["undoStack"] as? [String] ?? [])
}

func near(_ a: CGRect, _ b: CGRect, _ tol: CGFloat) -> Bool {
    abs(a.minX - b.minX) <= tol && abs(a.minY - b.minY) <= tol &&
    abs(a.width - b.width) <= tol && abs(a.height - b.height) <= tol
}
/// The object drawn closest to `target` (canvas units) — fixture shapes are identified by geometry
/// because IDs are not guaranteed to survive save → reopen.
func object(near target: CGRect, kind: String? = nil, in s: State) -> Obj? {
    s.objects.filter { kind == nil || $0.kind == kind }
        .min { dist($0.bounds, target) < dist($1.bounds, target) }
        .flatMap { dist($0.bounds, target) < 8 ? $0 : nil }
}
func dist(_ a: CGRect, _ b: CGRect) -> CGFloat {
    abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) + abs(a.height - b.height)
}
func describe(_ s: State) -> String {
    s.objects.map { "    \($0.kind)\($0.topLevel ? "" : " (child)") \($0.name) \($0.bounds)" }.joined(separator: "\n")
}

// MARK: - Input (real HID events)

let source = CGEventSource(stateID: .hidSystemState)
func mouse(_ type: CGEventType, _ p: CGPoint) {
    let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
    e?.setIntegerValueField(.mouseEventClickState, value: 1)
    e?.flags = []
    e?.post(tap: .cghidEventTap)
}
func drag(from p: CGPoint, by d: CGVector) {
    mouse(.mouseMoved, p); pause(0.2)
    mouse(.leftMouseDown, p); pause(0.2)
    let steps = 15
    for i in 1...steps {
        let t = CGFloat(i) / CGFloat(steps)
        mouse(.leftMouseDragged, CGPoint(x: p.x + d.dx * t, y: p.y + d.dy * t)); pause(0.03)
    }
    pause(0.15)
    mouse(.leftMouseUp, CGPoint(x: p.x + d.dx, y: p.y + d.dy)); pause(0.7)
}
/// Like a real keyboard: modifier keys go down (flagsChanged) before the key and up after it,
/// so the app's own modifier tracking (shift-constrain, ⌘ temp selection) sees them released.
func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
    func post(_ k: CGKeyCode, _ down: Bool, _ f: CGEventFlags) {
        let e = CGEvent(keyboardEventSource: source, virtualKey: k, keyDown: down)
        if [55, 56, 58, 59].contains(k) { e?.type = .flagsChanged }
        e?.flags = f
        e?.post(tap: .cghidEventTap)
        pause(0.05)
    }
    let mods: [(CGEventFlags, CGKeyCode)] = [(.maskCommand, 55), (.maskShift, 56), (.maskAlternate, 58), (.maskControl, 59)]
        .filter { flags.contains($0.0) }
    var held: CGEventFlags = []
    for (f, k) in mods { held.insert(f); post(k, true, held) }
    post(code, true, flags)
    post(code, false, flags)
    for (f, k) in mods.reversed() { held.remove(f); post(k, false, held) }
    pause(0.4)
}
let kZ: CGKeyCode = 6, kS: CGKeyCode = 1, kW: CGKeyCode = 13

// MARK: - Fixture

let fixture = """
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600">
  <rect x="500" y="100" width="120" height="90" fill="orange"/>
  <g transform="translate(100,300)">
    <rect x="0" y="0" width="100" height="80" fill="blue"/>
    <rect x="140" y="0" width="100" height="80" fill="green"/>
  </g>
  <line x1="100" y1="100" x2="400" y2="100" stroke="black" stroke-width="8"/>
</svg>
"""
let orangeRect = CGRect(x: 500, y: 100, width: 120, height: 90)
let blueRect = CGRect(x: 100, y: 300, width: 100, height: 80)
let greenRect = CGRect(x: 240, y: 300, width: 100, height: 80)

// MARK: - Run

guard CommandLine.arguments.count >= 2 else { log("usage: InkPenE2E <path/to/logos inkpen.io.app>"); exit(2) }
guard AXIsProcessTrusted() else { log("This process is not trusted for Accessibility."); exit(3) }
let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("inkpen-e2e-\(getpid())")
try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
let svgURL = workDir.appendingPathComponent("e2e-fixture.svg")
try! fixture.write(to: svgURL, atomically: true, encoding: .utf8)
log("Fixture: \(svgURL.path)")

let config = NSWorkspace.OpenConfiguration()
config.arguments = ["-InkPenAutomation", "YES", "-defaultTool", "Selection",
                    "-ApplePersistenceIgnoreState", "YES", "-AppleWindowTabbingMode", "always"]
config.createsNewApplicationInstance = true
config.activates = true
var launched: NSRunningApplication?
NSWorkspace.shared.open([svgURL], withApplicationAt: appURL, configuration: config) { app, error in
    if let error { log("launch error: \(error)") }
    launched = app
}
guard waitFor(20, { launched != nil }), let running = launched else { log("FAIL app did not launch"); exit(1) }
defer { running.forceTerminate() }
let app = AXUIElementCreateApplication(running.processIdentifier)
AXUIElementSetMessagingTimeout(app, 5)
log("Launched pid \(running.processIdentifier)")

func fixtureWindow() -> AXUIElement? { windows(app).first { title($0).contains("e2e-fixture") } }
func currentProbe() -> AXUIElement? { fixtureWindow().flatMap(probe(in:)) }
func state() -> State? { currentProbe().flatMap(readState) }
func front() {
    running.activate()
    if let w = fixtureWindow() { AXUIElementPerformAction(w, kAXRaiseAction as CFString) }
    pause(0.4)
}

func finish() -> Never {
    running.forceTerminate()
    log(failures.isEmpty ? "\nALL E2E CHECKS PASSED" : "\n\(failures.count) E2E CHECK(S) FAILED:\n- " + failures.joined(separator: "\n- "))
    exit(failures.isEmpty ? 0 : 1)
}

// 1. Open
log("\n[open] SVG opens in a window with the automation probe")
var s0: State?
_ = waitFor(25) { s0 = state(); return s0.map { !$0.objects.isEmpty } ?? false }
guard let start = s0 else {
    check(false, "probe found in window titled e2e-fixture (windows: \(windows(app).map(title)))")
    finish()
}
log(describe(start))
check(start.tool == "Selection", "selection tool active (got \(start.tool))")
guard let orange = object(near: orangeRect, in: start), let blue = object(near: blueRect, in: start),
      let green = object(near: greenRect, in: start) else {
    check(false, "fixture shapes found by geometry"); finish()
}
check(blue.parent != nil && blue.parent == green.parent, "blue and green rects share a parent group")
let edits0 = start.editSteps
log("  undo stack: \(start.undoStack)")

// 2. Drag a plain shape
log("\n[drag] drag orange rect by (+90, +60) screen px")
front()
guard let orangeScreen = orange.screen else { check(false, "orange has a screen rect"); finish() }
let d = CGVector(dx: 90, dy: 60)
drag(from: CGPoint(x: orangeScreen.midX, y: orangeScreen.midY), by: d)
let expectDX = d.dx / start.zoom, expectDY = d.dy / start.zoom
var s1: State?
_ = waitFor(3) { s1 = state(); return s1.map { $0.editSteps > edits0 } ?? false }
guard let afterDrag = s1, let movedOrange = afterDrag.obj(orange.id) else { check(false, "state after drag"); finish() }
let movedBy = CGVector(dx: movedOrange.bounds.minX - orange.bounds.minX, dy: movedOrange.bounds.minY - orange.bounds.minY)
let tol = max(2, 0.1 * hypot(expectDX, expectDY))
check(abs(movedBy.dx - expectDX) <= tol && abs(movedBy.dy - expectDY) <= tol,
      "orange moved by ≈(\(Int(expectDX)), \(Int(expectDY))) canvas units (got \(movedBy))")
log("  undo stack: \(afterDrag.undoStack)")
check(afterDrag.editSteps == edits0 + 1, "drag recorded exactly one edit undo step (\(afterDrag.undoStack))")
for o in start.objects where o.id != orange.id {
    check(afterDrag.obj(o.id).map { near($0.bounds, o.bounds, 0.01) } ?? false, "\(o.kind) \(o.bounds) untouched by the drag")
}

// 3. Undo / redo with the real shortcuts
log("\n[undo] ⌘Z restores, ⇧⌘Z re-applies")
front()
key(kZ, .maskCommand)
check(waitFor(3) { state()?.obj(orange.id).map { near($0.bounds, orange.bounds, 0.01) } ?? false },
      "⌘Z puts orange back exactly at \(orange.bounds)")
front()
key(kZ, [.maskCommand, .maskShift])
check(waitFor(3) { state()?.obj(orange.id).map { near($0.bounds, movedOrange.bounds, 0.01) } ?? false },
      "⇧⌘Z moves orange again to \(movedOrange.bounds)")

// 4. Drag a group member → the whole group moves
log("\n[group] drag the blue rect (group member) by (-40, +50)")
guard let groupID = blue.parent, let group0 = start.obj(groupID),
      let blueNow = state()?.obj(blue.id), let blueScreen = blueNow.screen else { check(false, "group state"); finish() }
front()
drag(from: CGPoint(x: blueScreen.midX, y: blueScreen.midY), by: CGVector(dx: -40, dy: 50))
let gdx = -40 / start.zoom, gdy = 50 / start.zoom
let sg = state()
for (name, o) in [("blue", blue), ("green", green), ("group", group0)] {
    let now = sg?.obj(o.id)?.bounds ?? .null
    check(abs(now.minX - o.bounds.minX - gdx) <= max(2, abs(gdx) * 0.1) && abs(now.minY - o.bounds.minY - gdy) <= max(2, abs(gdy) * 0.1),
          "\(name) moved with the group by ≈(\(Int(gdx)), \(Int(gdy))) (now \(now))")
}
check(sg?.obj(orange.id).map { near($0.bounds, movedOrange.bounds, 0.01) } ?? false, "orange untouched by the group drag")
front()
key(kZ, .maskCommand)
check(waitFor(3) { state().map { s in [blue, green, group0].allSatisfy { o in s.obj(o.id).map { near($0.bounds, o.bounds, 0.01) } ?? false } } ?? false },
      "⌘Z puts the whole group back exactly")

// 5. Drag the line
log("\n[line] drag the line by (+30, +70)")
if let line = start.objects.first(where: { $0.topLevel && $0.bounds.width > 250 && $0.bounds.height < 20 }),
   let lineScreen = state()?.obj(line.id)?.screen {
    let before = state()!.obj(line.id)!.bounds
    front()
    drag(from: CGPoint(x: lineScreen.midX, y: lineScreen.midY), by: CGVector(dx: 30, dy: 70))
    let now = state()?.obj(line.id)?.bounds ?? .null
    check(abs(now.minY - before.minY - 70 / start.zoom) <= max(2, 7 / start.zoom) && abs(now.width - before.width) < 0.5,
          "line moved down ≈\(Int(70 / start.zoom)) and kept its length (\(before) → \(now))")
    front()
    key(kZ, .maskCommand)
    check(waitFor(3) { state()?.obj(line.id).map { near($0.bounds, before, 0.01) } ?? false }, "⌘Z puts the line back exactly")
} else {
    check(false, "line found in \(describe(start))")
}

// 6. Save, close, reopen
log("\n[save] ⌘S writes the moved orange; reopening shows it there")
let mtime0 = (try? FileManager.default.attributesOfItem(atPath: svgURL.path)[.modificationDate] as? Date) ?? nil
let expectedOrange = state()?.obj(orange.id)?.bounds ?? movedOrange.bounds
front()
key(kS, .maskCommand)
check(waitFor(5) {
    let m = (try? FileManager.default.attributesOfItem(atPath: svgURL.path)[.modificationDate] as? Date) ?? nil
    return m != nil && m != mtime0
}, "⌘S wrote the file")
pause(0.5)
front()
key(kW, .maskCommand)
check(waitFor(5) { fixtureWindow() == nil }, "⌘W closes the saved document without asking")
NSWorkspace.shared.open([svgURL], withApplicationAt: appURL, configuration: {
    let c = NSWorkspace.OpenConfiguration(); c.activates = true; return c
}()) { _, _ in }
var s2: State?
check(waitFor(20) { s2 = state(); return s2.map { !$0.objects.isEmpty } ?? false }, "reopened document has a probe")
if let reopened = s2 {
    check(object(near: expectedOrange, in: reopened) != nil, "orange reopened at its saved position \(expectedOrange)\n\(describe(reopened))")
    check(object(near: orangeRect, in: reopened) == nil, "orange is no longer at its original position")
    check(reopened.objects.count == start.objects.count, "same object count after reopen (\(start.objects.count) → \(reopened.objects.count))")
}

// 7. Closing an edited document asks first
log("\n[close] ⌘W on an edited document shows a save sheet")
if let reopened = s2, let o = object(near: expectedOrange, in: reopened), let sc = o.screen {
    let saved = try? Data(contentsOf: svgURL)
    front()
    drag(from: CGPoint(x: sc.midX, y: sc.midY), by: CGVector(dx: -50, dy: -30))
    front()
    key(kW, .maskCommand)
    var sheet: AXUIElement?
    check(waitFor(5) {
        sheet = fixtureWindow().flatMap { w in children(w).first { (attr($0, kAXRoleAttribute) as? String) == kAXSheetRole } }
        return sheet != nil
    }, "save sheet appears instead of closing silently")
    if let sheet, let dont = findFirst(sheet, { (attr($0, kAXRoleAttribute) as? String) == kAXButtonRole &&
                                                 ["Don’t Save", "Don't Save", "Delete"].contains(title($0)) }) {
        AXUIElementPerformAction(dont, kAXPressAction as CFString)
        check(waitFor(5) { fixtureWindow() == nil }, "Don't Save closes the window")
        check((try? Data(contentsOf: svgURL)) == saved, "file on disk unchanged after Don't Save")
    } else if let sheet {
        check(false, "Don't Save button in sheet (buttons: \(children(sheet).map(title)))")
    }
} else {
    check(false, "orange found after reopen for the close test")
}

// 8. Tabs: move a document's tab to its own window and merge it back — the document must keep
// its objects and undo (DocumentBasedMainView only wipes a document after it is really closed),
// and saving afterwards must write the full drawing, not an empty one.
log("\n[tabs] open two documents as tabs, Move Tab to New Window, Merge All Windows")
let secondURL = workDir.appendingPathComponent("e2e-second.svg")
try! """
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300">
  <circle cx="200" cy="150" r="60" fill="red"/>
  <rect x="20" y="20" width="60" height="40" fill="purple"/>
</svg>
""".write(to: secondURL, atomically: true, encoding: .utf8)
func openDoc(_ url: URL) {
    NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: {
        let c = NSWorkspace.OpenConfiguration(); c.activates = true; return c
    }()) { _, _ in }
}
func secondWindow() -> AXUIElement? { windows(app).first { title($0).contains("e2e-second") } }
func secondState() -> State? { secondWindow().flatMap(probe(in:)).flatMap(readState) }
func menuItem(_ menu: String, _ item: String) -> AXUIElement? {
    guard let bar = attr(app, kAXMenuBarAttribute) else { return nil }
    let barEl = bar as! AXUIElement
    guard let top = children(barEl).first(where: { title($0) == menu }) else { return nil }
    return findFirst(top) { (attr($0, kAXRoleAttribute) as? String) == kAXMenuItemRole && title($0) == item }
}
func pressMenu(_ menu: String, _ item: String) -> Bool {
    front()
    guard let mi = menuItem(menu, item) else { return false }
    let enabled = (attr(mi, kAXEnabledAttribute) as? Bool) ?? false
    return enabled && AXUIElementPerformAction(mi, kAXPressAction as CFString) == .success
}
func sameFrame(_ a: AXUIElement, _ b: AXUIElement) -> Bool {
    func frame(_ w: AXUIElement) -> CGRect? {
        guard let pv = attr(w, kAXPositionAttribute), let sv = attr(w, kAXSizeAttribute) else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &p); AXValueGetValue(sv as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }
    guard let fa = frame(a), let fb = frame(b) else { return false }
    return near(fa, fb, 2)
}

openDoc(secondURL)
var sec0: State?
check(waitFor(20) { sec0 = secondState(); return sec0.map { !$0.objects.isEmpty } ?? false }, "second document opens with a probe")
openDoc(svgURL)
var t0: State?
check(waitFor(20) { t0 = state(); return t0.map { !$0.objects.isEmpty } ?? false }, "fixture reopened next to the second document")
let tabbedTogether: Bool = {
    guard let f = fixtureWindow() else { return false }
    // A background tab is either absent from AXWindows or shares the frame of the selected tab.
    return secondWindow().map { sameFrame($0, f) } ?? true
}()
check(tabbedTogether, "both documents are tabs of one window (windows: \(windows(app).map(title)))")

if let t0, let o = object(near: expectedOrange, in: t0) {
    let count0 = t0.objects.count
    check(pressMenu("Window", "Move Tab to New Window"), "Window ▸ Move Tab to New Window is enabled and pressed")
    // A background tab is not listed in AXWindows; after the move both documents are.
    check(waitFor(5) { fixtureWindow() != nil && secondWindow() != nil },
          "fixture and second document are now in separate windows (windows: \(windows(app).map(title)))")
    pause(1.5) // longer than DocumentBasedMainView's deferred wipe
    let moved = state()
    check(moved?.objects.count == count0, "moved tab keeps all \(count0) objects (got \(moved?.objects.count ?? -1))")
    // The window left behind is on screen, so it must show its document (not a blank
    // suspended-tab placeholder) without being clicked first.
    var sec1: State?
    check(waitFor(3) { sec1 = secondState(); return sec1 != nil },
          "window left behind shows its document without being clicked (probe present)")
    check(sec1?.objects.count == sec0?.objects.count,
          "other document keeps all its objects after the tab move (\(sec0?.objects.count ?? -1) → \(sec1?.objects.count ?? -1))")
    check(moved?.obj(o.id).map { near($0.bounds, o.bounds, 0.01) } ?? false, "moved tab: orange unchanged by the move")

    // Edit + undo still work in the moved window.
    if let sc = moved?.obj(o.id)?.screen {
        let edits = moved?.editSteps ?? 0
        front()
        drag(from: CGPoint(x: sc.midX, y: sc.midY), by: CGVector(dx: 40, dy: 40))
        check(waitFor(3) { (state()?.editSteps ?? 0) > edits && !(state()?.obj(o.id).map { near($0.bounds, o.bounds, 0.5) } ?? true) },
              "drag works in the moved window")
        front()
        key(kZ, .maskCommand)
        check(waitFor(3) { state()?.obj(o.id).map { near($0.bounds, o.bounds, 0.01) } ?? false }, "⌘Z works in the moved window")
        check(secondState()?.objects.count == sec0?.objects.count,
              "the other window still shows its document while the fixture window is in front")
    } else {
        check(false, "orange has a screen rect in the moved window")
    }

    check(pressMenu("Window", "Merge All Windows"), "Window ▸ Merge All Windows is enabled and pressed")
    check(waitFor(5) {
        guard let f = fixtureWindow() else { return false }
        return secondWindow().map { sameFrame($0, f) } ?? true
    }, "windows merged back into tabs (windows: \(windows(app).map(title)))")
    pause(1.5)
    let merged = state()
    check(merged?.objects.count == count0, "after merge the fixture keeps all \(count0) objects (got \(merged?.objects.count ?? -1))")

    // Save after the move/merge must write the full drawing.
    var dragged: CGRect?
    if let sc = merged?.obj(o.id)?.screen {
        front()
        drag(from: CGPoint(x: sc.midX, y: sc.midY), by: CGVector(dx: -60, dy: 30))
        dragged = state()?.obj(o.id)?.bounds
        check(dragged.map { !near($0, o.bounds, 0.5) } ?? false, "drag works after the merge")
    } else {
        check(false, "orange has a screen rect after the merge")
    }
    let mtime1 = (try? FileManager.default.attributesOfItem(atPath: svgURL.path)[.modificationDate] as? Date) ?? nil
    front()
    key(kS, .maskCommand)
    check(waitFor(5) {
        let m = (try? FileManager.default.attributesOfItem(atPath: svgURL.path)[.modificationDate] as? Date) ?? nil
        return m != nil && m != mtime1
    }, "⌘S after move/merge wrote the file")
    pause(0.5)
    front()
    key(kW, .maskCommand)
    check(waitFor(5) { fixtureWindow() == nil }, "⌘W closes the saved fixture")
    openDoc(svgURL)
    var r: State?
    check(waitFor(20) { r = state(); return r.map { !$0.objects.isEmpty } ?? false }, "fixture reopens after move/merge/save")
    if let r {
        check(r.objects.count == count0, "saved file has all \(count0) objects (got \(r.objects.count))\n\(describe(r))")
        if let dragged { check(object(near: dragged, in: r) != nil, "orange saved at its dragged position \(dragged)") }
    }
} else {
    check(false, "orange found when reopening for the tab test")
}

// 9. Tools: draw with the Rectangle and Ellipse tools, nudge with the arrow keys, copy/paste,
// delete — each through the real menus/shortcuts, each undoable, none touching other objects.
log("\n[tools] draw rectangle + ellipse, arrow-key nudge, ⌘C/⌘V, Delete, each with ⌘Z")
let kV: CGKeyCode = 9, kC: CGKeyCode = 8, kA: CGKeyCode = 0
let kDelete: CGKeyCode = 51, kRight: CGKeyCode = 124, kDown: CGKeyCode = 125
func click(_ p: CGPoint) {
    mouse(.mouseMoved, p); pause(0.2)
    mouse(.leftMouseDown, p); pause(0.1)
    mouse(.leftMouseUp, p); pause(0.6)
}
/// Canvas point → CG screen point, derived from any object the probe reports on screen.
func screenPoint(_ c: CGPoint, _ s: State) -> CGPoint? {
    guard let o = s.objects.first(where: { $0.screen != nil && $0.bounds.width > 1 && $0.bounds.height > 1 }),
          let sc = o.screen else { return nil }
    return CGPoint(x: sc.minX + (c.x - o.bounds.minX) * s.zoom, y: sc.minY + (c.y - o.bounds.minY) * s.zoom)
}
func unchanged(_ before: State, _ after: State, except skip: Set<String>) -> Bool {
    before.objects.allSatisfy { o in skip.contains(o.id) || (after.obj(o.id).map { near($0.bounds, o.bounds, 0.01) } ?? false) }
}
/// Draws `canvasRect` with `tool` (selected via the Tools menu) and returns the new top-level object.
func draw(_ tool: String, menuItem item: String, _ canvasRect: CGRect) -> Obj? {
    guard let before = state(), let p0 = screenPoint(canvasRect.origin, before) else {
        check(false, "\(tool): canvas → screen mapping"); return nil
    }
    check(pressMenu("Tools", item), "Tools ▸ \(item) pressed")
    check(waitFor(3) { state()?.tool == tool }, "\(tool) tool active (got \(state()?.tool ?? "nil"))")
    front()
    drag(from: p0, by: CGVector(dx: canvasRect.width * before.zoom, dy: canvasRect.height * before.zoom))
    var after: State?
    _ = waitFor(3) { after = state(); return (after?.objects.count ?? 0) > before.objects.count }
    guard let after else { check(false, "\(tool): state after drawing"); return nil }
    let added = after.objects.filter { before.obj($0.id) == nil }
    check(added.count == 1, "\(tool) drag added exactly one object (added \(added.count))")
    guard let new = added.first else { return nil }
    check(near(new.bounds, canvasRect, max(3, 6 / before.zoom)), "\(tool) drawn at \(canvasRect) (got \(new.bounds))")
    check(after.editSteps == before.editSteps + 1, "\(tool) drawing is one edit undo step (\(after.undoStack))")
    check(unchanged(before, after, except: []), "\(tool) drawing left every other object untouched")
    front()
    key(kZ, .maskCommand)
    check(waitFor(3) { state().map { $0.obj(new.id) == nil && $0.objects.count == before.objects.count } ?? false },
          "⌘Z removes the drawn \(tool)")
    front()
    key(kZ, [.maskCommand, .maskShift])
    check(waitFor(3) { state()?.obj(new.id).map { near($0.bounds, new.bounds, 0.01) } ?? false },
          "⇧⌘Z brings the drawn \(tool) back")
    return new
}

tools: do {
    guard state() != nil else { check(false, "fixture open for the tools test"); break tools }
    // Empty canvas area below-right of the fixture's shapes.
    guard let rectObj = draw("Rectangle", menuItem: "Rectangle Tool", CGRect(x: 560, y: 420, width: 120, height: 70)) else { break tools }
    _ = draw("Ellipse", menuItem: "Ellipse Tool", CGRect(x: 420, y: 470, width: 90, height: 60))

    // Back to Selection with its single-key shortcut, select the rectangle by clicking it.
    front()
    key(kA)
    check(waitFor(3) { state()?.tool == "Selection" }, "A switches to the Selection tool (got \(state()?.tool ?? "nil"))")
    guard let s1 = state(), let rc = s1.obj(rectObj.id)?.screen else { check(false, "drawn rectangle on screen"); break tools }
    front()
    click(CGPoint(x: rc.midX, y: rc.midY))
    check(waitFor(3) { state()?.selected == [rectObj.id] }, "clicking the drawn rectangle selects only it (selected \(state()?.selected ?? []))")

    // Arrow-key nudge.
    guard let s2 = state(), let r2 = s2.obj(rectObj.id) else { break tools }
    front()
    key(kRight); key(kDown)
    var s3: State?
    _ = waitFor(3) { s3 = state(); return s3?.obj(rectObj.id).map { $0.bounds.minY > r2.bounds.minY } ?? false }
    if let s3, let r3 = s3.obj(rectObj.id) {
        let dx = r3.bounds.minX - r2.bounds.minX, dy = r3.bounds.minY - r2.bounds.minY
        check(dx > 0 && dy > 0 && abs(dx - dy) < 0.01 && abs(r3.bounds.width - r2.bounds.width) < 0.01,
              "→ then ↓ nudge the rectangle right and down by the same step (moved \(dx), \(dy))")
        check(unchanged(s2, s3, except: [rectObj.id]), "nudge left every other object untouched")
        front()
        key(kZ, .maskCommand); key(kZ, .maskCommand)
        check(waitFor(3) { state()?.obj(rectObj.id).map { near($0.bounds, r2.bounds, 0.01) } ?? false },
              "⌘Z twice undoes both nudges exactly")
    } else {
        check(false, "arrow keys moved the selected rectangle (\(s3?.obj(rectObj.id)?.bounds ?? .null) vs \(r2.bounds))")
    }

    // Copy / paste.
    guard let s4 = state() else { break tools }
    if s4.selected != [rectObj.id] {
        front(); click(CGPoint(x: s4.obj(rectObj.id)!.screen!.midX, y: s4.obj(rectObj.id)!.screen!.midY))
    }
    let s5 = state() ?? s4
    front()
    key(kC, .maskCommand)
    key(kV, .maskCommand)
    var s6: State?
    _ = waitFor(3) { s6 = state(); return (s6?.objects.count ?? 0) > s5.objects.count }
    let pasted = s6.map { s in s.objects.filter { s5.obj($0.id) == nil } } ?? []
    check(pasted.count == 1, "⌘C ⌘V pastes exactly one new object (got \(pasted.count))")
    if let p = pasted.first, let s6 {
        let src = s5.obj(rectObj.id)!.bounds
        check(abs(p.bounds.width - src.width) < 0.01 && abs(p.bounds.height - src.height) < 0.01,
              "pasted copy has the rectangle's size (\(p.bounds.size) vs \(src.size))")
        check(s6.selected == [p.id], "the pasted copy is selected")
        check(unchanged(s5, s6, except: []), "paste left every existing object untouched")
        front()
        key(kZ, .maskCommand)
        check(waitFor(3) { state().map { $0.obj(p.id) == nil && $0.objects.count == s5.objects.count } ?? false },
              "⌘Z removes the pasted copy")
    }

    // Delete.
    guard let s7 = state(), let rs = s7.obj(rectObj.id)?.screen else { break tools }
    front()
    click(CGPoint(x: rs.midX, y: rs.midY))
    check(waitFor(3) { state()?.selected == [rectObj.id] }, "rectangle selected again before Delete")
    let s8 = state() ?? s7
    front()
    key(kDelete)
    check(waitFor(3) { state().map { $0.obj(rectObj.id) == nil && $0.objects.count == s8.objects.count - 1 } ?? false },
          "Delete removes only the selected rectangle")
    if let s9 = state() { check(unchanged(s8, s9, except: [rectObj.id]), "Delete left every other object untouched") }
    front()
    key(kZ, .maskCommand)
    check(waitFor(3) { state()?.obj(rectObj.id).map { near($0.bounds, s8.obj(rectObj.id)!.bounds, 0.01) } ?? false },
          "⌘Z brings the deleted rectangle back in place")
}

finish()

