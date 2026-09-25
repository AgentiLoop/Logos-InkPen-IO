import SwiftUI

struct ColorSwatchGrid: View {

    @ObservedObject var document: VectorDocument

    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor

    @State private var showingColorPicker = false
    @State private var showingCustomColorPopover = false

    let columns = [
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1)
    ]

    private var currentFillColor: VectorColor {
        if let firstSelectedObjectID = document.viewState.selectedObjectIDs.first,

           let object = document.findObject(by: firstSelectedObjectID) {
            switch object.objectType {
            case .text(let shape):
                if let typography = shape.typography {
                    return typography.fillColor
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.color
                }
            }
        }
        return defaultFillColor
    }

    private var currentStrokeColor: VectorColor {
        if let firstSelectedObjectID = document.viewState.selectedObjectIDs.first,

           let object = document.findObject(by: firstSelectedObjectID) {
            switch object.objectType {
            case .text(let shape):
                if let typography = shape.typography, typography.hasStroke {
                    return typography.strokeColor
                } else {
                    return .clear
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if let strokeStyle = shape.strokeStyle {
                    return strokeStyle.color
                } else {
                    return .clear
                }
            }
        }
        return defaultStrokeColor
    }

    private var currentFillOpacity: Double {
        if let firstSelectedObjectID = document.viewState.selectedObjectIDs.first,

           let object = document.findObject(by: firstSelectedObjectID) {
            switch object.objectType {
            case .text(let shape):
                if let typography = shape.typography {
                    return typography.fillOpacity
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.opacity
                }
            }
        }
        return document.defaultFillOpacity
    }

    private var currentStrokeOpacity: Double {
        if let firstSelectedObjectID = document.viewState.selectedObjectIDs.first,

           let object = document.findObject(by: firstSelectedObjectID) {
            switch object.objectType {
            case .text(let shape):
                if let typography = shape.typography {
                    return typography.strokeOpacity
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if let strokeStyle = shape.strokeStyle {
                    return strokeStyle.opacity
                }
            }
        }
        return document.defaultStrokeOpacity
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Button {
                    document.viewState.activeColorTarget = .stroke
                } label: {
                    if case .clear = currentStrokeColor {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)
                            if document.viewState.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentStrokeColor {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
                            GradientSwatchCanvas(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)
                            if document.viewState.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
                            Rectangle()
                                .fill(currentStrokeColor.color.opacity(currentStrokeOpacity))
                                .frame(width: 22, height: 22)
                            if document.viewState.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
                .help("Current Stroke Color (Opacity: \(Int(currentStrokeOpacity * 100))%) - Click to make active")
                .offset(x: 6, y: 6)
                Button {
                    document.viewState.activeColorTarget = .fill
                } label: {
                    if case .clear = currentFillColor {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)
                            if document.viewState.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentFillColor {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
                            GradientSwatchCanvas(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)
                            if document.viewState.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
                            Rectangle()
                                .fill(currentFillColor.color.opacity(currentFillOpacity))
                                .frame(width: 22, height: 22)
                            if document.viewState.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
                .help("Current Fill Color (Opacity: \(Int(currentFillOpacity * 100))%) - Click to make active")
                .offset(x: -6, y: -6)
            }
			.frame(width: 28, height: 28)
            .padding(.bottom, 6)
            .padding(.top, 8)
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.currentSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        document.setActiveColor(color)
                    } label: {
                        ZStack {
                            if case .clear = color {
                                ZStack {
                                    CheckerboardPattern(size: 2)
                                        .frame(width: 10, height: 10)
                                        .clipped()
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 10, height: 10)
                                        .border(Color.gray, width: 0.5)
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 10, y: 10))
                                    }
                                    .stroke(Color.red, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                }
                            } else if case .gradient(let gradient) = color {
                                GradientSwatchCanvas(gradient: gradient, size: 10)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            } else {
                                Rectangle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("\(colorDescription(for: color)) (Click to apply to \(document.viewState.activeColorTarget == .fill ? "fill" : "stroke"))")
                }
            }
            .padding(.horizontal, 2)
            Button {
                showingCustomColorPopover.toggle()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Add Custom Color")
            .popover(isPresented: $showingCustomColorPopover, arrowEdge: .trailing) {
                customColorPanel
            }
        }
    }

    @ViewBuilder
    private var customColorPanel: some View {
        ColorPanel(
            snapshot: Binding(
                get: { document.snapshot },
                set: { document.snapshot = $0 }
            ),
            selectedObjectIDs: document.viewState.selectedObjectIDs,
            activeColorTarget: Binding(
                get: { document.viewState.activeColorTarget },
                set: { document.viewState.activeColorTarget = $0 }
            ),
            colorMode: Binding(
                get: { document.settings.colorMode },
                set: { document.settings.colorMode = $0 }
            ),
            defaultFillColor: Binding(
                get: { document.defaultFillColor },
                set: { document.defaultFillColor = $0 }
            ),
            defaultStrokeColor: Binding(
                get: { document.defaultStrokeColor },
                set: { document.defaultStrokeColor = $0 }
            ),
            defaultFillOpacity: document.defaultFillOpacity,
            defaultStrokeOpacity: document.defaultStrokeOpacity,
            currentSwatches: document.currentSwatches,
            onTriggerLayerUpdates: { indices in document.triggerLayerUpdates(for: indices) },
            onAddColorSwatch: { color in document.addColorSwatch(color) },
            onRemoveColorSwatch: { color in document.removeColorSwatch(color) },
            onSetActiveColor: { color in document.setActiveColor(color) },
            colorDeltaColor: .constant(nil),
            colorDeltaOpacity: .constant(nil),
            onColorSelected: { color in
                document.setActiveColor(color)
            },
            initialColor: (document.viewState.activeColorTarget == .stroke) ? document.documentColorDefaults.strokeColor : document.documentColorDefaults.fillColor,
            onDismiss: {
                showingCustomColorPopover = false
            }
        )
        .frame(width: 300, height: 480)
    }

    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb): return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone): return "Pantone \(pantone.pantone)"
        case .spot(let spot): return "SPOT \(spot.number)"
        case .appleSystem(let systemColor): return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient):
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }
}
