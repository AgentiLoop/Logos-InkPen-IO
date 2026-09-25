import SwiftUI

struct GradientCoordinateConverter {

    enum CoordinateSystem: String {
        case objectBoundingBox = "objectBoundingBox"
        case userSpaceOnUse = "userSpaceOnUse"
    }

    struct RadialGradient {
        let id: String
        let coordinateSystem: CoordinateSystem
        let cx: Double
        let cy: Double
        let r: Double
        let fx: Double?
        let fy: Double?
        let stops: [GradientStop]
    }

    struct GradientStop {
        let offset: Double
        let color: String
    }

    struct BoundingBox {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    static func convertBoundingBoxToUserSpace(
        gradient: RadialGradient,
        boundingBox: BoundingBox
    ) -> RadialGradient {
        guard gradient.coordinateSystem == .objectBoundingBox else {
            return gradient
        }
        let center = SIMD2<Double>(gradient.cx, gradient.cy)
        let bboxOrigin = SIMD2<Double>(boundingBox.x, boundingBox.y)
        let bboxSize = SIMD2<Double>(boundingBox.width, boundingBox.height)
        let newCenter = bboxOrigin + center * bboxSize
        let newCx = newCenter.x
        let newCy = newCenter.y
        let newR = gradient.r * min(boundingBox.width, boundingBox.height)
        let newFx: Double?
        let newFy: Double?
        if let fx = gradient.fx, let fy = gradient.fy {
            let focal = SIMD2<Double>(fx, fy)
            let newFocal = bboxOrigin + focal * bboxSize
            newFx = newFocal.x
            newFy = newFocal.y
        } else {
            newFx = nil
            newFy = nil
        }
        return RadialGradient(
            id: gradient.id,
            coordinateSystem: .userSpaceOnUse,
            cx: newCx,
            cy: newCy,
            r: newR,
            fx: newFx,
            fy: newFy,
            stops: gradient.stops
        )
    }

    static func convertUserSpaceToBoundingBox(
        gradient: RadialGradient,
        boundingBox: BoundingBox
    ) -> RadialGradient {
        guard gradient.coordinateSystem == .userSpaceOnUse else {
            return gradient
        }
        let center = SIMD2<Double>(gradient.cx, gradient.cy)
        let bboxOrigin = SIMD2<Double>(boundingBox.x, boundingBox.y)
        let bboxSize = SIMD2<Double>(boundingBox.width, boundingBox.height)
        let normalizedCenter = (center - bboxOrigin) / bboxSize
        let newCx = normalizedCenter.x
        let newCy = normalizedCenter.y
        let newR = gradient.r / min(boundingBox.width, boundingBox.height)
        let newFx: Double?
        let newFy: Double?
        if let fx = gradient.fx, let fy = gradient.fy {
            let focal = SIMD2<Double>(fx, fy)
            let normalizedFocal = (focal - bboxOrigin) / bboxSize
            newFx = normalizedFocal.x
            newFy = normalizedFocal.y
        } else {
            newFx = nil
            newFy = nil
        }
        return RadialGradient(
            id: gradient.id,
            coordinateSystem: .objectBoundingBox,
            cx: newCx,
            cy: newCy,
            r: newR,
            fx: newFx,
            fy: newFy,
            stops: gradient.stops
        )
    }

    static func parseSVGGradients(from svgContent: String) -> [RadialGradient] {
        var gradients: [RadialGradient] = []

        let gradientPattern = #"<radialGradient[^>]*id="([^"]*)"[^>]*gradientUnits="([^"]*)"[^>]*cx="([^"]*)"[^>]*cy="([^"]*)"[^>]*r="([^"]*)"[^>]*>(.*?)</radialGradient>"#
        guard let regex = try? NSRegularExpression(pattern: gradientPattern, options: [.dotMatchesLineSeparators]) else {
            Log.error("Failed to create regex for gradient pattern", category: .error)
            return []
        }
        let matches = regex.matches(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        for match in matches {
            guard let id = extractValue(from: svgContent, range: match.range(at: 1)),
                  let gradientUnits = extractValue(from: svgContent, range: match.range(at: 2)),
                  let cxStr = extractValue(from: svgContent, range: match.range(at: 3)),
                  let cyStr = extractValue(from: svgContent, range: match.range(at: 4)),
                  let rStr = extractValue(from: svgContent, range: match.range(at: 5)),
                  let gradientContent = extractValue(from: svgContent, range: match.range(at: 6)),
                  let coordinateSystem = CoordinateSystem(rawValue: gradientUnits),
                  let cx = Double(cxStr),
                  let cy = Double(cyStr),

                  let r = Double(rStr) else {
                continue
            }
            let fxPattern = #"fx="([^"]*)"#
            let fyPattern = #"fy="([^"]*)"#
            guard let fxRegex = try? NSRegularExpression(pattern: fxPattern),

                  let fyRegex = try? NSRegularExpression(pattern: fyPattern) else {
                Log.error("Failed to create regex for fx/fy patterns", category: .error)
                continue
            }
            let fxMatch = fxRegex.firstMatch(in: svgContent, options: [], range: match.range)
            let fyMatch = fyRegex.firstMatch(in: svgContent, options: [], range: match.range)
            let fx = fxMatch.flatMap { Double(extractValue(from: svgContent, range: $0.range(at: 1)) ?? "") }
            let fy = fyMatch.flatMap { Double(extractValue(from: svgContent, range: $0.range(at: 1)) ?? "") }
            let stops = parseGradientStops(from: gradientContent)
            let gradient = RadialGradient(
                id: id,
                coordinateSystem: coordinateSystem,
                cx: cx,
                cy: cy,
                r: r,
                fx: fx,
                fy: fy,
                stops: stops
            )
            gradients.append(gradient)
        }
        return gradients
    }

    private static func parseGradientStops(from content: String) -> [GradientStop] {
        var stops: [GradientStop] = []

        let stopPattern = #"<stop[^>]*offset="([^"]*)"[^>]*stop-color="([^"]*)"[^>]*/>"#
        guard let regex = try? NSRegularExpression(pattern: stopPattern) else {
            Log.error("Failed to create regex for stop pattern", category: .error)
            return []
        }
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        for match in matches {
            guard let offsetStr = extractValue(from: content, range: match.range(at: 1)),

                  let color = extractValue(from: content, range: match.range(at: 2)) else {
                continue
            }
            let offset: Double
            if offsetStr.hasSuffix("%") {
                let percentage = Double(offsetStr.dropLast()) ?? 0
                offset = percentage / 100.0
            } else {
                offset = Double(offsetStr) ?? 0
            }
            stops.append(GradientStop(offset: offset, color: color))
        }
        return stops
    }

    static func parseBoundingBox(from svgContent: String) -> BoundingBox? {
        let viewBoxPattern = #"viewBox="([^"]*)"#
        guard let viewBoxRegex = try? NSRegularExpression(pattern: viewBoxPattern) else {
            Log.error("Failed to create regex for viewBox pattern", category: .error)
            return nil
        }
        if let match = viewBoxRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent)),

