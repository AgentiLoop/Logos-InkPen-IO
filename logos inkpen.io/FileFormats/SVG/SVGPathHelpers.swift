import SwiftUI

extension SVGParser {

    func parsePoints(_ pointsString: String) -> [CGPoint] {
        let coordinates = pointsString
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        var points: [CGPoint] = []
        for i in stride(from: 0, to: coordinates.count - 1, by: 2) {
            points.append(CGPoint(x: coordinates[i], y: coordinates[i + 1]))
        }
        return points
    }

    func tokenizeSVGPath(_ pathData: String) -> [String] {
        var tokens: [String] = []

        let chars = Array(pathData)

        var i = 0
        while i < chars.count {
            let char = chars[i]
            if char.isWhitespace || char == "," {
                i += 1
                continue
            }
            if char.isLetter {
                tokens.append(String(char))
                i += 1
                continue
            }
            if char.isNumber || char == "." || (char == "-" || char == "+") {
                var numberStr = ""
                var hasDecimal = false
                if char == "-" || char == "+" {
                    if i + 1 < chars.count && (chars[i + 1].isNumber || chars[i + 1] == ".") {
                        numberStr.append(char)
                        i += 1
                    } else {
                        i += 1
                        continue
                    }
                }
                while i < chars.count {
                    let currentChar = chars[i]
                    if currentChar.isNumber {
                        numberStr.append(currentChar)
                        i += 1
                    } else if currentChar == "." && !hasDecimal {
                        if i + 1 < chars.count && chars[i + 1].isNumber || numberStr.isEmpty || numberStr == "-" || numberStr == "+" {
                            numberStr.append(currentChar)
                            hasDecimal = true
                            i += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                    numberStr.append(chars[i])
                    i += 1
                    if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                        numberStr.append(chars[i])
                        i += 1
                    }
                    while i < chars.count && chars[i].isNumber {
                        numberStr.append(chars[i])
                        i += 1
                    }
                }
                if !numberStr.isEmpty && numberStr != "-" && numberStr != "+" {
                    tokens.append(numberStr)
                }
                continue
            }
            i += 1
        }
        return tokens
    }

    func parsePathData(_ pathData: String) -> [PathElement] {
        var elements: [PathElement] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControlPoint: CGPoint?

        let tokens = tokenizeSVGPath(pathData)

        var coordinateCount = 0
        var commandCount = 0
        for token in tokens {
            if token.rangeOfCharacter(from: .letters) != nil {
                commandCount += 1
            } else if Double(token) != nil {
                coordinateCount += 1
            }
        }
        var i = 0
        var currentCommand: String = ""
        while i < tokens.count {
            let token = tokens[i]
            if token.rangeOfCharacter(from: .letters) != nil {
                currentCommand = token
                i += 1
                if currentCommand == "Z" || currentCommand == "z" {
                    elements.append(.close)
                    currentPoint = subpathStart
                    lastControlPoint = nil
                }
                continue
            }
            switch currentCommand {
            case "M":
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: x, y: y)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    currentCommand = "L"
                } else {
                    i += 1
                }
            case "m":
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    currentCommand = "l"
                } else {
                    i += 1
                }
            case "L":
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    i += 1
                }
            case "l":
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    i += 1
                }
            case "H":
                if i < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
            case "h":
                if i < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
            case "V":
                if i < tokens.count {
                    let y = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
            case "v":
                if i < tokens.count {
                    let dy = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
            case "C":
                if i + 5 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x2 = Double(tokens[i + 2]) ?? 0
                    let y2 = Double(tokens[i + 3]) ?? 0
                    let x = Double(tokens[i + 4]) ?? 0
                    let y = Double(tokens[i + 5]) ?? 0
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    i += 1
                }
            case "c":
                if i + 5 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx2 = Double(tokens[i + 2]) ?? 0
                    let dy2 = Double(tokens[i + 3]) ?? 0
                    let dx = Double(tokens[i + 4]) ?? 0
                    let dy = Double(tokens[i + 5]) ?? 0
                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    let x2 = currentPoint.x + dx2
                    let y2 = currentPoint.y + dy2
                    let newPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    currentPoint = newPoint
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    i += 1
                }
            case "S":
                var didAdvance = false
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let x2 = Double(tokens[i]) ?? 0
                    let y2 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0
                    let x1: Double
                    let y1: Double
                    if let lastCP = lastControlPoint {
                        x1 = 2 * currentPoint.x - lastCP.x
                        y1 = 2 * currentPoint.y - lastCP.y
                    } else {
                        x1 = currentPoint.x
                        y1 = currentPoint.y
                    }
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 4
                    didAdvance = true
                }
                if !didAdvance { i += 1 }
            case "s":
                var didAdvance = false
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let dx2 = Double(tokens[i]) ?? 0
                    let dy2 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0
                    let reflectedX: Double
                    let reflectedY: Double
                    if let lastCP = lastControlPoint {
                        reflectedX = 2.0 * currentPoint.x - lastCP.x
                        reflectedY = 2.0 * currentPoint.y - lastCP.y
                    } else {
                        reflectedX = currentPoint.x
                        reflectedY = currentPoint.y
                    }
                    let secondControlX = currentPoint.x + dx2
                    let secondControlY = currentPoint.y + dy2
                    let endX = currentPoint.x + dx
                    let endY = currentPoint.y + dy
                    let firstControl = VectorPoint(reflectedX, reflectedY)
                    let secondControl = VectorPoint(secondControlX, secondControlY)
                    let endPointVector = VectorPoint(endX, endY)
                    currentPoint = CGPoint(x: endX, y: endY)
                    lastControlPoint = CGPoint(x: secondControlX, y: secondControlY)
                    let smoothCurveElement = PathElement.curve(
                        to: endPointVector,
                        control1: firstControl,
                        control2: secondControl
                    )
                    elements.append(smoothCurveElement)
                    i += 4
                    didAdvance = true
                }
                if !didAdvance { i += 1 }
            case "Q":
                if i + 3 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x1, y: y1)
                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }
            case "q":
                if i + 3 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0
                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = CGPoint(x: x1, y: y1)
                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }
            case "T":
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    let cpX: Double
                    let cpY: Double
                    if let lastCP = lastControlPoint {
                        cpX = 2.0 * currentPoint.x - lastCP.x
                        cpY = 2.0 * currentPoint.y - lastCP.y
                    } else {
                        cpX = currentPoint.x
                        cpY = currentPoint.y
                    }
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: cpX, y: cpY)
                    elements.append(.quadCurve(to: VectorPoint(currentPoint), control: VectorPoint(cpX, cpY)))
                    i += 2
                } else {
                    i += 1
                }
            case "t":
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    let cpX: Double
                    let cpY: Double
                    if let lastCP = lastControlPoint {
                        cpX = 2.0 * currentPoint.x - lastCP.x
                        cpY = 2.0 * currentPoint.y - lastCP.y
                    } else {
                        cpX = currentPoint.x
                        cpY = currentPoint.y
                    }
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = CGPoint(x: cpX, y: cpY)
                    elements.append(.quadCurve(to: VectorPoint(currentPoint), control: VectorPoint(cpX, cpY)))
                    i += 2
                } else {
                    i += 1
                }
            case "A", "a":
                let isRelative = currentCommand == "a"
                let arcTokens = expandArcTokens(tokens, from: i)

                var ai = 0
                while ai + 6 < arcTokens.count {
                    let rx = abs(Double(arcTokens[ai]) ?? 0)
                    let ry = abs(Double(arcTokens[ai + 1]) ?? 0)
                    let xRotation = Double(arcTokens[ai + 2]) ?? 0
                    let largeArc = (Double(arcTokens[ai + 3]) ?? 0) != 0
                    let sweep = (Double(arcTokens[ai + 4]) ?? 0) != 0
                    let ex = Double(arcTokens[ai + 5]) ?? 0
                    let ey = Double(arcTokens[ai + 6]) ?? 0
                    let endPoint = isRelative ? CGPoint(x: currentPoint.x + ex, y: currentPoint.y + ey) : CGPoint(x: ex, y: ey)
                    let curves = arcToBezierCurves(from: currentPoint, to: endPoint, rx: rx, ry: ry, xRotation: xRotation, largeArc: largeArc, sweep: sweep)
                    elements.append(contentsOf: curves)
                    currentPoint = endPoint
                    lastControlPoint = nil
                    ai += 7
                }
                while i < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    i += 1
                }
            default:
                i += 1
            }
        }
        return elements
    }

    private func expandArcTokens(_ tokens: [String], from start: Int) -> [String] {
        var result: [String] = []
        var paramIdx = 0
        var ti = start
        while ti < tokens.count {
            let token = tokens[ti]
            if token.rangeOfCharacter(from: .letters) != nil { break }
            let posInGroup = paramIdx % 7
            if (posInGroup == 3 || posInGroup == 4) && token.count > 1 {
                let first = token.prefix(1)
                if first == "0" || first == "1" {
                    result.append(String(first))
                    paramIdx += 1
                    let rest = String(token.dropFirst())
                    let newPos = paramIdx % 7
                    if newPos == 4 && rest.count > 1 && (rest.hasPrefix("0") || rest.hasPrefix("1")) {
                        result.append(String(rest.prefix(1)))
                        paramIdx += 1
                        let rest2 = String(rest.dropFirst())
                        if !rest2.isEmpty {
                            result.append(rest2)
                            paramIdx += 1
                        }
                    } else if !rest.isEmpty {
                        result.append(rest)
                        paramIdx += 1
                    }
                    ti += 1
                    continue
                }
            }
            result.append(token)
            paramIdx += 1
            ti += 1
        }
        return result
    }

    func arcToBezierCurves(from p1: CGPoint, to p2: CGPoint, rx inputRx: Double, ry inputRy: Double, xRotation: Double, largeArc: Bool, sweep: Bool) -> [PathElement] {
        if p1.x == p2.x && p1.y == p2.y { return [] }
        var rx = inputRx
        var ry = inputRy
        if rx == 0 || ry == 0 {
            return [.line(to: VectorPoint(p2))]
        }
        let phi = xRotation * .pi / 180.0
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (p1.x - p2.x) / 2.0
        let dy = (p1.y - p2.y) / 2.0
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        let x1pSq = x1p * x1p
        let y1pSq = y1p * y1p

        var rxSq = rx * rx
        var rySq = ry * ry

        let radiusCheck = x1pSq / rxSq + y1pSq / rySq
        if radiusCheck > 1.0 {
            let scale = sqrt(radiusCheck)
            rx *= scale
            ry *= scale
            rxSq = rx * rx
            rySq = ry * ry
        }
        var sq = max(0.0, (rxSq * rySq - rxSq * y1pSq - rySq * x1pSq) / (rxSq * y1pSq + rySq * x1pSq))
        sq = sqrt(sq)
        if largeArc == sweep { sq = -sq }
        let cxp = sq * rx * y1p / ry
        let cyp = -sq * ry * x1p / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2.0
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2.0
        let ux = (x1p - cxp) / rx
        let uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx
        let vy = (-y1p - cyp) / ry
        let startAngle = atan2(uy, ux)

        var sweepAngle = atan2(vy * ux - vx * uy, vx * ux + vy * uy)
        if !sweep && sweepAngle > 0 {
            sweepAngle -= 2.0 * .pi
        } else if sweep && sweepAngle < 0 {
            sweepAngle += 2.0 * .pi
        }
        let segmentCount = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2.0))))
        let segmentAngle = sweepAngle / Double(segmentCount)

        var elements: [PathElement] = []
        var angle = startAngle
        for _ in 0..<segmentCount {
            let endAngle = angle + segmentAngle
            let curves = arcSegmentToBezier(cx: cx, cy: cy, rx: rx, ry: ry, phi: phi, startAngle: angle, segmentAngle: segmentAngle)
            elements.append(contentsOf: curves)
            angle = endAngle
        }
        return elements
    }

    private func arcSegmentToBezier(cx: Double, cy: Double, rx: Double, ry: Double, phi: Double, startAngle: Double, segmentAngle: Double) -> [PathElement] {
        let alpha = sin(segmentAngle) * (sqrt(4.0 + 3.0 * tan(segmentAngle / 2.0) * tan(segmentAngle / 2.0)) - 1.0) / 3.0
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let cosStart = cos(startAngle)
        let sinStart = sin(startAngle)
        let cosEnd = cos(startAngle + segmentAngle)
        let sinEnd = sin(startAngle + segmentAngle)
        let dx1 = -rx * sinStart
        let dy1 = ry * cosStart
        let cp1x = cx + cosPhi * (rx * cosStart + alpha * dx1) - sinPhi * (ry * sinStart + alpha * dy1)
        let cp1y = cy + sinPhi * (rx * cosStart + alpha * dx1) + cosPhi * (ry * sinStart + alpha * dy1)
        let dx2 = -rx * sinEnd
        let dy2 = ry * cosEnd
        let cp2x = cx + cosPhi * (rx * cosEnd - alpha * dx2) - sinPhi * (ry * sinEnd - alpha * dy2)
        let cp2y = cy + sinPhi * (rx * cosEnd - alpha * dx2) + cosPhi * (ry * sinEnd - alpha * dy2)
        let endX = cx + cosPhi * rx * cosEnd - sinPhi * ry * sinEnd
        let endY = cy + sinPhi * rx * cosEnd + cosPhi * ry * sinEnd
        return [.curve(to: VectorPoint(endX, endY), control1: VectorPoint(cp1x, cp1y), control2: VectorPoint(cp2x, cp2y))]
    }
}
