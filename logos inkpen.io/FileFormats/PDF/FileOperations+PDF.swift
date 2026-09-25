import SwiftUI

extension FileOperations {

    static func generatePDFData(from document: VectorDocument) throws -> Data {
        return try generatePDFDataWithClippingSupport(from: document, isExport: false, useCMYK: false, textRenderingMode: .lines, includeInkpenData: true)
    }

    static func generatePDFDataForExport(from document: VectorDocument, useCMYK: Bool, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, includeInkpenData: Bool = false, includeBackground: Bool = true) throws -> Data {
        if !useCMYK {
            return try generatePDFDataFromView(from: document, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData, includeBackground: includeBackground)
        } else {
            return try generatePDFDataWithClippingSupport(from: document, isExport: true, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData, includeBackground: includeBackground)
        }
    }

    static func renderShapeToPDF(shape: VectorShape, context: CGContext) throws {
        let cgPath = convertVectorPathToCGPath(shape.path)
        context.saveGState()
        context.concatenate(shape.transform)
        var hasValidFill = false
        if let fillStyle = shape.fillStyle {
            if case .clear = fillStyle.color {
                hasValidFill = false
            } else if fillStyle.opacity > 0 {
                hasValidFill = true
            }
        }
        if hasValidFill, let fillStyle = shape.fillStyle {
            if case .gradient(let gradient) = fillStyle.color {
                context.addPath(cgPath)
                context.saveGState()
                context.clip()
                drawPDFGradient(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity)
                context.restoreGState()
            } else {
                context.addPath(cgPath)
                setFillStyle(fillStyle, context: context)
                context.fillPath()
            }
        }
        var hasValidStroke = false
        if let strokeStyle = shape.strokeStyle {
            if case .clear = strokeStyle.color {
                hasValidStroke = false
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                hasValidStroke = true
            }
        }
        if hasValidStroke, let strokeStyle = shape.strokeStyle {
            context.addPath(cgPath)
            setStrokeStyle(strokeStyle, context: context)
            context.strokePath()
        }
        context.restoreGState()
    }

    static func setFillStyle(_ fillStyle: FillStyle, context: CGContext) {
        let cgColor = fillStyle.color.cgColor
        let workingColorSpace = ColorManager.shared.workingCGColorSpace
        if let convertedColor = cgColor.converted(to: workingColorSpace, intent: .defaultIntent, options: nil),

           let components = convertedColor.components {
            var componentsWithOpacity = components
            if componentsWithOpacity.count > 0 {
                componentsWithOpacity[componentsWithOpacity.count - 1] = fillStyle.opacity
            }
            if let finalColor = CGColor(colorSpace: workingColorSpace, components: componentsWithOpacity) {
                context.setFillColor(finalColor)
            } else {
                context.setFillColor(cgColor.copy(alpha: fillStyle.opacity) ?? cgColor)
            }
        } else {
            context.setFillColor(cgColor.copy(alpha: fillStyle.opacity) ?? cgColor)
        }
    }

    static func setStrokeStyle(_ strokeStyle: StrokeStyle, context: CGContext) {
        let cgColor = strokeStyle.color.cgColor
        let workingColorSpace = ColorManager.shared.workingCGColorSpace
        if let convertedColor = cgColor.converted(to: workingColorSpace, intent: .defaultIntent, options: nil),

           let components = convertedColor.components {
            var componentsWithOpacity = components
            if componentsWithOpacity.count > 0 {
                componentsWithOpacity[componentsWithOpacity.count - 1] = strokeStyle.opacity
            }
            if let finalColor = CGColor(colorSpace: workingColorSpace, components: componentsWithOpacity) {
                context.setStrokeColor(finalColor)
            } else {
                context.setStrokeColor(cgColor.copy(alpha: strokeStyle.opacity) ?? cgColor)
            }
        } else {
            context.setStrokeColor(cgColor.copy(alpha: strokeStyle.opacity) ?? cgColor)
        }
        context.setLineWidth(strokeStyle.width)
        context.setLineCap(strokeStyle.lineCap.cgLineCap)
        context.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
        if !strokeStyle.dashPattern.isEmpty {
            let dashPatternCGFloat = strokeStyle.dashPattern.map { CGFloat($0) }
            context.setLineDash(phase: 0, lengths: dashPatternCGFloat)
        }
    }

