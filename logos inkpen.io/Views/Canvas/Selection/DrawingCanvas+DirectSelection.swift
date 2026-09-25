import SwiftUI
import Combine

extension DrawingCanvas {

    internal func selectIndividualAnchorPointOrHandle(at location: CGPoint, tolerance: Double) -> Bool {
        for shapeID in selectedObjectIDs {
            if let object = document.snapshot.objects[shapeID],
               case .shape(let shape) = object.objectType {
                let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
                if layer?.isLocked == true || shape.isLocked {
                    selectedObjectIDs.removeAll()
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    syncDirectSelectionWithDocument()
                    return true
                }
                    if shape.isGroupContainer {
                        for groupedShape in shape.groupedShapes {
                            if !groupedShape.isVisible { continue }
                            if checkAnchorPointsInShape(groupedShape, at: location, tolerance: tolerance) {
                                return true
                            }
                        }
                    } else {
                        if checkAnchorPointsInShape(shape, at: location, tolerance: tolerance) {
                            return true
                        }
                    }
            }
        }
        return false
    }

    private func checkAnchorPointsInShape(_ shape: VectorShape, at location: CGPoint, tolerance: Double) -> Bool {
        let pointSelectionRadius: Double = 6.0 / zoomLevel
        let handleSelectionRadius: Double = 4.0 / zoomLevel

        var points: [CGPoint] = []
        var elementIndices: [Int] = []
        for (elementIndex, element) in shape.path.elements.enumerated() {
            if let point = element.endpointCGPoint {
                points.append(point)
                elementIndices.append(elementIndex)
            }
        }
        guard !points.isEmpty else { return false }
        if let nearestIndex = MetalComputeEngine.shared.findNearestPointGPU(
            points: points,
            tapLocation: location,
            selectionRadius: pointSelectionRadius,
            transform: shape.transform
        ) {
            let elementIndex = elementIndices[nearestIndex]
            let pointID = PointID(
                shapeID: shape.id,
                pathIndex: 0,
                elementIndex: elementIndex
            )
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed && selectedPoints.contains(pointID) {
                let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
                selectedPoints.remove(pointID)
                for coincidentPoint in coincidentPoints {
                    selectedPoints.remove(coincidentPoint)
                }
                for endpointID in closedPathEndpoints {
                    selectedPoints.remove(endpointID)
                }
                syncDirectSelectionWithDocument()
            } else {
                selectPointWithCoincidents(pointID, addToSelection: isShiftCurrentlyPressed)
                syncDirectSelectionWithDocument()
            }
            return true
        }
        var handlePoints: [CGPoint] = []
        var anchorPoints: [CGPoint] = []
        var handleMetadata: [(elementIndex: Int, handleType: HandleType)] = []
        for (elementIndex, element) in shape.path.elements.enumerated() {
            switch element {
            case .curve(let to, _, let control2):
                let handle2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                if !handle2Collapsed {
                    handlePoints.append(control2.cgPoint)
                    anchorPoints.append(to.cgPoint)
                    handleMetadata.append((elementIndex: elementIndex, handleType: .control2))
                }
                if elementIndex + 1 < shape.path.elements.count,
                   case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                    let handle1Collapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !handle1Collapsed {
                        handlePoints.append(nextControl1.cgPoint)
                        anchorPoints.append(to.cgPoint)
                        handleMetadata.append((elementIndex: elementIndex + 1, handleType: .control1))
                    }
                }
            case .quadCurve(let to, let control):
                let quadHandleCollapsed = (abs(control.x - to.x) < 0.1 && abs(control.y - to.y) < 0.1)
                if !quadHandleCollapsed {
                    handlePoints.append(control.cgPoint)
                    anchorPoints.append(to.cgPoint)
                    handleMetadata.append((elementIndex: elementIndex, handleType: .control1))
                }
            case .move(let to), .line(let to):
                if elementIndex + 1 < shape.path.elements.count,
                   case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !outgoingHandleCollapsed {
                        handlePoints.append(nextControl1.cgPoint)
                        anchorPoints.append(to.cgPoint)
                        handleMetadata.append((elementIndex: elementIndex + 1, handleType: .control1))
                    }
                }
            case .close:
                continue
            }
        }
        if !handlePoints.isEmpty, let nearestIndex = MetalComputeEngine.shared.findNearestHandleGPU(
            handlePoints: handlePoints,
            anchorPoints: anchorPoints,
            tapLocation: location,
            selectionRadius: handleSelectionRadius,
            transform: shape.transform
        ) {
            let metadata = handleMetadata[nearestIndex]
            let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: metadata.elementIndex, handleType: metadata.handleType)
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed && selectedHandles.contains(handleID) {
                selectedHandles.remove(handleID)
                syncDirectSelectionWithDocument()
            } else {
                if !isShiftCurrentlyPressed {
                    selectedHandles.removeAll()
                    selectedPoints.removeAll()
                    visibleHandles.removeAll()
                }
                selectedHandles.insert(handleID)
                visibleHandles.insert(handleID)
                if handleID.handleType == .control2 {
                    if handleID.elementIndex + 1 < shape.path.elements.count {
                        let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: handleID.pathIndex, elementIndex: handleID.elementIndex + 1, handleType: .control1)
                        visibleHandles.insert(oppositeHandleID)
                    }
                } else if handleID.handleType == .control1 {
                    if handleID.elementIndex > 0 {
                        let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: handleID.pathIndex, elementIndex: handleID.elementIndex - 1, handleType: .control2)
                        visibleHandles.insert(oppositeHandleID)
                    }
                }
                selectCoincidentHandles(for: handleID, shape: shape)
                syncDirectSelectionWithDocument()
            }
            return true
        }
        return false
    }

    internal func directSelectWholeShape(at location: CGPoint) -> Bool {
        guard let hitShape = findShapeAtLocationForDirectSelect(at: location) else {
            return false
        }
        if hitShape.isLocked {
            selectedObjectIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
            return true
        }
        let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
        if isShiftCurrentlyPressed {
            if selectedObjectIDs.contains(hitShape.id) {
                selectedObjectIDs.remove(hitShape.id)
            } else {
                selectedObjectIDs.insert(hitShape.id)
            }
        } else {
            selectedObjectIDs.removeAll()
            selectedObjectIDs.insert(hitShape.id)
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
        }
        syncDirectSelectionWithDocument()
        return true
    }

    private func findShapeAtLocationForDirectSelect(at location: CGPoint) -> VectorShape? {
        var bestHit: (shape: VectorShape, zOrder: Int)? = nil
        for (layerIndex, layer) in document.snapshot.layers.enumerated().reversed() {
            if layer.isLocked { continue }
            for (objIndex, objectID) in layer.objectIDs.enumerated().reversed() {
                guard let obj = document.snapshot.objects[objectID] else { continue }
                let shape = obj.shape
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    continue
                }
                if shape.isLocked { continue }
                if !shape.isVisible { continue }
                if shape.isGroupContainer {
                    for (memberIdx, memberID) in shape.memberIDs.enumerated().reversed() {
                        if let memberObj = document.snapshot.objects[memberID] {
                            let memberShape = memberObj.shape
                            if !memberShape.isVisible { continue }
                            if memberShape.isLocked { continue }
                            if performPathOnlyHitTest(shape: memberShape, at: location) {
                                let zOrder = layerIndex * 100000 + objIndex * 1000 + memberIdx
                                if bestHit.map({ zOrder > $0.zOrder }) ?? true {
                                    bestHit = (memberShape, zOrder)
                                }
                            }
                        }
                    }
                    for (idx, groupedShape) in shape.groupedShapes.enumerated().reversed() {
                        if !groupedShape.isVisible { continue }
                        if groupedShape.isLocked { continue }
                        if performPathOnlyHitTest(shape: groupedShape, at: location) {
                            let zOrder = layerIndex * 100000 + objIndex * 1000 + idx
                            if bestHit.map({ zOrder > $0.zOrder }) ?? true {
                                bestHit = (groupedShape, zOrder)
                            }
                        }
                    }
                } else {
                    if performPathOnlyHitTest(shape: shape, at: location) {
                        let zOrder = layerIndex * 100000 + objIndex * 1000
                        if bestHit.map({ zOrder > $0.zOrder }) ?? true {
                            bestHit = (shape, zOrder)
                        }
                    }
                }
            }
        }
        return bestHit?.shape
    }

    internal func handleDirectSelectionTap(at location: CGPoint) {
        let screenTolerance: Double = 15.0
        let tolerance: Double = screenTolerance / zoomLevel

        var foundSelection = false

        let isOptionCurrentlyPressed = isOptionPressed || NSEvent.modifierFlags.contains(.option)
        if isOptionCurrentlyPressed {
            foundSelection = directSelectBehind(at: location)
            if foundSelection { return }
        }
        if !selectedObjectIDs.isEmpty {
            foundSelection = selectIndividualAnchorPointOrHandle(at: location, tolerance: tolerance)
        }
        if !foundSelection {
            foundSelection = directSelectWholeShape(at: location)
        }
        if !foundSelection {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
            selectedObjectIDs.removeAll()
            syncDirectSelectionWithDocument()
        }
    }

    private func directSelectBehind(at location: CGPoint) -> Bool {
        var shapesAtLocation: [VectorShape] = []
        for (_, layer) in document.snapshot.layers.enumerated().reversed() {
            if layer.isLocked { continue }
            for (_, objectID) in layer.objectIDs.enumerated().reversed() {
                guard let obj = document.snapshot.objects[objectID] else { continue }
                let shape = obj.shape
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" { continue }
                if shape.isLocked { continue }
                if !shape.isVisible { continue }
                if shape.isGroupContainer {
                    for memberID in shape.memberIDs.reversed() {
                        if let memberObj = document.snapshot.objects[memberID] {
                            let memberShape = memberObj.shape
                            if !memberShape.isVisible { continue }
                            if memberShape.isLocked { continue }
                            if performPathOnlyHitTest(shape: memberShape, at: location) {
                                shapesAtLocation.append(memberShape)
                            }
                        }
                    }
                    for groupedShape in shape.groupedShapes.reversed() {
                        if !groupedShape.isVisible { continue }
                        if groupedShape.isLocked { continue }
                        if performPathOnlyHitTest(shape: groupedShape, at: location) {
                            shapesAtLocation.append(groupedShape)
                        }
                    }
                } else {
                    if performPathOnlyHitTest(shape: shape, at: location) {
                        shapesAtLocation.append(shape)
                    }
                }
            }
        }
        guard !shapesAtLocation.isEmpty else { return false }
        let clickTolerance: CGFloat = 5.0
        let isSameLocation = abs(location.x - selectBehindLocation.x) < clickTolerance &&
                             abs(location.y - selectBehindLocation.y) < clickTolerance
        if isSameLocation {
            selectBehindIndex = (selectBehindIndex + 1) % shapesAtLocation.count
        } else {
            selectBehindLocation = location
            let topShape = shapesAtLocation[0]
            if selectedObjectIDs.contains(topShape.id) && shapesAtLocation.count > 1 {
                selectBehindIndex = 1
            } else {
                selectBehindIndex = 0
            }
        }
        let shapeToSelect = shapesAtLocation[selectBehindIndex]
        selectedObjectIDs.removeAll()
        selectedObjectIDs.insert(shapeToSelect.id)
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        visibleHandles.removeAll()
        syncDirectSelectionWithDocument()
        return true
    }

    private func selectCoincidentHandles(for handleID: HandleID, shape: VectorShape) {
        let anchorPoint: CGPoint?
        let pointIndex: Int
        if handleID.handleType == .control1 {
            pointIndex = handleID.elementIndex - 1
            if pointIndex >= 0 && pointIndex < shape.path.elements.count {
                anchorPoint = shape.path.elements[pointIndex].endpointCGPoint
            } else {
                return
            }
        } else if handleID.handleType == .control2 {
            pointIndex = handleID.elementIndex
            if pointIndex < shape.path.elements.count {
                anchorPoint = shape.path.elements[pointIndex].endpointCGPoint
            } else {
                return
            }
        } else {
            return
        }
        guard let anchor = anchorPoint else { return }
        let tolerance = 1.0
        for (index, element) in shape.path.elements.enumerated() {
            if index == pointIndex { continue }
            if let point = element.endpointCGPoint {
                let distance = anchor.distance(to: point)
                if distance <= tolerance {
                    if case .curve(_, _, let control2) = element {
                        let handle2Collapsed = (abs(control2.x - point.x) < 0.1 && abs(control2.y - point.y) < 0.1)
                        if !handle2Collapsed {
                            let coincidentHandleID = HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: index,
                                handleType: .control2
                            )
                            if coincidentHandleID != handleID {
                                visibleHandles.insert(coincidentHandleID)
                            }
                        }
                    }
                    let nextIndex = index + 1
                    if nextIndex < shape.path.elements.count {
                        if case .curve(_, let control1, _) = shape.path.elements[nextIndex] {
                            let handle1Collapsed = (abs(control1.x - point.x) < 0.1 && abs(control1.y - point.y) < 0.1)
                            if !handle1Collapsed {
                                let coincidentHandleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: nextIndex,
                                    handleType: .control1
                                )
                                if coincidentHandleID != handleID {
                                    visibleHandles.insert(coincidentHandleID)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
