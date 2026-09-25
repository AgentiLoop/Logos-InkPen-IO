import Foundation
import CoreGraphics
import Metal
import simd

class PDFMetalAccelerator {
    private static var _shared: PDFMetalAccelerator?

    private static let lock = NSLock()

    static var shared: PDFMetalAccelerator {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _shared { return existing }
        let instance = PDFMetalAccelerator()
        _shared = instance
        return instance
    }

    static func releaseShared() {
        lock.lock()
        _shared = nil
        lock.unlock()
    }
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let transformPointsPipeline: MTLComputePipelineState
    private let batchTransformPipeline: MTLComputePipelineState
    private let multiplyMatricesPipeline: MTLComputePipelineState
    private let calculateBoundsPipeline: MTLComputePipelineState
    private let mergeBoundsPipeline: MTLComputePipelineState
    private let batchDistancesPipeline: MTLComputePipelineState
    private let perpendicularDistancesPipeline: MTLComputePipelineState
    private let evaluateBezierPipeline: MTLComputePipelineState
    private let curveFlatnessPipeline: MTLComputePipelineState
    private let collinearityPipeline: MTLComputePipelineState
    private let rectIntersectionsPipeline: MTLComputePipelineState
    private let parallelMaxPipeline: MTLComputePipelineState
    private let parallelMaxIndexPipeline: MTLComputePipelineState
    private let interpolatePipeline: MTLComputePipelineState

