import SwiftUI

final class DrawingCanvasRegistry {
    static let shared = DrawingCanvasRegistry()

    private let lock = NSLock()

    weak var activeDocument: VectorDocument?

    private init() {}

    func setActiveDocument(_ document: VectorDocument) {
        lock.lock()
        defer { lock.unlock() }
        activeDocument = document
    }
}
