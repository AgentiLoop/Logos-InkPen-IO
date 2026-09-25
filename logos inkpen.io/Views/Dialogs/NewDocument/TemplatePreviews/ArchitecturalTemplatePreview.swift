import SwiftUI

struct ArchitecturalTemplatePreview: View {

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 40, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
            }
            HStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 60)
                Rectangle()
                    .fill(Color.ui.lightBlueBackground)
                    .frame(width: 100, height: 60)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 60)
                Rectangle()
                    .fill(Color.ui.lightSuccessBackground)
                    .frame(width: 80, height: 60)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 60)
            }
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 40, height: 2)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 80, height: 2)
            }
        }
    }
}