    private init() {
        let metal = SharedMetalDevice.shared
        self.device = metal.device
        guard let commandQueue = metal.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = commandQueue

        func createPipeline(named functionName: String) throws -> MTLComputePipelineState {
            guard let function = metal.library.makeFunction(name: functionName) else {
                throw NSError(domain: "PDFMetalAccelerator", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "Function \(functionName) not found"])
            }
            return try metal.device.makeComputePipelineState(function: function)
        }
        do {
            transformPointsPipeline = try createPipeline(named: "transformPoints")
            batchTransformPipeline = try createPipeline(named: "batchTransformPoints")
            multiplyMatricesPipeline = try createPipeline(named: "multiplyMatrices")
            calculateBoundsPipeline = try createPipeline(named: "calculateBounds")
            mergeBoundsPipeline = try createPipeline(named: "mergeBounds")
            batchDistancesPipeline = try createPipeline(named: "batchCalculateDistances")
            perpendicularDistancesPipeline = try createPipeline(named: "perpendicularDistances")
            evaluateBezierPipeline = try createPipeline(named: "evaluateCubicBezier")
            curveFlatnessPipeline = try createPipeline(named: "calculateCurveFlatness")
            collinearityPipeline = try createPipeline(named: "batchCheckCollinearity")
            rectIntersectionsPipeline = try createPipeline(named: "batchRectIntersections")
            parallelMaxPipeline = try createPipeline(named: "parallelMax")
            parallelMaxIndexPipeline = try createPipeline(named: "parallelMaxWithIndex")
            interpolatePipeline = try createPipeline(named: "batchInterpolate")
        } catch {
            fatalError("Failed to create Metal pipelines: \(error)")
        }
    }

    func transformPoints(_ points: [CGPoint], with matrix: PDFSIMDMatrix) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        let count = points.count

        var inputPoints = points.map { simd_float2(Float($0.x), Float($0.y)) }
        var matrixData = matrix.matrix
        guard let inputBuffer = device.makeBuffer(bytes: &inputPoints,
                                                  length: count * MemoryLayout<simd_float2>.stride,
                                                  options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: count * MemoryLayout<simd_float2>.stride,
                                                   options: .storageModeShared),
              let matrixBuffer = device.makeBuffer(bytes: &matrixData,
                                                   length: MemoryLayout<simd_float3x3>.stride,
                                                   options: .storageModeShared) else {
            return points
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return points
        }
        encoder.setComputePipelineState(transformPointsPipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(matrixBuffer, offset: 0, index: 2)
        let threadgroupSize = MTLSize(width: min(transformPointsPipeline.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputPointer = outputBuffer.contents().bindMemory(to: simd_float2.self, capacity: count)
        return (0..<count).map { CGPoint(x: CGFloat(outputPointer[$0].x), y: CGFloat(outputPointer[$0].y)) }
    }

    func multiplyMatrices(_ matrices: [(PDFSIMDMatrix, PDFSIMDMatrix)]) -> [PDFSIMDMatrix] {
        guard !matrices.isEmpty else { return [] }
        let count = matrices.count

        var matrices1 = matrices.map { $0.0.matrix }
        var matrices2 = matrices.map { $0.1.matrix }
        guard let buffer1 = device.makeBuffer(bytes: &matrices1,
                                              length: count * MemoryLayout<simd_float3x3>.stride,
                                              options: .storageModeShared),
              let buffer2 = device.makeBuffer(bytes: &matrices2,
                                              length: count * MemoryLayout<simd_float3x3>.stride,
                                              options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: count * MemoryLayout<simd_float3x3>.stride,
                                                   options: .storageModeShared) else {
            return matrices.map { $0.0.concatenating($0.1) }
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return matrices.map { $0.0.concatenating($0.1) }
        }
        encoder.setComputePipelineState(multiplyMatricesPipeline)
        encoder.setBuffer(buffer1, offset: 0, index: 0)
        encoder.setBuffer(buffer2, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        let threadgroupSize = MTLSize(width: min(multiplyMatricesPipeline.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputPointer = outputBuffer.contents().bindMemory(to: simd_float3x3.self, capacity: count)
        return (0..<count).map { PDFSIMDMatrix(metalBuffer: Array(UnsafeBufferPointer(start: outputPointer.advanced(by: $0), count: 1)).flatMap { [$0.columns.0.x, $0.columns.0.y, $0.columns.0.z, $0.columns.1.x, $0.columns.1.y, $0.columns.1.z, $0.columns.2.x, $0.columns.2.y, $0.columns.2.z] }) }
    }

    func calculateDistances(from origin: CGPoint, to points: [CGPoint]) -> [CGFloat] {
        guard !points.isEmpty else { return [] }
        let count = points.count

        var originVec = simd_float2(Float(origin.x), Float(origin.y))
        var pointVecs = points.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let originBuffer = device.makeBuffer(bytes: &originVec,
                                                   length: MemoryLayout<simd_float2>.stride,
                                                   options: .storageModeShared),
              let pointsBuffer = device.makeBuffer(bytes: &pointVecs,
                                                   length: count * MemoryLayout<simd_float2>.stride,
                                                   options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: count * MemoryLayout<Float>.stride,
                                                   options: .storageModeShared) else {
            return points.map { hypot($0.x - origin.x, $0.y - origin.y) }
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return points.map { hypot($0.x - origin.x, $0.y - origin.y) }
        }
        encoder.setComputePipelineState(batchDistancesPipeline)
        encoder.setBuffer(originBuffer, offset: 0, index: 0)
        encoder.setBuffer(pointsBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        let threadgroupSize = MTLSize(width: min(batchDistancesPipeline.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputPointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { CGFloat(outputPointer[$0]) }
    }

    func perpendicularDistances(points: [CGPoint], lineStart: CGPoint, lineEnd: CGPoint) -> [Float] {
        guard !points.isEmpty else { return [] }
        let count = points.count

        var pointVecs = points.map { simd_float2(Float($0.x), Float($0.y)) }
        var startVec = simd_float2(Float(lineStart.x), Float(lineStart.y))
        var endVec = simd_float2(Float(lineEnd.x), Float(lineEnd.y))
        guard let pointsBuffer = device.makeBuffer(bytes: &pointVecs,
                                                   length: count * MemoryLayout<simd_float2>.stride,
                                                   options: .storageModeShared),
              let startBuffer = device.makeBuffer(bytes: &startVec,
                                                  length: MemoryLayout<simd_float2>.stride,
                                                  options: .storageModeShared),
              let endBuffer = device.makeBuffer(bytes: &endVec,
                                                length: MemoryLayout<simd_float2>.stride,
                                                options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: count * MemoryLayout<Float>.stride,
                                                   options: .storageModeShared) else {
            return []
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return []
        }
        encoder.setComputePipelineState(perpendicularDistancesPipeline)
        encoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        encoder.setBuffer(startBuffer, offset: 0, index: 1)
        encoder.setBuffer(endBuffer, offset: 0, index: 2)
        encoder.setBuffer(outputBuffer, offset: 0, index: 3)
        let threadgroupSize = MTLSize(width: min(perpendicularDistancesPipeline.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputPointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: outputPointer, count: count))
    }

    func findMaxDistance(_ distances: [Float]) -> (maxValue: Float, maxIndex: Int) {
        guard !distances.isEmpty else { return (0, 0) }
        var distancesData = distances
        guard let inputBuffer = device.makeBuffer(bytes: &distancesData,
                                                  length: distances.count * MemoryLayout<Float>.stride,
                                                  options: .storageModeShared),
              let maxValueBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride,
                                                     options: .storageModeShared),
              let maxIndexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride,
                                                     options: .storageModeShared) else {
            let maxValue = distances.max() ?? 0
            let maxIndex = distances.firstIndex(of: maxValue) ?? 0
            return (maxValue, maxIndex)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            let maxValue = distances.max() ?? 0
            let maxIndex = distances.firstIndex(of: maxValue) ?? 0
            return (maxValue, maxIndex)
        }
        encoder.setComputePipelineState(parallelMaxIndexPipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(maxValueBuffer, offset: 0, index: 1)
        encoder.setBuffer(maxIndexBuffer, offset: 0, index: 2)
        let threadgroupSize = min(256, distances.count)
        encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: threadgroupSize, height: 1, depth: 1))
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let maxValue = maxValueBuffer.contents().bindMemory(to: Float.self, capacity: 1).pointee
        let maxIndex = Int(maxIndexBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee)
        return (maxValue, maxIndex)
    }

    func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tValues: [Float]) -> [CGPoint] {
        guard !tValues.isEmpty else { return [] }

        struct CubicCurve {
            var p0: simd_float2
            var p1: simd_float2
            var p2: simd_float2
            var p3: simd_float2
        }
        let count = tValues.count

        var curve = CubicCurve(
            p0: simd_float2(Float(p0.x), Float(p0.y)),
            p1: simd_float2(Float(p1.x), Float(p1.y)),
            p2: simd_float2(Float(p2.x), Float(p2.y)),
            p3: simd_float2(Float(p3.x), Float(p3.y))
        )
        var tData = tValues
        guard let curveBuffer = device.makeBuffer(bytes: &curve,
                                                  length: MemoryLayout<CubicCurve>.stride,
                                                  options: .storageModeShared),
              let tBuffer = device.makeBuffer(bytes: &tData,
                                              length: count * MemoryLayout<Float>.stride,
                                              options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: count * MemoryLayout<simd_float2>.stride,
                                                   options: .storageModeShared) else {
            return []
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return []
        }
        encoder.setComputePipelineState(evaluateBezierPipeline)
        encoder.setBuffer(curveBuffer, offset: 0, index: 0)
        encoder.setBuffer(tBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        let threadgroupSize = MTLSize(width: min(evaluateBezierPipeline.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputPointer = outputBuffer.contents().bindMemory(to: simd_float2.self, capacity: count)
        return (0..<count).map { CGPoint(x: CGFloat(outputPointer[$0].x), y: CGFloat(outputPointer[$0].y)) }
    }

    func batchCheckCollinearity(triplets: [(CGPoint, CGPoint, CGPoint)], tolerance: Float) -> [Bool] {
        guard !triplets.isEmpty else { return [] }
        let count = triplets.count

        var p1Array = triplets.map { simd_float2(Float($0.0.x), Float($0.0.y)) }
        var p2Array = triplets.map { simd_float2(Float($0.1.x), Float($0.1.y)) }
        var p3Array = triplets.map { simd_float2(Float($0.2.x), Float($0.2.y)) }
        var toleranceValue = tolerance
        guard let p1Buffer = device.makeBuffer(bytes: &p1Array,
                                               length: count * MemoryLayout<simd_float2>.stride,
                                               options: .storageModeShared),
              let p2Buffer = device.makeBuffer(bytes: &p2Array,
                                               length: count * MemoryLayout<simd_float2>.stride,
                                               options: .storageModeShared),
              let p3Buffer = device.makeBuffer(bytes: &p3Array,
                                               length: count * MemoryLayout<simd_float2>.stride,
                                               options: .storageModeShared),
              let toleranceBuffer = device.makeBuffer(bytes: &toleranceValue,
                                                      length: MemoryLayout<Float>.stride,
                                                      options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: count * MemoryLayout<Bool>.stride,
                                                   options: .storageModeShared) else {
            return []
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return []
        }
        encoder.setComputePipelineState(collinearityPipeline)
        encoder.setBuffer(p1Buffer, offset: 0, index: 0)
        encoder.setBuffer(p2Buffer, offset: 0, index: 1)
        encoder.setBuffer(p3Buffer, offset: 0, index: 2)
        encoder.setBuffer(outputBuffer, offset: 0, index: 3)
        encoder.setBuffer(toleranceBuffer, offset: 0, index: 4)
        let threadgroupSize = MTLSize(width: min(collinearityPipeline.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputPointer = outputBuffer.contents().bindMemory(to: Bool.self, capacity: count)
        return Array(UnsafeBufferPointer(start: outputPointer, count: count))
    }
}
