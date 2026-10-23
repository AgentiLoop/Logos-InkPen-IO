import CoreGraphics
import Foundation

/// Uniform-grid spatial index used to find hit-test candidates on the canvas.
///
/// CPU-only and per-instance. The earlier GPU version silently dropped objects (layers wider
/// than 10,000 grid cells, cells holding more than 256 objects, zero-width or zero-height lines),
/// kept change fingerprints in a static cache shared by every open document, and skipped
/// rebuilding a group when only its children moved. Any of those made imported SVGs hard or
/// impossible to click. Candidates returned here are still filtered by the exact hit test.
final class MetalSpatialIndex {
    static let gridSize: CGFloat = 50
    /// Objects covering more cells than this are kept in a per-layer list checked linearly.
    static let maxCellsPerObject = 1024

    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    private struct LayerIndex {
        var entries: [(id: UUID, rect: CGRect)] = []
        var cells: [Cell: [Int]] = [:]
        var oversized: [Int] = []
    }

    private var layerIndices: [UUID: LayerIndex] = [:]

    init?() {}

    func rebuildLayers(_ layerIDs: Set<UUID>, from snapshot: DocumentSnapshot) {
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
            var index = LayerIndex()
            if layer.isVisible {
                for objectID in layer.objectIDs {
                    if groupedChildIDs.contains(objectID) { continue }
                    guard let object = snapshot.objects[objectID], object.isVisible else { continue }
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        Self.insert(objectID, groupShape.groupBounds, into: &index)
                        for childShape in groupShape.groupedShapes where childShape.isVisible {
                            Self.insert(childShape.id, Self.hitBounds(of: childShape), into: &index)
                        }
                    case .text(let shape), .shape(let shape), .image(let shape), .warp(let shape),
                         .clipMask(let shape), .guide(let shape):
                        Self.insert(objectID, Self.hitBounds(of: shape), into: &index)
                    }
                }
            }
            layerIndices[layer.id] = index
        }
    }

    func purgeRemovedLayers(from snapshot: DocumentSnapshot) {
        let currentIDs = Set(snapshot.layers.map { $0.id })
        for staleID in layerIndices.keys where !currentIDs.contains(staleID) {
            layerIndices.removeValue(forKey: staleID)
        }
    }

    /// Objects whose bounds lie within `tolerance` of `point`.
    func candidateObjectIDs(at point: CGPoint, tolerance: CGFloat = 0) -> Set<UUID> {
        let slop = tolerance.isFinite ? max(0, tolerance) : 0
        return candidateObjectIDs(in: CGRect(x: point.x - slop, y: point.y - slop, width: slop * 2, height: slop * 2))
    }

    /// Objects whose bounds overlap `rect` (edges touching count, zero-size rects allowed).
    func candidateObjectIDs(in rect: CGRect) -> Set<UUID> {
        var result = Set<UUID>()
        guard let query = Self.cellRange(of: rect) else { return result }
        let queryCellCount = Double(query.maxX - query.minX + 1) * Double(query.maxY - query.minY + 1)
        for index in layerIndices.values {
            if queryCellCount > Double(index.entries.count) {
                // Huge query (e.g. marquee over everything): scanning entries is cheaper than cells.
                for entry in index.entries where Self.overlaps(entry.rect, rect) {
                    result.insert(entry.id)
                }
                continue
            }
            var visited = Set<Int>()
            for cx in query.minX...query.maxX {
                for cy in query.minY...query.maxY {
                    guard let slots = index.cells[Cell(x: cx, y: cy)] else { continue }
                    for slot in slots where visited.insert(slot).inserted {
                        if Self.overlaps(index.entries[slot].rect, rect) {
                            result.insert(index.entries[slot].id)
                        }
                    }
                }
            }
            for slot in index.oversized where Self.overlaps(index.entries[slot].rect, rect) {
                result.insert(index.entries[slot].id)
            }
        }
        return result
    }

    // MARK: - Helpers

    /// Bounds used for hit candidates: path bounds with transform, grown by half the stroke
    /// width (the hit test always counts the stroke). Text uses the same box as the text hit test.
    static func hitBounds(of shape: VectorShape) -> CGRect {
        if shape.typography != nil {
            let transformBox = CGRect(x: shape.transform.tx, y: shape.transform.ty,
                                      width: shape.bounds.width, height: shape.bounds.height)
            if let position = shape.textPosition, let size = shape.areaSize {
                return transformBox.union(CGRect(origin: position, size: size))
            }
            return transformBox
        }
        var rect = shape.bounds.applying(shape.transform)
        if let stroke = shape.strokeStyle, stroke.width.isFinite, stroke.width > 0 {
            rect = rect.insetBy(dx: -stroke.width / 2, dy: -stroke.width / 2)
        }
        return rect
    }

    private static func insert(_ id: UUID, _ rect: CGRect, into index: inout LayerIndex) {
        let r = rect.standardized
        guard !rect.isNull, let range = cellRange(of: r) else { return }
        let slot = index.entries.count
        index.entries.append((id, r))
        let cellCount = Double(range.maxX - range.minX + 1) * Double(range.maxY - range.minY + 1)
        if cellCount > Double(maxCellsPerObject) {
            index.oversized.append(slot)
            return
        }
        for cx in range.minX...range.maxX {
            for cy in range.minY...range.maxY {
                index.cells[Cell(x: cx, y: cy), default: []].append(slot)
            }
        }
    }

    private static func cellRange(of rect: CGRect) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        let r = rect.standardized
        guard r.minX.isFinite, r.minY.isFinite, r.maxX.isFinite, r.maxY.isFinite else { return nil }
        // Clamp so absurd coordinates can't overflow Int conversion; such objects end up oversized.
        let limit: CGFloat = 1e12
        func cell(_ v: CGFloat) -> Int { Int(floor(min(max(v, -limit), limit) / gridSize)) }
        return (cell(r.minX), cell(r.minY), cell(r.maxX), cell(r.maxY))
    }

    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX <= b.maxX && b.minX <= a.maxX && a.minY <= b.maxY && b.minY <= a.maxY
    }
}
