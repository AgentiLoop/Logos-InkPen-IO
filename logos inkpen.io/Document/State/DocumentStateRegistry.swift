import SwiftUI

final class DocumentStateRegistry {
    static let shared = DocumentStateRegistry()

    let table = NSHashTable<DocumentState>.weakObjects()

    private let lock = NSLock()

    private init() {}

    func register(_ state: DocumentState) {
        lock.lock(); defer { lock.unlock() }
        table.add(state)
    }

    func forceCleanupAll() {
        lock.lock(); let states = table.allObjects; lock.unlock()
        for state in states { state.forceCleanup() }
    }
}
