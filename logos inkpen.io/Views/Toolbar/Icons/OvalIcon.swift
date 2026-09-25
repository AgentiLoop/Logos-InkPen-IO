import SwiftUI

struct OvalIcon: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 5 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 10 + IconStrokeWidth)
            path.addEllipse(in: rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
