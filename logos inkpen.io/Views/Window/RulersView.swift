import SwiftUI

struct RulersView: View {

    @ObservedObject var document: VectorDocument

    let geometry: GeometryProxy
    let zoomLevel: Double
    let canvasOffset: CGPoint

    private let rulerThickness: CGFloat = 20

    @State private var isDraggingGuide = false
    @State private var draggingGuideOrientation: Guide.Orientation?
    @State private var draggingGuidePosition: CGFloat = 0
    var body: some View {
        if document.gridSettings.showRulers {
            ZStack {
                Canvas { context, size in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color.ui.controlBackground)
                    )
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: size.height - 0.5))
                            path.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                        },
                        with: .color(Color.ui.lightGrayBorder),
                        lineWidth: 0.5
                    )
                    drawHorizontalRuler(context: context, size: size, document: document)
                }
                .frame(height: rulerThickness)
                .position(x: geometry.size.width / 2, y: rulerThickness / 2)
                .contentShape(Path { path in
                    path.addRect(CGRect(x: rulerThickness, y: 0, width: max(0, geometry.size.width - rulerThickness), height: rulerThickness))
                })
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDraggingGuide = true
                            draggingGuideOrientation = .horizontal
                            let canvasY = (value.location.y - canvasOffset.y) / zoomLevel
                            draggingGuidePosition = canvasY
                        }
                        .onEnded { value in
                            if value.location.y > rulerThickness {
                                let canvasY = (value.location.y - canvasOffset.y) / zoomLevel
                                document.addGuideShape(position: canvasY, orientation: .horizontal)
                            }
                            isDraggingGuide = false
                            draggingGuideOrientation = nil
                        }
                )
                .contextMenu {
                    Text("Units").font(.caption).foregroundColor(.secondary)
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Button(unit.rawValue) {
                            document.settings.changeUnit(to: unit)
                            document.onSettingsChanged()
                        }
                    }
                }
                Canvas { context, size in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(Color.ui.controlBackground)
                    )
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: size.width - 0.5, y: 0))
                            path.addLine(to: CGPoint(x: size.width - 0.5, y: size.height))
                        },
                        with: .color(Color.ui.lightGrayBorder),
                        lineWidth: 0.5
                    )
                    var ctx = context
                    ctx.translateBy(x: 0, y: 0.5)
                    drawVerticalRuler(context: ctx, size: size, document: document)
                }
                .frame(width: rulerThickness)
                .position(x: rulerThickness / 2, y: geometry.size.height / 2)
                .contentShape(Path { path in
                    path.addRect(CGRect(x: 0, y: rulerThickness, width: rulerThickness, height: max(0, geometry.size.height - rulerThickness)))
                })
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDraggingGuide = true
                            draggingGuideOrientation = .vertical
                            let canvasX = (value.location.x - canvasOffset.x) / zoomLevel
                            draggingGuidePosition = canvasX
                        }
                        .onEnded { value in
                            if value.location.x > rulerThickness {
                                let canvasX = (value.location.x - canvasOffset.x) / zoomLevel
                                document.addGuideShape(position: canvasX, orientation: .vertical)
                            }
                            isDraggingGuide = false
                            draggingGuideOrientation = nil
                        }
                )
                .contextMenu {
                    Text("Units").font(.caption).foregroundColor(.secondary)
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Button(unit.rawValue) {
                            document.settings.changeUnit(to: unit)
                            document.onSettingsChanged()
                        }
                    }
                }
                PageOriginCrosshair(document: document, geometry: geometry, rulerThickness: rulerThickness, zoomLevel: zoomLevel, canvasOffset: canvasOffset)
                if isDraggingGuide, let orientation = draggingGuideOrientation {
                    let screenPosition = draggingGuidePosition * zoomLevel + (orientation == .horizontal ? canvasOffset.y : canvasOffset.x)
                    if orientation == .horizontal {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: screenPosition))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: screenPosition))
                        }
                        .stroke(Color.nonPhotoBlue, lineWidth: 1)
                    } else {
                        Path { path in
                            path.move(to: CGPoint(x: screenPosition, y: 0))
                            path.addLine(to: CGPoint(x: screenPosition, y: geometry.size.height))
                        }
                        .stroke(Color.nonPhotoBlue, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func drawHorizontalRuler(context: GraphicsContext, size: CGSize, document: VectorDocument) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = zoomLevel
        let canvasOffset = canvasOffset
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let startX = (-canvasOffset.x) / zoomLevel
        let endX = (size.width - canvasOffset.x) / zoomLevel
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)

        var loopStep = tickSpacing

        let majorTickInterval = getMajorTickInterval(for: unit, zoomLevel: zoomLevel)
        let offsetFromOrigin = startX - pageOrigin.x

        var x = floor(offsetFromOrigin / tickSpacing) * tickSpacing + pageOrigin.x
        while x <= endX {
            let rulerX = x * zoomLevel + canvasOffset.x
            if rulerX >= 0 && rulerX <= size.width {
                let relativePosition = x - pageOrigin.x

                var isMajorTick = abs(relativePosition.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                var labelUsesMajor = isMajorTick

                let tickHeight: CGFloat
                let lineWidth: CGFloat
                if unit == .pixels || unit == .points {
                    if isMajorTick {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else {
                        let positionInMajor = abs(relativePosition.truncatingRemainder(dividingBy: 50.0))
                        if abs(positionInMajor - 25.0) < 0.001 {
                            tickHeight = 10
                            lineWidth = 0.75
                        } else if abs(positionInMajor - 12.5) < 0.001 || abs(positionInMajor - 37.5) < 0.001 {
                            tickHeight = 6
                            lineWidth = 0.5
                        } else {
                            tickHeight = 4
                            lineWidth = 0.5
                        }
                    }
                } else if unit == .picas {
                    let majorStep = getMajorTickInterval(for: .picas, zoomLevel: zoomLevel)
                    let halfStep = majorStep / 2.0
                    let quarterStep = majorStep / 4.0
                    let eighthStep = majorStep / 8.0
                    let epsilon = 0.001
                    let isMajor = abs(relativePosition.truncatingRemainder(dividingBy: majorStep)) < epsilon
                    let isHalf = abs(relativePosition.truncatingRemainder(dividingBy: halfStep)) < epsilon
                    let isQuarter = abs(relativePosition.truncatingRemainder(dividingBy: quarterStep)) < epsilon
                    let isEighth = abs(relativePosition.truncatingRemainder(dividingBy: eighthStep)) < epsilon
                    let isThreePoint = abs(relativePosition.truncatingRemainder(dividingBy: 3.0)) < epsilon
                    if zoomLevel < 3.0 {
                        if isMajor {
                            tickHeight = 16
                            lineWidth = 1.0
                        } else if isHalf {
                            tickHeight = 12
                            lineWidth = 0.75
                        } else if isQuarter {
                            tickHeight = 8
                            lineWidth = 0.6
                        } else if isEighth {
                            tickHeight = 4
                            lineWidth = 0.5
                        } else if isThreePoint {
                            tickHeight = 3
                            lineWidth = 0.5
                        } else {
                            x += tickSpacing
                            continue
                        }
                    } else {
                        if isMajor {
                            tickHeight = 16
                            lineWidth = 1.0
                        } else if abs(relativePosition.truncatingRemainder(dividingBy: 6.0)) < epsilon {
                            tickHeight = 12
                            lineWidth = 0.75
                        } else if abs(relativePosition.truncatingRemainder(dividingBy: 3.0)) < epsilon {
                            tickHeight = 8
                            lineWidth = 0.6
                        } else if abs(relativePosition.truncatingRemainder(dividingBy: 1.0)) < epsilon {
                            tickHeight = 4
                            lineWidth = 0.5
                        } else {
                            x += tickSpacing
                            continue
                        }
                    }
                } else if unit == .centimeters || unit == .millimeters {
                    let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
                    let mmIndex = Int(round(x / mmPoints))
                    let isCentimeter = (mmIndex % 10 == 0)
                    let isHalfCentimeter = (mmIndex % 5 == 0)
                    let desiredMinorMm = max(1, Int(round(tickSpacing / mmPoints)))
                    let stepMm: Int = (desiredMinorMm % 5 == 0) ? min(desiredMinorMm, 5) : 1
                    loopStep = Double(stepMm) * mmPoints
                    if unit == .centimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    } else if unit == .millimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    }
                    if !isCentimeter && !isHalfCentimeter {
                        if mmIndex % desiredMinorMm != 0 {
                            x += loopStep
                            continue
                        }
                    }
                    if isCentimeter {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else if isHalfCentimeter {
                        tickHeight = 10
                        lineWidth = 0.7
                    } else {
                        tickHeight = 6
                        lineWidth = 0.5
                    }
                } else {
                    if isMajorTick {
                        tickHeight = 16
                        lineWidth = 1.0
                    } else if abs(relativePosition.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                        tickHeight = 12
                        lineWidth = 0.75
                    } else if abs(relativePosition.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                        tickHeight = 8
                        lineWidth = 0.6
                    } else if abs(relativePosition.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                        tickHeight = 4
                        lineWidth = 0.5
                    } else if abs(relativePosition.truncatingRemainder(dividingBy: pointsPerUnit / 16)) < 0.001 {
                        tickHeight = 3
                        lineWidth = 0.5
                    } else {
                        x += tickSpacing
                        continue
                    }
                }
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: rulerX, y: size.height - tickHeight))
                        path.addLine(to: CGPoint(x: rulerX, y: size.height))
                    },
                    with: .color(.primary),
                    lineWidth: lineWidth
                )
                if labelUsesMajor {
                    var labelText: String
                    if unit == .millimeters {
                        let mmValue = ((x - pageOrigin.x) / MeasurementUnit.millimeters.pointsPerUnit).rounded()
                        let mmInt = Int(mmValue)
                        labelText = String(mmInt)
                    } else {
                        let value = (x - pageOrigin.x) / pointsPerUnit
                        labelText = formatRulerValue(value, unit: unit)
                    }
                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.ui.primaryText)
                    let offsetX: CGFloat = 3
                    context.draw(text, at: CGPoint(x: rulerX + offsetX, y: size.height - 14), anchor: .leading)
                }
            }
            x += loopStep
        }
    }

    private func drawVerticalRuler(context: GraphicsContext, size: CGSize, document: VectorDocument) {
        let unit = document.settings.unit
        let pointsPerUnit = unit.pointsPerUnit
        let zoomLevel = zoomLevel
        let canvasOffset = canvasOffset
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let startY = (-canvasOffset.y) / zoomLevel
        let endY = (size.height - canvasOffset.y) / zoomLevel
        let tickSpacing = calculateTickSpacing(for: unit, zoomLevel: zoomLevel)

        var loopStep = tickSpacing

        let majorTickInterval = getMajorTickInterval(for: unit, zoomLevel: zoomLevel)
        let offsetFromOrigin = startY - pageOrigin.y

        var y = floor(offsetFromOrigin / tickSpacing) * tickSpacing + pageOrigin.y
        while y <= endY {
            let rulerY = y * zoomLevel + canvasOffset.y
            if rulerY >= 0 && rulerY <= size.height {
                let relativePosition = y - pageOrigin.y

                var isMajorTick = abs(relativePosition.truncatingRemainder(dividingBy: majorTickInterval)) < 0.001
                var labelUsesMajor = isMajorTick

                let tickWidth: CGFloat
                let lineWidth: CGFloat
                if unit == .pixels || unit == .points {
                    if isMajorTick {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else {
                        let positionInMajor = abs(y.truncatingRemainder(dividingBy: 50.0))
                        if abs(positionInMajor - 25.0) < 0.001 {
                            tickWidth = 10
                            lineWidth = 0.75
                        } else if abs(positionInMajor - 12.5) < 0.001 || abs(positionInMajor - 37.5) < 0.001 {
                            tickWidth = 6
                            lineWidth = 0.5
                        } else {
                            tickWidth = 4
                            lineWidth = 0.5
                        }
                    }
                } else if unit == .picas {
                    let majorStep = getMajorTickInterval(for: .picas, zoomLevel: zoomLevel)
                    let halfStep = majorStep / 2.0
                    let quarterStep = majorStep / 4.0
                    let eighthStep = majorStep / 8.0
                    let epsilon = 0.001
                    let isMajor = abs(y.truncatingRemainder(dividingBy: majorStep)) < epsilon
                    let isHalf = abs(y.truncatingRemainder(dividingBy: halfStep)) < epsilon
                    let isQuarter = abs(y.truncatingRemainder(dividingBy: quarterStep)) < epsilon
                    let isEighth = abs(y.truncatingRemainder(dividingBy: eighthStep)) < epsilon
                    let isThreePoint = abs(y.truncatingRemainder(dividingBy: 3.0)) < epsilon
                    if zoomLevel < 3.0 {
                        if isMajor {
                            tickWidth = 16
                            lineWidth = 1.0
                        } else if isHalf {
                            tickWidth = 12
                            lineWidth = 0.75
                        } else if isQuarter {
                            tickWidth = 8
                            lineWidth = 0.6
                        } else if isEighth {
                            tickWidth = 4
                            lineWidth = 0.5
                        } else if isThreePoint {
                            tickWidth = 3
                            lineWidth = 0.5
                        } else {
                            y += tickSpacing
                            continue
                        }
                    } else {
                        if isMajor {
                            tickWidth = 16
                            lineWidth = 1.0
                        } else if abs(y.truncatingRemainder(dividingBy: 6.0)) < epsilon {
                            tickWidth = 12
                            lineWidth = 0.75
                        } else if abs(y.truncatingRemainder(dividingBy: 3.0)) < epsilon {
                            tickWidth = 8
                            lineWidth = 0.6
                        } else if abs(y.truncatingRemainder(dividingBy: 1.0)) < epsilon {
                            tickWidth = 4
                            lineWidth = 0.5
                        } else {
                            y += tickSpacing
                            continue
                        }
                    }
                } else if unit == .centimeters || unit == .millimeters {
                    let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
                    let mmIndex = Int(round(y / mmPoints))
                    let isCentimeter = (mmIndex % 10 == 0)
                    let isHalfCentimeter = (mmIndex % 5 == 0)
                    let desiredMinorMm = max(1, Int(round(tickSpacing / mmPoints)))
                    let stepMm: Int = (desiredMinorMm % 5 == 0) ? min(desiredMinorMm, 5) : 1
                    loopStep = Double(stepMm) * mmPoints
                    if unit == .centimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    } else if unit == .millimeters {
                        isMajorTick = isCentimeter
                        labelUsesMajor = isCentimeter
                    }
                    if !isCentimeter && !isHalfCentimeter {
                        if mmIndex % desiredMinorMm != 0 {
                            y += loopStep
                            continue
                        }
                    }
                    if isCentimeter {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else if isHalfCentimeter {
                        tickWidth = 10
                        lineWidth = 0.7
                    } else {
                        tickWidth = 6
                        lineWidth = 0.5
                    }
                } else {
                    if isMajorTick {
                        tickWidth = 16
                        lineWidth = 1.0
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 2)) < 0.001 {
                        tickWidth = 12
                        lineWidth = 0.75
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 4)) < 0.001 {
                        tickWidth = 8
                        lineWidth = 0.6
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 8)) < 0.001 {
                        tickWidth = 4
                        lineWidth = 0.5
                    } else if abs(y.truncatingRemainder(dividingBy: pointsPerUnit / 16)) < 0.001 {
                        tickWidth = 3
                        lineWidth = 0.5
                    } else {
                        y += tickSpacing
                        continue
                    }
                }
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: size.width - tickWidth, y: rulerY))
                        path.addLine(to: CGPoint(x: size.width, y: rulerY))
                    },
                    with: .color(.primary),
                    lineWidth: lineWidth
                )
                if labelUsesMajor {
                    var labelText: String
                    if unit == .millimeters {
                        let mmValue = ((y - pageOrigin.y) / MeasurementUnit.millimeters.pointsPerUnit).rounded()
                        let mmInt = Int(mmValue)
                        labelText = String(mmInt)
                    } else {
                        let value = (y - pageOrigin.y) / pointsPerUnit
                        labelText = formatRulerValue(value, unit: unit)
                    }
                    let text = Text(labelText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.ui.primaryText)
                    var rotatedContext = context
                    rotatedContext.rotate(by: .degrees(-90))
                    let offsetX: CGFloat = 3
                    rotatedContext.draw(text, at: CGPoint(x: -rulerY + offsetX, y: size.width - 14), anchor: .leading)
                }
            }
            y += loopStep
        }
    }
}

