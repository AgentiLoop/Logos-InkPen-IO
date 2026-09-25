import SwiftUI

extension DrawingCanvas {

    @ViewBuilder
    internal var directSelectionContextMenu: some View {
        if document.viewState.currentTool == .bezierPen && isBezierDrawing && bezierPoints.count >= 3 {
            Button("Close Path") {
                closeBezierPath()
            }
                            .keyboardShortcut("j", modifiers: [.command])
            Button("Finish Path (Open)") {
                finishBezierPath()
            }
            .keyboardShortcut(.return)
            Button("Cancel Path") {
                cancelBezierDrawing()
            }
            .keyboardShortcut(.escape)
        }
        if document.viewState.currentTool == .directSelection && !selectedPoints.isEmpty {
            Button("Close Path") {
                closeSelectedPaths()
            }
            Button("Delete Selected") {
                deleteSelectedPoints()
            }
            .keyboardShortcut(.delete)
            Divider()
            Button("Analyze Coincident Points") {
                analyzeCoincidentPoints()
            }
        }
        if !document.viewState.selectedObjectIDs.isEmpty {
            Divider()
            Button("Make Clipping Mask") {
                document.makeClippingMaskFromSelection()
            }
            .disabled(document.viewState.selectedObjectIDs.count < 2)
            Button("Release Clipping Mask") {
                document.releaseClippingMaskForSelection()
            }
        }
    }
}
