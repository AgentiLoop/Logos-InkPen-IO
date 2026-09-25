import SwiftUI

public let kLayerRowHeight: CGFloat = 22

struct VisibilityButtonStyle: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundColor(isVisible ? .primary : .secondary.opacity(0.3))
            .frame(width: 20, height: 20)
    }
}

struct LockButtonStyle: ViewModifier {
    let isLocked: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 10))
            .foregroundColor(isLocked ? .orange : .secondary.opacity(0.3))
            .frame(width: 20, height: 20)
    }
}

extension View {

    func visibilityButton(isVisible: Bool) -> some View {
        modifier(VisibilityButtonStyle(isVisible: isVisible))
    }

    func lockButton(isLocked: Bool) -> some View {
        modifier(LockButtonStyle(isLocked: isLocked))
    }
}
