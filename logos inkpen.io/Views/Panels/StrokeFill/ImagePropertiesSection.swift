import SwiftUI

struct ImagePropertiesSection: View {
    let imageOpacity: Double
    let onUpdateImageOpacity: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.accentColor)
                Text("Image Properties")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(imageOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                Slider(value: Binding(
                    get: { imageOpacity },
                    set: { onUpdateImageOpacity($0) }
                ), in: 0...1)
                .controlSize(.regular)
                .help("Adjust image opacity (0-100%)")
            }
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}
