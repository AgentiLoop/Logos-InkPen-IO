import SwiftUI

struct ColorPickerModal: View {

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

    @Environment(\.presentationMode) var presentationMode

    let title: String
    let onColorSelected: (VectorColor) -> Void

    @State private var localActiveColorTarget: ColorTarget?
    var body: some View {
        NavigationView {
            ColorPanel(
                snapshot: $snapshot,
                selectedObjectIDs: selectedObjectIDs,
                activeColorTarget: Binding(
                    get: { localActiveColorTarget ?? activeColorTarget },
                    set: { localActiveColorTarget = $0 }
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
                onColorSelected: onColorSelected
            )
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
        }
        .frame(width: 300, height: 500)
    }
}
