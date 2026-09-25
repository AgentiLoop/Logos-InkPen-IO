import SwiftUI

extension VectorDocument {

    func performPathfinderOperation(_ operation: PathfinderOperation) -> Bool {
        let selectedShapes = getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            Log.error("❌ No shapes selected for pathfinder operation", category: .error)
            return false
        }
        let paths = selectedShapes.map { $0.path.cgPath }
        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            Log.error("❌ Cannot perform \(operation.rawValue) on selected shapes", category: .error)
            return false
        }
        guard let layerIndex = selectedLayerIndex else { return false }
        var oldShapes: [UUID: VectorShape] = [:]
        for shape in selectedShapes {
            oldShapes[shape.id] = shape
        }
        var resultShapes: [VectorShape] = []
        switch operation {
        case .union:
            if let unionPath = ProfessionalPathOperations.union(paths) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ UNION: No topmost shape found", category: .general)
                    return false
                }
                let unionShape = VectorShape(
                    name: "Union Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unionShape]
            }
        case .minusFront:
            guard selectedShapes.count >= 2 else {
                Log.error("❌ PUNCH requires at least 2 shapes", category: .error)
                return false
            }
            guard let backShape = selectedShapes.first else {
                Log.error("❌ PUNCH: No back shape found", category: .general)
                return false
            }
            let frontShapes = Array(selectedShapes.dropFirst())

            var resultPath = backShape.path.cgPath
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                }
            }
            let resultShape = VectorShape(
                name: "Punch Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
        case .intersect:
            guard selectedShapes.count == 2 else {
                Log.error("❌ INTERSECT requires exactly 2 shapes", category: .error)
                return false
            }
            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ No topmost shape found", category: .general)
                    return false
                }
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
            }
        case .exclude:
            guard selectedShapes.count == 2 else {
                Log.error("❌ EXCLUDE requires exactly 2 shapes", category: .error)
                return false
            }
            let excludedPaths = ProfessionalPathOperations.exclude(paths[0], paths[1])
            guard let topmostShape = selectedShapes.last else {
                Log.error("❌ No topmost shape found", category: .error)
                return false
            }
            for (index, excludedPath) in excludedPaths.enumerated() {
                let excludedShape = VectorShape(
                    name: "Excluded Shape \(index + 1)",
                    path: VectorPath(cgPath: excludedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes.append(excludedShape)
            }
        case .mosaic:
            let mosaicResults = CoreGraphicsPathOperations.splitWithShapeTracking(paths, using: .winding)

            var shapeCounters: [Int: Int] = [:]
            for (mosaicPath, originalShapeIndex) in mosaicResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                let originalShape = selectedShapes[originalShapeIndex]
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                let mosaicShape = VectorShape(
                    name: pieceNumber > 1 ? "Mosaic \(originalShape.name) (\(pieceNumber))" : "Mosaic \(originalShape.name)",
                    path: VectorPath(cgPath: mosaicPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mosaicShape)
            }
        case .cut:
            let cutResults = CoreGraphicsPathOperations.cutWithShapeTracking(paths, using: .winding)

            var shapeCounters: [Int: Int] = [:]
            for (cutPath, originalShapeIndex) in cutResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                let originalShape = selectedShapes[originalShapeIndex]
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                let cutShape = VectorShape(
                    name: pieceNumber > 1 ? "Cut \(originalShape.name) (\(pieceNumber))" : "Cut \(originalShape.name)",
                    path: VectorPath(cgPath: cutPath),
                    strokeStyle: nil,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(cutShape)
            }
        case .merge:
            let colors = selectedShapes.compactMap { $0.fillStyle?.color ?? .clear }
            guard colors.count == selectedShapes.count else {
                Log.error("❌ MERGE: Could not extract colors from all shapes", category: .error)
                return false
            }
            let mergeResults = ProfessionalPathOperations.professionalMergeWithShapeTracking(paths, colors: colors)

            var shapeCounters: [Int: Int] = [:]
            for (mergedPath, originalShapeIndex) in mergeResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                let originalShape = selectedShapes[originalShapeIndex]
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                let mergedShape = VectorShape(
                    name: pieceNumber > 1 ? "Merged \(originalShape.name) (\(pieceNumber))" : "Merged \(originalShape.name)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mergedShape)
            }
        case .crop:
            let cropResults = ProfessionalPathOperations.professionalCropWithShapeTracking(paths)

            var shapeCounters: [Int: Int] = [:]
            for (croppedPath, originalShapeIndex, isInvisibleCropShape) in cropResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                let originalShape = selectedShapes[originalShapeIndex]
                if isInvisibleCropShape {
                    let invisibleCropShape = VectorShape(
                        name: "Crop Boundary (\(originalShape.name))",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil,
                        fillStyle: nil,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(invisibleCropShape)
                } else {
                    shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                    let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                    let croppedShape = VectorShape(
                        name: pieceNumber > 1 ? "Cropped \(originalShape.name) (\(pieceNumber))" : "Cropped \(originalShape.name)",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil,
                        fillStyle: originalShape.fillStyle,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(croppedShape)
                }
            }
        case .dieline:
            let dielinePaths = ProfessionalPathOperations.dieline(paths)
            for (index, dielinePath) in dielinePaths.enumerated() {
                let dielineShape = VectorShape(
                    name: "Dieline \(index + 1)",
                    path: VectorPath(cgPath: dielinePath),
                    strokeStyle: StrokeStyle(
                        color: .black,
                        width: 1.0,
                        placement: .center,
                        lineCap: .round,
                        lineJoin: .round
                    ),
                    fillStyle: nil,
                    transform: .identity,
                    opacity: 1.0
                )
                resultShapes.append(dielineShape)
            }
        case .separate:
            var separatedShapes: [VectorShape] = []
            for (_, shape) in selectedShapes.enumerated() {
                let components = CoreGraphicsPathOperations.componentsSeparated(shape.path.cgPath, using: .winding)
                if components.count <= 1 {
                    separatedShapes.append(shape)
                } else {
                    for (componentIndex, component) in components.enumerated() {
                        let separatedShape = VectorShape(
                            name: components.count > 1 ? "\(shape.name) Component \(componentIndex + 1)" : shape.name,
                            path: VectorPath(cgPath: component),
                            strokeStyle: shape.strokeStyle,
                            fillStyle: shape.fillStyle,
                            transform: shape.transform,
                            opacity: shape.opacity
                        )
                        separatedShapes.append(separatedShape)
                    }
                }
            }
            resultShapes = separatedShapes
        case .kick:
            guard selectedShapes.count >= 2 else {
                Log.error("❌ KICK requires at least 2 shapes", category: .error)
                return false
            }
            guard let frontShape = selectedShapes.last else {
                Log.error("❌ KICK: No front shape found", category: .general)
                return false
            }
            let backShapes = Array(selectedShapes.dropLast())

            var resultPath = frontShape.path.cgPath
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.kick(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                }
            }
            let resultShape = VectorShape(
                name: "Kick Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
        case .combine:
            if let unionPath = ProfessionalPathOperations.union(paths) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ COMBINE: No topmost shape found", category: .general)
                    return false
                }
                let combinedShape = VectorShape(
                    name: "Combined Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [combinedShape]
            }
        }
        guard !resultShapes.isEmpty else {
            Log.error("❌ Pathfinder operation \(operation.rawValue) produced no results", category: .error)
            return false
        }
        var newShapes: [UUID: VectorShape] = [:]
        for shape in resultShapes {
            newShapes[shape.id] = shape
        }
        let command = GroupCommand(
            operation: .pathOperation,
            layerIndex: layerIndex,
            removedObjectIDs: Array(oldShapes.keys),
            removedShapes: oldShapes,
            addedObjectIDs: Array(newShapes.keys),
            addedShapes: newShapes,
            oldSelectedObjectIDs: Set(oldShapes.keys),
            newSelectedObjectIDs: Set(newShapes.keys)
        )
        executeCommand(command)
        return true
    }
}
