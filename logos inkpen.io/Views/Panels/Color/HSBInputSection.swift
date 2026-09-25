import SwiftUI

struct HSBInputSection: View {

    @Binding var sharedColor: VectorColor

    let activeColorTarget: ColorTarget

    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor
    @Binding var colorDeltaColor: VectorColor?

    let onSetActiveColor: (VectorColor) -> Void
    let onAddColorSwatch: (VectorColor) -> Void
    let disableSetActiveColor: Bool
    let onDismiss: (() -> Void)?

    init(sharedColor: Binding<VectorColor>, activeColorTarget: ColorTarget, defaultFillColor: Binding<VectorColor>, defaultStrokeColor: Binding<VectorColor>, colorDeltaColor: Binding<VectorColor?>, onSetActiveColor: @escaping (VectorColor) -> Void, onAddColorSwatch: @escaping (VectorColor) -> Void, disableSetActiveColor: Bool = false, onDismiss: (() -> Void)? = nil) {
        self._sharedColor = sharedColor
        self.activeColorTarget = activeColorTarget
        self._defaultFillColor = defaultFillColor
        self._defaultStrokeColor = defaultStrokeColor
        self._colorDeltaColor = colorDeltaColor
        self.onSetActiveColor = onSetActiveColor
        self.onAddColorSwatch = onAddColorSwatch
        self.disableSetActiveColor = disableSetActiveColor
        self.onDismiss = onDismiss
    }

    @State private var hueValue: String = "0"
    @State private var saturationValue: String = "100"
    @State private var brightnessValue: String = "100"
    @State private var hexValue: String = "ff0000"
    @State private var isUpdatingHexFromHSB: Bool = false
    @State private var hueSlider: Double = 0
    @State private var saturationSlider: Double = 100
    @State private var brightnessSlider: Double = 100
    @State private var isProgrammaticallyUpdating: Bool = false
    @State private var isDisplayingGradient: Bool = false
    @State private var pmsEntryText: String = ""
    @State private var livePMSPreview: PantoneLibraryColor? = nil

    @ObservedObject private var pantoneLibrary = PantoneLibrary.shared
    private var currentColor: HSBColorModel {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        return HSBColorModel(hue: h, saturation: s, brightness: b)
    }

    private var closestPantoneColor: PantoneLibraryColor? {
        let userHue = Double(hueValue) ?? 0
        let normalizedHue = userHue >= 360 ? 0 : userHue
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        let matchingColor = HSBColorModel(hue: normalizedHue, saturation: s, brightness: b)
        return pantoneLibrary.findClosestMatch(to: matchingColor)
    }

    private var livePreviewColor: (pms: PantoneLibraryColor?, hsb: HSBColorModel) {
        if let livePMS = livePMSPreview {
            let hsbApproximation = HSBColorModel.fromRGB(livePMS.rgbEquivalent)
            return (pms: livePMS, hsb: hsbApproximation)
        } else {
            let userHue = Double(hueValue) ?? 0
            let s = (Double(saturationValue) ?? 0) / 100.0
            let b = (Double(brightnessValue) ?? 0) / 100.0
            let preservedHSB = HSBColorModel(hue: userHue, saturation: s, brightness: b)
            return (pms: closestPantoneColor, hsb: preservedHSB)
        }
    }

    private var currentHueColor: Color {
        Color(hue: (Double(hueValue) ?? 0) / 360.0, saturation: 1.0, brightness: 1.0)
    }

    private var currentSaturationColor: Color {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = Double(brightnessValue) ?? 100
        return Color(hue: h/360.0, saturation: s, brightness: b/100.0)
    }

    private var currentBrightnessColor: Color {
        let h = Double(hueValue) ?? 0
        let s = Double(saturationValue) ?? 100
        let b = (Double(brightnessValue) ?? 0) / 100.0
        return Color(hue: h/360.0, saturation: s/100.0, brightness: b)
    }

    private func swiftUIColor(h: Double, s: Double, b: Double) -> Color {
        return Color(hue: h/360.0, saturation: s/100.0, brightness: b/100.0)
    }

