import SwiftUI
import Combine

struct SettingsSectionIconStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.blue)
    }
}

struct SettingsSectionTitleStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
    }
}

struct SettingsFieldLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
    }
}

struct SettingsUnitTextStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: 60, alignment: .leading)
    }
}

struct SettingsToggleLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .frame(width: 120, alignment: .leading)
    }
}

extension View {

    func settingsSectionIcon() -> some View {
        modifier(SettingsSectionIconStyle())
    }

    func settingsSectionTitle() -> some View {
        modifier(SettingsSectionTitleStyle())
    }

    func settingsFieldLabel() -> some View {
        modifier(SettingsFieldLabelStyle())
    }

    func settingsUnitText() -> some View {
        modifier(SettingsUnitTextStyle())
    }

    func settingsToggleLabel() -> some View {
        modifier(SettingsToggleLabelStyle())
    }
}

private struct SettingsSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .settingsSectionIcon()
            Text(title)
                .settingsSectionTitle()
        }
    }
}

struct DocumentSettingsView: View {

    @ObservedObject var document: VectorDocument

    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        VStack(spacing: 0) {
            professionalHeader
            ScrollView {
                VStack(spacing: 24) {
                    documentSizeSection
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 24) {
                            displaySettingsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        Divider()
                            .frame(height: 100)
                        VStack(alignment: .leading, spacing: 24) {
                            colorSettingsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    displayOptionsSection
                    HStack(alignment: .top, spacing: 24) {
                        layerSelectionSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        gridSpacingSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            professionalFooter
        }
        .frame(width: 600, height: 700)
        .background(Color.platformWindowBackground)
    }

    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Document Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Configure document properties and preferences")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.ui.lightGrayBackground)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            Divider()
        }
        .background(Color.platformControlBackground)
    }

    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(icon: "ruler", title: "Document Size")
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .settingsFieldLabel()
                        HStack(spacing: 8) {
                            TextField("Width", value: $document.settings.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 120)
                                .onChange(of: document.settings.width) {
                                    document.onSettingsChanged()
                                }
                            Text(document.settings.unit.rawValue.capitalized)
                                .settingsUnitText()
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .settingsFieldLabel()
                        HStack(spacing: 8) {
                            TextField("Height", value: $document.settings.height, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 120)
                                .onChange(of: document.settings.height) {
                                    document.onSettingsChanged()
                                }
                            Text(document.settings.unit.rawValue.capitalized)
                                .settingsUnitText()
                        }
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .settingsFieldLabel()
                    Picker("Unit", selection: $document.settings.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: document.settings.unit) { oldUnit, newUnit in
                        let convertedWidth = UnitsConverter.convert(value: document.settings.width, from: oldUnit, to: newUnit)
                        let convertedHeight = UnitsConverter.convert(value: document.settings.height, from: oldUnit, to: newUnit)
                        document.settings.width = convertedWidth
                        document.settings.height = convertedHeight
                        let convertedGridSpacing = UnitsConverter.convert(value: document.settings.gridSpacing, from: oldUnit, to: newUnit)
                        document.settings.gridSpacing = convertedGridSpacing
                        document.onSettingsChanged()
                    }
                }
            }
        }
    }

    private var colorSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(icon: "paintpalette", title: "Color Settings")
            VStack(alignment: .leading, spacing: 6) {
                Text("Color Mode")
                    .settingsFieldLabel()
                Picker("Color Mode", selection: $document.settings.colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.uppercased()).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }

    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(icon: "eye", title: "Display Settings")
            VStack(alignment: .leading, spacing: 6) {
                Text("Resolution")
                    .settingsFieldLabel()
                HStack(spacing: 8) {
                    TextField("Resolution", value: $document.settings.resolution, format: .number)
                        .textFieldStyle(ProfessionalTextFieldStyle())
                        .frame(width: 120)
                        .onChange(of: document.settings.resolution) {
                            document.onSettingsChanged()
                        }
                    Text("DPI")
                        .settingsUnitText()
                }
            }
        }
    }

    private var layerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Layer")
                .settingsFieldLabel()
            Picker("", selection: Binding(
                    get: {
                        if let selectedId = document.settings.selectedLayerId,

                           let layer = document.snapshot.layers.first(where: { $0.id == selectedId }) {
                            return layer.id
                        } else if let firstLayer = document.snapshot.layers.first {
                            return firstLayer.id
                        } else {
                            return UUID()
                        }
                    },
                    set: { newLayerId in
                        if let selectedLayer = document.snapshot.layers.first(where: { $0.id == newLayerId }) {
                            document.settings.selectedLayerId = selectedLayer.id
                            document.settings.selectedLayerName = selectedLayer.name
                            document.layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == newLayerId }) ?? 0
                            document.onSettingsChanged()
                        }
                    }
                )) {
                    ForEach(document.snapshot.layers) { layer in
                        Text(layer.name).tag(layer.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(document.snapshot.layers.isEmpty)
        }
    }

    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(icon: "eye", title: "Display Options")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 25) {
                    HStack {
                        Text("Show Rulers")
                            .settingsToggleLabel()
                        StylusToggleButton(isOn: $document.settings.showRulers) { newValue in
                            document.gridSettings.showRulers = newValue
                            UserDefaults.standard.set(newValue, forKey: "showRulers")
                            document.onSettingsChanged()
                        }
                    }
                    HStack {
                        Text("Snap to Point")
                            .settingsToggleLabel()
                        StylusToggleButton(isOn: $document.settings.snapToPoint) { newValue in
                            document.gridSettings.snapToPoint = newValue
                            UserDefaults.standard.set(newValue, forKey: "snapToPoint")
                            document.onSettingsChanged()
                        }
                    }
                }
                HStack(spacing: 25) {
                    HStack {
                        Text("Show Grid")
                            .settingsToggleLabel()
                        StylusToggleButton(isOn: $document.gridSettings.showGrid) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "showGrid")
                            document.objectWillChange.send()
                        }
                    }
                    HStack {
                        Text("Snap to Grid")
                            .settingsToggleLabel()
                        StylusToggleButton(isOn: $document.settings.snapToGrid) { newValue in
                            document.gridSettings.snapToGrid = newValue
                            UserDefaults.standard.set(newValue, forKey: "snapToGrid")
                            document.onSettingsChanged()
                        }
                    }
                    HStack {
                        Text("Grid on Top")
                            .settingsToggleLabel()
                        StylusToggleButton(isOn: $document.gridSettings.gridOnTop) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "gridOnTop")
                            document.objectWillChange.send()
                        }
                    }
                }
            }
        }
    }

    private var gridSpacingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grid Spacing")
                .settingsFieldLabel()
            HStack(spacing: 8) {
                TextField("Grid Spacing", value: $document.settings.gridSpacing, format: .number)
                    .textFieldStyle(ProfessionalTextFieldStyle())
                    .frame(width: 120)
                    .onChange(of: document.settings.gridSpacing) {
                        document.onSettingsChanged()
                    }
                Text(document.settings.unit.rawValue.capitalized)
                    .settingsUnitText()
            }
        }
    }

    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.platformControlBackground)
    }
}
