import SwiftUI

struct BlankTemplatePreview: View {

    var body: some View {
        VStack {
            Image(systemName: "doc")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            Text("Blank Document")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