private func getMajorTickInterval(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    switch unit {
    case .pixels, .points:
        if zoomLevel >= 1.0 {
            return 50.0
        } else if zoomLevel >= 0.5 {
            return 100.0
        } else if zoomLevel >= 0.25 {
            return 200.0
        } else {
            return 400.0
        }
    case .inches:
        return pointsPerUnit
    case .centimeters:
        return pointsPerUnit
    case .millimeters:
        return pointsPerUnit * 10
    case .picas:
        if zoomLevel >= 4.0 {
            return pointsPerUnit * 1
        } else if zoomLevel >= 2.0 {
            return pointsPerUnit * 2
        } else if zoomLevel >= 1.0 {
            return pointsPerUnit * 4
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit * 8
        } else {
            return pointsPerUnit * 16
        }
    }
}

private func calculateTickSpacing(for unit: MeasurementUnit, zoomLevel: Double) -> Double {
    let pointsPerUnit = unit.pointsPerUnit
    switch unit {
    case .pixels, .points:
        if zoomLevel >= 1.0 {
            return 12.5
        } else if zoomLevel >= 0.5 {
            return 25.0
        } else if zoomLevel >= 0.25 {
            return 50.0
        } else {
            return 100.0
        }
    case .inches:
        if zoomLevel >= 1.0 {
            return pointsPerUnit / 16
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit / 8
        } else if zoomLevel >= 0.33 {
            return pointsPerUnit / 4
        } else if zoomLevel >= 0.25 {
            return pointsPerUnit / 2
        } else {
            return pointsPerUnit * 2
        }
    case .centimeters:
        let mmPoints = MeasurementUnit.millimeters.pointsPerUnit
        if zoomLevel >= 1.0 {
            return mmPoints * 1
        } else if zoomLevel >= 0.75 {
            return mmPoints * 2
        } else if zoomLevel >= 0.5 {
            return mmPoints * 4
        } else if zoomLevel >= 0.24 {
            return mmPoints * 12
        } else {
            return mmPoints * 16
        }
    case .millimeters:
        if zoomLevel >= 1.0 {
            return pointsPerUnit * 1
        } else if zoomLevel >= 0.75 {
            return pointsPerUnit * 2
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit * 4
        } else if zoomLevel >= 0.24 {
            return pointsPerUnit * 12
        } else {
            return pointsPerUnit * 16
        }
    case .picas:
        if zoomLevel >= 4.0 {
            return 1.0
        } else if zoomLevel >= 2.0 {
            return 1.0
        } else if zoomLevel >= 1.0 {
            return 1.0
        } else if zoomLevel >= 0.5 {
            return pointsPerUnit
        } else {
            return pointsPerUnit * 2
        }
    }
}

