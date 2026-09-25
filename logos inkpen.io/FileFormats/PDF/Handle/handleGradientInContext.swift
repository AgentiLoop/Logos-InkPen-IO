import SwiftUI

extension PDFCommandParser {

    func handleGradientInContext(gradient: VectorGradient) {
        if !currentPath.isEmpty {
            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: FillStyle(gradient: gradient))
            compoundPathParts.removeAll()
            isInCompoundPath = false
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            if !compoundPathParts.isEmpty || !currentPath.isEmpty {
                activeGradient = gradient
                createCompoundShapeFromParts(filled: true, stroked: false)
                compoundPathParts.removeAll()
                currentPath.removeAll()
                isInCompoundPath = false
                activeGradient = nil
            }
        } else {
            createShapeFromShading(gradient: gradient)
        }
    }
}
