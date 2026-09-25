import SwiftUI

struct LetterheadTemplatePreview: View {

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.ui.lightBlueBackground)
                .frame(height: 40)
            Rectangle()
                .fill(Color.white)
                .overlay(
                    VStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                    }
                    .padding()
                )
        }
    }
}
