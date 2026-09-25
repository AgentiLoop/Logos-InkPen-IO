import SwiftUI

struct FillPropertiesSection: View {
    let fillOpacity: Double
    let fillColor: VectorColor
    let onApplyFill: () -> Void
    let onUpdateFillOpacity: (Double) -> Void
    let onFillOpacityEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fill")
                .font(.headline)
                .fontWeight(.medium)
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(fillOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                ZStack {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: 6)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                    Capsule()
                        .fill(
                            SwiftUI.LinearGradient(
                                gradient: Gradient(colors: [
                                    fillColor.color.opacity(0),
                                    fillColor.color.opacity(1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 6)
                        .allowsHitTesting(false)
                    Slider(value: Binding(
                        get: { fillOpacity },
                        set: { onUpdateFillOpacity($0) }
                    ), in: 0...1, onEditingChanged: onFillOpacityEditingChanged)
                    .controlSize(.regular)
                    .tint(Color.clear)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}
