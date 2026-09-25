import MetalKit

class MetalComputeEngine {
    let device: MTLDevice

    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    private var douglasPeuckerPipeline: MTLComputePipelineState?
    private var bezierCalculationPipeline: MTLComputePipelineState?
    private var matrixTransformPipeline: MTLComputePipelineState?
    private var collisionDetectionPipeline: MTLComputePipelineState?
    private var pathRenderingPipeline: MTLComputePipelineState?
    private var vectorDistancePipeline: MTLComputePipelineState?
    private var vectorNormalizePipeline: MTLComputePipelineState?
    private var vectorLerpPipeline: MTLComputePipelineState?
    private var handleCalculationPipeline: MTLComputePipelineState?
    private var curvatureCalculationPipeline: MTLComputePipelineState?
    private var chaikinSmoothingPipeline: MTLComputePipelineState?
    private var distanceCalculationPipeline: MTLComputePipelineState?
    private var squareRootPipeline: MTLComputePipelineState?
    private var trigonometricPipeline: MTLComputePipelineState?
    private var polygonCalculationPipeline: MTLComputePipelineState?
    private var booleanGeometryPipeline: MTLComputePipelineState?
    private var pathIntersectionPipeline: MTLComputePipelineState?
    private var findNearestPointPipeline: MTLComputePipelineState?
    private var findMinDistanceIndexPipeline: MTLComputePipelineState?
    private var findPointsInRadiusPipeline: MTLComputePipelineState?
    private var findNearestHandlePipeline: MTLComputePipelineState?
    private var pathHitTestPipeline: MTLComputePipelineState?
    private var findNearestSnapPointPipeline: MTLComputePipelineState?
    private var removeCoincidentPointsPipeline: MTLComputePipelineState?
    private var smoothBrushStrokePipeline: MTLComputePipelineState?

    private static var _shared: MetalComputeEngine?

    private static let lock = NSLock()

    static var shared: MetalComputeEngine {
        lock.lock()
        defer { lock.unlock() }
        if let existing = _shared { return existing }
        let instance = try! MetalComputeEngine()
        _shared = instance
        return instance
    }

    static func releaseShared() {
        lock.lock()
        _shared = nil
        lock.unlock()
    }

    private init() throws {
        let metal = SharedMetalDevice.shared
        self.device = metal.device
        self.library = metal.library
        guard let commandQueue = metal.makeCommandQueue() else {
            throw MetalError.commandBufferCreationFailed
        }
        self.commandQueue = commandQueue
        try setupComputePipelines()
    }

    private func setupComputePipelines() throws {
        if let function = library.makeFunction(name: "calculate_distances") {
            douglasPeuckerPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_bezier_curves") {
            bezierCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "transform_points") {
            matrixTransformPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "point_in_polygon") {
            collisionDetectionPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "render_path_points") {
            pathRenderingPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_vector_distances") {
            vectorDistancePipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "normalize_vectors") {
            vectorNormalizePipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "lerp_vectors") {
            vectorLerpPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_linked_handles") {
            handleCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_curvature") {
            curvatureCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "chaikin_smoothing") {
            chaikinSmoothingPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_point_distance") {
            distanceCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_square_roots") {
            squareRootPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_trigonometric") {
            trigonometricPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "calculate_polygon_points") {
            polygonCalculationPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "boolean_geometry_union") {
            booleanGeometryPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "path_intersection_calculation") {
            pathIntersectionPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "find_nearest_point") {
            findNearestPointPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "find_min_distance_index") {
            findMinDistanceIndexPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "find_points_in_radius") {
            findPointsInRadiusPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "find_nearest_handle") {
            findNearestHandlePipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "path_hit_test") {
            pathHitTestPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "find_nearest_snap_point") {
            findNearestSnapPointPipeline = try device.makeComputePipelineState(function: function)
        }
            if let function = library.makeFunction(name: "remove_coincident_points") {
            removeCoincidentPointsPipeline = try device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "smooth_brush_stroke") {
            smoothBrushStrokePipeline = try device.makeComputePipelineState(function: function)
        }
    }

