import SwiftUI

struct ConeIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let r = CGRect(
                x: 5 - IconStrokeExpand,
                y: 4 - IconStrokeExpand,
                width: 10 + IconStrokeWidth,
                height: 10 + IconStrokeWidth
            )
            let apex = CGPoint(x: r.midX, y: r.minY)
            let baseLeft = CGPoint(x: r.minX, y: r.maxY)
            let baseRight = CGPoint(x: r.maxX, y: r.maxY)
            let move = CGPoint(x: baseRight.x - r.width * 0.007461, y: baseRight.y - r.height * 0.13586)
            let c1 = CGPoint(x: baseRight.x - r.width * 0.002364, y: baseRight.y - r.height * 0.12957)
            let c2 = CGPoint(x: baseRight.x, y: baseRight.y - r.height * 0.12317)
            let rightStart = CGPoint(x: baseRight.x, y: baseRight.y - r.height * 0.11645)
            let c3 = CGPoint(x: baseRight.x, y: baseRight.y - r.height * 0.05216)
            let c4 = CGPoint(x: r.midX + r.width * 0.27608, y: r.maxY)
            let mid = CGPoint(x: r.midX, y: r.maxY)
            let c5 = CGPoint(x: r.midX - r.width * 0.27608, y: r.maxY)
            let c6 = CGPoint(x: baseLeft.x, y: baseLeft.y - r.height * 0.05216)
            let leftEnd = CGPoint(x: baseLeft.x, y: baseLeft.y - r.height * 0.11645)
            let c7 = CGPoint(x: baseLeft.x, y: baseLeft.y - r.height * 0.12160)
            let c8 = CGPoint(x: baseLeft.x + r.width * 0.00141, y: baseLeft.y - r.height * 0.12660)
            let leftExit = CGPoint(x: baseLeft.x + r.width * 0.00463, y: baseLeft.y - r.height * 0.13147)
            path.move(to: move)
            path.addCurve(to: rightStart, control1: c1, control2: c2)
            path.addCurve(to: mid, control1: c3, control2: c4)
            path.addCurve(to: leftEnd, control1: c5, control2: c6)
            path.addCurve(to: leftExit, control1: c7, control2: c8)
            path.addLine(to: apex)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
