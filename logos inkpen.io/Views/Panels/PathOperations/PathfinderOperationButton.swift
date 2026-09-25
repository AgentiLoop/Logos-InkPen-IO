import SwiftUI

struct PathfinderOperationButton: View {
    let operation: PathfinderOperation
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: operation.iconName)
                    .font(.system(size: operation.isShapeMode ? 14 : 12))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                Text(operation.rawValue)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }
            .frame(height: operation.isShapeMode ? 48 : 42)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .help(operation.description)
    }
}
