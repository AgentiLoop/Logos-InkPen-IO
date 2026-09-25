import SwiftUI

struct BusinessCardTemplatePreview: View {

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.ui.lightBlueBackground)
                .frame(height: 20)
            HStack {
                VStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 80, height: 4)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 2)
                }
                Spacer()
            }
            .padding(.horizontal)
            Spacer()
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                .padding(8)
        )
    }
}
