import SwiftUI

struct GradientPreviewAndStopsView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let activeColorTarget: ColorTarget

    @Binding var editingGradientStopId: UUID?
    @Binding var editingGradientStopColor: VectorColor
    @Binding var showingGradientColorPicker: Bool

    let getGradientStops: (VectorGradient) -> [GradientStop]
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let getScale: (VectorGradient) -> Double
    let getAspectRatio: (VectorGradient) -> Double
    let updateOriginX: (Double, Bool) -> Void
    let updateOriginY: (Double, Bool) -> Void
    let updateOriginXOptimized: (Double, Bool, Bool) -> Void
    let updateOriginYOptimized: (Double, Bool, Bool) -> Void
    let updateOriginXY: (Double, Double) -> Void
    let onOriginEditingChanged: (Bool) -> Void
    let addColorStop: () -> Void
    let updateStopPosition: (UUID, Double) -> Void
    let updateStopOpacity: (UUID, Double) -> Void
    let removeColorStop: (UUID) -> Void
    let applyGradientToSelectedShapes: () -> Void
    let applyGradientToSelectedShapesOptimized: (Bool) -> Void
    let activateGradientStop: (UUID, VectorColor) -> Void
    let onStopEditingChanged: (Bool) -> Void

    @State private var popoverStopID: UUID? = nil
    @State private var currentEditingStop: (id: UUID, color: VectorColor)? = nil
    @State private var popoverManager = SlidingPopoverManager()
    @State private var anchorViews: [UUID: NSView] = [:]

    @FocusState private var focusedStopID: UUID?

    @State private var isEditingOpacity: Bool = false

    @Environment(AppState.self) private var appState
    private func createGradientPreview(geometry: GeometryProxy, squareSize: CGFloat) -> some View {
        let liveX = document.viewState.liveGradientOriginX
        let liveY = document.viewState.liveGradientOriginY
        let padding: CGFloat = 8
        let contentSize = CGSize(width: squareSize, height: squareSize)
        return Canvas { context, size in
            context.translateBy(x: padding, y: padding)
            guard let gradient = currentGradient else {
                context.fill(Path(CGRect(origin: .zero, size: contentSize)), with: .color(.gray.opacity(0.3)))
                context.stroke(Path(CGRect(origin: .zero, size: contentSize)), with: .color(Color.ui.lightGrayBorder), lineWidth: 1)
                return
            }
            let originX = liveX ?? getOriginX(gradient)
            let originY = liveY ?? getOriginY(gradient)
            context.withCGContext { cgContext in
                renderGradientToCGContext(gradient: gradient, context: cgContext, size: contentSize, liveOriginX: originX, liveOriginY: originY)
            }
            context.stroke(Path(CGRect(origin: .zero, size: contentSize)), with: .color(Color.ui.lightGrayBorder), lineWidth: 1)
            for i in 0..<5 {
                let position = CGFloat(i) / 4.0
                let xPos = position * contentSize.width
                let yPos = position * contentSize.height
                let isCenter = position == 0.5
                let opacity = isCenter ? 0.9 : 0.3
                let width: CGFloat = isCenter ? 1.0 : 0.5

                var vLine = Path()
                vLine.move(to: CGPoint(x: xPos, y: 0))
                vLine.addLine(to: CGPoint(x: xPos, y: contentSize.height))
                context.stroke(vLine, with: .color(.white.opacity(opacity)), lineWidth: width)
                var hLine = Path()
                hLine.move(to: CGPoint(x: 0, y: yPos))
                hLine.addLine(to: CGPoint(x: contentSize.width, y: yPos))
                context.stroke(hLine, with: .color(.white.opacity(opacity)), lineWidth: width)
            }
            let gridPoints: [(x: CGFloat, y: CGFloat, isCenter: Bool)] = [
                (0, 0, false), (0.5, 0, false), (1, 0, false),
                (0, 0.5, false), (0.5, 0.5, true), (1, 0.5, false),
                (0, 1, false), (0.5, 1, false), (1, 1, false),
                (0.25, 0.25, false), (0.75, 0.25, false),
                (0.25, 0.75, false), (0.75, 0.75, false),
                (0.25, 0.5, false), (0.75, 0.5, false),
                (0.5, 0.25, false), (0.5, 0.75, false)
            ]
            for point in gridPoints {
                let pos = CGPoint(x: point.x * contentSize.width, y: point.y * contentSize.height)
                let circle = Path(ellipseIn: CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12))
                let color = point.isCenter ? Color.green.opacity(0.6) : Color.ui.mediumBlueBackground
                context.fill(circle, with: .color(color))
            }
            let labels: [(text: String, x: CGFloat, y: CGFloat, alignX: CGFloat, alignY: CGFloat)] = [
                ("(0,0)", 12, 12, 0, 0),
                ("(0.5,0)", contentSize.width/2, 12, 0.5, 0),
                ("(1,0)", contentSize.width - 12, 12, 1, 0),
                ("(0,1)", 12, contentSize.height - 12, 0, 1),
                ("(0.5,1)", contentSize.width/2, contentSize.height - 12, 0.5, 1),
                ("(1,1)", contentSize.width - 12, contentSize.height - 12, 1, 1)
            ]
            for label in labels {
                let text = Text(label.text)
                    .font(.caption2)
                    .foregroundColor(Color.ui.white)
                context.draw(text, at: CGPoint(x: label.x, y: label.y), anchor: UnitPoint(x: label.alignX, y: label.alignY))
            }
            let clampedX = max(0.0, min(1.0, originX))
            let clampedY = max(0.0, min(1.0, originY))
            let dotPos = CGPoint(x: clampedX * contentSize.width, y: clampedY * contentSize.height)
            let dotCircle = Path(ellipseIn: CGRect(x: dotPos.x - 4, y: dotPos.y - 4, width: 8, height: 8))
            context.fill(dotCircle, with: .color(.white))
            context.stroke(dotCircle, with: .color(.black), lineWidth: 1)
        }
        .frame(width: squareSize + padding * 2, height: squareSize + padding * 2)
    }

    private func renderGradientToCGContext(gradient: VectorGradient, context: CGContext, size: CGSize, liveOriginX: Double, liveOriginY: Double) {
        context.saveGState()
        let pathBounds = CGRect(origin: .zero, size: size)
        let path = CGPath(rect: pathBounds, transform: nil)
        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                return stop.color.cgColor
            } else {
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        context.addPath(path)
        context.clip()
        switch gradient {
        case .linear(let linear):
            let scale = CGFloat(linear.scaleX)
            let scaledOriginX = liveOriginX * Double(scale)
            let scaledOriginY = liveOriginY * Double(scale)
            let centerX = pathBounds.minX + pathBounds.width * scaledOriginX
            let centerY = pathBounds.minY + pathBounds.height * scaledOriginY
            let gradientAngle = CGFloat(linear.storedAngle * .pi / 180.0)
            let gradientVector = CGPoint(x: linear.endPoint.x - linear.startPoint.x, y: linear.endPoint.y - linear.startPoint.y)
            let gradientLength = sqrt(gradientVector.x * gradientVector.x + gradientVector.y * gradientVector.y)
            let scaledLength = gradientLength * CGFloat(scale) * max(pathBounds.width, pathBounds.height)
            let startX = centerX - cos(gradientAngle) * scaledLength / 2
            let startY = centerY - sin(gradientAngle) * scaledLength / 2
            let endX = centerX + cos(gradientAngle) * scaledLength / 2
            let endY = centerY + sin(gradientAngle) * scaledLength / 2
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .radial(let radial):
            let center = CGPoint(x: pathBounds.minX + pathBounds.width * liveOriginX,
                                 y: pathBounds.minY + pathBounds.height * liveOriginY)
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            let angleRadians = CGFloat(radial.angle * .pi / 180.0)
            context.rotate(by: angleRadians)
            let scaleX = CGFloat(radial.scaleX)
            let scaleY = CGFloat(radial.scaleY)
            context.scaleBy(x: scaleX, y: scaleY)
            let focalPoint: CGPoint
            if let focal = radial.focalPoint {
                focalPoint = CGPoint(x: focal.x, y: focal.y)
            } else {
                focalPoint = CGPoint.zero
            }
            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)
            context.drawRadialGradient(cgGradient, startCenter: focalPoint, startRadius: 0, endCenter: CGPoint.zero, endRadius: radius, options: [.drawsAfterEndLocation])
            context.restoreGState()
        }
        context.restoreGState()
    }

    @State private var dragStartGradient: VectorGradient? = nil
    @State private var dragStartOpacities: [UUID: Double] = [:]
    @State private var isDragging = false
    @State private var dragTranslation: CGSize = .zero
    @State private var isColorPickerOpen = false
    @State private var isColorPickerDismissing = false
    private func showPopoverForStop(_ stop: GradientStop) {
        guard let anchorView = anchorViews[stop.id], let gradient = currentGradient else { return }
        if !isColorPickerOpen {
            onStopEditingChanged(true)
            isColorPickerOpen = true
        }
        let popoverContent = GradientStopColorPicker(
            snapshot: document.snapshot,
            selectedObjectIDs: document.viewState.selectedObjectIDs,
            document: document,
            stopColor: stop.color,
            currentGradient: gradient,
            activeColorTarget: activeColorTarget,
            onColorChanged: { color in
                guard !isColorPickerDismissing else { return }
                activateGradientStop(stop.id, color)
            },
            onDismiss: {
                onStopEditingChanged(false)
                isColorPickerOpen = false
                popoverManager.dismiss()
                popoverStopID = nil
            }
        )
        .frame(width: 300, height: 480)
        .environment(appState)
        popoverManager.show(
            content: popoverContent,
            anchorView: anchorView,
            edge: .leading,
            onDismiss: {
                guard !isColorPickerDismissing else { return }
                isColorPickerDismissing = true
                onStopEditingChanged(false)
                isColorPickerOpen = false
                popoverStopID = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isColorPickerDismissing = false
                }
            }
        )
        popoverStopID = stop.id
    }
    private let snapPoints: [(x: CGFloat, y: CGFloat)] = [
        (0, 0), (0.5, 0), (1, 0),
        (0, 0.5), (0.5, 0.5), (1, 0.5),
        (0, 1), (0.5, 1), (1, 1),
        (0.25, 0.25), (0.75, 0.25),
        (0.25, 0.75), (0.75, 0.75),
        (0.25, 0.5), (0.75, 0.5),
        (0.5, 0.25), (0.5, 0.75)
    ]

    private func findSnapPoint(for location: CGPoint, squareSize: CGFloat, padding: CGFloat, snapRadius: CGFloat) -> (x: CGFloat, y: CGFloat)? {
        for point in snapPoints {
            let pointPos = CGPoint(x: point.x * squareSize + padding, y: point.y * squareSize + padding)
            let snapDistance = location.distance(to: pointPos)
            if snapDistance <= snapRadius {
                return point
            }
        }
        return nil
    }

    private func createPreviewContent(geometry: GeometryProxy) -> some View {
        let padding: CGFloat = 8
        let fullWidth = geometry.size.width
        let squareSize = fullWidth - (padding * 2)
        return createGradientPreview(geometry: geometry, squareSize: squareSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragTranslation = .zero
                            dragStartGradient = currentGradient
                            for objectID in document.viewState.selectedObjectIDs {
                                if let shape = document.findShape(by: objectID) {
                                    dragStartOpacities[objectID] = shape.fillStyle?.opacity ?? 1.0
                                }
                            }
                            onOriginEditingChanged(true)
                        }
                        dragTranslation = value.translation
                        let snapRadius: CGFloat = 6.0

                        var finalX: Double
                        var finalY: Double
                        if let snapPoint = findSnapPoint(for: value.location, squareSize: squareSize, padding: padding, snapRadius: snapRadius) {
                            finalX = snapPoint.x
                            finalY = snapPoint.y
                        } else {
                            finalX = max(0.0, min(1.0, (value.location.x - padding) / squareSize))
                            finalY = max(0.0, min(1.0, (value.location.y - padding) / squareSize))
                        }
                        updateOriginXY(finalX, finalY)
                    }
                    .onEnded { value in
                        isDragging = false
                        onOriginEditingChanged(false)
                        dragStartGradient = nil
                        dragStartOpacities.removeAll()
                    }
            )
    }

    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                GeometryReader { geometry in
                    createPreviewContent(geometry: geometry)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.bottom, 12)
                let stops = currentGradient.map { getGradientStops($0).sorted { $0.position < $1.position } } ?? []
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Color Stops")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("%")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                            .frame(width: 40, alignment: .center)
                        Text("Opaq")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                            .frame(width: 40, alignment: .center)
                        Button(action: addColorStop) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(width: 16)
                    }
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            ZStack {
                                Button(action: {
                                    if popoverStopID == stop.id {
                                        popoverManager.dismiss()
                                        popoverStopID = nil
                                    } else {
                                        showPopoverForStop(stop)
                                    }
                                }) {
                                    renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 0, borderWidth: 1, opacity: stop.opacity)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .onHover { hovering in
                                    if hovering && popoverManager.isShown && popoverStopID != stop.id {
                                        showPopoverForStop(stop)
                                    }
                                }
                                .background(
                                    PopoverAnchorView { view in
                                        anchorViews[stop.id] = view
                                    }
                                )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Slider(value: Binding(
                                        get: { stop.position },
                                        set: { updateStopPosition(stop.id, $0) }
                                    ), in: 0...1, onEditingChanged: onStopEditingChanged)
                                    .controlSize(.regular)
                                    TextField("", text: Binding(
                                        get: {
                                            let percentage = stop.position * 100
                                            return percentage.truncatingRemainder(dividingBy: 1) == 0 ?
                                                String(format: "%.0f", percentage) :
                                                String(format: "%.1f", percentage)
                                        },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                let clamped = max(0, min(100, doubleValue))
                                                updateStopPosition(stop.id, clamped / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                    TextField("", text: Binding(
                                        get: {
                                            let percentage = stop.opacity * 100
                                            return percentage.truncatingRemainder(dividingBy: 1) == 0 ?
                                                String(format: "%.0f", percentage) :
                                                String(format: "%.1f", percentage)
                                        },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                let clamped = max(0, min(100, doubleValue))
                                                updateStopOpacity(stop.id, clamped / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                    .focused($focusedStopID, equals: stop.id)
                                }
                            }
                            Button(action: {
                                if stops.count > 2 {
                                    removeColorStop(stop.id)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.ui.errorColor)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .onChange(of: focusedStopID) { oldValue, newValue in
                if newValue != nil && oldValue == nil && !isEditingOpacity {
                    isEditingOpacity = true
                    onStopEditingChanged(true)
                }
                else if newValue == nil && oldValue != nil && isEditingOpacity {
                    isEditingOpacity = false
                    onStopEditingChanged(false)
                }
            }
        }
    }
}
