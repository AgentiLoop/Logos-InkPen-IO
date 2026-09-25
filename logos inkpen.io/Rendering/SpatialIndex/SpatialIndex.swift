import SwiftUI

struct SpatialIndex {
    private let gridSize: CGFloat = 50

    private var grid: [GridCell: Set<UUID>] = [:]
    private var objectBounds: [UUID: CGRect] = [:]
    private var layerGrids: [UUID: [GridCell: [UUID]]] = [:]

    struct GridCell: Hashable {
        let x: Int
        let y: Int
    }

    mutating func rebuild(from snapshot: DocumentSnapshot) {
        grid.removeAll(keepingCapacity: true)
        objectBounds.removeAll(keepingCapacity: true)
        layerGrids.removeAll(keepingCapacity: true)
        var groupedChildIDs = Set<UUID>()
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }
        for layer in snapshot.layers {
            guard layer.isVisible else { continue }
            var layerGrid: [GridCell: [UUID]] = [:]
            for objectID in layer.objectIDs {
                if groupedChildIDs.contains(objectID) { continue }
                guard let object = snapshot.objects[objectID], object.isVisible else { continue }
                if object.shape.isGroupContainer {
                    let groupBounds = object.shape.groupBounds
                    objectBounds[objectID] = groupBounds
                    let groupCells = cellsForBounds(groupBounds)
                    for cell in groupCells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            let childBounds = childShape.bounds.applying(childShape.transform)
                            objectBounds[childShape.id] = childBounds
                            let childCells = cellsForBounds(childBounds)
                            for cell in childCells {
                                grid[cell, default: []].insert(childShape.id)
                                layerGrid[cell, default: []].append(childShape.id)
                            }
                        }
                    default:
                        break
                    }
                } else {
                    let bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        if let position = shape.textPosition, let size = shape.areaSize {
                            bounds = CGRect(origin: position, size: size)
                        } else {
                            bounds = CGRect(
                                x: shape.transform.tx,
                                y: shape.transform.ty,
                                width: shape.bounds.width,
                                height: shape.bounds.height
                            )
                        }
                    case .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .clipMask(let shape),
                         .guide(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                    case .group, .clipGroup:
                        continue
                    }
                    objectBounds[objectID] = bounds
                    let cells = cellsForBounds(bounds)
                    for cell in cells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }
                }
            }
            layerGrids[layer.id] = layerGrid
        }
    }

    mutating func rebuildLayers(_ layerIDs: Set<UUID>, from snapshot: DocumentSnapshot) {
        guard !layerIDs.isEmpty else { return }
        for layerID in layerIDs {
            if let layerGrid = layerGrids[layerID] {
                for (cell, objectIDs) in layerGrid {
                    for objectID in objectIDs {
                        grid[cell]?.remove(objectID)
                        if grid[cell]?.isEmpty == true {
                            grid.removeValue(forKey: cell)
                        }
                        objectBounds.removeValue(forKey: objectID)
                    }
                }
            }
            layerGrids.removeValue(forKey: layerID)
        }
        var groupedChildIDs = Set<UUID>()
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }
        for layer in snapshot.layers where layerIDs.contains(layer.id) {
            guard layer.isVisible else { continue }
            var layerGrid: [GridCell: [UUID]] = [:]
            for objectID in layer.objectIDs {
                if groupedChildIDs.contains(objectID) { continue }
                guard let object = snapshot.objects[objectID], object.isVisible else { continue }
                if object.shape.isGroupContainer {
                    let groupBounds = object.shape.groupBounds
                    objectBounds[objectID] = groupBounds
                    let groupCells = cellsForBounds(groupBounds)
                    for cell in groupCells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            let childBounds = childShape.bounds.applying(childShape.transform)
                            objectBounds[childShape.id] = childBounds
                            let childCells = cellsForBounds(childBounds)
                            for cell in childCells {
                                grid[cell, default: []].insert(childShape.id)
                                layerGrid[cell, default: []].append(childShape.id)
                            }
                        }
                    default:
                        break
                    }
                } else {
                    let bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        if let position = shape.textPosition, let size = shape.areaSize {
                            bounds = CGRect(origin: position, size: size)
                        } else {
                            bounds = CGRect(
                                x: shape.transform.tx,
                                y: shape.transform.ty,
                                width: shape.bounds.width,
                                height: shape.bounds.height
                            )
                        }
                    case .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .clipMask(let shape),
                         .guide(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                    case .group, .clipGroup:
                        continue
                    }
                    objectBounds[objectID] = bounds
                    let cells = cellsForBounds(bounds)
                    for cell in cells {
                        grid[cell, default: []].insert(objectID)
                        layerGrid[cell, default: []].append(objectID)
                    }
                }
            }
            layerGrids[layer.id] = layerGrid
        }
    }

    mutating func updateObject(_ objectID: UUID, in snapshot: DocumentSnapshot) {
        var targetLayerID: UUID?
        for layer in snapshot.layers {
            if layer.objectIDs.contains(objectID) {
                targetLayerID = layer.id
                break
            }
        }
        if let oldBounds = objectBounds[objectID] {
            let oldCells = cellsForBounds(oldBounds)
            for cell in oldCells {
                grid[cell]?.remove(objectID)
                if grid[cell]?.isEmpty == true {
                    grid.removeValue(forKey: cell)
                }
                for layerID in layerGrids.keys {
                    layerGrids[layerID]?[cell]?.removeAll { $0 == objectID }
                }
            }
        }
        if let object = snapshot.objects[objectID], object.isVisible, let layerID = targetLayerID {
            let bounds = object.shape.bounds.applying(object.shape.transform)
            objectBounds[objectID] = bounds
            let cells = cellsForBounds(bounds)
            for cell in cells {
                grid[cell, default: []].insert(objectID)
                layerGrids[layerID, default: [:]][cell, default: []].append(objectID)
            }
        } else {
            objectBounds.removeValue(forKey: objectID)
        }
    }

    func candidateObjectIDs(at point: CGPoint) -> Set<UUID> {
        let cell = GridCell(
            x: Int(floor(point.x / gridSize)),
            y: Int(floor(point.y / gridSize))
        )
        return grid[cell] ?? []
    }

    func candidateObjectIDs(in rect: CGRect) -> Set<UUID> {
        let cells = cellsForBounds(rect)

        var candidates = Set<UUID>()
        for cell in cells {
            if let objectIDs = grid[cell] {
                candidates.formUnion(objectIDs)
            }
        }
        return candidates
    }

    func hitTest(at point: CGPoint, in snapshot: DocumentSnapshot, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        let cell = GridCell(
            x: Int(floor(point.x / gridSize)),
            y: Int(floor(point.y / gridSize))
        )
        for layer in snapshot.layers.reversed() {
            guard layer.isVisible else { continue }
            guard let objectIDs = layerGrids[layer.id]?[cell] else { continue }
            for objectID in objectIDs.reversed() {
                guard let object = snapshot.objects[objectID] else { continue }
                if testFunction(object, point) {
                    return object
                }
            }
        }
        return nil
    }

    private func cellsForBounds(_ bounds: CGRect) -> Set<GridCell> {
        let minX = Int(floor(bounds.minX / gridSize))
        let maxX = Int(floor(bounds.maxX / gridSize))
        let minY = Int(floor(bounds.minY / gridSize))
        let maxY = Int(floor(bounds.maxY / gridSize))

        var cells = Set<GridCell>()
        cells.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
        for x in minX...maxX {
            for y in minY...maxY {
                cells.insert(GridCell(x: x, y: y))
            }
        }
        return cells
    }

    func getAllCachedBounds() -> [UUID: CGRect] {
        return objectBounds
    }

    var debugInfo: String {
        let totalCells = grid.count
        let totalObjects = objectBounds.count
        let avgObjectsPerCell = grid.isEmpty ? 0 : grid.values.reduce(0, { $0 + $1.count }) / grid.count
        return """
        SpatialIndex Debug:
        - Grid size: \(gridSize)x\(gridSize)
        - Active cells: \(totalCells)
        - Indexed objects: \(totalObjects)
        - Avg objects/cell: \(avgObjectsPerCell)
        """
    }
}
