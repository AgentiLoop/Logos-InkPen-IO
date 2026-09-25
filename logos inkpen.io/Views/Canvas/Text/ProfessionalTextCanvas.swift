import SwiftUI
import AppKit
import simd

struct ProfessionalTextCanvas: View {

    @ObservedObject var document: VectorDocument

    @StateObject private var viewModel: ProfessionalTextViewModel

    let textObjectID: UUID
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode
    let letterSpacingDelta: Double?
    let lineHeightDelta: Double?
    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?

    @Binding var textContentDelta: (id: UUID, content: String)?
    init(document: VectorDocument, textObjectID: UUID, zoomLevel: Double, canvasOffset: CGPoint, dragPreviewDelta: CGPoint = .zero, dragPreviewTrigger: Bool = false, viewMode: ViewMode = .color, letterSpacingDelta: Double? = nil, lineHeightDelta: Double? = nil, fontSizeDelta: Double? = nil, lineSpacingDelta: Double? = nil, textContentDelta: Binding<(id: UUID, content: String)?>) {
        self.document = document
        self.textObjectID = textObjectID
        self.zoomLevel = zoomLevel
        self.canvasOffset = canvasOffset
        self.dragPreviewDelta = dragPreviewDelta
        self.dragPreviewTrigger = dragPreviewTrigger
        self.viewMode = viewMode
        self.letterSpacingDelta = letterSpacingDelta
        self.lineHeightDelta = lineHeightDelta
        self.fontSizeDelta = fontSizeDelta
        self.lineSpacingDelta = lineSpacingDelta
        self._textContentDelta = textContentDelta
        let actualText = document.findText(by: textObjectID) ?? VectorText(content: "", typography: TypographyProperties(strokeColor: .black, fillColor: .black))
        self._viewModel = StateObject(wrappedValue: ProfessionalTextViewModel(textObject: actualText, document: document))
    }

    var body: some View {
        let textObject = document.findText(by: textObjectID) ?? viewModel.textObject
        let bounds = textObject.bounds
        let position = textObject.position
        let fontSize = fontSizeDelta ?? textObject.typography.fontSize
        let lineHeight: CGFloat
        if let delta = lineHeightDelta {
            lineHeight = CGFloat(delta)
        } else if let delta = fontSizeDelta {
            lineHeight = CGFloat(delta) * (textObject.typography.lineHeight / textObject.typography.fontSize)
        } else {
            lineHeight = textObject.typography.lineHeight
        }
        let letterSpacing = letterSpacingDelta ?? textObject.typography.letterSpacing
        let lineSpacing = lineSpacingDelta ?? textObject.typography.lineSpacing
        let fontFamily = textObject.typography.fontFamily
        let fontVariant = textObject.typography.fontVariant
        let fillColor = textObject.typography.fillColor
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let zoom = Float(zoomLevel)
        let dragDelta = SIMD2<Float>(Float(dragPreviewDelta.x), Float(dragPreviewDelta.y))
        let scaledDrag = dragDelta * zoom
        return TextViewRepresentable(
            viewModel: viewModel,
            viewMode: viewMode,
            letterSpacing: letterSpacing,
            lineHeight: lineHeight,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            fontFamily: fontFamily,
            fontVariant: fontVariant,
            fillColor: fillColor,
            fontManager: document.fontManager,
            textContentDelta: $textContentDelta
        )
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .position(x: position.x + bounds.width / 2, y: position.y + bounds.height / 2)
        .scaleEffect(CGFloat(zoom), anchor: .topLeading)
        .offset(x: CGFloat(offsetVec.x), y: CGFloat(offsetVec.y))
        .offset(x: shouldApplyDragPreview() ? CGFloat(scaledDrag.x) : 0,
                y: shouldApplyDragPreview() ? CGFloat(scaledDrag.y) : 0)
        .onKeyPress(action: handleKeyPress)
    }

    private func shouldApplyDragPreview() -> Bool {
        if document.viewState.selectedObjectIDs.contains(textObjectID) {
            return true
        }
        for selectedID in document.viewState.selectedObjectIDs {
            if let selectedObject = document.findObject(by: selectedID) {
                switch selectedObject.objectType {
                case .group(let selectedShape), .clipGroup(let selectedShape):
                    if selectedShape.isGroupContainer && selectedShape.groupedShapes.contains(where: { $0.id == textObjectID }) {
                        return true
                    }
                default:
                    continue
                }
            }
        }
        return false
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard viewModel.isEditing && keyPress.key == .escape else { return .ignored }
        viewModel.document.updateTextContent(viewModel.textObject.id, content: viewModel.text)
        viewModel.updateDocumentTextBounds(viewModel.textBoxFrame)
        viewModel.stopEditing()
        document.setTextEditingInUnified(id: viewModel.textObject.id, isEditing: false)
        NSApp.keyWindow?.makeFirstResponder(nil)
        return .handled
    }

