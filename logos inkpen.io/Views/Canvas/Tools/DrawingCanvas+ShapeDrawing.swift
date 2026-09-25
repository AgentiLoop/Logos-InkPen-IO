import SwiftUI
import simd

extension DrawingCanvas {

    private func geometricTypeForTool(_ tool: DrawingTool) -> GeometricShapeType? {
        switch tool {
        case .line: return .line
        case .rectangle: return .rectangle
        case .square: return .square
        case .roundedRectangle: return .roundedRectangle
        case .circle: return .circle
        case .ellipse, .oval, .egg, .pill: return .ellipse
        case .star: return .star
        case .polygon, .hexagon: return .hexagon
        case .pentagon: return .pentagon
        case .heptagon: return .heptagon
        case .octagon, .nonagon: return .octagon
        case .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle, .cone: return .triangle
        case .freehand, .brush, .marker: return .brushStroke
        default: return nil
        }
    }

    private func calculateDistanceWithFallback(from point1: CGPoint, to point2: CGPoint) -> Float {
        let metalEngine = MetalComputeEngine.shared
        let distanceResult = metalEngine.calculatePointDistanceGPU(from: point1, to: point2)
        switch distanceResult {
        case .success(let distance):
            return distance
        case .failure(_):
            let distance = simd_length(SIMD2<Double>(point2.x - point1.x, point2.y - point1.y))
            return Float(distance)
        }
    }

