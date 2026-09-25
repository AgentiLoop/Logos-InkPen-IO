import SwiftUI

struct SVGConsolidationHelpers {

    static func consolidateSharedGradientsFixed(in inputShapes: [VectorShape]) -> [VectorShape] {
        guard !inputShapes.isEmpty else { return inputShapes }

        struct GroupKey: Hashable {
            let blendMode: BlendMode
            let opacity: Double
            let gradientSig: String
        }
        var buckets: [GroupKey: [VectorShape]] = [:]
        var shapeToBucketMap: [VectorShape: GroupKey] = [:]
        for shape in inputShapes {
            guard let fill = shape.fillStyle,
                  case .gradient(let g) = fill.color,
                  !shape.isGroup,
                  !shape.isWarpObject,
                  !shape.isClippingPath else {
                continue
            }
            let key = GroupKey(blendMode: shape.blendMode, opacity: fill.opacity, gradientSig: g.signature)
            buckets[key, default: []].append(shape)
            shapeToBucketMap[shape] = key
        }
        var consolidatedShapes: [GroupKey: VectorShape] = [:]
        for (key, shapes) in buckets {
            if shapes.count == 1 {
                consolidatedShapes[key] = shapes[0]
                continue
            }
            let cgPaths: [CGPath] = shapes.map { $0.path.cgPath }

            var combined: CGPath? = cgPaths.first
            for p in cgPaths.dropFirst() {
                if let c = combined, let u = CoreGraphicsPathOperations.union(c, p, using: .winding) {
                    combined = u
                } else {
                    combined = nil
                    break
                }
            }
            let compoundPath: VectorPath
            if let unified = combined {
                compoundPath = VectorPath(cgPath: unified, fillRule: .winding)
            } else {
                var elements: [PathElement] = []
                for p in cgPaths {
                    let vp = VectorPath(cgPath: p)
                    elements.append(contentsOf: vp.elements)
                }
                compoundPath = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
            }
            let base = shapes[0]

            var compound = VectorShape(
                name: "Compound Gradient",
                path: compoundPath,
                geometricType: nil,
                strokeStyle: nil,
                fillStyle: base.fillStyle,
                transform: .identity,
                isVisible: true,
                isLocked: false,
                opacity: base.opacity,
                blendMode: key.blendMode,
                isGroup: false,
                groupedShapes: [],
                groupTransform: .identity,
                isCompoundPath: true,
                isWarpObject: false,
                originalPath: nil,
                warpEnvelope: [],
                originalEnvelope: [],
                isRoundedRectangle: false,
                originalBounds: nil,
                cornerRadii: []
            )
            compound.updateBounds()
            consolidatedShapes[key] = compound
        }
        var result: [VectorShape] = []
        for shape in inputShapes {
            if let key = shapeToBucketMap[shape] {
                if let consolidatedShape = consolidatedShapes[key] {
                    if !result.contains(where: { $0.id == consolidatedShape.id }) {
                        result.append(consolidatedShape)
                    }
                } else {
                    result.append(shape)
                }
            } else {
                result.append(shape)
            }
        }
        return result
    }
}
