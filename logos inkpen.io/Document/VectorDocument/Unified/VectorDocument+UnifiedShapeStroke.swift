import SwiftUI

extension VectorDocument {

    func updateShapeStrokeLineJoinInUnified(id: UUID, lineJoin: CGLineJoin) {
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineJoin: lineJoin, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.lineJoin = LineJoin(lineJoin)
            }
        }
    }

    func updateShapeStrokeLineCapInUnified(id: UUID, lineCap: CGLineCap) {
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, lineCap: lineCap, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.lineCap = LineCap(lineCap)
            }
        }
    }

    func updateShapeStrokeMiterLimitInUnified(id: UUID, miterLimit: CGFloat) {
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, miterLimit: miterLimit, opacity: defaultStrokeOpacity)
            } else {
                shape.strokeStyle?.miterLimit = miterLimit
            }
        }
    }

    func updateShapeStrokeScaleWithTransformInUnified(id: UUID, scaleWithTransform: Bool) {
        updateShapeByID(id) { shape in
            if shape.strokeStyle == nil {
                shape.strokeStyle = StrokeStyle(color: defaultStrokeColor, width: defaultStrokeWidth, placement: strokeDefaults.placement, opacity: defaultStrokeOpacity, scaleWithTransform: scaleWithTransform)
            } else {
                shape.strokeStyle?.scaleWithTransform = scaleWithTransform
            }
        }
    }

    func createFillStyleInUnified(id: UUID, color: VectorColor, opacity: Double) {
        updateShapeByID(id) { shape in
            shape.fillStyle = FillStyle(color: color, opacity: opacity)
        }
    }

    func createStrokeStyleInUnified(id: UUID, color: VectorColor, width: Double, placement: StrokePlacement, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: Double, opacity: Double) {
        updateShapeByID(id) { shape in
            shape.strokeStyle = StrokeStyle(
                color: color,
                width: width,
                placement: placement,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                opacity: opacity
            )
        }
    }

    func updateShapePathUnified(id: UUID, path: VectorPath) {
        updateShapeByID(id) { shape in
            shape.path = path
            shape.updateBounds()
        }
    }

    func updateShapeCornerRadiiInUnified(id: UUID, cornerRadii: [Double], path: VectorPath) {
        updateShapeByID(id) { shape in
            shape.cornerRadii = cornerRadii
            shape.path = path
            shape.updateBounds()
        }
    }

    func updateShapeGradientInUnified(id: UUID, gradient: VectorGradient, target: ColorTarget) {
        updateShapeByID(id) { shape in
            switch target {
            case .fill:
                let currentOpacity = shape.fillStyle?.opacity ?? 1.0
                shape.fillStyle = FillStyle(gradient: gradient, opacity: currentOpacity)
            case .stroke:
                let currentStroke = shape.strokeStyle
                shape.strokeStyle = StrokeStyle(
                    gradient: gradient,
                    width: currentStroke?.width ?? defaultStrokeWidth,
                    placement: currentStroke?.placement ?? strokeDefaults.placement,
                    lineCap: currentStroke?.lineCap.cgLineCap ?? strokeDefaults.lineCap,
                    lineJoin: currentStroke?.lineJoin.cgLineJoin ?? strokeDefaults.lineJoin,
                    miterLimit: currentStroke?.miterLimit ?? strokeDefaults.miterLimit,
                    opacity: currentStroke?.opacity ?? 1.0
                )
            }
        }
    }

    func updateShapeTransformAndPathInUnified(id: UUID, path: VectorPath? = nil, transform: CGAffineTransform? = nil) {
        updateShapeByID(id) { shape in
            if let path = path {
                shape.path = path
            }
            if let transform = transform {
                shape.transform = transform
            }
            shape.updateBounds()
        }
    }

    func updateEntireShapeInUnified(id: UUID, updater: (inout VectorShape) -> Void) {
        updateShapeByID(id) { shape in
            updater(&shape)
            shape.updateBounds()
        }
    }
}
