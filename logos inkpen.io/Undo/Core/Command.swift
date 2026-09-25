import Foundation

protocol Command {

    func execute(on document: VectorDocument)

    func undo(on document: VectorDocument)

    func mergeWith(_ other: Command) -> Command?
}

extension Command {

    func mergeWith(_ other: Command) -> Command? {
        return nil
    }
}

class BaseCommand: Command {

    func execute(on document: VectorDocument) {
        fatalError("Subclasses must implement execute(on:)")
    }

    func undo(on document: VectorDocument) {
        fatalError("Subclasses must implement undo(on:)")
    }
}
