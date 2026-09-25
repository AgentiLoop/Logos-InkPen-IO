import SwiftUI

struct SkewedRectangleIcon: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: "rectangle")
            .font(.system(size: 16))
            .foregroundColor(isSelected ? .white : .primary)
            .transformEffect(CGAffineTransform(a: 1.0, b: 0.0, c: -0.3, d: 1.0, tx: 2, ty: 0))
            .frame(width: 20, height: 20)
            .fixedSize()
    }
}
