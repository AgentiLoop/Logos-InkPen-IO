import SwiftUI

extension DrawingCanvas {

    struct SnapPoint {
        let point: CGPoint
        let objectID: UUID
        let isAnchor: Bool
        let description: String
    }

    func findNearestSnapPoint(to point: CGPoint, threshold: CGFloat = 10.0) -> SnapPoint? {
        guard document.gridSettings.snapToPoint else { return nil }
        var allSnapPoints: [CGPoint] = []
        var allObjectIDs: [UUID] = []
        var snapPointMetadata: [(objectID: UUID, isAnchor: Bool, description: String)] = []
        for object in document.snapshot.objects.values {
            switch object.objectType {
            case .shape(let shape), .text(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                if !shape.isVisible || shape.isLocked {
                    continue
                }
                if let currentShapeId = currentShapeId, shape.id == currentShapeId {
                    continue
                }
                let snapPoints = extractSnapPoints(from: shape)
                for snapPoint in snapPoints {
                    allSnapPoints.append(snapPoint.point)
                    allObjectIDs.append(snapPoint.objectID)
                    snapPointMetadata.append((objectID: snapPoint.objectID, isAnchor: snapPoint.isAnchor, description: snapPoint.description))
                }
            }
        }
        guard !allSnapPoints.isEmpty else { return nil }
        if let result = MetalComputeEngine.shared.findNearestSnapPointGPU(
            snapPoints: allSnapPoints,
            objectIDs: allObjectIDs,
            mousePoint: point,
            threshold: threshold
        ) {
            let metadata = snapPointMetadata[result.index]
            return SnapPoint(
                point: result.point,
                objectID: metadata.objectID,
                isAnchor: metadata.isAnchor,
                description: metadata.description
            )
        }
        return nil
    }

    private func extractSnapPoints(from shape: VectorShape) -> [SnapPoint] {
        var snapPoints: [SnapPoint] = []
        if shape.typography != nil {
            let bounds = shape.bounds
            snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Text top-left"))
            snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Text top-right"))
            snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Text bottom-left"))
            snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Text bottom-right"))
            snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Text center"))
            return snapPoints
        }
        for element in shape.path.elements {
                switch element {
                case .move(to: let point):
                    snapPoints.append(SnapPoint(point: point.cgPoint, objectID: shape.id, isAnchor: true, description: "Move to"))
                case .line(to: let point):
                    snapPoints.append(SnapPoint(point: point.cgPoint, objectID: shape.id, isAnchor: true, description: "Line to"))
                case .curve(to: let endPoint, control1: let control1, control2: let control2):
                    snapPoints.append(SnapPoint(point: endPoint.cgPoint, objectID: shape.id, isAnchor: true, description: "Curve end"))
                    snapPoints.append(SnapPoint(point: control1.cgPoint, objectID: shape.id, isAnchor: false, description: "Control 1"))
                    snapPoints.append(SnapPoint(point: control2.cgPoint, objectID: shape.id, isAnchor: false, description: "Control 2"))
                case .quadCurve(to: let endPoint, control: let control):
                    snapPoints.append(SnapPoint(point: endPoint.cgPoint, objectID: shape.id, isAnchor: true, description: "Quad curve end"))
                    snapPoints.append(SnapPoint(point: control.cgPoint, objectID: shape.id, isAnchor: false, description: "Quad control"))
                case .close:
                    break
                }
        }
        let bounds = shape.bounds
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Top-left"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Top-right"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Bottom-left"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Bottom-right"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Center"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Top-center"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Bottom-center"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Left-center"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Right-center"))
        let transformedSnapPoints = snapPoints.map { snapPoint in
            let transformedPoint = snapPoint.point.applying(shape.transform)
            return SnapPoint(point: transformedPoint, objectID: snapPoint.objectID, isAnchor: snapPoint.isAnchor, description: snapPoint.description)
        }
        return transformedSnapPoints
    }

    func applySnapping(to point: CGPoint) -> CGPoint {
        if document.gridSettings.snapToPoint {
            if let snapPoint = findNearestSnapPoint(to: point) {
                currentSnapPoint = snapPoint.point
                return snapPoint.point
            } else {
                currentSnapPoint = nil
            }
        }
        if document.gridSettings.snapToGrid {
            return snapToGrid(point)
        }
        currentSnapPoint = nil
        return point
    }

    func drawSnapPointFeedback(in context: CGContext, at mousePoint: CGPoint, snapPointView: CGPoint) {
        guard document.gridSettings.snapToPoint else { return }
        context.saveGState()
        context.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8))
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [])
        context.addEllipse(in: CGRect(x: snapPointView.x - 8, y: snapPointView.y - 8, width: 16, height: 16))
        context.strokePath()
        context.setFillColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.3))
        context.addEllipse(in: CGRect(x: snapPointView.x - 4, y: snapPointView.y - 4, width: 8, height: 8))
        context.fillPath()
        let distance = hypot(mousePoint.x - snapPointView.x, mousePoint.y - snapPointView.y)
        if distance > 1.0 {
            context.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.4))
            context.setLineWidth(1.0)
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.move(to: mousePoint)
            context.addLine(to: snapPointView)
            context.strokePath()
        }
        context.restoreGState()
    }

    func drawSnapPointFeedback(in context: CGContext, at mousePoint: CGPoint) {
        guard document.gridSettings.snapToPoint, let snapPoint = currentSnapPoint else { return }
        drawSnapPointFeedback(in: context, at: mousePoint, snapPointView: snapPoint)
    }
}
