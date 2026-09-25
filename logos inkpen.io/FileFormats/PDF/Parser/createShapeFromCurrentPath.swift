import SwiftUI

extension PDFCommandParser {

    func createShapeFromCurrentPath(filled: Bool, stroked: Bool, customFillStyle: FillStyle? = nil) {
        guard !currentPath.isEmpty else {
            return
        }
        var vectorElements: [PathElement] = []
        for command in currentPath {
            switch command {
            case .moveTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1 = VectorPoint(Double(cp1.x), Double(pageSize.height - cp1.y))
                let transformedCP2 = VectorPoint(Double(cp2.x), Double(pageSize.height - cp2.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.curve(
                    to: transformedTo,
                    control1: transformedCP1,
                    control2: transformedCP2
                ))
            case .quadCurveTo(let cp, let to):
                let transformedCP = VectorPoint(Double(cp.x), Double(pageSize.height - cp.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.quadCurve(
                    to: transformedTo,
                    control: transformedCP
                ))
            case .closePath:
                vectorElements.append(.close)
            case .rectangle:
                break
            }
        }
        let vectorPath = VectorPath(elements: vectorElements, isClosed: currentPath.contains(.closePath))

        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        if filled {
            if let custom = customFillStyle {
                fillStyle = custom
            } else if let gradient = activeGradient {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let isWhiteShape = (r > 0.95 && g > 0.95 && b > 0.95)
                if isWhiteShape && (isInCompoundPath || !compoundPathParts.isEmpty || gradientShapes.count > 0) {
                    gradientShapes.append(shapes.count)
                    fillStyle = FillStyle(gradient: gradient)
                } else {
                    fillStyle = FillStyle(gradient: gradient)
                }
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let a = Double(currentFillColor.components?[3] ?? 1.0)
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
                fillStyle = FillStyle(color: vectorColor)
            }
        }
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0)
            let a = Double(currentStrokeColor.components?[3] ?? 1.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center)
        }
        if fillStyle == nil && strokeStyle == nil {
            let defaultColor = VectorColor.rgb(RGBColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0))
            fillStyle = FillStyle(color: defaultColor)
        }
        let isGradientShape = fillStyle?.isGradient ?? false
        let shape = VectorShape(
            name: "PDF Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            isCompoundPath: isGradientShape
        )
        shapes.append(shape)
        onShapeCreated?(shape)
        if activeGradient != nil && gradientShapes.isEmpty {
            activeGradient = nil
        }
        currentPath.removeAll()
    }
}
