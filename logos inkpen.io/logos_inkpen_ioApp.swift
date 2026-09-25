import SwiftUI

@main
struct logos_inken_ioApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @FocusedObject var documentState: DocumentState?
    private var appState = AppState.shared

    @Environment(\.openWindow) private var openWindow

    @Environment(\.dismissWindow) private var dismissWindow

    @AppStorage("imagePreviewQuality") private var imagePreviewQuality: Double = 1.0
    init() {
        UserDefaults.standard.register(defaults: [
            "brushPreviewStyle": AppState.BrushPreviewStyle.fill.rawValue,
            "brushPreviewIsFinal": false
        ])
        let metalWorking = MetalComputeEngine.testMetalEngine()
        if !metalWorking {
            Log.metal("❌ Metal Engine Failed", level: .error)
        }
        _ = AppEventMonitor.shared
    }

    private func windowTitle(for fileURL: URL?) -> String {
        guard let fileURL = fileURL else { return "Untitled" }
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        if ["inkpen", "pdf", "svg"].contains(fileExtension) {
            return fileName
        } else {
            return fileURL.deletingPathExtension().lastPathComponent
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: InkpenDocument()) { file in
            DocumentBasedContentView(inkpenDocument: file.$document, fileURL: file.fileURL)
                .environment(appState)
                .navigationTitle(windowTitle(for: file.fileURL))
                .background(WindowAccessor { window in
                    guard let window = window else { return }
                    if window.isMiniaturized {
                        window.deminiaturize(nil)
                    }
                    window.isRestorable = false
                    window.tabbingMode = .preferred
                    window.tabbingIdentifier = "InkpenDocumentTabGroup"
                    let autosaveName: String
                    if let fileURL = file.fileURL {
                        autosaveName = "InkpenDoc_\(fileURL.path.hashValue)"
                    } else {
                        autosaveName = "InkpenUntitled_\(window.windowNumber)"
                    }
                    let hadSavedFrame = window.frameAutosaveName == autosaveName
                    if window.frameAutosaveName != autosaveName {
                        window.setFrameAutosaveName(autosaveName)
                    }
                    let isFirstDocumentWindow = NSDocumentController.shared.documents.count <= 1
                    if !hadSavedFrame, isFirstDocumentWindow, let screen = window.screen ?? NSScreen.main {
                        let visibleFrame = screen.visibleFrame
                        window.setFrame(visibleFrame, display: false)
                    }
                })
                .onAppear {
                    appState.setWindowActions(
                        openWindow: { id in openWindow(id: id) },
                        dismissWindow: { id in dismissWindow(id: id) }
                    )
                }
        }
        .commands {
            Group {
                CommandGroup(replacing: .importExport) {
                    Button("Document Setup…") {
                        openWindow(id: "onboarding-setup")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .help("Open Document Setup to configure document settings")
                    Divider()
                    Button("Import…") {
                        documentState?.showImportDialog()
                    }
                    .keyboardShortcut("i", modifiers: [.command])
                    .help("Import SVG, PDF, PNG")
                    Divider()
                    Button("Export SVG…") {
                        documentState?.exportSVG()
                    }
                    .keyboardShortcut("e", modifiers: [.command])
                    .help("Export as SVG (Scalable Vector Graphics)")
                    Button("Export PDF…") {
                        documentState?.exportPDF()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .help("Export as PDF (Portable Document Format)")
                    Button("Export PNG…") {
                        documentState?.exportPNG()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .control])
                    .help("Export as PNG (Portable Network Graphics)")
                    Divider()
                    Button("Export AutoDesk SVG…") {
                        documentState?.exportAutoDeskSVG()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .option])
                    .help("Export SVG at 96 DPI for AutoDesk applications")
                }
                CommandGroup(replacing: .appSettings) {
                    Menu("Default Tool") {
                        Button(AppState.shared.defaultTool == .selection ? "✓ Selection Tool (Arrow)" : "Selection Tool (Arrow)") {
                            AppState.shared.defaultTool = .selection
                        }
                        .help("Set selection tool as default for new documents")
                        Button(AppState.shared.defaultTool == .directSelection ? "✓ Direct Selection Tool" : "Direct Selection Tool") {
                            AppState.shared.defaultTool = .directSelection
                        }
                        .help("Set direct selection tool as default for new documents")
                        Divider()
                        Button(AppState.shared.defaultTool == .bezierPen ? "✓ Bezier Pen Tool" : "Bezier Pen Tool") {
                            AppState.shared.defaultTool = .bezierPen
                        }
                        .help("Set bezier pen tool as default for new documents")
                        Button(AppState.shared.defaultTool == .freehand ? "✓ Freehand Tool" : "Freehand Tool") {
                            AppState.shared.defaultTool = .freehand
                        }
                        .help("Set freehand tool as default for new documents")
                        Button(AppState.shared.defaultTool == .brush ? "✓ Brush Tool" : "Brush Tool") {
                            AppState.shared.defaultTool = .brush
                        }
                        .help("Set brush tool as default for new documents")
                        Divider()
                        Button(AppState.shared.defaultTool == .line ? "✓ Line Tool" : "Line Tool") {
                            AppState.shared.defaultTool = .line
                        }
                        .help("Set line tool as default for new documents")
                        Button(AppState.shared.defaultTool == .rectangle ? "✓ Rectangle Tool" : "Rectangle Tool") {
                            AppState.shared.defaultTool = .rectangle
                        }
                        .help("Set rectangle tool as default for new documents")
                        Button(AppState.shared.defaultTool == .circle ? "✓ Circle Tool" : "Circle Tool") {
                            AppState.shared.defaultTool = .circle
                        }
                        .help("Set circle tool as default for new documents")
                    }
                    Divider()
                    Button("Preferences...") {
                        openWindow(id: "app-preferences")
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                    .help("Open application preferences")
                }
                CommandGroup(replacing: .undoRedo) {
                    Button("Undo") {
                        documentState?.undo()
                    }
                    .keyboardShortcut("z", modifiers: [.command])
                    .disabled(documentState?.canUndo != true)
                    Button("Redo") {
                        documentState?.redo()
                    }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(documentState?.canRedo != true)
                }
                CommandGroup(replacing: .pasteboard) {
                    Button("Cut") {
                        documentState?.cut()
                    }
                    .keyboardShortcut("x", modifiers: [.command])
                    .disabled(documentState?.canCut != true)
                    Button("Copy") {
                        documentState?.copy()
                    }
                    .keyboardShortcut("c", modifiers: [.command])
                    .disabled(documentState?.canCopy != true)
                    Button("Paste") {
                        documentState?.paste()
                    }
                    .keyboardShortcut("v", modifiers: [.command])
                    .disabled(documentState?.canPaste != true)
                    Button("Paste in Back") {
                        documentState?.pasteInBack()
                    }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .disabled(documentState?.canPaste != true)
                    Button("Paste in Front") {
                        documentState?.pasteInFront()
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(documentState?.canPaste != true)
                    Button("Delete") {
                        documentState?.delete()
                    }
                    .keyboardShortcut(.delete)
                    .disabled(documentState?.hasSelection != true)
                }
                CommandGroup(replacing: .textEditing) {
                    Button("Select All") {
                        documentState?.selectAll()
                    }
                    .keyboardShortcut("a", modifiers: [.command])
                    Button("Deselect All") {
                        documentState?.deselectAll()
                    }
                    .keyboardShortcut(.tab)
                    .disabled(documentState?.hasSelection != true)
                }
            }
            Group {
                CommandMenu("Object") {
                    Menu("Arrange") {
                        Button("Bring to Front") {
                            documentState?.bringToFront()
                        }
                        .keyboardShortcut("]", modifiers: [.command, .shift])
                        .disabled(documentState?.hasSelection != true)
                        Button("Bring Forward") {
                            documentState?.bringForward()
                        }
                        .keyboardShortcut("]", modifiers: [.command])
                        .disabled(documentState?.hasSelection != true)
                        Button("Send Backward") {
                            documentState?.sendBackward()
                        }
                        .keyboardShortcut("[", modifiers: [.command])
                        .disabled(documentState?.hasSelection != true)
                        Button("Send to Back") {
                            documentState?.sendToBack()
                        }
                        .keyboardShortcut("[", modifiers: [.command, .shift])
                        .disabled(documentState?.hasSelection != true)
                    }
                    Button("Align") {
                        documentState?.alignByOrigin()
                    }
                    .keyboardShortcut("a", modifiers: [.command, .option])
                    .disabled(documentState?.canAlign != true)
                    Button("Align X") {
                        documentState?.alignByOriginX()
                    }
                    .keyboardShortcut("a", modifiers: [.command, .option, .shift])
                    .disabled(documentState?.canAlign != true)
                    Button("Align Y") {
                        documentState?.alignByOriginY()
                    }
                    .keyboardShortcut("a", modifiers: [.command, .option, .control])
                    .disabled(documentState?.canAlign != true)
                    Button("Group") {
                        documentState?.groupObjects()
                    }
                    .keyboardShortcut("g", modifiers: [.command])
                    .disabled(documentState?.canGroup != true)
                    Button("Ungroup") {
                        documentState?.ungroupObjects()
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(documentState?.canUngroup != true)
                    Divider()
                    Button("Flatten") {
                        documentState?.flattenObjects()
                    }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                    .disabled(documentState?.canFlatten != true)
                    .help("Flatten multiple shapes - preserves individual colors while enabling Scale, Rotate and Shear tools")
                    Button("Unflatten") {
                        documentState?.unflattenObjects()
                    }
                    .keyboardShortcut("f", modifiers: [.command, .option, .shift])
                    .disabled(documentState?.canUnflatten != true)
                    .help("Restore flattened group back to individual shapes with original colors")
                    Divider()
                    Button("Duplicate") {
                        documentState?.duplicate()
                    }
                    .keyboardShortcut("d", modifiers: [.command])
                    .disabled(documentState?.hasSelection != true)
                    Button("Move...") {
                        documentState?.showMoveDialog = true
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    .disabled(documentState?.hasSelection != true)
                    Divider()
                    Button("Lock") {
                        documentState?.lockSelectedObjects()
                    }
                    .keyboardShortcut("2", modifiers: [.command])
                    .disabled(documentState?.hasSelection != true)
                    .help("Lock selected objects")
                    Button("Unlock All") {
                        documentState?.unlockAllObjects()
                    }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                    .help("Unlock all objects in the document")
                    Button("Hide") {
                        documentState?.hideSelectedObjects()
                    }
                    .keyboardShortcut("3", modifiers: [.command])
                    .disabled(documentState?.hasSelection != true)
                    .help("Hide selected objects")
                    Button("Show All") {
                        documentState?.showAllObjects()
                    }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                    .help("Show all hidden objects")
                    Divider()
                    Button("Create Outlines") {
                        documentState?.createOutlines()
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(!(documentState?.document?.viewState.selectedObjectIDs.isEmpty == false))
                    .help("Convert selected text objects to vector outlines")
                    Divider()
                    Menu("Links") {
                        Button("Embed Linked Images in Selection") {
                            documentState?.embedSelectedLinkedImages()
                        }
                        .disabled(documentState?.canEmbedLinkedImages != true)
                        .help("Embed the image data into the document for portability. Default behavior keeps links.")
                    }
                    Divider()
                    Button("Make Compound Path") {
                        documentState?.makeCompoundPath()
                    }
                    .keyboardShortcut("8", modifiers: [.command])
                    .disabled(documentState?.canMakeCompoundPath != true)
                    .help("Combine selected paths into a compound path with holes")
                    Button("Release Compound Path") {
                        documentState?.releaseCompoundPath()
                    }
                    .keyboardShortcut("8", modifiers: [.command, .option])
                    .disabled(documentState?.canReleaseCompoundPath != true)
                    .help("Break compound path into separate individual paths")
                    Divider()
                    Button("Make Looping Path") {
                        documentState?.makeLoopingPath()
                    }
                    .keyboardShortcut("9", modifiers: [.command])
                    .disabled(documentState?.canMakeLoopingPath != true)
                    .help("Combine selected paths into a looping path with winding fill rule")
                    Button("Release Looping Path") {
                        documentState?.releaseLoopingPath()
                    }
                    .keyboardShortcut("9", modifiers: [.command, .option])
                    .disabled(documentState?.canReleaseLoopingPath != true)
                    .help("Break looping path into separate individual paths")
                    Divider()
                    Button("Unwrap Warp Object") {
                        documentState?.unwrapWarpObject()
                    }
                    .keyboardShortcut("w", modifiers: [.command, .option, .shift])
                    .disabled(documentState?.canUnwrapWarpObject != true)
                    .help("Unwrap the selected warp object back to its original shape")
                    Button("Expand Warp Object") {
                        documentState?.expandWarpObject()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .option, .shift])
                    .disabled(documentState?.canExpandWarpObject != true)
                    .help("Permanently apply the warp transformation to create a regular shape")
                    Divider()
                    Button("Clean Duplicate Points") {
                        documentState?.cleanupDuplicatePoints()
                    }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                    .help("Remove overlapping points and merge their curve data smoothly")
                    Button("Clean All Duplicate Points") {
                        documentState?.cleanupAllDuplicatePoints()
                    }
                    .keyboardShortcut("k", modifiers: [.command, .option])
                    .help("Clean duplicate points in all shapes in the document")
                }
                CommandMenu("Panel") {
                    Button(action: { appState.selectedPanelTab = .layers }) {
                        Label("Layer", systemImage: PanelTab.layers.iconName)
                    }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    Button(action: { appState.selectedPanelTab = .properties }) {
                        Label("Paint", systemImage: PanelTab.properties.iconName)
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    Button(action: { appState.selectedPanelTab = .gradient }) {
                        Label("Grade", systemImage: PanelTab.gradient.iconName)
                    }
                    .keyboardShortcut("g", modifiers: [.command, .control])
                    Button(action: { appState.selectedPanelTab = .color }) {
                        Label("Ink", systemImage: PanelTab.color.iconName)
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    Button(action: { appState.selectedPanelTab = .pathOps }) {
                        Label("Path", systemImage: PanelTab.pathOps.iconName)
                    }
                    .keyboardShortcut("o", modifiers: [.command, .control])
                    Button(action: { appState.selectedPanelTab = .font }) {
                        Label("Font", systemImage: PanelTab.font.iconName)
                    }
                    .keyboardShortcut("f", modifiers: [.command, .control])
                }
                CommandGroup(replacing: .sidebar) {
                    Button("Zoom In") {
                        documentState?.zoomIn()
                    }
                    .keyboardShortcut("=", modifiers: [.command])
                    Button("Zoom Out") {
                        documentState?.zoomOut()
                    }
                    .keyboardShortcut("-", modifiers: [.command])
                    Button("Fit to Page") {
                        documentState?.fitToPage()
                    }
                    .keyboardShortcut("0", modifiers: [.command])
                    Button("Actual Size") {
                        documentState?.actualSize()
                    }
                    .keyboardShortcut("1", modifiers: [.command])
                    Divider()
                    Button {
                        documentState?.toggleColorKeylineView()
                    } label: {
                        HStack {
                            if documentState?.document?.viewState.viewMode == .keyline {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Color/Keyline View")
                        }
                    }
                    .keyboardShortcut("y", modifiers: [.command])
                    Button {
                        appState.showClippingInKeyline.toggle()
                    } label: {
                        HStack {
                            if appState.showClippingInKeyline {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Show Clipping in Keyline Mode")
                        }
                    }
                    Button {
                        documentState?.toggleRulers()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.showRulers == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Rulers")
                        }
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    Button {
                        documentState?.toggleGrid()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.showGrid == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Grid")
                        }
                    }
                    .keyboardShortcut("'", modifiers: [.command])
                    Button {
                        documentState?.toggleSnapToGrid()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.snapToGrid == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Snap to Grid")
                        }
                    }
                    .keyboardShortcut(";", modifiers: [.command])
                    Button {
                        documentState?.toggleSnapToPoint()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.snapToPoint == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Toggle Snap to Point")
                        }
                    }
                    .keyboardShortcut(".", modifiers: [.command])
                    Divider()
                    Button {
                        documentState?.toggleGuides()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.showGuides == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Show Guides")
                        }
                    }
                    .keyboardShortcut(";", modifiers: [.command, .shift])
                    Button {
                        documentState?.toggleLockGuides()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.guidesLocked == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Lock Guides")
                        }
                    }
                    .keyboardShortcut("l", modifiers: [.command, .option])
                    Button {
                        documentState?.toggleSnapToGuides()
                    } label: {
                        HStack {
                            if documentState?.document?.gridSettings.snapToGuides == true {
                                Image(systemName: "checkmark")
                            }
                            Text("Snap to Guides")
                        }
                    }
                    Button("Clear Guides") {
                        documentState?.clearGuides()
                    }
                    .disabled(documentState?.document?.getGuideShapes().isEmpty ?? true)
                }
                CommandMenu("Tools") {
                    Button("Selection Tool") {
                        documentState?.switchToTool(.selection)
                    }
                    .keyboardShortcut("a", modifiers: [])
                    .help("Switch to selection tool")
                    Button("Direct Selection Tool") {
                        documentState?.switchToTool(.directSelection)
                    }
                    .keyboardShortcut("d", modifiers: [])
                    .help("Switch to direct selection tool")
                    Button("Convert Anchor Point Tool") {
                        documentState?.switchToTool(.convertAnchorPoint)
                    }
                    .keyboardShortcut("c", modifiers: [])
                    .help("Switch to convert anchor point tool")
                    Divider()
                    Button("Scale Tool") {
                        documentState?.switchToTool(.scale)
                    }
                    .keyboardShortcut("s", modifiers: [])
                    .help("Switch to scale tool")
                    Button("Rotate Tool") {
                        documentState?.switchToTool(.rotate)
                    }
                    .keyboardShortcut("r", modifiers: [])
                    .help("Switch to rotate tool")
                    Button("Shear Tool") {
                        documentState?.switchToTool(.shear)
                    }
                    .keyboardShortcut("x", modifiers: [])
                    .help("Switch to shear tool")
                    Button("Warp Tool") {
                        documentState?.switchToTool(.warp)
                    }
                    .keyboardShortcut("w", modifiers: [])
                    .help("Switch to warp tool")
                    Divider()
                    Button("Bezier Pen Tool") {
                        documentState?.switchToTool(.bezierPen)
                    }
                    .keyboardShortcut("p", modifiers: [])
                    .help("Switch to bezier pen tool")
                    Button("Freehand Tool") {
                        documentState?.switchToTool(.freehand)
                    }
                    .keyboardShortcut("f", modifiers: [])
                    .help("Switch to freehand tool")
                    Button("Brush Tool") {
                        documentState?.switchToTool(.brush)
                    }
                    .keyboardShortcut("b", modifiers: [])
                    .help("Switch to brush tool")
                    Button("Marker Tool") {
                        documentState?.switchToTool(.marker)
                    }
                    .keyboardShortcut("m", modifiers: [])
                    .help("Switch to marker tool")
                    Button("Font Tool") {
                        documentState?.switchToTool(.font)
                    }
                    .keyboardShortcut("t", modifiers: [])
                    .help("Switch to font tool")
                    Divider()
                    Button("Line Tool") {
                        documentState?.switchToTool(.line)
                    }
                    .keyboardShortcut("l", modifiers: [])
                    .help("Switch to line tool")
                    Button("Rectangle Tool") {
                        documentState?.switchToTool(.rectangle)
                    }
                    .keyboardShortcut("r", modifiers: [.option])
                    .help("Switch to rectangle tool")
                    Button("Square Tool") {
                        documentState?.switchToTool(.square)
                    }
                    .keyboardShortcut("s", modifiers: [.option])
                    .help("Switch to square tool")
                    Button("Rounded Rectangle Tool") {
                        documentState?.switchToTool(.roundedRectangle)
                    }
                    .keyboardShortcut("r", modifiers: [.shift, .option])
                    .help("Switch to rounded rectangle tool")
                    Button("Pill Tool") {
                        documentState?.switchToTool(.pill)
                    }
                    .keyboardShortcut("p", modifiers: [.shift, .option])
                    .help("Switch to pill tool")
                    Button("Circle Tool") {
                        documentState?.switchToTool(.circle)
                    }
                    .keyboardShortcut("c", modifiers: [.option])
                    .help("Switch to circle tool")
                    Button("Ellipse Tool") {
                        documentState?.switchToTool(.ellipse)
                    }
                    .keyboardShortcut("e", modifiers: [])
                    .help("Switch to ellipse tool")
                    Button("Oval Tool") {
                        documentState?.switchToTool(.oval)
                    }
                    .keyboardShortcut("o", modifiers: [])
                    .help("Switch to oval tool")
                    Button("Egg Tool") {
                        documentState?.switchToTool(.egg)
                    }
                    .keyboardShortcut("e", modifiers: [.shift])
                    .help("Switch to egg tool")
                    Button("Cone Tool") {
                        documentState?.switchToTool(.cone)
                    }
                    .keyboardShortcut("c", modifiers: [.shift, .option])
                    .help("Switch to cone tool")
                    Divider()
                    Button("Equilateral Triangle Tool") {
                        documentState?.switchToTool(.equilateralTriangle)
                    }
                    .keyboardShortcut("t", modifiers: [.shift])
                    .help("Switch to equilateral triangle tool")
                    Button("Isosceles Triangle Tool") {
                        documentState?.switchToTool(.isoscelesTriangle)
                    }
                    .keyboardShortcut("i", modifiers: [.shift])
                    .help("Switch to isosceles triangle tool")
                    Button("Right Triangle Tool") {
                        documentState?.switchToTool(.rightTriangle)
                    }
                    .keyboardShortcut("t", modifiers: [.shift, .option])
                    .help("Switch to right triangle tool")
                    Button("Acute Triangle Tool") {
                        documentState?.switchToTool(.acuteTriangle)
                    }
                    .keyboardShortcut("a", modifiers: [.shift])
                    .help("Switch to acute triangle tool")
                    Divider()
                    Button("Star Tool") {
                        documentState?.switchToTool(.star)
                    }
                    .keyboardShortcut("s", modifiers: [.shift])
                    .help("Switch to star tool")
                    Button("Polygon Tool") {
                        documentState?.switchToTool(.polygon)
                    }
                    .keyboardShortcut("p", modifiers: [.option])
                    .help("Switch to polygon tool")
                    Button("Pentagon Tool") {
                        documentState?.switchToTool(.pentagon)
                    }
                    .keyboardShortcut("5", modifiers: [])
                    .help("Switch to pentagon tool")
                    Button("Hexagon Tool") {
                        documentState?.switchToTool(.hexagon)
                    }
                    .keyboardShortcut("6", modifiers: [])
                    .help("Switch to hexagon tool")
                    Button("Heptagon Tool") {
                        documentState?.switchToTool(.heptagon)
                    }
                    .keyboardShortcut("7", modifiers: [])
                    .help("Switch to heptagon tool")
                    Button("Octagon Tool") {
                        documentState?.switchToTool(.octagon)
                    }
                    .keyboardShortcut("8", modifiers: [])
                    .help("Switch to octagon tool")
                    Divider()
                    Button("Eyedropper Tool") {
                        documentState?.switchToTool(.eyedropper)
                    }
                    .keyboardShortcut("i", modifiers: [])
                    .help("Switch to eyedropper tool")
                    Button("Hand Tool") {
                        documentState?.switchToTool(.hand)
                    }
                    .keyboardShortcut("h", modifiers: [])
                    .help("Switch to hand tool")
                    Button("Zoom Tool") {
                        documentState?.switchToTool(.zoom)
                    }
                    .keyboardShortcut("z", modifiers: [])
                    .help("Switch to zoom tool")
                    Button("Gradient Tool") {
                        documentState?.switchToTool(.gradient)
                    }
                    .keyboardShortcut("g", modifiers: [])
                    .help("Switch to gradient tool")
                    Button("Corner Radius Tool") {
                        documentState?.switchToTool(.cornerRadius)
                    }
                    .keyboardShortcut(.upArrow, modifiers: [.control])
                    .help("Switch to corner radius tool")
                }
                CommandMenu("Debug") {
                    Button(action: {
                        appState.showSpatialIndexBounds.toggle()
                    }) {
                        Label(appState.showSpatialIndexBounds ? "Hide Spatial Index Bounds" : "Show Spatial Index Bounds", systemImage: "rectangle.dashed")
                    }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .help("Toggle spatial index bounds overlay (red dashed boxes)")
                    Divider()
                    Toggle(isOn: Binding(
                        get: { ApplicationSettings.shared.embedImagesByDefault },
                        set: { ApplicationSettings.shared.embedImagesByDefault = $0 }
                    )) {
                        HStack {
                            if ApplicationSettings.shared.embedImagesByDefault {
                                Image(systemName: "checkmark")
                            }
                            Text("Embed Images by Default")
                        }
                    }
                    .help("When enabled, imported images are embedded in the document. When disabled, images are linked by path.")
                    Menu("Image Preview Quality: \(Int(imagePreviewQuality * 100))%") {
                        Button("10%") {
                            imagePreviewQuality = 0.1
                            MetalImageTileRenderer.shared?.clearCache()
                        }
                        Button("20%") {
                            imagePreviewQuality = 0.2
                            MetalImageTileRenderer.shared?.clearCache()
                        }
                        Button("30%") {
                            imagePreviewQuality = 0.3
                            MetalImageTileRenderer.shared?.clearCache()
                        }
                        Button("50%") {
                            imagePreviewQuality = 0.5
                            MetalImageTileRenderer.shared?.clearCache()
                        }
                        Button("75%") {
                            imagePreviewQuality = 0.75
                            MetalImageTileRenderer.shared?.clearCache()
                        }
                        Button("100%") {
                            imagePreviewQuality = 1.0
                            MetalImageTileRenderer.shared?.clearCache()
                        }
                    }
                    .help("Controls the resolution of cached image previews. Lower values use less memory but may appear pixelated when zoomed in.")
                }
                if SandboxChecker.isNotSandboxed {
                    CommandMenu("Donate") {
                        Button(action: {
                            if let url = URL(string: "https://www.paypal.com/ncp/payment/3DTH3S7XARK98") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Tip Jar", systemImage: "dollarsign.circle")
                        }
                        .help("Support the developer with a tip via PayPal")
                    }
                    CommandGroup(replacing: .help) {
                        Button(action: {
                            openLogosInkPenHelp()
                        }) {
                            Label("Logos InkPen Help", systemImage: "questionmark.circle")
                        }
                        .keyboardShortcut("?", modifiers: .command)
                        .help("Open Logos InkPen Help documentation")
                    }
                    CommandGroup(after: .help) {
                        Divider()
                        Button(action: {
                            if let url = URL(string: "https://www.paypal.com/ncp/payment/3DTH3S7XARK98") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Tip Jar", systemImage: "dollarsign.circle")
                        }
                        .help("Support the developer with a tip via PayPal")
                    }
                }
            }
        }
        Window("Document Setup", id: "onboarding-setup") {
            NewDocumentSetupView(
                isPresented: .constant(true),
                onDocumentCreated: { newDoc, _ in
                    appState.pendingNewDocument = newDoc
                    dismissWindow(id: "onboarding-setup")
                    appState.shouldShowDocumentSetup = false
                    NSDocumentController.shared.newDocument(nil)
                }
            )
            .environment(appState)
        }
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: Set<String>())
        Window("Preferences", id: "app-preferences") {
            PreferencesView()
                .environment(appState)
                .background(WindowAccessor { window in
                    window?.tabbingMode = .disallowed
                })
        }
        .windowResizability(.contentMinSize)
    }
}

class ClipboardManager {
    static let shared = ClipboardManager()

    private let pasteboard = NSPasteboard.general
    private let vectorObjectsType = NSPasteboard.PasteboardType("io.logos.logos-inkpen-io.vectorObjects")

    private init() {}

    private func regenerateUUIDsForShapes(_ shapes: [VectorShape]) -> ([VectorShape], [UUID: UUID]) {
        var oldToNewID: [UUID: UUID] = [:]
        for shape in shapes {
            oldToNewID[shape.id] = UUID()
        }
        var newShapes: [VectorShape] = []
        for shape in shapes {
            var newShape = shape
            newShape.id = oldToNewID[shape.id] ?? UUID()
            if !newShape.memberIDs.isEmpty {
                newShape.memberIDs = newShape.memberIDs.map { oldToNewID[$0] ?? $0 }
            }
            if !newShape.groupedShapes.isEmpty {
                newShape.groupedShapes = newShape.groupedShapes.map { childShape in
                    var newChild = childShape
                    newChild.id = UUID()
                    return newChild
                }
            }
            newShapes.append(newShape)
        }
        return (newShapes, oldToNewID)
    }

    private func regenerateUUIDs(for shape: VectorShape) -> VectorShape {
        var newShape = shape
        newShape.id = UUID()
        if !newShape.groupedShapes.isEmpty {
            newShape.groupedShapes = newShape.groupedShapes.map { childShape in
                regenerateUUIDs(for: childShape)
            }
        }
        return newShape
    }

    func canPaste() -> Bool {
        return pasteboard.data(forType: vectorObjectsType) != nil
    }

    func cut(from document: VectorDocument) {
        copy(from: document)
        document.removeSelectedObjects()
    }

    private func collectShapeAndMembers(
        _ shape: VectorShape,
        from document: VectorDocument,
        into out: inout [VectorShape],
        visited: inout Set<UUID>
    ) {
        guard !visited.contains(shape.id) else { return }
        visited.insert(shape.id)
        out.append(shape)
        for memberID in shape.memberIDs {
            if let memberObj = document.snapshot.objects[memberID] {
                collectShapeAndMembers(memberObj.shape, from: document, into: &out, visited: &visited)
            }
        }
    }

    func copy(from document: VectorDocument) {
        var shapesToCopy: [VectorShape] = []
        var copiedShapeIDs: Set<UUID> = []
        var textToCopy: [VectorText] = []
        for objectID in document.viewState.selectedObjectIDs {
            if let vectorObject = document.findObject(by: objectID) {
                switch vectorObject.objectType {
                case .text(let shape):
                    if let textContent = shape.textContent {
                        let originalText = document.findText(by: objectID)
                        let originalAreaSize = originalText?.areaSize ?? shape.areaSize
                        let typography = originalText?.typography ?? shape.typography ?? TypographyProperties(strokeColor: .black, fillColor: .black)
                        let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                        let vectorText = VectorText(
                            content: textContent,
                            typography: typography,
                            position: position,
                            transform: .identity,
                            isVisible: shape.isVisible,
                            isLocked: shape.isLocked,
                            isEditing: false,
                                layerIndex: vectorObject.layerIndex,
                                cursorPosition: 0,
                                areaSize: originalAreaSize
                            )
                            textToCopy.append(vectorText)
                        }
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    collectShapeAndMembers(shape, from: document, into: &shapesToCopy, visited: &copiedShapeIDs)
                }
            }
        }
        let clipboardData = ClipboardData(shapes: shapesToCopy, texts: textToCopy)
        do {
            let data = try JSONEncoder().encode(clipboardData)
            pasteboard.clearContents()
            pasteboard.setData(data, forType: vectorObjectsType)
        } catch {
            Log.error("❌ Failed to copy objects: \(error)", category: .error)
        }
    }

    func paste(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            guard let selectedLayerId = document.settings.selectedLayerId,
                  let layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId }) else { return }
            if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                Log.error("❌ Cannot paste into locked layer '\(document.snapshot.layers[layerIndex].name)'", category: .error)
                return
            }
            if layerIndex < document.snapshot.layers.count {
                let layerName = document.snapshot.layers[layerIndex].name
                if layerName == "Canvas" || layerName == "Pasteboard" || layerName == "Guides" {
                    Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                    return
                }
            }
            var newObjectIDs: Set<UUID> = []
            let (newShapes, _) = regenerateUUIDsForShapes(clipboardData.shapes)
            var memberIDSet = Set<UUID>()
            for shape in newShapes {
                if !shape.memberIDs.isEmpty {
                    memberIDSet.formUnion(shape.memberIDs)
                }
            }
            var topLevelObjects: [VectorObject] = []
            var memberObjects: [VectorObject] = []
            for shape in newShapes {
                let obj = VectorObject(shape: shape, layerIndex: layerIndex)
                if memberIDSet.contains(shape.id) {
                    memberObjects.append(obj)
                } else {
                    topLevelObjects.append(obj)
                    newObjectIDs.insert(shape.id)
                }
            }
            let textObjects = clipboardData.texts.map { text -> VectorObject in
                var newText = text
                newText.id = UUID()
                newText.layerIndex = layerIndex
                let textShape = VectorShape.from(newText)
                newObjectIDs.insert(newText.id)
                return VectorObject(shape: textShape, layerIndex: layerIndex)
            }
            for memberObj in memberObjects {
                document.snapshot.objects[memberObj.id] = memberObj
            }
            let objectsToAdd = topLevelObjects + textObjects
            if !objectsToAdd.isEmpty {
                let currentTool = document.viewState.currentTool
                let command = AddObjectCommand(objects: objectsToAdd)
                document.commandManager.execute(command)
                if currentTool != .selection && currentTool != .directSelection {
                    document.viewState.currentTool = .selection
                }
                document.viewState.selectedObjectIDs = newObjectIDs
            }
        } catch {
            Log.error("❌ Failed to paste objects: \(error)", category: .error)
        }
    }

    func pasteInBack(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            guard let selectedLayerId = document.settings.selectedLayerId,
                  let layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId }) else { return }
            if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                Log.error("❌ Cannot paste into locked layer '\(document.snapshot.layers[layerIndex].name)'", category: .error)
                return
            }
            if layerIndex < document.snapshot.layers.count {
                let layerName = document.snapshot.layers[layerIndex].name
                if layerName == "Canvas" || layerName == "Pasteboard" || layerName == "Guides" {
                    Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                    return
                }
            }
            var newObjectIDs: Set<UUID> = []
            let (newShapes, _) = regenerateUUIDsForShapes(clipboardData.shapes)
            var memberIDSet = Set<UUID>()
            for shape in newShapes {
                if !shape.memberIDs.isEmpty {
                    memberIDSet.formUnion(shape.memberIDs)
                }
            }
            var topLevelObjects: [VectorObject] = []
            var memberObjects: [VectorObject] = []
            for shape in newShapes {
                let obj = VectorObject(shape: shape, layerIndex: layerIndex)
                if memberIDSet.contains(shape.id) {
                    memberObjects.append(obj)
                } else {
                    topLevelObjects.append(obj)
                    newObjectIDs.insert(shape.id)
                }
            }
            let textObjects = clipboardData.texts.map { text -> VectorObject in
                var newText = text
                newText.id = UUID()
                newText.layerIndex = layerIndex
                let textShape = VectorShape.from(newText)
                newObjectIDs.insert(newText.id)
                return VectorObject(shape: textShape, layerIndex: layerIndex)
            }
            for memberObj in memberObjects {
                document.snapshot.objects[memberObj.id] = memberObj
            }
            let objectsToAdd = topLevelObjects + textObjects
            if !objectsToAdd.isEmpty {
                let currentTool = document.viewState.currentTool
                let position: AddObjectAtPositionCommand.InsertPosition
                if !document.viewState.selectedObjectIDs.isEmpty {
                    position = .beforeSelection(document.viewState.selectedObjectIDs)
                } else {
                    position = .back
                }
                let command = AddObjectAtPositionCommand(objects: objectsToAdd, position: position)
                document.commandManager.execute(command)
                if currentTool != .selection && currentTool != .directSelection {
                    document.viewState.currentTool = .selection
                }
                document.viewState.selectedObjectIDs = newObjectIDs
            }
        } catch {
            Log.error("❌ Failed to paste in back: \(error)", category: .error)
        }
    }

    func pasteInFront(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            guard let selectedLayerId = document.settings.selectedLayerId,
                  let layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId }) else { return }
            if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                Log.error("❌ Cannot paste into locked layer '\(document.snapshot.layers[layerIndex].name)'", category: .error)
                return
            }
            if layerIndex < document.snapshot.layers.count {
                let layerName = document.snapshot.layers[layerIndex].name
                if layerName == "Canvas" || layerName == "Pasteboard" || layerName == "Guides" {
                    Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                    return
                }
            }
            var newObjectIDs: Set<UUID> = []
            let (newShapes, _) = regenerateUUIDsForShapes(clipboardData.shapes)
            var memberIDSet = Set<UUID>()
            for shape in newShapes {
                if !shape.memberIDs.isEmpty {
                    memberIDSet.formUnion(shape.memberIDs)
                }
            }
            var topLevelObjects: [VectorObject] = []
            var memberObjects: [VectorObject] = []
            for shape in newShapes {
                let obj = VectorObject(shape: shape, layerIndex: layerIndex)
                if memberIDSet.contains(shape.id) {
                    memberObjects.append(obj)
                } else {
                    topLevelObjects.append(obj)
                    newObjectIDs.insert(shape.id)
                }
            }
            let textObjects = clipboardData.texts.map { text -> VectorObject in
                var newText = text
                newText.id = UUID()
                newText.layerIndex = layerIndex
                let textShape = VectorShape.from(newText)
                newObjectIDs.insert(newText.id)
                return VectorObject(shape: textShape, layerIndex: layerIndex)
            }
            for memberObj in memberObjects {
                document.snapshot.objects[memberObj.id] = memberObj
            }
            let objectsToAdd = topLevelObjects + textObjects
            if !objectsToAdd.isEmpty {
                let currentTool = document.viewState.currentTool
                let position: AddObjectAtPositionCommand.InsertPosition
                if !document.viewState.selectedObjectIDs.isEmpty {
                    position = .afterSelection(document.viewState.selectedObjectIDs)
                } else {
                    position = .front
                }
                let command = AddObjectAtPositionCommand(objects: objectsToAdd, position: position)
                document.commandManager.execute(command)
                if currentTool != .selection && currentTool != .directSelection {
                    document.viewState.currentTool = .selection
                }
                document.viewState.selectedObjectIDs = newObjectIDs
            }
        } catch {
            Log.error("❌ Failed to paste in front: \(error)", category: .error)
        }
    }
}

struct ClipboardData: Codable {
    let shapes: [VectorShape]
    let texts: [VectorText]
}

func openLogosInkPenHelp() {
    let helpBookName = "LogosInkPenHelp"
    if let helpBookPath = Bundle.main.path(forResource: helpBookName, ofType: "help") {
        let helpBookURL = URL(fileURLWithPath: helpBookPath)
        let indexPath = helpBookURL.appendingPathComponent("Contents/Resources/en.lproj/index.html")
        if FileManager.default.fileExists(atPath: indexPath.path) {
            NSWorkspace.shared.open(indexPath)
        } else {
            NSWorkspace.shared.open(helpBookURL)
            Log.warning("📚 Help index not found, opening Help Book root", category: .general)
        }
    } else {
        let projectHelpPath = "/Users/toddbruss/Documents/GitHub/logos/logos inkpen.io/LogosInkPenHelp.help/Contents/Resources/en.lproj/index.html"
        if FileManager.default.fileExists(atPath: projectHelpPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: projectHelpPath))
        } else {
            Log.error("📚 Help Book not found", category: .error)
            let alert = NSAlert()
            alert.messageText = "Help Not Available"
            alert.informativeText = "The help documentation could not be found."
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}
