import SwiftUI

extension VectorDocument {

    func getAllShapes() -> [VectorShape] {
        var allShapes: [VectorShape] = []
        for obj in snapshot.objects.values {
            if case .shape(let shape) = obj.objectType {
                allShapes.append(shape)
            }
        }
        return allShapes
    }

    func getTotalShapeCount() -> Int {
        return snapshot.objects.values.reduce(0) { count, obj in
            if case .shape(_) = obj.objectType {
                return count + 1
            }
            return count
        }
    }
}
