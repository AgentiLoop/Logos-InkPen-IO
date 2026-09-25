import SwiftUI

struct RoundedRectangleIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 6 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 8 + IconStrokeWidth)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
