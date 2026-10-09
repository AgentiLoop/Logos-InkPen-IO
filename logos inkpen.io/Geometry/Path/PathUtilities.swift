import SwiftUI

func deletePointsFromPath(_ path: VectorPath, selectedPoints: [PointID]) -> VectorPath {
    var elements = path.elements

    let indicesToDelete = Set(selectedPoints.map { $0.elementIndex }).sorted(by: >)
    for index in indicesToDelete {
        if index < elements.count {
            if canDeleteElement(at: index, in: elements) {
                elements = removingAnchor(at: index, from: elements)
            }
        }
    }
    let validatedElements = validatePathElements(elements)
    return VectorPath(elements: validatedElements, isClosed: path.isClosed)
}

func canDeleteElement(at index: Int, in elements: [PathElement]) -> Bool {
    if case .close = elements[index] { return false }
    let pointCount = elements.filter { element in
        switch element {
        case .move, .line, .curve, .quadCurve: return true
        case .close: return false
        }
    }.count
    return pointCount > 2
}

/// Illustrator-style Delete Anchor Point: the path keeps its shape as closely as possible.
/// The two segments meeting at the anchor merge into one that keeps the outer handles of the neighbouring anchors;
/// deleting the first anchor promotes the next anchor to the start of the path.
func removingAnchor(at index: Int, from elements: [PathElement]) -> [PathElement] {
    guard index >= 0, index < elements.count else { return elements }
    var result = elements
    let next: PathElement? = index + 1 < elements.count ? elements[index + 1] : nil

    if case .move = elements[index] {
        guard let next, let nextEnd = next.endpoint, !isMove(next) else {
            result.remove(at: index)
            return result
        }
        result[index] = .move(to: nextEnd)
        result.remove(at: index + 1)
        return result
    }

    guard let next, !isMove(next), let nextEnd = next.endpoint else {
        result.remove(at: index)
        return result
    }

    let previousAnchor: VectorPoint? = index > 0 ? elements[index - 1].endpoint : nil
    let merged: PathElement
    switch (elements[index], next) {
    case (.curve(_, let c1, _), .curve(_, _, let c2)):
        merged = .curve(to: nextEnd, control1: c1, control2: c2)
    case (.line, .curve(_, _, let c2)):
        merged = .curve(to: nextEnd, control1: previousAnchor ?? nextEnd, control2: c2)
    case (.curve(_, let c1, _), .line):
        merged = .curve(to: nextEnd, control1: c1, control2: nextEnd)
    case (.line, .line):
        merged = .line(to: nextEnd)
    default:
        result.remove(at: index)
        return result
    }
    result[index] = merged
    result.remove(at: index + 1)
    return result
}

private func isMove(_ element: PathElement) -> Bool {
    if case .move = element { return true }
    return false
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
