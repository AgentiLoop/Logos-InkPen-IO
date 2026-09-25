import SwiftUI

struct Layer: Equatable, Identifiable, Codable {
    let id: UUID

    var name: String
    var objectIDs: [UUID]
    var isVisible: Bool
    var isLocked: Bool
    var opacity: Double
    var blendMode: BlendMode
    var color: LayerColor

    init(
        id: UUID = UUID(),
        name: String,
        objectIDs: [UUID] = [],
        isVisible: Bool = true,
        isLocked: Bool = false,
        opacity: Double = 1.0,
        blendMode: BlendMode = .normal,
        color: LayerColor = .blue
    ) {
        self.id = id
        self.name = name
        self.objectIDs = objectIDs
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
        self.color = color
    }
}
