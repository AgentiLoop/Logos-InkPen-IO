import SwiftUI

extension PDFCommandParser {

    func handleMoveTo(scanner: CGPDFScannerRef) {
        if !currentPath.isEmpty {
            compoundPathParts.append(currentPath)
            isInCompoundPath = true
            moveToCount += 1
        } else {
            moveToCount = 1
            if !isInCompoundPath {
                compoundPathParts.removeAll()
            }
        }
        var x: CGFloat = 0, y: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        let point = CGPoint(x: x, y: y)
        currentPoint = point
        pathStartPoint = point
        currentPath.append(.moveTo(point))
    }

    func handleLineTo(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        let point = CGPoint(x: x, y: y)
        currentPath.append(.lineTo(point))
        currentPoint = point
    }

    func handleCurveTo(scanner: CGPDFScannerRef) {
        var x1: CGFloat = 0, y1: CGFloat = 0
        var x2: CGFloat = 0, y2: CGFloat = 0
        var x3: CGFloat = 0, y3: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        let cp1 = CGPoint(x: x1, y: y1)
        let cp2 = CGPoint(x: x2, y: y2)
        let to = CGPoint(x: x3, y: y3)
        currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
        currentPoint = to
    }

    func handleCurveToV(scanner: CGPDFScannerRef) {
        var x2: CGFloat = 0, y2: CGFloat = 0
        var x3: CGFloat = 0, y3: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2) else { return }
        let cp1 = currentPoint
        let cp2 = CGPoint(x: x2, y: y2)
        let to = CGPoint(x: x3, y: y3)
        currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
        currentPoint = to
    }

    func handleCurveToY(scanner: CGPDFScannerRef) {
        var x1: CGFloat = 0, y1: CGFloat = 0
        var x3: CGFloat = 0, y3: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        let cp1 = CGPoint(x: x1, y: y1)
        let to = CGPoint(x: x3, y: y3)
        let cp2 = to
        currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
        currentPoint = to
    }

    func handleRectangle(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0
        var width: CGFloat = 0, height: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &height),
              CGPDFScannerPopNumber(scanner, &width),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        let rect = CGRect(x: x, y: y, width: width, height: height)
        if rect.width == pageSize.width && rect.height == pageSize.height {
            return
        }
        currentPath.append(.moveTo(CGPoint(x: rect.minX, y: rect.minY)))
        currentPath.append(.lineTo(CGPoint(x: rect.maxX, y: rect.minY)))
        currentPath.append(.lineTo(CGPoint(x: rect.maxX, y: rect.maxY)))
        currentPath.append(.lineTo(CGPoint(x: rect.minX, y: rect.maxY)))
        currentPath.append(.closePath)
        currentPoint = CGPoint(x: rect.minX, y: rect.minY)
    }

    func handleClosePath() {
        currentPath.append(.closePath)
        currentPoint = pathStartPoint
    }
}
