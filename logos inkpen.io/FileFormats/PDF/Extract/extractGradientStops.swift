import SwiftUI

extension PDFCommandParser {

    func extractGradientStops(from dict: CGPDFDictionaryRef) -> [GradientStop] {
        var stops: [GradientStop] = []
        var functionObjRef: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(dict, "Function", &functionObjRef),

              let functionObj = functionObjRef else {
            Log.error("PDF: ❌ No Function found in shading dictionary", category: .error)
            stops = [
                GradientStop(position: 0.0, color: .black, opacity: 1.0),
                GradientStop(position: 1.0, color: .white, opacity: 1.0)
            ]
            return stops
        }
        var functionArray: CGPDFArrayRef?
        if CGPDFObjectGetValue(functionObj, .array, &functionArray),

           let functions = functionArray {
            let count = CGPDFArrayGetCount(functions)
            for i in 0..<count {
                let position = Double(i) / Double(max(1, count - 1))
                let color = extractColorFromFunctionIndex(functions, index: i)
                stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            }
        } else {
            let objectType = CGPDFObjectGetType(functionObj)

            var functionDict: CGPDFDictionaryRef?
            var functionStream: CGPDFStreamRef?
            if CGPDFObjectGetValue(functionObj, .dictionary, &functionDict),

               let function = functionDict {
                let (startColor, endColor) = extractColorsFromFunction(function)
                let allColors = extractAllColorsFromFunction(function)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                } else {
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                }
            } else if CGPDFObjectGetValue(functionObj, .stream, &functionStream),
                      let stream = functionStream,

                      let streamDict = CGPDFStreamGetDictionary(stream) {
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                } else {
                    let (startColor, endColor) = extractColorsFromFunction(streamDict)
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                }
            } else {
                Log.error("PDF: ❌ Failed to extract function (type \(objectType.rawValue)), creating default gradient", category: .error)
                stops = [
                    GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
                    GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)), opacity: 1.0)
                ]
            }
        }
        return stops
    }
}
