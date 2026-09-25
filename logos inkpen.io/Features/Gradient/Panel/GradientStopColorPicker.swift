import SwiftUI

struct GradientStopColorPicker: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument
    let stopColor: VectorColor
    let currentGradient: VectorGradient
    let activeColorTarget: ColorTarget
    let onColorChanged: (VectorColor) -> Void
    let onDismiss: () -> Void

    @State private var currentColor: VectorColor
    @State private var isDismissing = false
    init(snapshot: DocumentSnapshot, selectedObjectIDs: Set<UUID>, document: VectorDocument, stopColor: VectorColor, currentGradient: VectorGradient, activeColorTarget: ColorTarget, onColorChanged: @escaping (VectorColor) -> Void, onDismiss: @escaping () -> Void) {
        self.snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self.document = document
        self.stopColor = stopColor
        self.currentGradient = currentGradient
        self.activeColorTarget = activeColorTarget
        self.onColorChanged = onColorChanged
        self.onDismiss = onDismiss
        self._currentColor = State(initialValue: stopColor)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            loadedContent
            GlassCloseButton(action: onDismiss)
        }
        .frame(width: 300, height: 480)
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
                .frame(height: 8)
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Color Mode", selection: Binding(
                        get: { document.settings.colorMode },
                        set: { newMode in
                            let oldMode = document.settings.colorMode
                            document.settings.colorMode = newMode
                            currentColor = convertColorToMode(currentColor, from: oldMode, to: newMode)
                        }
                    )) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.iconName)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                if document.settings.colorMode == .pms {
                    HSBInputSection(
                        sharedColor: $currentColor,
                        activeColorTarget: activeColorTarget,
                        defaultFillColor: .constant(.black),
                        defaultStrokeColor: .constant(.black),
                        colorDeltaColor: .constant(nil),
                        onSetActiveColor: { color in document.setActiveColor(color) },
                        onAddColorSwatch: { color in document.addColorSwatch(color) },
                        disableSetActiveColor: true,
                        onDismiss: onDismiss
                    )
                    .padding(.horizontal, 12)
                } else if document.settings.colorMode == .cmyk {
                    CMYKInputSection(
                        sharedColor: $currentColor,
                        activeColorTarget: activeColorTarget,
                        defaultFillColor: .constant(.black),
                        defaultStrokeColor: .constant(.black),
                        colorDeltaColor: .constant(nil),
                        onSetActiveColor: { color in document.setActiveColor(color) },
                        onAddColorSwatch: { color in document.addColorSwatch(color) },
                        onColorSelected: nil,
                        disableSetActiveColor: true,
                        onDismiss: onDismiss
                    )
                    .padding(.horizontal, 12)
                } else if document.settings.colorMode == .rgb {
                    RGBInputSection(
                        snapshot: Binding(
                            get: { document.snapshot },
                            set: { document.snapshot = $0 }
                        ),
                        selectedObjectIDs: selectedObjectIDs,
                        activeColorTarget: activeColorTarget,
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
                        onTriggerLayerUpdates: { indices in
                            document.triggerLayerUpdates(for: indices)
                        },
                        onAddColorSwatch: { color in
                            document.addColorSwatch(color)
                        },
                        onSetActiveColor: { color in
                            document.setActiveColor(color)
                        },
                        colorDeltaColor: .constant(nil),
                        colorDeltaOpacity: .constant(nil),
                        sharedColor: $currentColor,
                        disableSetActiveColor: true,
                        onDismiss: onDismiss
                    )
                        .padding(.horizontal, 12)
                }
                HStack {
                    Text(colorModeDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 8), spacing: 4) {
                        ForEach(Array(document.currentSwatches.prefix(40).enumerated()), id: \.offset) { index, color in
                            Button {
                                currentColor = color
                                onColorChanged(color)
                            } label: {
                                ZStack {
                                    renderColorSwatchRightPanel(color, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)
                                    if case .pantone = color {
                                        overlayText(for: color)
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help(colorDescription(for: color))
                        }
                    }
                    .padding(.horizontal, 12)
                }
                Spacer()
            }
            .onChange(of: currentColor) { _, newColor in
                if !isDismissing {
                    onColorChanged(newColor)
                }
            }
            .onChange(of: stopColor) { _, newStopColor in
                currentColor = newStopColor
            }
    }

    private var colorModeDescription: String {
        switch document.settings.colorMode {
        case .rgb:
            return "RGB colors for screen display"
        case .cmyk:
            return "CMYK colors for print production"
        case .pms:
            return "PMS colors with Pantone matching"
        }
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

    private func overlayText(for color: VectorColor) -> some View {
        Group {
            if case .pantone(let pantone) = color {
                Text(pantone.pantone)
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1)
                    .frame(width: 30, height: 30)
                    .allowsTightening(true)
            }
        }
    }

    private func convertColorToMode(_ color: VectorColor, from oldMode: ColorMode, to newMode: ColorMode) -> VectorColor {
        if oldMode == newMode {
            return color
        }
        let rgbColor: RGBColor
        switch color {
        case .rgb(let rgb):
            rgbColor = rgb
        case .cmyk(let cmyk):
            rgbColor = RGBColor(
                red: (1 - cmyk.cyan) * (1 - cmyk.black),
                green: (1 - cmyk.magenta) * (1 - cmyk.black),
                blue: (1 - cmyk.yellow) * (1 - cmyk.black)
            )
        case .hsb(let hsb):
            let c = hsb.brightness * hsb.saturation
            let x = c * (1 - abs(((hsb.hue / 60).truncatingRemainder(dividingBy: 2)) - 1))
            let m = hsb.brightness - c

            var r: Double = 0, g: Double = 0, b: Double = 0
            if hsb.hue < 60 { r = c; g = x; b = 0 }
            else if hsb.hue < 120 { r = x; g = c; b = 0 }
            else if hsb.hue < 180 { r = 0; g = c; b = x }
            else if hsb.hue < 240 { r = 0; g = x; b = c }
            else if hsb.hue < 300 { r = x; g = 0; b = c }
            else { r = c; g = 0; b = x }
            rgbColor = RGBColor(red: r + m, green: g + m, blue: b + m)
        default:
            return color
        }
        switch newMode {
        case .rgb:
            return .rgb(rgbColor)
        case .cmyk:
            let k = 1 - max(rgbColor.red, rgbColor.green, rgbColor.blue)
            if k == 1 {
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1))
            }
            let c = (1 - rgbColor.red - k) / (1 - k)
            let m = (1 - rgbColor.green - k) / (1 - k)
            let y = (1 - rgbColor.blue - k) / (1 - k)
            return .cmyk(CMYKColor(cyan: c, magenta: m, yellow: y, black: k))
        case .pms:
            let maxVal = max(rgbColor.red, rgbColor.green, rgbColor.blue)
            let minVal = min(rgbColor.red, rgbColor.green, rgbColor.blue)
            let delta = maxVal - minVal

            var hue: Double = 0
            if delta != 0 {
                if maxVal == rgbColor.red {
                    hue = 60 * (((rgbColor.green - rgbColor.blue) / delta).truncatingRemainder(dividingBy: 6))
                } else if maxVal == rgbColor.green {
                    hue = 60 * (((rgbColor.blue - rgbColor.red) / delta) + 2)
                } else {
                    hue = 60 * (((rgbColor.red - rgbColor.green) / delta) + 4)
                }
            }
            if hue < 0 { hue += 360 }
            let saturation = maxVal == 0 ? 0 : delta / maxVal
            return .hsb(HSBColorModel(hue: hue, saturation: saturation, brightness: maxVal))
        }
    }
}
