import SwiftUI
import Combine
import UniformTypeIdentifiers

class DocumentState: ObservableObject {
    lazy var document: VectorDocument? = nil

    private func getDocumentBaseName() -> String {
        if let fileURL = NSDocumentController.shared.currentDocument?.fileURL {
            return fileURL.deletingPathExtension().lastPathComponent
        }
        return "Untitled"
    }

    @Published var isFocused = false
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var hasSelection = false
    @Published var canCut = false
    @Published var canCopy = false
    @Published var canPaste = false
    @Published var canGroup = false
    @Published var canUngroup = false
    @Published var canFlatten = false
    @Published var canUnflatten = false
    @Published var canMakeCompoundPath = false
    @Published var canReleaseCompoundPath = false
    @Published var canMakeLoopingPath = false
    @Published var canReleaseLoopingPath = false
    @Published var canUnwrapWarpObject = false
    @Published var canExpandWarpObject = false
    @Published var canEmbedLinkedImages = false
    @Published var showMoveDialog = false

    private var isTerminating = false
    private var pasteboardChangeCount: Int = 0
    private var pasteboardTimer: Timer?
    private var missingImageObserver: NSObjectProtocol?
    private var promptedMissingImages = Set<UUID>()

    init() {
        DocumentStateRegistry.shared.register(self)
        startPasteboardMonitoring()
        missingImageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("MissingLinkedImage"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let shapeID = userInfo["shapeID"] as? UUID,
                  let path = userInfo["path"] as? String else { return }
            guard !self.promptedMissingImages.contains(shapeID) else { return }
            self.promptedMissingImages.insert(shapeID)
            self.promptForMissingImage(shapeID: shapeID, originalPath: path)
        }
    }

    deinit {
        cleanup()
        if let observer = missingImageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        pasteboardTimer?.invalidate()
        pasteboardTimer = nil
    }

    func setDocument(_ document: VectorDocument) {
        self.document = document
        updateAllStates()
        Task {
            await setupDocumentObserversAsync()
        }
    }

    func cleanup() {
        selectionCancellable?.cancel()
        selectionCancellable = nil
        commandManagerCancellable?.cancel()
        commandManagerCancellable = nil
        pasteboardTimer?.invalidate()
        pasteboardTimer = nil
        if let doc = document {
            let docShapeIDs = Set(doc.snapshot.objects.keys)
            for id in docShapeIDs {
                SVGToInkPenImporter.svgShapeRegistry.removeValue(forKey: id)
            }
            doc.imageStorage.removeAll()
        }
        MemoryDiag.checkpoint("DocumentState.cleanup")
        document = nil
    }

    func forceCleanup() {
        isTerminating = true
        document = nil
        canUndo = false
        canRedo = false
        hasSelection = false
        canCut = false
        canCopy = false
        canPaste = false
        canGroup = false
        canUngroup = false
        canFlatten = false
        canUnflatten = false
        canMakeCompoundPath = false
        canReleaseCompoundPath = false
        canMakeLoopingPath = false
        canReleaseLoopingPath = false
        canUnwrapWarpObject = false
        canExpandWarpObject = false
    }

