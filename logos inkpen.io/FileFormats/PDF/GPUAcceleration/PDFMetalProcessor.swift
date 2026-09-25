import Foundation
import Metal

class PDFMetalProcessor {
    private static var _shared: PDFMetalProcessor?

    private static let lock = NSLock()

    static var shared: PDFMetalProcessor {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _shared { return existing }
        let instance = PDFMetalProcessor()
        _shared = instance
        return instance
    }

    static func releaseShared() {
        lock.lock()
        _shared = nil
        lock.unlock()
    }
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var rgbToRGBAPipeline: MTLComputePipelineState?
    private var indexedToRGBAPipeline: MTLComputePipelineState?
    private var extractGradientColorsPipeline: MTLComputePipelineState?
    private var isInitialized: Bool = false

    private init() {
        setupMetal()
    }

    private func setupMetal() {
        let metal = SharedMetalDevice.shared
        self.device = metal.device
        self.commandQueue = metal.makeCommandQueue()
        do {
            if let rgbToRGBAFunction = metal.library.makeFunction(name: "rgbToRGBA") {
                rgbToRGBAPipeline = try metal.device.makeComputePipelineState(function: rgbToRGBAFunction)
            }
            if let indexedToRGBAFunction = metal.library.makeFunction(name: "indexedToRGBA") {
                indexedToRGBAPipeline = try metal.device.makeComputePipelineState(function: indexedToRGBAFunction)
            }
            if let extractGradientFunction = metal.library.makeFunction(name: "extractGradientColors8Bit") {
                extractGradientColorsPipeline = try metal.device.makeComputePipelineState(function: extractGradientFunction)
            }
            isInitialized = true
        } catch {
            Log.error("❌ Failed to create Metal compute pipelines: \(error)", category: .error)
        }
    }

