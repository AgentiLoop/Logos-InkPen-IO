import SwiftUI

extension DrawingCanvas {

    internal func createConePath(rect r: CGRect) -> VectorPath {
        let apex = VectorPoint(r.midX, r.minY)
        let baseLeft = VectorPoint(r.minX, r.maxY)
        let baseRight = VectorPoint(r.maxX, r.maxY)
        let move = VectorPoint(baseRight.x - r.width * 0.007461, baseRight.y - r.height * 0.13586)
        let c1 = VectorPoint(baseRight.x - r.width * 0.002364, baseRight.y - r.height * 0.12957)
        let c2 = VectorPoint(baseRight.x, baseRight.y - r.height * 0.12317)
        let rightStart = VectorPoint(baseRight.x, baseRight.y - r.height * 0.11645)
        let c3 = VectorPoint(baseRight.x, baseRight.y - r.height * 0.05216)
        let c4 = VectorPoint(r.midX + r.width * 0.27608, r.maxY)
        let mid = VectorPoint(r.midX, r.maxY)
        let c5 = VectorPoint(r.midX - r.width * 0.27608, r.maxY)
        let c6 = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.05216)
        let leftEnd = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.11645)
        let c7 = VectorPoint(baseLeft.x, baseLeft.y - r.height * 0.12160)
        let c8 = VectorPoint(baseLeft.x + r.width * 0.00141, baseLeft.y - r.height * 0.12660)
        let leftExit = VectorPoint(baseLeft.x + r.width * 0.00463, baseLeft.y - r.height * 0.13147)
        return VectorPath(elements: [
            .move(to: move),
            .curve(to: rightStart, control1: c1, control2: c2),
            .curve(to: mid, control1: c3, control2: c4),
            .curve(to: leftEnd, control1: c5, control2: c6),
            .curve(to: leftExit, control1: c7, control2: c8),
            .line(to: apex),
            .close
        ], isClosed: true)
    }
}
