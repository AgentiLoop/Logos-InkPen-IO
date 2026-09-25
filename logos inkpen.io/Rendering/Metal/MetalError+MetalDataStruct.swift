enum MetalError: Error {
    case libraryCreationFailed
    case deviceNotAvailable
    case commandBufferCreationFailed
    case computeEncoderCreationFailed
    case bufferCreationFailed
    case pipelineNotAvailable
    case operationFailed(String)
}

struct Point2D {
    let x: Float
    let y: Float
}

enum TrigonometricFunction: Int {
    case sine = 0
    case cosine = 1
    case tangent = 2
    case atan2 = 3
}

struct PolygonParams {
    let radius: Float
    let sides: UInt32
    let startAngle: Float
}
