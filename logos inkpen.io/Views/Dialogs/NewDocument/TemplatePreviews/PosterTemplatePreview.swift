import SwiftUI

struct PosterTemplatePreview: View {

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.purple.opacity(0.2))
                .frame(height: 60)
            Rectangle()
                .fill(Color.orange.opacity(0.1))
                .frame(height: 120)
            Rectangle()
                .fill(Color.ui.lightSuccessBackground)
                .frame(height: 40)
        }
        .background(Color.white)
    }
}
