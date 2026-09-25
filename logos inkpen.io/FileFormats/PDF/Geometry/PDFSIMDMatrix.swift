import Foundation
import CoreGraphics
import Metal
import simd

struct PDFSIMDMatrix {
    var matrix: simd_float3x3

    init() {
        self.matrix = matrix_identity_float3x3
    }

    init(_ transform: CGAffineTransform) {
        self.matrix = simd_float3x3(
            simd_float3(Float(transform.a), Float(transform.b), 0),
            simd_float3(Float(transform.c), Float(transform.d), 0),
            simd_float3(Float(transform.tx), Float(transform.ty), 1)
        )
    }

    init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.matrix = simd_float3x3(
            simd_float3(Float(a), Float(b), 0),
            simd_float3(Float(c), Float(d), 0),
            simd_float3(Float(tx), Float(ty), 1)
        )
    }

    var cgAffineTransform: CGAffineTransform {
        return CGAffineTransform(
            a: CGFloat(matrix[0][0]),
            b: CGFloat(matrix[0][1]),
            c: CGFloat(matrix[1][0]),
            d: CGFloat(matrix[1][1]),
            tx: CGFloat(matrix[2][0]),
            ty: CGFloat(matrix[2][1])
        )
    }

    var tx: CGFloat {
        get { CGFloat(matrix[2][0]) }
        set { matrix[2][0] = Float(newValue) }
    }

    var ty: CGFloat {
        get { CGFloat(matrix[2][1]) }
        set { matrix[2][1] = Float(newValue) }
    }

    var a: CGFloat {
        get { CGFloat(matrix[0][0]) }
        set { matrix[0][0] = Float(newValue) }
    }

    var b: CGFloat {
        get { CGFloat(matrix[0][1]) }
        set { matrix[0][1] = Float(newValue) }
    }

    var c: CGFloat {
        get { CGFloat(matrix[1][0]) }
        set { matrix[1][0] = Float(newValue) }
    }

    var d: CGFloat {
        get { CGFloat(matrix[1][1]) }
        set { matrix[1][1] = Float(newValue) }
    }

    var metalBufferArray: [Float] {
        return [
            matrix[0][0], matrix[0][1], matrix[0][2],
            matrix[1][0], matrix[1][1], matrix[1][2],
            matrix[2][0], matrix[2][1], matrix[2][2]
        ]
    }

    init(metalBuffer: [Float]) {
        precondition(metalBuffer.count >= 9, "Metal buffer must contain at least 9 floats for 3x3 matrix")
        self.matrix = simd_float3x3(
            simd_float3(metalBuffer[0], metalBuffer[1], metalBuffer[2]),
            simd_float3(metalBuffer[3], metalBuffer[4], metalBuffer[5]),
            simd_float3(metalBuffer[6], metalBuffer[7], metalBuffer[8])
        )
    }

    func createMetalBuffer(device: MTLDevice) -> MTLBuffer? {
        let array = metalBufferArray
        return device.makeBuffer(bytes: array,
                                length: array.count * MemoryLayout<Float>.size,
                                options: .storageModeShared)
    }

    mutating func concatenate(_ other: PDFSIMDMatrix) {
        self.matrix = self.matrix * other.matrix
    }

    func concatenating(_ other: PDFSIMDMatrix) -> PDFSIMDMatrix {
        var result = self
        result.concatenate(other)
        return result
    }

    func transform(point: CGPoint) -> CGPoint {
        let p = simd_float3(Float(point.x), Float(point.y), 1.0)
        let transformed = matrix * p
        return CGPoint(
            x: CGFloat(transformed.x),
            y: CGFloat(transformed.y)
        )
    }

    func transformPoints(_ points: [CGPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        return PDFMetalAccelerator.shared.transformPoints(points, with: self)
    }

    func inverted() -> PDFSIMDMatrix? {
        let det = simd_determinant(matrix)
        guard abs(det) > 1e-6 else { return nil }
        var result = PDFSIMDMatrix()
        result.matrix = simd_inverse(matrix)
        return result
    }

    static func translation(tx: CGFloat, ty: CGFloat) -> PDFSIMDMatrix {
        var m = PDFSIMDMatrix()
        m.matrix[2][0] = Float(tx)
        m.matrix[2][1] = Float(ty)
        return m
    }

    static func scale(sx: CGFloat, sy: CGFloat) -> PDFSIMDMatrix {
        var m = PDFSIMDMatrix()
        m.matrix[0][0] = Float(sx)
        m.matrix[1][1] = Float(sy)
        return m
    }

    static func rotation(angle: CGFloat) -> PDFSIMDMatrix {
        let cos = Float(Foundation.cos(angle))
        let sin = Float(Foundation.sin(angle))

        var m = PDFSIMDMatrix()
        m.matrix[0][0] = cos
        m.matrix[0][1] = sin
        m.matrix[1][0] = -sin
        m.matrix[1][1] = cos
        return m
    }
}

extension PDFSIMDMatrix {

    static func batchConcatenate(_ matrices: [PDFSIMDMatrix]) -> PDFSIMDMatrix {
        guard !matrices.isEmpty else { return PDFSIMDMatrix() }
        guard matrices.count > 1 else { return matrices[0] }
        var pairs = [(PDFSIMDMatrix, PDFSIMDMatrix)]()

        let result = matrices[0]
        for i in 1..<matrices.count {
            pairs.append((result, matrices[i]))
        }
        if !pairs.isEmpty {
            let results = PDFMetalAccelerator.shared.multiplyMatrices(pairs)
            return results.last ?? result
        }
        return result
    }

    static func precomputeTextMatrix(fontSize: CGFloat, horizontalScaling: CGFloat) -> PDFSIMDMatrix {
        return PDFSIMDMatrix.scale(sx: fontSize * horizontalScaling / 100.0, sy: fontSize)
    }

    static func textMatrix(fontSize: CGFloat, horizontalScaling: CGFloat, tx: CGFloat, ty: CGFloat) -> PDFSIMDMatrix {
        let scaleX = fontSize * horizontalScaling / 100.0
        let scaleY = fontSize

        var m = PDFSIMDMatrix()
        m.matrix[0][0] = Float(scaleX)
        m.matrix[1][1] = Float(scaleY)
        m.matrix[2][0] = Float(tx)
        m.matrix[2][1] = Float(ty)
        return m
    }

    static func batchTransformTextPositions(positions: [(x: CGFloat, y: CGFloat)],
                                            fontSize: CGFloat,
                                            horizontalScaling: CGFloat,
                                            baseTransform: PDFSIMDMatrix) -> [CGPoint] {
        guard !positions.isEmpty else { return [] }
        let textScale = PDFSIMDMatrix.scale(sx: fontSize * horizontalScaling / 100.0, sy: fontSize)
        let combinedTransform = baseTransform.concatenating(textScale)
        let points = positions.map { CGPoint(x: $0.x, y: $0.y) }
        return PDFMetalAccelerator.shared.transformPoints(points, with: combinedTransform)
    }
}
