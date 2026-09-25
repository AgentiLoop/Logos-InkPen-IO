import SwiftUI

struct PanelTabBar: View {

    @Binding var selectedTab: PanelTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(width: 46.5, height: 45)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .background(Color.platformControlBackground)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .bottom
        )
    }
}
