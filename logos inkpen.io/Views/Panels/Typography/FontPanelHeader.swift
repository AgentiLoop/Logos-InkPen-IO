import SwiftUI

struct FontPanelHeader: View {
    let selectedText: VectorText?
    let editingText: VectorText?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Font Properties")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            if let editingText = editingText {
                HStack {
                    Text("Editing TextBox UUID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(editingText.id.uuidString.prefix(8))
                        .font(.caption.monospaced())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                        .help("Currently editing text box: \(editingText.id.uuidString)")
                    Text("(BLUE - Edit Mode)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Spacer()
                }
            } else if let selectedText = selectedText {
                HStack {
                    Text("Selected TextBox UUID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedText.id.uuidString.prefix(8))
                        .font(.caption.monospaced())
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                        .help("Currently selected text box: \(selectedText.id.uuidString)")
                    Text("(GREEN - Selected)")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Spacer()
                }
            } else {
                HStack {
                    Text("No TextBox Selected")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("(Showing defaults for new text)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            if selectedText != nil {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                        .font(.caption2)
                    Text("Font settings isolated per text box UUID")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}
