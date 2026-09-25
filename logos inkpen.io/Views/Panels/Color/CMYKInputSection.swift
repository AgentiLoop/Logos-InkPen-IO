import SwiftUI

struct CMYKInputSection: View {

    @Binding var sharedColor: VectorColor

    let activeColorTarget: ColorTarget

    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor
    @Binding var colorDeltaColor: VectorColor?

    let onSetActiveColor: (VectorColor) -> Void
    let onAddColorSwatch: (VectorColor) -> Void
    let onColorSelected: ((VectorColor) -> Void)?
    let disableSetActiveColor: Bool
    let onDismiss: (() -> Void)?

    init(sharedColor: Binding<VectorColor>, activeColorTarget: ColorTarget, defaultFillColor: Binding<VectorColor>, defaultStrokeColor: Binding<VectorColor>, colorDeltaColor: Binding<VectorColor?>, onSetActiveColor: @escaping (VectorColor) -> Void, onAddColorSwatch: @escaping (VectorColor) -> Void, onColorSelected: ((VectorColor) -> Void)? = nil, disableSetActiveColor: Bool = false, onDismiss: (() -> Void)? = nil) {
        self._sharedColor = sharedColor
        self.activeColorTarget = activeColorTarget
        self._defaultFillColor = defaultFillColor
        self._defaultStrokeColor = defaultStrokeColor
        self._colorDeltaColor = colorDeltaColor
        self.onSetActiveColor = onSetActiveColor
        self.onAddColorSwatch = onAddColorSwatch
        self.onColorSelected = onColorSelected
        self.disableSetActiveColor = disableSetActiveColor
        self.onDismiss = onDismiss
    }

    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    @State private var cyanSlider: Double = 0
    @State private var magentaSlider: Double = 0
    @State private var yellowSlider: Double = 0
    @State private var blackSlider: Double = 0
    @State private var isProgrammaticallyUpdating: Bool = false
    @State private var isDisplayingGradient: Bool = false
    private var currentColor: CMYKColor {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        return CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }

    private func swiftUIColorFromCMYK(c: Double, m: Double, y: Double, k: Double) -> Color {
        let cmykColor = CMYKColor(cyan: c/100.0, magenta: m/100.0, yellow: y/100.0, black: k/100.0)
        return cmykColor.color
    }

