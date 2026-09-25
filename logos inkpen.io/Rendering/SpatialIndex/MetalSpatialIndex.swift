import Metal
import MetalKit
import SwiftUI

class MetalSpatialIndex {
    private static var sharedDevice: MTLDevice?
    private static var sharedCommandQueue: MTLCommandQueue?
    private static var sharedBuildPipeline: MTLComputePipelineState?
    private static var sharedQueryPointPipeline: MTLComputePipelineState?
    private static var sharedQueryRectPipeline: MTLComputePipelineState?
    private static var sharedClearGridPipeline: MTLComputePipelineState?
    private static var sharedInitialized = false

    private var device: MTLDevice { Self.sharedDevice! }
    private var commandQueue: MTLCommandQueue { Self.sharedCommandQueue! }
    private var pipelineState: MTLComputePipelineState { Self.sharedBuildPipeline! }
    private var queryPointPipeline: MTLComputePipelineState { Self.sharedQueryPointPipeline! }
    private var queryRectPipeline: MTLComputePipelineState { Self.sharedQueryRectPipeline! }
    private var clearGridPipeline: MTLComputePipelineState { Self.sharedClearGridPipeline! }

    private let gridSize: Float = 50.0
    private let maxObjectsPerCell: UInt32 = 256

    private var layerIndices: [UUID: LayerSpatialIndex] = [:]

    private static let fingerprintLock = NSLock()

    private static var sharedLayerFingerprints: [UUID: Int] = [:]

    fileprivate struct LayerSpatialIndex {
        var objectBoundsBuffer: MTLBuffer?
        var gridCellCountsBuffer: MTLBuffer?
        var gridCellObjectsBuffer: MTLBuffer?
        var paramsBuffer: MTLBuffer?
        var gridMinX: Int32 = 0
        var gridMinY: Int32 = 0
        var gridMaxX: Int32 = 0
        var gridMaxY: Int32 = 0
        var totalCells: Int = 0
        var objectIDs: [UUID] = []
        var objectIDToIndex: [UUID: UInt32] = [:]
    }

    init?() {
        if !Self.sharedInitialized {
            let metal = SharedMetalDevice.shared
            guard let cmdQueue = metal.makeCommandQueue() else {
                return nil
            }
            guard let buildPipeline = metal.makePipeline(named: "build_spatial_index"),
                  let qpPipeline = metal.makePipeline(named: "query_point"),
                  let qrPipeline = metal.makePipeline(named: "query_rect"),

                  let cgPipeline = metal.makePipeline(named: "clear_grid") else {
                return nil
            }
            Self.sharedDevice = metal.device
            Self.sharedCommandQueue = cmdQueue
            Self.sharedBuildPipeline = buildPipeline
            Self.sharedQueryPointPipeline = qpPipeline
            Self.sharedQueryRectPipeline = qrPipeline
            Self.sharedClearGridPipeline = cgPipeline
            Self.sharedInitialized = true
        }
        guard Self.sharedInitialized else { return nil }
    }

    nonisolated deinit { }

    static func releaseSharedPipelines() {
        sharedBuildPipeline = nil
        sharedQueryPointPipeline = nil
        sharedQueryRectPipeline = nil
        sharedClearGridPipeline = nil
        sharedCommandQueue = nil
        sharedDevice = nil
        sharedInitialized = false
        fingerprintLock.lock()
        sharedLayerFingerprints.removeAll()
        fingerprintLock.unlock()
    }

