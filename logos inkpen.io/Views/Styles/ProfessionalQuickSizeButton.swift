import SwiftUI

struct ProfessionalQuickSizeButton: View {
    let size: QuickSize
    let displayUnit: MeasurementUnit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                VStack(spacing: 2) {
                    Text(size.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    Text(displayText)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .help("\(displayText) \(displayUnit.rawValue)")
    }

    private var iconName: String {
        switch size.name {
        case "Letter", "Legal", "Letter Wide":
            return "doc.text"
        case "Business Card":
            return "creditcard"
        case "Web HD", "Wide":
            return "display"
        case "Mobile":
            return "iphone"
        case "Square":
            return "square"
        default:
            return "doc"
        }
    }

    private var displayText: String {
        let w = UnitsConverter.convert(value: size.baseWidth, from: size.baseUnit, to: displayUnit)
        let h = UnitsConverter.convert(value: size.baseHeight, from: size.baseUnit, to: displayUnit)
        return "\(Int(w))×\(Int(h))"
    }
}
