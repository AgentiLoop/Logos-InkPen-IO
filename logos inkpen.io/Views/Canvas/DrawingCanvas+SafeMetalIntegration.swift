import SwiftUI

#if os(macOS)
import AppKit
#endif
import MetalKit

extension DrawingCanvas {

    @ViewBuilder
    internal func enhancedCanvasMainContent(geometry: GeometryProxy) -> some View {
        ZStack {
            canvasBaseContent(geometry: geometry, imagePreviewQuality: imagePreviewQuality, imageTileSize: imageTileSize, imageInterpolationQuality: CGInterpolationQuality(rawValue: Int32(imageInterpolationQuality)) ?? .none)
            canvasOverlays(geometry: geometry)
            pressureSensitiveOverlay(geometry: geometry)
            #if os(macOS)
            CanvasCursorOverlayView(
                isHovering: isCanvasHovering,
                currentTool: document.viewState.currentTool,
                isPanActive: isPanGestureActive,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )
            #endif
        }
        .scaleEffect(liveZoomDelta)
        .offset(x: livePanDelta.x, y: livePanDelta.y)
        .onAppear {
            setupCanvas()
            previousTool = document.viewState.currentTool
            if !hasPerformedInitialFitToPage {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !hasPerformedInitialFitToPage {
                        document.requestZoom(to: 0.0, mode: .fitToPage)
                        hasPerformedInitialFitToPage = true
                    }
                }
            }
        }
        .onDisappear {
        }
        .onChange(of: document.viewState.currentTool) { oldTool, newTool in
            handleToolChange(oldTool: oldTool, newTool: newTool)
            #if os(macOS)
            if isCanvasHovering {
                if newTool == .hand {
                    HandOpenCursor.set()
                } else if newTool == .eyedropper {
                    EyedropperCursor.set()
                } else if newTool == .selectSameColor {
                    EyedropperCursor.set()
                } else if newTool == .zoom {
                    MagnifyingGlassCursor.set()
                } else if newTool == .rectangle || newTool == .square || newTool == .circle || newTool == .equilateralTriangle || newTool == .isoscelesTriangle || newTool == .rightTriangle || newTool == .acuteTriangle || newTool == .cone || newTool == .polygon || newTool == .pentagon || newTool == .hexagon || newTool == .heptagon || newTool == .octagon || newTool == .nonagon {
                    CrosshairCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            #endif
        }
        .onHover { isHovering in
            isCanvasHovering = isHovering
            #if os(macOS)
            if isHovering {
                if document.viewState.currentTool == .hand {
                    HandOpenCursor.set()
                } else if document.viewState.currentTool == .eyedropper {
                    EyedropperCursor.set()
                } else if document.viewState.currentTool == .selectSameColor {
                    EyedropperCursor.set()
                } else if document.viewState.currentTool == .zoom {
                    MagnifyingGlassCursor.set()
                } else if document.viewState.currentTool == .rectangle || document.viewState.currentTool == .square || document.viewState.currentTool == .circle || document.viewState.currentTool == .equilateralTriangle || document.viewState.currentTool == .isoscelesTriangle || document.viewState.currentTool == .rightTriangle || document.viewState.currentTool == .acuteTriangle || document.viewState.currentTool == .cone || document.viewState.currentTool == .polygon || document.viewState.currentTool == .pentagon || document.viewState.currentTool == .hexagon || document.viewState.currentTool == .heptagon || document.viewState.currentTool == .octagon || document.viewState.currentTool == .nonagon {
                    CrosshairCursor.set()
                }
            } else {
                NSCursor.arrow.set()
            }
            #endif
        }
        .onContinuousHover { phase in
            handleHover(phase: phase, geometry: geometry)
            #if os(macOS)
            if isCanvasHovering && document.viewState.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            #endif
        }
        .onTapGesture { location in
            handleUnifiedTap(at: location, geometry: geometry)
            #if os(macOS)
            let pointInView = location
            let insideCanvas = pointInView.x >= 0 && pointInView.y >= 0 &&
                pointInView.x <= geometry.size.width && pointInView.y <= geometry.size.height
            if insideCanvas || isCanvasHovering {
                switch document.viewState.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .selectSameColor:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    CrosshairCursor.set()
                default:
                    NSCursor.arrow.set()
                }
                DispatchQueue.main.async {
                    if (insideCanvas || self.isCanvasHovering) {
                        switch self.document.viewState.currentTool {
                        case .hand:
                            HandOpenCursor.set()
                        case .eyedropper:
                            EyedropperCursor.set()
                        case .zoom:
                            MagnifyingGlassCursor.set()
                        case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                            CrosshairCursor.set()
                        default:
                            NSCursor.arrow.set()
                        }
                    }
                }
            }
            #endif
        }
        .onTapGesture { location in
            handleUnifiedTap(at: location, geometry: geometry)
        }
        .simultaneousGesture(
            document.viewState.currentTool != .gradient && document.viewState.currentTool != .cornerRadius ?
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    handleUnifiedDragChanged(value: value, geometry: geometry)
                }
                .onEnded { value in
                    handleUnifiedDragEnded(value: value, geometry: geometry)
                } : nil
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    handleZoomGestureChanged(value: value, geometry: geometry)
                }
                .onEnded { value in
                    handleZoomGestureEnded(value: value, geometry: geometry)
                }
        )
        .onChange(of: document.viewState.zoomRequest) {
            if let request = document.viewState.zoomRequest {
                handleZoomRequest(request, geometry: geometry)
            }
        }
        .onChange(of: zoomLevel) { _, _ in
            #if os(macOS)
            if isCanvasHovering {
                switch document.viewState.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .selectSameColor:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    CrosshairCursor.set()
                default:
                    break
                }
                DispatchQueue.main.async {
                    if self.isCanvasHovering {
                        switch self.document.viewState.currentTool {
                        case .hand:
                            HandOpenCursor.set()
                        case .eyedropper:
                            EyedropperCursor.set()
                        case .zoom:
                            MagnifyingGlassCursor.set()
                        case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                            CrosshairCursor.set()
                        default:
                            break
                        }
                    }
                }
            }
            #endif
        }
        .onChange(of: canvasOffset) { _, _ in
            #if os(macOS)
            if isCanvasHovering {
                switch document.viewState.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .selectSameColor:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .square, .circle, .equilateralTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    NSCursor.crosshair.set()
                default:
                    break
                }
            }
            #endif
        }
        .contextMenu {
            directSelectionContextMenu
        }
    }
}
