import SwiftUI
import AppKit
import simd

struct GridCanvasView: View {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let majorGridInterval: Int
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let minorLineWidth: CGFloat = 0.5
            let majorLineWidth: CGFloat
            let shouldShowMinor: Bool
            if zoomLevel <= 0.25 {
                shouldShowMinor = false
                majorLineWidth = minorLineWidth
            } else if zoomLevel <= 0.5 {
                shouldShowMinor = true
                majorLineWidth = minorLineWidth
            } else {
                shouldShowMinor = true
                majorLineWidth = 1.0
            }
            if shouldShowMinor {
                drawGridLines(
                    context: context,
                    gridSpacing: gridSpacing,
                    canvasSize: canvasSize,
                    majorGridInterval: majorGridInterval,
                    isMajor: false,
                    opacity: 0.3,
                    lineWidth: minorLineWidth,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset
                )
            }
            drawGridLines(
                context: context,
                gridSpacing: gridSpacing,
                canvasSize: canvasSize,
                majorGridInterval: majorGridInterval,
                isMajor: true,
                opacity: 0.4,
                lineWidth: majorLineWidth,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )
        }
    }

    private func drawGridLines(
        context: GraphicsContext,
        gridSpacing: CGFloat,
        canvasSize: CGSize,
        majorGridInterval: Int,
        isMajor: Bool,
        opacity: Double,
        lineWidth: CGFloat,
        zoomLevel: Double,
        canvasOffset: CGPoint
    ) {
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let sizeVec = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
        let zoom = Float(zoomLevel)
        let scaledSize = sizeVec * zoom
        let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

        var path = Path()
        for i in 0...gridSteps {
            let shouldDraw = isMajor ? (i % majorGridInterval == 0) : (i % majorGridInterval != 0)
            if shouldDraw {
                let x = CGFloat(i) * gridSpacing
                if x <= canvasSize.width {
                    let transformedX = Float(x) * zoom + offsetVec.x
                    let startY = offsetVec.y
                    let endY = scaledSize.y + offsetVec.y
                    path.move(to: CGPoint(x: CGFloat(transformedX), y: CGFloat(startY)))
                    path.addLine(to: CGPoint(x: CGFloat(transformedX), y: CGFloat(endY)))
                }
            }
        }
        for i in 0...gridSteps {
            let shouldDraw = isMajor ? (i % majorGridInterval == 0) : (i % majorGridInterval != 0)
            if shouldDraw {
                let y = CGFloat(i) * gridSpacing
                if y <= canvasSize.height {
                    let transformedY = Float(y) * zoom + offsetVec.y
                    let startX = offsetVec.x
                    let endX = scaledSize.x + offsetVec.x
                    path.move(to: CGPoint(x: CGFloat(startX), y: CGFloat(transformedY)))
                    path.addLine(to: CGPoint(x: CGFloat(endX), y: CGFloat(transformedY)))
                }
            }
        }
        let adjustedLineWidth: CGFloat
        if zoomLevel < 1.0 {
            adjustedLineWidth = lineWidth / zoomLevel
        } else {
            adjustedLineWidth = max(lineWidth / zoomLevel, lineWidth * 0.75)
        }
        context.stroke(
            path,
            with: .color(.gray.opacity(opacity)),
            lineWidth: adjustedLineWidth
        )
    }
}

struct GridView: View, Equatable {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let unit: MeasurementUnit
    let zoomLevel: Double
    let canvasOffset: CGPoint

    static func == (lhs: GridView, rhs: GridView) -> Bool {
        lhs.gridSpacing == rhs.gridSpacing &&
        lhs.canvasSize == rhs.canvasSize &&
        lhs.unit == rhs.unit &&
        lhs.zoomLevel == rhs.zoomLevel &&
        lhs.canvasOffset == rhs.canvasOffset
    }

    var body: some View {
        let baseSpacing = gridSpacing * unit.pointsPerUnit

        let spacingMultiplier: CGFloat = {
            switch unit {
            case .pixels, .points:
                return 25.0
            case .millimeters:
                return 10.0
            case .picas:
                return 4.0
            default:
                return 1.0
            }
        }()
        let actualGridSpacing = baseSpacing * spacingMultiplier
        let majorGridInterval = unit.majorGridInterval
        GridCanvasView(
            gridSpacing: actualGridSpacing,
            canvasSize: canvasSize,
            majorGridInterval: majorGridInterval,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset
        )
    }
}
