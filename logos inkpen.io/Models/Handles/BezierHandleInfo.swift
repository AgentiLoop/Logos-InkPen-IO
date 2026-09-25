struct BezierHandleInfo: Codable, Hashable {
    var control1: VectorPoint?
    var control2: VectorPoint?
    var hasHandles: Bool = false
}
