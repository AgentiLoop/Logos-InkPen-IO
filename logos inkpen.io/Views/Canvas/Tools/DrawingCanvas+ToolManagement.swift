import SwiftUI
import Combine

extension DrawingCanvas {

    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        let isCmdPressed = NSEvent.modifierFlags.contains(.command)
        if newTool == .selection && isCmdPressed {
            isTemporarySelectionViaCommand = true
        } else if oldTool == .selection && isTemporarySelectionViaCommand {
            isTemporarySelectionViaCommand = false
        }
        if isCornerRadiusEditMode {
            isCornerRadiusEditMode = false
        }
        if (previousTool == .font || oldTool == .font) && newTool != .font {
            stopAllTextEditing()
        } else if newTool == .selection && !isTemporarySelectionViaCommand {
            stopAllTextEditing()
        }
        let isTemporaryTool = newTool == .hand || newTool == .zoom || (newTool == .selection && isTemporarySelectionViaCommand)
        if previousTool == .bezierPen && newTool != .bezierPen && !isTemporaryTool && isBezierDrawing {
            finishBezierPath()
        }
        if previousTool == .freehand && newTool != .freehand && !isTemporaryTool && isFreehandDrawing {
            handleFreehandDragEnd()
        }
        if previousTool == .font && newTool == .selection {
        }
        if previousTool == .selection && newTool == .font {
        }
        handleSelectionConversion(from: oldTool, to: newTool)
        previousTool = newTool
    }

    private func stopAllTextEditing() {
        var stoppedCount = 0
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                stoppedCount += 1
            }
        }
        for obj in document.snapshot.objects.values {
            switch obj.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                if groupShape.isGroupContainer {
                    for childShape in groupShape.groupedShapes {
                        if childShape.typography != nil && childShape.isEditing == true {
                            document.setTextEditingInUnified(id: childShape.id, isEditing: false)
                            stoppedCount += 1
                        }
                    }
                }
            default:
                break
            }
        }
        if isEditingText {
            isEditingText = false
            editingTextID = nil
            currentCursorPosition = 0
            currentSelectionRange = NSRange(location: 0, length: 0)
        }
        isTextEditingMode = false
        #if os(macOS)
        NSCursor.arrow.set()
        #endif
        if let window = NSApp.keyWindow {
            window.makeFirstResponder(nil)
        }
    }

    private func finishTextEditingButKeepSelected(_ textID: UUID) {
        document.setTextEditingInUnified(id: textID, isEditing: false)
        document.viewState.selectedObjectIDs = [textID]
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
    }

    private func handleSelectionConversion(from oldTool: DrawingTool, to newTool: DrawingTool) {
        if newTool == .selection && isTemporarySelectionViaCommand {
        }
        else if newTool == .selection {
            if !selectedObjectIDs.isEmpty {
                document.viewState.selectedObjectIDs = selectedObjectIDs
                selectedObjectIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
            }
        }
        else if newTool == .directSelection {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
            if !document.viewState.selectedObjectIDs.isEmpty {
                var newSelection = Set<UUID>()
                for objectID in document.viewState.selectedObjectIDs {
                    if let obj = document.snapshot.objects[objectID] {
                        let shape = obj.shape
                        if shape.isGroupContainer {
                            if let topMemberID = shape.memberIDs.last,

                               let _ = document.snapshot.objects[topMemberID] {
                                newSelection.insert(topMemberID)
                            } else if let topGroupedShape = shape.groupedShapes.last {
                                newSelection.insert(topGroupedShape.id)
                            }
                        } else {
                            newSelection.insert(objectID)
                        }
                    }
                }
                selectedObjectIDs = newSelection
                syncDirectSelectionWithDocument()
            }
        }
        else if newTool == .bezierPen {
            if let selectedPointID = selectedPoints.first {
                if getShapeForPoint(selectedPointID) != nil,

                   let pointPosition = getPointPosition(selectedPointID) {
                    continueExistingPath(from: pointPosition)
                }
            }
        }
        else if newTool == .convertAnchorPoint || newTool == .penPlusMinus {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
            if !document.viewState.selectedObjectIDs.isEmpty {
                selectedObjectIDs = document.viewState.selectedObjectIDs
                syncDirectSelectionWithDocument()
            }
        }
        else if newTool == .font {
            for selectedID in document.viewState.selectedObjectIDs {
                if let obj = document.snapshot.objects[selectedID],
                   case .text = obj.objectType {
                    document.setTextEditingInUnified(id: selectedID, isEditing: true)
                    break
                }
            }
        }
        else if (oldTool == .directSelection || oldTool == .convertAnchorPoint || oldTool == .penPlusMinus) &&
                 newTool != .selection && newTool != .directSelection && newTool != .convertAnchorPoint && newTool != .penPlusMinus && newTool != .bezierPen && newTool != .font && newTool != .hand && newTool != .zoom && newTool != .scale && newTool != .rotate && newTool != .reflect && newTool != .shear && newTool != .warp {
            document.viewState.selectedObjectIDs.removeAll()
            selectedObjectIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
        }
        else if newTool == .hand || oldTool == .hand || newTool == .zoom || oldTool == .zoom {
        }
    }

    internal func clearToolState() {
        if document.viewState.currentTool != .bezierPen {
            showClosePathHint = false
            showContinuePathHint = false
        }
    }
}
