import SwiftUI
import AppKit
import simd

fileprivate let enableHandToolLogging = false

extension DrawingCanvas {

    internal func handlePanGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        if initialCanvasOffset == CGPoint.zero && handToolDragStart == CGPoint.zero {
            initialCanvasOffset = canvasOffset
            handToolDragStart = value.startLocation
            isPanGestureActive = true
            #if os(macOS)
            HandClosedCursor.set()
            #endif
        }
        let currentLoc = SIMD2<Float>(Float(value.location.x), Float(value.location.y))
        let startLoc = SIMD2<Float>(Float(handToolDragStart.x), Float(handToolDragStart.y))
        let initialOffset = SIMD2<Float>(Float(initialCanvasOffset.x), Float(initialCanvasOffset.y))
        let delta = currentLoc - startLoc
        let newOffset = initialOffset + delta
        #if os(macOS)
        if document.viewState.currentTool == .hand {
            HandClosedCursor.set()
        }
        #endif
        canvasOffset = CGPoint(x: CGFloat(newOffset.x), y: CGFloat(newOffset.y))
    }

    internal func handlePanGestureEnd() {
        initialCanvasOffset = .zero
        handToolDragStart = .zero
        isPanGestureActive = false
        #if os(macOS)
        if document.viewState.currentTool == .hand {
            HandOpenCursor.set()
        }
        #endif
    }
}
