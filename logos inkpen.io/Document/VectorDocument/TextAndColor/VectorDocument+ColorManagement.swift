import SwiftUI
import Combine

extension VectorDocument {

    func addColorToCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !colorSwatches.rgb.contains(color) {
                colorSwatches.rgb.append(color)
            }
        case .cmyk:
            if !colorSwatches.cmyk.contains(color) {
                colorSwatches.cmyk.append(color)
            }
        case .pms:
            if !colorSwatches.hsb.contains(color) {
                colorSwatches.hsb.append(color)
            }
        }
    }

    func addColorSwatch(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }

    func addColorToSwatches(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }

    func removeColorFromCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            colorSwatches.rgb.removeAll { $0 == color }
        case .cmyk:
            colorSwatches.cmyk.removeAll { $0 == color }
        case .pms:
            colorSwatches.hsb.removeAll { $0 == color }
        }
    }

    func notifyActiveToolsOfFillOpacityChange() {
        viewState.lastColorChangeType = .fillOpacity
        viewState.colorChangeNotification = UUID()
    }

    func notifyActiveToolsOfStrokeColorChange() {
        viewState.lastColorChangeType = .strokeColor
        viewState.colorChangeNotification = UUID()
    }

    func notifyActiveToolsOfStrokeOpacityChange() {
        viewState.lastColorChangeType = .strokeOpacity
        viewState.colorChangeNotification = UUID()
    }

    func notifyActiveToolsOfColorChange() {
        viewState.lastColorChangeType = .fillOpacity
        viewState.colorChangeNotification = UUID()
    }

    private func applyColorToShape(_ shape: inout VectorShape, color: VectorColor, isText: Bool) {
        if isText {
            switch viewState.activeColorTarget {
            case .fill:
                if shape.typography != nil {
                    shape.typography?.fillColor = color
                }
            case .stroke:
                if shape.typography != nil {
                    shape.typography?.hasStroke = true
                    shape.typography?.strokeColor = color
                }
            }
        } else {
            switch viewState.activeColorTarget {
            case .fill:
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: color)
                } else {
                    shape.fillStyle?.color = color
                }
            case .stroke:
                if shape.strokeStyle == nil {
                    shape.strokeStyle = StrokeStyle(color: color, placement: .center)
                } else {
                    shape.strokeStyle?.color = color
                }
            }
        }
    }

    func setActiveColor(_ color: VectorColor) {
        let shouldSaveUndo = !viewState.selectedObjectIDs.isEmpty

        var oldColors: [UUID: VectorColor] = [:]
        var newColors: [UUID: VectorColor] = [:]
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]
        for objectID in viewState.selectedObjectIDs {
            if let vectorObject = snapshot.objects[ objectID] {
                switch vectorObject.objectType {
                case .text(let shape):
                    switch viewState.activeColorTarget {
                    case .fill:
                        oldColors[objectID] = shape.typography?.fillColor ?? .black
                        newColors[objectID] = color
                        let currentOpacity = shape.typography?.fillOpacity ?? defaultFillOpacity
                        oldOpacities[objectID] = currentOpacity
                        newOpacities[objectID] = currentOpacity
                    case .stroke:
                        oldColors[objectID] = shape.typography?.strokeColor ?? .clear
                        newColors[objectID] = color
                        let currentOpacity = shape.typography?.strokeOpacity ?? defaultStrokeOpacity
                        oldOpacities[objectID] = currentOpacity
                        newOpacities[objectID] = currentOpacity
                    }
                case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape), .guide(let shape):
                    switch viewState.activeColorTarget {
                    case .fill:
                        oldColors[objectID] = shape.fillStyle?.color ?? .black
                        newColors[objectID] = color
                        let currentOpacity = shape.fillStyle?.opacity ?? defaultFillOpacity
                        oldOpacities[objectID] = currentOpacity
                        newOpacities[objectID] = currentOpacity
                    case .stroke:
                        oldColors[objectID] = shape.strokeStyle?.color ?? .clear
                        newColors[objectID] = color
                        let currentOpacity = shape.strokeStyle?.opacity ?? defaultStrokeOpacity
                        oldOpacities[objectID] = currentOpacity
                        newOpacities[objectID] = currentOpacity
                    }
                case .group(let shape), .clipGroup(let shape):
                    switch viewState.activeColorTarget {
                    case .fill:
                        oldColors[objectID] = shape.fillStyle?.color ?? .black
                        newColors[objectID] = color
                        let currentOpacity = shape.fillStyle?.opacity ?? defaultFillOpacity
                        oldOpacities[objectID] = currentOpacity
                        newOpacities[objectID] = currentOpacity
                        if !shape.memberIDs.isEmpty {
                            for memberID in shape.memberIDs {
                                if let memberObj = snapshot.objects[memberID] {
                                    switch memberObj.objectType {
                                    case .text(let memberShape):
                                        oldColors[memberID] = memberShape.typography?.fillColor ?? .black
                                        newColors[memberID] = color
                                        let childOpacity = memberShape.typography?.fillOpacity ?? defaultFillOpacity
                                        oldOpacities[memberID] = childOpacity
                                        newOpacities[memberID] = childOpacity
                                    case .shape(let memberShape), .image(let memberShape), .warp(let memberShape), .clipMask(let memberShape), .guide(let memberShape):
                                        oldColors[memberID] = memberShape.fillStyle?.color ?? .black
                                        newColors[memberID] = color
                                        let childOpacity = memberShape.fillStyle?.opacity ?? defaultFillOpacity
                                        oldOpacities[memberID] = childOpacity
                                        newOpacities[memberID] = childOpacity
                                    case .group, .clipGroup:
                                        break
                                    }
                                }
                            }
                        } else {
                            for childShape in shape.groupedShapes {
                                if let typography = childShape.typography {
                                    oldColors[childShape.id] = typography.fillColor
                                    newColors[childShape.id] = color
                                    let childOpacity = typography.fillOpacity
                                    oldOpacities[childShape.id] = childOpacity
                                    newOpacities[childShape.id] = childOpacity
                                } else {
                                    oldColors[childShape.id] = childShape.fillStyle?.color ?? .black
                                    newColors[childShape.id] = color
                                    let childOpacity = childShape.fillStyle?.opacity ?? defaultFillOpacity
                                    oldOpacities[childShape.id] = childOpacity
                                    newOpacities[childShape.id] = childOpacity
                                }
                            }
                        }
                    case .stroke:
                        oldColors[objectID] = shape.strokeStyle?.color ?? .clear
                        newColors[objectID] = color
                        let currentOpacity = shape.strokeStyle?.opacity ?? defaultStrokeOpacity
                        oldOpacities[objectID] = currentOpacity
                        newOpacities[objectID] = currentOpacity
                        if !shape.memberIDs.isEmpty {
                            for memberID in shape.memberIDs {
                                if let memberObj = snapshot.objects[memberID] {
                                    switch memberObj.objectType {
                                    case .text(let memberShape):
                                        oldColors[memberID] = memberShape.typography?.strokeColor ?? .clear
                                        newColors[memberID] = color
                                        let childOpacity = memberShape.typography?.strokeOpacity ?? defaultStrokeOpacity
                                        oldOpacities[memberID] = childOpacity
                                        newOpacities[memberID] = childOpacity
                                    case .shape(let memberShape), .image(let memberShape), .warp(let memberShape), .clipMask(let memberShape), .guide(let memberShape):
                                        oldColors[memberID] = memberShape.strokeStyle?.color ?? .clear
                                        newColors[memberID] = color
                                        let childOpacity = memberShape.strokeStyle?.opacity ?? defaultStrokeOpacity
                                        oldOpacities[memberID] = childOpacity
                                        newOpacities[memberID] = childOpacity
                                    case .group, .clipGroup:
                                        break
                                    }
                                }
                            }
                        } else {
                            for childShape in shape.groupedShapes {
                                if let typography = childShape.typography {
                                    oldColors[childShape.id] = typography.strokeColor
                                    newColors[childShape.id] = color
                                    let childOpacity = typography.strokeOpacity
                                    oldOpacities[childShape.id] = childOpacity
                                    newOpacities[childShape.id] = childOpacity
                                } else {
                                    oldColors[childShape.id] = childShape.strokeStyle?.color ?? .clear
                                    newColors[childShape.id] = color
                                    let childOpacity = childShape.strokeStyle?.opacity ?? defaultStrokeOpacity
                                    oldOpacities[childShape.id] = childOpacity
                                    newOpacities[childShape.id] = childOpacity
                                }
                            }
                        }
                    }
                }
            }
        }
        if shouldSaveUndo && !oldColors.isEmpty {
            let commandTarget: ChangeColorCommand.ColorTarget = (viewState.activeColorTarget == .fill) ? .fill : .stroke
            let command = ChangeColorCommand(
                objectIDs: Array(viewState.selectedObjectIDs),
                target: commandTarget,
                oldColors: oldColors,
                newColors: newColors,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            executeCommand(command)
        }
        switch viewState.activeColorTarget {
        case .fill:
            defaultFillColor = color
        case .stroke:
            defaultStrokeColor = color
        }
        for objectID in viewState.selectedObjectIDs {
            if let vectorObject = snapshot.objects[ objectID] {
                switch vectorObject.objectType {
                case .group(let groupShape), .clipGroup(let groupShape):
                    if !groupShape.memberIDs.isEmpty {
                        for memberID in groupShape.memberIDs {
                            if let memberObject = snapshot.objects[memberID] {
                                switch memberObject.objectType {
                                case .text:
                                    updateShapeByID(memberID) { shape in
                                        applyColorToShape(&shape, color: color, isText: true)
                                    }
                                case .shape, .image, .warp, .clipGroup, .clipMask, .guide:
                                    updateShapeByID(memberID) { shape in
                                        applyColorToShape(&shape, color: color, isText: false)
                                    }
                                case .group:
                                    updateShapeByID(memberID) { shape in
                                        applyColorToShape(&shape, color: color, isText: false)
                                    }
                                }
                            }
                        }
                    } else {
                        for childShape in groupShape.groupedShapes {
                            if let childObject = snapshot.objects[ childShape.id] {
                                switch childObject.objectType {
                                case .text:
                                    updateShapeByID(childShape.id) { shape in
                                        applyColorToShape(&shape, color: color, isText: true)
                                    }
                                case .shape, .image, .warp, .clipGroup, .clipMask, .guide:
                                    updateShapeByID(childShape.id) { shape in
                                        applyColorToShape(&shape, color: color, isText: false)
                                    }
                                case .group:
                                    updateShapeByID(childShape.id) { shape in
                                        applyColorToShape(&shape, color: color, isText: false)
                                    }
                                }
                            }
                        }
                    }
                case .text:
                    updateShapeByID(objectID) { shape in
                        applyColorToShape(&shape, color: color, isText: true)
                    }
                case .shape, .image, .warp, .clipMask, .guide:
                    updateShapeByID(objectID) { shape in
                        applyColorToShape(&shape, color: color, isText: false)
                    }
                }
            }
        }
    }

    func removeColorSwatch(_ color: VectorColor) {
        removeColorFromCurrentMode(color)
    }

    func getSelectedObjectColor() -> VectorColor? {
        guard let firstSelectedID = viewState.selectedObjectIDs.first else { return nil }
        if let vectorObject = snapshot.objects[ firstSelectedID] {
            switch vectorObject.objectType {
            case .text(let shape):
                if viewState.activeColorTarget == .stroke {
                    return shape.typography?.strokeColor
                } else {
                    return shape.typography?.fillColor
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if viewState.activeColorTarget == .stroke {
                    return shape.strokeStyle?.color
                } else {
                    return shape.fillStyle?.color
                }
            }
        }
        return nil
    }

    static func createDefaultRGBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        let rgbColors: [VectorColor] = [
            .rgb(RGBColor(red: 1, green: 0, blue: 0)),
            .rgb(RGBColor(red: 0, green: 1, blue: 0)),
            .rgb(RGBColor(red: 0, green: 0, blue: 1)),
            .rgb(RGBColor(red: 1, green: 1, blue: 0)),
            .rgb(RGBColor(red: 1, green: 0, blue: 1)),
            .rgb(RGBColor(red: 0, green: 1, blue: 1)),
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5)),
            .rgb(RGBColor(red: 1, green: 0.5, blue: 0)),
            .rgb(RGBColor(red: 0.5, green: 0, blue: 0.5)),
            .rgb(RGBColor(red: 0, green: 0.5, blue: 0)),
            .rgb(RGBColor(red: 0, green: 0, blue: 0.5)),
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0)),
        ]
        let p3Colors: [VectorColor] = [
            .rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0)),
            .rgb(RGBColor(red: 1.0, green: 0.231, blue: 0.188)),
            .rgb(RGBColor(red: 0.204, green: 0.780, blue: 0.349)),
            .rgb(RGBColor(red: 1.0, green: 0.800, blue: 0.0)),
            .rgb(RGBColor(red: 1.0, green: 0.584, blue: 0.0)),
            .rgb(RGBColor(red: 0.686, green: 0.322, blue: 0.871)),
            .rgb(RGBColor(red: 1.0, green: 0.176, blue: 0.333)),
            .rgb(RGBColor(red: 0.353, green: 0.784, blue: 0.980)),
            .rgb(RGBColor(red: 0.345, green: 0.337, blue: 0.839)),
            .rgb(RGBColor(red: 0.635, green: 0.518, blue: 0.368)),
            .rgb(RGBColor(red: 0.557, green: 0.557, blue: 0.576)),
            .rgb(RGBColor(red: 0.682, green: 0.682, blue: 0.698)),
            .rgb(RGBColor(red: 0.780, green: 0.780, blue: 0.800))
        ]
        return basicColors + rgbColors + p3Colors
    }

    static func createDefaultCMYKSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]

        var cmykColors: [VectorColor] = []

        let cmykValues = [
            (100, 0, 0, 0),
            (0, 100, 0, 0),
            (0, 0, 100, 0),
            (0, 0, 0, 100),
            (100, 100, 0, 0),
            (0, 100, 100, 0),
            (100, 0, 100, 0),
            (100, 0, 0, 25),
            (0, 100, 0, 25),
            (0, 0, 100, 25),
            (0, 0, 0, 25),
            (0, 0, 0, 50),
            (0, 0, 0, 75),
            (30, 30, 30, 100),
            (40, 40, 40, 100),
            (0, 30, 45, 0),
            (0, 40, 60, 10),
            (0, 50, 75, 25),
        ]
        for (c, m, y, k) in cmykValues {
            let cmykColor = CMYKColor(
                cyan: Double(c) / 100.0,
                magenta: Double(m) / 100.0,
                yellow: Double(y) / 100.0,
                black: Double(k) / 100.0
            )
            cmykColors.append(.cmyk(cmykColor))
        }
        return basicColors + cmykColors
    }

    static func createDefaultHSBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]

        var hsbColors: [VectorColor] = []
        for hue in stride(from: 0, to: 360, by: 30) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 1.0, brightness: 1.0)
            hsbColors.append(.hsb(hsbColor))
        }
        for hue in stride(from: 0, to: 360, by: 60) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.5, brightness: 0.8)
            hsbColors.append(.hsb(hsbColor))
        }
        for hue in stride(from: 0, to: 360, by: 90) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.8, brightness: 0.5)
            hsbColors.append(.hsb(hsbColor))
        }
        return basicColors + hsbColors
    }
}
