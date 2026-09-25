import SwiftUI

struct SquareIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let rect = CGRect(x: 5 - IconStrokeExpand, y: 5 - IconStrokeExpand, width: 10 + IconStrokeWidth, height: 10 + IconStrokeWidth)
            path.addRect(rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
