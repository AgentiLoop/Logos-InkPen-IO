import SwiftUI

class CoreGraphicsPathOperations {

    private static func isFinite(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite &&
               rect.size.width.isFinite && rect.size.height.isFinite
    }

    static func union(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            if pathA.isEmpty && pathB.isEmpty { return nil }
            return pathA.isEmpty ? pathB : pathA
        }
        if pathA === pathB {
            let pathBounds = pathA.boundingBox
            guard isFinite(pathBounds) && !pathBounds.isNull else {
                return nil
            }
            let result = pathA.union(pathA, using: fillRule)
            guard !result.isEmpty && isFinite(result.boundingBox) else {
                return pathA
            }
            return result
        }
        let boundsA = pathA.boundingBox
        let boundsB = pathB.boundingBox
        guard isFinite(boundsA) && !boundsA.isNull && isFinite(boundsB) && !boundsB.isNull else {
            return nil
        }
        let result = pathA.union(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }

    static func unionMultiplePaths(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> CGPath? {
        let validPaths = paths.filter { !$0.isEmpty }
        guard !validPaths.isEmpty else { return nil }
        guard validPaths.count > 1 else { return validPaths.first }
        var result = validPaths[0]
        for i in 1..<validPaths.count {
            guard let unionResult = union(result, validPaths[i], using: fillRule) else {
                return result
            }
            result = unionResult
        }
        return result
    }

    private static func pathsCanPotentiallyUnion(_ pathA: CGPath, _ pathB: CGPath) -> Bool {
        let boundsA = pathA.boundingBox
        let boundsB = pathB.boundingBox
        guard !boundsA.isNull && !boundsB.isNull &&
              !boundsA.isInfinite && !boundsB.isInfinite else {
            return false
        }
        let tolerance: CGFloat = 1.0
        let expandedBoundsA = boundsA.insetBy(dx: -tolerance, dy: -tolerance)
        return expandedBoundsA.intersects(boundsB)
    }

    private static func findConnectedComponents(_ pathsWithIndices: [(CGPath, Int)], using fillRule: CGPathFillRule = .winding) -> [[(CGPath, Int)]] {
        guard pathsWithIndices.count > 1 else {
            return [pathsWithIndices]
        }
        var groups: [[(CGPath, Int)]] = []
        var processed: Set<Int> = []
        for i in 0..<pathsWithIndices.count {
            if processed.contains(i) { continue }
            var currentGroup: [(CGPath, Int)] = [pathsWithIndices[i]]
            var groupIndices: Set<Int> = [i]
            processed.insert(i)
            var queue: [Int] = [i]
            while !queue.isEmpty {
                let currentIndex = queue.removeFirst()
                let currentPath = pathsWithIndices[currentIndex].0
                for j in 0..<pathsWithIndices.count {
                    if processed.contains(j) || groupIndices.contains(j) { continue }
                    let otherPath = pathsWithIndices[j].0
                    if pathsAreConnected(currentPath, otherPath, using: fillRule) {
                        currentGroup.append(pathsWithIndices[j])
                        groupIndices.insert(j)
                        processed.insert(j)
                        queue.append(j)
                    }
                }
            }
            groups.append(currentGroup)
        }
        return groups
    }

    private static func pathsAreConnected(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> Bool {
        if !pathsCanPotentiallyUnion(pathA, pathB) {
            return false
        }
        let intersection = pathA.intersection(pathB, using: fillRule)
        if !intersection.isEmpty {
            return true
        }
        let union = pathA.union(pathB, using: fillRule)
        if !union.isEmpty {
            let areaA = pathA.boundingBox.width * pathA.boundingBox.height
            let areaB = pathB.boundingBox.width * pathB.boundingBox.height
            let unionArea = union.boundingBox.width * union.boundingBox.height
            let tolerance: CGFloat = 0.1
            return unionArea < (areaA + areaB) * (1.0 - tolerance)
        }
        return false
    }

    static func intersection(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            return nil
        }
        let result = pathA.intersection(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }

    static func subtract(_ subtractPath: CGPath, from basePath: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !subtractPath.isEmpty && !basePath.isEmpty else {
            return basePath
        }
        let result = basePath.subtracting(subtractPath, using: fillRule)
        return result.isEmpty ? nil : result
    }

    static func symmetricDifference(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            if pathA.isEmpty && pathB.isEmpty { return nil }
            return pathA.isEmpty ? pathB : pathA
        }
        let result = pathA.symmetricDifference(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }

    static func normalized(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !path.isEmpty else { return nil }
        let result = path.normalized(using: fillRule)
        return result.isEmpty ? nil : result
    }

    static func componentsSeparated(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        guard !path.isEmpty else { return [] }
        return path.componentsSeparated(using: fillRule)
    }

    static func split(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return splitWithShapeTracking(paths, using: fillRule).map { $0.0 }
    }

    static func splitWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        let allPieces = getAllMosaicPieces(paths, using: fillRule)
        return allPieces
    }

    private static func getAllMosaicPieces(_ paths: [CGPath], using fillRule: CGPathFillRule) -> [(CGPath, Int)] {
        guard !paths.isEmpty else { return [] }
        let shapeCount = paths.count
        guard shapeCount <= 20 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        var allPieces: [(CGPath, Int)] = []
        for mask in 1..<(1 << shapeCount) {
            var intersectingIndices: [Int] = []
            for i in 0..<shapeCount {
                if (mask & (1 << i)) != 0 {
                    intersectingIndices.append(i)
                }
            }
            guard !intersectingIndices.isEmpty else { continue }
            if intersectingIndices.count == 1 {
                let shapeIndex = intersectingIndices[0]
                let currentPath = paths[shapeIndex]

                var exclusivePath = currentPath
                for otherIndex in 0..<shapeCount {
                    if otherIndex != shapeIndex {
                        if let subtracted = subtract(paths[otherIndex], from: exclusivePath, using: fillRule) {
                            exclusivePath = subtracted
                        }
                        if exclusivePath.isEmpty { break }
                    }
                }
                if !exclusivePath.isEmpty {
                    let components = componentsSeparated(exclusivePath, using: fillRule)
                    for component in components {
                        if !component.isEmpty {
                            allPieces.append((component, shapeIndex))
                        }
                    }
                }
            } else {
                var intersectionPath = paths[intersectingIndices[0]]
                for i in 1..<intersectingIndices.count {
                    let shapeIndex = intersectingIndices[i]
                    if let newIntersection = intersection(intersectionPath, paths[shapeIndex], using: fillRule) {
                        intersectionPath = newIntersection
                    } else {
                        intersectionPath = CGMutablePath()
                        break
                    }
                    if intersectionPath.isEmpty { break }
                }
                for excludeIndex in 0..<shapeCount {
                    if !intersectingIndices.contains(excludeIndex) {
                        if let subtracted = subtract(paths[excludeIndex], from: intersectionPath, using: fillRule) {
                            intersectionPath = subtracted
                        }
                        if intersectionPath.isEmpty { break }
                    }
                }
                if !intersectionPath.isEmpty {
                    let components = componentsSeparated(intersectionPath, using: fillRule)
                    for component in components {
                        if !component.isEmpty {
                            let topmostIndex = intersectingIndices.max() ?? intersectingIndices[0]
                            allPieces.append((component, topmostIndex))
                        }
                    }
                }
            }
        }
        var uniquePieces: [(CGPath, Int)] = []

        let tolerance: CGFloat = 0.1
        for (candidate, candidateIndex) in allPieces {
            var isDuplicate = false
            for (existing, _) in uniquePieces {
                if pathsAreEquivalent(candidate, existing, tolerance: tolerance) {
                    isDuplicate = true
                    break
                }
            }
            if !isDuplicate {
                uniquePieces.append((candidate, candidateIndex))
            }
        }
        return uniquePieces
    }

    private static func pathsAreEquivalent(_ path1: CGPath, _ path2: CGPath, tolerance: CGFloat) -> Bool {
        if path1.isEmpty && path2.isEmpty { return true }
        if path1.isEmpty || path2.isEmpty { return false }
        let bounds1 = path1.boundingBoxOfPath
        let bounds2 = path2.boundingBoxOfPath
        let boundsEqual = abs(bounds1.minX - bounds2.minX) < tolerance &&
                         abs(bounds1.minY - bounds2.minY) < tolerance &&
                         abs(bounds1.maxX - bounds2.maxX) < tolerance &&
                         abs(bounds1.maxY - bounds2.maxY) < tolerance
        if !boundsEqual { return false }
        let midPoint = CGPoint(x: bounds1.midX, y: bounds1.midY)
        let path1ContainsMid = path1.contains(midPoint, using: .winding)
        let path2ContainsMid = path2.contains(midPoint, using: .winding)
        return path1ContainsMid == path2ContainsMid
    }

    static func cutWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        var resultPaths: [(CGPath, Int)] = []
        for i in 0..<paths.count {
            let currentPath = paths[i]
            guard !currentPath.isEmpty else {
                continue
            }
            var visiblePath = currentPath
            var hasShapesInFront = false
            for j in (i+1)..<paths.count {
                let frontPath = paths[j]
                guard !frontPath.isEmpty else { continue }
                hasShapesInFront = true
                if let subtracted = subtract(frontPath, from: visiblePath, using: fillRule) {
                    visiblePath = subtracted
                } else {
                    visiblePath = CGMutablePath()
                    break
                }
                if visiblePath.isEmpty {
                    break
                }
            }
            if hasShapesInFront {
                if !visiblePath.isEmpty {
                    let components = componentsSeparated(visiblePath, using: fillRule)
                    for component in components {
                        if !component.isEmpty {
                            resultPaths.append((component, i))
                        }
                    }
                }
            } else {
                resultPaths.append((currentPath, i))
            }
        }
        return resultPaths
    }

