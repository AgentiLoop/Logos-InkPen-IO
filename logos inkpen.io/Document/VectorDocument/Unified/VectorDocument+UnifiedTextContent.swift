import SwiftUI
import Combine

extension VectorDocument {

    func updateTextContentInUnified(id: UUID, content: String) {
        updateShapeByID(id) { shape in
            shape.textContent = content
        }
    }

    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int?) {
        updateShapeByID(id) { shape in
            shape.cursorPosition = cursorPosition
        }
    }

    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        updateShapeByID(id) { shape in
            shape.transform = CGAffineTransform(translationX: position.x, y: position.y)
            shape.textPosition = position
        }
    }

    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        updateShapeByID(id) { shape in
            shape.bounds = bounds
        }
    }

    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize?) {
        updateShapeByID(id) { shape in
            shape.areaSize = areaSize
        }
    }

    func updateShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        Log.warning("updateShapeAtIndex is deprecated - use unified system", category: .general)
    }

    func removeShapeAtIndex(layerIndex: Int, shapeIndex: Int) {
        Log.warning("removeShapeAtIndex is deprecated - use unified system", category: .general)
    }
}
