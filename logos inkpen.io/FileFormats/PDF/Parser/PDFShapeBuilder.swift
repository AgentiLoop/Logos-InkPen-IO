import SwiftUI

extension PDFCommandParser {

    func handleFill() {
        if !isInCompoundPath && currentPath.isEmpty && compoundPathParts.isEmpty {
            return
        }
        if shouldSkipBlackBackground() {
            currentPath.removeAll()
            return
        }
        if isInCompoundPath && !compoundPathParts.isEmpty {
            createCompoundShapeFromParts(filled: true, stroked: false)
            return
        }
        if !isInCompoundPath {
            createShapeFromCurrentPath(filled: true, stroked: false)
        } else {
            if !currentPath.isEmpty {
                compoundPathParts.append(currentPath)
                currentPath.removeAll()
            }
        }
    }

    func shouldSkipBlackBackground() -> Bool {
        guard let imageBounds = transparentImageBounds else { return false }
        let r = Double(currentFillColor.components?[0] ?? 0.0)
        let g = Double(currentFillColor.components?[1] ?? 0.0)
        let b = Double(currentFillColor.components?[2] ?? 0.0)
        let isBlack = (r < 0.1 && g < 0.1 && b < 0.1)
        if !isBlack { return false }
        for command in currentPath {
            if case .rectangle(let rect) = command {
                if rect.contains(imageBounds) || rect.equalTo(imageBounds) {
                    return true
                }
            }
        }
        if currentPath.count >= 4 {
            var minX = CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude
            for command in currentPath {
                switch command {
                case .moveTo(let pt), .lineTo(let pt):
                    minX = min(minX, pt.x)
                    minY = min(minY, pt.y)
                    maxX = max(maxX, pt.x)
                    maxY = max(maxY, pt.y)
                default:
                    break
                }
            }
            let pathBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            if pathBounds.contains(imageBounds) || pathBounds.equalTo(imageBounds) {
                return true
            }
        }
        return false
    }

    func handleStroke() {
        if let lastShapeIndex = shapes.indices.last {
            let lastShape = shapes[lastShapeIndex]
            if lastShape.fillStyle != nil && lastShape.strokeStyle == nil && !currentPath.isEmpty {
                let lastPathElementCount = lastShape.path.elements.count
                let currentPathCommandCount = currentPath.count
                if abs(lastPathElementCount - currentPathCommandCount) <= 1 {
                    let r = Double(currentStrokeColor.components?[0] ?? 0.0)
                    let g = Double(currentStrokeColor.components?[1] ?? 0.0)
                    let b = Double(currentStrokeColor.components?[2] ?? 0.0)
                    let strokeColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                    let strokeStyle = StrokeStyle(
                        color: strokeColor,
                        width: currentLineWidth,
                        placement: .center,
                        dashPattern: currentLineDashPattern,
                        lineCap: currentLineCap,
                        lineJoin: currentLineJoin,
                        miterLimit: currentMiterLimit,
                        opacity: currentStrokeOpacity
                    )
                    let mergedShape = VectorShape(
                        name: lastShape.name,
                        path: lastShape.path,
                        strokeStyle: strokeStyle,
                        fillStyle: lastShape.fillStyle
                    )
                    shapes[lastShapeIndex] = mergedShape
                    currentPath.removeAll()
                    return
                }
            }
        }
        createShapeFromCurrentPath(filled: false, stroked: true)
    }

    func handleFillAndStroke() {
        createShapeFromCurrentPath(filled: true, stroked: true)
    }

