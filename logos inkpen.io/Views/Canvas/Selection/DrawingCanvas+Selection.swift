import SwiftUI

extension DrawingCanvas {

    internal func selectObjectAt(_ location: CGPoint) {
        handleSelectionTap(at: location)
    }

    internal func isDraggingSelectedObject(at location: CGPoint) -> Bool {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                if !shape.isVisible || shape.isLocked { continue }
                let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                let absoluteBounds = CGRect(
                    x: position.x + shape.bounds.minX,
                    y: position.y + shape.bounds.minY,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
                if absoluteBounds.contains(location) {
                    return true
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if !shape.isVisible {
                    continue
                }
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    if shapeBounds.contains(location) {
                        return true
                    }
                } else {
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    if isStrokeOnly && shape.strokeStyle != nil {
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance) {
                            return true
                        }
                    } else {
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                        if expandedBounds.contains(location) {
                            return true
                        } else {
                            if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
}
