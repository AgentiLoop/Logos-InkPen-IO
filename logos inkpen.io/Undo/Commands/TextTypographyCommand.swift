import Foundation

class TextTypographyCommand: BaseCommand {
    private let textID: UUID
    private let oldTypography: TypographyProperties?
    private let newTypography: TypographyProperties?

    init(textID: UUID, oldTypography: TypographyProperties?, newTypography: TypographyProperties?) {
        self.textID = textID
        self.oldTypography = oldTypography
        self.newTypography = newTypography
    }

    override func execute(on document: VectorDocument) {
        applyTypography(newTypography, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyTypography(oldTypography, to: document)
    }

    private func applyTypography(_ typography: TypographyProperties?, to document: VectorDocument) {
        document.updateShapeByID(textID) { shape in
            shape.typography = typography
        }
    }
}
