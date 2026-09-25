import SwiftUI

struct AlignmentButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 36, height: 28)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == AlignmentButtonStyle {

    static func alignment(isSelected: Bool) -> AlignmentButtonStyle {
        AlignmentButtonStyle(isSelected: isSelected)
    }
}
