import SwiftUI

struct FontPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument

    @Binding var fontSizeDelta: Double?
    @Binding var lineSpacingDelta: Double?
    @Binding var lineHeightDelta: Double?
    @Binding var letterSpacingDelta: Double?

    @State private var lastLoggedEditing: UUID?
    @State private var fontFamilyUpdateTrigger: Bool = false
    private var selectedTextTypography: TypographyProperties? {
        guard !selectedObjectIDs.isEmpty,
              let textID = selectedObjectIDs.first else { return nil }
        if let newVectorObj = snapshot.objects[textID],
           case .text(let shape) = newVectorObj.objectType {
            if let typography = shape.typography {
                return typography
            } else {
                return TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
            }
        }
        return nil
    }

    private var selectedTextID: UUID? {
        return selectedObjectIDs.first
    }

    private var selectedTextContent: String? {
        guard let textID = selectedTextID else { return nil }
        if let newVectorObj = snapshot.objects[textID],
           case .text(let shape) = newVectorObj.objectType {
            return shape.textContent ?? shape.name.replacingOccurrences(of: "Text: ", with: "")
        }
        return nil
    }

    private var selectedText: VectorText? {
        guard let textID = selectedTextID,
              let typography = selectedTextTypography else { return nil }
        if let newVectorObj = snapshot.objects[textID],
           case .text(let shape) = newVectorObj.objectType {
            return VectorText.from(shape)
        }
        var text = VectorText(
            content: selectedTextContent ?? "",
            typography: typography,
            position: .zero
        )
        text.id = textID
        return text
    }

    private var editingText: VectorText? {
        if let newVectorObj = document.snapshot.objects.values.first(where: { obj in
            if case .text(let shape) = obj.objectType {
                return shape.isEditing == true
            }
            return false
        }) {
            if case .text(let shape) = newVectorObj.objectType {
                return VectorText.from(shape)
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    FontPanelHeader(
                        selectedText: selectedText,
                        editingText: editingText
                    )
                    VStack(spacing: 16) {
                        FontPickerView(
                            selectedObjectIDs: selectedObjectIDs,
                            document: document,
                            selectedTextTypography: selectedTextTypography,
                            selectedText: selectedText,
                            editingText: editingText,
                            fontFamilyUpdateTrigger: $fontFamilyUpdateTrigger
                        )
                        FontSizeControls(
                            selectedObjectIDs: selectedObjectIDs,
                            selectedFontSize: document.fontManager.selectedFontSize,
                            selectedLineSpacing: document.fontManager.selectedLineSpacing,
                            selectedLineHeight: document.fontManager.selectedLineHeight,
                            document: document,
                            selectedText: selectedText,
                            editingText: editingText,
                            fontSizeDelta: $fontSizeDelta,
                            lineSpacingDelta: $lineSpacingDelta,
                            lineHeightDelta: $lineHeightDelta,
                            letterSpacingDelta: $letterSpacingDelta
                        )
                        FontAlignmentControls(
                            selectedObjectIDs: selectedObjectIDs,
                            selectedTextAlignment: document.fontManager.selectedTextAlignment,
                            document: document,
                            selectedText: selectedText,
                            editingText: editingText
                        )
                        ConvertToOutlinesButton(
                            selectedObjectIDs: selectedObjectIDs,
                            selectedLayerIndex: document.selectedLayerIndex,
                            snapshot: snapshot,
                            document: document,
                            selectedText: selectedText
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .background(Color.platformControlBackground.opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal, 12)
                Spacer()
            }
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
            let freshEditingText = document.snapshot.objects.values.first { obj in
                if case .text(let shape) = obj.objectType {
                    return shape.isEditing == true
                }
                return false
            }.flatMap { obj -> VectorText? in
                if case .text(let shape) = obj.objectType, var text = VectorText.from(shape) {
                    text.layerIndex = obj.layerIndex
                    return text
                }
                return nil
            }
            if let newEditingText = freshEditingText {
                if newEditingText.id != lastLoggedEditing {
                    lastLoggedEditing = newEditingText.id
                }
            } else {
                if lastLoggedEditing != nil {
                    lastLoggedEditing = nil
                }
            }
        }
    }
}