    static func drawPDFGradientForExport(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double, useCMYK: Bool) {
        if useCMYK {
            drawPDFGradientAsCMYK(gradient, in: context, bounds: bounds, opacity: opacity)
        } else {
            drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        }
    }

    static func drawPDFGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        #if DEBUG
        let method = AppState.shared.pdfGradientMethod
        switch method {
        case .cgShading:
            drawPDFGradientWithCGShading(gradient, in: context, bounds: bounds, opacity: opacity)
        case .blend:
            drawPDFGradientAsBlend(gradient, in: context, bounds: bounds, opacity: opacity)
        case .mesh:
            drawPDFGradientAsMesh(gradient, in: context, bounds: bounds, opacity: opacity)
        case .cmyk:
            drawPDFGradientAsCMYK(gradient, in: context, bounds: bounds, opacity: opacity)
        default:
            drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        }
        #else
        drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        #endif
    }

    private static func drawPDFGradientWithCGGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        context.setAlpha(CGFloat(opacity))
        switch gradient {
        case .linear(let linearGradient):
            let colorSpace = ColorManager.shared.workingCGColorSpace

            var colors: [CGFloat] = []
            var locations: [CGFloat] = []
            for stop in linearGradient.stops {
                locations.append(stop.position)
                switch stop.color {
                case .rgb(let rgb):
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                case .white:
                    colors.append(contentsOf: [1.0, 1.0, 1.0, CGFloat(stop.opacity)])
                case .black:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                case .clear:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, 0.0])
                case .cmyk(let cmyk):
                    let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
                    let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)
                    let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
                    colors.append(contentsOf: [r, g, b, CGFloat(stop.opacity)])
                case .hsb(let hsb):
                    let rgb = hsb.rgbColor
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                default:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                }
            }
            guard let cgGradient = CGGradient(
                colorSpace: colorSpace,
                colorComponents: colors,
                locations: locations,
                count: locations.count
            ) else { return }
            let angle = linearGradient.angle * .pi / 180.0
            let centerX = bounds.midX
            let centerY = bounds.midY
            let radius = max(bounds.width, bounds.height) / 2.0
            let startX = centerX - radius * cos(angle)
            let startY = centerY - radius * sin(angle)
            let endX = centerX + radius * cos(angle)
            let endY = centerY + radius * sin(angle)
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)
            context.drawLinearGradient(
                cgGradient,
                start: startPoint,
                end: endPoint,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        case .radial(let radialGradient):
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            var colors: [CGFloat] = []
            var locations: [CGFloat] = []
            for stop in radialGradient.stops {
                locations.append(stop.position)
                switch stop.color {
                case .rgb(let rgb):
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                case .white:
                    colors.append(contentsOf: [1.0, 1.0, 1.0, CGFloat(stop.opacity)])
                case .black:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                case .clear:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, 0.0])
                case .cmyk(let cmyk):
                    let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
                    let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)
                    let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
                    colors.append(contentsOf: [r, g, b, CGFloat(stop.opacity)])
                case .hsb(let hsb):
                    let rgb = hsb.rgbColor
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                default:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                }
            }
            guard let cgGradient = CGGradient(
                colorSpace: colorSpace,
                colorComponents: colors,
                locations: locations,
                count: locations.count
            ) else { return }
            let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
            let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
            let center = CGPoint(x: centerX, y: centerY)
            let radius = min(bounds.width, bounds.height) * radialGradient.radius
            let focalCenter: CGPoint
            if let focalPoint = radialGradient.focalPoint {
                let focalX = bounds.minX + bounds.width * focalPoint.x
                let focalY = bounds.minY + bounds.height * focalPoint.y
                focalCenter = CGPoint(x: focalX, y: focalY)
            } else {
                focalCenter = center
            }
            context.drawRadialGradient(
                cgGradient,
                startCenter: focalCenter,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    private final class GradientData {
        let stops: [(position: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)]

        init(stops: [GradientStop], opacity: Double) {
            self.stops = stops.map { stop in
                let cgColor = stop.color.cgColor
                if let components = cgColor.components, components.count >= 3 {
                    return (
                        CGFloat(stop.position),
                        components[0],
                        components[1],
                        components[2],
                        (components.count > 3 ? components[3] : 1.0) * CGFloat(stop.opacity) * CGFloat(opacity)
                    )
                } else if let components = cgColor.components, components.count == 2 {
                    return (
                        CGFloat(stop.position),
                        components[0],
                        components[0],
                        components[0],
                        components[1] * CGFloat(stop.opacity) * CGFloat(opacity)
                    )
                } else {
                    return (CGFloat(stop.position), 0, 0, 0, CGFloat(stop.opacity) * CGFloat(opacity))
                }
            }
        }

        func interpolateColor(at t: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
            guard !stops.isEmpty else { return (0, 0, 0, 0) }
            guard let first = stops.first, let last = stops.last else {
                return (0, 0, 0, 0)
            }
            if t <= first.position {
                return (first.r, first.g, first.b, first.a)
            }
            if t >= last.position {
                return (last.r, last.g, last.b, last.a)
            }
            var lower = first
            var upper = last
            for i in 0..<(stops.count - 1) {
                if t >= stops[i].position && t <= stops[i + 1].position {
                    lower = stops[i]
                    upper = stops[i + 1]
                    break
                }
            }
            let range = upper.position - lower.position
            let factor = range > 0 ? (t - lower.position) / range : 0
            return (
                lower.r + (upper.r - lower.r) * factor,
                lower.g + (upper.g - lower.g) * factor,
                lower.b + (upper.b - lower.b) * factor,
                lower.a + (upper.a - lower.a) * factor
            )
        }
    }

    private static func drawPDFGradientWithCGShading(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        switch gradient {
        case .linear(let linearGradient):
            drawLinearGradientWithCGShading(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawRadialGradientWithCGShading(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }
    }

    private static func drawLinearGradientWithCGShading(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let gradientData = GradientData(stops: linearGradient.stops, opacity: opacity)
        let colorSpace = ColorManager.shared.workingCGColorSpace
        let angle = linearGradient.angle * .pi / 180.0
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radius = max(bounds.width, bounds.height) / 2.0
        let startX = centerX - radius * cos(angle)
        let startY = centerY - radius * sin(angle)
        let endX = centerX + radius * cos(angle)
        let endY = centerY + radius * sin(angle)
        let startPoint = CGPoint(x: startX, y: startY)
        let endPoint = CGPoint(x: endX, y: endY)

        var callbacks = CGFunctionCallbacks(
            version: 0,
            evaluate: { info, input, output in
                guard let info = info else { return }
                let data = Unmanaged<GradientData>.fromOpaque(info).takeUnretainedValue()
                let t = input[0]
                let color = data.interpolateColor(at: t)
                output[0] = color.r
                output[1] = color.g
                output[2] = color.b
                output[3] = color.a
            },
            releaseInfo: { info in
                guard info != nil else { return }
            }
        )
        let function = CGFunction(
            info: Unmanaged.passRetained(gradientData).toOpaque(),
            domainDimension: 1,
            domain: [0, 1],
            rangeDimension: 4,
            range: [0, 1, 0, 1, 0, 1, 0, 1],
            callbacks: &callbacks
        )
        guard let function = function,
              let shading = CGShading(axialSpace: colorSpace,
                                     start: startPoint,
                                     end: endPoint,
                                     function: function,
                                     extendStart: true,
                                     extendEnd: true) else {
            Log.fileOperation("⚠️ CGShading creation failed for linear gradient, falling back to CGGradient", level: .warning)
            drawSimplifiedLinearGradientWithCGGradient(linearGradient, in: context, bounds: bounds, opacity: opacity)
            return
        }
        context.saveGState()
        context.clip(to: bounds)
        context.drawShading(shading)
        context.restoreGState()
    }

    private static func drawRadialGradientWithCGShading(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let gradientData = GradientData(stops: radialGradient.stops, opacity: opacity)
        let colorSpace = ColorManager.shared.workingCGColorSpace
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let radius = min(bounds.width, bounds.height) * radialGradient.radius
        let focalCenter: CGPoint
        if let focalPoint = radialGradient.focalPoint {
            let focalX = bounds.minX + bounds.width * focalPoint.x
            let focalY = bounds.minY + bounds.height * focalPoint.y
            focalCenter = CGPoint(x: focalX, y: focalY)
        } else {
            focalCenter = center
        }
        var callbacks = CGFunctionCallbacks(
            version: 0,
            evaluate: { info, input, output in
                guard let info = info else { return }
                let data = Unmanaged<GradientData>.fromOpaque(info).takeUnretainedValue()
                let t = input[0]
                let color = data.interpolateColor(at: t)
                output[0] = color.r
                output[1] = color.g
                output[2] = color.b
                output[3] = color.a
            },
            releaseInfo: { info in
                guard info != nil else { return }
            }
        )
        let function = CGFunction(
            info: Unmanaged.passRetained(gradientData).toOpaque(),
            domainDimension: 1,
            domain: [0, 1],
            rangeDimension: 4,
            range: [0, 1, 0, 1, 0, 1, 0, 1],
            callbacks: &callbacks
        )
        guard let function = function,
              let shading = CGShading(radialSpace: colorSpace,
                                     start: focalCenter,
                                     startRadius: 0,
                                     end: center,
                                     endRadius: radius,
                                     function: function,
                                     extendStart: false,
                                     extendEnd: true) else {
            Log.fileOperation("⚠️ CGShading creation failed for radial gradient, falling back to CGGradient", level: .warning)
            drawSimplifiedRadialGradientWithCGGradient(radialGradient, in: context, bounds: bounds, opacity: opacity)
            return
        }
        context.saveGState()
        context.clip(to: bounds)
        context.drawShading(shading)
        context.restoreGState()
    }

    private static func drawSimplifiedLinearGradientWithCGGradient(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let colorSpace = ColorManager.shared.workingCGColorSpace
        let angle = linearGradient.angle * .pi / 180.0
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radius = max(bounds.width, bounds.height) / 2.0
        let startX = centerX - radius * cos(angle)
        let startY = centerY - radius * sin(angle)
        let endX = centerX + radius * cos(angle)
        let endY = centerY + radius * sin(angle)
        let startPoint = CGPoint(x: startX, y: startY)
        let endPoint = CGPoint(x: endX, y: endY)

        var colors: [CGFloat] = []
        var locations: [CGFloat] = []
        for stop in linearGradient.stops {
            locations.append(stop.position)
            let cgColor = stop.color.cgColor
            if let components = cgColor.components {
                if components.count >= 3 {
                    colors.append(contentsOf: [
                        components[0],
                        components[1],
                        components[2],
                        (components.count > 3 ? components[3] : 1.0) * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else if components.count == 2 {
                    colors.append(contentsOf: [
                        components[0],
                        components[0],
                        components[0],
                        components[1] * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else {
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                }
            } else {
                colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
            }
        }
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: locations.count
        ) else { return }
        context.saveGState()
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func drawSimplifiedRadialGradientWithCGGradient(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let colorSpace = ColorManager.shared.workingCGColorSpace
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let radius = min(bounds.width, bounds.height) * radialGradient.radius
        let focalCenter: CGPoint
        if let focalPoint = radialGradient.focalPoint {
            let focalX = bounds.minX + bounds.width * focalPoint.x
            let focalY = bounds.minY + bounds.height * focalPoint.y
            focalCenter = CGPoint(x: focalX, y: focalY)
        } else {
            focalCenter = center
        }
        var colors: [CGFloat] = []
        var locations: [CGFloat] = []
        for stop in radialGradient.stops {
            locations.append(stop.position)
            let cgColor = stop.color.cgColor
            if let components = cgColor.components {
                if components.count >= 3 {
                    colors.append(contentsOf: [
                        components[0],
                        components[1],
                        components[2],
                        (components.count > 3 ? components[3] : 1.0) * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else if components.count == 2 {
                    colors.append(contentsOf: [
                        components[0],
                        components[0],
                        components[0],
                        components[1] * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else {
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                }
            } else {
                colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
            }
        }
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: locations.count
        ) else { return }
        context.saveGState()
        context.drawRadialGradient(
            gradient,
            startCenter: focalCenter,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func drawPDFGradientAsBlend(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        context.saveGState()
        switch gradient {
        case .linear(let linearGradient):
            drawLinearGradientAsBlend(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawRadialGradientAsBlend(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }
        context.restoreGState()
    }

    private static func drawLinearGradientAsBlend(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let bandCount = AppState.shared.pdfBlendSteps
        let stops = linearGradient.stops
        guard stops.count >= 2 else { return }
        let angle = linearGradient.angle * .pi / 180.0
        context.saveGState()
        context.clip(to: bounds)
        let halfWidth = bounds.width / 2.0
        let halfHeight = bounds.height / 2.0
        let gradientLength = abs(CGFloat(cos(angle))) * halfWidth + abs(CGFloat(sin(angle))) * halfHeight
        for i in 0..<bandCount {
            let t0 = Double(i) / Double(bandCount)
            let t1 = Double(i + 1) / Double(bandCount)
            let tMid = (t0 + t1) / 2.0
            let color = interpolateGradientColor(at: tMid, stops: stops, opacity: opacity)
            let bandStart = -gradientLength + (2.0 * gradientLength * CGFloat(t0))
            let bandEnd = -gradientLength + (2.0 * gradientLength * CGFloat(t1))
            context.saveGState()
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: -angle)
            let bandWidth = max(bounds.width, bounds.height) * 2
            let bandRect = CGRect(x: bandStart, y: -bandWidth/2, width: bandEnd - bandStart, height: bandWidth)
            context.setFillColor(color)
            context.fill(bandRect)
            context.restoreGState()
        }
        context.restoreGState()
    }

    private static func drawRadialGradientAsBlend(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let bandCount = AppState.shared.pdfBlendSteps
        let stops = radialGradient.stops
        guard stops.count >= 2 else { return }
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let maxRadius = min(bounds.width, bounds.height) * radialGradient.radius
        for i in (0..<bandCount).reversed() {
            let t0 = Double(i) / Double(bandCount)
            let t1 = Double(i + 1) / Double(bandCount)
            let tMid = (t0 + t1) / 2.0
            let color = interpolateGradientColor(at: tMid, stops: stops, opacity: opacity)
            let outerRadius = maxRadius * t1
            let innerRadius = maxRadius * t0
            context.saveGState()
            context.setFillColor(color)
            context.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius,
                                         width: outerRadius * 2, height: outerRadius * 2))
            if i > 0 {
                context.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                             width: innerRadius * 2, height: innerRadius * 2))
                context.fillPath(using: .evenOdd)
            } else {
                context.fillPath()
            }
            context.restoreGState()
        }
    }

    private static func drawPDFGradientAsMesh(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        context.saveGState()
        switch gradient {
        case .linear(let linearGradient):
            drawLinearGradientAsMesh(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawRadialGradientAsMesh(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }
        context.restoreGState()
    }

    private static func drawLinearGradientAsMesh(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let gridSizeX = AppState.shared.pdfMeshGridX
        let gridSizeY = AppState.shared.pdfMeshGridY
        let stops = linearGradient.stops
        guard stops.count >= 2 else { return }
        let angle = linearGradient.angle * .pi / 180.0
        for row in 0..<gridSizeY {
            for col in 0..<gridSizeX {
                let x0 = bounds.minX + (bounds.width * CGFloat(col) / CGFloat(gridSizeX))
                let x1 = bounds.minX + (bounds.width * CGFloat(col + 1) / CGFloat(gridSizeX))
                let y0 = bounds.minY + (bounds.height * CGFloat(row) / CGFloat(gridSizeY))
                let y1 = bounds.minY + (bounds.height * CGFloat(row + 1) / CGFloat(gridSizeY))
                let cellCenterX = (x0 + x1) / 2
                let cellCenterY = (y0 + y1) / 2
                let dx = cellCenterX - bounds.midX
                let dy = cellCenterY - bounds.midY
                let cosAngle = CGFloat(cos(angle))
                let sinAngle = CGFloat(sin(angle))
                let maxDim = max(bounds.width, bounds.height)
                let projection = (dx * cosAngle + dy * sinAngle) / maxDim
                let t = (projection + 1.0) / 2.0
                let color = interpolateGradientColor(at: t, stops: stops, opacity: opacity)
                context.setFillColor(color)
                context.fill(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
            }
        }
    }

    private static func drawRadialGradientAsMesh(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let gridSize = 12
        let stops = radialGradient.stops
        guard stops.count >= 2 else { return }
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let maxRadius = min(bounds.width, bounds.height) * radialGradient.radius
        let angleStep = (2 * Double.pi) / Double(gridSize)
        let radiusStep = maxRadius / CGFloat(gridSize)
        for r in (0..<gridSize).reversed() {
            let innerRadius = CGFloat(r) * radiusStep
            let outerRadius = CGFloat(r + 1) * radiusStep
            let t = (Double(r) + 0.5) / Double(gridSize)
            let color = interpolateGradientColor(at: t, stops: stops, opacity: opacity)
            for a in 0..<gridSize {
                let angle1 = Double(a) * angleStep
                let angle2 = Double(a + 1) * angleStep
                context.saveGState()
                let path = CGMutablePath()
                path.move(to: CGPoint(
                    x: center.x + innerRadius * cos(angle1),
                    y: center.y + innerRadius * sin(angle1)
                ))
                path.addArc(
                    center: center,
                    radius: outerRadius,
                    startAngle: angle1,
                    endAngle: angle2,
                    clockwise: false
                )
                path.addLine(to: CGPoint(
                    x: center.x + innerRadius * cos(angle2),
                    y: center.y + innerRadius * sin(angle2)
                ))
                if innerRadius > 0 {
                    path.addArc(
                        center: center,
                        radius: innerRadius,
                        startAngle: angle2,
                        endAngle: angle1,
                        clockwise: true
                    )
                }
                path.closeSubpath()
                context.addPath(path)
                context.setFillColor(color)
                context.fillPath()
                context.restoreGState()
            }
        }
    }

    private static func drawPDFGradientAsCMYK(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let stops = gradient.stops
        guard !stops.isEmpty else {
            return
        }
        context.saveGState()
        context.clip(to: bounds)
        context.setAlpha(CGFloat(opacity))
        switch gradient {
        case .linear(let linearGradient):
            drawCMYKLinearGradient(linearGradient, stops: stops, in: context, bounds: bounds)
        case .radial(let radialGradient):
            drawCMYKRadialGradient(radialGradient, stops: stops, in: context, bounds: bounds)
        }
        context.restoreGState()
    }

    private static func drawCMYKLinearGradient(_ linearGradient: LinearGradient, stops: [GradientStop], in context: CGContext, bounds: CGRect) {
        let startX = bounds.minX + bounds.width * linearGradient.startPoint.x
        let startY = bounds.minY + bounds.height * linearGradient.startPoint.y
        let endX = bounds.minX + bounds.width * linearGradient.endPoint.x
        let endY = bounds.minY + bounds.height * linearGradient.endPoint.y
        let start = CGPoint(x: startX, y: startY)
        let end = CGPoint(x: endX, y: endY)
        let colorSpace = CGColorSpace(name: CGColorSpace.genericCMYK)!

        var cmykComponents: [CGFloat] = []
        var locations: [CGFloat] = []
        for stop in stops {
            let rgba = stop.color.cgColor.rgbaComponents
            let (r, g, b, _) = (rgba.r, rgba.g, rgba.b, rgba.a)
            let k = 1.0 - max(r, g, b)
            let c = k < 1.0 ? (1.0 - r - k) / (1.0 - k) : 0
            let m = k < 1.0 ? (1.0 - g - k) / (1.0 - k) : 0
            let y = k < 1.0 ? (1.0 - b - k) / (1.0 - k) : 0
            cmykComponents.append(contentsOf: [c, m, y, k, CGFloat(stop.opacity)])
            locations.append(CGFloat(stop.position))
        }
        if let gradient = CGGradient(colorSpace: colorSpace,
                                     colorComponents: cmykComponents,
                                     locations: locations,
                                     count: stops.count) {
            context.drawLinearGradient(gradient,
                                      start: start,
                                      end: end,
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    private static func drawCMYKRadialGradient(_ radialGradient: RadialGradient, stops: [GradientStop], in context: CGContext, bounds: CGRect) {
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let maxRadius = min(bounds.width, bounds.height) * radialGradient.radius
        let colorSpace = CGColorSpace(name: CGColorSpace.genericCMYK)!

        var cmykComponents: [CGFloat] = []
        var locations: [CGFloat] = []
        for stop in stops {
            let rgba = stop.color.cgColor.rgbaComponents
            let (r, g, b, _) = (rgba.r, rgba.g, rgba.b, rgba.a)
            let k = 1.0 - max(r, g, b)
            let c = k < 1.0 ? (1.0 - r - k) / (1.0 - k) : 0
            let m = k < 1.0 ? (1.0 - g - k) / (1.0 - k) : 0
            let y = k < 1.0 ? (1.0 - b - k) / (1.0 - k) : 0
            cmykComponents.append(contentsOf: [c, m, y, k, CGFloat(stop.opacity)])
            locations.append(CGFloat(stop.position))
        }
        if let gradient = CGGradient(colorSpace: colorSpace,
                                     colorComponents: cmykComponents,
                                     locations: locations,
                                     count: stops.count) {
            context.drawRadialGradient(gradient,
                                      startCenter: center,
                                      startRadius: 0,
                                      endCenter: center,
                                      endRadius: maxRadius,
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    private static func interpolateGradientColor(at t: Double, stops: [GradientStop], opacity: Double) -> CGColor {
        guard let first = stops.first, let last = stops.last else { return .clear }
        var lowerStop = first
        var upperStop = last
        for i in 0..<(stops.count - 1) {
            if t >= stops[i].position && t <= stops[i + 1].position {
                lowerStop = stops[i]
                upperStop = stops[i + 1]
                break
            }
        }
        guard let firstStop = stops.first, let lastStop = stops.last else { return .clear }
        if t <= firstStop.position {
            let cgColor = firstStop.color.cgColor
            return cgColor.withAlpha(CGFloat(firstStop.opacity * opacity))
        }
        if t >= lastStop.position {
            let cgColor = lastStop.color.cgColor
            return cgColor.withAlpha(CGFloat(lastStop.opacity * opacity))
        }
        let range = upperStop.position - lowerStop.position
        let factor = range > 0 ? (t - lowerStop.position) / range : 0
        let rgba1 = lowerStop.color.cgColor.rgbaComponents
        let rgba2 = upperStop.color.cgColor.rgbaComponents
        let r = rgba1.r * (1 - factor) + rgba2.r * factor
        let g = rgba1.g * (1 - factor) + rgba2.g * factor
        let b = rgba1.b * (1 - factor) + rgba2.b * factor
        let a = (lowerStop.opacity * (1 - factor) + upperStop.opacity * factor) * opacity
        return CGColor(red: r, green: g, blue: b, alpha: CGFloat(a))
    }

    private static func colorFromVectorColor(_ color: VectorColor, opacity: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let cgColor = color.cgColor
        if let components = cgColor.components, components.count >= 3 {
            if components.count == 4 {
                return (components[0], components[1], components[2], components[3] * CGFloat(opacity))
            } else {
                return (components[0], components[1], components[2], CGFloat(opacity))
            }
        } else if let components = cgColor.components, components.count == 2 {
            return (components[0], components[0], components[0], components[1] * CGFloat(opacity))
        } else {
            return (0.0, 0.0, 0.0, CGFloat(opacity))
        }
    }
}