    func convertRGBtoRGBA(rgbData: Data, maskData: Data?, width: Int, height: Int) -> Data? {
        guard isInitialized,
              let device = device,
              let commandQueue = commandQueue,

              let pipeline = rgbToRGBAPipeline else {
            Log.warning("⚠️ Metal not available, falling back to CPU for RGB->RGBA conversion", category: .general)
            return nil
        }
        let pixelCount = width * height
        let rgbSize = pixelCount * 3
        let rgbaSize = pixelCount * 4
        let rgbBuffer: MTLBuffer? = rgbData.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: rgbSize, options: .storageModeShared)
        }
        guard let rgbBuffer,
              let rgbaBuffer = device.makeBuffer(length: rgbaSize,
                                                  options: .storageModeShared) else {
            Log.error("❌ Failed to allocate Metal buffers for image conversion", category: .error)
            return nil
        }
        var maskBuffer: MTLBuffer?
        var hasMaskValue: UInt32 = 0
        if let mask = maskData {
            maskBuffer = mask.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return nil }
                return device.makeBuffer(bytes: base, length: pixelCount, options: .storageModeShared)
            }
            hasMaskValue = 1
        }
        let hasMaskBuffer = device.makeBuffer(bytes: &hasMaskValue,
                                              length: MemoryLayout<UInt32>.size,
                                              options: .storageModeShared)
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(rgbBuffer, offset: 0, index: 0)
        encoder.setBuffer(maskBuffer ?? rgbBuffer, offset: 0, index: 1)
        encoder.setBuffer(rgbaBuffer, offset: 0, index: 2)
        encoder.setBuffer(hasMaskBuffer, offset: 0, index: 3)
        let threadGroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (pixelCount + pipeline.threadExecutionWidth - 1) / pipeline.threadExecutionWidth,
                                  height: 1,
                                  depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultData = Data(bytes: rgbaBuffer.contents(), count: rgbaSize)
        return resultData
    }

    func convertIndexedToRGBA(indexData: Data, paletteData: Data, maskData: Data?, width: Int, height: Int) -> Data? {
        guard isInitialized,
              let device = device,
              let commandQueue = commandQueue,

              let pipeline = indexedToRGBAPipeline else {
            Log.warning("⚠️ Metal not available, falling back to CPU for indexed->RGBA conversion", category: .general)
            return nil
        }
        let pixelCount = width * height
        let rgbaSize = pixelCount * 4
        let paletteEntries = paletteData.count / 3
        let indexBuffer: MTLBuffer? = indexData.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: pixelCount, options: .storageModeShared)
        }
        let paletteBuffer: MTLBuffer? = paletteData.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: paletteData.count, options: .storageModeShared)
        }
        guard let indexBuffer,
              let paletteBuffer,
              let rgbaBuffer = device.makeBuffer(length: rgbaSize,
                                                  options: .storageModeShared) else {
            return nil
        }
        var maskBuffer: MTLBuffer?
        var hasMaskValue: UInt32 = 0
        if let mask = maskData {
            maskBuffer = mask.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return nil }
                return device.makeBuffer(bytes: base, length: pixelCount, options: .storageModeShared)
            }
            hasMaskValue = 1
        }
        var paletteEntriesValue = UInt32(paletteEntries)

        let paletteEntriesBuffer = device.makeBuffer(bytes: &paletteEntriesValue,
                                                      length: MemoryLayout<UInt32>.size,
                                                      options: .storageModeShared)
        let hasMaskBuffer = device.makeBuffer(bytes: &hasMaskValue,
                                              length: MemoryLayout<UInt32>.size,
                                              options: .storageModeShared)
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(indexBuffer, offset: 0, index: 0)
        encoder.setBuffer(paletteBuffer, offset: 0, index: 1)
        encoder.setBuffer(maskBuffer ?? indexBuffer, offset: 0, index: 2)
        encoder.setBuffer(rgbaBuffer, offset: 0, index: 3)
        encoder.setBuffer(paletteEntriesBuffer, offset: 0, index: 4)
        encoder.setBuffer(hasMaskBuffer, offset: 0, index: 5)
        let threadGroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (pixelCount + pipeline.threadExecutionWidth - 1) / pipeline.threadExecutionWidth,
                                  height: 1,
                                  depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultData = Data(bytes: rgbaBuffer.contents(), count: rgbaSize)
        return resultData
    }

    func extractGradientColors(sampleData: Data,
                              totalSamples: Int,
                              outputComponents: Int,
                              rangeMin: [Float],
                              rangeMax: [Float]) -> [VectorColor]? {
        guard isInitialized,
              let device = device,
              let commandQueue = commandQueue,

              let pipeline = extractGradientColorsPipeline else {
            Log.warning("⚠️ Metal not available, falling back to CPU for gradient extraction", category: .general)
            return nil
        }
        let maxSamples = 1024
        let actualSamples = min(totalSamples, maxSamples)
        let outputSize = actualSamples * 3 * MemoryLayout<Float>.size
        let sampleBuffer: MTLBuffer? = sampleData.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: sampleData.count, options: .storageModeShared)
        }
        guard let sampleBuffer,
              let colorBuffer = device.makeBuffer(length: outputSize,
                                                  options: .storageModeShared),
              let rangeMinBuffer = device.makeBuffer(bytes: rangeMin,
                                                      length: rangeMin.count * MemoryLayout<Float>.size,
                                                      options: .storageModeShared),
              let rangeMaxBuffer = device.makeBuffer(bytes: rangeMax,
                                                      length: rangeMax.count * MemoryLayout<Float>.size,
                                                      options: .storageModeShared) else {
            return nil
        }
        var outputComponentsValue = UInt32(outputComponents)

        let componentsBuffer = device.makeBuffer(bytes: &outputComponentsValue,
                                                 length: MemoryLayout<UInt32>.size,
                                                 options: .storageModeShared)
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sampleBuffer, offset: 0, index: 0)
        encoder.setBuffer(colorBuffer, offset: 0, index: 1)
        encoder.setBuffer(componentsBuffer, offset: 0, index: 2)
        encoder.setBuffer(rangeMinBuffer, offset: 0, index: 3)
        encoder.setBuffer(rangeMaxBuffer, offset: 0, index: 4)
        let threadGroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (actualSamples + pipeline.threadExecutionWidth - 1) / pipeline.threadExecutionWidth,
                                  height: 1,
                                  depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let floatPointer = colorBuffer.contents().assumingMemoryBound(to: Float.self)

        var colors: [VectorColor] = []
        colors.reserveCapacity(actualSamples)
        for i in 0..<actualSamples {
            let r = Double(floatPointer[i * 3 + 0])
            let g = Double(floatPointer[i * 3 + 1])
            let b = Double(floatPointer[i * 3 + 2])
            colors.append(.rgb(RGBColor(red: r, green: g, blue: b)))
        }
        return colors
    }
}
