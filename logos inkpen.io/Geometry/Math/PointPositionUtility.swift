import Foundation

func getPointPositionExternal(_ pointID: PointID, in document: VectorDocument) -> VectorPoint? {
    for object in document.snapshot.objects.values {
        if case .shape(let shape) = object.objectType,
           shape.id == pointID.shapeID {
            guard pointID.elementIndex < shape.path.elements.count else { return nil }
            return shape.path.elements[pointID.elementIndex].endpoint
        }
    }
    return nil
}
