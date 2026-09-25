import MetalKit
import Combine

class MetalDeviceManager: ObservableObject {

    @Published var device: MTLDevice
    @Published var commandQueue: MTLCommandQueue
    init() {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("❌ Metal GPU not available. This application requires Metal GPU support.")
        }
        guard let cmdQueue = metalDevice.makeCommandQueue() else {
            fatalError("❌ Failed to create Metal command queue. GPU may be unavailable.")
        }
        self.device = metalDevice
        self.commandQueue = cmdQueue
    }

    func executeRenderCommand<T>(_ command: (MTLDevice, MTLCommandQueue) -> T) -> T {
        return command(device, commandQueue)
    }

    func validateMetalSupport() -> Bool {
        return true
    }
}