           let viewBoxStr = extractValue(from: svgContent, range: match.range(at: 1)) {
            let components = viewBoxStr.components(separatedBy: .whitespaces).compactMap { Double($0) }
            if components.count >= 4 {
                return BoundingBox(
                    x: components[0],
                    y: components[1],
                    width: components[2],
                    height: components[3]
                )
            }
        }
        let widthPattern = #"width="([^"]*)"#
        let heightPattern = #"height="([^"]*)"#
        guard let widthRegex = try? NSRegularExpression(pattern: widthPattern),

              let heightRegex = try? NSRegularExpression(pattern: heightPattern) else {
            Log.error("Failed to create regex for width/height patterns", category: .error)
            return nil
        }
        let widthMatch = widthRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        let heightMatch = heightRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        if let widthStr = widthMatch.flatMap({ extractValue(from: svgContent, range: $0.range(at: 1)) }),
           let heightStr = heightMatch.flatMap({ extractValue(from: svgContent, range: $0.range(at: 1)) }),
           let width = Double(widthStr),

           let height = Double(heightStr) {
            return BoundingBox(x: 0, y: 0, width: width, height: height)
        }
        return nil
    }

    private static func extractValue(from string: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,

              let swiftRange = Range(range, in: string) else {
            return nil
        }
        return String(string[swiftRange])
    }

    static func generateSVG(
        originalContent: String,
        convertedGradients: [RadialGradient],
        boundingBox: BoundingBox
    ) -> String {
        var result = originalContent
        for gradient in convertedGradients {
            let oldGradientPattern = #"<radialGradient[^>]*id="\#(gradient.id)"[^>]*>.*?</radialGradient>"#
            let newGradientContent = generateGradientSVG(gradient: gradient)
            guard let regex = try? NSRegularExpression(pattern: oldGradientPattern, options: [.dotMatchesLineSeparators]) else {
                Log.error("Failed to create regex for old gradient pattern", category: .error)
                continue
            }
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: newGradientContent
            )
        }
        return result
    }

    private static func generateGradientSVG(gradient: RadialGradient) -> String {
        var content = #"<radialGradient id="\#(gradient.id)" gradientUnits="\#(gradient.coordinateSystem.rawValue)" cx="\#(gradient.cx)" cy="\#(gradient.cy)" r="\#(gradient.r)""#
        if let fx = gradient.fx, let fy = gradient.fy {
            content += #" fx="\#(fx)" fy="\#(fy)""#
        }
        content += ">\n"
        for stop in gradient.stops {
            let offsetPercent = Int(stop.offset * 100)
            content += #"  <stop offset="\#(offsetPercent)%" stop-color="\#(stop.color)" />\n"#
        }
        content += "</radialGradient>"
        return content
    }
}

extension GradientCoordinateConverter {

    static func parseGradientCoordinate(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, useExtremeValueHandling: Bool = false, viewBoxWidth: Double = 100.0, viewBoxHeight: Double = 100.0) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if gradientUnits == .userSpaceOnUse {
            if trimmed.hasSuffix("%") {
                let percentValue = Double(String(trimmed.dropLast(1))) ?? 0.0
                let dimension = isXCoordinate ? viewBoxWidth : viewBoxHeight
                return percentValue / 100.0 * dimension
            }
            return Double(trimmed) ?? 0.0
        }
        if trimmed.hasSuffix("%") {
            let percentValue = Double(String(trimmed.dropLast(1))) ?? 0.0
            return percentValue / 100.0
        }
        if let absoluteValue = Double(trimmed) {
            if absoluteValue > 1.0 {
                return min(absoluteValue / 100.0, 1.0)
            }
            return absoluteValue
        }
        return 0.0
    }

    static func parseRadialGradientCoordinateExtreme(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, viewBoxWidth: Double = 100.0, viewBoxHeight: Double = 100.0) -> Double {
        return parseGradientCoordinate(value, gradientUnits: gradientUnits, isXCoordinate: isXCoordinate, useExtremeValueHandling: true, viewBoxWidth: viewBoxWidth, viewBoxHeight: viewBoxHeight)
    }
}
