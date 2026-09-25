import SwiftUI
import SwiftUI

struct PersistentWarpMarquee: View {

    @ObservedObject var document: VectorDocument

    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isEnvelopeTool: Bool

    private let handleSize: CGFloat = 8

    var body: some View {
        ZStack {
            if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                warpEnvelopeOutline()
                if isEnvelopeTool {
                    warpCornerHandles()
                } else {
                    warpCornerDots()
                    if document.viewState.currentTool == .selection {
                        warpGridOverlay()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func warpEnvelopeOutline() -> some View {
        if shape.warpEnvelope.count >= 4 {
            let corners = shape.warpEnvelope
            Path { path in
                path.move(to: corners[0])
                path.addLine(to: corners[1])
                path.addLine(to: corners[2])
                path.addLine(to: corners[3])
                path.closeSubpath()
            }
            .stroke(
                Color.blue,
                style: SwiftUI.StrokeStyle(
                    lineWidth: 2.0 / zoomLevel,
                    dash: [6.0 / zoomLevel, 4.0 / zoomLevel]
                )
            )
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(shape.transform)
        }
    }

    @ViewBuilder
    private func warpCornerHandles() -> some View {
        if shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]
                Rectangle()
                    .fill(Color.green)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(cornerPos)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }

    @ViewBuilder
    private func warpCornerDots() -> some View {
        if shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4.0 / zoomLevel, height: 4.0 / zoomLevel)
                    .position(cornerPos)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }

    @ViewBuilder
    private func warpGridOverlay() -> some View {
        if shape.warpEnvelope.count >= 4 {
            let gridLines = 4
            let corners = shape.warpEnvelope
            ForEach(0..<4) { row in
                let t = CGFloat(row) / CGFloat(gridLines - 1)
                Path { path in
                    let startPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: 0.0, v: t
                    )
                    let endPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: 1.0, v: t
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .opacity(0.8)
            }
            ForEach(0..<4) { col in
                let u = CGFloat(col) / CGFloat(gridLines - 1)
                Path { path in
                    let startPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: u, v: 0.0
                    )
                    let endPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: u, v: 1.0
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .opacity(0.8)
            }
        }
    }

    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )
        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }
}
