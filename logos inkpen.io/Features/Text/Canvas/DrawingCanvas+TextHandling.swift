import SwiftUI
import Combine

extension DrawingCanvas {

    func handleFontToolTap(at location: CGPoint) {
        lastTapLocation = location
        let hasSelectedOrEditingText = document.viewState.selectedObjectIDs.contains { id in
            if let obj = document.findObject(by: id),
               case .text = obj.objectType {
                return true
            }
            return false
        }
        if hasSelectedOrEditingText {
            return
        }
        if let existingTextID = findTextAt(location: location) {
            startEditingText(textID: existingTextID, at: location)
        } else {
            createNewTextAt(location: location)
        }
    }

    func handleAggressiveBackgroundTap(at location: CGPoint) {
        let tapHitsText = document.snapshot.objects.values.contains { obj in
            switch obj.objectType {
            case .text(let shape):
                if !shape.isVisible || shape.isLocked { return false }
                let textPos = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                let exactBounds = CGRect(
                    x: textPos.x,
                    y: textPos.y,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
                let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)
                return expandedBounds.contains(location)
            case .group(let shape), .clipGroup(let shape):
                for childShape in shape.groupedShapes {
                    if childShape.typography != nil {
                        if !childShape.isVisible || childShape.isLocked { continue }
                        let textPos = CGPoint(x: childShape.transform.tx, y: childShape.transform.ty)
                        let exactBounds = CGRect(
                            x: textPos.x,
                            y: textPos.y,
                            width: childShape.bounds.width,
                            height: childShape.bounds.height
                        )
                        let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)
                        if expandedBounds.contains(location) {
                            return true
                        }
                    }
                }
                return false
            case .shape, .image, .warp, .clipMask, .guide:
                return false
            }
        }
        if !tapHitsText {
            document.viewState.selectedObjectIDs.removeAll()
            for obj in document.snapshot.objects.values {
                switch obj.objectType {
                case .text(let shape):
                    if shape.isEditing == true {
                        document.setTextEditingInUnified(id: shape.id, isEditing: false)
                    }
                case .group(let shape):
                    for childShape in shape.groupedShapes {
                        if childShape.typography != nil && childShape.isEditing == true {
                            document.setTextEditingInUnified(id: childShape.id, isEditing: false)
                        }
                    }
                case .shape, .image, .warp, .clipGroup, .clipMask, .guide:
                    break
                }
            }
            finishTextEditing()
        }
    }

    func findTextAt(location: CGPoint) -> UUID? {
        for obj in document.snapshot.objects.values {
            switch obj.objectType {
            case .text(let shape):
                if !shape.isVisible || shape.isLocked { continue }
                let textPos = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                let textBounds = CGRect(
                    x: textPos.x,
                    y: textPos.y,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
                if textBounds.contains(location) {
                    return shape.id
                }
            case .group(let shape), .clipGroup(let shape):
                for childShape in shape.groupedShapes {
                    if childShape.typography != nil {
                        if !childShape.isVisible || childShape.isLocked { continue }
                        let textPos = CGPoint(x: childShape.transform.tx, y: childShape.transform.ty)
                        let textBounds = CGRect(
                            x: textPos.x,
                            y: textPos.y,
                            width: childShape.bounds.width,
                            height: childShape.bounds.height
                        )
                        if textBounds.contains(location) {
                            return childShape.id
                        }
                    }
                }
            case .shape, .image, .warp, .clipMask, .guide:
                break
            }
        }
        return nil
    }

    func startEditingText(textID: UUID, at location: CGPoint, isDoubleClickFromArrow: Bool = false) {
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType,
               shape.id != textID,
               shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }
        }
        if let textObject = document.findText(by: textID) {
            document.setTextEditingInUnified(id: textObject.id, isEditing: true)
            document.viewState.orderedSelectedObjectIDs = [textID]
            document.viewState.selectedObjectIDs = [textID]
            isEditingText = true
            editingTextID = textID
        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }

    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false, at location: CGPoint = .zero) {
        guard let textObject = document.findText(by: textID) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
        let currentState = textObject.getState(in: document)
        if textObject.isLocked {
            return
        }
        if isDoubleClick || isCornerClick {
            switch currentState {
            case .unselected:
                document.viewState.orderedSelectedObjectIDs = [textID]
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
                document.viewState.orderedSelectedObjectIDs = [textID]
                document.viewState.selectedObjectIDs = [textID]
            case .selected:
                break
            case .editing:
                break
            }
        }
    }

    func calculateCursorPosition(in textObj: VectorText, at tapLocation: CGPoint) -> Int {
        let relativePoint = CGPoint(
            x: tapLocation.x - textObj.position.x,
            y: tapLocation.y - textObj.position.y
        )
        let attributes = textObj.typography.textAttributes()
        let attributedString = NSAttributedString(string: textObj.content, attributes: attributes)
        let containerWidth = textObj.areaSize?.width ?? textObj.bounds.width
        let textContainer = NSTextContainer(containerSize: CGSize(
            width: containerWidth,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage(attributedString: attributedString)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let characterIndex = layoutManager.characterIndex(
            for: relativePoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        let finalIndex = max(0, min(textObj.content.count, characterIndex))
        return finalIndex
    }

    func createNewTextAt(location: CGPoint) {
        createNewTextWithSize(at: location, width: 300, height: 100)
    }

    func createNewTextWithSize(at location: CGPoint, width: CGFloat, height: CGFloat) {
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontVariant: document.fontManager.selectedFontVariant,
            fontSize: document.fontManager.selectedFontSize,
            lineHeight: document.fontManager.selectedLineHeight,
            lineSpacing: document.fontManager.selectedLineSpacing,
            letterSpacing: 0.0,
            alignment: document.fontManager.selectedTextAlignment,
            hasStroke: false,
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,
            fillOpacity: document.defaultFillOpacity
        )
        let emptyPath = VectorPath(elements: [], isClosed: false)

        var shape = VectorShape(
            name: "Text",
            path: emptyPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: CGAffineTransform(translationX: location.x, y: location.y),
            textContent: "",
            typography: typography,
            areaSize: CGSize(width: width, height: height),
            isEditing: true,
            textPosition: location
        )
        shape.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        document.addShape(shape)
        document.viewState.orderedSelectedObjectIDs = [shape.id]
        document.viewState.selectedObjectIDs = [shape.id]
        isEditingText = true
        editingTextID = shape.id
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
    }

    func insertTextAtCursor(_ text: String) {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID) else { return }
        let insertIndex = textObj.content.index(
            textObj.content.startIndex,
            offsetBy: min(currentCursorPosition, textObj.content.count)
        )
        textObj.content.insert(contentsOf: text, at: insertIndex)
        currentCursorPosition += text.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        textObj.updateBounds()
        document.updateTextInUnified(textObj)
    }

    func deleteBackward() {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID) else { return }
        if currentSelectionRange.length > 0 {
            deleteSelectedText()
        } else if currentCursorPosition > 0 {
            let deleteIndex = textObj.content.index(
                textObj.content.startIndex,
                offsetBy: currentCursorPosition - 1
            )
            textObj.content.remove(at: deleteIndex)
            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
            textObj.updateBounds()
            document.updateTextInUnified(textObj)
        }
    }

    func deleteSelectedText() {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID),
              currentSelectionRange.length > 0 else { return }
        let startIndex = textObj.content.index(
            textObj.content.startIndex,
            offsetBy: currentSelectionRange.location
        )
        let endIndex = textObj.content.index(
            startIndex,
            offsetBy: currentSelectionRange.length
        )
        textObj.content.removeSubrange(startIndex..<endIndex)
        currentCursorPosition = currentSelectionRange.location
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        textObj.updateBounds()
        document.updateTextInUnified(textObj)
    }

    func selectAll() {
        guard let editingID = editingTextID,
              let textObj = document.findText(by: editingID) else { return }
        currentSelectionRange = NSRange(location: 0, length: textObj.content.count)
        currentCursorPosition = textObj.content.count
    }

    func moveCursorLeft() {
        if currentCursorPosition > 0 {
            currentCursorPosition -= 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        }
    }

    func moveCursorRight() {
        guard let editingID = editingTextID,
              let textObj = document.findText(by: editingID) else { return }
        if currentCursorPosition < textObj.content.count {
            currentCursorPosition += 1
            currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
        }
    }

    func moveCursorToBeginning() {
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
    }

    func moveCursorToEnd() {
        guard let editingID = editingTextID,
              let textObj = document.findText(by: editingID) else { return }
        currentCursorPosition = textObj.content.count
        currentSelectionRange = NSRange(location: currentCursorPosition, length: 0)
    }

    func finishTextEditing() {
        if let editingID = editingTextID {
            if var textObj = document.findText(by: editingID) {
                textObj.updateBounds()
                document.updateTextBoundsInUnified(id: editingID, bounds: textObj.bounds)
            }
            document.setTextEditingInUnified(id: editingID, isEditing: false)
        }
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        isTextEditingMode = false
        #if os(macOS)
        NSCursor.arrow.set()
        #endif
        if let window = NSApp.keyWindow {
            window.makeFirstResponder(nil)
        }
    }

    func cancelTextEditing() {
        if let editingID = editingTextID {
            if let textObj = document.findText(by: editingID) {
                if textObj.content.isEmpty {
                    document.removeTextFromUnifiedSystem(id: editingID)
                } else {
                    document.setTextEditingInUnified(id: textObj.id, isEditing: false)
                }
            }
        }
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        isTextEditingMode = false
        #if os(macOS)
        NSCursor.arrow.set()
        #endif
        if let window = NSApp.keyWindow {
            window.makeFirstResponder(nil)
        }
        Log.error("❌ Cancelled text editing", category: .error)
    }

    func handleTextKeyPress(_ key: String) {
        guard isEditingText else { return }
        switch key {
        case "\u{08}":
            deleteBackward()
        case "\u{7F}":
            deleteForward()
        case "\u{1B}":
            finishTextEditing()
        case "\u{0D}", "\u{0A}":
            finishTextEditing()
        default:
            if key.count == 1 && !key.isEmpty {
                insertTextAtCursor(key)
            }
        }
    }

    private func deleteForward() {
        guard let editingID = editingTextID,
              var textObj = document.findText(by: editingID) else { return }
        if currentSelectionRange.length > 0 {
            deleteSelectedText()
        } else if currentCursorPosition < textObj.content.count {
            let deleteIndex = textObj.content.index(
                textObj.content.startIndex,
                offsetBy: currentCursorPosition
            )
            textObj.content.remove(at: deleteIndex)
            textObj.updateBounds()
            document.updateTextInUnified(textObj)
        }
    }

    func handleTextSelectionChange(textID: UUID, isSelected: Bool) {
        if isSelected {
            document.viewState.selectedObjectIDs.insert(textID)
        } else {
            document.viewState.selectedObjectIDs.remove(textID)
        }
    }

    func handleTextEditingChange(textID: UUID, isEditing: Bool) {
        if isEditing {
            isEditingText = true
            editingTextID = textID
            if let textObj = document.findText(by: textID) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: true)
            }
            document.viewState.selectedObjectIDs.insert(textID)
        } else {
            if let textObj = document.findText(by: textID) {
                document.setTextEditingInUnified(id: textObj.id, isEditing: false)
            }
            if editingTextID == textID {
                isEditingText = false
                editingTextID = nil
                currentCursorPosition = 0
                currentSelectionRange = NSRange(location: 0, length: 0)
            }
        }
    }

    func handleTextContentChange(textID: UUID, newContent: String) {
        guard var textObj = document.findText(by: textID) else { return }
        document.updateTextContentInUnified(id: textObj.id, content: newContent)
        textObj.updateBounds()
        document.updateTextInUnified(textObj)
    }

    func handleTextPositionChange(textID: UUID, newPosition: CGPoint) {
        guard let textObj = document.findText(by: textID) else { return }
        document.modifyShapesWithUndo(shapeIDs: [textID]) { _ in
            document.updateTextPositionInUnified(id: textObj.id, position: newPosition)
        }
    }

    func handleTextBoundsChange(textID: UUID, newBounds: CGRect) {
        guard let textObj = document.findText(by: textID) else { return }
        document.modifyShapesWithUndo(shapeIDs: [textID]) { _ in
            document.updateTextBoundsInUnified(id: textObj.id, bounds: newBounds)
        }
    }

    func handleCanvasBackgroundTap(at location: CGPoint) {
        let hitAnyTextBox = document.snapshot.objects.values.contains { obj in
            guard case .text(let shape) = obj.objectType,
                  var textObj = VectorText.from(shape) else { return false }
            textObj.layerIndex = obj.layerIndex
            let textFrame = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: 300,
                height: max(textObj.bounds.height, 100)
            )
            return textFrame.contains(location)
        }
        if !hitAnyTextBox {
            document.viewState.selectedObjectIDs.removeAll()
            for obj in document.snapshot.objects.values {
                if case .text(let shape) = obj.objectType, shape.isEditing == true {
                    document.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }
            isEditingText = false
            editingTextID = nil
        }
    }

    func handleTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        if findTextAt(location: startLocation) != nil {
            return
        }
        if !isDrawing {
            for obj in document.snapshot.objects.values {
                if case .text(let shape) = obj.objectType, shape.isEditing == true {
                    document.setTextEditingInUnified(id: shape.id, isEditing: false)
                }
            }
            finishTextEditing()
        }
        let isDraggingResizeHandle = isLocationOnTextResizeHandle(startLocation)
        if isDraggingResizeHandle {
            return
        }
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        if !isDrawing {
            isDrawing = true
            shapeDragStart = startLocation
            shapeStartPoint = startLocation
            drawingStartPoint = startLocation
        }
        let minX = min(shapeStartPoint.x, currentLocation.x)
        let minY = min(shapeStartPoint.y, currentLocation.y)
        let width = abs(currentLocation.x - shapeStartPoint.x)
        let height = abs(currentLocation.y - shapeStartPoint.y)
        let finalWidth = max(width, 50.0)
        let finalHeight = max(height, 30.0)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(minX, minY)),
            .line(to: VectorPoint(minX + finalWidth, minY)),
            .line(to: VectorPoint(minX + finalWidth, minY + finalHeight)),
            .line(to: VectorPoint(minX, minY + finalHeight)),
            .close
        ])
    }

    func finishTextBoxDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let hasSelectedText = document.viewState.selectedObjectIDs.contains { id in
            if let obj = document.findObject(by: id),
               case .text = obj.objectType {
                return true
            }
            return false
        }
        if hasSelectedText {
            return
        }
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let endLocation = screenToCanvas(value.location, geometry: geometry)
        let minX = min(startLocation.x, endLocation.x)
        let minY = min(startLocation.y, endLocation.y)
        let width = abs(endLocation.x - startLocation.x)
        let height = abs(endLocation.y - startLocation.y)
        let finalWidth = max(width, 100.0)
        let finalHeight = max(height, 50.0)
        let typography = TypographyProperties(
            fontFamily: document.fontManager.selectedFontFamily,
            fontVariant: document.fontManager.selectedFontVariant,
            fontSize: document.fontManager.selectedFontSize,
            lineHeight: document.fontManager.selectedLineHeight,
            lineSpacing: document.fontManager.selectedLineSpacing,
            letterSpacing: 0.0,
            alignment: document.fontManager.selectedTextAlignment,
            hasStroke: false,
            strokeColor: document.defaultStrokeColor,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,
            fillOpacity: document.defaultFillOpacity
        )
        let emptyPath = VectorPath(elements: [], isClosed: false)

        var shape = VectorShape(
            name: "Text",
            path: emptyPath,
            geometricType: nil,
            strokeStyle: nil,
            fillStyle: nil,
            transform: CGAffineTransform(translationX: minX, y: minY),
            textContent: "",
            typography: typography,
            areaSize: CGSize(width: finalWidth, height: finalHeight),
            isEditing: true,
            textPosition: CGPoint(x: minX, y: minY)
        )
        shape.bounds = CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight)
        document.addShape(shape)
        document.viewState.orderedSelectedObjectIDs = [shape.id]
        document.viewState.selectedObjectIDs = [shape.id]
        isEditingText = true
        editingTextID = shape.id
    }

    func resetTextBoxDrawingState() {
        isDrawing = false
        currentPath = nil
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
    }

    private func isLocationOnTextResizeHandle(_ location: CGPoint) -> Bool {
        let handleRadius: Double = 6.0
        let tolerance: Double = 15.0
        let totalTolerance = handleRadius + tolerance
        for obj in document.snapshot.objects.values {
            guard case .text(let shape) = obj.objectType else { continue }
            if !shape.isVisible || shape.isLocked { continue }
            let textPos = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            let textBounds = CGRect(
                x: textPos.x,
                y: textPos.y,
                width: shape.bounds.width,
                height: shape.bounds.height
            )
            let handles = [
                CGPoint(x: textBounds.minX, y: textBounds.minY),
                CGPoint(x: textBounds.maxX, y: textBounds.minY),
                CGPoint(x: textBounds.minX, y: textBounds.maxY),
                CGPoint(x: textBounds.maxX, y: textBounds.maxY),
                CGPoint(x: textBounds.midX, y: textBounds.minY),
                CGPoint(x: textBounds.midX, y: textBounds.maxY),
                CGPoint(x: textBounds.minX, y: textBounds.midY),
                CGPoint(x: textBounds.maxX, y: textBounds.midY),
            ]
            for (_, handle) in handles.enumerated() {
                let distance = location.distance(to: handle)
                if distance <= totalTolerance {
                    return true
                }
            }
            let edgeTolerance: Double = 0.0
            let expandedBounds = textBounds.insetBy(dx: -edgeTolerance, dy: -edgeTolerance)
            if expandedBounds.contains(location) && !textBounds.insetBy(dx: edgeTolerance, dy: edgeTolerance).contains(location) {
                return true
            }
        }
        return false
    }
}