    func rebuildLayers(_ layerIDs: Set<UUID>, from snapshot: DocumentSnapshot) {
        let includeStrokesInBounds = ApplicationSettings.shared.boundingBoxIncludesStrokes

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
        var totalObjectsRebuilt = 0
        var layersActuallyRebuilt = 0
        for layer in snapshot.layers {
            guard layerIDs.contains(layer.id) else { continue }
            var fp = Hasher()
            fp.combine(layer.isVisible)
            fp.combine(includeStrokesInBounds)
            for id in layer.objectIDs {
                fp.combine(id)
                if let obj = snapshot.objects[id] {
                    fp.combine(obj.isVisible)
                    let b: CGRect
                    switch obj.objectType {
                    case .shape(let s), .image(let s), .warp(let s), .clipMask(let s), .guide(let s):
                        b = s.bounds.applying(s.transform)
                    case .text(let s):
                        b = CGRect(x: s.transform.tx, y: s.transform.ty, width: s.bounds.width, height: s.bounds.height)
                    case .group(let g), .clipGroup(let g):
                        b = g.groupBounds
                    }
                    fp.combine(b.origin.x); fp.combine(b.origin.y)
                    fp.combine(b.size.width); fp.combine(b.size.height)
                }
            }
            let fingerprint = fp.finalize()

            let fingerprintUnchanged: Bool = {
                Self.fingerprintLock.lock()
                defer { Self.fingerprintLock.unlock() }
                if Self.sharedLayerFingerprints[layer.id] == fingerprint {
                    return true
                }
                Self.sharedLayerFingerprints[layer.id] = fingerprint
                return false
            }()
            if fingerprintUnchanged {
                continue
            }
            layersActuallyRebuilt += 1
            var boundsData: [(UUID, CGRect)] = []
            var minX: CGFloat = .infinity
            var minY: CGFloat = .infinity
            var maxX: CGFloat = -.infinity
            var maxY: CGFloat = -.infinity
            guard layer.isVisible else {
                layerIndices[layer.id] = LayerSpatialIndex()
                continue
            }
            for objectID in layer.objectIDs {
                if groupedChildIDs.contains(objectID) { continue }
                guard let object = snapshot.objects[objectID], object.isVisible else { continue }
                if object.shape.isGroupContainer {
                    let groupBounds = object.shape.groupBounds
                    boundsData.append((objectID, groupBounds))
                    minX = min(minX, groupBounds.minX)
                    minY = min(minY, groupBounds.minY)
                    maxX = max(maxX, groupBounds.maxX)
                    maxY = max(maxY, groupBounds.maxY)
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            var childBounds = childShape.bounds.applying(childShape.transform)
                            if includeStrokesInBounds, let strokeStyle = childShape.strokeStyle {
                                let strokeExpansion = strokeStyle.width / 2.0
                                childBounds = childBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                            }
                            guard childBounds.minX.isFinite && childBounds.minY.isFinite
                                    && childBounds.maxX.isFinite && childBounds.maxY.isFinite
                                    && childBounds.width > 0 && childBounds.height > 0 else { continue }
                            boundsData.append((childShape.id, childBounds))
                            minX = min(minX, childBounds.minX)
                            minY = min(minY, childBounds.minY)
                            maxX = max(maxX, childBounds.maxX)
                            maxY = max(maxY, childBounds.maxY)
                        }
                    default:
                        break
                    }
                } else {
                    var bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        bounds = CGRect(x: shape.transform.tx, y: shape.transform.ty,
                                       width: shape.bounds.width, height: shape.bounds.height)
                    case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape), .guide(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                        if includeStrokesInBounds, let strokeStyle = shape.strokeStyle {
                            let strokeExpansion = strokeStyle.width / 2.0
                            bounds = bounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                        }
                    case .group, .clipGroup:
                        continue
                    }
                    guard bounds.minX.isFinite && bounds.minY.isFinite
                            && bounds.maxX.isFinite && bounds.maxY.isFinite
                            && bounds.width > 0 && bounds.height > 0 else { continue }
                    boundsData.append((objectID, bounds))
                    minX = min(minX, bounds.minX)
                    minY = min(minY, bounds.minY)
                    maxX = max(maxX, bounds.maxX)
                    maxY = max(maxY, bounds.maxY)
                }
            }
            totalObjectsRebuilt += boundsData.count
            if boundsData.isEmpty {
                layerIndices[layer.id] = LayerSpatialIndex()
                continue
            }
            var layerIndex = LayerSpatialIndex()
            guard minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite else {
                layerIndices[layer.id] = LayerSpatialIndex()
                continue
            }
            layerIndex.gridMinX = Int32(clamping: Int(floor(minX / CGFloat(gridSize))))
            layerIndex.gridMinY = Int32(clamping: Int(floor(minY / CGFloat(gridSize))))
            layerIndex.gridMaxX = Int32(clamping: Int(floor(maxX / CGFloat(gridSize))))
            layerIndex.gridMaxY = Int32(clamping: Int(floor(maxY / CGFloat(gridSize))))
            let gridWidth = Int(layerIndex.gridMaxX - layerIndex.gridMinX + 1)
            let gridHeight = Int(layerIndex.gridMaxY - layerIndex.gridMinY + 1)
            let maxGridCells = 10_000
            guard gridWidth > 0 && gridHeight > 0 && gridWidth * gridHeight <= maxGridCells else {
                layerIndices[layer.id] = LayerSpatialIndex()
                continue
            }
            layerIndex.totalCells = gridWidth * gridHeight
            layerIndex.objectIDs = boundsData.map { $0.0 }
            for (index, id) in layerIndex.objectIDs.enumerated() {
                layerIndex.objectIDToIndex[id] = UInt32(index)
            }
            let objectCount = boundsData.count

            var objectBoundsArray: [ObjectBounds] = boundsData.enumerated().map { index, data in
                ObjectBounds(
                    bounds: SIMD4<Float>(Float(data.1.minX), Float(data.1.minY),
                                        Float(data.1.maxX), Float(data.1.maxY)),
                    objectIndex: UInt32(index)
                )
            }
            layerIndex.objectBoundsBuffer = device.makeBuffer(
                bytes: &objectBoundsArray,
                length: MemoryLayout<ObjectBounds>.stride * objectCount,
                options: .storageModeShared
            )
            layerIndex.gridCellCountsBuffer = device.makeBuffer(
                length: MemoryLayout<UInt32>.stride * layerIndex.totalCells,
                options: .storageModeShared
            )
            let maxTotalSlots = layerIndex.totalCells * Int(maxObjectsPerCell)
            layerIndex.gridCellObjectsBuffer = device.makeBuffer(
                length: MemoryLayout<UInt32>.stride * maxTotalSlots,
                options: .storageModeShared
            )
            var params = SpatialGridParams(
                gridSize: gridSize,
                maxObjectsPerCell: maxObjectsPerCell,
                gridMinX: layerIndex.gridMinX,
                gridMinY: layerIndex.gridMinY,
                gridMaxX: layerIndex.gridMaxX,
                gridMaxY: layerIndex.gridMaxY,
                totalObjects: UInt32(objectCount)
            )
            layerIndex.paramsBuffer = device.makeBuffer(
                bytes: &params,
                length: MemoryLayout<SpatialGridParams>.stride,
                options: .storageModeShared
            )
            guard let commandBuffer = commandQueue.makeCommandBuffer(),

                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continue
            }
            computeEncoder.setComputePipelineState(clearGridPipeline)
            computeEncoder.setBuffer(layerIndex.gridCellCountsBuffer, offset: 0, index: 0)
            let clearThreads = MTLSize(width: layerIndex.totalCells, height: 1, depth: 1)
            let clearThreadsPerGroup = MTLSize(
                width: min(clearGridPipeline.threadExecutionWidth, layerIndex.totalCells),
                height: 1, depth: 1
            )
            computeEncoder.dispatchThreads(clearThreads, threadsPerThreadgroup: clearThreadsPerGroup)
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setBuffer(layerIndex.objectBoundsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(layerIndex.gridCellCountsBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(layerIndex.gridCellObjectsBuffer, offset: 0, index: 2)
            computeEncoder.setBuffer(layerIndex.paramsBuffer, offset: 0, index: 3)
            let buildThreads = MTLSize(width: objectCount, height: 1, depth: 1)
            let buildThreadsPerGroup = MTLSize(
                width: min(pipelineState.threadExecutionWidth, objectCount),
                height: 1, depth: 1
            )
            computeEncoder.dispatchThreads(buildThreads, threadsPerThreadgroup: buildThreadsPerGroup)
            computeEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            layerIndices[layer.id] = layerIndex
        }
    }

    func invalidateFingerprints() {
        Self.fingerprintLock.lock()
        Self.sharedLayerFingerprints.removeAll(keepingCapacity: true)
        Self.fingerprintLock.unlock()
    }

    func purgeRemovedLayers(from snapshot: DocumentSnapshot) {
        let currentIDs = Set(snapshot.layers.map { $0.id })
        let staleIDs = Set(layerIndices.keys).subtracting(currentIDs)
        guard !staleIDs.isEmpty else { return }
        for staleID in staleIDs {
            layerIndices.removeValue(forKey: staleID)
        }
        Self.fingerprintLock.lock()
        for staleID in staleIDs {
            Self.sharedLayerFingerprints.removeValue(forKey: staleID)
        }
        Self.fingerprintLock.unlock()
    }

    func candidateObjectIDs(at point: CGPoint) -> Set<UUID> {
        var result = Set<UUID>()
        for (_, layerIndex) in layerIndices {
            guard let gridCellCountsBuffer = layerIndex.gridCellCountsBuffer,
                  let gridCellObjectsBuffer = layerIndex.gridCellObjectsBuffer,
                  let paramsBuffer = layerIndex.paramsBuffer,
                  layerIndex.totalCells > 0 else {
                continue
            }
            let maxCandidates = Int(maxObjectsPerCell)
            let candidatesBuffer = device.makeBuffer(
                length: MemoryLayout<UInt32>.stride * maxCandidates,
                options: .storageModeShared
            )
            var candidateCount: UInt32 = 0

            let candidateCountBuffer = device.makeBuffer(
                bytes: &candidateCount,
                length: MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            )
            var queryPoint = simd_float2(Float(point.x), Float(point.y))

            let queryPointBuffer = device.makeBuffer(
                bytes: &queryPoint,
                length: MemoryLayout<simd_float2>.stride,
                options: .storageModeShared
            )
            guard let commandBuffer = commandQueue.makeCommandBuffer(),

                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continue
            }
            computeEncoder.setComputePipelineState(queryPointPipeline)
            computeEncoder.setBuffer(gridCellCountsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(gridCellObjectsBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(candidatesBuffer, offset: 0, index: 2)
            computeEncoder.setBuffer(candidateCountBuffer, offset: 0, index: 3)
            computeEncoder.setBuffer(queryPointBuffer, offset: 0, index: 4)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 5)
            let threads = MTLSize(width: 1, height: 1, depth: 1)
            let threadsPerGroup = MTLSize(width: 1, height: 1, depth: 1)
            computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard let countPtr = candidateCountBuffer?.contents().bindMemory(to: UInt32.self, capacity: 1) else {
                continue
            }
            let count = Int(countPtr.pointee)
            guard count > 0, let candidatesPtr = candidatesBuffer?.contents().bindMemory(to: UInt32.self, capacity: maxCandidates) else {
                continue
            }
            for i in 0..<min(count, maxCandidates) {
                let objectIndex = Int(candidatesPtr[i])
                if objectIndex < layerIndex.objectIDs.count {
                    result.insert(layerIndex.objectIDs[objectIndex])
                }
            }
        }
        return result
    }

    func candidateObjectIDs(in rect: CGRect) -> Set<UUID> {
        var result = Set<UUID>()
        for (_, layerIndex) in layerIndices {
            guard let gridCellCountsBuffer = layerIndex.gridCellCountsBuffer,
                  let gridCellObjectsBuffer = layerIndex.gridCellObjectsBuffer,
                  let paramsBuffer = layerIndex.paramsBuffer,
                  layerIndex.totalCells > 0 else {
                continue
            }
            guard rect.minX.isFinite && rect.minY.isFinite && rect.maxX.isFinite && rect.maxY.isFinite else { continue }
            let minCellX = Int32(clamping: Int(floor(rect.minX / CGFloat(gridSize))))
            let maxCellX = Int32(clamping: Int(floor(rect.maxX / CGFloat(gridSize))))
            let minCellY = Int32(clamping: Int(floor(rect.minY / CGFloat(gridSize))))
            let maxCellY = Int32(clamping: Int(floor(rect.maxY / CGFloat(gridSize))))
            let cellWidth = max(1, maxCellX - minCellX + 1)
            let cellHeight = max(1, maxCellY - minCellY + 1)
            let maxCandidates = Int(maxObjectsPerCell) * Int(cellWidth) * Int(cellHeight)
            let candidatesBuffer = device.makeBuffer(
                length: MemoryLayout<UInt32>.stride * maxCandidates,
                options: .storageModeShared
            )
            var candidateCount: UInt32 = 0

            let candidateCountBuffer = device.makeBuffer(
                bytes: &candidateCount,
                length: MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            )
            var queryRect = simd_float4(Float(rect.minX), Float(rect.minY), Float(rect.maxX), Float(rect.maxY))

            let queryRectBuffer = device.makeBuffer(
                bytes: &queryRect,
                length: MemoryLayout<simd_float4>.stride,
                options: .storageModeShared
            )
            guard let commandBuffer = commandQueue.makeCommandBuffer(),

                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continue
            }
            computeEncoder.setComputePipelineState(queryRectPipeline)
            computeEncoder.setBuffer(gridCellCountsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(gridCellObjectsBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(candidatesBuffer, offset: 0, index: 2)
            computeEncoder.setBuffer(candidateCountBuffer, offset: 0, index: 3)
            computeEncoder.setBuffer(queryRectBuffer, offset: 0, index: 4)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 5)
            let threads = MTLSize(width: Int(cellWidth), height: Int(cellHeight), depth: 1)
            let threadsPerGroup = MTLSize(
                width: min(queryRectPipeline.threadExecutionWidth, Int(cellWidth)),
                height: min(queryRectPipeline.maxTotalThreadsPerThreadgroup / queryRectPipeline.threadExecutionWidth, Int(cellHeight)),
                depth: 1
            )
            computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)
            computeEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard let countPtr = candidateCountBuffer?.contents().bindMemory(to: UInt32.self, capacity: 1) else {
                continue
            }
            let count = Int(countPtr.pointee)
            guard count > 0, let candidatesPtr = candidatesBuffer?.contents().bindMemory(to: UInt32.self, capacity: maxCandidates) else {
                continue
            }
            for i in 0..<min(count, maxCandidates) {
                let objectIndex = Int(candidatesPtr[i])
                if objectIndex < layerIndex.objectIDs.count {
                    result.insert(layerIndex.objectIDs[objectIndex])
                }
            }
        }
        return result
    }
}

private struct ObjectBounds {
    let bounds: SIMD4<Float>
    let objectIndex: UInt32
}

private struct SpatialGridParams {
    let gridSize: Float
    let maxObjectsPerCell: UInt32
    let gridMinX: Int32
    let gridMinY: Int32
    let gridMaxX: Int32
    let gridMaxY: Int32
    let totalObjects: UInt32
}
