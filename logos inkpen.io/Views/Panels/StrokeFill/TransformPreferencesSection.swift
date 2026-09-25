import SwiftUI

struct TransformPreferencesSection: View {

    @ObservedObject private var settings = ApplicationSettings.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.accentColor)
                Text("Transform")
                    .font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Scaling Preview")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Scale objects in real-time instead of showing outline")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.liveScalingPreview)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, objects scale in real-time during transform; when disabled, only a red outline preview is shown")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide Transform Box While Dragging")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Show transform box only after drag completes")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.hideTransformBoxDuringDrag)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, the transform box is hidden during drag and appears after drag ends")
                }
            }
        }
        .padding()
        .background(Color.platformControlBackground)
        .cornerRadius(12)
    }
}
