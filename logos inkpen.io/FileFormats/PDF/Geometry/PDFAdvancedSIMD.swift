import Foundation
import CoreGraphics
import simd
import Accelerate

struct PDFAdvancedSIMD {

    static func calculatePathBounds(points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        let count = points.count

        var xValues = [Float](repeating: 0, count: count)
        var yValues = [Float](repeating: 0, count: count)
        for (i, point) in points.enumerated() {
            xValues[i] = Float(point.x)
            yValues[i] = Float(point.y)
        }
        var minX: Float = 0
        var maxX: Float = 0
        var minY: Float = 0
        var maxY: Float = 0
        vDSP_minv(xValues, 1, &minX, vDSP_Length(count))
        vDSP_maxv(xValues, 1, &maxX, vDSP_Length(count))
        vDSP_minv(yValues, 1, &minY, vDSP_Length(count))
        vDSP_maxv(yValues, 1, &maxY, vDSP_Length(count))
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
    }

    static func batchCalculateDistances(from origin: CGPoint, to points: [CGPoint]) -> [CGFloat] {
        guard !points.isEmpty else { return [] }
        let count = points.count

        var xDiffs = [Float](repeating: 0, count: count)
        var yDiffs = [Float](repeating: 0, count: count)
        var distances = [Float](repeating: 0, count: count)

        let originX = Float(origin.x)
        let originY = Float(origin.y)
        for (i, point) in points.enumerated() {
            xDiffs[i] = Float(point.x) - originX
            yDiffs[i] = Float(point.y) - originY
        }
        var xSquared = [Float](repeating: 0, count: count)
        var ySquared = [Float](repeating: 0, count: count)
        vDSP_vsq(xDiffs, 1, &xSquared, 1, vDSP_Length(count))
        vDSP_vsq(yDiffs, 1, &ySquared, 1, vDSP_Length(count))
        var sumSquares = [Float](repeating: 0, count: count)
        vDSP_vadd(xSquared, 1, ySquared, 1, &sumSquares, 1, vDSP_Length(count))
        var countInt32 = Int32(count)
        vvsqrtf(&distances, sumSquares, &countInt32)
        return distances.map { CGFloat($0) }
    }

