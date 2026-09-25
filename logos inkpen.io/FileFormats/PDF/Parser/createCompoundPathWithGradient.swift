import SwiftUI

extension PDFCommandParser {

    func createCompoundPathWithGradient(gradient: VectorGradient) {
        guard !gradientShapes.isEmpty else {
            Log.warning("PDF: ⚠️ No gradient shapes tracked", category: .general)
            return
        }
        var combinedPaths: [VectorPath] = []
        for shapeIndex in gradientShapes {
            if shapeIndex < shapes.count {
                let shape = shapes[shapeIndex]
                combinedPaths.append(shape.path)
            }
        }
        for shapeIndex in gradientShapes.sorted(by: >) {
            if shapeIndex < shapes.count {
                shapes.remove(at: shapeIndex)
            }
        }
        var allElements: [PathElement] = []
        for path in combinedPaths {
            allElements.append(contentsOf: path.elements)
        }
        let compoundPath = VectorPath(elements: allElements, isClosed: false, fillRule: .evenOdd)
        let fillStyle = FillStyle(gradient: gradient)
        let compoundShape = VectorShape(
            name: "PDF Compound Shape (Gradient)",
            path: compoundPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        shapes.append(compoundShape)
        gradientShapes.removeAll()
        activeGradient = nil
    }
}
