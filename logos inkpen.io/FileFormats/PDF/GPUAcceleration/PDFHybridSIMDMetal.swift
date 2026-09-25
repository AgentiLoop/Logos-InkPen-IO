import Foundation
import CoreGraphics
import simd

class PDFHybridProcessor {
    static let shared = PDFHybridProcessor()

    private let simdBatchSize = 4

    private init() {}

    func transformPoints(_ points: [CGPoint], with matrix: PDFSIMDMatrix) -> [CGPoint] {
        return transformPointsSIMD(points, with: matrix)
    }

    private func transformPointsSIMD(_ points: [CGPoint], with matrix: PDFSIMDMatrix) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        var results = [CGPoint]()
        results.reserveCapacity(points.count)
        let stride = simdBatchSize
        let fullBatches = points.count / stride
        for batch in 0..<fullBatches {
            let baseIndex = batch * stride
            let p0 = simd_float3(Float(points[baseIndex + 0].x), Float(points[baseIndex + 0].y), 1.0)
            let p1 = simd_float3(Float(points[baseIndex + 1].x), Float(points[baseIndex + 1].y), 1.0)
            let p2 = simd_float3(Float(points[baseIndex + 2].x), Float(points[baseIndex + 2].y), 1.0)
            let p3 = simd_float3(Float(points[baseIndex + 3].x), Float(points[baseIndex + 3].y), 1.0)
            let t0 = matrix.matrix * p0
            let t1 = matrix.matrix * p1
            let t2 = matrix.matrix * p2
            let t3 = matrix.matrix * p3
            results.append(CGPoint(x: CGFloat(t0.x), y: CGFloat(t0.y)))
            results.append(CGPoint(x: CGFloat(t1.x), y: CGFloat(t1.y)))
            results.append(CGPoint(x: CGFloat(t2.x), y: CGFloat(t2.y)))
            results.append(CGPoint(x: CGFloat(t3.x), y: CGFloat(t3.y)))
        }
        for i in (fullBatches * stride)..<points.count {
            let p = simd_float3(Float(points[i].x), Float(points[i].y), 1.0)
            let t = matrix.matrix * p
            results.append(CGPoint(x: CGFloat(t.x), y: CGFloat(t.y)))
        }
        return results
    }

    func calculateBounds(for shapes: [VectorShape]) -> CGRect? {
        guard !shapes.isEmpty else { return nil }
        return calculateBoundsSIMD(for: shapes)
    }

    private func calculateBoundsSIMD(for shapes: [VectorShape]) -> CGRect {
        return PDFBoundsCalculator.calculateArtworkBounds(from: shapes, pageSize: .zero)
    }

    func batchMultiplyMatrices(_ matrices: [(PDFSIMDMatrix, PDFSIMDMatrix)]) -> [PDFSIMDMatrix] {
        guard !matrices.isEmpty else { return [] }
        return batchMultiplyMatricesSIMD(matrices)
    }

    private func batchMultiplyMatricesSIMD(_ matrices: [(PDFSIMDMatrix, PDFSIMDMatrix)]) -> [PDFSIMDMatrix] {
        var results = [PDFSIMDMatrix]()
        results.reserveCapacity(matrices.count)
        for (m1, m2) in matrices {
            let result = m1.concatenating(m2)
            results.append(result)
        }
        return results
    }

    enum ProcessingMethod {
        case gpu
        case simdCPU
        case standard
    }

    func chooseProcessingMethod(itemCount: Int) -> ProcessingMethod {
        if itemCount >= simdBatchSize {
            return .simdCPU
        }
        return .standard
    }
}

extension simd_float3x3 {

    var metalBufferArray: [Float] {
        return [
            columns.0.x, columns.0.y, columns.0.z,
            columns.1.x, columns.1.y, columns.1.z,
            columns.2.x, columns.2.y, columns.2.z
        ]
    }

    init(metalBuffer: [Float]) {
        precondition(metalBuffer.count >= 9, "Buffer must contain at least 9 floats")
        self.init(
            simd_float3(metalBuffer[0], metalBuffer[1], metalBuffer[2]),
            simd_float3(metalBuffer[3], metalBuffer[4], metalBuffer[5]),
            simd_float3(metalBuffer[6], metalBuffer[7], metalBuffer[8])
        )
    }
}

extension PDFHybridProcessor {

    func processBatches<T, R>(_ items: [T], batchSize: Int = 4, processor: ([T]) -> [R]) -> [R] {
        guard !items.isEmpty else { return [] }
        var results = [R]()
        results.reserveCapacity(items.count)
        var index = 0
        while index < items.count {
            let end = min(index + batchSize, items.count)
            let batch = Array(items[index..<end])
            let batchResults = processor(batch)
            results.append(contentsOf: batchResults)
            index = end
        }
        return results
    }

    func processParallelSIMD<T, R>(_ items: [T], processor: (T) -> R) -> [R] {
        guard !items.isEmpty else { return [] }
        if items.count >= 1000 {
            return items.withUnsafeBufferPointer { buffer in
                let results = UnsafeMutablePointer<R>.allocate(capacity: items.count)
                defer { results.deallocate() }
                DispatchQueue.concurrentPerform(iterations: items.count) { index in
                    results[index] = processor(buffer[index])
                }
                return Array(UnsafeBufferPointer(start: results, count: items.count))
            }
        }
        return items.map(processor)
    }
}
