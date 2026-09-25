import SwiftUI

struct FontAlignmentControls: View {
    let selectedObjectIDs: Set<UUID>
    let selectedTextAlignment: TextAlignment
    let document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?

    private var currentTextAlignment: NSTextAlignment {
        if let selectedText = selectedText {
            return selectedText.typography.alignment.nsTextAlignment
        } else if let editingText = editingText {
            return editingText.typography.alignment.nsTextAlignment
        } else {
            return selectedTextAlignment.nsTextAlignment
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alignment")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Button {
                    updateAlignment(.left)
                } label: {
                    Image(systemName: "text.alignleft")
                }
                .buttonStyle(.alignment(isSelected: currentTextAlignment == .left))
                .help("Align Left")
                Button {
                    updateAlignment(.center)
                } label: {
                    Image(systemName: "text.aligncenter")
                }
                .buttonStyle(.alignment(isSelected: currentTextAlignment == .center))
                .help("Align Center")
                Button {
                    updateAlignment(.right)
                } label: {
                    Image(systemName: "text.alignright")
                }
                .buttonStyle(.alignment(isSelected: currentTextAlignment == .right))
                .help("Align Right")
                Button {
                    updateAlignment(.justified)
                } label: {
                    Image(systemName: "text.justify")
                }
                .buttonStyle(.alignment(isSelected: currentTextAlignment == .justified))
                .help("Justify")
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private func updateAlignment(_ alignment: TextAlignment) {
        document.fontManager.selectedTextAlignment = alignment
        for textID in selectedObjectIDs {
            document.updateShapeByID(textID) { shape in
                var typography = shape.typography ?? TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
                typography.alignment = alignment
                shape.typography = typography
            }
        }
    }
}
