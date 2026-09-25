import SwiftUI

func createCirclePath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let controlPointOffsetX = radiusX * 0.552
        let controlPointOffsetY = radiusY * 0.552
        return VectorPath(elements: [
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            .close
        ], isClosed: true)
    }

func createCirclePath(center: CGPoint, radius: Double) -> VectorPath {
        let controlPointOffset = radius * 0.552
        return VectorPath(elements: [
            .move(to: VectorPoint(center.x + radius, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + controlPointOffset),
                   control2: VectorPoint(center.x + controlPointOffset, center.y + radius)),
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - controlPointOffset, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + controlPointOffset)),
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - controlPointOffset),
                   control2: VectorPoint(center.x - controlPointOffset, center.y - radius)),
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + controlPointOffset, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - controlPointOffset)),
            .close
        ], isClosed: true)
    }

func createEllipsePath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let controlPointOffsetX = radiusX * 0.552
        let controlPointOffsetY = radiusY * 0.552
        return VectorPath(elements: [
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            .close
        ], isClosed: true)
    }

func createOvalPath(rect: CGRect) -> VectorPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let controlPointOffsetX = radiusX * 0.58
        let controlPointOffsetY = radiusY * 0.58
        return VectorPath(elements: [
            .move(to: VectorPoint(center.x + radiusX, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radiusY),
                   control1: VectorPoint(center.x + radiusX, center.y + controlPointOffsetY),
                   control2: VectorPoint(center.x + controlPointOffsetX, center.y + radiusY)),
            .curve(to: VectorPoint(center.x - radiusX, center.y),
                   control1: VectorPoint(center.x - controlPointOffsetX, center.y + radiusY),
                   control2: VectorPoint(center.x - radiusX, center.y + controlPointOffsetY)),
            .curve(to: VectorPoint(center.x, center.y - radiusY),
                   control1: VectorPoint(center.x - radiusX, center.y - controlPointOffsetY),
                   control2: VectorPoint(center.x - controlPointOffsetX, center.y - radiusY)),
            .curve(to: VectorPoint(center.x + radiusX, center.y),
                   control1: VectorPoint(center.x + controlPointOffsetX, center.y - radiusY),
                   control2: VectorPoint(center.x + radiusX, center.y - controlPointOffsetY)),
            .close
        ], isClosed: true)
    }

func createEggPath(rect: CGRect) -> VectorPath {
        let centerX = rect.midX
        let centerY = rect.midY
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let kTop: CGFloat = 0.552 * 0.78
        let kBottom: CGFloat = 0.552 * 1.12
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        return VectorPath(elements: [
            .move(to: VectorPoint(centerX, minY)),
            .curve(
                to: VectorPoint(maxX, centerY),
                control1: VectorPoint(centerX + kTop * radiusX, minY),
                control2: VectorPoint(maxX, centerY - kTop * radiusY)
            ),
            .curve(
                to: VectorPoint(centerX, maxY),
                control1: VectorPoint(maxX, centerY + kBottom * radiusY),
                control2: VectorPoint(centerX + kBottom * radiusX, maxY)
            ),
            .curve(
                to: VectorPoint(minX, centerY),
                control1: VectorPoint(centerX - kBottom * radiusX, maxY),
                control2: VectorPoint(minX, centerY + kBottom * radiusY)
            ),
            .curve(
                to: VectorPoint(centerX, minY),
                control1: VectorPoint(minX, centerY - kTop * radiusY),
                control2: VectorPoint(centerX - kTop * radiusX, minY)
            ),
            .close
        ], isClosed: true)
    }

func createStarPath(center: CGPoint, outerRadius: Double, innerRadius: Double, points: Int) -> VectorPath {
        var elements: [PathElement] = []

        let angleStep = .pi / Double(points)
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }

