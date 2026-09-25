import SwiftUI

struct ImportResultHeaderStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.headline)
    }
}

struct ImportResultSectionStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct ImportResultWarningStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.orange)
    }
}

struct ImportResultErrorStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.red)
    }
}

extension View {

    func importResultHeader() -> some View {
        modifier(ImportResultHeaderStyle())
    }

    func importResultSection() -> some View {
        modifier(ImportResultSectionStyle())
    }

    func importResultWarning() -> some View {
        modifier(ImportResultWarningStyle())
    }

    func importResultError() -> some View {
        modifier(ImportResultErrorStyle())
    }
}

struct ImportResultView: View {
    let result: VectorImportResult
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(result.success ? "Import Successful" : "Import Failed")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Format: \(result.metadata.originalFormat.displayName)")
                        .importResultSection()
                }
                Spacer()
            }
            if result.success {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Imported Objects")
                            .importResultHeader()
                        Label("\(result.metadata.shapeCount) shapes", systemImage: "square.and.pencil")
                        Label("\(result.metadata.textObjectCount) text objects", systemImage: "textformat")
                        Label("\(result.metadata.layerCount) layers", systemImage: "square.stack")
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Document Info")
                            .importResultHeader()
                        Label("Size: \(Int(result.metadata.documentSize.width))×\(Int(result.metadata.documentSize.height))", systemImage: "rectangle")
                        Label("DPI: \(Int(result.metadata.dpi))", systemImage: "grid")
                        Label("Units: \(result.metadata.units.rawValue)", systemImage: "ruler")
                    }
                }
            }
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warnings")
                        .importResultHeader()
                        .foregroundColor(.orange)
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .importResultWarning()
                    }
                }
            }
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Errors")
                        .importResultHeader()
                        .foregroundColor(.red)
                    ForEach(result.errors, id: \.localizedDescription) { error in
                        Label(error.localizedDescription, systemImage: "xmark.circle")
                            .importResultError()
                    }
                }
            }
            HStack {
                if !result.success {
                    Button("Try Again") {
                        onRetry()
                    }
                }
                Spacer()
                Button("Close") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}