    internal func handleShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let dragDistance = calculateDistanceWithFallback(from: value.startLocation, to: value.location)
        let minimumDragThreshold: Double = 0.0
        if Double(dragDistance) < minimumDragThreshold {
            return
        }
        if !isDrawing {
            let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let isDraggingResizeHandle = isLocationOnShapeResizeHandle(startLocation)
            if isDraggingResizeHandle {
                return
            }
            isDrawing = true
            shapeDragStart = value.startLocation
            var initialPoint = startLocation

            let shapeTools: [DrawingTool] = [.line, .rectangle, .square, .roundedRectangle, .pill,
                                              .circle, .ellipse, .oval, .egg, .cone,
                                              .star, .polygon, .pentagon, .hexagon, .heptagon,
                                              .octagon, .nonagon, .equilateralTriangle,
                                              .rightTriangle, .acuteTriangle, .isoscelesTriangle]
            if (document.gridSettings.snapToPoint || document.gridSettings.snapToGrid) && shapeTools.contains(document.viewState.currentTool) {
                initialPoint = applySnapping(to: initialPoint)
            }
            shapeStartPoint = initialPoint
            drawingStartPoint = shapeStartPoint
        }
        let cursorDelta = CGPoint(
            x: value.location.x - shapeDragStart.x,
            y: value.location.y - shapeDragStart.y
        )
        let preciseZoom = Double(zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        var currentLocation = CGPoint(
            x: shapeStartPoint.x + canvasDelta.x,
            y: shapeStartPoint.y + canvasDelta.y
        )
        let shapeTools: [DrawingTool] = [.line, .rectangle, .square, .roundedRectangle, .pill,
                                          .circle, .ellipse, .oval, .egg, .cone,
                                          .star, .polygon, .pentagon, .hexagon, .heptagon,
                                          .octagon, .nonagon, .equilateralTriangle,
                                          .rightTriangle, .acuteTriangle, .isoscelesTriangle]
        if (document.gridSettings.snapToPoint || document.gridSettings.snapToGrid) && shapeTools.contains(document.viewState.currentTool) {
            currentLocation = applySnapping(to: currentLocation)
        }
        if abs(canvasDelta.x) > 2 || abs(canvasDelta.y) > 2 {
        }
        guard let startPoint = drawingStartPoint else { return }
        switch document.viewState.currentTool {
        case .line:
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(startPoint)),
                .line(to: VectorPoint(currentLocation))
            ])
        case .rectangle:
            var width = currentLocation.x - startPoint.x
            var height = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(width), abs(height))
                width = width >= 0 ? size : -size
                height = height >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rectBounds: CGRect
            if isOptionCurrentlyPressed {
                rectBounds = CGRect(
                    x: startPoint.x - width,
                    y: startPoint.y - height,
                    width: width * 2,
                    height: height * 2
                )
            } else {
                rectBounds = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: width,
                    height: height
                )
            }
            let normalizedRect = rectBounds.standardized
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
                .line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
                .line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
                .line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
                .close
            ], isClosed: true)
        case .square:
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let size = max(abs(dragDeltaX), abs(dragDeltaY))
            let signedSizeX = dragDeltaX >= 0 ? size : -size
            let signedSizeY = dragDeltaY >= 0 ? size : -size
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var squareRect: CGRect
            if isOptionCurrentlyPressed {
                squareRect = CGRect(
                    x: startPoint.x - signedSizeX,
                    y: startPoint.y - signedSizeY,
                    width: signedSizeX * 2,
                    height: signedSizeY * 2
                )
            } else {
                squareRect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: signedSizeX,
                    height: signedSizeY
                )
            }
            let normalizedRect = squareRect.standardized
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(normalizedRect.minX, normalizedRect.minY)),
                .line(to: VectorPoint(normalizedRect.maxX, normalizedRect.minY)),
                .line(to: VectorPoint(normalizedRect.maxX, normalizedRect.maxY)),
                .line(to: VectorPoint(normalizedRect.minX, normalizedRect.maxY)),
                .close
            ], isClosed: true)
        case .roundedRectangle:
            var width = currentLocation.x - startPoint.x
            var height = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(width), abs(height))
                width = width >= 0 ? size : -size
                height = height >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - width,
                    y: startPoint.y - height,
                    width: width * 2,
                    height: height * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: width,
                    height: height
                )
            }
            let normalizedRect = rect.standardized
            let cornerRadius: Double = 20.0
            currentPath = createRoundedRectPath(rect: normalizedRect, cornerRadius: cornerRadius)
        case .pill:
            var dragDeltaX = currentLocation.x - startPoint.x
            var dragDeltaY = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                dragDeltaX = dragDeltaX >= 0 ? size : -size
                dragDeltaY = dragDeltaY >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - dragDeltaX,
                    y: startPoint.y - dragDeltaY,
                    width: dragDeltaX * 2,
                    height: dragDeltaY * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX,
                    height: dragDeltaY
                )
            }
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            let cornerRadius = min(normalizedRect.width, normalizedRect.height) / 2
            currentPath = createRoundedRectPath(rect: normalizedRect, cornerRadius: cornerRadius)
        case .circle:
            let dragDeltaX = currentLocation.x - startPoint.x
            let dragDeltaY = currentLocation.y - startPoint.y
            let size = max(abs(dragDeltaX), abs(dragDeltaY))
            let signedSize = (dragDeltaX >= 0 && dragDeltaY >= 0) || (dragDeltaX < 0 && dragDeltaY < 0) ? size : -size
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var circleRect: CGRect
            if isOptionCurrentlyPressed {
                circleRect = CGRect(
                    x: startPoint.x - signedSize,
                    y: startPoint.y - signedSize,
                    width: signedSize * 2,
                    height: signedSize * 2
                )
            } else {
                circleRect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX >= 0 ? size : -size,
                    height: dragDeltaY >= 0 ? size : -size
                )
            }
            currentPath = createCirclePath(rect: circleRect)
        case .ellipse:
            var width = currentLocation.x - startPoint.x
            var height = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(width), abs(height))
                width = width >= 0 ? size : -size
                height = height >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - width,
                    y: startPoint.y - height,
                    width: width * 2,
                    height: height * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: width,
                    height: height
                )
            }
            currentPath = createEllipsePath(rect: rect)
        case .oval:
            var dragDeltaX = currentLocation.x - startPoint.x
            var dragDeltaY = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                dragDeltaX = dragDeltaX >= 0 ? size : -size
                dragDeltaY = dragDeltaY >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - dragDeltaX,
                    y: startPoint.y - dragDeltaY,
                    width: dragDeltaX * 2,
                    height: dragDeltaY * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX,
                    height: dragDeltaY
                )
            }
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            currentPath = createOvalPath(rect: normalizedRect)
        case .egg:
            var dragDeltaX = currentLocation.x - startPoint.x
            var dragDeltaY = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                dragDeltaX = dragDeltaX >= 0 ? size : -size
                dragDeltaY = dragDeltaY >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - dragDeltaX,
                    y: startPoint.y - dragDeltaY,
                    width: dragDeltaX * 2,
                    height: dragDeltaY * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX,
                    height: dragDeltaY
                )
            }
            let normalizedRect = CGRect(
                x: min(rect.minX, rect.maxX),
                y: min(rect.minY, rect.maxY),
                width: abs(rect.width),
                height: abs(rect.height)
            )
            currentPath = createEggPath(rect: normalizedRect)
        case .equilateralTriangle:
            let width = currentLocation.x - startPoint.x
            let height = currentLocation.y - startPoint.y
            let size = max(abs(width), abs(height))
            let triangleHeight = height >= 0 ? size : -size
            let sqrt3: Float
            let metalEngine = MetalComputeEngine.shared
            let sqrtResult = metalEngine.calculateSquareRootGPU(3.0)
            switch sqrtResult {
            case .success(let value):
                sqrt3 = value
            case .failure(_):
                sqrt3 = Float(sqrt(3.0))
            }
            let triangleWidth = CGFloat(abs(triangleHeight) * 2.0 / Double(sqrt3))
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var triangleRect: CGRect
            if isOptionCurrentlyPressed {
                triangleRect = CGRect(
                    x: startPoint.x - (width >= 0 ? triangleWidth : -triangleWidth) / 2,
                    y: startPoint.y - triangleHeight / 2,
                    width: width >= 0 ? triangleWidth : -triangleWidth,
                    height: triangleHeight
                )
            } else {
                triangleRect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: width >= 0 ? triangleWidth : -triangleWidth,
                    height: triangleHeight
                )
            }
            if document.gridSettings.snapToGrid {
                currentPath = createEquilateralTrianglePathWithGridSnapping(rect: triangleRect, gridSpacing: document.settings.gridSpacing, unit: document.settings.unit)
            } else {
                let centerX = triangleRect.midX
                let topY = triangleRect.minY
                let bottomY = triangleRect.maxY
                let baseHalfWidth = abs(triangleWidth) / 2.0
                currentPath = VectorPath(elements: [
                    .move(to: VectorPoint(centerX, topY)),
                    .line(to: VectorPoint(centerX - baseHalfWidth, bottomY)),
                    .line(to: VectorPoint(centerX + baseHalfWidth, bottomY)),
                    .close
                ], isClosed: true)
            }
        case .rightTriangle:
            var dragDeltaX = currentLocation.x - startPoint.x
            var dragDeltaY = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                dragDeltaX = dragDeltaX >= 0 ? size : -size
                dragDeltaY = dragDeltaY >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - abs(dragDeltaX),
                    y: startPoint.y - abs(dragDeltaY),
                    width: abs(dragDeltaX) * 2,
                    height: abs(dragDeltaY) * 2
                )
            } else {
                rect = CGRect(
                    x: min(startPoint.x, startPoint.x + dragDeltaX),
                    y: min(startPoint.y, startPoint.y + dragDeltaY),
                    width: abs(dragDeltaX),
                    height: abs(dragDeltaY)
                )
            }
            let dragX = dragDeltaX >= 0 ? "RIGHT" : "LEFT"
            let dragY = dragDeltaY >= 0 ? "DOWN" : "UP"
            let dragDirection = "\(dragX)_\(dragY)"
            currentPath = createRightTrianglePath(rect: rect, dragDirection: dragDirection)
        case .acuteTriangle:
            var dragDeltaX = currentLocation.x - startPoint.x
            var dragDeltaY = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                dragDeltaX = dragDeltaX >= 0 ? size : -size
                dragDeltaY = dragDeltaY >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - dragDeltaX,
                    y: startPoint.y - dragDeltaY,
                    width: dragDeltaX * 2,
                    height: dragDeltaY * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX,
                    height: dragDeltaY
                )
            }
            currentPath = createAcuteTrianglePath(rect: rect)
        case .isoscelesTriangle:
            var dragDeltaX = currentLocation.x - startPoint.x
            var dragDeltaY = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                dragDeltaX = dragDeltaX >= 0 ? size : -size
                dragDeltaY = dragDeltaY >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var rect: CGRect
            if isOptionCurrentlyPressed {
                rect = CGRect(
                    x: startPoint.x - dragDeltaX,
                    y: startPoint.y - dragDeltaY,
                    width: dragDeltaX * 2,
                    height: dragDeltaY * 2
                )
            } else {
                rect = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX,
                    height: dragDeltaY
                )
            }
            currentPath = createIsoscelesTrianglePath(rect: rect)
        case .cone:
            var dx = currentLocation.x - startPoint.x
            var dy = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(dx), abs(dy))
                dx = dx >= 0 ? size : -size
                dy = dy >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

            var raw: CGRect
            if isOptionCurrentlyPressed {
                raw = CGRect(x: startPoint.x - dx, y: startPoint.y - dy, width: dx * 2, height: dy * 2)
            } else {
                raw = CGRect(x: startPoint.x, y: startPoint.y, width: dx, height: dy)
            }
            let r = CGRect(x: min(raw.minX, raw.maxX), y: min(raw.minY, raw.maxY), width: abs(raw.width), height: abs(raw.height))
            let apex = VectorPoint(r.midX, r.minY)
            let baseLeft = VectorPoint(r.minX, r.maxY)
            let baseRight = VectorPoint(r.maxX, r.maxY)
            let move = VectorPoint(baseRight.x - r.width * 0.007461, baseRight.y - r.height * 0.13586)
            let c1 = VectorPoint(baseRight.x - r.width * 0.002364, baseRight.y - r.height * 0.12957)
            let c2 = VectorPoint(baseRight.x, baseRight.y - r.height * 0.12317)
            let rightStart = VectorPoint(baseRight.x, baseRight.y - r.height * 0.11645)
            let c3 = VectorPoint(baseRight.x, baseRight.y - r.height * 0.05216)
            let c4 = VectorPoint(r.midX + r.width * 0.27608, r.maxY)
            let mid = VectorPoint(r.midX, r.maxY)
            let c5 = VectorPoint(r.midX - r.width * 0.27608, r.maxY)
            let c6 = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.05216)
            let leftEnd = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.11645)
            let c7 = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.12160)
            let c8 = VectorPoint(baseLeft.x + r.width * 0.00141, baseLeft.y - r.height * 0.12660)
            let leftExit = VectorPoint(baseLeft.x + r.width * 0.00463, baseLeft.y - r.height * 0.13147)
            currentPath = VectorPath(elements: [
                .move(to: move),
                .curve(to: rightStart, control1: c1, control2: c2),
                .curve(to: mid, control1: c3, control2: c4),
                .curve(to: leftEnd, control1: c5, control2: c6),
                .curve(to: leftExit, control1: c7, control2: c8),
                .line(to: apex),
                .close
            ], isClosed: true)
        case .star:
            var width = currentLocation.x - startPoint.x
            var height = currentLocation.y - startPoint.y

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let size = max(abs(width), abs(height))
                width = width >= 0 ? size : -size
                height = height >= 0 ? size : -size
            }
            let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)
            let center: CGPoint
            let outerRadius: Float
            if isOptionCurrentlyPressed {
                center = startPoint
                outerRadius = Float(max(abs(width), abs(height)))
            } else {
                center = CGPoint(
                    x: startPoint.x + width / 2,
                    y: startPoint.y + height / 2
                )
                outerRadius = Float(max(abs(width), abs(height)) / 2.0)
            }
            let selectedVariant = ToolGroupManager.shared.selectedVariant
            let points: Int
            let innerRatio: Double
            switch selectedVariant {
            case .threePoint:
                points = 3
                innerRatio = 0.22
            case .fourPoint:
                points = 4
                innerRatio = 0.28
            case .fivePoint:
                points = 5
                innerRatio = 0.40
            case .sixPoint:
                points = 6
                innerRatio = 0.40
            case .sevenPoint:
                points = 7
                innerRatio = 0.40
            }
            let innerRadius = Double(outerRadius) * innerRatio
            let finalCenter: CGPoint
            if document.gridSettings.snapToGrid {
                let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

                let spacingMultiplier: CGFloat = {
                    switch document.settings.unit {
                    case .pixels, .points:
                        return 25.0
                    case .millimeters:
                        return 1.0
                    case .inches:
                        return 1.0
                    case .centimeters:
                        return 10.0
                    case .picas:
                        return 1.0
                    }
                }()
                let actualGridSpacing = baseSpacing * spacingMultiplier
                let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
                let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
                finalCenter = CGPoint(x: snappedX, y: snappedY)
            } else {
                finalCenter = center
            }
            currentPath = createStarPath(center: finalCenter, outerRadius: Double(outerRadius), innerRadius: innerRadius, points: points)
		case .polygon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

			var rect: CGRect
			if isOptionCurrentlyPressed {
				let signedSize = dragDeltaX >= 0 && dragDeltaY >= 0 ? size : -size
				rect = CGRect(
					x: startPoint.x - signedSize,
					y: startPoint.y - signedSize,
					width: signedSize * 2,
					height: signedSize * 2
				)
			} else {
				rect = CGRect(
					x: startPoint.x,
					y: startPoint.y,
					width: dragDeltaX >= 0 ? size : -size,
					height: dragDeltaY >= 0 ? size : -size
				)
			}
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			let finalCenter: CGPoint
			if document.gridSettings.snapToGrid {
				let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

				let spacingMultiplier: CGFloat = {
					switch document.settings.unit {
					case .pixels, .points:
						return 25.0
					case .millimeters:
						return 1.0
					case .inches:
						return 1.0
					case .centimeters:
						return 10.0
					case .picas:
						return 1.0
					}
				}()
				let actualGridSpacing = baseSpacing * spacingMultiplier
				let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
				let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
				finalCenter = CGPoint(x: snappedX, y: snappedY)
			} else {
				finalCenter = center
			}
			currentPath = createPolygonPath(center: finalCenter, radius: radius, sides: 6)
		case .pentagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

			var rect: CGRect
			if isOptionCurrentlyPressed {
				let signedSize = dragDeltaX >= 0 && dragDeltaY >= 0 ? size : -size
				rect = CGRect(
					x: startPoint.x - signedSize,
					y: startPoint.y - signedSize,
					width: signedSize * 2,
					height: signedSize * 2
				)
			} else {
				rect = CGRect(
					x: startPoint.x,
					y: startPoint.y,
					width: dragDeltaX >= 0 ? size : -size,
					height: dragDeltaY >= 0 ? size : -size
				)
			}
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			let finalCenter: CGPoint
			if document.gridSettings.snapToGrid {
				let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

				let spacingMultiplier: CGFloat = {
					switch document.settings.unit {
					case .pixels, .points:
						return 25.0
					case .millimeters:
						return 1.0
					case .inches:
						return 1.0
					case .centimeters:
						return 10.0
					case .picas:
						return 1.0
					}
				}()
				let actualGridSpacing = baseSpacing * spacingMultiplier
				let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
				let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
				finalCenter = CGPoint(x: snappedX, y: snappedY)
			} else {
				finalCenter = center
			}
			currentPath = createPolygonPath(center: finalCenter, radius: radius, sides: 5)
		case .hexagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

			var rect: CGRect
			if isOptionCurrentlyPressed {
				let signedSize = dragDeltaX >= 0 && dragDeltaY >= 0 ? size : -size
				rect = CGRect(
					x: startPoint.x - signedSize,
					y: startPoint.y - signedSize,
					width: signedSize * 2,
					height: signedSize * 2
				)
			} else {
				rect = CGRect(
					x: startPoint.x,
					y: startPoint.y,
					width: dragDeltaX >= 0 ? size : -size,
					height: dragDeltaY >= 0 ? size : -size
				)
			}
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			let finalCenter: CGPoint
			if document.gridSettings.snapToGrid {
				let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

				let spacingMultiplier: CGFloat = {
					switch document.settings.unit {
					case .pixels, .points:
						return 25.0
					case .millimeters:
						return 1.0
					case .inches:
						return 1.0
					case .centimeters:
						return 10.0
					case .picas:
						return 1.0
					}
				}()
				let actualGridSpacing = baseSpacing * spacingMultiplier
				let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
				let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
				finalCenter = CGPoint(x: snappedX, y: snappedY)
			} else {
				finalCenter = center
			}
			currentPath = createPolygonPath(center: finalCenter, radius: radius, sides: 6)
		case .heptagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

			var rect: CGRect
			if isOptionCurrentlyPressed {
				let signedSize = dragDeltaX >= 0 && dragDeltaY >= 0 ? size : -size
				rect = CGRect(
					x: startPoint.x - signedSize,
					y: startPoint.y - signedSize,
					width: signedSize * 2,
					height: signedSize * 2
				)
			} else {
				rect = CGRect(
					x: startPoint.x,
					y: startPoint.y,
					width: dragDeltaX >= 0 ? size : -size,
					height: dragDeltaY >= 0 ? size : -size
				)
			}
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			let finalCenter: CGPoint
			if document.gridSettings.snapToGrid {
				let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

				let spacingMultiplier: CGFloat = {
					switch document.settings.unit {
					case .pixels, .points:
						return 25.0
					case .millimeters:
						return 1.0
					case .inches:
						return 1.0
					case .centimeters:
						return 10.0
					case .picas:
						return 1.0
					}
				}()
				let actualGridSpacing = baseSpacing * spacingMultiplier
				let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
				let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
				finalCenter = CGPoint(x: snappedX, y: snappedY)
			} else {
				finalCenter = center
			}
			currentPath = createPolygonPath(center: finalCenter, radius: radius, sides: 7)
		case .octagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

			var rect: CGRect
			if isOptionCurrentlyPressed {
				let signedSize = dragDeltaX >= 0 && dragDeltaY >= 0 ? size : -size
				rect = CGRect(
					x: startPoint.x - signedSize,
					y: startPoint.y - signedSize,
					width: signedSize * 2,
					height: signedSize * 2
				)
			} else {
				rect = CGRect(
					x: startPoint.x,
					y: startPoint.y,
					width: dragDeltaX >= 0 ? size : -size,
					height: dragDeltaY >= 0 ? size : -size
				)
			}
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			let finalCenter: CGPoint
			if document.gridSettings.snapToGrid {
				let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

				let spacingMultiplier: CGFloat = {
					switch document.settings.unit {
					case .pixels, .points:
						return 25.0
					case .millimeters:
						return 1.0
					case .inches:
						return 1.0
					case .centimeters:
						return 10.0
					case .picas:
						return 1.0
					}
				}()
				let actualGridSpacing = baseSpacing * spacingMultiplier
				let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
				let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
				finalCenter = CGPoint(x: snappedX, y: snappedY)
			} else {
				finalCenter = center
			}
			currentPath = createPolygonPath(center: finalCenter, radius: radius, sides: 8)
		case .nonagon:
			let dragDeltaX = currentLocation.x - startPoint.x
			let dragDeltaY = currentLocation.y - startPoint.y
			let size = max(abs(dragDeltaX), abs(dragDeltaY))
			let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)

			var rect: CGRect
			if isOptionCurrentlyPressed {
				let signedSize = dragDeltaX >= 0 && dragDeltaY >= 0 ? size : -size
				rect = CGRect(
					x: startPoint.x - signedSize,
					y: startPoint.y - signedSize,
					width: signedSize * 2,
					height: signedSize * 2
				)
			} else {
				rect = CGRect(
					x: startPoint.x,
					y: startPoint.y,
					width: dragDeltaX >= 0 ? size : -size,
					height: dragDeltaY >= 0 ? size : -size
				)
			}
			let normalizedRect = CGRect(
				x: min(rect.minX, rect.maxX),
				y: min(rect.minY, rect.maxY),
				width: abs(rect.width),
				height: abs(rect.height)
			)
			let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)
			let radius = Double(min(normalizedRect.width, normalizedRect.height) / 2.0)
			let finalCenter: CGPoint
			if document.gridSettings.snapToGrid {
				let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit

				let spacingMultiplier: CGFloat = {
					switch document.settings.unit {
					case .pixels, .points:
						return 25.0
					case .millimeters:
						return 1.0
					case .inches:
						return 1.0
					case .centimeters:
						return 10.0
					case .picas:
						return 1.0
					}
				}()
				let actualGridSpacing = baseSpacing * spacingMultiplier
				let snappedX = round(center.x / actualGridSpacing) * actualGridSpacing
				let snappedY = round(center.y / actualGridSpacing) * actualGridSpacing
				finalCenter = CGPoint(x: snappedX, y: snappedY)
			} else {
				finalCenter = center
			}
			currentPath = createPolygonPath(center: finalCenter, radius: radius, sides: 9)
        default:
            break
        }
    }

    internal func finishShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let path = currentPath else { return }
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            lineCap: document.strokeDefaults.lineCap,
            lineJoin: document.strokeDefaults.lineJoin,
            miterLimit: document.strokeDefaults.miterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle = FillStyle(
            color: document.defaultFillColor,
            opacity: document.defaultFillOpacity
        )
        var shapeGeometricType = geometricTypeForTool(document.viewState.currentTool)
        if document.viewState.currentTool == .rectangle && isShiftPressed {
            shapeGeometricType = .square
        }
        else if document.viewState.currentTool == .ellipse && isShiftPressed {
            shapeGeometricType = .circle
        }
        let shapeName = shapeGeometricType?.rawValue ?? document.viewState.currentTool.rawValue
        if document.viewState.currentTool == .rectangle || document.viewState.currentTool == .square ||
           document.viewState.currentTool == .roundedRectangle || document.viewState.currentTool == .pill {
            let startPoint = shapeStartPoint
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            let originalBounds: CGRect
            if document.viewState.currentTool == .square {
                let dragDeltaX = currentLocation.x - startPoint.x
                let dragDeltaY = currentLocation.y - startPoint.y
                let size = max(abs(dragDeltaX), abs(dragDeltaY))
                originalBounds = CGRect(
                    x: startPoint.x,
                    y: startPoint.y,
                    width: dragDeltaX >= 0 ? size : -size,
                    height: dragDeltaY >= 0 ? size : -size
                )
            } else {
                originalBounds = CGRect(
                    x: min(startPoint.x, currentLocation.x),
                    y: min(startPoint.y, currentLocation.y),
                    width: abs(currentLocation.x - startPoint.x),
                    height: abs(currentLocation.y - startPoint.y)
                )
            }
            let initialRadius: Double
            let cornerRadii: [Double]
            switch document.viewState.currentTool {
            case .rectangle, .square:
                initialRadius = 0.0
                cornerRadii = [0.0, 0.0, 0.0, 0.0]
            case .roundedRectangle:
                initialRadius = 20.0
                cornerRadii = [initialRadius, initialRadius, initialRadius, initialRadius]
            case .pill:
                let maxRadius = min(originalBounds.width, originalBounds.height) / 2
                initialRadius = maxRadius
                cornerRadii = [initialRadius, initialRadius, initialRadius, initialRadius]
            default:
                initialRadius = 0.0
                cornerRadii = [0.0, 0.0, 0.0, 0.0]
            }
            let shape = VectorShape(
                name: shapeName,
                path: path,
                geometricType: shapeGeometricType,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle,
                isRoundedRectangle: true,
                originalBounds: originalBounds,
                cornerRadii: cornerRadii
            )
            document.addShape(shape)
        } else {
            let shape = VectorShape(
                name: shapeName,
                path: path,
                geometricType: shapeGeometricType,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            document.addShape(shape)
        }
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
    }

    private func isLocationOnShapeResizeHandle(_ location: CGPoint) -> Bool {
        let handleRadius: Double = 6.0
        let tolerance: Double = 15.0
        let totalTolerance = handleRadius + tolerance
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.findObject(by: objectID) else { continue }
            switch object.objectType {
            case .text:
                continue
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                if !shape.isVisible || shape.isLocked { continue }
                let shapeBounds: CGRect
                if shape.isGroupContainer {
                    shapeBounds = shape.groupBounds
                } else {
                    shapeBounds = shape.bounds.applying(shape.transform)
                }
                let handles = [
                    CGPoint(x: shapeBounds.minX, y: shapeBounds.minY),
                    CGPoint(x: shapeBounds.maxX, y: shapeBounds.minY),
                    CGPoint(x: shapeBounds.minX, y: shapeBounds.maxY),
                    CGPoint(x: shapeBounds.maxX, y: shapeBounds.maxY),
                    CGPoint(x: shapeBounds.midX, y: shapeBounds.minY),
                    CGPoint(x: shapeBounds.midX, y: shapeBounds.maxY),
                    CGPoint(x: shapeBounds.minX, y: shapeBounds.midY),
                    CGPoint(x: shapeBounds.maxX, y: shapeBounds.midY),
                ]
                for handle in handles {
                    let distance = location.distance(to: handle)
                    if distance <= totalTolerance {
                        return true
                    }
                }
                let center = shape.calculateCentroid()
                let centerDistance = location.distance(to: center)
                if centerDistance <= totalTolerance {
                    return true
                }
            }
        }
        return false
    }
}