    private var hueGradient: SwiftUI.LinearGradient {
        SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                Color(hue: 0.0, saturation: 1.0, brightness: 1.0),
                Color(hue: 0.167, saturation: 1.0, brightness: 1.0),
                Color(hue: 0.333, saturation: 1.0, brightness: 1.0),
                Color(hue: 0.5, saturation: 1.0, brightness: 1.0),
                Color(hue: 0.667, saturation: 1.0, brightness: 1.0),
                Color(hue: 0.833, saturation: 1.0, brightness: 1.0),
                Color(hue: 1.0, saturation: 1.0, brightness: 1.0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var saturationGradient: SwiftUI.LinearGradient {
        let h = Double(hueValue) ?? 0
        let b = Double(brightnessValue) ?? 100
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(h: h, s: 0, b: b),
                swiftUIColor(h: h, s: 100, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var brightnessGradient: SwiftUI.LinearGradient {
        let h = Double(hueValue) ?? 0
        let s = Double(saturationValue) ?? 100
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(h: h, s: s, b: 0),
                swiftUIColor(h: h, s: s, b: 100)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentHueColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    Text("H")
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
                            .fill(hueGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $hueSlider, in: 0...360)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: hueSlider) { _, _ in
                                hueValue = String(Int(hueSlider))
                                updateHexFromHSB()
                                livePMSPreview = nil
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $hueValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: hueValue) { _, _ in
                            if let intValue = Double(hueValue) {
                                hueSlider = min(360, max(0, intValue))
                                updateHexFromHSB()
                                livePMSPreview = nil
                                updateSharedColor()
                                updateSharedColor()
                            }
                        }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentSaturationColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    Text("S")
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
                            .fill(saturationGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $saturationSlider, in: 0...100)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: saturationSlider) { _, _ in
                                saturationValue = String(Int(saturationSlider))
                                updateHexFromHSB()
                                livePMSPreview = nil
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $saturationValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: saturationValue) { _, _ in
                            if let intValue = Double(saturationValue) {
                                saturationSlider = min(100, max(0, intValue))
                                updateHexFromHSB()
                                livePMSPreview = nil
                                updateSharedColor()
                                updateSharedColor()
                            }
                        }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentBrightnessColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    Text("B")
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
                            .fill(brightnessGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                        Slider(value: $brightnessSlider, in: 0...100)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: brightnessSlider) { _, _ in
                                brightnessValue = String(Int(brightnessSlider))
                                updateHexFromHSB()
                                livePMSPreview = nil
                                updateSharedColor()
                            }
                    }
                    TextField("", text: $brightnessValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: brightnessValue) { _, _ in
                            if let intValue = Double(brightnessValue) {
                                brightnessSlider = min(100, max(0, intValue))
                                updateHexFromHSB()
                                livePMSPreview = nil
                                updateSharedColor()
                                updateSharedColor()
                            }
                        }
                }
            }
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Button(action: {
                        applyHSBColorToActiveSelection()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            onDismiss?()
                        }
                    }) {
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(livePreviewColor.hsb.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            Text("HSB")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Click to apply HSB color to selection")
                    Button(action: {
                        applyPMSColorToActiveSelection()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            onDismiss?()
                        }
                    }) {
                        VStack(spacing: 2) {
                            ZStack {
                                Rectangle()
                                    .fill(livePreviewColor.pms?.color ?? livePreviewColor.hsb.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                if let pantoneColor = livePreviewColor.pms {
                                    Text(pantoneColor.pantone.replacingOccurrences(of: "-c", with: "").replacingOccurrences(of: " C", with: ""))
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.5)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 30, height: 30)
                                        .allowsTightening(true)
                                }
                            }
                            Text("PMS")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Click to add PMS/Pantone color to swatches (converts to closest Pantone match)")
                    Spacer()
                }
                HStack(spacing: 6) {
                    TextField("PMS # or Name", text: $pmsEntryText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 10))
                        .onSubmit {
                            searchAndApplyPMSColor()
                        }
                        .onChange(of: pmsEntryText) { _, newValue in
                            performLivePMSSearch(newValue)
                        }
                    Button("Add") {
                        if !pmsEntryText.isEmpty {
                            searchAndApplyPMSColor()
                        } else {
                            addColorToSwatches()
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                    Text("#")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("ff0000", text: $hexValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 10))
                        .frame(width: 60)
                        .onChange(of: hexValue) { _, _ in
                            if !isUpdatingHexFromHSB {
                                livePMSPreview = nil
                            }
                        }
                }
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            loadFromSharedColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadFromSharedColor()
        }
    }

    private func updateHexFromHSB() {
        let userHue = Double(hueValue) ?? 0
        let normalizedHue = userHue >= 360 ? 0 : userHue
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        let calculationColor = HSBColorModel(hue: normalizedHue, saturation: s, brightness: b)
        let rgbColor = calculationColor.rgbColor
        let r = Int(rgbColor.red * 255)
        let g = Int(rgbColor.green * 255)
        let b_value = Int(rgbColor.blue * 255)
        isUpdatingHexFromHSB = true
        hexValue = String(format: "%02x%02x%02x", r, g, b_value)
        isUpdatingHexFromHSB = false
    }

    private func updateSharedColor() {
        if isDisplayingGradient {
            return
        }
        let hsbColor = VectorColor.hsb(currentColor)
        sharedColor = hsbColor
        if isProgrammaticallyUpdating {
            return
        }
        colorDeltaColor = hsbColor
        if activeColorTarget == .fill {
            defaultFillColor = hsbColor
        } else {
            defaultStrokeColor = hsbColor
        }
    }

    private func loadFromSharedColor() {
        isDisplayingGradient = false
        var hsbColor: HSBColorModel
        switch sharedColor {
        case .hsb(let hsb):
            hsbColor = hsb
        case .rgb(let rgb):
            hsbColor = HSBColorModel.fromRGB(rgb)
        case .cmyk(let cmyk):
            hsbColor = HSBColorModel.fromRGB(cmyk.rgbColor)
        case .pantone(let pantone):
            hsbColor = HSBColorModel.fromRGB(pantone.rgbEquivalent)
        case .spot(let spot):
            hsbColor = spot.hsbEquivalent
        case .appleSystem(let system):
            hsbColor = HSBColorModel.fromRGB(system.rgbEquivalent)
        case .gradient(let gradient):
            isDisplayingGradient = true
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .hsb(let hsb):
                    hsbColor = hsb
                default:
                    let swiftUIColor = firstStop.color.color
                    let components = swiftUIColor.components
                    let rgbColor = RGBColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
                    hsbColor = HSBColorModel.fromRGB(rgbColor)
                }
            } else {
                hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 0)
            }
        case .clear:
            return
        case .black:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 0)
        case .white:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        }
        setHSBValues(
            hue: hsbColor.hue,
            saturation: hsbColor.saturation * 100,
            brightness: hsbColor.brightness * 100
        )
    }

    private func setHSBValues(hue: Double, saturation: Double, brightness: Double) {
        isProgrammaticallyUpdating = true
        hueValue = String(Int(hue))
        saturationValue = String(Int(saturation))
        brightnessValue = String(Int(brightness))
        hueSlider = hue
        saturationSlider = saturation
        brightnessSlider = brightness
        updateHexFromHSB()
        isProgrammaticallyUpdating = false
    }

    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.hsb(currentColor)
        if !disableSetActiveColor {
            onSetActiveColor(vectorColor)
        }
        updateSharedColor()
    }

    private func addColorToSwatches() {
        let exactHSBColor = HSBColorModel(
            hue: Double(hueValue) ?? 0,
            saturation: (Double(saturationValue) ?? 0) / 100.0,
            brightness: (Double(brightnessValue) ?? 0) / 100.0
        )
        let vectorColor = VectorColor.hsb(exactHSBColor)
        onAddColorSwatch(vectorColor)
    }

    private func performLivePMSSearch(_ query: String) {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedQuery.isEmpty {
            livePMSPreview = nil
            return
        }
        let searchResults = pantoneLibrary.searchColors(query: cleanedQuery)
        if let foundColor = searchResults.first {
            livePMSPreview = foundColor
            let hsbColor = HSBColorModel.fromRGB(foundColor.rgbEquivalent)
            hueValue = String(Int(hsbColor.hue))
            saturationValue = String(Int(hsbColor.saturation * 100))
            brightnessValue = String(Int(hsbColor.brightness * 100))
            hueSlider = hsbColor.hue
            saturationSlider = hsbColor.saturation * 100
            brightnessSlider = hsbColor.brightness * 100
            updateHexFromHSB()
            updateSharedColor()
        } else {
            livePMSPreview = nil
        }
    }

    private func searchAndApplyPMSColor() {
        let cleanedEntry = pmsEntryText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if cleanedEntry.isEmpty { return }
        let searchResults = pantoneLibrary.searchColors(query: cleanedEntry)
        if let foundColor = searchResults.first {
            let hsbColor = HSBColorModel.fromRGB(foundColor.rgbEquivalent)
            hueValue = String(Int(hsbColor.hue))
            saturationValue = String(Int(hsbColor.saturation * 100))
            brightnessValue = String(Int(hsbColor.brightness * 100))
            hueSlider = hsbColor.hue
            saturationSlider = hsbColor.saturation * 100
            brightnessSlider = hsbColor.brightness * 100
            updateHexFromHSB()
            updateSharedColor()
            pmsEntryText = ""
            livePMSPreview = nil
            let pmsColor = VectorColor.pantone(foundColor)
            onAddColorSwatch(pmsColor)
        }
    }

    private func applyHSBColorToActiveSelection() {
        applyColorToActiveSelection()
        addColorToSwatches()
    }

    private func applyPMSColorToActiveSelection() {
        if let pantoneColor = livePreviewColor.pms {
            let pmsVectorColor = VectorColor.pantone(pantoneColor)
            onSetActiveColor(pmsVectorColor)
            onAddColorSwatch(pmsVectorColor)
        } else {
            applyColorToActiveSelection()
            addColorToSwatches()
        }
    }
}
