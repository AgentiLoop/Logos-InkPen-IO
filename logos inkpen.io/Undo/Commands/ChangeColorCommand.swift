import Foundation

class ChangeColorCommand: BaseCommand {

    enum ColorTarget {
        case fill
        case stroke
    }
    private let objectIDs: [UUID]
    private let target: ColorTarget
    private let oldColors: [UUID: VectorColor]
    private let newColors: [UUID: VectorColor]
    private let oldOpacities: [UUID: Double]
    private let newOpacities: [UUID: Double]

    init(objectIDs: [UUID],
         target: ColorTarget,
         oldColors: [UUID: VectorColor],
         newColors: [UUID: VectorColor],
         oldOpacities: [UUID: Double],
         newOpacities: [UUID: Double]) {
        self.objectIDs = objectIDs
        self.target = target
        self.oldColors = oldColors
        self.newColors = newColors
        self.oldOpacities = oldOpacities
        self.newOpacities = newOpacities
    }

    override func execute(on document: VectorDocument) {
        applyColors(newColors, opacities: newOpacities, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyColors(oldColors, opacities: oldOpacities, to: document)
    }

    private func applyColors(_ colors: [UUID: VectorColor],
                             opacities: [UUID: Double],
                             to document: VectorDocument) {
        for id in objectIDs {
            guard var obj = document.snapshot.objects[id] else { continue }
            if let color = colors[id], let opacity = opacities[id] {
                switch obj.objectType {
                case .text(var shape):
                    if var typography = shape.typography {
                        switch target {
                        case .fill:
                            typography.fillColor = color
                            typography.fillOpacity = opacity
                        case .stroke:
                            typography.strokeColor = color
                            typography.strokeOpacity = opacity
                        }
                        shape.typography = typography
                    }
                    obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                    document.snapshot.objects[id] = obj
                case .shape(var shape), .image(var shape), .warp(var shape), .clipMask(var shape):
                    switch target {
                    case .fill:
                        shape.fillStyle?.color = color
                        shape.fillStyle?.opacity = opacity
                    case .stroke:
                        shape.strokeStyle?.color = color
                        shape.strokeStyle?.opacity = opacity
                    }
                    obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                    document.snapshot.objects[id] = obj
                case .group(var shape), .clipGroup(var shape):
                    switch target {
                    case .fill:
                        shape.fillStyle?.color = color
                        shape.fillStyle?.opacity = opacity
                        var updatedChildren: [VectorShape] = []
                        for var childShape in shape.groupedShapes {
                            if let childColor = colors[childShape.id], let childOpacity = opacities[childShape.id] {
                                if var typography = childShape.typography {
                                    typography.fillColor = childColor
                                    typography.fillOpacity = childOpacity
                                    childShape.typography = typography
                                } else {
                                    childShape.fillStyle?.color = childColor
                                    childShape.fillStyle?.opacity = childOpacity
                                }
                            }
                            updatedChildren.append(childShape)
                        }
                        shape.groupedShapes = updatedChildren
                    case .stroke:
                        shape.strokeStyle?.color = color
                        shape.strokeStyle?.opacity = opacity
                        var updatedChildren: [VectorShape] = []
                        for var childShape in shape.groupedShapes {
                            if let childColor = colors[childShape.id], let childOpacity = opacities[childShape.id] {
                                if var typography = childShape.typography {
                                    typography.strokeColor = childColor
                                    typography.strokeOpacity = childOpacity
                                    childShape.typography = typography
                                } else {
                                    childShape.strokeStyle?.color = childColor
                                    childShape.strokeStyle?.opacity = childOpacity
                                }
                            }
                            updatedChildren.append(childShape)
                        }
                        shape.groupedShapes = updatedChildren
                    }
                    obj = VectorObject(shape: shape, layerIndex: obj.layerIndex)
                    document.snapshot.objects[id] = obj
                case .guide:
                    break
                }
            }
        }
    }
}
