import SwiftUI

struct ColorLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .foregroundColor(Color.ui.secondaryText)
    }
}

struct ColorSwatchButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {

    func colorLabelStyle() -> some View {
        modifier(ColorLabelStyle())
    }
}

struct CurrentColorsView: View {
    let strokeColor: VectorColor
    let fillColor: VectorColor
    let strokeOpacity: Double
    let fillOpacity: Double

    @Binding var snapshot: DocumentSnapshot

    let selectedObjectIDs: Set<UUID>
    let activeColorTarget: ColorTarget

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

    let onSetActiveColorTarget: (ColorTarget) -> Void
    let onColorSelected: (VectorColor) -> Void

    @Environment(AppState.self) private var appState

    @State private var popoverManager = SlidingPopoverManager()
    @State private var anchorViews: [String: NSView] = [:]
    @State private var activeAnchorKey: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ColorSwatchView(
                    color: fillColor,
                    opacity: fillOpacity,
                    label: "Fill",
                    anchorKey: "fill",
                    popoverManager: popoverManager,
                    anchorViews: $anchorViews,
                    activeAnchorKey: $activeAnchorKey,
                    appState: appState,
                    snapshot: $snapshot,
                    selectedObjectIDs: selectedObjectIDs,
                    activeColorTarget: activeColorTarget,
                    colorMode: $colorMode,
                    defaultFillColor: $defaultFillColor,
                    defaultStrokeColor: $defaultStrokeColor,
                    defaultFillOpacity: defaultFillOpacity,
                    defaultStrokeOpacity: defaultStrokeOpacity,
                    currentSwatches: currentSwatches,
                    onTriggerLayerUpdates: onTriggerLayerUpdates,
                    onAddColorSwatch: onAddColorSwatch,
                    onRemoveColorSwatch: onRemoveColorSwatch,
                    onSetActiveColor: onSetActiveColor,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    onColorSelected: { color in
                        onSetActiveColorTarget(.fill)
                        onColorSelected(color)
                    },
                    onSetActiveColorTarget: onSetActiveColorTarget
                )
            }
            HStack(spacing: 8) {
                ColorSwatchView(
                    color: strokeColor,
                    opacity: strokeOpacity,
                    label: "Stroke",
                    anchorKey: "stroke",
                    popoverManager: popoverManager,
                    anchorViews: $anchorViews,
                    activeAnchorKey: $activeAnchorKey,
                    appState: appState,
                    snapshot: $snapshot,
                    selectedObjectIDs: selectedObjectIDs,
                    activeColorTarget: activeColorTarget,
                    colorMode: $colorMode,
                    defaultFillColor: $defaultFillColor,
                    defaultStrokeColor: $defaultStrokeColor,
                    defaultFillOpacity: defaultFillOpacity,
                    defaultStrokeOpacity: defaultStrokeOpacity,
                    currentSwatches: currentSwatches,
                    onTriggerLayerUpdates: onTriggerLayerUpdates,
                    onAddColorSwatch: onAddColorSwatch,
                    onRemoveColorSwatch: onRemoveColorSwatch,
                    onSetActiveColor: onSetActiveColor,
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity,
                    onColorSelected: { color in
                        onSetActiveColorTarget(.stroke)
                        onColorSelected(color)
                    },
                    onSetActiveColorTarget: onSetActiveColorTarget
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(8)
    }
}

private struct ColorSwatchView: View {
    let color: VectorColor
    let opacity: Double
    let label: String
    let anchorKey: String
    let popoverManager: SlidingPopoverManager

    @Binding var anchorViews: [String: NSView]
    @Binding var activeAnchorKey: String?

    let appState: AppState

    @Binding var snapshot: DocumentSnapshot

    let selectedObjectIDs: Set<UUID>
    let activeColorTarget: ColorTarget

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

    let onColorSelected: (VectorColor) -> Void
    let onSetActiveColorTarget: (ColorTarget) -> Void

