import SwiftUI

struct LogoTemplatePreview: View {

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                .frame(width: 100, height: 100)
            Text("LOGO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
        }
    }
}
