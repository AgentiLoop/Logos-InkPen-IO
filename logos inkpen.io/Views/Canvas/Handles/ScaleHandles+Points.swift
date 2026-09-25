import SwiftUI

extension ScaleHandles {

    func extractPathPoints() {
        pathPoints.removeAll()
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue
                    }
                }
            }
        } else {
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue
                }
            }
        }
        centerPoint = VectorPoint(shape.calculateCentroid())
    }

    @ViewBuilder
    func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            let baseTransform = (isScaling && !previewTransform.isIdentity) ? previewTransform : shape.transform
            let transformedPoint = CGPoint(x: point.x, y: point.y).applying(baseTransform)
            Circle()
                .fill(isLockedPin ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: transformedPoint.x * zoomLevel + canvasOffset.x,
                    y: transformedPoint.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isScaling {
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handleScalingFromPoint(draggedPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )
        }
    }

    func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex
        if let index = pointIndex {
            if index < pathPoints.count {
                let point = pathPoints[index]
                scalingAnchorPoint = CGPoint(x: point.x, y: point.y)
            } else {
                let cornerIndex = index - pathPoints.count
                let bounds: CGRect
                if ImageContentRegistry.containsImage(shape, in: document) {
                    let pathBounds = shape.path.cgPath.boundingBoxOfPath
                    bounds = pathBounds.applying(shape.transform)
                } else {
                    bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                }
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                scalingAnchorPoint = cornerPosition(for: cornerIndex, in: bounds, center: center)
            }
        } else {
            scalingAnchorPoint = shape.calculateCentroid()
        }
    }

    func updatePathPointsAfterScaling() {
        pathPoints.removeAll()
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue
                    }
                }
            }
        } else {
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue
                }
            }
        }
        centerPoint = VectorPoint(shape.calculateCentroid())
        pointsRefreshTrigger += 1
    }
}
