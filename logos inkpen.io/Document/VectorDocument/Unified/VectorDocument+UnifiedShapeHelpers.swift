import SwiftUI
import Combine

extension VectorDocument {

    func updateShapeFillColorInUnified(id: UUID, color: VectorColor) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeFillColorInUnified(id: memberID, color: color)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            if shape.fillStyle == nil {
                shape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
            } else {
                shape.fillStyle?.color = color
            }
            if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
                var updatedChildren: [VectorShape] = []
                for var childShape in shape.groupedShapes {
                    if childShape.fillStyle == nil {
                        childShape.fillStyle = FillStyle(color: color, opacity: defaultFillOpacity)
                    } else {
                        childShape.fillStyle?.color = color
                    }
                    updatedChildren.append(childShape)
                }
                shape.groupedShapes = updatedChildren
            }
        }
    }

    func updateShapeStrokeColorInUnified(id: UUID, color: VectorColor) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokeColorInUnified(id: memberID, color: color)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.color = color
            }
            if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
                var updatedChildren: [VectorShape] = []
                for var childShape in shape.groupedShapes {
                    if childShape.strokeStyle == nil {
                        childShape.strokeStyle = StrokeStyle(color: color, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
                    } else {
                        childShape.strokeStyle?.color = color
                    }
                    updatedChildren.append(childShape)
                }
                shape.groupedShapes = updatedChildren
            }
        }
    }

    func updateShapeFillOpacityInUnified(id: UUID, opacity: Double) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeFillOpacityInUnified(id: memberID, opacity: opacity)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            if shape.fillStyle == nil {
                shape.fillStyle = FillStyle(color: defaultFillColor, opacity: opacity)
            } else {
                shape.fillStyle?.opacity = opacity
            }
        }
    }

    func updateShapeStrokeWidthInUnified(id: UUID, width: Double) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokeWidthInUnified(id: memberID, width: width)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: width, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.width = width
            }
        }
    }

    func lockShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isLocked = true
        }
    }

    func unlockShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isLocked = false
        }
    }

    func hideShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isVisible = false
        }
    }

    func showShapeInUnified(id: UUID) {
        updateShapeByID(id) { shape in
            shape.isVisible = true
        }
    }

    func updateShapeStrokeOpacityInUnified(id: UUID, opacity: Double) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokeOpacityInUnified(id: memberID, opacity: opacity)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: opacity)
            } else {
                shape.strokeStyle?.opacity = opacity
            }
        }
    }

    func updateShapeOpacityInUnified(id: UUID, opacity: Double) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeOpacityInUnified(id: memberID, opacity: opacity)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            shape.opacity = opacity
        }
    }

    func applyTransformToGroup(groupID: UUID, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        guard let object = snapshot.objects[groupID] else { return }
        var memberIDs: [UUID] = []
        switch object.objectType {
        case .group(let shape), .clipGroup(let shape):
            memberIDs = shape.memberIDs
        default:
            return
        }
        guard !memberIDs.isEmpty else { return }
        for memberID in memberIDs {
            applyTransformToMemberShape(memberID: memberID, transform: transform)
        }
        recalculateGroupBounds(groupID: groupID)
    }

    private func applyTransformToMemberShape(memberID: UUID, transform: CGAffineTransform) {
        guard let object = snapshot.objects[memberID] else { return }
        switch object.objectType {
        case .group(let shape), .clipGroup(let shape):
            if !shape.memberIDs.isEmpty {
                for nestedMemberID in shape.memberIDs {
                    applyTransformToMemberShape(memberID: nestedMemberID, transform: transform)
                }
                recalculateGroupBounds(groupID: memberID)
            }
        case .shape, .image, .warp, .clipMask, .guide:
            updateShapeByID(memberID) { shape in
                let combinedTransform = shape.transform.concatenating(transform)

                var transformedElements: [PathElement] = []
                for element in shape.path.elements {
                    switch element {
                    case .move(let to):
                        let transformedPoint = to.cgPoint.applying(combinedTransform)
                        transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                    case .line(let to):
                        let transformedPoint = to.cgPoint.applying(combinedTransform)
                        transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                    case .curve(let to, let control1, let control2):
                        let transformedTo = to.cgPoint.applying(combinedTransform)
                        let transformedControl1 = control1.cgPoint.applying(combinedTransform)
                        let transformedControl2 = control2.cgPoint.applying(combinedTransform)
                        transformedElements.append(.curve(
                            to: VectorPoint(transformedTo),
                            control1: VectorPoint(transformedControl1),
                            control2: VectorPoint(transformedControl2)
                        ))
                    case .quadCurve(let to, let control):
                        let transformedTo = to.cgPoint.applying(combinedTransform)
                        let transformedControl = control.cgPoint.applying(combinedTransform)
                        transformedElements.append(.quadCurve(
                            to: VectorPoint(transformedTo),
                            control: VectorPoint(transformedControl)
                        ))
                    case .close:
                        transformedElements.append(.close)
                    }
                }
                shape.path = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
                shape.transform = .identity
                shape.updateBounds()
            }
        case .text:
            updateShapeByID(memberID) { shape in
                if let textPosition = shape.textPosition {
                    let transformedPosition = textPosition.applying(transform)
                    shape.textPosition = transformedPosition
                }
            }
        }
    }

    func recalculateGroupBounds(groupID: UUID) {
        guard let object = snapshot.objects[groupID] else {
            Log.error("❌ recalculateGroupBounds: Group \(groupID) not found in snapshot.objects", category: .error)
            return
        }
        var memberIDs: [UUID] = []
        switch object.objectType {
        case .group(let shape), .clipGroup(let shape):
            memberIDs = shape.memberIDs
        default:
            return
        }
        var calculatedGroupBounds = CGRect.null
        var foundMembers = 0
        for memberID in memberIDs {
            guard let memberObject = snapshot.objects[memberID] else {
                Log.error("❌ recalculateGroupBounds: Member \(memberID) not found in snapshot.objects", category: .error)
                continue
            }
            let memberShape = memberObject.shape
            foundMembers += 1
            let shapeBounds: CGRect
            if memberShape.typography != nil, let textPosition = memberShape.textPosition, let areaSize = memberShape.areaSize {
                shapeBounds = CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
            } else if memberShape.isGroupContainer {
                shapeBounds = memberShape.groupBounds.applying(memberShape.transform)
            } else {
                shapeBounds = memberShape.bounds.applying(memberShape.transform)
            }
            if !shapeBounds.isNull && !shapeBounds.isInfinite && shapeBounds.width > 0 && shapeBounds.height > 0 {
                calculatedGroupBounds = calculatedGroupBounds.union(shapeBounds)
            }
        }
        if !calculatedGroupBounds.isNull && !calculatedGroupBounds.isInfinite && foundMembers > 0 {
            updateShapeByID(groupID) { shape in
                shape.bounds = calculatedGroupBounds
            }
        } else {
            Log.error("❌ recalculateGroupBounds: Invalid bounds calculated for group \(groupID), foundMembers=\(foundMembers)", category: .error)
        }
    }

    func updateShapeStrokePlacementInUnified(id: UUID, placement: StrokePlacement) {
        if let object = snapshot.objects[id] {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                if !shape.memberIDs.isEmpty {
                    for memberID in shape.memberIDs {
                        updateShapeStrokePlacementInUnified(id: memberID, placement: placement)
                    }
                    return
                }
            default:
                break
            }
        }
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: placement, lineCap: strokeDefaults.lineCap, lineJoin: strokeDefaults.lineJoin, miterLimit: strokeDefaults.miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.placement = placement
            }
        }
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokePlacement": placement.rawValue]
        )
    }
}
