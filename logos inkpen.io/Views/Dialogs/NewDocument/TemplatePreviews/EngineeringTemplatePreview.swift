import SwiftUI

struct EngineeringTemplatePreview: View {

    var body: some View {
        VStack {
            HStack {
                VStack(spacing: 2) {
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 40, height: 40)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 60, height: 1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 80, height: 1)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 1)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 40, height: 1)
                }
                .background(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 90, height: 30)
                )
            }
            Spacer()
        }
        .padding()
    }
}
