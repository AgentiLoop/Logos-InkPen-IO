import Foundation
import Combine

class CommandManager: ObservableObject {

    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    private var undoStack: [Command] = []
    private var redoStack: [Command] = []

    private let maxStackSize: Int

    var undoCount: Int { undoStack.count }
    var redoCount: Int { redoStack.count }

    /// Fires when document content changes through a command, undo, or redo.
    /// Selection-only commands do not fire. Used to mark the owning NSDocument
    /// as edited so Save, the close prompt, and autosave all work.
    let contentDidChange = PassthroughSubject<Void, Never>()

    weak var document: VectorDocument?

    init(maxStackSize: Int = 100) {
        self.maxStackSize = maxStackSize
    }

    func execute(_ command: Command) {
        guard let document = document else { return }
        document.isUndoRedoOperation = true
        command.execute(on: document)
        document.changeNotifier.notifyGeneralChange()
        document.isUndoRedoOperation = false
        addToUndoStack(command)
    }

    func recordCompletedCommand(_ command: Command) {
        addToUndoStack(command)
    }

    private func addToUndoStack(_ command: Command) {
        if let lastCommand = undoStack.last,

           let mergedCommand = lastCommand.mergeWith(command) {
            undoStack[undoStack.count - 1] = mergedCommand
        } else {
            undoStack.append(command)
            if undoStack.count > maxStackSize {
                undoStack.removeFirst()
            }
        }
        redoStack.removeAll()
        updateState()
        notifyContentChange(for: command)
    }

    func undo() {
        guard let document = document, !undoStack.isEmpty else { return }
        document.isUndoRedoOperation = true
        let command = undoStack.removeLast()
        command.undo(on: document)
        document.changeNotifier.notifyGeneralChange()
        redoStack.append(command)
        document.isUndoRedoOperation = false
        updateState()
        notifyContentChange(for: command)
    }

    func redo() {
        guard let document = document, !redoStack.isEmpty else { return }
        document.isUndoRedoOperation = true
        let command = redoStack.removeLast()
        command.execute(on: document)
        document.changeNotifier.notifyGeneralChange()
        undoStack.append(command)
        document.isUndoRedoOperation = false
        updateState()
        notifyContentChange(for: command)
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }

    private func notifyContentChange(for command: Command) {
        if command is SelectionCommand { return }
        contentDidChange.send()
    }

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
