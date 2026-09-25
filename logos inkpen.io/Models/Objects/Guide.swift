import SwiftUI

struct Guide: Identifiable, Codable, Equatable {
    let id: UUID

    var position: CGFloat
    var orientation: Orientation

    enum Orientation: String, Codable {
        case horizontal
        case vertical
    }

    init(id: UUID = UUID(), position: CGFloat, orientation: Orientation) {
        self.id = id
        self.position = position
        self.orientation = orientation
    }
}

extension Color {
    static let nonPhotoBlue = Color(red: 164/255, green: 221/255, blue: 237/255)
    static let nonPhotoBlueSelected = Color(red: 114/255, green: 188/255, blue: 218/255)
}