    func douglasPeuckerGPU(_ points: [CGPoint], tolerance: Float) -> Result<[CGPoint], MetalError> {
        guard points.count > 2 else {
            return .failure(.operationFailed("Need at least 3 points for Douglas-Peucker simplification"))
        }
        guard douglasPeuckerPipeline != nil else {
            return .failure(.pipelineNotAvailable)
        }
        let result = douglasPeuckerRecursiveGPU(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
        return .success(result)
    }

    private func douglasPeuckerRecursiveGPU(points: [CGPoint], tolerance: Float, startIndex: Int, endIndex: Int) -> [CGPoint] {
        guard endIndex - startIndex > 1 else {
            return [points[startIndex], points[endIndex]]
        }
        let segmentPoints = Array(points[startIndex...endIndex])
        let lineStart = points[startIndex]
        let lineEnd = points[endIndex]
        let maxResult = findMaxDistanceGPU(points: segmentPoints, lineStart: lineStart, lineEnd: lineEnd)
        switch maxResult {
        case .success(let result):
            if result.distance > tolerance {
                let maxIndex = startIndex + result.index
            let leftSegment = douglasPeuckerRecursiveGPU(
                points: points, tolerance: tolerance,
                startIndex: startIndex, endIndex: maxIndex
            )
            let rightSegment = douglasPeuckerRecursiveGPU(
                points: points, tolerance: tolerance,
                startIndex: maxIndex, endIndex: endIndex
            )
                            return leftSegment + Array(rightSegment.dropFirst())
            } else {
                return [points[startIndex], points[endIndex]]
            }
        case .failure(_):
            return [points[startIndex], points[endIndex]]
        }
    }

    private func findMaxDistanceGPU(points: [CGPoint], lineStart: CGPoint, lineEnd: CGPoint) -> Result<(distance: Float, index: Int), MetalError> {
        guard let pipeline = douglasPeuckerPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let pointCount = points.count
        guard pointCount > 0 else {
            return .failure(.operationFailed("No points provided"))
        }
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        guard let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: bufferOptions),

              let distancesBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: bufferOptions) else {
            return .failure(.bufferCreationFailed)
        }
        var lineStartMetal = Point2D(x: Float(lineStart.x), y: Float(lineStart.y))
        var lineEndMetal = Point2D(x: Float(lineEnd.x), y: Float(lineEnd.y))
        var pointCountUInt = UInt32(pointCount)
        var zeroUInt: UInt32 = 0
        guard let maxIndexBuffer = device.makeBuffer(bytes: &zeroUInt, length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&lineStartMetal, length: MemoryLayout<Point2D>.stride, index: 1)
        computeEncoder.setBytes(&lineEndMetal, length: MemoryLayout<Point2D>.stride, index: 2)
        computeEncoder.setBuffer(distancesBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(maxIndexBuffer, offset: 0, index: 4)
        computeEncoder.setBytes(&pointCountUInt, length: MemoryLayout<UInt32>.stride, index: 5)
        let tpw = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, pointCount))
        let threadsPerGroup = MTLSize(width: tpw, height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + tpw - 1) / tpw, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let distancesPointer = distancesBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)

        var maxDistance: Float = 0
        var maxIndex = 0
        for i in 0..<pointCount {
            let distance = distancesPointer[i]
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        return .success((distance: maxDistance, index: maxIndex))
    }

    func transformPointsGPU(_ points: [CGPoint], transform: CGAffineTransform) -> Result<[CGPoint], MetalError> {
        guard let pipeline = matrixTransformPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let pointCount = points.count
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let transformMatrix: [Float] = [
            Float(transform.a), Float(transform.b), 0,
            Float(transform.c), Float(transform.d), 0,
            Float(transform.tx), Float(transform.ty), 1
        ]
        guard let inputBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let transformBuffer = device.makeBuffer(bytes: transformMatrix, length: 9 * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(transformBuffer, offset: 0, index: 2)
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: pointCount)

        var result: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        return .success(result)
    }

    func pointsInPolygonGPU(_ testPoints: [CGPoint], polygon: [CGPoint]) -> Result<[Bool], MetalError> {
        guard let pipeline = collisionDetectionPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let testPointCount = testPoints.count
        let polygonVertexCount = polygon.count
        let metalTestPoints = testPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalPolygonVertices = polygon.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        guard let testPointsBuffer = device.makeBuffer(bytes: metalTestPoints, length: testPointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let polygonBuffer = device.makeBuffer(bytes: metalPolygonVertices, length: polygonVertexCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let resultsBuffer = device.makeBuffer(length: testPointCount * MemoryLayout<Bool>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var vertexCount = UInt32(polygonVertexCount)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(testPointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(polygonBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultsBuffer, offset: 0, index: 2)
        computeEncoder.setBytes(&vertexCount, length: MemoryLayout<UInt32>.stride, index: 3)
        let threadsPerGroup = MTLSize(width: min(testPointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (testPointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = resultsBuffer.contents().bindMemory(to: Bool.self, capacity: testPointCount)

        var results: [Bool] = []
        for i in 0..<testPointCount {
            results.append(resultPointer[i])
        }
        return .success(results)
    }

    func calculateDistancesGPU(from sourcePoints: [CGPoint], to targetPoints: [CGPoint]) -> Result<[Float], MetalError> {
        guard sourcePoints.count == targetPoints.count else {
            return .failure(.operationFailed("Source and target point counts must match"))
        }
        guard let pipeline = vectorDistancePipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let pointCount = sourcePoints.count
        let metalSourcePoints = sourcePoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalTargetPoints = targetPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        guard let sourceBuffer = device.makeBuffer(bytes: metalSourcePoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let targetBuffer = device.makeBuffer(bytes: metalTargetPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let distanceBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(targetBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(distanceBuffer, offset: 0, index: 2)
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = distanceBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)

        var results: [Float] = []
        for i in 0..<pointCount {
            results.append(resultPointer[i])
        }
        return .success(results)
    }

    func normalizeVectorsGPU(_ vectors: [CGPoint]) -> Result<[CGPoint], MetalError> {
        guard let pipeline = vectorNormalizePipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let vectorCount = vectors.count
        let metalVectors = vectors.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        guard let inputBuffer = device.makeBuffer(bytes: metalVectors, length: vectorCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: vectorCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        let threadsPerGroup = MTLSize(width: min(vectorCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (vectorCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: vectorCount)

        var results: [CGPoint] = []
        for i in 0..<vectorCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        return .success(results)
    }

    func lerpVectorsGPU(from startPoints: [CGPoint], to endPoints: [CGPoint], t: Float) -> Result<[CGPoint], MetalError> {
        guard startPoints.count == endPoints.count else {
            return .failure(.operationFailed("Start and end point counts must match"))
        }
        guard let pipeline = vectorLerpPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let pointCount = startPoints.count
        let metalStartPoints = startPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalEndPoints = endPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        guard let startBuffer = device.makeBuffer(bytes: metalStartPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let endBuffer = device.makeBuffer(bytes: metalEndPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var lerpFactor = t
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(startBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(endBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
        computeEncoder.setBytes(&lerpFactor, length: MemoryLayout<Float>.stride, index: 3)
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: pointCount)

        var results: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        return .success(results)
    }

    func calculateLinkedHandlesGPU(anchorPoints: [CGPoint], draggedHandles: [CGPoint], originalOppositeHandles: [CGPoint]) -> Result<[CGPoint], MetalError> {
        guard anchorPoints.count == draggedHandles.count &&
              draggedHandles.count == originalOppositeHandles.count else {
            return .failure(.operationFailed("All point arrays must have the same count"))
        }
        guard let pipeline = handleCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let pointCount = anchorPoints.count
        let metalAnchorPoints = anchorPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalDraggedHandles = draggedHandles.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let metalOriginalHandles = originalOppositeHandles.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        guard let anchorBuffer = device.makeBuffer(bytes: metalAnchorPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let draggedBuffer = device.makeBuffer(bytes: metalDraggedHandles, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),
              let originalBuffer = device.makeBuffer(bytes: metalOriginalHandles, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(anchorBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(draggedBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(originalBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 3)
        let threadsPerGroup = MTLSize(width: min(pointCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: Point2D.self, capacity: pointCount)

        var results: [CGPoint] = []
        for i in 0..<pointCount {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        return .success(results)
    }

    func calculateCurvatureGPU(points: [CGPoint]) -> Result<[Float], MetalError> {
        guard points.count >= 3 else {
            return .failure(.operationFailed("Need at least 3 points for curvature calculation"))
        }
        guard let pipeline = curvatureCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let pointCount = points.count
        let metalPoints = points.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        guard let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<Point2D>.stride, options: .storageModeShared),

              let curvatureBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var pointCountInt = UInt32(pointCount)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(curvatureBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&pointCountInt, length: MemoryLayout<UInt32>.stride, index: 2)
        let processCount = max(1, pointCount - 2)
        let threadsPerGroup = MTLSize(width: min(processCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (processCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = curvatureBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)

        var results: [Float] = []
        for i in 0..<pointCount {
            results.append(resultPointer[i])
        }
        return .success(results)
    }

    func chaikinSmoothingGPU(points: [CGPoint], ratio: Float = 0.25) -> Result<[CGPoint], MetalError> {
        guard points.count >= 3 else {
            return .failure(.operationFailed("Need at least 3 points for Chaikin smoothing"))
        }
        guard let pipeline = chaikinSmoothingPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let inputCount = points.count
        let outputCount = (inputCount - 1) * 2 + 1
        let simdPoints = points.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let inputBuffer = device.makeBuffer(bytes: simdPoints, length: inputCount * MemoryLayout<simd_float2>.stride, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: outputCount * MemoryLayout<simd_float2>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var inputCountInt = UInt32(inputCount)
        var smoothingRatio = ratio
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&inputCountInt, length: MemoryLayout<UInt32>.stride, index: 2)
        computeEncoder.setBytes(&smoothingRatio, length: MemoryLayout<Float>.stride, index: 3)
        let processCount = inputCount - 1
        let threadsPerGroup = MTLSize(width: min(processCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (processCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: simd_float2.self, capacity: outputCount)

        var results: [CGPoint] = []
        for i in 0..<outputCount {
            let point = resultPointer[i]
            if point.x != 0 || point.y != 0 || i == 0 {
                results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
        }
        return .success(results)
    }

    func calculatePointDistanceGPU(from point1: CGPoint, to point2: CGPoint) -> Result<Float, MetalError> {
        let results = calculateDistancesGPU(from: [point1], to: [point2])
        switch results {
        case .success(let distances):
            return .success(distances.first ?? 0.0)
        case .failure(let error):
            return .failure(error)
        }
    }

    func calculateSquareRootGPU(_ value: Float) -> Result<Float, MetalError> {
        let results = calculateSquareRootsGPU([value])
        switch results {
        case .success(let squareRoots):
            return .success(squareRoots.first ?? 0.0)
        case .failure(let error):
            return .failure(error)
        }
    }

    func calculateSquareRootsGPU(_ values: [Float]) -> Result<[Float], MetalError> {
        guard !values.isEmpty else {
            return .failure(.operationFailed("Values array cannot be empty"))
        }
        guard let pipeline = squareRootPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let valueCount = values.count
        guard let inputBuffer = device.makeBuffer(bytes: values, length: valueCount * MemoryLayout<Float>.stride, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: valueCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        let threadsPerGroup = MTLSize(width: min(valueCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (valueCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: valueCount)

        var results: [Float] = []
        for i in 0..<valueCount {
            results.append(resultPointer[i])
        }
        return .success(results)
    }

    func booleanGeometryUnionGPU(path1Points: [Point2D], path2Points: [Point2D]) -> Result<[Point2D], MetalError> {
        guard let pipeline = booleanGeometryPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        let resultCount = path1Points.count + path2Points.count
        let resultPoints = [Point2D](repeating: Point2D(x: 0, y: 0), count: resultCount)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        guard let path1Buffer = device.makeBuffer(bytes: path1Points, length: path1Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let path2Buffer = device.makeBuffer(bytes: path2Points, length: path2Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let resultBuffer = device.makeBuffer(bytes: resultPoints, length: resultCount * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let path1CountBuffer = device.makeBuffer(bytes: [UInt32(path1Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared),

              let path2CountBuffer = device.makeBuffer(bytes: [UInt32(path2Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(path1Buffer, offset: 0, index: 0)
        computeEncoder.setBuffer(path2Buffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(path1CountBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(path2CountBuffer, offset: 0, index: 4)
        let threadGroupSize = MTLSize(width: 64, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (resultCount + 63) / 64, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = resultBuffer.contents().assumingMemoryBound(to: Point2D.self)
        let resultArray = Array<Point2D>(UnsafeBufferPointer(start: resultPointer, count: resultCount))
        return .success(resultArray)
    }

    func pathIntersectionGPU(path1Points: [Point2D], path2Points: [Point2D]) -> Result<[Point2D], MetalError> {
        guard let pipeline = pathIntersectionPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        let maxIntersections = 1000
        let intersectionPoints = [Point2D](repeating: Point2D(x: 0, y: 0), count: maxIntersections)

        var intersectionCount: UInt32 = 0
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        guard let path1Buffer = device.makeBuffer(bytes: path1Points, length: path1Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let path2Buffer = device.makeBuffer(bytes: path2Points, length: path2Points.count * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let resultBuffer = device.makeBuffer(bytes: intersectionPoints, length: maxIntersections * MemoryLayout<Point2D>.size, options: .storageModeShared),
              let countBuffer = device.makeBuffer(bytes: &intersectionCount, length: MemoryLayout<UInt32>.size, options: .storageModeShared),
              let path1CountBuffer = device.makeBuffer(bytes: [UInt32(path1Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared),

              let path2CountBuffer = device.makeBuffer(bytes: [UInt32(path2Points.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(path1Buffer, offset: 0, index: 0)
        computeEncoder.setBuffer(path2Buffer, offset: 0, index: 1)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(path1CountBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(path2CountBuffer, offset: 0, index: 5)
        let threadGroupSize = MTLSize(width: 64, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (path1Points.count * path2Points.count + 63) / 64, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = resultBuffer.contents().assumingMemoryBound(to: Point2D.self)
        let resultArray = Array<Point2D>(UnsafeBufferPointer(start: resultPointer, count: Int(intersectionCount)))
        return .success(resultArray)
    }

    func calculateTrigonometricGPU(angles: [Float], function: TrigonometricFunction) -> Result<[Float], MetalError> {
        guard !angles.isEmpty else {
            return .failure(.operationFailed("Angles array cannot be empty"))
        }
        guard let pipeline = trigonometricPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let angleCount = angles.count
        let inputBuffer = device.makeBuffer(bytes: angles, length: angleCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        let outputBuffer = device.makeBuffer(length: angleCount * MemoryLayout<Float>.stride, options: .storageModeShared)

        var trigFunction = UInt32(function.rawValue)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&trigFunction, length: MemoryLayout<UInt32>.stride, index: 2)
        let threadsPerGroup = MTLSize(width: min(angleCount, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (angleCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Float.self, capacity: angleCount) else {
            return .failure(.bufferCreationFailed)
        }
        var results: [Float] = []
        for i in 0..<angleCount {
            results.append(resultPointer[i])
        }
        return .success(results)
    }

    func calculatePolygonPointsGPU(center: CGPoint, radius: Float, sides: Int, startAngle: Float = -Float.pi/2) -> Result<[CGPoint], MetalError> {
        guard sides > 2 else {
            return .failure(.operationFailed("Polygon must have at least 3 sides"))
        }
        guard let pipeline = polygonCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        var centerPoint = Point2D(x: Float(center.x), y: Float(center.y))

        let outputBuffer = device.makeBuffer(length: sides * MemoryLayout<Point2D>.stride, options: .storageModeShared)

        var params = PolygonParams(radius: radius, sides: UInt32(sides), startAngle: startAngle)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&centerPoint, length: MemoryLayout<Point2D>.stride, index: 1)
        computeEncoder.setBytes(&params, length: MemoryLayout<PolygonParams>.stride, index: 2)
        let threadsPerGroup = MTLSize(width: min(sides, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (sides + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard let resultPointer = outputBuffer?.contents().bindMemory(to: Point2D.self, capacity: sides) else {
            return .failure(.bufferCreationFailed)
        }
        var results: [CGPoint] = []
        for i in 0..<sides {
            let point = resultPointer[i]
            results.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        return .success(results)
    }

    func calculateBezierCurveGPU(controlPoints: [CGPoint], steps: Int = 100) -> Result<[CGPoint], MetalError> {
        guard controlPoints.count == 4 else {
            return .failure(.operationFailed("Bezier curve requires exactly 4 control points"))
        }
        guard let pipeline = bezierCalculationPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return .failure(.commandBufferCreationFailed)
        }
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.computeEncoderCreationFailed)
        }
        let metalControlPoints = controlPoints.map { Point2D(x: Float($0.x), y: Float($0.y)) }
        let controlPointsBuffer = device.makeBuffer(bytes: metalControlPoints, length: 4 * MemoryLayout<Point2D>.stride, options: .storageModeShared)
        let resultBuffer = device.makeBuffer(length: steps * MemoryLayout<Point2D>.stride, options: .storageModeShared)

        var stepCount = Int32(steps)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(resultBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&stepCount, length: MemoryLayout<Int32>.stride, index: 2)
        let threadsPerGroup = MTLSize(width: min(steps, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (steps + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard let resultPointer = resultBuffer?.contents().bindMemory(to: Point2D.self, capacity: steps) else {
            return .failure(.bufferCreationFailed)
        }
        var result: [CGPoint] = []
        for i in 0..<steps {
            let point = resultPointer[i]
            result.append(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        return .success(result)
    }

    func findNearestPointGPU(points: [CGPoint], tapLocation: CGPoint, selectionRadius: CGFloat, transform: CGAffineTransform = .identity) -> Int? {
        guard !points.isEmpty else { return nil }
        guard let pipeline = findNearestPointPipeline else { return nil }
        let transformedPoints = points.map { $0.applying(transform) }
        let metalPoints = transformedPoints.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        let pointCount = metalPoints.count
        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        guard let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<simd_float2>.stride, options: bufferOptions),
              let distancesBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: bufferOptions),

              let validIndicesBuffer = device.makeBuffer(length: pointCount * MemoryLayout<UInt32>.stride, options: bufferOptions) else {
            return nil
        }
        var tapLocationMetal = simd_float2(Float(tapLocation.x), Float(tapLocation.y))
        var radiusMetal = Float(selectionRadius)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&tapLocationMetal, length: MemoryLayout<simd_float2>.stride, index: 1)
        computeEncoder.setBytes(&radiusMetal, length: MemoryLayout<Float>.stride, index: 2)
        computeEncoder.setBuffer(distancesBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(validIndicesBuffer, offset: 0, index: 4)
        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, pointCount), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let distancesPointer = distancesBuffer.contents().bindMemory(to: Float.self, capacity: pointCount)
        let validIndicesPointer = validIndicesBuffer.contents().bindMemory(to: UInt32.self, capacity: pointCount)

        var minDistance: Float = .infinity
        var minIndex: Int? = nil
        for i in 0..<pointCount {
            if validIndicesPointer[i] != UInt32.max {
                let distance = distancesPointer[i]
                if distance < minDistance {
                    minDistance = distance
                    minIndex = i
                }
            }
        }
        return minIndex
    }

    func findNearestHandleGPU(handlePoints: [CGPoint], anchorPoints: [CGPoint], tapLocation: CGPoint, selectionRadius: CGFloat, transform: CGAffineTransform = .identity) -> Int? {
        guard !handlePoints.isEmpty, handlePoints.count == anchorPoints.count else { return nil }
        guard let pipeline = findNearestHandlePipeline else { return nil }
        let transformedHandles = handlePoints.map { $0.applying(transform) }
        let transformedAnchors = anchorPoints.map { $0.applying(transform) }
        let metalHandles = transformedHandles.map { simd_float2(Float($0.x), Float($0.y)) }
        let metalAnchors = transformedAnchors.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        let handleCount = metalHandles.count
        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        guard let handlesBuffer = device.makeBuffer(bytes: metalHandles, length: handleCount * MemoryLayout<simd_float2>.stride, options: bufferOptions),
              let anchorsBuffer = device.makeBuffer(bytes: metalAnchors, length: handleCount * MemoryLayout<simd_float2>.stride, options: bufferOptions),
              let distancesBuffer = device.makeBuffer(length: handleCount * MemoryLayout<Float>.stride, options: bufferOptions),

              let validIndicesBuffer = device.makeBuffer(length: handleCount * MemoryLayout<UInt32>.stride, options: bufferOptions) else {
            return nil
        }
        var tapLocationMetal = simd_float2(Float(tapLocation.x), Float(tapLocation.y))
        var radiusMetal = Float(selectionRadius)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(handlesBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(anchorsBuffer, offset: 0, index: 1)
        computeEncoder.setBytes(&tapLocationMetal, length: MemoryLayout<simd_float2>.stride, index: 2)
        computeEncoder.setBytes(&radiusMetal, length: MemoryLayout<Float>.stride, index: 3)
        computeEncoder.setBuffer(distancesBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(validIndicesBuffer, offset: 0, index: 5)
        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, handleCount), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (handleCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let distancesPointer = distancesBuffer.contents().bindMemory(to: Float.self, capacity: handleCount)
        let validIndicesPointer = validIndicesBuffer.contents().bindMemory(to: UInt32.self, capacity: handleCount)

        var minDistance: Float = .infinity
        var minIndex: Int? = nil
        for i in 0..<handleCount {
            if validIndicesPointer[i] != UInt32.max {
                let distance = distancesPointer[i]
                if distance < minDistance {
                    minDistance = distance
                    minIndex = i
                }
            }
        }
        return minIndex
    }

    func findPointsInRadiusGPU(points: [CGPoint], tapLocation: CGPoint, selectionRadius: CGFloat, transform: CGAffineTransform = .identity, maxMatches: Int = 1000) -> [Int] {
        guard !points.isEmpty else { return [] }
        guard let pipeline = findPointsInRadiusPipeline else { return [] }
        let transformedPoints = points.map { $0.applying(transform) }
        let metalPoints = transformedPoints.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return []
        }
        let pointCount = metalPoints.count
        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        guard let pointsBuffer = device.makeBuffer(bytes: metalPoints, length: pointCount * MemoryLayout<simd_float2>.stride, options: bufferOptions),
              let matchingIndicesBuffer = device.makeBuffer(length: maxMatches * MemoryLayout<UInt32>.stride, options: bufferOptions),

              let matchCountBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            return []
        }
        matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee = 0
        var tapLocationMetal = simd_float2(Float(tapLocation.x), Float(tapLocation.y))
        var radiusMetal = Float(selectionRadius)
        var maxMatchesMetal = UInt32(maxMatches)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(pointsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&tapLocationMetal, length: MemoryLayout<simd_float2>.stride, index: 1)
        computeEncoder.setBytes(&radiusMetal, length: MemoryLayout<Float>.stride, index: 2)
        computeEncoder.setBuffer(matchingIndicesBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(matchCountBuffer, offset: 0, index: 4)
        computeEncoder.setBytes(&maxMatchesMetal, length: MemoryLayout<UInt32>.stride, index: 5)
        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, pointCount), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (pointCount + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let matchCount = Int(matchCountBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee)
        let matchingIndicesPointer = matchingIndicesBuffer.contents().bindMemory(to: UInt32.self, capacity: min(matchCount, maxMatches))

        var results: [Int] = []
        for i in 0..<min(matchCount, maxMatches) {
            results.append(Int(matchingIndicesPointer[i]))
        }
        return results
    }

    static func testMetalEngine() -> Bool {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return false
        }
        let engine = MetalComputeEngine.shared
        let testPoint1 = CGPoint(x: 0, y: 0)
        let testPoint2 = CGPoint(x: 3, y: 4)
        let distanceResult = engine.calculatePointDistanceGPU(from: testPoint1, to: testPoint2)
        let expectedDistance: Float = 5.0
        switch distanceResult {
        case .success(let distance):
            return abs(distance - expectedDistance) < 0.1
        case .failure:
            return false
        }
    }

    func pathHitTestGPU(_ path: CGPath, point: CGPoint, tolerance: CGFloat) -> Bool {
        guard let pipeline = pathHitTestPipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("Metal GPU path hit test pipeline not available")
        }
        var segments: [MetalPathSegment] = []
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                segments.append(MetalPathSegment(
                    type: 0,
                    point: simd_float2(Float(points[0].x), Float(points[0].y)),
                    control1: simd_float2(0, 0),
                    control2: simd_float2(0, 0)
                ))
            case .addLineToPoint:
                segments.append(MetalPathSegment(
                    type: 1,
                    point: simd_float2(Float(points[0].x), Float(points[0].y)),
                    control1: simd_float2(0, 0),
                    control2: simd_float2(0, 0)
                ))
            case .addQuadCurveToPoint:
                segments.append(MetalPathSegment(
                    type: 3,
                    point: simd_float2(Float(points[1].x), Float(points[1].y)),
                    control1: simd_float2(Float(points[0].x), Float(points[0].y)),
                    control2: simd_float2(0, 0)
                ))
            case .addCurveToPoint:
                segments.append(MetalPathSegment(
                    type: 2,
                    point: simd_float2(Float(points[2].x), Float(points[2].y)),
                    control1: simd_float2(Float(points[0].x), Float(points[0].y)),
                    control2: simd_float2(Float(points[1].x), Float(points[1].y))
                ))
            case .closeSubpath:
                segments.append(MetalPathSegment(
                    type: 4,
                    point: simd_float2(0, 0),
                    control1: simd_float2(0, 0),
                    control2: simd_float2(0, 0)
                ))

            @unknown default:
                break
            }
        }
        guard !segments.isEmpty else { return false }
        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        guard let segmentsBuffer = device.makeBuffer(bytes: segments, length: segments.count * MemoryLayout<MetalPathSegment>.stride, options: bufferOptions),

              let hitResultBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            fatalError("Failed to create Metal buffers for path hit test")
        }
        hitResultBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee = 0
        var segmentCount = UInt32(segments.count)
        var tapPoint = simd_float2(Float(point.x), Float(point.y))
        var toleranceFloat = Float(tolerance)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(segmentsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&segmentCount, length: MemoryLayout<UInt32>.stride, index: 1)
        computeEncoder.setBytes(&tapPoint, length: MemoryLayout<simd_float2>.stride, index: 2)
        computeEncoder.setBytes(&toleranceFloat, length: MemoryLayout<Float>.stride, index: 3)
        computeEncoder.setBuffer(hitResultBuffer, offset: 0, index: 4)
        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, segments.count), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (segments.count + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let hitResult = hitResultBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        return hitResult == 1
    }

    func findNearestSnapPointGPU(snapPoints: [CGPoint], objectIDs: [UUID], mousePoint: CGPoint, threshold: CGFloat) -> (index: Int, objectID: UUID, point: CGPoint)? {
        guard let pipeline = findNearestSnapPointPipeline,
              !snapPoints.isEmpty,
              snapPoints.count == objectIDs.count else {
            return nil
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        let snapFloat2Array = snapPoints.map { simd_float2(Float($0.x), Float($0.y)) }
        let bufferOptions: MTLResourceOptions = device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
        guard let snapPointsBuffer = device.makeBuffer(bytes: snapFloat2Array, length: snapFloat2Array.count * MemoryLayout<simd_float2>.stride, options: bufferOptions),

              let distancesBuffer = device.makeBuffer(length: snapPoints.count * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return nil
        }
        var snapCount = UInt32(snapPoints.count)
        var mouseFloat2 = simd_float2(Float(mousePoint.x), Float(mousePoint.y))
        var thresholdFloat = Float(threshold)
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(snapPointsBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&snapCount, length: MemoryLayout<UInt32>.stride, index: 1)
        computeEncoder.setBytes(&mouseFloat2, length: MemoryLayout<simd_float2>.stride, index: 2)
        computeEncoder.setBytes(&thresholdFloat, length: MemoryLayout<Float>.stride, index: 3)
        computeEncoder.setBuffer(distancesBuffer, offset: 0, index: 4)
        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, snapPoints.count), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (snapPoints.count + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let distancesPtr = distancesBuffer.contents().bindMemory(to: Float.self, capacity: snapPoints.count)

        var nearestIndex: Int?
        var nearestDist = Float(threshold)
        for i in 0..<snapPoints.count {
            let dist = distancesPtr[i]
            if dist < nearestDist {
                nearestDist = dist
                nearestIndex = i
            }
        }
        guard let index = nearestIndex else {
            return nil
        }
        return (index: index, objectID: objectIDs[index], point: snapPoints[index])
    }

    func removeCoincidentPointsGPU(_ points: [CGPoint], pressures: [Float]? = nil, tolerance: Float = 1.0) -> Result<([CGPoint], [Float]?), MetalError> {
        guard !points.isEmpty else {
            return .success(([], nil))
        }
        guard let pipeline = removeCoincidentPointsPipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.commandBufferCreationFailed)
        }
        let pointCount = points.count
        let simdPoints = points.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let inputBuffer = device.makeBuffer(bytes: simdPoints, length: pointCount * MemoryLayout<simd_float2>.stride, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<simd_float2>.stride, options: .storageModeShared),

              let outputCountBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        outputCountBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee = 0
        var pressureInputBuffer: MTLBuffer?
        var pressureOutputBuffer: MTLBuffer?
        if let pressures = pressures {
            pressureInputBuffer = device.makeBuffer(bytes: pressures, length: pressures.count * MemoryLayout<Float>.stride, options: .storageModeShared)
            pressureOutputBuffer = device.makeBuffer(length: pointCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(pressureInputBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(pressureOutputBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(outputCountBuffer, offset: 0, index: 4)
        var count = UInt32(pointCount)
        computeEncoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 5)
        var tol = tolerance
        computeEncoder.setBytes(&tol, length: MemoryLayout<Float>.stride, index: 6)
        let threadsPerGroup = MTLSize(width: 1, height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: 1, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputCount = Int(outputCountBuffer.contents().assumingMemoryBound(to: UInt32.self).pointee)
        let resultPointer = outputBuffer.contents().assumingMemoryBound(to: simd_float2.self)

        var resultPoints: [CGPoint] = []
        for i in 0..<outputCount {
            let simdPoint = resultPointer[i]
            resultPoints.append(CGPoint(x: CGFloat(simdPoint.x), y: CGFloat(simdPoint.y)))
        }
        var resultPressures: [Float]?
        if let pressureOutput = pressureOutputBuffer {
            let pressurePointer = pressureOutput.contents().assumingMemoryBound(to: Float.self)
            resultPressures = Array(UnsafeBufferPointer(start: pressurePointer, count: outputCount))
        }
        return .success((resultPoints, resultPressures))
    }

    func smoothBrushStrokeGPU(_ points: [CGPoint], pressures: [Float]? = nil, smoothingFactor: Float = 0.7, subdivisions: Int = 4) -> Result<([CGPoint], [Float]?), MetalError> {
        guard points.count >= 2 else {
            return .success((points, pressures))
        }
        guard let pipeline = smoothBrushStrokePipeline else {
            return .failure(.pipelineNotAvailable)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),

              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return .failure(.commandBufferCreationFailed)
        }
        let inputCount = points.count
        let outputCount = (inputCount - 1) * subdivisions + 1
        let simdPoints = points.map { simd_float2(Float($0.x), Float($0.y)) }
        guard let inputBuffer = device.makeBuffer(bytes: simdPoints, length: inputCount * MemoryLayout<simd_float2>.stride, options: .storageModeShared),

              let outputBuffer = device.makeBuffer(length: outputCount * MemoryLayout<simd_float2>.stride, options: .storageModeShared) else {
            return .failure(.bufferCreationFailed)
        }
        var pressureInputBuffer: MTLBuffer?
        var pressureOutputBuffer: MTLBuffer?
        if let pressures = pressures {
            pressureInputBuffer = device.makeBuffer(bytes: pressures, length: pressures.count * MemoryLayout<Float>.stride, options: .storageModeShared)
            pressureOutputBuffer = device.makeBuffer(length: outputCount * MemoryLayout<Float>.stride, options: .storageModeShared)
        }
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(pressureInputBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(pressureOutputBuffer, offset: 0, index: 3)
        var count = UInt32(inputCount)
        var smooth = smoothingFactor
        var subdiv = UInt32(subdivisions)
        computeEncoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 4)
        computeEncoder.setBytes(&smooth, length: MemoryLayout<Float>.stride, index: 5)
        computeEncoder.setBytes(&subdiv, length: MemoryLayout<UInt32>.stride, index: 6)
        let totalThreads = (inputCount - 1) * subdivisions
        let threadsPerGroup = MTLSize(width: min(totalThreads, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(width: (totalThreads + threadsPerGroup.width - 1) / threadsPerGroup.width, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let resultPointer = outputBuffer.contents().assumingMemoryBound(to: simd_float2.self)

        var resultPoints: [CGPoint] = []
        resultPoints.append(points[0])
        for i in 0..<totalThreads {
            let simdPoint = resultPointer[i]
            resultPoints.append(CGPoint(x: CGFloat(simdPoint.x), y: CGFloat(simdPoint.y)))
        }
        if let lastPoint = points.last {
            resultPoints.append(lastPoint)
        }
        var resultPressures: [Float]?
        if let pressureOutput = pressureOutputBuffer {
            let pressurePointer = pressureOutput.contents().assumingMemoryBound(to: Float.self)
            resultPressures = Array(UnsafeBufferPointer(start: pressurePointer, count: outputCount))
        }
        return .success((resultPoints, resultPressures))
    }
}

struct MetalPathSegment {
    let type: UInt32
    let point: simd_float2
    let control1: simd_float2
    let control2: simd_float2
}
