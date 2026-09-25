import SwiftUI
import simd

extension DrawingCanvas {
    internal var allowedZoomSteps: [CGFloat] { ZoomMath.steps }

    internal func quantizeZoomToNearestAllowed(_ zoom: CGFloat) -> CGFloat {
        ZoomMath.nearestStep(to: zoom)
    }

    internal func nextAllowedStepUp(from zoom: CGFloat) -> CGFloat {
        ZoomMath.stepUp(from: zoom)
    }

    internal func nextAllowedStepDown(from zoom: CGFloat) -> CGFloat {
        ZoomMath.stepDown(from: zoom)
    }

    internal func handleZoomGestureChanged(value: CGFloat, geometry: GeometryProxy) {
        guard !isBezierDrawing && !isPanGestureActive else {
            return
        }
        if !isZoomGestureActive {
            isZoomGestureActive = true
        }
        let zoomData = SIMD2<Float>(Float(initialZoomLevel), Float(value))
        let currentZoom = zoomData.x
        let gestureValue = zoomData.y
        let adjustedValue = 1.0 + (gestureValue - 1.0) * 1.5
        let newZoomLevel = CGFloat(currentZoom * adjustedValue)
        let clampedZoom = ZoomMath.clamp(newZoomLevel)
        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: clampedZoom, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: clampedZoom, focalPoint: viewCenter, geometry: geometry)
        }
    }

    internal func handleZoomGestureEnded(value: CGFloat, geometry: GeometryProxy) {
        defer {
            isZoomGestureActive = false
        }
        guard !isBezierDrawing && !isPanGestureActive else {
            return
        }
        let zoomData = SIMD2<Float>(Float(initialZoomLevel), Float(value))
        let currentZoom = zoomData.x
        let gestureValue = zoomData.y
        let adjustedValue = 1.0 + (gestureValue - 1.0) * 1.5
        let finalZoomLevel = ZoomMath.clamp(CGFloat(currentZoom * adjustedValue))
        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: viewCenter, geometry: geometry)
        }
        initialZoomLevel = finalZoomLevel
        #if os(macOS)
        if isCanvasHovering && document.viewState.currentTool == .zoom {
            MagnifyingGlassCursor.set()
            DispatchQueue.main.async { if isCanvasHovering && document.viewState.currentTool == .zoom { MagnifyingGlassCursor.set() } }
        }
        #endif
    }

    internal func handleZoomRequest(_ request: ZoomRequest, geometry: GeometryProxy) {
        switch request.mode {
        case .fitToPage:
            fitToPage(geometry: geometry)
        case .actualSize:
            actualSize(geometry: geometry)
        case .zoomIn:
            let newZoom = nextAllowedStepUp(from: zoomLevel)
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: newZoom, focalPoint: viewCenter, geometry: geometry)
        case .zoomOut:
            let newZoom = nextAllowedStepDown(from: zoomLevel)
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: newZoom, focalPoint: viewCenter, geometry: geometry)
        case .custom(let focalPoint):
            handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: focalPoint, geometry: geometry)
        }
        document.clearZoomRequest()
        #if os(macOS)
        if isCanvasHovering {
            switch document.viewState.currentTool {
            case .hand:
                NSCursor.openHand.set()
            case .eyedropper:
                EyedropperCursor.set()
            case .selectSameColor:
                EyedropperCursor.set()
            case .zoom:
                MagnifyingGlassCursor.set()
            default:
                break
            }
            DispatchQueue.main.async {
                if isCanvasHovering {
                    switch document.viewState.currentTool {
                    case .hand:
                        NSCursor.openHand.set()
                    case .eyedropper:
                        EyedropperCursor.set()
                    case .zoom:
                        MagnifyingGlassCursor.set()
                    default:
                        break
                    }
                }
            }
        }
        #endif
    }
}
