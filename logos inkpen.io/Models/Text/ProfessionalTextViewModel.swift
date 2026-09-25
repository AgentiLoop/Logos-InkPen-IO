import SwiftUI
import AppKit
import CoreText
import Combine

@MainActor
class ProfessionalTextViewModel: ObservableObject {

    @Published var text: String = ""
    @Published var fontSize: CGFloat = 24.0
    @Published var selectedFont: PlatformFont = PlatformFont.systemFont(ofSize: 24.0)
    @Published var textAlignment: NSTextAlignment = .center
    @Published var isEditing: Bool = false
    @Published var textBoxFrame: CGRect = CGRect(x: 100, y: 100, width: 200, height: 100)
    @Published var textObject: VectorText

    let document: VectorDocument

    var linePaths: [CGPath] = []

    init(textObject: VectorText, document: VectorDocument) {
        self.textObject = textObject
        self.document = document
        self.text = textObject.content
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        self.textAlignment = textObject.typography.alignment.nsTextAlignment
        let width = textObject.areaSize?.width ?? 200.0
        let height = textObject.areaSize?.height ?? calculateTextHeight(for: textObject.content)
        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: width,
            height: height
        )
        self.isEditing = textObject.isEditing
    }

    private func calculateTextHeight(for content: String) -> CGFloat {
        guard !content.isEmpty else { return 50.0 }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: selectedFont,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: textBoxFrame.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: content.count))
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return max(50.0, ceil(usedRect.height + 10))
    }

    func syncFromDocument(_ textObject: VectorText) {
        guard self.textObject.id == textObject.id else {
            Log.error("❌ SYNC ERROR: Mismatched text IDs", category: .error)
            return
        }
        if isEditing && Date().timeIntervalSince1970 - lastTypingTime < 0.1 {
            return
        }
        let contentChanged = self.text != textObject.content
        let documentContentEmpty = textObject.content.isEmpty
        let viewModelContentNotEmpty = !self.text.isEmpty
        let shouldSyncContent = contentChanged && !(documentContentEmpty && viewModelContentNotEmpty)
        let fontChanged = self.fontSize != CGFloat(textObject.typography.fontSize)
        let editingChanged = self.isEditing != textObject.isEditing
        let colorChanged = self.textObject.typography.fillColor != textObject.typography.fillColor
        let typographyChanged = (
            self.textObject.typography.alignment != textObject.typography.alignment ||
            self.textObject.typography.fontFamily != textObject.typography.fontFamily ||
            self.textObject.typography.fontVariant != textObject.typography.fontVariant ||
            abs(self.textObject.typography.lineHeight - textObject.typography.lineHeight) > 0.01 ||
            abs(self.textObject.typography.lineSpacing - textObject.typography.lineSpacing) > 0.01
        )
        let positionChanged = (
            abs(self.textBoxFrame.origin.x - textObject.position.x) > 0.1 ||
            abs(self.textBoxFrame.origin.y - textObject.position.y) > 0.1
        )
        let sizeChanged = (
            abs(self.textBoxFrame.width - textObject.bounds.width) > 0.1 ||
            abs(self.textBoxFrame.height - textObject.bounds.height) > 0.1
        )
        if !shouldSyncContent && !fontChanged && !editingChanged && !colorChanged && !typographyChanged && !positionChanged && !sizeChanged {
            return
        }
        let wasAutoResizing = isAutoResizing
        isAutoResizing = true
        defer { isAutoResizing = wasAutoResizing }
        self.textObject = textObject
        if shouldSyncContent {
            self.text = textObject.content
        }
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        if !self.isEditing {
            self.isEditing = textObject.isEditing
        }
        self.textAlignment = textObject.typography.alignment.nsTextAlignment
        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: textObject.bounds.width,
            height: textObject.bounds.height
        )
    }
    private var lastTypingTime: TimeInterval = 0

    func updateLastTypingTime() {
        lastTypingTime = Date().timeIntervalSince1970
    }
    var isAutoResizing = false

    func startEditing() {
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType,
               shape.id != textObject.id,
               shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }
        }
        isEditing = true
    }

    func stopEditing() {
        isEditing = false
        updateDocumentTextBounds(textBoxFrame)
    }

    func updateTextBoxFrame(_ newFrame: CGRect) {
        isAutoResizing = true
        textBoxFrame = newFrame
        updateDocumentTextBounds(newFrame)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isAutoResizing = false
        }
    }

    func updateDocumentTextBounds(_ frame: CGRect) {
        document.updateShapeByID(textObject.id) { shape in
            shape.transform = CGAffineTransform(translationX: frame.minX, y: frame.minY)
            shape.textPosition = CGPoint(x: frame.minX, y: frame.minY)
            shape.bounds = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
            shape.areaSize = CGSize(width: frame.width, height: frame.height)
        }
    }

    private func isRectangleGlyph(_ path: CGPath) -> Bool {
        var subpaths: [[CGPoint]] = []
        var currentPath: [CGPoint] = []
        var hasCurves = false
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                }
                currentPath = [element.points[0]]
            case .addLineToPoint:
                currentPath.append(element.points[0])
            case .addQuadCurveToPoint, .addCurveToPoint:
                hasCurves = true
            case .closeSubpath:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = []
                }

            @unknown default:
                break
            }
        }
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        if hasCurves {
            return false
        }
        if subpaths.count != 2 {
            return false
        }
        for subpath in subpaths {
            if subpath.count < 4 || subpath.count > 5 {
                return false
            }
            if !isRectangularPath(subpath) {
                return false
            }
        }
        let bounds1 = boundingBox(of: subpaths[0])
        let bounds2 = boundingBox(of: subpaths[1])
        let isNested = (bounds1.contains(bounds2) || bounds2.contains(bounds1))
        if isNested {
            Log.warning("⚠️ DETECTED RECTANGLE GLYPH: Missing character placeholder with rectangular counter", category: .general)
            return true
        }
        return false
    }

    private func isRectangularPath(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4 else { return false }
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = abs(p2.x - p1.x)
            let dy = abs(p2.y - p1.y)
            let isHorizontal = dy < 0.1 && dx > 0.1
            let isVertical = dx < 0.1 && dy > 0.1
            if !isHorizontal && !isVertical {
                return false
            }
        }
        return true
    }

    private func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func convertUsingNSLayoutManager() {
        linePaths = CTLineTextConverter.convertTextToPaths(
            text: text,
            font: selectedFont,
            textBoxFrame: textBoxFrame,
            alignment: textAlignment,
            lineSpacing: textObject.typography.lineSpacing,
            lineHeight: textObject.typography.lineHeight,
            letterSpacing: textObject.typography.letterSpacing
        )
    }

    private func convertToCoreTextPath() {
        convertUsingNSLayoutManager()
    }

    func convertToPath() {
        guard !text.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES: Cannot convert empty text", category: .error)
            return
        }
        convertToCoreTextPath()
        guard !linePaths.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES FAILED: No line paths created", category: .error)
            return
        }
        let targetLayerIndex = document.selectedLayerIndex ?? 2
        let textPositionInLayer = document.snapshot.layers[targetLayerIndex].objectIDs.firstIndex(of: textObject.id)

        var createdShapeIDs: [UUID] = []
        for (lineIndex, linePath) in linePaths.enumerated() {
            let vectorPath = convertCGPathToVectorPath(linePath)
            let lineName = "Line \(lineIndex + 1)"
            let strokeStyle: StrokeStyle? = textObject.typography.hasStroke ? StrokeStyle(
                color: textObject.typography.strokeColor,
                width: textObject.typography.strokeWidth,
                placement: .center,
                dashPattern: [],
                lineCap: .round,
                lineJoin: textObject.typography.strokeLineJoin.cgLineJoin,
                miterLimit: 4.0,
                opacity: textObject.typography.strokeOpacity
            ) : nil
            let outlineShape = VectorShape(
                name: lineName,
                path: vectorPath,
                strokeStyle: strokeStyle,
                fillStyle: FillStyle(
                    color: textObject.typography.fillColor,
                    opacity: textObject.typography.fillOpacity
                ),
                transform: .identity,
                isGroup: false,
                isCompoundPath: true,
                textContent: nil,
                typography: nil,
                cursorPosition: nil,
                areaSize: nil,
                isEditing: nil,
                textPosition: nil
            )
            let shapeObject = VectorObject(id: outlineShape.id, layerIndex: targetLayerIndex, objectType: .shape(outlineShape))
            document.snapshot.objects[outlineShape.id] = shapeObject
            createdShapeIDs.append(outlineShape.id)
        }
        if let insertIndex = textPositionInLayer {
            for (offset, shapeID) in createdShapeIDs.enumerated() {
                document.snapshot.layers[targetLayerIndex].objectIDs.insert(shapeID, at: insertIndex + offset)
            }
        } else {
            for shapeID in createdShapeIDs {
                if !document.snapshot.layers[targetLayerIndex].objectIDs.contains(shapeID) {
                    document.snapshot.layers[targetLayerIndex].objectIDs.append(shapeID)
                }
            }
        }
        document.removeTextFromUnifiedSystem(id: textObject.id)
    }

    func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
        var elements: [PathElement] = []
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(Double(point.x), Double(point.y))))
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(Double(point.x), Double(point.y))))
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control: VectorPoint(Double(control.x), Double(control.y))
                ))
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control1: VectorPoint(Double(control1.x), Double(control1.y)),
                    control2: VectorPoint(Double(control2.x), Double(control2.y))
                ))
            case .closeSubpath:
                elements.append(.close)

            @unknown default:
                break
            }
        }
        elements = makeCurvesSmooth(elements)
        return VectorPath(elements: elements, isClosed: false, fillRule: .evenOdd)
    }

    private func makeCurvesSmooth(_ elements: [PathElement]) -> [PathElement] {
        var smoothedElements: [PathElement] = []

        let angleTolerance = 10.0 * .pi / 180.0
        for i in 0..<elements.count {
            let currentElement = elements[i]
            guard case .curve(let anchor, let incomingHandle, let outgoingHandle) = currentElement else {
                smoothedElements.append(currentElement)
                continue
            }
            let incomingVec = CGVector(dx: incomingHandle.x - anchor.x, dy: incomingHandle.y - anchor.y)
            let outgoingVec = CGVector(dx: outgoingHandle.x - anchor.x, dy: outgoingHandle.y - anchor.y)
            let incomingAngle = atan2(incomingVec.dy, incomingVec.dx)
            let outgoingAngle = atan2(outgoingVec.dy, outgoingVec.dx)

            var angleDiff = abs(incomingAngle - outgoingAngle)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }
            if abs(angleDiff - .pi) < angleTolerance {
                let incomingLength = sqrt(incomingVec.dx * incomingVec.dx + incomingVec.dy * incomingVec.dy)
                let outgoingLength = sqrt(outgoingVec.dx * outgoingVec.dx + outgoingVec.dy * outgoingVec.dy)
                let avgLength = (incomingLength + outgoingLength) / 2.0
                let outgoingNormalized = CGVector(
                    dx: outgoingVec.dx / outgoingLength,
                    dy: outgoingVec.dy / outgoingLength
                )
                let smoothedIncoming = VectorPoint(
                    anchor.x - outgoingNormalized.dx * avgLength,
                    anchor.y - outgoingNormalized.dy * avgLength
                )
                let smoothedOutgoing = VectorPoint(
                    anchor.x + outgoingNormalized.dx * avgLength,
                    anchor.y + outgoingNormalized.dy * avgLength
                )
                smoothedElements.append(.curve(to: anchor, control1: smoothedIncoming, control2: smoothedOutgoing))
                continue
            }
            smoothedElements.append(currentElement)
        }
        return smoothedElements
    }

    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false, at location: CGPoint = .zero) {
        guard let textObject = document.findText(by: textID) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
        let currentState = textObject.getState(in: document)
        if textObject.isLocked {
            Log.warning("🚫 TEXT LOCKED: Cannot interact with locked text", category: .general)
            return
        }
        if isDoubleClick || isCornerClick {
            switch currentState {
            case .unselected:
                document.viewState.selectedObjectIDs = [textID]
                if document.viewState.currentTool == .font && isCornerClick {
                    startEditingText(textID: textID, at: location, isDoubleClickFromArrow: false)
                }
            case .selected:
                if isDoubleClick {
                    let needsAdjustment = document.viewState.currentTool != .font
                    document.viewState.currentTool = .font
                    startEditingText(textID: textID, at: location, isDoubleClickFromArrow: needsAdjustment)
                } else if document.viewState.currentTool == .font {
                    startEditingText(textID: textID, at: location, isDoubleClickFromArrow: false)
                }
            case .editing:
                break
            }
        } else {
            switch currentState {
            case .unselected:
                document.viewState.selectedObjectIDs = [textID]
            case .selected:
                break
            case .editing:
                break
            }
        }
    }

    private func startEditingText(textID: UUID, at location: CGPoint = .zero, isDoubleClickFromArrow: Bool = false) {
        var editingCount = 0
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                editingCount += 1
            }
        }
        if let textObject = document.findText(by: textID) {
            document.setTextEditingInUnified(id: textObject.id, isEditing: true)
            document.viewState.selectedObjectIDs = [textID]
        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }
}
