import SwiftUI

struct VariableStrokeSection: View {
    let hasPressureInput: Bool

    @Environment(AppState.self) private var appState

    @ObservedObject private var settings = ApplicationSettings.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scribble.variable")
                    .foregroundColor(.accentColor)
                Text("Brush Tool")
                    .font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Thickness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(settings.currentBrushThickness))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                Slider(value: $settings.currentBrushThickness, in: 0.25...72)
                .controlSize(.regular)
                .help("Adjust brush stroke thickness (0.25-72 points)")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pressure Sensitivity")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.pressureSensitivityEnabled },
                        set: { appState.pressureSensitivityEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .controlSize(.small)
                }
                .help("Enable or disable pressure sensitivity for variable stroke")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(settings.currentBrushSmoothingTolerance))px")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                Slider(value: $settings.currentBrushSmoothingTolerance, in: 0...10)
                .controlSize(.regular)
                .help("Point reduction threshold - higher values remove more duplicate points for smoother strokes (0-10 pixels)")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Taper Start")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(settings.currentBrushTaperStart * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                Slider(value: $settings.currentBrushTaperStart, in: 0...1)
                .controlSize(.regular)
                .help("Controls how much of the beginning tapers (0-100%)")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Taper End")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(settings.currentBrushTaperEnd * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                Slider(value: $settings.currentBrushTaperEnd, in: 0...1)
                .controlSize(.regular)
                .help("Controls how much of the end tapers (0-100%)")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Min Taper Thickness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(settings.currentBrushMinTaperThickness))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                Slider(value: $settings.currentBrushMinTaperThickness, in: 0...15)
                .controlSize(.regular)
                .help("Minimum thickness at taper ends (0-15 points)")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Coincident Point Passes")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(settings.brushCoincidentPointPasses)")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(settings.brushCoincidentPointPasses) },
                    set: { settings.brushCoincidentPointPasses = Int($0) }
                ), in: 0...3, step: 1)
                .controlSize(.regular)
                .help("Number of passes to remove duplicate/coincident points (0-3)")
            }
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview Style")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Picker("", selection: Binding(
                        get: { appState.brushPreviewStyle },
                        set: { appState.brushPreviewStyle = $0 }
                    )) {
                        Text("Blue Outline").tag(AppState.BrushPreviewStyle.outline)
                        Text("Fill Color").tag(AppState.BrushPreviewStyle.fill)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                    .help("Choose how the brush preview appears while drawing")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply No Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Remove stroke from brush shapes")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.brushApplyNoStroke)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, brush shapes will have no stroke regardless of current stroke settings")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Overlap")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Union overlapping parts of same shape")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.brushRemoveOverlap)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, overlapping parts of brush strokes will be merged using union operation")
                }
            }
            HStack {
                Image(systemName: hasPressureInput ? "hand.point.up.braille" : "hand.tap")
                    .foregroundColor(hasPressureInput ? .green : .orange)
                Text(hasPressureInput ? "Pressure input detected" : "Using simulated pressure")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.platformControlBackground)
        .cornerRadius(12)
    }
}