    private var cyanGradient: SwiftUI.LinearGradient {
        let m = Double(magentaValue) ?? 0
        let y = Double(yellowValue) ?? 0
        let k = Double(blackValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: 0, m: m, y: y, k: k),
                swiftUIColorFromCMYK(c: 100, m: m, y: y, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var magentaGradient: SwiftUI.LinearGradient {
        let c = Double(cyanValue) ?? 0
        let y = Double(yellowValue) ?? 0
        let k = Double(blackValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: 0, y: y, k: k),
                swiftUIColorFromCMYK(c: c, m: 100, y: y, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var yellowGradient: SwiftUI.LinearGradient {
        let c = Double(cyanValue) ?? 0
        let m = Double(magentaValue) ?? 0
        let k = Double(blackValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: m, y: 0, k: k),
                swiftUIColorFromCMYK(c: c, m: m, y: 100, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var blackGradient: SwiftUI.LinearGradient {
        let c = Double(cyanValue) ?? 0
        let m = Double(magentaValue) ?? 0
        let y = Double(yellowValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: m, y: y, k: 0),
                swiftUIColorFromCMYK(c: c, m: m, y: y, k: 100)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 12, height: 12)
                    Text("C")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        Capsule()
                            .fill(cyanGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $cyanSlider, in: 0...100)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: cyanSlider) {
                                cyanValue = String(Int(cyanSlider))
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $cyanValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: cyanValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(cyanValue) {
                                cyanSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 12, height: 12)
                    Text("M")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        Capsule()
                            .fill(magentaGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $magentaSlider, in: 0...100)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: magentaSlider) {
                                magentaValue = String(Int(magentaSlider))
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $magentaValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: magentaValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(magentaValue) {
                                magentaSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12)
                    Text("Y")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        Capsule()
                            .fill(yellowGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $yellowSlider, in: 0...100)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: yellowSlider) {
                                yellowValue = String(Int(yellowSlider))
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $yellowValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: yellowValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(yellowValue) {
                                yellowSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 12, height: 12)
                    Text("K")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        Capsule()
                            .fill(blackGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $blackSlider, in: 0...100)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: blackSlider) {
                                blackValue = String(Int(blackSlider))
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $blackValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: blackValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(blackValue) {
                                blackSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
            }
            HStack(spacing: 8) {
                Button(action: {
                    applyColorToActiveSelection()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        onDismiss?()
                    }
                }) {
                Rectangle()
                        .fill(currentColor.color)
                        .frame(width: 30, height: 30)
                    .overlay(
                        Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Click to apply color to active fill or stroke")
                VStack(alignment: .leading, spacing: 2) {
                    Text("CMYK(\(Int(currentColor.cyan * 100)), \(Int(currentColor.magenta * 100)), \(Int(currentColor.yellow * 100)), \(Int(currentColor.black * 100)))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                    Button("Add Swatch") {
                        addCMYKColorToSwatches()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadFromSharedColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadFromSharedColor()
        }
    }

    private func updateSharedColor() {
        if isDisplayingGradient {
            return
        }
        let cmykColor = VectorColor.cmyk(currentColor)
        sharedColor = cmykColor
        if isProgrammaticallyUpdating {
            return
        }
        colorDeltaColor = cmykColor
        if activeColorTarget == .fill {
            defaultFillColor = cmykColor
        } else {
            defaultStrokeColor = cmykColor
        }
    }

    private func loadFromSharedColor() {
        isDisplayingGradient = false
        switch sharedColor {
        case .rgb(let rgb):
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .cmyk(let cmyk):
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .hsb(let hsb):
            let rgb = hsb.rgbColor
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .pantone(let pantone):
            let cmyk = pantone.cmykEquivalent
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .spot(let spot):
            let cmyk = spot.cmykEquivalent
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .appleSystem(let system):
            let rgb = system.rgbEquivalent
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .gradient(let gradient):
            isDisplayingGradient = true
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .cmyk(let cmyk):
                    setCMYKValues(
                        cyan: Int(cmyk.cyan * 100),
                        magenta: Int(cmyk.magenta * 100),
                        yellow: Int(cmyk.yellow * 100),
                        black: Int(cmyk.black * 100)
                    )
                default:
                    let swiftUIColor = firstStop.color.color
                    let components = swiftUIColor.components
                    let rgbColor = RGBColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
                    let cmyk = ColorManagement.rgbToCMYK(rgbColor)
                    setCMYKValues(
                        cyan: Int(cmyk.cyan * 100),
                        magenta: Int(cmyk.magenta * 100),
                        yellow: Int(cmyk.yellow * 100),
                        black: Int(cmyk.black * 100)
                    )
                }
            } else {
                setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 0)
            }
        case .clear:
            return
        case .black:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 100)
        case .white:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 0)
        }
    }

    private func setCMYKValues(cyan: Int, magenta: Int, yellow: Int, black: Int) {
        isProgrammaticallyUpdating = true
        cyanValue = String(cyan)
        magentaValue = String(magenta)
        yellowValue = String(yellow)
        blackValue = String(black)
        cyanSlider = Double(cyan)
        magentaSlider = Double(magenta)
        yellowSlider = Double(yellow)
        blackSlider = Double(black)
        isProgrammaticallyUpdating = false
    }

    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.cmyk(currentColor)
        if !disableSetActiveColor {
            onSetActiveColor(vectorColor)
        }
        onAddColorSwatch(vectorColor)
    }

    private func addCMYKColorToSwatches() {
        let vectorColor = VectorColor.cmyk(currentColor)
        onAddColorSwatch(vectorColor)
    }
}
