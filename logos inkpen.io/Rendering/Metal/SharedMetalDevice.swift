import Metal

final class SharedMetalDevice {
    static let shared = SharedMetalDevice()

    let device: MTLDevice
    let library: MTLLibrary

    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal GPU not available")
        }
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal default library")
        }
        self.device = device
        self.library = library
    }

    func makeCommandQueue() -> MTLCommandQueue? {
        device.makeCommandQueue()
    }

    func makePipeline(named functionName: String) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: functionName) else { return nil }
        return try? device.makeComputePipelineState(function: function)
    }

    static func releaseAll() {
        MetalComputeEngine.releaseShared()
        PDFMetalAccelerator.releaseShared()
        PDFMetalProcessor.releaseShared()
        MetalImageTileRenderer.releaseShared()
        GPUCoordinateTransform.releaseShared()
        MetalSpatialIndex.releaseSharedPipelines()
    }
}
