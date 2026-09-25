import SwiftUI

extension PDFCommandParser {

    func extractGradientStopsFromPDFStream(shadingDict: CGPDFDictionaryRef) -> [GradientStop] {
        var functionObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, "Function", &functionObj),

              let funcObj = functionObj else {
            Log.error("PDF: ❌ No Function found in shading dictionary - falling back to subsampling", category: .error)
            return createSubsampledGradientStops(from: shadingDict)
        }
        var functionStream: CGPDFStreamRef?
        if CGPDFObjectGetValue(funcObj, .stream, &functionStream),

           let stream = functionStream {
            guard let streamDict = CGPDFStreamGetDictionary(stream) else {
                Log.error("PDF: Failed to get stream dictionary", category: .error)
                return []
            }
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(streamDict, "FunctionType", &functionType)
            if functionType == 0 {
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                if allColors.count > 11 {
                    let subsampledStops = createGradientStopsFromColors(allColors)
                    return subsampledStops
                } else if allColors.count >= 2 {
                    var stops: [GradientStop] = []
                    for i in 0..<allColors.count {
                        let position = Double(i) / Double(max(1, allColors.count - 1))
                        stops.append(GradientStop(position: position, color: allColors[i], opacity: 1.0))
                    }
                    return stops
                }
                Log.error("PDF: 🔄 Color extraction failed, using fallback subsampling", category: .error)
                return createSubsampledGradientStops(from: shadingDict)
            }
        }
        var functionDict: CGPDFDictionaryRef?
        if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),

           let funcDict = functionDict {
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(funcDict, "FunctionType", &functionType)
            if functionType == 2 {
                let nativeStops = extractExponentialFunctionGradientStops(dictionary: funcDict)
                if nativeStops.count >= 2 {
                    return nativeStops
                }
                Log.error("PDF: 🔄 Exponential function extraction failed, using fallback", category: .error)
                return createSubsampledGradientStops(from: shadingDict)
            } else if functionType == 3 {
                let nativeStops = extractStitchingFunctionGradientStops(dictionary: funcDict)
                if !nativeStops.isEmpty {
                    return nativeStops
                } else {
                    Log.error("PDF: ❌ FAILED to extract original stops from stitching function", category: .error)
                    return createSubsampledGradientStops(from: shadingDict)
                }
            }
        }
        Log.error("PDF: ❌ Could not extract gradient stops from PDF Function - using subsampling fallback", category: .error)
        return createSubsampledGradientStops(from: shadingDict)
    }

    private func createSubsampledGradientStops(from shadingDict: CGPDFDictionaryRef? = nil) -> [GradientStop] {
        var allColors: [VectorColor] = []
        if let shadingDict = shadingDict {
            var functionObj: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(shadingDict, "Function", &functionObj),

               let funcObj = functionObj {
                var functionDict: CGPDFDictionaryRef?
                if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),

                   let funcDict = functionDict {
                    allColors = extractAllColorsFromFunction(funcDict)
                }
                var functionStream: CGPDFStreamRef?
                if allColors.isEmpty,
                   CGPDFObjectGetValue(funcObj, .stream, &functionStream),

                   let stream = functionStream {
                    guard let streamDict = CGPDFStreamGetDictionary(stream) else {
                Log.error("PDF: Failed to get stream dictionary", category: .error)
                return []
            }
                    allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                }
            }
        }
        if allColors.count > 2 {
            let subsampledStops = createGradientStopsFromColors(allColors)
            return subsampledStops
        }
        Log.error("PDF: ❌ Could not extract any colors from PDF - using basic two-color fallback", category: .error)
        return [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), opacity: 1.0),
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)), opacity: 1.0)
        ]
    }

    private func extractExponentialFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        var c0Array: CGPDFArrayRef?
        var c1Array: CGPDFArrayRef?
        var startColor = VectorColor.black
        var endColor = VectorColor.white
        if CGPDFDictionaryGetArray(dictionary, "C0", &c0Array),

           let c0 = c0Array {
            startColor = extractColorFromArray(c0)
        }
        if CGPDFDictionaryGetArray(dictionary, "C1", &c1Array),

           let c1 = c1Array {
            endColor = extractColorFromArray(c1)
        }
        let gradientStops = [
            GradientStop(position: 0.0, color: startColor, opacity: 1.0),
            GradientStop(position: 1.0, color: endColor, opacity: 1.0)
        ]
        return gradientStops
    }

    private func extractStitchingFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        var functionsArray: CGPDFArrayRef?
        var boundsArray: CGPDFArrayRef?
        var encodeArray: CGPDFArrayRef?
        var domainArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Functions", &functionsArray),

              let functions = functionsArray else {
            Log.error("PDF: ❌ No Functions array in stitching function", category: .error)
            return []
        }
        CGPDFDictionaryGetArray(dictionary, "Bounds", &boundsArray)
        CGPDFDictionaryGetArray(dictionary, "Encode", &encodeArray)
        CGPDFDictionaryGetArray(dictionary, "Domain", &domainArray)
        let functionCount = CGPDFArrayGetCount(functions)

        var bounds: [Double] = [0.0]
        if let boundsArr = boundsArray {
            let boundsCount = CGPDFArrayGetCount(boundsArr)
            for i in 0..<boundsCount {
                var boundValue: CGPDFReal = 0
                if CGPDFArrayGetNumber(boundsArr, i, &boundValue) {
                    bounds.append(Double(boundValue))
                }
            }
        }
        bounds.append(1.0)
        var gradientStops: [GradientStop] = []
        for i in 0..<functionCount {
            var functionObj: CGPDFObjectRef?
            guard CGPDFArrayGetObject(functions, i, &functionObj),

                  let funcObj = functionObj else {
                Log.error("PDF: ❌ Could not get function \(i)", category: .error)
                continue
            }
            var functionDict: CGPDFDictionaryRef?
            if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),

               let funcDict = functionDict {
                let subStops = extractExponentialFunctionGradientStops(dictionary: funcDict)
                if subStops.count >= 2 {
                    let startPosition = bounds[i]
                    let startStop = GradientStop(
                        position: startPosition,
                        color: subStops[0].color,
                        opacity: 1.0
                    )
                    gradientStops.append(startStop)
                    if i == functionCount - 1 {
                        let endPosition = bounds[i + 1]
                        let endStop = GradientStop(
                            position: endPosition,
                            color: subStops[1].color,
                            opacity: 1.0
                        )
                        gradientStops.append(endStop)
                    }
                }
            }
        }
        gradientStops.sort { $0.position < $1.position }
        return gradientStops
    }
}
