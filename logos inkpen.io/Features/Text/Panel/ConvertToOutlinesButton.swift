import SwiftUI

struct FullWidthSecondaryButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ConvertToOutlinesButton: View {
    let selectedObjectIDs: Set<UUID>
    let selectedLayerIndex: Int?
    let snapshot: DocumentSnapshot
    let document: VectorDocument
    let selectedText: VectorText?

    var body: some View {
        Button("Convert to Outlines") {
            convertSelectedTextToOutlines()
        }
        .buttonStyle(FullWidthSecondaryButtonStyle())
        .help("Convert text to vector paths (⌘⇧O)")
        .keyboardShortcut("o", modifiers: [.command, .shift])
        .disabled(selectedText == nil)
    }

    private func convertSelectedTextToOutlines() {
        guard !selectedObjectIDs.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES: No text selected", category: .error)
            return
        }
        if let layerIndex = selectedLayerIndex,
           layerIndex >= 0 && layerIndex < snapshot.layers.count {
            let layer = snapshot.layers[layerIndex]
            if layer.isLocked {
                Log.error("❌ CONVERT TO OUTLINES: Layer '\(layer.name)' is locked", category: .error)
                return
            }
        }
        document.convertSelectedTextToOutlines()
    }
}
