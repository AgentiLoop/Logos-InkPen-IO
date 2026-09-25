import SwiftUI
import AppKit

struct DocumentSectionIconStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.blue)
    }
}

struct DocumentSectionTitleStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
    }
}

struct DocumentFieldLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
    }
}

extension View {

    func documentSectionIcon() -> some View {
        modifier(DocumentSectionIconStyle())
    }

    func documentSectionTitle() -> some View {
        modifier(DocumentSectionTitleStyle())
    }

    func documentFieldLabel() -> some View {
        modifier(DocumentFieldLabelStyle())
    }
}

private struct DocumentSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .documentSectionIcon()
            Text(title)
                .documentSectionTitle()
        }
    }
}

struct NewDocumentSetupView: View {

    @Binding var isPresented: Bool

    let onDocumentCreated: (VectorDocument, URL?) -> Void

    @State private var setupData = DocumentSetupData()
    @State private var documentPreview: NSImage?
    @State private var isGeneratingPreview = false
    @State private var skipNextUnitConversion = false

    @Environment(AppState.self) private var appState

    @Environment(\.dismissWindow) private var dismissWindow
    var body: some View {
            VStack(spacing: 0) {
            professionalHeader
            HStack(spacing: 0) {
                settingsPanel
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1)
                previewPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            professionalFooter
        }
        .background(Color.ui.windowBackground)
        .onAppear {
            generateDocumentPreview()
        }
    }

    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Document")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Create a new vector document with professional settings")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { dismissWindow() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .padding(.trailing, -11)
                .padding(.top, -55)
                .buttonStyle(BorderlessButtonStyle())
                .help("Cancel")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            Divider()
        }
        .background(Color.ui.controlBackground)
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                documentNameSection
                documentSizeSection
                quickSizesSection
            }
            .padding(24)
        }
        .frame(width: 450)
        .background(Color.ui.controlBackground)
    }

    private var documentNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DocumentSectionHeader(icon: "doc.text", title: "Document Name")
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter document name", text: $setupData.filename)
                    .textFieldStyle(ProfessionalTextFieldStyle())
                    .onChange(of: setupData.filename) { _, _ in generateDocumentPreview() }
                Text("File will be saved as: \(setupData.filename.isEmpty ? "Untitled" : setupData.filename).inkpen")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DocumentSectionHeader(icon: "ruler", title: "Document Size")
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .documentFieldLabel()
                        HStack(spacing: 8) {
                            TextField("Width", value: $setupData.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                            Text(unitLabel)
                                .documentFieldLabel()
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .documentFieldLabel()
                        HStack(spacing: 8) {
                            TextField("Height", value: $setupData.height, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                            Text(unitLabel)
                                .documentFieldLabel()
                        }
                    }
                }
            }
        }
        .onChange(of: setupData.width) { _, _ in generateDocumentPreview() }
        .onChange(of: setupData.height) { _, _ in generateDocumentPreview() }
        .onChange(of: setupData.unit) { oldUnit, newUnit in
            if skipNextUnitConversion {
                skipNextUnitConversion = false
                generateDocumentPreview()
                return
            }
            let convertedWidth = UnitsConverter.convert(value: setupData.width, from: oldUnit, to: newUnit)
            let convertedHeight = UnitsConverter.convert(value: setupData.height, from: oldUnit, to: newUnit)
            setupData.width = convertedWidth
            setupData.height = convertedHeight
            generateDocumentPreview()
        }
    }

    private var quickSizesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DocumentSectionHeader(icon: "square.grid.2x2", title: "Quick Sizes")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(quickSizes, id: \.self) { size in
                    ProfessionalQuickSizeButton(size: size, displayUnit: setupData.unit) {
                        applyQuickSize(size)
                    }
                }
            }
        }
    }

    private var previewPanel: some View {
             VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                DocumentSectionHeader(icon: "eye", title: "Document Preview")
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.platformControlBackground)
                            .frame(width: 210, height: 210)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        if let preview = documentPreview {
                            Image(nsImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 195, maxHeight: 195)
                        } else if isGeneratingPreview {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating preview...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Preview not available")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    VStack(spacing: 8) {
                        Text("\(formatNumberForDisplay(setupData.width)) × \(formatNumberForDisplay(setupData.height)) \(setupData.unit.rawValue)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text("\(setupData.colorMode.rawValue.uppercased()) • \(Int(setupData.resolution)) DPI")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .documentFieldLabel()
                    Picker("Unit", selection: $setupData.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color Mode")
                            .documentFieldLabel()
                        Picker("Color Mode", selection: $setupData.colorMode) {
                            ForEach(ColorMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue.uppercased()).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolution")
                            .documentFieldLabel()
                        HStack(spacing: 6) {
                            TextField("Resolution", value: $setupData.resolution, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 80)
                            Text("DPI")
                                .documentFieldLabel()
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    dismissWindow()
                }
                .buttonStyle(ProfessionalSecondaryButtonStyle())
                Button("Create Document") {
                    createDocument()
                }
                .buttonStyle(ProfessionalPrimaryButtonStyle())
                .disabled(setupData.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.ui.controlBackground)
    }

    private var unitLabel: String {
        setupData.unit.rawValue
    }

    private var quickSizes: [QuickSize] {
        [
            QuickSize(name: "Letter", baseWidth: 8.5, baseHeight: 11.0, baseUnit: .inches),
            QuickSize(name: "Legal", baseWidth: 8.5, baseHeight: 14.0, baseUnit: .inches),
            QuickSize(name: "Letter Wide", baseWidth: 11.0, baseHeight: 8.5, baseUnit: .inches),
            QuickSize(name: "Business Card", baseWidth: 3.5, baseHeight: 2.0, baseUnit: .inches),
            QuickSize(name: "Web HD", baseWidth: 1920, baseHeight: 1080, baseUnit: .pixels),
            QuickSize(name: "Mobile", baseWidth: 375, baseHeight: 812, baseUnit: .pixels),
            QuickSize(name: "Square", baseWidth: 1000, baseHeight: 1000, baseUnit: .pixels),
            QuickSize(name: "Wide", baseWidth: 1920, baseHeight: 1080, baseUnit: .pixels)
        ]
    }

    private func applyQuickSize(_ size: QuickSize) {
        let targetUnit = setupData.unit
        setupData.width = UnitsConverter.convert(value: size.baseWidth, from: size.baseUnit, to: targetUnit)
        setupData.height = UnitsConverter.convert(value: size.baseHeight, from: size.baseUnit, to: targetUnit)
        generateDocumentPreview()
    }

    private func generateDocumentPreview() {
        isGeneratingPreview = true
        DispatchQueue.global(qos: .userInitiated).async {
            let previewSize = CGSize(width: 280, height: 280)
            let scale: CGFloat = 2.0
            let pixelWidth = Int(previewSize.width * scale)
            let pixelHeight = Int(previewSize.height * scale)
            guard let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                DispatchQueue.main.async {
                    self.isGeneratingPreview = false
                }
                return
            }
            context.scaleBy(x: scale, y: scale)
            context.setFillColor(CGColor(gray: 0.95, alpha: 1.0))
            context.fill(CGRect(origin: .zero, size: previewSize))
            let aspectRatio = setupData.width / setupData.height
            let maxSize: CGFloat = 240
            let docWidth: CGFloat
            let docHeight: CGFloat
            if aspectRatio > 1 {
                docWidth = maxSize
                docHeight = maxSize / aspectRatio
            } else {
                docHeight = maxSize
                docWidth = maxSize * aspectRatio
            }
            let docRect = CGRect(
                x: (previewSize.width - docWidth) / 2,
                y: (previewSize.height - docHeight) / 2,
                width: docWidth,
                height: docHeight
            )
            context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
            context.fill(docRect)
            context.setStrokeColor(CGColor(gray: 0.5, alpha: 1.0))
            context.setLineWidth(1.0)
            context.stroke(docRect)
            let infoText = "\(Int(setupData.width))×\(Int(setupData.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: PlatformFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: PlatformColor.gray
            ]
            let textSize = infoText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: docRect.midX - textSize.width / 2,
                y: docRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            let attrString = NSAttributedString(string: infoText, attributes: attributes)
            context.saveGState()
            context.translateBy(x: 0, y: previewSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            attrString.draw(in: textRect)
            context.restoreGState()
            if let cgImage = context.makeImage() {
                let image = NSImage(cgImage: cgImage, size: previewSize)
                DispatchQueue.main.async {
                    self.documentPreview = image
                    self.isGeneratingPreview = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isGeneratingPreview = false
                }
            }
        }
    }

    private func createDocument() {
        let document = VectorDocument(settings: setupData.documentSettings)
        document.viewState.currentTool = appState.defaultTool
        let filename = setupData.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let suggestedURL = documentsPath?.appendingPathComponent("\(filename).inkpen")
        onDocumentCreated(document, suggestedURL)
        isPresented = false
    }
}
