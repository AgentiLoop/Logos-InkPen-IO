import SwiftUI

struct PillIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 7 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 6 + IconStrokeWidth)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 3, height: 3))
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