func createPolygonPath(center: CGPoint, radius: Double, sides: Int) -> VectorPath {
        var elements: [PathElement] = []

        let angleStep = 2 * .pi / Double(sides)
        let startAngle = -Double.pi / 2 + ((sides % 2 == 0) ? angleStep / 2 : 0)
        for i in 0..<sides {
            let angle = Double(i) * angleStep + startAngle
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        return VectorPath(elements: elements, isClosed: true)
    }

func createRoundedRectPathWithIndividualCorners(rect: CGRect, cornerRadii: [Double]) -> VectorPath {
        guard cornerRadii.count == 4 else {
            return createRoundedRectPath(rect: rect, cornerRadius: 0)
        }
        let topLeftRadius = min(cornerRadii[0], min(rect.width, rect.height) / 2)
        let topRightRadius = min(cornerRadii[1], min(rect.width, rect.height) / 2)
        let bottomRightRadius = min(cornerRadii[2], min(rect.width, rect.height) / 2)
        let bottomLeftRadius = min(cornerRadii[3], min(rect.width, rect.height) / 2)
        let topLeftOffset = topLeftRadius * 0.552
        let topRightOffset = topRightRadius * 0.552
        let bottomRightOffset = bottomRightRadius * 0.552
        let bottomLeftOffset = bottomLeftRadius * 0.552
        return VectorPath(elements: [
            .move(to: VectorPoint(rect.minX + topLeftRadius, rect.minY)),
            .line(to: VectorPoint(rect.maxX - topRightRadius, rect.minY)),
            .curve(to: VectorPoint(rect.maxX, rect.minY + topRightRadius),
                   control1: VectorPoint(rect.maxX - topRightRadius + topRightOffset, rect.minY),
                   control2: VectorPoint(rect.maxX, rect.minY + topRightRadius - topRightOffset)),
            .line(to: VectorPoint(rect.maxX, rect.maxY - bottomRightRadius)),
            .curve(to: VectorPoint(rect.maxX - bottomRightRadius, rect.maxY),
                   control1: VectorPoint(rect.maxX, rect.maxY - bottomRightRadius + bottomRightOffset),
                   control2: VectorPoint(rect.maxX - bottomRightRadius + bottomRightOffset, rect.maxY)),
            .line(to: VectorPoint(rect.minX + bottomLeftRadius, rect.maxY)),
            .curve(to: VectorPoint(rect.minX, rect.maxY - bottomLeftRadius),
                   control1: VectorPoint(rect.minX + bottomLeftRadius - bottomLeftOffset, rect.maxY),
                   control2: VectorPoint(rect.minX, rect.maxY - bottomLeftRadius + bottomLeftOffset)),
            .line(to: VectorPoint(rect.minX, rect.minY + topLeftRadius)),
            .curve(to: VectorPoint(rect.minX + topLeftRadius, rect.minY),
                   control1: VectorPoint(rect.minX, rect.minY + topLeftRadius - topLeftOffset),
                   control2: VectorPoint(rect.minX + topLeftRadius - topLeftOffset, rect.minY)),
            .close
        ], isClosed: true)
    }

func createRoundedRectPath(rect: CGRect, cornerRadius: Double) -> VectorPath {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let controlPointOffset = radius * 0.552
        return VectorPath(elements: [
            .move(to: VectorPoint(rect.minX + radius, rect.minY)),
            .line(to: VectorPoint(rect.maxX - radius, rect.minY)),
            .curve(to: VectorPoint(rect.maxX, rect.minY + radius),
                   control1: VectorPoint(rect.maxX - radius + controlPointOffset, rect.minY),
                   control2: VectorPoint(rect.maxX, rect.minY + radius - controlPointOffset)),
            .line(to: VectorPoint(rect.maxX, rect.maxY - radius)),
            .curve(to: VectorPoint(rect.maxX - radius, rect.maxY),
                   control1: VectorPoint(rect.maxX, rect.maxY - radius + controlPointOffset),
                   control2: VectorPoint(rect.maxX - radius + controlPointOffset, rect.maxY)),
            .line(to: VectorPoint(rect.minX + radius, rect.maxY)),
            .curve(to: VectorPoint(rect.minX, rect.maxY - radius),
                   control1: VectorPoint(rect.minX + radius - controlPointOffset, rect.maxY),
                   control2: VectorPoint(rect.minX, rect.maxY - radius + controlPointOffset)),
            .line(to: VectorPoint(rect.minX, rect.minY + radius)),
            .curve(to: VectorPoint(rect.minX + radius, rect.minY),
                   control1: VectorPoint(rect.minX, rect.minY + radius - controlPointOffset),
                   control2: VectorPoint(rect.minX + radius - controlPointOffset, rect.minY)),
            .close
        ], isClosed: true)
    }

func createEquilateralTrianglePathWithGridSnapping(rect: CGRect, gridSpacing: Double, unit: MeasurementUnit) -> VectorPath {
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        let baseSpacing = gridSpacing * unit.pointsPerUnit

        let spacingMultiplier: CGFloat = {
            switch unit {
            case .pixels, .points:
                return 25.0
            case .millimeters:
                return 1.0
            case .inches:
                return 1.0
            case .centimeters:
                return 10.0
            case .picas:
                return 1.0
            }
        }()
        let actualGridSpacing = baseSpacing * spacingMultiplier
        let topX = round(normalizedRect.midX / actualGridSpacing) * actualGridSpacing
        let topY = round(normalizedRect.minY / actualGridSpacing) * actualGridSpacing
        let bottomLeftX = round(normalizedRect.minX / actualGridSpacing) * actualGridSpacing
        let bottomLeftY = round(normalizedRect.maxY / actualGridSpacing) * actualGridSpacing
        let bottomRightX = round(normalizedRect.maxX / actualGridSpacing) * actualGridSpacing
        let bottomRightY = bottomLeftY
        let topPoint = VectorPoint(topX, topY)
        let bottomLeft = VectorPoint(bottomLeftX, bottomLeftY)
        let bottomRight = VectorPoint(bottomRightX, bottomRightY)
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }

func createRightTrianglePath(rect: CGRect, dragDirection: String) -> VectorPath {
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        let topLeft = VectorPoint(normalizedRect.minX, normalizedRect.minY)
        let topRight = VectorPoint(normalizedRect.maxX, normalizedRect.minY)
        let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
        let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
        switch dragDirection {
        case "RIGHT_DOWN":
            return VectorPath(elements: [
                .move(to: topLeft),
                .line(to: bottomLeft),
                .line(to: bottomRight),
                .close
            ], isClosed: true)
        case "RIGHT_UP":
            return VectorPath(elements: [
                .move(to: bottomLeft),
                .line(to: topLeft),
                .line(to: topRight),
                .close
            ], isClosed: true)
        case "LEFT_DOWN":
            return VectorPath(elements: [
                .move(to: topRight),
                .line(to: bottomRight),
                .line(to: bottomLeft),
                .close
            ], isClosed: true)
        case "LEFT_UP":
            return VectorPath(elements: [
                .move(to: bottomRight),
                .line(to: topRight),
                .line(to: topLeft),
                .close
            ], isClosed: true)
        default:
            return VectorPath(elements: [
                .move(to: topLeft),
                .line(to: bottomLeft),
                .line(to: bottomRight),
                .close
            ], isClosed: true)
        }
    }

func createAcuteTrianglePath(rect: CGRect) -> VectorPath {
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        let apexOffsetRatio: CGFloat = 0.2
        let apexX = normalizedRect.minX + normalizedRect.width * apexOffsetRatio
        let topPoint = VectorPoint(apexX, normalizedRect.minY)
        let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
        let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
    }

func createIsoscelesTrianglePath(rect: CGRect) -> VectorPath {
        let normalizedRect = CGRect(
            x: min(rect.minX, rect.maxX),
            y: min(rect.minY, rect.maxY),
            width: abs(rect.width),
            height: abs(rect.height)
        )
        let topPoint = VectorPoint(normalizedRect.midX, normalizedRect.minY)
        let bottomLeft = VectorPoint(normalizedRect.minX, normalizedRect.maxY)
        let bottomRight = VectorPoint(normalizedRect.maxX, normalizedRect.maxY)
        return VectorPath(elements: [
            .move(to: topPoint),
            .line(to: bottomLeft),
            .line(to: bottomRight),
            .close
        ], isClosed: true)
}