    static func cut(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return cutWithShapeTracking(paths, using: fillRule).map { $0.0 }
    }

    static func mergeWithShapeTracking(_ paths: [CGPath], colors: [VectorColor], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 && colors.count == paths.count else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        let cutResults = cutWithShapeTracking(paths, using: fillRule)

        var colorGroups: [VectorColor: [(CGPath, Int)]] = [:]
        for (cutPath, originalIndex) in cutResults {
            let color = colors[originalIndex]
            if colorGroups[color] == nil {
                colorGroups[color] = []
            }
            colorGroups[color]?.append((cutPath, originalIndex))
        }
        var resultPaths: [(CGPath, Int)] = []
        for (_, group) in colorGroups {
            if group.count == 1 {
                let (path, originalIndex) = group[0]
                resultPaths.append((path, originalIndex))
            } else {
                let pathsToUnion = group.map { $0.0 }
                let firstOriginalIndex = group[0].1
                if let unionedPath = Self.unionMultiplePaths(pathsToUnion, using: fillRule) {
                    resultPaths.append((unionedPath, firstOriginalIndex))
                } else {
                    for (path, originalIndex) in group {
                        resultPaths.append((path, originalIndex))
                    }
                }
            }
        }
        return resultPaths
    }

    static func cropWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int, Bool)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index, false) }
        }
        guard let cropShape = paths.last else {
            Log.error("❌ CROP: No crop shape found", category: .general)
            return []
        }
        let shapesToCrop = Array(paths.dropLast())
        let cropShapeIndex = paths.count - 1

        var croppedPaths: [CGPath] = []
        var originalIndices: [Int] = []
        for (index, path) in shapesToCrop.enumerated() {
            guard !path.isEmpty && !cropShape.isEmpty else {
                continue
            }
            if let croppedPath = intersection(path, cropShape, using: fillRule) {
                if !croppedPath.isEmpty && !croppedPath.boundingBoxOfPath.isEmpty {
                    croppedPaths.append(croppedPath)
                    originalIndices.append(index)
                }
            }
        }
        if croppedPaths.count >= 2 {
            let cutResults = cutWithShapeTracking(croppedPaths, using: fillRule)

            var finalResults: [(CGPath, Int, Bool)] = []
            for (cutPath, cutIndex) in cutResults {
                if cutIndex < originalIndices.count {
                    let originalIndex = originalIndices[cutIndex]
                    finalResults.append((cutPath, originalIndex, false))
                } else {
                    let originalIndex = cutIndex % shapesToCrop.count
                    finalResults.append((cutPath, originalIndex, false))
                }
            }
            finalResults.append((cropShape, cropShapeIndex, true))
            return finalResults
        } else {
            var finalResults: [(CGPath, Int, Bool)] = []
            for (index, path) in croppedPaths.enumerated() {
                if index < originalIndices.count {
                    let originalIndex = originalIndices[index]
                    finalResults.append((path, originalIndex, false))
                }
            }
            finalResults.append((cropShape, cropShapeIndex, true))
            return finalResults
        }
    }
}