private func formatRulerValue(_ value: Double, unit: MeasurementUnit) -> String {
    let roundedValue = value.rounded()
    if abs(roundedValue) < 0.01 {
        return "0"
    }
    switch unit {
    case .inches:
        return String(format: "%.0f", roundedValue)
    case .centimeters:
        return String(format: "%.0f", roundedValue)
    case .millimeters:
        return String(format: "%.0f", roundedValue)
    case .points:
        return String(format: "%.0f", roundedValue)
    case .pixels:
        return String(format: "%.0f", roundedValue)
    case .picas:
        return String(format: "%.0f", roundedValue)
    }
}

extension VectorDocument {

    func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard gridSettings.snapToGrid else { return point }
        let gridSpacing = settings.gridSpacing * settings.unit.pointsPerUnit
        guard gridSpacing > 0 else { return point }
        let snappedX = round(point.x / gridSpacing) * gridSpacing
        let snappedY = round(point.y / gridSpacing) * gridSpacing
        return CGPoint(x: snappedX, y: snappedY)
    }

    func snapToGuidelines(_ point: CGPoint, snapDistance: CGFloat = 5.0) -> CGPoint {
        let guidesLayerVisible = snapshot.layers.count > 2 && snapshot.layers[2].isVisible
        guard gridSettings.snapToGuides && guidesLayerVisible else { return point }
        var snappedPoint = point
        var didSnapX = false
        var didSnapY = false

        let guideShapes = getShapesForLayer(2).filter { $0.isGuide }
        for shape in guideShapes {
            guard let orientation = shape.guideOrientation else { continue }
            let position: CGFloat
            if let firstElement = shape.path.elements.first,
               case .move(let pt) = firstElement {
                switch orientation {
                case .horizontal:
                    position = CGFloat(pt.y)
                case .vertical:
                    position = CGFloat(pt.x)
                }
            } else {
                continue
            }
            switch orientation {
            case .horizontal:
                if !didSnapY && abs(point.y - position) < snapDistance {
                    snappedPoint.y = position
                    didSnapY = true
                }
            case .vertical:
                if !didSnapX && abs(point.x - position) < snapDistance {
                    snappedPoint.x = position
                    didSnapX = true
                }
            }
            if didSnapX && didSnapY {
                break
            }
        }
        return snappedPoint
    }

    func snapPoint(_ point: CGPoint, snapDistance: CGFloat = 5.0) -> CGPoint {
        var result = point
        result = snapToGuidelines(result, snapDistance: snapDistance)
        result = snapToGrid(result)
        return result
    }
}

