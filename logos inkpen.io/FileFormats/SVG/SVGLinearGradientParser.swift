import SwiftUI

extension SVGParser {

    internal func parseLinearGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            return
        }
        currentGradientId = id
        currentGradientType = "linearGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true
    }

    internal func finishLinearGradientElement(inheritedGradient: VectorGradient?) -> VectorGradient {
        let attributes = currentGradientAttributes
        let gradientUnits = parseGradientUnits(from: attributes)
        let x1Raw = attributes["x1"] ?? "0%"
        let y1Raw = attributes["y1"] ?? "0%"
        let x2Raw = attributes["x2"] ?? "100%"
        let y2Raw = attributes["y2"] ?? "0%"

        var x1 = parseGradientCoordinate(x1Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        var y1 = parseGradientCoordinate(y1Raw, gradientUnits: gradientUnits, isXCoordinate: false)
        var x2 = parseGradientCoordinate(x2Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        var y2 = parseGradientCoordinate(y2Raw, gradientUnits: gradientUnits, isXCoordinate: false)
        var startPoint: CGPoint
        var endPoint: CGPoint
        if let inherited = inheritedGradient, case .linear(let inh) = inherited,
           attributes["x1"] == nil && attributes["y1"] == nil && attributes["x2"] == nil && attributes["y2"] == nil {
            startPoint = inh.startPoint
            endPoint = inh.endPoint
        } else {
            startPoint = CGPoint(x: x1, y: y1)
            endPoint = CGPoint(x: x2, y: y2)
        }
        let spreadMethod = parseSpreadMethod(from: attributes)
        if gradientUnits == .userSpaceOnUse {
            if let gradientTransformRaw = attributes["gradientTransform"] {
                let gradTransform = parseTransform(gradientTransformRaw)
                startPoint = startPoint.applying(gradTransform)
                endPoint = endPoint.applying(gradTransform)
            }
            if !currentTransform.isIdentity {
                startPoint = startPoint.applying(currentTransform)
                endPoint = endPoint.applying(currentTransform)
            }
            x1 = startPoint.x
            y1 = startPoint.y
            x2 = endPoint.x
            y2 = endPoint.y
            let originX = (startPoint.x + endPoint.x) / 2.0
            let originY = (startPoint.y + endPoint.y) / 2.0
            let angleDegrees = radiansToDegrees(atan2(y2 - y1, x2 - x1))

            var linearGradient = LinearGradient(
                startPoint: startPoint,
                endPoint: endPoint,
                stops: currentGradientStops,
                spreadMethod: spreadMethod,
                units: gradientUnits
            )
            if let inherited = inheritedGradient, case .linear(let inh) = inherited {
                if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
                if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
            }
            linearGradient.originPoint = CGPoint(x: originX, y: originY)
            linearGradient.storedAngle = angleDegrees
            return VectorGradient.linear(linearGradient)
        }
        let gradTransform = attributes["gradientTransform"].map { parseTransform($0) } ?? .identity
        let transformedStart = startPoint.applying(gradTransform)
        let transformedEnd = endPoint.applying(gradTransform)

        var linearGradient = LinearGradient(
            startPoint: transformedStart,
            endPoint: transformedEnd,
            stops: currentGradientStops,
            spreadMethod: spreadMethod,
            units: gradientUnits
        )
        if let inherited = inheritedGradient, case .linear(let inh) = inherited {
            if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
            if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
        }
        linearGradient.originPoint = CGPoint(
            x: (transformedStart.x + transformedEnd.x) / 2.0,
            y: (transformedStart.y + transformedEnd.y) / 2.0
        )
        return VectorGradient.linear(linearGradient)
    }
}