    private func startPasteboardMonitoring() {
        pasteboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, !self.isTerminating else { return }
            let currentChangeCount = NSPasteboard.general.changeCount
            if currentChangeCount != self.pasteboardChangeCount {
                self.pasteboardChangeCount = currentChangeCount
                self.canPaste = ClipboardManager.shared.canPaste()
            }
        }
    }
    private var selectionCancellable: AnyCancellable?
    private var commandManagerCancellable: AnyCancellable?

    private func setupDocumentObserversAsync() async {
        guard let document = document else { return }
        await MainActor.run {
            selectionCancellable = document.viewState.objectWillChange.sink { [weak self] _ in
                self?.updateAllStates()
            }
            commandManagerCancellable = document.commandManager.objectWillChange.sink { [weak self] _ in
                self?.updateAllStates()
            }
        }
    }

    private func updateAllStates() {
        guard !isTerminating else {
            return
        }
        guard let document = document else {
            canUndo = false
            canRedo = false
            hasSelection = false
            canCut = false
            canCopy = false
            canPaste = false
            canGroup = false
            canUngroup = false
            canFlatten = false
            canUnflatten = false
            canMakeCompoundPath = false
            canReleaseCompoundPath = false
            canMakeLoopingPath = false
            canReleaseLoopingPath = false
            canUnwrapWarpObject = false
            canExpandWarpObject = false
            return
        }
        canUndo = document.commandManager.canUndo
        canRedo = document.commandManager.canRedo
        hasSelection = !document.viewState.selectedObjectIDs.isEmpty
        canCut = hasSelection
        canCopy = hasSelection
        canPaste = ClipboardManager.shared.canPaste()

        func isShape(_ newVectorObject: VectorObject) -> Bool {
            switch newVectorObject.objectType {
            case .shape, .image, .warp, .group, .clipGroup, .clipMask:
                return true
            case .text, .guide:
                return false
            }
        }
        let selectedShapes = document.viewState.selectedObjectIDs.compactMap { id in
            document.snapshot.objects[id]
        }.filter { isShape($0) }
        let selectedShapeCount = selectedShapes.count
        let totalSelectedCount = document.viewState.selectedObjectIDs.count
        canGroup = totalSelectedCount > 1
        canUngroup = selectedShapes.contains { newVectorObject in
            if case .group(let shape) = newVectorObject.objectType {
                return shape.isGroupContainer
            }
            return false
        }
        canFlatten = selectedShapeCount > 1
        canUnflatten = selectedShapeCount == 1 && selectedShapes.contains { newVectorObject in
            if case .group(let shape) = newVectorObject.objectType {
                return shape.isGroup
            }
            return false
        }
        canMakeCompoundPath = selectedShapeCount > 1
        canReleaseCompoundPath = selectedShapeCount == 1 && selectedShapes.contains { newVectorObject in
            if case .shape(let shape) = newVectorObject.objectType {
                return shape.isTrueCompoundPath
            }
            return false
        }
        canMakeLoopingPath = selectedShapeCount > 1
        canReleaseLoopingPath = selectedShapeCount == 1 && selectedShapes.contains { newVectorObject in
            if case .shape(let shape) = newVectorObject.objectType {
                return shape.isTrueLoopingPath
            }
            return false
        }
        canUnwrapWarpObject = selectedShapeCount == 1 && selectedShapes.contains { newVectorObject in
            if case .warp = newVectorObject.objectType {
                return true
            }
            return false
        }
        canExpandWarpObject = selectedShapeCount == 1 && selectedShapes.contains { newVectorObject in
            if case .warp = newVectorObject.objectType {
                return true
            }
            return false
        }
        canEmbedLinkedImages = {
            for newVectorObject in selectedShapes {
                switch newVectorObject.objectType {
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if shape.linkedImagePath != nil { return true }
                    if ImageContentRegistry.containsImage(shape, in: document) { return true }
                case .text, .guide:
                    break
                }
            }
            return false
        }()
    }

    private func hydrateGroupImagesRecursively(_ shape: VectorShape, document: VectorDocument, count: inout Int) {
        if shape.embeddedImageData != nil || shape.linkedImagePath != nil || shape.linkedImageBookmarkData != nil {
            if ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document) != nil {
                count += 1
            }
        }
        if shape.isGroup || shape.isClippingGroup {
            for child in shape.groupedShapes {
                hydrateGroupImagesRecursively(child, document: document, count: &count)
            }
            for memberID in shape.memberIDs {
                if let obj = document.snapshot.objects[memberID] {
                    let childShape: VectorShape
                    switch obj.objectType {
                    case .shape(let s), .image(let s), .warp(let s), .group(let s), .clipGroup(let s), .clipMask(let s), .guide(let s):
                        childShape = s
                    case .text(let s):
                        childShape = s
                    }
                    hydrateGroupImagesRecursively(childShape, document: document, count: &count)
                }
            }
        }
    }

    func showImportDialog() {
        guard let document = document else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .svg,
            .pdf,
            .freehandDocument,
            .encapsulatedPostScript,
            .png,
            .jpeg,
            .tiff,
            .bmp,
            .heic,
            .heif,
            .gif,
            .webP,
            .image,
            .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import"
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else { return }
            Task { [weak self] in
                let result = await VectorImportManager.shared.importVectorFile(from: url)
                await MainActor.run {
                    guard let self else { return }
                    if result.success {
                        let isUsable: VectorImportResult.ShapeFilter = { shape in
                            let tempObj = VectorObject(shape: shape, layerIndex: 0)
                            if case .image = tempObj.objectType {
                                if let data = shape.embeddedImageData {
                                    return !(data.count < 16 || SVGParser.looksLikeXML(data))
                                }
                                return shape.linkedImagePath != nil || shape.linkedImageBookmarkData != nil
                            }
                            return true
                        }
                        let usableShapes = result.shapes.filter(isUsable)
                        let dispatched = result.dispatchAsImportCommand(into: document, filter: isUsable) != nil
                        if dispatched {
                            var imagesHydrated = 0
                            for shape in usableShapes {
                                self.hydrateGroupImagesRecursively(shape, document: document, count: &imagesHydrated)
                            }
                            document.viewState.selectedObjectIDs = Set(usableShapes.map { $0.id })
                        }
                        self.updateAllStates()
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Import Failed"
                        let errorText = result.errors.map { $0.localizedDescription }.joined(separator: ", ")
                        alert.informativeText = errorText.isEmpty ? "The selected file could not be imported." : errorText
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }
    }

    func exportSVG() {
        guard let document = document else { return }
        let panel = NSSavePanel()
        panel.title = "Export SVG"
        panel.nameFieldStringValue = "\(getDocumentBaseName()).svg"
        panel.allowedContentTypes = [.svg]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false
        panel.message = "Export as SVG (Scalable Vector Graphics)"
        let accessoryView = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 280))
        let textToOutlinesCheckbox = NSButton(checkboxWithTitle: "Convert text to outlines",
                                              target: nil, action: nil)
        textToOutlinesCheckbox.frame = CGRect(x: 20, y: 240, width: 250, height: 20)
        textToOutlinesCheckbox.state = .off
        accessoryView.addSubview(textToOutlinesCheckbox)
        let textModeLabel = NSTextField(labelWithString: "SVG Text Rendering Mode:")
        textModeLabel.frame = CGRect(x: 40, y: 195, width: 300, height: 20)
        textModeLabel.font = PlatformFont.systemFont(ofSize: PlatformFont.smallSystemFontSize)
        accessoryView.addSubview(textModeLabel)
        let glyphsRadio = NSButton(radioButtonWithTitle: "Individual Glyphs (most accurate)", target: nil, action: nil)
        glyphsRadio.frame = CGRect(x: 60, y: 170, width: 300, height: 18)
        glyphsRadio.state = AppState.shared.svgTextRenderingMode == .glyphs ? .on : .off
        accessoryView.addSubview(glyphsRadio)
        let linesRadio = NSButton(radioButtonWithTitle: "By Lines (faster)", target: nil, action: nil)
        linesRadio.frame = CGRect(x: 60, y: 150, width: 300, height: 18)
        linesRadio.state = AppState.shared.svgTextRenderingMode == .lines ? .on : .off
        accessoryView.addSubview(linesRadio)
        let colorSpaceLabel = NSTextField(labelWithString: "Color Space:")
        colorSpaceLabel.frame = CGRect(x: 20, y: 115, width: 300, height: 20)
        colorSpaceLabel.font = PlatformFont.systemFont(ofSize: PlatformFont.smallSystemFontSize)
        accessoryView.addSubview(colorSpaceLabel)
        let displayP3Radio = NSButton(radioButtonWithTitle: "Display P3 (wide gamut)", target: nil, action: nil)
        displayP3Radio.frame = CGRect(x: 40, y: 90, width: 250, height: 18)
        displayP3Radio.state = AppState.shared.exportColorSpace == .displayP3 ? .on : .off
        accessoryView.addSubview(displayP3Radio)
        let sRGBRadio = NSButton(radioButtonWithTitle: "sRGB (standard, maximum compatibility)", target: nil, action: nil)
        sRGBRadio.frame = CGRect(x: 40, y: 70, width: 300, height: 18)
        sRGBRadio.state = AppState.shared.exportColorSpace == .sRGB ? .on : .off
        accessoryView.addSubview(sRGBRadio)
        let includeInkpenCheckbox = NSButton(checkboxWithTitle: "Include native .inkpen document",
                                             target: nil, action: nil)
        includeInkpenCheckbox.frame = CGRect(x: 20, y: 40, width: 250, height: 20)
        includeInkpenCheckbox.state = .on
        accessoryView.addSubview(includeInkpenCheckbox)
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                  target: nil, action: nil)
        bgCheckbox.frame = CGRect(x: 20, y: 15, width: 200, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)
        let svgHandler = ExportTextOptionsHandler(textToOutlinesCheckbox: textToOutlinesCheckbox,
                                                  textModeLabel: textModeLabel,
                                                  glyphsRadio: glyphsRadio,
                                                  linesRadio: linesRadio)
        textToOutlinesCheckbox.target = svgHandler
        textToOutlinesCheckbox.action = #selector(ExportTextOptionsHandler.toggleTextOptions(_:))
        glyphsRadio.target = svgHandler
        glyphsRadio.action = #selector(ExportTextOptionsHandler.selectGlyphs(_:))
        linesRadio.target = svgHandler
        linesRadio.action = #selector(ExportTextOptionsHandler.selectLines(_:))

        class ColorSpaceHandler: NSObject {
            let displayP3Radio: NSButton
            let sRGBRadio: NSButton

            init(displayP3Radio: NSButton, sRGBRadio: NSButton) {
                self.displayP3Radio = displayP3Radio
                self.sRGBRadio = sRGBRadio
            }

            @objc func selectDisplayP3(_ sender: NSButton) {
                displayP3Radio.state = .on
                sRGBRadio.state = .off
            }

            @objc func selectSRGB(_ sender: NSButton) {
                displayP3Radio.state = .off
                sRGBRadio.state = .on
            }
        }
        let colorSpaceHandler = ColorSpaceHandler(displayP3Radio: displayP3Radio, sRGBRadio: sRGBRadio)
        displayP3Radio.target = colorSpaceHandler
        displayP3Radio.action = #selector(ColorSpaceHandler.selectDisplayP3(_:))
        sRGBRadio.target = colorSpaceHandler
        sRGBRadio.action = #selector(ColorSpaceHandler.selectSRGB(_:))
        objc_setAssociatedObject(accessoryView, "textOptionsHandler", svgHandler, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(accessoryView, "colorSpaceHandler", colorSpaceHandler, .OBJC_ASSOCIATION_RETAIN)
        let shouldHideTextOptions = textToOutlinesCheckbox.state == .on
        textModeLabel.isHidden = shouldHideTextOptions
        glyphsRadio.isHidden = shouldHideTextOptions
        linesRadio.isHidden = shouldHideTextOptions
        panel.accessoryView = accessoryView
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            let includeBackground = bgCheckbox.state == .on
            let convertTextToOutlines = textToOutlinesCheckbox.state == .on
            let includeInkpenData = includeInkpenCheckbox.state == .on
            let textRenderingMode: AppState.SVGTextRenderingMode = glyphsRadio.state == .on ? .glyphs : .lines
            AppState.shared.svgTextRenderingMode = textRenderingMode
            let colorSpace: AppState.ExportColorSpace = displayP3Radio.state == .on ? .displayP3 : .sRGB
            AppState.shared.exportColorSpace = colorSpace
            Task {
                do {
                    var svgContent: String
                    if convertTextToOutlines && document.snapshot.objects.values.contains(where: { obj in
                        if case .text = obj.objectType { return true }
                        return false
                    }) {
                        svgContent = try await DocumentState.exportSVGWithTextToOutlines(
                            document,
                            includeBackground: includeBackground,
                            textRenderingMode: AppState.shared.svgTextRenderingMode,
                            includeInkpenData: includeInkpenData,
                            isAutoDesk: false
                        )
                    } else {
                        svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: includeBackground, textRenderingMode: AppState.shared.svgTextRenderingMode, includeInkpenData: includeInkpenData)
                    }
                    try svgContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    await MainActor.run {
                        Log.error("❌ Failed to export SVG: \(error)", category: .error)
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }

    func exportPDF() {
        guard let document = document else { return }
        let panel = NSSavePanel()
        panel.title = "Export PDF"
        panel.nameFieldStringValue = "\(getDocumentBaseName()).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false
        panel.message = "Export as PDF (Portable Document Format)"
        let accessoryView = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 250))
        let textToOutlinesCheckbox = NSButton(checkboxWithTitle: "Convert text to outlines",
                                              target: nil, action: nil)
        textToOutlinesCheckbox.frame = CGRect(x: 20, y: 210, width: 250, height: 20)
        textToOutlinesCheckbox.state = .off
        accessoryView.addSubview(textToOutlinesCheckbox)
        let textModeLabel = NSTextField(labelWithString: "PDF Text Rendering Mode:")
        textModeLabel.frame = CGRect(x: 40, y: 165, width: 300, height: 20)
        textModeLabel.font = PlatformFont.systemFont(ofSize: PlatformFont.smallSystemFontSize)
        accessoryView.addSubview(textModeLabel)
        let glyphsRadio = NSButton(radioButtonWithTitle: "Individual Glyphs (most accurate)", target: nil, action: nil)
        glyphsRadio.frame = CGRect(x: 60, y: 140, width: 300, height: 18)
        glyphsRadio.state = AppState.shared.pdfTextRenderingMode == .glyphs ? .on : .off
        accessoryView.addSubview(glyphsRadio)
        let linesRadio = NSButton(radioButtonWithTitle: "By Lines (faster)", target: nil, action: nil)
        linesRadio.frame = CGRect(x: 60, y: 120, width: 300, height: 18)
        linesRadio.state = AppState.shared.pdfTextRenderingMode == .lines ? .on : .off
        accessoryView.addSubview(linesRadio)
        let cmykCheckbox = NSButton(checkboxWithTitle: "Use CMYK color space",
                                    target: nil, action: nil)
        cmykCheckbox.frame = CGRect(x: 20, y: 80, width: 250, height: 20)
        cmykCheckbox.state = .off
        accessoryView.addSubview(cmykCheckbox)
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                  target: nil, action: nil)
        bgCheckbox.frame = CGRect(x: 20, y: 50, width: 250, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)
        let includeInkpenCheckbox = NSButton(checkboxWithTitle: "Include native .inkpen document",
                                             target: nil, action: nil)
        includeInkpenCheckbox.frame = CGRect(x: 20, y: 20, width: 250, height: 20)
        includeInkpenCheckbox.state = .on
        accessoryView.addSubview(includeInkpenCheckbox)
        let handler = ExportTextOptionsHandler(textToOutlinesCheckbox: textToOutlinesCheckbox,
                                               textModeLabel: textModeLabel,
                                               glyphsRadio: glyphsRadio,
                                               linesRadio: linesRadio)
        textToOutlinesCheckbox.target = handler
        textToOutlinesCheckbox.action = #selector(ExportTextOptionsHandler.toggleTextOptions(_:))
        glyphsRadio.target = handler
        glyphsRadio.action = #selector(ExportTextOptionsHandler.selectGlyphs(_:))
        linesRadio.target = handler
        linesRadio.action = #selector(ExportTextOptionsHandler.selectLines(_:))
        objc_setAssociatedObject(accessoryView, "textOptionsHandler", handler, .OBJC_ASSOCIATION_RETAIN)
        panel.accessoryView = accessoryView
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let useCMYK = cmykCheckbox.state == .on
            let convertTextToOutlines = textToOutlinesCheckbox.state == .on
            let includeInkpenData = includeInkpenCheckbox.state == .on
            let includeBackground = bgCheckbox.state == .on
            let textRenderingMode: AppState.PDFTextRenderingMode = linesRadio.state == .on ? .lines : .glyphs
            AppState.shared.pdfTextRenderingMode = textRenderingMode
            Task {
                do {
                    var pdfData: Data
                    if convertTextToOutlines && document.snapshot.objects.values.contains(where: { obj in
                        if case .text = obj.objectType { return true }
                        return false
                    }) {
                        pdfData = try await DocumentState.exportWithTextToOutlines(document) {
                            try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData, includeBackground: includeBackground)
                        }
                    } else {
                        pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData, includeBackground: includeBackground)
                    }
                    try pdfData.write(to: url)
                } catch {
                    await MainActor.run {
                        Log.error("❌ Failed to export PDF: \(error)", category: .error)
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }

    func exportPNG() {
        guard let document = document else { return }
        let panel = NSSavePanel()
        panel.title = "Export PNG"
        panel.nameFieldStringValue = "\(getDocumentBaseName()).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.message = "Export as PNG (Portable Network Graphics)"
        let accessoryView = NSView(frame: CGRect(x: 0, y: 0, width: 350, height: 170))
        let textToOutlinesCheckbox = NSButton(checkboxWithTitle: "Convert text to outlines",
                                              target: nil, action: nil)
        textToOutlinesCheckbox.frame = CGRect(x: 20, y: 130, width: 250, height: 20)
        textToOutlinesCheckbox.state = .on
        accessoryView.addSubview(textToOutlinesCheckbox)
        let iconCheckbox = NSButton(checkboxWithTitle: "Export as Icon Set",
                                    target: nil, action: nil)
        iconCheckbox.frame = CGRect(x: 20, y: 100, width: 200, height: 20)
        iconCheckbox.state = .off
        accessoryView.addSubview(iconCheckbox)
        let iconSizesLabel = NSTextField(labelWithString: "Sizes: 1024×1024, 512×512, 256×256, 128×128, 64×64, 32×32, 16×16 px")
        iconSizesLabel.frame = CGRect(x: 40, y: 75, width: 300, height: 20)
        iconSizesLabel.font = PlatformFont.systemFont(ofSize: 10)
        iconSizesLabel.textColor = PlatformColor.secondaryLabelColor
        iconSizesLabel.isHidden = true
        accessoryView.addSubview(iconSizesLabel)
        let scaleLabel = NSTextField(labelWithString: "Scale:")
        scaleLabel.frame = CGRect(x: 20, y: 45, width: 50, height: 20)
        accessoryView.addSubview(scaleLabel)
        let scalePopup = NSPopUpButton(frame: CGRect(x: 75, y: 43, width: 150, height: 25))
        if SandboxChecker.isSandboxed {
            scalePopup.addItems(withTitles: [
                "1x", "2x", "3x", "4x",
                "1024×1024 icon",
                "512×512 icon",
                "256×256 icon",
                "128×128 icon",
                "64×64 icon",
                "32×32 icon",
                "16×16 icon"
            ])
        } else {
            scalePopup.addItems(withTitles: ["1x", "2x", "3x", "4x", "Icon Set"])
        }
        scalePopup.selectItem(withTitle: "2x")
        accessoryView.addSubview(scalePopup)
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                  target: nil, action: nil)
        bgCheckbox.frame = CGRect(x: 20, y: 10, width: 200, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)
        iconCheckbox.target = iconCheckbox
        iconCheckbox.action = #selector(NSButton.performClick(_:))
        iconCheckbox.sendAction(on: .leftMouseUp)

        class IconCheckboxHandler: NSObject {
            let scaleLabel: NSTextField
            let scalePopup: NSPopUpButton
            let bgCheckbox: NSButton
            let iconSizesLabel: NSTextField
            let iconCheckbox: NSButton
            let textToOutlinesCheckbox: NSButton

            init(scaleLabel: NSTextField, scalePopup: NSPopUpButton, bgCheckbox: NSButton, iconSizesLabel: NSTextField, iconCheckbox: NSButton, textToOutlinesCheckbox: NSButton) {
                self.scaleLabel = scaleLabel
                self.scalePopup = scalePopup
                self.bgCheckbox = bgCheckbox
                self.iconSizesLabel = iconSizesLabel
                self.iconCheckbox = iconCheckbox
                self.textToOutlinesCheckbox = textToOutlinesCheckbox
            }

            @objc func toggleIconMode(_ sender: NSButton) {
                let isIconMode = sender.state == .on
                scaleLabel.isHidden = isIconMode
                scalePopup.isHidden = isIconMode
                bgCheckbox.isHidden = isIconMode
                iconSizesLabel.isHidden = !isIconMode
                textToOutlinesCheckbox.isHidden = isIconMode
                if isIconMode {
                    bgCheckbox.state = .off
                    scalePopup.selectItem(withTitle: "Icon Set")
                }
            }

            @objc func scaleChanged(_ sender: NSPopUpButton) {
                let selectedItem = sender.titleOfSelectedItem ?? ""
                let isIconOption = selectedItem == "Icon Set" || selectedItem.contains("icon")
                if isIconOption {
                    iconCheckbox.state = .on
                    bgCheckbox.isHidden = true
                    bgCheckbox.state = .off
                    iconSizesLabel.isHidden = selectedItem.contains("×")
                    textToOutlinesCheckbox.isHidden = true
                } else {
                    iconCheckbox.state = .off
                    bgCheckbox.isHidden = false
                    iconSizesLabel.isHidden = true
                    textToOutlinesCheckbox.isHidden = false
                }
            }
        }
        let handler = IconCheckboxHandler(scaleLabel: scaleLabel, scalePopup: scalePopup,
                                          bgCheckbox: bgCheckbox, iconSizesLabel: iconSizesLabel,
                                          iconCheckbox: iconCheckbox, textToOutlinesCheckbox: textToOutlinesCheckbox)
        iconCheckbox.target = handler
        iconCheckbox.action = #selector(IconCheckboxHandler.toggleIconMode(_:))
        scalePopup.target = handler
        scalePopup.action = #selector(IconCheckboxHandler.scaleChanged(_:))
        objc_setAssociatedObject(accessoryView, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
        panel.accessoryView = accessoryView
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let selectedScale = scalePopup.titleOfSelectedItem ?? "2x"
            let isIconMode = iconCheckbox.state == .on || selectedScale == "Icon Set"
            let convertTextToOutlines = textToOutlinesCheckbox.state == .on
            if isIconMode {
                let folderURL = url.deletingLastPathComponent()
                Task {
                    do {
                        try FileOperations.exportIconSet(document, folderURL: folderURL)
                    } catch {
                        await MainActor.run {
                            Log.error("❌ Failed to export icon set: \(error)", category: .error)
                            let alert = NSAlert()
                            alert.messageText = "Export Failed"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .critical
                            alert.runModal()
                        }
                    }
                }
            } else {
                let selectedOption = scalePopup.titleOfSelectedItem ?? "2x"
                if selectedOption.contains("icon") {
                    let sizeString = selectedOption.replacingOccurrences(of: " icon", with: "")
                    let pixelSize = Int(sizeString.split(separator: "×")[0]) ?? 512
                    Task {
                        do {
                            try FileOperations.exportSingleIcon(document, url: url, pixelSize: pixelSize)
                        } catch {
                            await MainActor.run {
                                Log.error("❌ Failed to export icon: \(error)", category: .error)
                                let alert = NSAlert()
                                alert.messageText = "Export Failed"
                                alert.informativeText = error.localizedDescription
                                alert.alertStyle = .critical
                                alert.runModal()
                            }
                        }
                    }
                } else {
                    let scale = CGFloat(Int(selectedOption.dropLast()) ?? 2)
                    let includeBackground = bgCheckbox.state == .on
                    Task {
                        do {
                            if convertTextToOutlines && document.snapshot.objects.values.contains(where: { obj in
                                if case .text = obj.objectType { return true }
                                return false
                            }) {
                                try await DocumentState.exportWithTextToOutlines(document) {
                                    try FileOperations.exportToPNGFromView(document, url: url, scale: scale,
                                                                   includeBackground: includeBackground)
                                    return Data()
                                }
                            } else {
                                try FileOperations.exportToPNGFromView(document, url: url, scale: scale,
                                                               includeBackground: includeBackground)
                            }
                        } catch {
                            await MainActor.run {
                                Log.error("❌ Failed to export PNG: \(error)", category: .error)
                                let alert = NSAlert()
                                alert.messageText = "Export Failed"
                                alert.informativeText = error.localizedDescription
                                alert.alertStyle = .critical
                                alert.runModal()
                            }
                        }
                    }
                }
            }
        }
    }

    func exportAutoDeskSVG() {
        guard let document = document else { return }
        let panel = NSSavePanel()
        panel.title = "Export AutoDesk SVG"
        panel.nameFieldStringValue = "\(getDocumentBaseName())-96dpi.svg"
        panel.allowedContentTypes = [.svg]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.isExtensionHidden = false
        panel.message = "Export SVG at 96 DPI for AutoDesk applications"
        let accessoryView = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 180))
        let textToOutlinesCheckbox = NSButton(checkboxWithTitle: "Convert text to outlines",
                                              target: nil, action: nil)
        textToOutlinesCheckbox.frame = CGRect(x: 20, y: 140, width: 250, height: 20)
        textToOutlinesCheckbox.state = .off
        accessoryView.addSubview(textToOutlinesCheckbox)
        let textModeLabel = NSTextField(labelWithString: "SVG Text Rendering Mode:")
        textModeLabel.frame = CGRect(x: 40, y: 95, width: 300, height: 20)
        textModeLabel.font = PlatformFont.systemFont(ofSize: PlatformFont.smallSystemFontSize)
        accessoryView.addSubview(textModeLabel)
        let glyphsRadio = NSButton(radioButtonWithTitle: "Individual Glyphs (most accurate)", target: nil, action: nil)
        glyphsRadio.frame = CGRect(x: 60, y: 70, width: 300, height: 18)
        glyphsRadio.state = AppState.shared.svgTextRenderingMode == .glyphs ? .on : .off
        accessoryView.addSubview(glyphsRadio)
        let linesRadio = NSButton(radioButtonWithTitle: "By Lines (faster)", target: nil, action: nil)
        linesRadio.frame = CGRect(x: 60, y: 50, width: 300, height: 18)
        linesRadio.state = AppState.shared.svgTextRenderingMode == .lines ? .on : .off
        accessoryView.addSubview(linesRadio)
        let bgCheckbox = NSButton(checkboxWithTitle: "Include background",
                                  target: nil, action: nil)
        bgCheckbox.frame = CGRect(x: 20, y: 20, width: 200, height: 20)
        bgCheckbox.state = .off
        accessoryView.addSubview(bgCheckbox)
        let autodeskHandler = ExportTextOptionsHandler(textToOutlinesCheckbox: textToOutlinesCheckbox,
                                                       textModeLabel: textModeLabel,
                                                       glyphsRadio: glyphsRadio,
                                                       linesRadio: linesRadio)
        textToOutlinesCheckbox.target = autodeskHandler
        textToOutlinesCheckbox.action = #selector(ExportTextOptionsHandler.toggleTextOptions(_:))
        glyphsRadio.target = autodeskHandler
        glyphsRadio.action = #selector(ExportTextOptionsHandler.selectGlyphs(_:))
        linesRadio.target = autodeskHandler
        linesRadio.action = #selector(ExportTextOptionsHandler.selectLines(_:))
        objc_setAssociatedObject(accessoryView, "textOptionsHandler", autodeskHandler, .OBJC_ASSOCIATION_RETAIN)
        let shouldHideTextOptions = textToOutlinesCheckbox.state == .on
        textModeLabel.isHidden = shouldHideTextOptions
        glyphsRadio.isHidden = shouldHideTextOptions
        linesRadio.isHidden = shouldHideTextOptions
        panel.accessoryView = accessoryView
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            let includeBackground = bgCheckbox.state == .on
            let convertTextToOutlines = textToOutlinesCheckbox.state == .on
            let textRenderingMode: AppState.SVGTextRenderingMode = glyphsRadio.state == .on ? .glyphs : .lines
            AppState.shared.svgTextRenderingMode = textRenderingMode
            Task {
                do {
                    var svgContent: String
                    if convertTextToOutlines && document.snapshot.objects.values.contains(where: { obj in
                        if case .text = obj.objectType { return true }
                        return false
                    }) {
                        svgContent = try await DocumentState.exportSVGWithTextToOutlines(
                            document,
                            includeBackground: includeBackground,
                            textRenderingMode: AppState.shared.svgTextRenderingMode,
                            includeInkpenData: true,
                            isAutoDesk: true
                        )
                    } else {
                        svgContent = try SVGExporter.shared.exportToAutoDeskSVG(document, includeBackground: includeBackground, textRenderingMode: AppState.shared.svgTextRenderingMode, includeInkpenData: true)
                    }
                    try svgContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    await MainActor.run {
                        Log.error("❌ Failed to export AutoDesk SVG: \(error)", category: .error)
                        let alert = NSAlert()
                        alert.messageText = "Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }

    func undo() {
        document?.undo()
        updateAllStates()
    }

    func redo() {
        document?.redo()
        updateAllStates()
    }

    func cut() {
        guard let document = document else { return }
        ClipboardManager.shared.cut(from: document)
        updateAllStates()
    }

    func copy() {
        guard let document = document else { return }
        ClipboardManager.shared.copy(from: document)
        updateAllStates()
    }

    func paste() {
        guard let document = document else { return }
        ClipboardManager.shared.paste(to: document)
        updateAllStates()
    }

    func pasteInBack() {
        guard let document = document else { return }
        ClipboardManager.shared.pasteInBack(to: document)
        updateAllStates()
    }

    func pasteInFront() {
        guard let document = document else { return }
        ClipboardManager.shared.pasteInFront(to: document)
        updateAllStates()
    }

    func selectAll() {
        document?.selectAll()
        updateAllStates()
    }

    func deselectAll() {
        document?.clearSelectionWithUndo()
        updateAllStates()
    }

    func delete() {
        guard let document = document else { return }
        document.removeSelectedObjects()
        updateAllStates()
    }

    func bringToFront() {
        document?.bringSelectedToFront()
        updateAllStates()
    }

    func bringForward() {
        document?.bringSelectedForward()
        updateAllStates()
    }

    func sendBackward() {
        document?.sendSelectedBackward()
        updateAllStates()
    }

    func sendToBack() {
        document?.sendSelectedToBack()
        updateAllStates()
    }

    func groupObjects() {
        document?.groupSelectedObjects()
        updateAllStates()
    }

    func ungroupObjects() {
        document?.ungroupSelectedObjects()
        updateAllStates()
    }

    func flattenObjects() {
        document?.flattenSelectedObjects()
        updateAllStates()
    }

    func unflattenObjects() {
        document?.unflattenSelectedObjects()
        updateAllStates()
    }

    func alignByOrigin() {
        document?.alignSelectedObjectsByOrigin()
        updateAllStates()
    }

    func alignByOriginX() {
        document?.alignSelectedObjectsByOriginX()
        updateAllStates()
    }

    func alignByOriginY() {
        document?.alignSelectedObjectsByOriginY()
        updateAllStates()
    }

    var canAlign: Bool {
        guard let doc = document else { return false }
        return doc.viewState.orderedSelectedObjectIDs.count >= 2
    }

    func duplicate() {
        guard let document = document else { return }
        if !document.viewState.selectedObjectIDs.isEmpty {
            document.duplicateSelectedShapes()
        } else if !document.viewState.selectedObjectIDs.isEmpty {
            document.duplicateSelectedText()
        }
        updateAllStates()
    }

    func makeCompoundPath() {
        document?.makeCompoundPath()
        updateAllStates()
    }

    func releaseCompoundPath() {
        document?.releaseCompoundPath()
        updateAllStates()
    }

    func makeLoopingPath() {
        document?.makeLoopingPath()
        updateAllStates()
    }

    func releaseLoopingPath() {
        document?.releaseLoopingPath()
        updateAllStates()
    }

    func unwrapWarpObject() {
        document?.unwrapWarpObject()
        updateAllStates()
    }

    func expandWarpObject() {
        document?.expandWarpObject()
        updateAllStates()
    }

    func lockSelectedObjects() {
        document?.lockSelectedObjects()
        updateAllStates()
    }

    func unlockAllObjects() {
        document?.unlockAllObjects()
        updateAllStates()
    }

    func hideSelectedObjects() {
        document?.hideSelectedObjects()
        updateAllStates()
    }

    func showAllObjects() {
        document?.showAllObjects()
        updateAllStates()
    }

    func zoomIn() {
        document?.requestZoom(to: 0.0, mode: .zoomIn)
    }

    func zoomOut() {
        document?.requestZoom(to: 0.0, mode: .zoomOut)
    }

    func fitToPage() {
        document?.requestZoom(to: 0.0, mode: .fitToPage)
    }

    func actualSize() {
        document?.requestZoom(to: 1.0, mode: .actualSize)
    }

    func toggleColorKeylineView() {
        guard let doc = document else { return }
        if doc.viewState.viewMode == .color {
            doc.viewState.viewMode = .keyline
        } else {
            doc.viewState.viewMode = .color
        }
    }

    func toggleRulers() {
        document?.gridSettings.showRulers.toggle()
    }

    func toggleGrid() {
        document?.settings.showGrid.toggle()
        document?.gridSettings.showGrid = document?.settings.showGrid ?? false
    }

    func toggleSnapToGrid() {
        document?.gridSettings.snapToGrid.toggle()
        document?.settings.snapToGrid = document?.gridSettings.snapToGrid ?? false
    }

    func toggleSnapToPoint() {
        document?.gridSettings.snapToPoint.toggle()
        document?.settings.snapToPoint = document?.gridSettings.snapToPoint ?? false
    }

    func toggleGuides() {
        document?.gridSettings.showGuides.toggle()
    }

    func toggleLockGuides() {
        document?.gridSettings.guidesLocked.toggle()
    }

    func toggleSnapToGuides() {
        document?.gridSettings.snapToGuides.toggle()
    }

    func clearGuides() {
        document?.clearGuides()
    }

    func createOutlines() {
        guard let document = document, !document.viewState.selectedObjectIDs.isEmpty else { return }
        document.convertSelectedTextToOutlines()
        updateAllStates()
    }

    func embedSelectedLinkedImages() {
        guard let document = document else { return }
        for layerIndex in document.snapshot.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            for shapeIndex in shapes.indices {
                guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                guard document.viewState.selectedObjectIDs.contains(shape.id) else { continue }
                var cgImage: CGImage? = ImageContentRegistry.image(for: shape.id, in: document)
                if cgImage == nil {
                    cgImage = ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                }
                guard let image = cgImage else { continue }
                let mutableData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else { continue }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { continue }
                document.updateEntireShapeInUnified(id: shape.id) { updatedShape in
                    updatedShape.embeddedImageData = mutableData as Data
                }
            }
        }
        updateAllStates()
    }

    func cleanupDuplicatePoints() {
        guard let document = document else { return }
        if !document.viewState.selectedObjectIDs.isEmpty {
            ProfessionalPathOperations.cleanupSelectedShapesDuplicates(document, tolerance: 5.0)
        } else {
            ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
        }
        updateAllStates()
    }

    func cleanupAllDuplicatePoints() {
        guard let document = document else { return }
        ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
        updateAllStates()
    }

    func switchToTool(_ tool: DrawingTool) {
        guard let document = document else { return }
        document.viewState.currentTool = tool
        ToolGroupManager.shared.handleKeyboardToolSwitch(tool: tool)
    }

    static func convertAllTextToOutlinesForExport(_ document: VectorDocument) {
        let textObjects = document.snapshot.objects.values.compactMap { obj -> VectorText? in
            guard case .text(let shape) = obj.objectType else { return nil }
            var vectorText = VectorText.from(shape)
            vectorText?.layerIndex = obj.layerIndex
            return vectorText
        }
        guard !textObjects.isEmpty else { return }
        for textObj in textObjects {
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: document)
            viewModel.convertToPath()
        }
        let textIDs = document.snapshot.objects.filter { _, obj in
            if case .text = obj.objectType {
                return true
            }
            return false
        }.map { $0.key }
        for id in textIDs {
            document.snapshot.objects.removeValue(forKey: id)
        }
        document.viewState.selectedObjectIDs.removeAll()
    }

    private func promptForMissingImage(shapeID: UUID, originalPath: String) {
        guard let document = document else { return }
        let filename = URL(fileURLWithPath: originalPath).lastPathComponent
        let panel = NSOpenPanel()
        panel.message = "The linked image '\(filename)' could not be found. Please locate it."
        panel.prompt = "Choose Image"
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let originalDir = URL(fileURLWithPath: originalPath).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: originalDir.path) {
            panel.directoryURL = originalDir
        }
        panel.begin { [weak self] response in
            guard let self = self,
                  response == .OK,

                  let newURL = panel.url else {
                return
            }
            if var shape = document.snapshot.objects[shapeID]?.shape {
                shape.embeddedImageData = nil
                shape.linkedImagePath = newURL.path
                let newFilename = newURL.lastPathComponent
                shape.name = "[IMG] \(newFilename)"
                if let bookmark = try? newURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    shape.linkedImageBookmarkData = bookmark
                }
                ImageContentRegistry.dequarantine(newURL)
                if let existingObject = document.snapshot.objects[shapeID] {
                    let updatedObject = VectorObject(
                        id: shapeID,
                        layerIndex: existingObject.layerIndex,
                        objectType: .image(shape)
                    )
                    document.snapshot.objects[shapeID] = updatedObject
                    document.triggerLayerUpdate(for: existingObject.layerIndex)
                }
                self.promptedMissingImages.remove(shapeID)
            }
        }
    }
}