    static func batchApplyTransform(_ transform: CGAffineTransform, to points: [CGPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        let count = points.count

        var results = [CGPoint](repeating: .zero, count: count)

        let a = Float(transform.a)
        let b = Float(transform.b)
        let c = Float(transform.c)
        let d = Float(transform.d)
        let tx = Float(transform.tx)
        let ty = Float(transform.ty)
        let stride = 4
        let fullBatches = count / stride
        for batch in 0..<fullBatches {
            let baseIndex = batch * stride
            let p0 = simd_float2(Float(points[baseIndex + 0].x), Float(points[baseIndex + 0].y))
            let p1 = simd_float2(Float(points[baseIndex + 1].x), Float(points[baseIndex + 1].y))
            let p2 = simd_float2(Float(points[baseIndex + 2].x), Float(points[baseIndex + 2].y))
            let p3 = simd_float2(Float(points[baseIndex + 3].x), Float(points[baseIndex + 3].y))
            let t0 = simd_float2(a * p0.x + c * p0.y + tx, b * p0.x + d * p0.y + ty)
            let t1 = simd_float2(a * p1.x + c * p1.y + tx, b * p1.x + d * p1.y + ty)
            let t2 = simd_float2(a * p2.x + c * p2.y + tx, b * p2.x + d * p2.y + ty)
            let t3 = simd_float2(a * p3.x + c * p3.y + tx, b * p3.x + d * p3.y + ty)
            results[baseIndex + 0] = CGPoint(x: CGFloat(t0.x), y: CGFloat(t0.y))
            results[baseIndex + 1] = CGPoint(x: CGFloat(t1.x), y: CGFloat(t1.y))
            results[baseIndex + 2] = CGPoint(x: CGFloat(t2.x), y: CGFloat(t2.y))
            results[baseIndex + 3] = CGPoint(x: CGFloat(t3.x), y: CGFloat(t3.y))
        }
        for i in (fullBatches * stride)..<count {
            let p = points[i]
            let x = a * Float(p.x) + c * Float(p.y) + tx
            let y = b * Float(p.x) + d * Float(p.y) + ty
            results[i] = CGPoint(x: CGFloat(x), y: CGFloat(y))
        }
        return results
    }

    static func batchInterpolate(from start: CGPoint, to end: CGPoint, steps: Int) -> [CGPoint] {
        guard steps > 0 else { return [] }
        var results = [CGPoint](repeating: .zero, count: steps)

        let startVec = simd_float2(Float(start.x), Float(start.y))
        let endVec = simd_float2(Float(end.x), Float(end.y))
        let delta = endVec - startVec
        let stride = 4
        let fullBatches = steps / stride
        for batch in 0..<fullBatches {
            let baseIndex = batch * stride
            let t0 = Float(baseIndex + 0) / Float(steps - 1)
            let t1 = Float(baseIndex + 1) / Float(steps - 1)
            let t2 = Float(baseIndex + 2) / Float(steps - 1)
            let t3 = Float(baseIndex + 3) / Float(steps - 1)
            let p0 = startVec + t0 * delta
            let p1 = startVec + t1 * delta
            let p2 = startVec + t2 * delta
            let p3 = startVec + t3 * delta
            results[baseIndex + 0] = CGPoint(x: CGFloat(p0.x), y: CGFloat(p0.y))
            results[baseIndex + 1] = CGPoint(x: CGFloat(p1.x), y: CGFloat(p1.y))
            results[baseIndex + 2] = CGPoint(x: CGFloat(p2.x), y: CGFloat(p2.y))
            results[baseIndex + 3] = CGPoint(x: CGFloat(p3.x), y: CGFloat(p3.y))
        }
        for i in (fullBatches * stride)..<steps {
            let t = Float(i) / Float(steps - 1)
            let p = startVec + t * delta
            results[i] = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        }
        return results
    }

    static func evaluateCubicBezier(
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        tValues: [Float]
    ) -> [CGPoint] {
        guard !tValues.isEmpty else { return [] }
        var results = [CGPoint](repeating: .zero, count: tValues.count)

        let p0Vec = simd_float2(Float(p0.x), Float(p0.y))
        let p1Vec = simd_float2(Float(p1.x), Float(p1.y))
        let p2Vec = simd_float2(Float(p2.x), Float(p2.y))
        let p3Vec = simd_float2(Float(p3.x), Float(p3.y))
        for (i, t) in tValues.enumerated() {
            let oneMinusT = 1.0 - t
            let oneMinusT2 = oneMinusT * oneMinusT
            let oneMinusT3 = oneMinusT2 * oneMinusT
            let t2 = t * t
            let t3 = t2 * t
            let point = oneMinusT3 * p0Vec +
                       3.0 * oneMinusT2 * t * p1Vec +
                       3.0 * oneMinusT * t2 * p2Vec +
                       t3 * p3Vec
            results[i] = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
        }
        return results
    }

    static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count, "Arrays must have same length")
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }

    static func vectorAdd(_ a: [Float], _ b: [Float]) -> [Float] {
        precondition(a.count == b.count, "Arrays must have same length")
        var result = [Float](repeating: 0, count: a.count)
        vDSP_vadd(a, 1, b, 1, &result, 1, vDSP_Length(a.count))
        return result
    }

    static func vectorMultiply(_ a: [Float], _ b: [Float]) -> [Float] {
        precondition(a.count == b.count, "Arrays must have same length")
        var result = [Float](repeating: 0, count: a.count)
        vDSP_vmul(a, 1, b, 1, &result, 1, vDSP_Length(a.count))
        return result
    }

    static func scalarMultiply(_ vector: [Float], by scalar: Float) -> [Float] {
        var result = [Float](repeating: 0, count: vector.count)
        var scalarCopy = scalar
        vDSP_vsmul(vector, 1, &scalarCopy, &result, 1, vDSP_Length(vector.count))
        return result
    }

    static func cacheOptimizedTransform(
        points: [CGPoint],
        transform: (CGPoint) -> CGPoint
    ) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        let cacheOptimalBatchSize = 1024

        var results = [CGPoint](repeating: .zero, count: points.count)
        var index = 0
        while index < points.count {
            let endIndex = min(index + cacheOptimalBatchSize, points.count)
            for i in index..<endIndex {
                results[i] = transform(points[i])
            }
            index = endIndex
        }
        return results
    }

    static func batchRectIntersections(rect: CGRect, testRects: [CGRect]) -> [Bool] {
        guard !testRects.isEmpty else { return [] }
        var results = [Bool](repeating: false, count: testRects.count)

        let rectMin = simd_float2(Float(rect.minX), Float(rect.minY))
        let rectMax = simd_float2(Float(rect.maxX), Float(rect.maxY))
        let stride = 4
        let fullBatches = testRects.count / stride
        for batch in 0..<fullBatches {
            let baseIndex = batch * stride
            for i in 0..<4 {
                let testRect = testRects[baseIndex + i]
                let testMin = simd_float2(Float(testRect.minX), Float(testRect.minY))
                let testMax = simd_float2(Float(testRect.maxX), Float(testRect.maxY))
                let intersects = rectMin.x <= testMax.x &&
                                rectMax.x >= testMin.x &&
                                rectMin.y <= testMax.y &&
                                rectMax.y >= testMin.y
                results[baseIndex + i] = intersects
            }
        }
        for i in (fullBatches * stride)..<testRects.count {
            results[i] = rect.intersects(testRects[i])
        }
        return results
    }

    static func parallelSIMDProcess(
        points: [CGPoint],
        processor: ([CGPoint]) -> [CGPoint]
    ) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        if points.count >= 10000 {
            let coreCount = ProcessInfo.processInfo.processorCount
            let batchSize = (points.count + coreCount - 1) / coreCount

            var results = [CGPoint](repeating: .zero, count: points.count)
            results.withUnsafeMutableBufferPointer { buffer in
                DispatchQueue.concurrentPerform(iterations: coreCount) { coreIndex in
                    let startIndex = coreIndex * batchSize
                    guard startIndex < points.count else { return }
                    let endIndex = min(startIndex + batchSize, points.count)
                    let batch = Array(points[startIndex..<endIndex])
                    let processed = processor(batch)
                    for (i, point) in processed.enumerated() {
                        buffer[startIndex + i] = point
                    }
                }
            }
            return results
        }
        return processor(points)
    }
}