    @State private var localActiveColorTarget: ColorTarget
    init(color: VectorColor, opacity: Double, label: String, anchorKey: String, popoverManager: SlidingPopoverManager, anchorViews: Binding<[String: NSView]>, activeAnchorKey: Binding<String?>, appState: AppState, snapshot: Binding<DocumentSnapshot>, selectedObjectIDs: Set<UUID>, activeColorTarget: ColorTarget, colorMode: Binding<ColorMode>, defaultFillColor: Binding<VectorColor>, defaultStrokeColor: Binding<VectorColor>, defaultFillOpacity: Double, defaultStrokeOpacity: Double, currentSwatches: [VectorColor], onTriggerLayerUpdates: @escaping (Set<Int>) -> Void, onAddColorSwatch: @escaping (VectorColor) -> Void, onRemoveColorSwatch: @escaping (VectorColor) -> Void, onSetActiveColor: @escaping (VectorColor) -> Void, colorDeltaColor: Binding<VectorColor?>, colorDeltaOpacity: Binding<Double?>, onColorSelected: @escaping (VectorColor) -> Void, onSetActiveColorTarget: @escaping (ColorTarget) -> Void) {
        self.color = color
        self.opacity = opacity
        self.label = label
        self.anchorKey = anchorKey
        self.popoverManager = popoverManager
        self._anchorViews = anchorViews
        self._activeAnchorKey = activeAnchorKey
        self.appState = appState
        self._snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self.activeColorTarget = activeColorTarget
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
        self.onSetActiveColorTarget = onSetActiveColorTarget
        self._localActiveColorTarget = State(initialValue: activeColorTarget)
    }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                if activeAnchorKey == anchorKey && popoverManager.isShown {
                    popoverManager.dismiss()
                    activeAnchorKey = nil
                } else {
                    showPopover()
                }
            }) {
                renderColorSwatchRightPanel(
                    color,
                    width: 30,
                    height: 30,
                    cornerRadius: 0,
                    borderWidth: 1,
                    opacity: opacity
                )
            }
            .buttonStyle(BorderlessButtonStyle())
            .focusable(false)
            .onHover { hovering in
                if hovering && popoverManager.isShown && activeAnchorKey != anchorKey {
                    showPopover()
                }
            }
            .overlay(
                PopoverAnchorView { view in
                    anchorViews[anchorKey] = view
                }
                .allowsHitTesting(false)
            )
            Text(label)
                .colorLabelStyle()
        }
    }

    private func showPopover() {
        guard let anchorView = anchorViews[anchorKey] else { return }
        localActiveColorTarget = (anchorKey == "fill") ? .fill : .stroke
        onSetActiveColorTarget(localActiveColorTarget)
        let popoverContent = ColorPanel(
            snapshot: $snapshot,
            selectedObjectIDs: selectedObjectIDs,
            activeColorTarget: Binding(
                get: { localActiveColorTarget },
                set: { newTarget in
                    localActiveColorTarget = newTarget
                    onSetActiveColorTarget(newTarget)
                }
            ),
            colorMode: $colorMode,
            defaultFillColor: $defaultFillColor,
            defaultStrokeColor: $defaultStrokeColor,
            defaultFillOpacity: defaultFillOpacity,
            defaultStrokeOpacity: defaultStrokeOpacity,
            currentSwatches: currentSwatches,
            onTriggerLayerUpdates: onTriggerLayerUpdates,
            onAddColorSwatch: onAddColorSwatch,
            onRemoveColorSwatch: onRemoveColorSwatch,
            onSetActiveColor: onSetActiveColor,
            colorDeltaColor: $colorDeltaColor,
            colorDeltaOpacity: $colorDeltaOpacity,
            onColorSelected: onColorSelected,
            initialColor: self.color,
            onDismiss: {
                popoverManager.dismiss()
                activeAnchorKey = nil
            }
        )
        .frame(width: 300, height: 480)
        .environment(appState)
        popoverManager.show(content: popoverContent, anchorView: anchorView, edge: .leading)
        activeAnchorKey = anchorKey
    }
}
