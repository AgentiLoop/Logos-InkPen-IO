import SwiftUI

struct ColorPanel: View {

    @Binding var snapshot: DocumentSnapshot

    let selectedObjectIDs: Set<UUID>

    @Binding var activeColorTarget: ColorTarget
    @Binding var colorMode: ColorMode
    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor

    let defaultFillOpacity: Double
    let defaultStrokeOpacity: Double
    let currentSwatches: [VectorColor]
    let onTriggerLayerUpdates: (Set<Int>) -> Void
    let onAddColorSwatch: (VectorColor) -> Void
    let onRemoveColorSwatch: (VectorColor) -> Void
    let onSetActiveColor: (VectorColor) -> Void

    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?

    @State private var searchText = ""
    @State private var showingPantoneSearch = false
    @State private var currentPreviewColor: VectorColor = .rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0, colorSpace: .displayP3))
    @State private var isLoaded = false

    let onColorSelected: ((VectorColor) -> Void)?
    let hasInitialColor: Bool
    let initialColor: VectorColor?
    let onDismiss: (() -> Void)?

    init(
        snapshot: Binding<DocumentSnapshot>,
        selectedObjectIDs: Set<UUID>,
        activeColorTarget: Binding<ColorTarget>,
        colorMode: Binding<ColorMode>,
        defaultFillColor: Binding<VectorColor>,
        defaultStrokeColor: Binding<VectorColor>,
        defaultFillOpacity: Double,
        defaultStrokeOpacity: Double,
        currentSwatches: [VectorColor],
        onTriggerLayerUpdates: @escaping (Set<Int>) -> Void,
        onAddColorSwatch: @escaping (VectorColor) -> Void,
        onRemoveColorSwatch: @escaping (VectorColor) -> Void,
        onSetActiveColor: @escaping (VectorColor) -> Void,
        colorDeltaColor: Binding<VectorColor?>,
        colorDeltaOpacity: Binding<Double?>,
        onColorSelected: ((VectorColor) -> Void)? = nil,
        initialColor: VectorColor? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self._snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self._activeColorTarget = activeColorTarget
        self._colorMode = colorMode
        self._defaultFillColor = defaultFillColor
        self._defaultStrokeColor = defaultStrokeColor
        self.defaultFillOpacity = defaultFillOpacity
        self.defaultStrokeOpacity = defaultStrokeOpacity
        self.currentSwatches = currentSwatches
        self.onTriggerLayerUpdates = onTriggerLayerUpdates
        self.onAddColorSwatch = onAddColorSwatch
        self.onRemoveColorSwatch = onRemoveColorSwatch
        self.onSetActiveColor = onSetActiveColor
        self._colorDeltaColor = colorDeltaColor
        self._colorDeltaOpacity = colorDeltaOpacity
        self.onColorSelected = onColorSelected
        self.hasInitialColor = (initialColor != nil)
        self.initialColor = initialColor
        self.onDismiss = onDismiss
        let color = initialColor ?? (activeColorTarget.wrappedValue == .stroke ? defaultStrokeColor.wrappedValue : defaultFillColor.wrappedValue)
        self._currentPreviewColor = State(initialValue: color)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isLoaded {
                loadedContent
            } else {
                VStack {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        isLoaded = true
                    }
                }
            }
            if let dismiss = onDismiss {
                GlassCloseButton(action: dismiss)
            }
        }
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
                Spacer()
                    .frame(height: 8)
            VStack(alignment: .leading, spacing: 4) {
                Picker("Color Mode", selection: Binding(
                    get: { colorMode },
                    set: { newMode in
                        let oldMode = colorMode
                        colorMode = newMode
                        currentPreviewColor = convertColorToMode(currentPreviewColor, from: oldMode, to: newMode)
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
            if colorMode == .rgb {
                RGBInputSection(
                    snapshot: $snapshot,
                    selectedObjectIDs: selectedObjectIDs,
                    activeColorTarget: activeColorTarget,
                    defaultFillColor: $defaultFillColor,
                    defaultStrokeColor: $defaultStrokeColor,
                    defaultFillOpacity: defaultFillOpacity,
                    defaultStrokeOpacity: defaultStrokeOpacity,
                    onTriggerLayerUpdates: onTriggerLayerUpdates,
                    onAddColorSwatch: onAddColorSwatch,
                    onSetActiveColor: onSetActiveColor,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    sharedColor: $currentPreviewColor,
                    onColorSelected: onColorSelected,
                    onDismiss: onDismiss
                )
                .padding(.horizontal, 12)
            } else if colorMode == .cmyk {
                CMYKInputSection(
                    sharedColor: $currentPreviewColor,
                    activeColorTarget: activeColorTarget,
                    defaultFillColor: $defaultFillColor,
                    defaultStrokeColor: $defaultStrokeColor,
                    colorDeltaColor: $colorDeltaColor,
                    onSetActiveColor: onSetActiveColor,
                    onAddColorSwatch: onAddColorSwatch,
                    onColorSelected: onColorSelected,
                    disableSetActiveColor: hasInitialColor,
                    onDismiss: onDismiss
                )
                .padding(.horizontal, 12)
            } else if colorMode == .pms {
                HSBInputSection(
                    sharedColor: $currentPreviewColor,
                    activeColorTarget: activeColorTarget,
                    defaultFillColor: $defaultFillColor,
                    defaultStrokeColor: $defaultStrokeColor,
                    colorDeltaColor: $colorDeltaColor,
                    onSetActiveColor: onSetActiveColor,
                    onAddColorSwatch: onAddColorSwatch,
                    disableSetActiveColor: hasInitialColor,
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
                                    ForEach(Array(filteredColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        if hasInitialColor {
                            onColorSelected?(color)
                        } else {
                            selectColor(color)
                            currentPreviewColor = color
                        }
                        DispatchQueue.main.async {
                            onDismiss?()
                        }
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
                    .contextMenu {
                        Button("Delete Swatch") {
                            onRemoveColorSwatch(color)
                        }
                    }
                    }
                }
                .padding(.horizontal, 12)
            }
            Spacer()
        }
        .onAppear {
            currentPreviewColor = (activeColorTarget == .stroke) ? defaultStrokeColor : defaultFillColor
        }
        .onChange(of: activeColorTarget) { _, newTarget in
            currentPreviewColor = (newTarget == .stroke) ? defaultStrokeColor : defaultFillColor
        }
        .onChange(of: defaultFillColor) { _, newFill in
            if activeColorTarget == .fill {
                currentPreviewColor = newFill
            }
        }
        .onChange(of: defaultStrokeColor) { _, newStroke in
            if activeColorTarget == .stroke {
                currentPreviewColor = newStroke
            }
        }
        .onChange(of: initialColor) { _, newInitialColor in
            if let newColor = newInitialColor {
                currentPreviewColor = newColor
            }
        }
    }

    private var colorModeDescription: String {
        switch colorMode {
        case .rgb:
            return "RGB colors for screen display"
        case .cmyk:
            return "CMYK colors for print production"
        case .pms:
            return "PMS colors with Pantone matching"
        }
    }

    private var filteredColors: [VectorColor] {
        if searchText.isEmpty {
            return currentSwatches
        } else {
            return currentSwatches.filter { color in
                colorDescription(for: color).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func selectColor(_ color: VectorColor) {
        if let onColorSelected = onColorSelected {
            onColorSelected(color)
        } else {
            currentPreviewColor = color
            onSetActiveColor(color)
        }
    }

    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb):
            return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk):
            return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb):
            return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone):
            return "PANTONE \(pantone.pantone) - \(pantone.name)"
        case .spot(let spot):
            return "SPOT \(spot.number) - \(spot.name)"
        case .appleSystem(let systemColor):
            return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient):
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }

    @ViewBuilder
    private func overlayText(for color: VectorColor) -> some View {
        if case .pantone(let pantone) = color {
            Text(pantone.pantone)
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

    private func convertColorToMode(_ color: VectorColor, from oldMode: ColorMode, to newMode: ColorMode) -> VectorColor {
        if oldMode == newMode {
            return color
        }
        if oldMode == .rgb && newMode == .cmyk {
            switch color {
            case .rgb(let rgbColor):
                let cmykColor = ColorManagement.rgbToCMYK(rgbColor)
                return .cmyk(cmykColor)
            case .cmyk:
                return color
            case .hsb(let hsb):
                let cmykColor = ColorManagement.rgbToCMYK(hsb.rgbColor)
                return .cmyk(cmykColor)
            case .pantone(let pantone):
                return .cmyk(pantone.cmykEquivalent)
            case .spot(let spot):
                return .cmyk(spot.cmykEquivalent)
            case .appleSystem(let system):
                let cmykColor = ColorManagement.rgbToCMYK(system.rgbEquivalent)
                return .cmyk(cmykColor)
            case .clear:
                return .clear
            case .black:
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1))
            case .white:
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0))
            case .gradient:
                return color
            }
        }
        if oldMode == .cmyk && newMode == .rgb {
            switch color {
            case .cmyk(let cmykColor):
                let rgbColor = cmykColor.rgbColor
                return .rgb(rgbColor)
            case .rgb:
                return color
            case .hsb(let hsb):
                return .rgb(hsb.rgbColor)
            case .pantone(let pantone):
                return .rgb(pantone.rgbEquivalent)
            case .spot(let spot):
                return .rgb(spot.rgbEquivalent)
            case .appleSystem:
                return color
            case .clear:
                return .clear
            case .black:
                return .rgb(RGBColor(red: 0, green: 0, blue: 0))
            case .white:
                return .rgb(RGBColor(red: 1, green: 1, blue: 1))
            case .gradient:
                return color
            }
        }
        if newMode == .pms {
            switch color {
            case .hsb:
                return color
            case .rgb(let rgb):
                return .hsb(HSBColorModel.fromRGB(rgb))
            case .cmyk(let cmyk):
                return .hsb(HSBColorModel.fromRGB(cmyk.rgbColor))
            case .pantone(let pantone):
                return .hsb(HSBColorModel.fromRGB(pantone.rgbEquivalent))
            case .spot(let spot):
                return .hsb(spot.hsbEquivalent)
            case .appleSystem(let system):
                return .hsb(HSBColorModel.fromRGB(system.rgbEquivalent))
            case .clear:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 1, alpha: 0))
            case .black:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 0))
            case .white:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 1))
            case .gradient:
                return color
            }
        }
        return color
    }
}
