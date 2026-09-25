import SwiftUI

func deletePointsFromPath(_ path: VectorPath, selectedPoints: [PointID]) -> VectorPath {
    var elements = path.elements

    let indicesToDelete = selectedPoints.compactMap { $0.elementIndex }.sorted(by: >)
    for index in indicesToDelete {
        if index < elements.count {
            if canDeleteElement(at: index, in: elements) {
                elements.remove(at: index)
            }
        }
    }
    let validatedElements = validatePathElements(elements)
    return VectorPath(elements: validatedElements, isClosed: path.isClosed)
}

func canDeleteElement(at index: Int, in elements: [PathElement]) -> Bool {
    if case .move = elements[index] {
        let moveCount = elements.compactMap { if case .move = $0 { return 1 } else { return nil } }.count
        return moveCount > 1
    }
    let pointCount = elements.filter { element in
        switch element {
        case .move, .line, .curve, .quadCurve: return true
        case .close: return false
        }
    }.count
    return pointCount > 2
}

func validatePathElements(_ elements: [PathElement]) -> [PathElement] {
    var validElements: [PathElement] = []
    for element in elements {
        switch element {
        case .move(_):
            validElements.append(element)
        case .line(_):
            if !validElements.isEmpty {
                validElements.append(element)
            }
        case .curve(_, _, _):
            if !validElements.isEmpty {
                validElements.append(element)
            }
        case .quadCurve(_, _):
            if !validElements.isEmpty {
                validElements.append(element)
            }
        case .close:
            let pointCount = validElements.filter { element in
                switch element {
                case .move, .line, .curve, .quadCurve: return true
                case .close: return false
                }
            }.count
            if pointCount >= 3 {
                validElements.append(element)
            }
        }
    }
    if validElements.isEmpty {
        validElements.append(.move(to: VectorPoint(0, 0)))
    }
    return validElements
}
