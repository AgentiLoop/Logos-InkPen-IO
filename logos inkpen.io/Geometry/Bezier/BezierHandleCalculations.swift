import CoreGraphics
import Foundation
import simd

func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
    let metalEngine = MetalComputeEngine.shared
    let results = metalEngine.calculateLinkedHandlesGPU(
        anchorPoints: [anchorPoint],
        draggedHandles: [draggedHandle],
        originalOppositeHandles: [originalOppositeHandle]
    )
    switch results {
    case .success(let linkedHandles):
        if let result = linkedHandles.first {
            return result
        }
    case .failure:
        break
    }
    return calculateLinkedHandleCPU(anchorPoint: anchorPoint, draggedHandle: draggedHandle, originalOppositeHandle: originalOppositeHandle)
}

private func calculateLinkedHandleCPU(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
    let anchorVec = SIMD2<Double>(Double(anchorPoint.x), Double(anchorPoint.y))
    let draggedVec = SIMD2<Double>(Double(draggedHandle.x), Double(draggedHandle.y))
    let originalVec = SIMD2<Double>(Double(originalOppositeHandle.x), Double(originalOppositeHandle.y))
    let draggedVector = draggedVec - anchorVec
    let originalVector = originalVec - anchorVec
    let originalLength = simd_length(originalVector)
    let draggedLength = simd_length(draggedVector)
    guard draggedLength > 0.1 else { return originalOppositeHandle }
    let normalizedDragged = simd_normalize(draggedVector)
    let linkedHandleVec = anchorVec - normalizedDragged * originalLength
    return CGPoint(x: linkedHandleVec.x, y: linkedHandleVec.y)
}
