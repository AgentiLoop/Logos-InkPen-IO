import Foundation
import Combine

class TextEditCommand: BaseCommand {
    private let textID: UUID
    private let oldContent: String
    private let newContent: String

    init(textID: UUID, oldContent: String, newContent: String) {
        self.textID = textID
        self.oldContent = oldContent
        self.newContent = newContent
    }

    override func execute(on document: VectorDocument) {
        applyContent(newContent, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyContent(oldContent, to: document)
    }

    private func applyContent(_ content: String, to document: VectorDocument) {
        guard var obj = document.snapshot.objects[textID] else { return }
        switch obj.objectType {
        case .text(var shape):
            shape.textContent = content
            obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
            document.snapshot.objects[textID] = obj
            document.triggerLayerUpdate(for: obj.layerIndex)
        case .shape, .image, .warp, .group, .clipGroup, .clipMask, .guide:
            break
        }
    }

    func mergeWith(_ other: Command) -> Command? {
        guard let otherTextEdit = other as? TextEditCommand,
              otherTextEdit.textID == self.textID else {
            return nil
        }
        return TextEditCommand(
            textID: textID,
            oldContent: self.oldContent,
            newContent: otherTextEdit.newContent
        )
    }
}
