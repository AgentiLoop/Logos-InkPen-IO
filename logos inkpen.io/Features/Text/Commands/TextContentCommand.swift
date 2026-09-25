import Foundation

class TextContentCommand: BaseCommand {
    private let textID: UUID
    private let oldContent: String
    private let newContent: String
    private let oldBounds: CGRect?
    private let newBounds: CGRect?

    init(textID: UUID, oldContent: String, newContent: String, oldBounds: CGRect? = nil, newBounds: CGRect? = nil) {
        self.textID = textID
        self.oldContent = oldContent
        self.newContent = newContent
        self.oldBounds = oldBounds
        self.newBounds = newBounds
    }

    override func execute(on document: VectorDocument) {
        if var object = document.snapshot.objects[textID] {
            switch object.objectType {
            case .text(var shape):
                shape.textContent = newContent
                if let bounds = newBounds {
                    shape.bounds = bounds
                }
                object = VectorObject(id: shape.id, layerIndex: object.layerIndex, objectType: .text(shape))
                document.snapshot.objects[textID] = object
                document.triggerLayerUpdate(for: object.layerIndex)
            default:
                break
            }
        }
    }

    override func undo(on document: VectorDocument) {
        if var object = document.snapshot.objects[textID] {
            switch object.objectType {
            case .text(var shape):
                shape.textContent = oldContent
                if let bounds = oldBounds {
                    shape.bounds = bounds
                }
                object = VectorObject(id: shape.id, layerIndex: object.layerIndex, objectType: .text(shape))
                document.snapshot.objects[textID] = object
                document.triggerLayerUpdate(for: object.layerIndex)
            default:
                break
            }
        }
    }
}
