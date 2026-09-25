import MetalKit
import simd

class GPUCoordinateTransform {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue?
    private let computePipeline: MTLComputePipelineState?

    private var isMetalAvailable: Bool = false

    private static var _shared: GPUCoordinateTransform?

    private static let lock = NSLock()

    static var shared: GPUCoordinateTransform {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _shared { return existing }
        let instance = GPUCoordinateTransform()
        _shared = instance
        return instance
    }

    static func releaseShared() {
        lock.lock()
        _shared = nil
        lock.unlock()
    }

    private init() {
        let metal = SharedMetalDevice.shared
        self.device = metal.device
        self.commandQueue = metal.makeCommandQueue()
        self.computePipeline = metal.makePipeline(named: "coordinate_transform")
        self.isMetalAvailable = (computePipeline != nil)
    }

    struct CoordinateTransformParams {
        var offset: SIMD2<Float>
        var zoom: Float
        var isScreenToCanvas: Bool

        init(offset: SIMD2<Float>, zoom: Float, isScreenToCanvas: Bool) {
            self.offset = offset
            self.zoom = zoom
            self.isScreenToCanvas = isScreenToCanvas
        }
    }

    func transformPoints(_ points: [CGPoint], offset: CGPoint, zoom: CGFloat, screenToCanvas: Bool) -> [CGPoint] {
        guard points.count > 100, isMetalAvailable else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }
        return transformPointsGPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
    }

    private func transformPointsCPU(_ points: [CGPoint], offset: CGPoint, zoom: CGFloat, screenToCanvas: Bool) -> [CGPoint] {
        let offsetVec = SIMD2<Float>(Float(offset.x), Float(offset.y))
        let zoomFloat = Float(zoom)
        return points.map { point in
            let pointVec = SIMD2<Float>(Float(point.x), Float(point.y))
            let transformed: SIMD2<Float>
            if screenToCanvas {
                transformed = (pointVec - offsetVec) / zoomFloat
            } else {
                transformed = pointVec * zoomFloat + offsetVec
            }
            return CGPoint(x: CGFloat(transformed.x), y: CGFloat(transformed.y))
        }
    }

    private func transformPointsGPU(_ points: [CGPoint], offset: CGPoint, zoom: CGFloat, screenToCanvas: Bool) -> [CGPoint] {
        guard let commandQueue = commandQueue,

              let pipeline = computePipeline else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }
        let inputData = points.map { SIMD2<Float>(Float($0.x), Float($0.y)) }
        let dataSize = inputData.count * MemoryLayout<SIMD2<Float>>.stride
        guard let inputBuffer = device.makeBuffer(bytes: inputData, length: dataSize, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: dataSize, options: .storageModeShared) else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }
        var params = CoordinateTransformParams(
            offset: SIMD2<Float>(Float(offset.x), Float(offset.y)),
            zoom: Float(zoom),
            isScreenToCanvas: screenToCanvas
        )
        guard let paramsBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<CoordinateTransformParams>.stride, options: .storageModeShared) else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return transformPointsCPU(points, offset: offset, zoom: zoom, screenToCanvas: screenToCanvas)
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        let threadGroupSize = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, points.count), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (points.count + threadGroupSize.width - 1) / threadGroupSize.width,
            height: 1,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: points.count)
        return (0..<points.count).map { i in
            let result = resultPointer[i]
            return CGPoint(x: CGFloat(result.x), y: CGFloat(result.y))
        }
    }

    var isGPUAvailable: Bool {
        return isMetalAvailable
    }

    func getDeviceInfo() -> String {
        if isMetalAvailable {
            return "GPU Transform: \(device.name)"
        } else {
            return "GPU Transform: CPU SIMD Fallback"
        }
    }
}
