import SwiftUI

extension PDFCommandParser {

    func createShapeFromShading(gradient: VectorGradient) {
        let pageRect = [
            PathCommand.moveTo(CGPoint(x: 0, y: 0)),
            PathCommand.lineTo(CGPoint(x: pageSize.width, y: 0)),
            PathCommand.lineTo(CGPoint(x: pageSize.width, y: pageSize.height)),
            PathCommand.lineTo(CGPoint(x: 0, y: pageSize.height)),
            PathCommand.closePath
        ]
        var vectorElements: [PathElement] = []
        for command in pageRect {
            switch command {
            case .moveTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
            case .closePath:
                vectorElements.append(.close)
            default:
                break
            }
        }
        let vectorPath = VectorPath(elements: vectorElements, isClosed: true)
        let fillStyle = FillStyle(gradient: gradient)
        let shadingShape = VectorShape(
            name: "PDF Shading Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: nil,
            fillStyle: fillStyle,
            isCompoundPath: true
        )
        shapes.append(shadingShape)
    }
}