struct UnitsConverter {

    static func convert(value: Double, from: MeasurementUnit, to: MeasurementUnit) -> Double {
        if from == to { return value }
        let points = value * from.pointsPerUnit
        return points / to.pointsPerUnit
    }

    static func formatValue(_ value: Double, unit: MeasurementUnit) -> String {
        let convertedValue = value / unit.pointsPerUnit
        switch unit {
        case .inches:
            return String(format: "%.3f in", convertedValue)
        case .centimeters:
            return String(format: "%.2f cm", convertedValue)
        case .millimeters:
            return String(format: "%.1f mm", convertedValue)
        case .points:
            return String(format: "%.0f pt", convertedValue)
        case .pixels:
            return String(format: "%.0f px", convertedValue)
        case .picas:
            return String(format: "%.2f pc", convertedValue)
        }
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    var x = abs(a)
    var y = abs(b)
    while y != 0 {
        let r = x % y
        x = y
        y = r
    }
    return max(1, x)
}

struct PageOriginCrosshair: View {

    @ObservedObject var document: VectorDocument

    let geometry: GeometryProxy
    let rulerThickness: CGFloat
    let zoomLevel: Double
    let canvasOffset: CGPoint

    @State private var isDragging = false
    @State private var currentDragLocation: CGPoint?
    var body: some View {
        ZStack {
            CrosshairIcon()
                .frame(width: rulerThickness, height: rulerThickness)
                .position(x: rulerThickness / 2, y: rulerThickness / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let adjustedLocation = CGPoint(
                                x: value.location.x + rulerThickness / 2,
                                y: value.location.y + rulerThickness / 2
                            )
                            currentDragLocation = adjustedLocation
                        }
                        .onEnded { value in
                            isDragging = false
                            currentDragLocation = nil
                            let adjustedLocation = CGPoint(
                                x: value.location.x + rulerThickness / 2,
                                y: value.location.y + rulerThickness / 2
                            )
                            updatePageOrigin(screenLocation: adjustedLocation)
                        }
                )
            if isDragging, let dragLocation = currentDragLocation {
                let snappedLocation = getSnappedScreenLocation(dragLocation)
                ForEach(getSnapPointsInScreenSpace(), id: \.debugDescription) { point in
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .position(point)
                }
                Path { path in
                    path.move(to: CGPoint(x: snappedLocation.x, y: 0))
                    path.addLine(to: CGPoint(x: snappedLocation.x, y: geometry.size.height))
                }
                .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5]))
                Path { path in
                    path.move(to: CGPoint(x: snappedLocation.x, y: 0))
                    path.addLine(to: CGPoint(x: snappedLocation.x, y: geometry.size.height))
                }
                .stroke(Color(white: 0.3), style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5], dashPhase: 5))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: snappedLocation.y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: snappedLocation.y))
                }
                .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5]))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: snappedLocation.y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: snappedLocation.y))
                }
                .stroke(Color(white: 0.3), style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [5, 5], dashPhase: 5))
            }
        }
    }

    private func screenToCanvasPosition(_ screenPoint: CGPoint) -> CGPoint {
        let canvasScreenPoint = CGPoint(
            x: screenPoint.x - rulerThickness,
            y: screenPoint.y - rulerThickness
        )
        return CGPoint(
            x: (canvasScreenPoint.x - canvasOffset.x) / zoomLevel,
            y: (canvasScreenPoint.y - canvasOffset.y) / zoomLevel
        )
    }

    private func canvasToScreenPosition(_ canvasPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: canvasPoint.x * zoomLevel + canvasOffset.x,
            y: canvasPoint.y * zoomLevel + canvasOffset.y
        )
    }

    private func applySnapToCanvasPoint(_ canvasPoint: CGPoint) -> CGPoint {
        let canvasWidth = document.settings.sizeInPoints.width
        let canvasHeight = document.settings.sizeInPoints.height
        let snapThreshold: CGFloat = 10.0
        let snapPoints: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: canvasWidth, y: 0),
            CGPoint(x: 0, y: canvasHeight),
            CGPoint(x: canvasWidth, y: canvasHeight),
            CGPoint(x: canvasWidth / 2, y: 0),
            CGPoint(x: canvasWidth / 2, y: canvasHeight),
            CGPoint(x: 0, y: canvasHeight / 2),
            CGPoint(x: canvasWidth, y: canvasHeight / 2),
            CGPoint(x: canvasWidth / 2, y: canvasHeight / 2)
        ]
        var closestPoint: CGPoint?
        var closestDistance: CGFloat = snapThreshold
        for snapPoint in snapPoints {
            let distance = hypot(canvasPoint.x - snapPoint.x, canvasPoint.y - snapPoint.y)
            if distance < closestDistance {
                closestDistance = distance
                closestPoint = snapPoint
            }
        }
        return closestPoint ?? canvasPoint
    }

    private func getSnappedScreenLocation(_ screenPoint: CGPoint) -> CGPoint {
        let canvasPoint = screenToCanvasPosition(screenPoint)
        let snappedCanvasPoint = applySnapToCanvasPoint(canvasPoint)
        return canvasToScreenPosition(snappedCanvasPoint)
    }

    private func getSnapPointsInScreenSpace() -> [CGPoint] {
        let canvasWidth = document.settings.sizeInPoints.width
        let canvasHeight = document.settings.sizeInPoints.height
        let canvasSnapPoints: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: canvasWidth, y: 0),
            CGPoint(x: 0, y: canvasHeight),
            CGPoint(x: canvasWidth, y: canvasHeight),
            CGPoint(x: canvasWidth / 2, y: 0),
            CGPoint(x: canvasWidth / 2, y: canvasHeight),
            CGPoint(x: 0, y: canvasHeight / 2),
            CGPoint(x: canvasWidth, y: canvasHeight / 2),
            CGPoint(x: canvasWidth / 2, y: canvasHeight / 2)
        ]
        return canvasSnapPoints.map { canvasToScreenPosition($0) }
    }

    private func updatePageOrigin(screenLocation: CGPoint) {
        let canvasPoint = screenToCanvasPosition(screenLocation)
        let snappedCanvasPoint = applySnapToCanvasPoint(canvasPoint)
        document.settings.pageOrigin = snappedCanvasPoint
        document.onSettingsChanged()
    }
}

struct CrosshairIcon: View {

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.ui.controlBackground)
                Path { path in
                    let padding: CGFloat = 1
                    path.move(to: CGPoint(x: padding, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width - padding, y: geometry.size.height / 2))
                    path.move(to: CGPoint(x: geometry.size.width / 2, y: padding))
                    path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - padding))
                }
                .stroke(Color.gray, style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [1, 1]))
                Rectangle()
                    .stroke(Color.ui.lightGrayBorder, lineWidth: 0.5)
            }
        }
        .contentShape(Rectangle())
    }
}

extension CGSize {

    var asCGPoint: CGPoint {
        CGPoint(x: width, y: height)
    }
}

extension CGPoint {

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        lhs.adding(rhs)
    }
}
