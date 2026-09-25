import SwiftUI

extension SVGParser {

    func finishGradientElement() {
        guard let gradientId = currentGradientId, let gradientType = currentGradientType, isParsingGradient else { return }
        let attributes = currentGradientAttributes

        var inheritedGradient: VectorGradient? = nil
        if let hrefRaw = attributes["xlink:href"] ?? attributes["href"] {
            var refId = hrefRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if refId.hasPrefix("url(#") && refId.hasSuffix(")") {
                refId = String(refId.dropFirst(5).dropLast(1))
            } else if refId.hasPrefix("#") {
                refId = String(refId.dropFirst())
            }
            inheritedGradient = gradientDefinitions[refId]
        }
        if currentGradientStops.isEmpty {
            if let inherited = inheritedGradient {
                currentGradientStops = inherited.stops
            } else {
                currentGradientStops = [
                    GradientStop(position: 0.0, color: .black),
                    GradientStop(position: 1.0, color: .white)
                ]
            }
        }
        let vectorGradient: VectorGradient
        if gradientType == "linearGradient" {
            vectorGradient = finishLinearGradientElement(inheritedGradient: inheritedGradient)
        } else {
            vectorGradient = finishRadialGradientElement(inheritedGradient: inheritedGradient)
        }
        gradientDefinitions[gradientId] = vectorGradient
        currentGradientId = nil
        currentGradientType = nil
        currentGradientAttributes = [:]
        currentGradientStops = []
        isParsingGradient = false
        if detectedExtremeValues {
            detectedExtremeValues = false
            useExtremeValueHandling = false
        }
    }

    internal func parseGradientUnits(from attributes: [String: String]) -> GradientUnits {
        return GradientUnits(rawValue: attributes["gradientUnits"] ?? "objectBoundingBox") ?? .objectBoundingBox
    }

    internal func parseSpreadMethod(from attributes: [String: String]) -> GradientSpreadMethod {
        return GradientSpreadMethod(rawValue: attributes["spreadMethod"] ?? "pad") ?? .pad
    }

    internal func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }

    internal func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }

    internal func parseGradientStop(attributes: [String: String]) {
        guard isParsingGradient else { return }
        let offset = parseLength(attributes["offset"]) ?? 0.0

        var stopColor = VectorColor.black
        var stopOpacity = 1.0
        if let colorValue = attributes["stop-color"] {
            stopColor = parseColor(colorValue) ?? .black
        }
        if let opacityValue = attributes["stop-opacity"] {
            stopOpacity = parseLength(opacityValue) ?? 1.0
        }
        if let style = attributes["style"] {
            let styleDict = parseStyleAttribute(style)
            if let stopColorValue = styleDict["stop-color"] {
                stopColor = parseColor(stopColorValue) ?? stopColor
            }
            if let stopOpacityValue = styleDict["stop-opacity"] {
                stopOpacity = parseLength(stopOpacityValue) ?? stopOpacity
            }
        }
        let gradientStop = GradientStop(position: offset, color: stopColor, opacity: stopOpacity)
        currentGradientStops.append(gradientStop)
    }

    internal func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        return max(minValue, min(maxValue, value))
    }

    internal func parseStyleAttribute(_ style: String) -> [String: String] {
        var styleDict: [String: String] = [:]

        let declarations = style.components(separatedBy: ";")
        for declaration in declarations {
            let keyValue = declaration.components(separatedBy: ":")
            if keyValue.count >= 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                styleDict[key] = value
            }
        }
        return styleDict
    }
}