    func createCompoundShapeFromParts(filled: Bool, stroked: Bool) {
        defer {
            compoundPathParts.removeAll()
            currentPath.removeAll()
            isInCompoundPath = false
            moveToCount = 0
            activeGradient = nil
        }
        var allParts = compoundPathParts
        if !currentPath.isEmpty {
            allParts.append(currentPath)
        }
        if activeGradient != nil {
        } else {
            var separateParts: [[PathCommand]] = []
            var previousCommands: [PathCommand] = []
            for part in allParts {
                var newCommands: [PathCommand] = []
                for command in part {
                    if !previousCommands.contains(where: { pathCommandEquals($0, command) }) {
                        newCommands.append(command)
                    }
                }
                if !newCommands.isEmpty {
                    separateParts.append(newCommands)
                    previousCommands = part
                }
            }
            if !separateParts.isEmpty {
                allParts = separateParts
            }
        }
        var combinedElements: [PathElement] = []
        for (_, part) in allParts.enumerated() {
            for command in part {
                switch command {
                case .moveTo(let point):
                    let flippedY = pageSize.height - point.y
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.move(to: vectorPoint))
                case .lineTo(let point):
                    let flippedY = pageSize.height - point.y
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.line(to: vectorPoint))
                case .curveTo(let cp1, let cp2, let point):
                    let flippedCP1Y = pageSize.height - cp1.y
                    let flippedCP2Y = pageSize.height - cp2.y
                    let flippedY = pageSize.height - point.y
                    let vectorCP1 = VectorPoint(Double(cp1.x), Double(flippedCP1Y))
                    let vectorCP2 = VectorPoint(Double(cp2.x), Double(flippedCP2Y))
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.curve(to: vectorPoint, control1: vectorCP1, control2: vectorCP2))
                case .quadCurveTo(let cp, let point):
                    let flippedCPY = pageSize.height - cp.y
                    let flippedY = pageSize.height - point.y
                    let vectorCP = VectorPoint(Double(cp.x), Double(flippedCPY))
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.quadCurve(to: vectorPoint, control: vectorCP))
                case .rectangle(let rect):
                    let flippedY = pageSize.height - rect.origin.y - rect.height
                    combinedElements.append(.move(to: VectorPoint(Double(rect.minX), Double(flippedY))))
                    combinedElements.append(.line(to: VectorPoint(Double(rect.maxX), Double(flippedY))))
                    combinedElements.append(.line(to: VectorPoint(Double(rect.maxX), Double(flippedY + rect.height))))
                    combinedElements.append(.line(to: VectorPoint(Double(rect.minX), Double(flippedY + rect.height))))
                    combinedElements.append(.close)
                case .closePath:
                    combinedElements.append(.close)
                }
            }
        }
        let vectorPath = VectorPath(elements: combinedElements, isClosed: combinedElements.contains(.close), fillRule: .evenOdd)

        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        if filled {
            if let gradient = activeGradient {
                fillStyle = FillStyle(gradient: gradient)
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
            }
        }
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 1.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(
                color: vectorColor,
                width: currentLineWidth,
                placement: .center,
                dashPattern: currentLineDashPattern,
                lineCap: currentLineCap,
                lineJoin: currentLineJoin,
                miterLimit: currentMiterLimit,
                opacity: currentStrokeOpacity
            )
        }
        let compoundShape = VectorShape(
            name: activeGradient != nil ? "PDF Compound Shape (Gradient)" : "PDF Compound Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            transform: .identity,
            isCompoundPath: true
        )
        shapes.append(compoundShape)
    }

    func createShapeFromCurrentPath(filled: Bool, stroked: Bool) {
        guard !currentPath.isEmpty else {
            return
        }
        var vectorElements: [PathElement] = []

        let shouldApplyFlip = filled && !stroked
        for command in currentPath {
            switch command {
            case .moveTo(let point):
                let transformedPoint: VectorPoint
                if shouldApplyFlip {
                    transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                } else {
                    transformedPoint = VectorPoint(Double(point.x), Double(point.y))
                }
                vectorElements.append(.move(to: transformedPoint))
            case .lineTo(let point):
                let transformedPoint: VectorPoint
                if shouldApplyFlip {
                    transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                } else {
                    transformedPoint = VectorPoint(Double(point.x), Double(point.y))
                }
                vectorElements.append(.line(to: transformedPoint))
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1: VectorPoint
                let transformedCP2: VectorPoint
                let transformedTo: VectorPoint
                if shouldApplyFlip {
                    transformedCP1 = VectorPoint(Double(cp1.x), Double(pageSize.height - cp1.y))
                    transformedCP2 = VectorPoint(Double(cp2.x), Double(pageSize.height - cp2.y))
                    transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                } else {
                    transformedCP1 = VectorPoint(Double(cp1.x), Double(cp1.y))
                    transformedCP2 = VectorPoint(Double(cp2.x), Double(cp2.y))
                    transformedTo = VectorPoint(Double(to.x), Double(to.y))
                }
                vectorElements.append(.curve(to: transformedTo, control1: transformedCP1, control2: transformedCP2))
            case .quadCurveTo(let cp, let to):
                let transformedCP: VectorPoint
                let transformedTo: VectorPoint
                if shouldApplyFlip {
                    transformedCP = VectorPoint(Double(cp.x), Double(pageSize.height - cp.y))
                    transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                } else {
                    transformedCP = VectorPoint(Double(cp.x), Double(cp.y))
                    transformedTo = VectorPoint(Double(to.x), Double(to.y))
                }
                vectorElements.append(.quadCurve(to: transformedTo, control: transformedCP))
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
            let r = Double(currentFillColor.components?[0] ?? 0.0)
            let g = Double(currentFillColor.components?[1] ?? 0.0)
            let b = Double(currentFillColor.components?[2] ?? 1.0)
            let isWhiteShape = (r > 0.95 && g > 0.95 && b > 0.95)
            if let gradient = activeGradient {
                if isWhiteShape && (isInCompoundPath || !compoundPathParts.isEmpty || gradientShapes.count > 0) {
                    gradientShapes.append(shapes.count)
                    fillStyle = FillStyle(gradient: gradient)
                } else {
                    fillStyle = FillStyle(gradient: gradient)
                }
            } else if let gradient = currentFillGradient {
                fillStyle = FillStyle(gradient: gradient)
            } else {
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
            }
        }
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(
                color: vectorColor,
                width: currentLineWidth,
                placement: .center,
                dashPattern: currentLineDashPattern,
                lineCap: currentLineCap,
                lineJoin: currentLineJoin,
                miterLimit: currentMiterLimit,
                opacity: currentStrokeOpacity
            )
        }
        if fillStyle == nil && strokeStyle == nil {
            currentPath.removeAll()
            return
        }
        let shape = VectorShape(
            name: "PDF Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        shapes.append(shape)
        if activeGradient != nil && gradientShapes.isEmpty {
            activeGradient = nil
        }
        currentPath.removeAll()
    }

    private func pathCommandEquals(_ cmd1: PathCommand, _ cmd2: PathCommand) -> Bool {
        let tolerance: CGFloat = 0.01
        switch (cmd1, cmd2) {
        case (.moveTo(let p1), .moveTo(let p2)):
            return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance
        case (.lineTo(let p1), .lineTo(let p2)):
            return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance
        case (.curveTo(let cp1_1, let cp2_1, let to1), .curveTo(let cp1_2, let cp2_2, let to2)):
            return abs(cp1_1.x - cp1_2.x) < tolerance && abs(cp1_1.y - cp1_2.y) < tolerance &&
                   abs(cp2_1.x - cp2_2.x) < tolerance && abs(cp2_1.y - cp2_2.y) < tolerance &&
                   abs(to1.x - to2.x) < tolerance && abs(to1.y - to2.y) < tolerance
        case (.quadCurveTo(let cp1, let to1), .quadCurveTo(let cp2, let to2)):
            return abs(cp1.x - cp2.x) < tolerance && abs(cp1.y - cp2.y) < tolerance &&
                   abs(to1.x - to2.x) < tolerance && abs(to1.y - to2.y) < tolerance
        case (.closePath, .closePath):
            return true
        case (.rectangle(let r1), .rectangle(let r2)):
            return abs(r1.origin.x - r2.origin.x) < tolerance &&
                   abs(r1.origin.y - r2.origin.y) < tolerance &&
                   abs(r1.size.width - r2.size.width) < tolerance &&
                   abs(r1.size.height - r2.size.height) < tolerance
        default:
            return false
        }
    }

    private func pathCommandsAreEqual(_ path1: [PathCommand], _ path2: [PathCommand]) -> Bool {
        guard path1.count == path2.count else { return false }
        let tolerance: CGFloat = 0.01
        for (cmd1, cmd2) in zip(path1, path2) {
            switch (cmd1, cmd2) {
            case (.moveTo(let p1), .moveTo(let p2)):
                if abs(p1.x - p2.x) > tolerance || abs(p1.y - p2.y) > tolerance {
                    return false
                }
            case (.lineTo(let p1), .lineTo(let p2)):
                if abs(p1.x - p2.x) > tolerance || abs(p1.y - p2.y) > tolerance {
                    return false
                }
            case (.curveTo(let cp1_1, let cp2_1, let to1), .curveTo(let cp1_2, let cp2_2, let to2)):
                if abs(cp1_1.x - cp1_2.x) > tolerance || abs(cp1_1.y - cp1_2.y) > tolerance ||
                   abs(cp2_1.x - cp2_2.x) > tolerance || abs(cp2_1.y - cp2_2.y) > tolerance ||
                   abs(to1.x - to2.x) > tolerance || abs(to1.y - to2.y) > tolerance {
                    return false
                }
            case (.quadCurveTo(let cp1, let to1), .quadCurveTo(let cp2, let to2)):
                if abs(cp1.x - cp2.x) > tolerance || abs(cp1.y - cp2.y) > tolerance ||
                   abs(to1.x - to2.x) > tolerance || abs(to1.y - to2.y) > tolerance {
                    return false
                }
            case (.closePath, .closePath):
                continue
            case (.rectangle(let r1), .rectangle(let r2)):
                if abs(r1.origin.x - r2.origin.x) > tolerance ||
                   abs(r1.origin.y - r2.origin.y) > tolerance ||
                   abs(r1.size.width - r2.size.width) > tolerance ||
                   abs(r1.size.height - r2.size.height) > tolerance {
                    return false
                }
            default:
                return false
            }
        }
        return true
    }
}
