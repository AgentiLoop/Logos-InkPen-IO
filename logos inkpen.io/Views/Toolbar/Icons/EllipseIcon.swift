import SwiftUI

struct EllipseIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let rect = CGRect(x: 3 - IconStrokeExpand, y: 6 - IconStrokeExpand, width: 14 + IconStrokeWidth, height: 8 + IconStrokeWidth)
            path.addEllipse(in: rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
