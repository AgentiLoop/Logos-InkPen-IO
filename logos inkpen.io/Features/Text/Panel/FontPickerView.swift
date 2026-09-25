import SwiftUI
import AppKit

struct FontPickerLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct FontPickerPickerStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

extension View {

    func fontPickerLabel() -> some View {
        modifier(FontPickerLabelStyle())
    }

    func fontPickerStyle() -> some View {
        modifier(FontPickerPickerStyle())
    }
}

struct FontPickerView: View {
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument
    let selectedTextTypography: TypographyProperties?
    let selectedText: VectorText?
    let editingText: VectorText?

    @Binding var fontFamilyUpdateTrigger: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font")
                .fontPickerLabel()
            Picker("", selection: Binding(
                get: {
                    if let textID = selectedObjectIDs.first,

                       let freshText = document.findText(by: textID) {
                        return freshText.typography.fontFamily
                    }
                    return document.fontManager.selectedFontFamily
                },
                set: { (newFamily: String) in
                    document.fontManager.selectedFontFamily = newFamily
                    let defaultVariant = document.fontManager.getAvailableVariantNames(for: newFamily).first ?? "Regular"
                    document.fontManager.selectedFontVariant = defaultVariant
                    for textID in selectedObjectIDs {
                        document.updateShapeByID(textID) { shape in
                            var typography = shape.typography ?? TypographyProperties(
                                strokeColor: shape.strokeStyle?.color ?? .black,
                                fillColor: shape.fillStyle?.color ?? .black
                            )
                            typography.fontFamily = newFamily
                            typography.fontVariant = defaultVariant
                            shape.typography = typography
                        }
                    }
                }
            )) {
                ForEach(document.fontManager.availableFonts, id: \.self) { fontFamily in
                    Text(fontFamily)
                        .font(.custom(fontFamily, size: 12))
                        .tag(fontFamily)
                }
            }
            .fontPickerStyle()
            Text("Weight")
                .fontPickerLabel()
            Picker("", selection: Binding(
                get: {
                    if let textID = selectedObjectIDs.first,
                       let freshText = document.findText(by: textID),
                       let variant = freshText.typography.fontVariant,
                       !variant.isEmpty {
                        return variant
                    }
                    return document.fontManager.selectedFontVariant
                },
                set: { (newVariant: String) in
                    document.fontManager.selectedFontVariant = newVariant
                    for textID in selectedObjectIDs {
                        document.updateShapeByID(textID) { shape in
                            var typography = shape.typography ?? TypographyProperties(
                                strokeColor: shape.strokeStyle?.color ?? .black,
                                fillColor: shape.fillStyle?.color ?? .black
                            )
                            typography.fontVariant = newVariant
                            shape.typography = typography
                        }
                    }
                }
            )) {

                let currentFamily = {
                    if let textID = selectedObjectIDs.first,

                       let freshText = document.findText(by: textID) {
                        return freshText.typography.fontFamily
                    }
                    return document.fontManager.selectedFontFamily
                }()
                ForEach(document.fontManager.getAvailableVariantNames(for: currentFamily), id: \.self) { variant in
                    Text(cleanVariantName(variant))
                        .font(getFontForVariant(family: currentFamily, variantName: variant))
                        .tag(variant)
                }
            }
            .fontPickerStyle()
        }
    }

    private func getFontForVariant(family: String, variantName: String) -> Font {
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        for member in members {
            if let postScriptName = member[0] as? String,
               let displayName = member[1] as? String,
               displayName == variantName {
                return Font.custom(postScriptName, size: 12)
            }
        }
        return Font.system(size: 12)
    }

    private func cleanVariantName(_ name: String) -> String {
        let weightMap: [String: String] = [
            "W0": "Ultra Light",
            "W1": "Light",
            "W2": "Thin",
            "W3": "Light",
            "W4": "Book",
            "W5": "Regular",
            "W6": "Medium",
            "W7": "Demibold",
            "W8": "Semibold",
            "W9": "Bold",
            "W10": "Extra Bold",
            "W11": "Heavy",
            "W12": "Black",
            "W13": "Ultra Black",
            "W14": "Extra Black",
            "W15": "Ultra Black"
        ]
        if let fullName = weightMap[name] {
            return fullName
        }
        for (code, fullWeight) in weightMap {
            if name.hasPrefix(code) {
                let remainder = name.dropFirst(code.count).trimmingCharacters(in: .whitespaces)
                if remainder.isEmpty {
                    return fullWeight
                } else {
                    return "\(fullWeight) \(remainder)"
                }
            }
        }
        return name
    }
}