    struct TextViewRepresentable: NSViewRepresentable {

        @ObservedObject var viewModel: ProfessionalTextViewModel

        @State var isUpdatingFromTyping: Bool = false

        let viewMode: ViewMode
        let letterSpacing: CGFloat
        let lineHeight: CGFloat
        let fontSize: CGFloat
        let lineSpacing: CGFloat
        let fontFamily: String
        let fontVariant: String?
        let fillColor: VectorColor
        let fontManager: FontManager

        @Binding var textContentDelta: (id: UUID, content: String)?
        func makeNSView(context: Context) -> DisabledContextMenuTextView {
            let textView = DisabledContextMenuTextView()
            let width = viewModel.textObject.areaSize?.width ?? viewModel.textObject.bounds.width
            let height = viewModel.textObject.areaSize?.height ?? viewModel.textObject.bounds.height
            textView.isEditable = true
            textView.isSelectable = true
            textView.backgroundColor = CGColor.clear.platformColor
            textView.textContainerInset = CGSize(width: 0, height: 0)
            textView.textContainer?.lineFragmentPadding = 0
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
            textView.isVerticallyResizable = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = []
            textView.textContainer?.containerSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.lineBreakMode = .byWordWrapping
            textView.frame = CGRect(x: 0, y: 0, width: width, height: height)
            textView.maxSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.minSize = CGSize(width: width, height: 50)
            textView.allowsUndo = true
            textView.usesFindPanel = true
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.menu = nil
            textView.delegate = context.coordinator

            let liveFont: PlatformFont = {
                if let variant = fontVariant,
                   let postScriptName = fontManager.getPostScriptName(family: fontFamily, variant: variant),

                   let font = PlatformFont(name: postScriptName, size: fontSize) {
                    return font
                }
                return PlatformFont(name: fontFamily, size: fontSize) ?? PlatformFont.systemFont(ofSize: fontSize)
            }()
            textView.font = liveFont
            textView.textColor = CGColor.clear.platformColor
            textView.allowsInteraction = true
            textView.shouldShowCursor = true
            textView.string = viewModel.text
            if !viewModel.text.isEmpty {
                let range = NSRange(location: 0, length: viewModel.text.count)
                textView.textStorage?.beginEditing()
                textView.textStorage?.addAttribute(.kern, value: letterSpacing, range: range)
                textView.textStorage?.endEditing()
                textView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                if let textContainer = textView.textContainer {
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
            }
            context.coordinator.textView = textView
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
            return textView
        }

        func updateNSView(_ nsView: DisabledContextMenuTextView, context: Context) {
            let coordinator = context.coordinator
            if !isUpdatingFromTyping {
                coordinator.isRestoringSelection = true
                DispatchQueue.main.async { coordinator.isRestoringSelection = false }
            }
            let now = Date()
            if isUpdatingFromTyping && now.timeIntervalSince(coordinator.lastUpdateTime) < 0.1 {
                return
            }
            coordinator.lastUpdateTime = now
            if !isUpdatingFromTyping && nsView.string != viewModel.text {
                nsView.string = viewModel.text
            }

            let liveFont: PlatformFont = {
                if let variant = fontVariant,
                   let postScriptName = fontManager.getPostScriptName(family: fontFamily, variant: variant),

                   let font = PlatformFont(name: postScriptName, size: fontSize) {
                    return font
                }
                return PlatformFont(name: fontFamily, size: fontSize) ?? PlatformFont.systemFont(ofSize: fontSize)
            }()
            nsView.font = liveFont
            if nsView.string.count > 0 {
                let range = NSRange(location: 0, length: nsView.string.count)
                nsView.textStorage?.beginEditing()
                nsView.textStorage?.addAttribute(.font, value: liveFont, range: range)
                nsView.textStorage?.addAttribute(.foregroundColor, value: CGColor.clear.platformColor, range: range)
                nsView.textStorage?.addAttribute(.kern, value: letterSpacing, range: range)
                nsView.textStorage?.endEditing()
                if let textContainer = nsView.textContainer {
                    nsView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                    nsView.layoutManager?.ensureLayout(for: textContainer)
                }
            }
            let width = viewModel.textObject.areaSize?.width ?? viewModel.textObject.bounds.width
            let height = viewModel.textObject.areaSize?.height ?? viewModel.textObject.bounds.height
            let currentWidth = nsView.textContainer?.containerSize.width ?? 0
            if abs(currentWidth - width) > 1.0 {
                nsView.textContainer?.containerSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                nsView.frame = CGRect(x: 0, y: 0, width: width, height: height)
                nsView.maxSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                nsView.minSize = CGSize(width: width, height: 50)
                nsView.textContainer.flatMap { nsView.layoutManager?.ensureLayout(for: $0) }
            }
            applyStyle(to: nsView)
            DispatchQueue.main.async {
                if nsView.window?.firstResponder != nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }

        private func applyStyle(to textView: NSTextView) {
            let cursorColor: PlatformColor
            if viewMode == .keyline {
                cursorColor = CGColor.black.platformColor
            } else {
                let fillCGColor = fillColor.cgColor
                if let components = fillCGColor.components, components.count >= 3 {
                    let colorWithOpacity = CGColor(red: components[0], green: components[1], blue: components[2], alpha: 1.0)
                    cursorColor = colorWithOpacity.platformColor
                } else {
                    cursorColor = fillCGColor.platformColor
                }
            }
            textView.insertionPointColor = cursorColor
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = viewModel.textAlignment
            paragraphStyle.lineSpacing = max(0, lineSpacing)
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
            textView.defaultParagraphStyle = paragraphStyle

            let liveFont: PlatformFont = {
                if let variant = fontVariant,
                   let postScriptName = fontManager.getPostScriptName(family: fontFamily, variant: variant),

                   let font = PlatformFont(name: postScriptName, size: fontSize) {
                    return font
                }
                return PlatformFont(name: fontFamily, size: fontSize) ?? PlatformFont.systemFont(ofSize: fontSize)
            }()
            textView.typingAttributes = [
                .font: textView.font ?? liveFont,
                .foregroundColor: PlatformColor.clear,
                .paragraphStyle: paragraphStyle,
                .kern: letterSpacing
            ]
            if textView.string.count > 0 {
                let range = NSRange(location: 0, length: textView.string.count)
                textView.textStorage?.beginEditing()
                textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                textView.textStorage?.addAttribute(.foregroundColor, value: PlatformColor.clear, range: range)
                textView.textStorage?.addAttribute(.kern, value: letterSpacing, range: range)
                textView.textStorage?.endEditing()
                if let textContainer = textView.textContainer {
                    textView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, NSTextViewDelegate {
            var parent: TextViewRepresentable
            var lastUpdateTime: Date = Date()
            var isRestoringSelection: Bool = false

            weak var textView: DisabledContextMenuTextView?

            var updateTimer: Timer?
            var originalText: String?

            init(_ parent: TextViewRepresentable) {
                self.parent = parent
                self.originalText = parent.viewModel.text
            }

            func textDidChange(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView, textView.isEditable else { return }
                let newText = textView.string
                guard newText != parent.viewModel.text else { return }
                parent.isUpdatingFromTyping = true
                let textObjectId = parent.viewModel.textObject.id
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.viewModel.text = newText
                    self.parent.viewModel.updateLastTypingTime()
                    self.parent.textContentDelta = (textObjectId, newText)
                    self.updateTimer?.invalidate()
                    self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        if let originalText = self.originalText, originalText != newText {
                            let command = TextContentCommand(
                                textID: textObjectId,
                                oldContent: originalText,
                                newContent: newText
                            )
                            self.parent.viewModel.document.executeCommand(command)
                            self.originalText = newText
                        } else {
                            self.parent.viewModel.document.updateTextContent(textObjectId, content: newText)
                        }
                        self.parent.textContentDelta = nil
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.parent.isUpdatingFromTyping = false
                }
            }

            func textViewDidChangeSelection(_ notification: Notification) {
                guard !isRestoringSelection, let textView = notification.object as? NSTextView else { return }
                let selectedRange = textView.selectedRange()
                if textView.string.count > 0, selectedRange.location < textView.string.count {
                    if let attrs = textView.textStorage?.attributes(at: selectedRange.location, effectiveRange: nil) {
                        textView.typingAttributes = attrs
                    }
                }
            }

            func textDidEndEditing(_ notification: Notification) {
                let finalText = parent.viewModel.text
                let textFrame = parent.viewModel.textBoxFrame
                let textObjectId = parent.viewModel.textObject.id
                updateTimer?.invalidate()
                updateTimer = nil
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.textContentDelta = nil
                    if let originalText = self.originalText, originalText != finalText {
                        let command = TextContentCommand(
                            textID: textObjectId,
                            oldContent: originalText,
                            newContent: finalText,
                            oldBounds: nil,
                            newBounds: textFrame
                        )
                        self.parent.viewModel.document.executeCommand(command)
                        self.originalText = finalText
                    } else {
                        self.parent.viewModel.document.updateTextContent(textObjectId, content: finalText)
                    }
                    self.parent.viewModel.updateDocumentTextBounds(textFrame)
                    self.parent.isUpdatingFromTyping = false
                }
            }
        }
    }
}
