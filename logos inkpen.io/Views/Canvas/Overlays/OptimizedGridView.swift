import SwiftUI

struct OptimizedGridView: View {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let unit: MeasurementUnit
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let pageOrigin: CGPoint

    var body: some View {
        Canvas { context, size in
            let baseSpacing = gridSpacing * unit.pointsPerUnit

            let spacingMultiplier: CGFloat = {
                switch unit {
                case .pixels, .points:
                    return 25.0
                case .millimeters:
                    return 1.0
                case .picas:
                    return 4.0
                default:
                    return 1.0
                }
            }()
            let actualGridSpacing = baseSpacing * spacingMultiplier
            let majorGridInterval = unit.majorGridInterval
            let tileSize = actualGridSpacing * CGFloat(majorGridInterval)
            let shouldShowMinor = zoomLevel > 0.5
            let minorLineWidth: CGFloat = 0.625
            let majorLineWidth: CGFloat = zoomLevel <= 0.5 ? 0.3125 : 0.625
            let (minorPattern, majorPattern) = createTilePatterns(
                tileSize: tileSize,
                gridSpacing: actualGridSpacing,
                majorInterval: majorGridInterval,
                showMinor: shouldShowMinor
            )
            let visibleStartX = max(0, -canvasOffset.x / zoomLevel)
            let visibleEndX = min(canvasSize.width, (size.width - canvasOffset.x) / zoomLevel)
            let visibleStartY = max(0, -canvasOffset.y / zoomLevel)
            let visibleEndY = min(canvasSize.height, (size.height - canvasOffset.y) / zoomLevel)
            let offsetFromOriginX = (visibleStartX - pageOrigin.x) / tileSize
            let offsetFromOriginY = (visibleStartY - pageOrigin.y) / tileSize
            let tileStartX = Int(floor(offsetFromOriginX))
            let tileEndX = Int(ceil((visibleEndX - pageOrigin.x) / tileSize))
            let tileStartY = Int(floor(offsetFromOriginY))
            let tileEndY = Int(ceil((visibleEndY - pageOrigin.y) / tileSize))
            guard tileStartX <= tileEndX && tileStartY <= tileEndY else { return }
            for tileX in tileStartX...tileEndX {
                for tileY in tileStartY...tileEndY {
                    let x = pageOrigin.x + CGFloat(tileX) * tileSize
                    let y = pageOrigin.y + CGFloat(tileY) * tileSize
                    if x < canvasSize.width && y < canvasSize.height {
                        var transform = CGAffineTransform.identity
                        transform = transform.translatedBy(
                            x: x * zoomLevel + canvasOffset.x,
                            y: y * zoomLevel + canvasOffset.y
                        )
                        transform = transform.scaledBy(x: zoomLevel, y: zoomLevel)
                        if shouldShowMinor && !minorPattern.isEmpty {
                            let transformedMinor = minorPattern.applying(transform)
                            context.stroke(
                                transformedMinor,
                                with: .color(.gray.opacity(0.3)),
                                lineWidth: minorLineWidth
                            )
                        }
                        if !majorPattern.isEmpty {
                            let transformedMajor = majorPattern.applying(transform)
                            context.stroke(
                                transformedMajor,
                                with: .color(.gray.opacity(0.45)),
                                lineWidth: majorLineWidth
                            )
                        }
                    }
                }
            }
        }
    }

    private func createTilePatterns(
        tileSize: CGFloat,
        gridSpacing: CGFloat,
        majorInterval: Int,
        showMinor: Bool
    ) -> (minor: Path, major: Path) {
        var minorPath = Path()
        var majorPath = Path()
        if showMinor {
            for i in 1..<majorInterval {
                let offset = CGFloat(i) * gridSpacing
                minorPath.move(to: CGPoint(x: offset, y: 0))
                minorPath.addLine(to: CGPoint(x: offset, y: tileSize))
                minorPath.move(to: CGPoint(x: 0, y: offset))
                minorPath.addLine(to: CGPoint(x: tileSize, y: offset))
            }
        }
        majorPath.move(to: CGPoint(x: 0, y: 0))
        majorPath.addLine(to: CGPoint(x: 0, y: tileSize))
        majorPath.move(to: CGPoint(x: 0, y: 0))
        majorPath.addLine(to: CGPoint(x: tileSize, y: 0))
        majorPath.move(to: CGPoint(x: tileSize, y: 0))
        majorPath.addLine(to: CGPoint(x: tileSize, y: tileSize))
        majorPath.move(to: CGPoint(x: 0, y: tileSize))
        majorPath.addLine(to: CGPoint(x: tileSize, y: tileSize))
        return (minorPath, majorPath)
    }
}
