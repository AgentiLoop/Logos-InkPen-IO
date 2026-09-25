import SwiftUI

enum PathCommand: Equatable {
    case moveTo(CGPoint)
    case lineTo(CGPoint)
    case curveTo(cp1: CGPoint, cp2: CGPoint, to: CGPoint)
    case quadCurveTo(cp: CGPoint, to: CGPoint)
    case rectangle(CGRect)
    case closePath
}
