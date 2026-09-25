import Foundation
import CoreGraphics

enum AlignmentAxis {
    case both
    case xOnly
    case yOnly
}

extension VectorDocument {

    func alignSelectedObjectsByOrigin() {
        alignSelectedObjectsByOrigin(axis: .both)
    }

    func alignSelectedObjectsByOriginX() {
        alignSelectedObjectsByOrigin(axis: .xOnly)
    }

    func alignSelectedObjectsByOriginY() {
        alignSelectedObjectsByOrigin(axis: .yOnly)
    }

    private func shapesPositionInTransform(_ shape: VectorShape) -> Bool {
        return shape.embeddedImageData != nil || shape.linkedImagePath != nil || shape.linkedImageBookmarkData != nil || !shape.transform.isIdentity
    }

    private func worldBounds(_ shape: VectorShape) -> CGRect {
        if shape.isGroupContainer { return shape.groupBounds }
        if shape.typography != nil {
            if let pos = shape.textPosition, let size = shape.areaSize {
                return CGRect(origin: pos, size: size)
            }
            return CGRect(x: shape.transform.tx, y: shape.transform.ty, width: shape.bounds.width, height: shape.bounds.height)
        }
        return shape.bounds.applying(shape.transform)
    }

    private func alignSelectedObjectsByOrigin(axis: AlignmentAxis) {
        let orderedIDs = viewState.orderedSelectedObjectIDs
        guard orderedIDs.count >= 2 else { return }
        let anchorID = determineAlignmentAnchor(from: orderedIDs)
        guard let anchorObj = snapshot.objects[anchorID] else { return }
        let anchorShape = anchorObj.shape
        let anchorOrigin = anchorShape.transformOrigin ?? .center
        let anchorBounds = worldBounds(anchorShape)
        let anchorPoint = CGPoint(
            x: anchorBounds.minX + anchorBounds.width * anchorOrigin.point.x,
            y: anchorBounds.minY + anchorBounds.height * anchorOrigin.point.y
        )
        modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in orderedIDs where objectID != anchorID {
                    guard let obj = snapshot.objects[objectID] else { continue }
                    var shape = obj.shape

                    let shapeOrigin = shape.transformOrigin ?? .center
                    let shapeBounds = worldBounds(shape)
                    let currentOriginPoint = CGPoint(
                        x: shapeBounds.minX + shapeBounds.width * shapeOrigin.point.x,
                        y: shapeBounds.minY + shapeBounds.height * shapeOrigin.point.y
                    )
                    let offsetX: CGFloat
                    let offsetY: CGFloat
                    switch axis {
                    case .both:
                        offsetX = anchorPoint.x - currentOriginPoint.x
                        offsetY = anchorPoint.y - currentOriginPoint.y
                    case .xOnly:
                        offsetX = anchorPoint.x - currentOriginPoint.x
                        offsetY = 0
                    case .yOnly:
                        offsetX = 0
                        offsetY = anchorPoint.y - currentOriginPoint.y
                    }
                    guard abs(offsetX) > 0.001 || abs(offsetY) > 0.001 else { continue }
                    if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                        let translationTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
                        applyTransformToGroup(groupID: shape.id, transform: translationTransform)
                        continue
                    } else if shape.isGroupContainer {
                        for i in shape.groupedShapes.indices {
                            var groupedShape = shape.groupedShapes[i]
                            translateShapePath(&groupedShape, dx: offsetX, dy: offsetY)
                            shape.groupedShapes[i] = groupedShape
                        }
                        shape.updateBounds()
                    } else if shape.typography != nil {
                        if let pos = shape.textPosition {
                            shape.textPosition = CGPoint(x: pos.x + offsetX, y: pos.y + offsetY)
                            shape.transform = CGAffineTransform(translationX: pos.x + offsetX, y: pos.y + offsetY)
                        }
                    } else if shapesPositionInTransform(shape) {
                        let translationTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
                        shape.transform = shape.transform.concatenating(translationTransform)
                    } else {
                        translateShapePath(&shape, dx: offsetX, dy: offsetY)
                    }
                    updateShapeByID(objectID, silent: false) { s in
                        s = shape
                    }
                }
            }
        )
    }

    private func determineAlignmentAnchor(from orderedIDs: [UUID]) -> UUID {
        for objectID in orderedIDs {
            guard let obj = snapshot.objects[objectID] else { continue }
            let shape = obj.shape
            if shape.isLocked {
                return objectID
            }
        }
        let mode = ApplicationSettings.shared.alignmentAnchorMode
        switch mode {
        case .firstSelected:
            return orderedIDs.first ?? orderedIDs[0]
        case .lastSelected:
            return orderedIDs.last ?? orderedIDs[0]
        case .largestArea:
            var largestID = orderedIDs[0]
            var largestArea: CGFloat = 0
            for objectID in orderedIDs {
                guard let obj = snapshot.objects[objectID] else { continue }
                let shape = obj.shape
                let bounds = worldBounds(shape)
                let area = bounds.width * bounds.height
                if area > largestArea {
                    largestArea = area
                    largestID = objectID
                }
            }
            return largestID
        case .smallestArea:
            var smallestID = orderedIDs[0]
            var smallestArea: CGFloat = .greatestFiniteMagnitude
            for objectID in orderedIDs {
                guard let obj = snapshot.objects[objectID] else { continue }
                let shape = obj.shape
                let bounds = worldBounds(shape)
                let area = bounds.width * bounds.height
                if area < smallestArea {
                    smallestArea = area
                    smallestID = objectID
                }
            }
            return smallestID
        }
    }

    private func translateShapePath(_ shape: inout VectorShape, dx: CGFloat, dy: CGFloat) {
        var translatedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                translatedElements.append(.move(to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy))))
            case .line(let to):
                translatedElements.append(.line(to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy))))
            case .curve(let to, let control1, let control2):
                translatedElements.append(.curve(
                    to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy)),
                    control1: VectorPoint(CGPoint(x: control1.x + dx, y: control1.y + dy)),
                    control2: VectorPoint(CGPoint(x: control2.x + dx, y: control2.y + dy))
                ))
            case .quadCurve(let to, let control):
                translatedElements.append(.quadCurve(
                    to: VectorPoint(CGPoint(x: to.x + dx, y: to.y + dy)),
                    control: VectorPoint(CGPoint(x: control.x + dx, y: control.y + dy))
                ))
            case .close:
                translatedElements.append(.close)
            }
        }
        shape.path = VectorPath(elements: translatedElements)
        shape.updateBounds()
    }
}
